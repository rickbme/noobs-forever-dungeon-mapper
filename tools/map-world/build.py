"""Builds NoobsForeverDungeonMapper/Data/WorldMaps.lua: the world map (Azeroth) and the two continents,
with the dungeon and raid entrances placed on them.

  * Map art: the Forever client's own continent maps (UiMap 947, 1414, 1415). The addon draws them by
    FileDataID, as it does the dungeon maps, so no art is bundled. Tables come from wago.tools.
  * Entrances: OpenMap's Places.lua (tools/map-world/places.lua, MIT; see CREDITS.md). Most are in world
    yards on a continent; the new dungeons are a spot (0..1) on a zone's map, which is converted through
    that zone's UiMapAssignment.
  * Coordinates: a UiMapAssignment's Region_0..5 are the map's corners in world yards. x (north) runs from
    Region_0 (bottom) to Region_3 (top); y (west) from Region_4 (left) to Region_1 (right).

usage: python3 -P tools/map-world/build.py [--preview <dir> --wow <World of Warcraft folder>]
Run with the venv's Python (Pillow, numpy) for --preview. Cache: ~/.cache/noobs-forever-dungeon-mapper.
"""
import csv
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "NoobsForeverDungeonMapper", "Data", "WorldMaps.lua")
BUILD = os.environ.get("FD_BUILD", "1.60.1.70959")
CACHE = os.path.expanduser("~/.cache/noobs-forever-dungeon-mapper")
UA = {"User-Agent": "noobs-forever-dungeon-mapper-tools/0.1"}

WORLD, KALIMDOR, EASTERN = 947, 1414, 1415
CONTINENT_OF = {0: EASTERN, 1: KALIMDOR}      # Places.lua's continent number -> UiMap
NAMES = {WORLD: "Azeroth", KALIMDOR: "Kalimdor", EASTERN: "Eastern Kingdoms"}


def table(name):
    path = os.path.join(CACHE, "%s-%s.csv" % (name, BUILD))
    if not (os.path.exists(path) and os.path.getsize(path) > 50):
        os.makedirs(CACHE, exist_ok=True)
        data = urllib.request.urlopen(urllib.request.Request(
            "https://wago.tools/db2/%s/csv?build=%s" % (name, BUILD), headers=UA), timeout=120).read()
        open(path, "wb").write(data)
        time.sleep(0.3)
    return list(csv.DictReader(open(path, encoding="utf-8")))


def parse_places():
    """Places.lua's `instances`: [(continent|None, x, y, [(id, name, raid, lo, hi)], zone map|None)]"""
    out, inside = [], False
    for line in open(os.path.join(HERE, "places.lua"), encoding="utf-8"):
        if line.startswith("\tinstances = {"):
            inside = True
        elif inside and line.startswith("\t},"):
            break
        elif inside:
            m = re.match(r'\s*\{ (nil|\d+), (-?[\d.]+), (-?[\d.]+), \{(.*)\}(?:, map = (\d+))? \},', line)
            if not m:
                continue
            cont = None if m.group(1) == "nil" else int(m.group(1))
            inst = [(int(a), b, c == "true", int(d), int(e)) for a, b, c, d, e in
                    re.findall(r'\{ (\d+), "(.*?)", (true|false), (\d+), (\d+) \}', m.group(4))]
            out.append((cont, float(m.group(2)), float(m.group(3)), inst, int(m.group(5)) if m.group(5) else None))
    return out


def main():
    args = sys.argv[1:]
    preview = wow = None
    if "--preview" in args:
        preview = args[args.index("--preview") + 1]
    if "--wow" in args:
        wow = args[args.index("--wow") + 1]

    art = {int(r["UiMapID"]): r["UiMapArtID"] for r in table("UiMapXMapArt")}
    tiles_by_art = {}
    for r in table("UiMapArtTile"):
        if r["LayerIndex"] == "0":
            tiles_by_art.setdefault(r["UiMapArtID"], {})[(int(r["RowIndex"]), int(r["ColIndex"]))] = int(r["FileDataID"])

    def tiles(uimap):
        t = tiles_by_art[art[uimap]]
        return [t[(r, c)] for r in range(3) for c in range(4)]

    regions, world_rects = {}, {}
    for r in table("UiMapAssignment"):
        mid = int(r["UiMapID"])
        if mid == WORLD:
            world_rects[int(r["MapID"])] = tuple(float(r[k]) for k in ("UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"))
        elif mid not in regions:
            regions[mid] = (int(r["MapID"]), tuple(float(r["Region_%d" % i]) for i in range(6)))

    def to_ui(region, x, y):
        r0, r1, _, r3, r4, _ = region
        return (r4 - y) / (r4 - r1), (r3 - x) / (r3 - r0)

    def from_ui(region, ux, uy):
        r0, r1, _, r3, r4, _ = region
        return r3 - uy * (r3 - r0), r4 - ux * (r4 - r1)

    # every entrance as (continent number, world x, world y, instances)
    spots = []
    for cont, a, b, inst, zone in parse_places():
        if cont is None:
            mapid, region = regions[zone]
            x, y = from_ui(region, a, b)
            spots.append((mapid, x, y, inst))
        else:
            spots.append((cont, a, b, inst))

    maps = {}
    for cont, ui in CONTINENT_OF.items():
        _, region = regions[ui]
        pins = []
        for c, x, y, inst in spots:
            if c == cont:
                px, py = to_ui(region, x, y)
                pins.append((px, py, inst))
        maps[ui] = pins
    world_pins = []
    for cont, ui in CONTINENT_OF.items():
        u0, v0, u1, v1 = world_rects[cont]
        for px, py, inst in maps[ui]:
            world_pins.append((u0 + px * (u1 - u0), v0 + py * (v1 - v0), inst))
    maps[WORLD] = world_pins

    def lua_str(s):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    lines = [
        "-- The world map and the continents' maps, with the dungeon and raid entrances on them.",
        "--   { uiMapID, name, tiles = { 12 FileDataIDs, row by row, 4 x 256 px across, 3 down },",
        "--     pins = { { x, y (0..1 across and down the 1002 x 668 picture), { { instanceID, name, raid, minLevel, maxLevel }, ... } }, ... },",
        "--     sub = { { uiMapID, x, y, w, h } } (on the world map: where each continent lies) }",
        "-- The art is the Forever client's own, drawn by FileDataID. Entrances are OpenMap's (MIT).",
        "-- Generated by tools/map-world/build.py (build %s); regenerate rather than edit." % BUILD,
        "local _, ns = ...",
        "",
        "ns.WorldMaps = {",
    ]
    for ui in (WORLD, EASTERN, KALIMDOR):
        lines.append("\t{")
        lines.append("\t\tuiMapID = %d, name = %s," % (ui, lua_str(NAMES[ui])))
        lines.append("\t\ttiles = { %s }," % ", ".join(str(t) for t in tiles(ui)))
        if ui == WORLD:
            subs = []
            for cont, cui in CONTINENT_OF.items():
                u0, v0, u1, v1 = world_rects[cont]
                subs.append("{ %d, %.4f, %.4f, %.4f, %.4f }" % (cui, u0, v0, u1 - u0, v1 - v0))
            lines.append("\t\tsub = { %s }," % ", ".join(subs))
        lines.append("\t\tpins = {")
        for px, py, inst in maps[ui]:
            items = ", ".join("{ %d, %s, %s, %d, %d }" % (i, lua_str(n), "true" if raid else "false", lo, hi)
                              for i, n, raid, lo, hi in inst)
            lines.append("\t\t\t{ %.4f, %.4f, { %s } }," % (px, py, items))
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote", os.path.relpath(OUT, ROOT), "-", ", ".join("%s: %d pins" % (NAMES[u], len(p)) for u, p in maps.items()))

    if preview:
        from PIL import Image, ImageDraw
        sys.path.insert(0, os.path.join(ROOT, "tools", "casc"))
        sys.path.insert(0, os.path.join(ROOT, "tools", "map-dungeons"))
        from casc import Casc
        from minimap import blp
        casc = Casc(wow, "wowf")
        os.makedirs(preview, exist_ok=True)
        for ui, pins in maps.items():
            page = Image.new("RGB", (1024, 768))
            for n, fid in enumerate(tiles(ui)):
                page.paste(blp(casc.read(fid)).convert("RGB"), ((n % 4) * 256, (n // 4) * 256))
            page = page.crop((0, 0, 1002, 668))
            d = ImageDraw.Draw(page)
            icons = os.path.join(ROOT, "NoobsForeverDungeonMapper", "Media", "Textures")
            normal = Image.open(os.path.join(icons, "DungeonPortal.tga")).convert("RGBA")
            raid = Image.open(os.path.join(icons, "DungeonPortalRaid.tga")).convert("RGBA")
            size = 22 if ui == WORLD else 28
            for px, py, inst in pins:
                icon = (raid if all(i[2] for i in inst) else normal).resize((size, size), Image.LANCZOS)
                page.paste(icon, (int(px * 1002 - size / 2), int(py * 668 - size / 2)), icon)
            page.save(os.path.join(preview, "world_%d.png" % ui))


if __name__ == "__main__":
    main()
