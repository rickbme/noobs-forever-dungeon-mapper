# Handoff: Noobs Forever Dungeon Mapper

Notes for the next working session. Read this first, then [AGENTS.md](AGENTS.md) (rules) and
[PLAN.md](PLAN.md) (history and direction). Last updated 2026-11-19.

## What this is

A World of Warcraft: Forever addon (`NoobsForeverDungeonMapper/`) from the Noobs Forever guild. It opens the
dungeon's map when you enter a dungeon, with a floor picker, boss pins, a boss list with kill tracking, an
"area you are in" marker, and a world map showing every dungeon entrance. Everything has a button, so
no slash commands are needed (`/fd` still works as a shortcut).

- Repo: https://github.com/rickbme/noobs-forever-dungeon-mapper (only branch: `main`)
- Version: `0.2.6-beta` (in the `.toc`). Releases: v0.1.0-beta to v0.2.6-beta (GitHub pre-releases).
- Modelled on [OpenMap](https://github.com/openmap-world/openmap) (MIT); see [CREDITS.md](CREDITS.md).
- Maps of the new dungeons are by Santiago Reyes, used under his announcement's terms (non-commercial, keep
  watermark and credit). A thank-you and permission request was written; it may or may not have been sent.
- License: MIT for our code. Blizzard art and Reyes' art are not covered by it.

## Status

| Done and checked offline (lint + harness, 400+ checks) | Checked in game by the maintainer |
|---|---|
| Dungeon map window, floors, boss pins and list, kill tracking, minimap button | Window, Options window, welcome popup, Ragefire Chasm looked fine |
| Reyes' maps for 8 of the 9 new dungeons, credit line on the map | Only partly checked |
| Maps built from the game's own minimap pictures (fallback) | Not checked |
| "You are here" marker by sub-zone (only The Hall of Thanes has anchors) | **Not checked** |
| `/fd probe` and sub-zone recording | **Not checked: its results are needed** |
| "My quests here" panel and quest markers on bosses | **Not checked: matching depends on how the quest log files and words quests** |
| Boss pin placer + "Share my boss pins" | **Not checked, click-to-map conversion untested** |
| World map (Azeroth, both continents) with entrances; opens on the player's continent with a marker outdoors | **Not checked** |

Follow [docs/in-game-checklist.md](docs/in-game-checklist.md) for the in-game pass.

## Layout

| Path | What |
|---|---|
| `NoobsForeverDungeonMapper/*.toc`, `Bindings.xml` | `## Interface: 16001`, game type `forever`, load order, key bindings |
| `Data/Dungeons.lua` | **generated** by `tools/gen_data.py`: dungeons, Blizzard floors, bosses and pins, sub-zones |
| `Data/DungeonDrawn.lua` | **generated** by `tools/map-dungeons/drawn.py` from `art/drawn/dungeons/` (Reyes' maps) |
| `Data/DungeonMinimap.lua` | **generated** by `tools/map-dungeons/minimap.py` (maps built from the install's minimap pictures) |
| `Data/WorldMaps.lua` | **generated** by `tools/map-world/build.py`: continent art IDs and entrance pins |
| `Data/DungeonBosses.lua`, `tools/map-world/places.lua` | OpenMap's data, copied as is (attributed) |
| `Data/BossPlaces.lua`, `Data/Anchors.lua`, `Data/Merge.lua` | hand-written: placed boss pins, "you are here" areas, and the merge of all sources |
| `Core.lua` | saved variables (`NoobsForeverDungeonMapperDB`), events, kill tracking, floor guessing, slash commands |
| `MapFrame.lua` | the dungeon map window (tiles, pins, boss list, you-are-here, placer UI) |
| `WorldMap.lua` | the world map window |
| `Options.lua` | options window, welcome popup, Options > AddOns entry, key binding functions |
| `BossPlacer.lua`, `Probe.lua` | boss pin placer and export; `/fd probe` |
| `MinimapButton.lua`, `LiveView.lua` | minimap button; optional enlarged minimap |
| `Media/Textures/` | tiles cut from the client (minimap-built maps) and Reyes' maps (35 MB of TGA) |
| `tools/test/harness.lua`, `tools/test/lint.py` | offline tests against a stubbed WoW API; static checks |
| `tools/package.py` | builds the addon-only zip for players (`dist/`) |
| `tools/casc/casc.py` | reads files by ID from a local game install (adapted from OpenMap) |

## Commands

```bash
for f in NoobsForeverDungeonMapper/*.lua NoobsForeverDungeonMapper/Data/*.lua; do luac5.1 -p "$f"; done
python3 -P tools/test/lint.py
lua5.1 tools/test/harness.lua
python3 -P tools/package.py v0.1.0-beta        # the player zip, into dist/
```

The map generators need Pillow and numpy (a virtual environment is best) and, for the ones that read
files, the game install. See [docs/development.md](docs/development.md).

## Key facts learned (don't re-research these)

- **Forever client**: product `wowf`, build 1.60.1.70959 as of 2026-11-19, TOC interface `16001`. Modern
  (Midnight-era) API with "secret values": `issecretvalue()` exists and the addon wraps reads in `ns.Safe`.
- **No dungeon UiMaps in Forever** (its `UiMap` has 60 world, zone and city maps), but the **legacy dungeon
  map textures still ship** and are drawn by FileDataID (4x3 tiles of 256 px, visible 1002x668). Map
  definitions come from **MoP Classic** tables (build 5.5.4.x); Wrath Classic lacks the vanilla art.
- **Continent art exists too**: UiMaps 947 (Azeroth), 1414 (Kalimdor), 1415 (Eastern Kingdoms) have 12 tiles
  each, all present in the install. `UiMapAssignment` gives each map's corners in world yards.
- **The new dungeons**: only some have client data. The WDT files for The Drowned City, Blackmaw Hold, Shaper's
  Terrace, Krol'dok Stronghold and Alcaz Prison are **encrypted** in the installed build (re-check after
  patches). Alcaz Prison has no map at all (Reyes lists it as planned).
- **Player position is expected blocked in instances** (`C_Map.GetPlayerMapPosition`, `UnitPosition`,
  `GetPlayerFacing`), from the API docs. Not yet confirmed live: that is what `/fd probe` is for.
- **Boss kills**: Forever fires `ENCOUNTER_END` (`success == 1`); `BOSS_KILL` is unreliable. Payloads may be
  secret, so match by encounter ID, then name.
- `GetInstanceInfo()`'s 8th return is the instanceID (= Map table ID). `LFGDungeons.MapID` is 0 everywhere.
- **Don't hook `WorldMapFrame`**: it breaks the map's OnShow on this client. We use standalone windows.
- **Minimap**: Forever's Edit Mode `MinimapContainer`. Live view only calls `Minimap:SetScale`, never in combat.
- **wago.tools rejects Python's default User-Agent**; endpoints `/api/builds`, `/db2/<Table>/csv?build=<ver>`,
  `/api/casc/<FileDataID>?download&version=<ver>`. A missing file answers HTTP 200 with an empty body.
- **Boss pins**: only 118 of 242 bosses have one. OpenMap has none for Ragefire Chasm, Stockade, Scarlet
  Monastery, Scholomance, ZF, BFD, SFK or the new dungeons. Blackrock Spire and Dire Maul have a different floor
  order from OpenMap's, so its pins are skipped there.
- **Non-English clients may draw some game tiles as solid green squares** (OpenMap's finding; it copies the
  tiles into the addon). Not handled here yet.
- **Blizzard UI source for Forever**: https://github.com/Gethe/wow-ui-source, branch `forever`
  (`Blizzard_APIDocumentationGenerated` lists each function's restrictions).
- **Reference addons** (studied, no code copied; both GPL, keep it that way): perweum/dungeon-crawler-forever,
  Arcaneology/WowHandbookAddon.

## Working conventions

- The maintainer plays on a separate Windows PC; the development machine is Linux and can only run the game
  through a compatibility layer, so in-game results come back as screenshots or saved-variables files
  (`WTF/Account/<account>/SavedVariables/NoobsForeverDungeonMapper.lua`).
- Never push a tag or publish a release without the maintainer's go-ahead for that release.
- Say plainly what has not been checked in game.

## Guild feedback to follow up (2026-11-25)

See the table at the end of PLAN.md: kill display needs a real run (`encounterLog` in the saved variables),
the greyed-out map needs a screenshot, quest locations need a data source.

## To do next (in order)

1. **In-game pass** with [docs/in-game-checklist.md](docs/in-game-checklist.md); fix what breaks and add each bug to
   the harness. Send back the saved-variables file after running `/fd probe log` in a dungeon.
2. **Publish the beta** (needs the maintainer's go-ahead): bump the version if wanted, tag, push the tag; the
   `release` workflow builds `NoobsForeverDungeonMapper-<tag>.zip`, the addon-only download.
3. **Anchors**: fill `Data/Anchors.lua` from the sub-zone names the probe records (only The Hall of Thanes has
   anchors, and its names are unconfirmed).
4. **Boss pins**: gather players' "Share my boss pins" exports into `Data/BossPlaces.lua`.
5. **Green-squares guard** for non-English clients, if anyone needs it.
6. Re-check the encrypted dungeons after patches, and Alcaz Prison's map when Reyes publishes it.
7. **Later**: zone maps, own position on the continent outdoors, raid data (MC, BWL, ZG, AQ), quest and loot
   notes, auto-hide in combat.
