"""Merge players' boss pins into NoobsForeverDungeonMapper/Data/BossPlaces.lua.

Players export their pins from the addon (Options > Share my boss pins) as lines like

    NFDM|34|Stormwind Stockade|Hamhock|1|0.8000|0.4500

and paste them to the guild (the Discord boss pins channel). Give this tool a text file (or stdin) holding
those messages; Discord quoting, `code ticks` and chatter around the lines are ignored. It

  1. checks each line against the game data (dungeon, boss, floor, 0..1 position) and skips bad ones,
  2. adds the new ones to tools/pins/submissions.txt (the record of everything received, oldest first, one line
     per pin; a line sent again moves to the end),
  3. for each boss counts ONE opinion per player (lines carry a random six-digit hex code, no name: a player's
     latest pin for a boss replaces their earlier ones), takes the floor most people chose and the MEDIAN
     position, and uses the group of
     players who agree within --spread (default 0.10 of the map) when they are a majority and ignores the
     far-off ones, and flags bosses where no majority agrees (leaving those out unless --accept-conflicts), and
  4. rewrites Data/BossPlaces.lua from all submissions.

A player who removes a pin they already sent withdraws it with a `NFDM|REMOVE|id|dungeon|boss|code` line, which
this tool applies (the code identifies the player). To judge the data use --explain (each player's pin and how far
it is from the result), --min-agree 2 (only publish bosses two players agree on) and --ignore (discard a player's
pins, one boss of theirs, or everything for a boss to start it again).

    python3 -P tools/ingest_pins.py pasted.txt
    python3 -P tools/ingest_pins.py --stdin < pasted.txt
    python3 -P tools/ingest_pins.py                 (just rebuild BossPlaces.lua from submissions.txt)

Add --check to report without writing anything. Needs only Python 3.
"""
import argparse
import collections
import math
import os
import re
import statistics
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DATA = os.path.join(ROOT, "NoobsForeverDungeonMapper", "Data")
SUBMISSIONS = os.path.join(ROOT, "tools", "pins", "submissions.txt")
IGNORE = os.path.join(ROOT, "tools", "pins", "ignore.txt")
OUT = os.path.join(DATA, "BossPlaces.lua")


def norm(s):
    return re.sub(r"[^0-9a-z]", "", s.lower())


def load_dungeons():
    """{id: {"name", "floors", "bosses": {norm name: real name}}} from the generated data files"""
    text = open(os.path.join(DATA, "Dungeons.lua"), encoding="utf-8").read()
    out = {}
    parts = re.split(r"\n  \[(\d+)\] = \{", text)
    for i in range(1, len(parts), 2):
        body = parts[i + 1].split("\n  [")[0]
        floors_part = body.split("bosses = {")[0]
        bosses = re.findall(r'\{ id = \d+, name = "(.*?)"', body)
        out[int(parts[i])] = {
            "name": re.search(r'name = "(.*?)"', body).group(1),
            "floors": len(re.findall(r"tiles = \{", floors_part)),
            "bosses": {norm(b): b for b in bosses},
        }
    # the new dungeons' floors come from the drawn / minimap-built maps
    for fname in ("DungeonDrawn.lua", "DungeonMinimap.lua"):
        path = os.path.join(DATA, fname)
        if not os.path.exists(path):
            continue
        t = open(path, encoding="utf-8").read()
        p = re.split(r"\n\t\[(\d+)\] = \{", t)
        for i in range(1, len(p), 2):
            n = len(re.findall(r"tiles = \{", p[i + 1].split("\n\t},")[0]))
            mid = int(p[i])
            if mid in out and out[mid]["floors"] == 0:
                out[mid]["floors"] = n
    return out


def parse_line(line, dungeons):
    """-> (pin tuple, None) for a good pin line, (None, reason) for a bad one, (None, None) for chatter.
    A pin is (id, boss, floor, x, y, contributor code or None)."""
    line = re.sub(r"^[\s>`]+", "", line)
    line = re.sub(r"[\s`]+$", "", line)
    m = re.match(r"^NFDM\|(.*)$", line)
    if not m:
        return None, None
    f = m.group(1).split("|")
    if len(f) < 6:
        return None, "incomplete: " + line[:60]
    try:
        mid, floor, x, y = int(f[0]), int(f[3]), float(f[4]), float(f[5])
    except ValueError:
        return None, "not numbers: " + line[:60]
    d = dungeons.get(mid)
    if not d:
        return None, "unknown dungeon %s" % f[0]
    if d["floors"] == 0:
        return None, "%s has no map yet" % d["name"]
    boss = d["bosses"].get(norm(f[2]))
    if not boss:
        return None, "no boss '%s' in %s" % (f[2], d["name"])
    if not 1 <= floor <= d["floors"]:
        return None, "%s: floor %d isn't one of %s's" % (boss, floor, d["name"])
    if not (0 <= x <= 1 and 0 <= y <= 1):
        return None, "%s: position off the map" % boss
    code = f[6].strip() if len(f) >= 7 and re.fullmatch(r"[0-9a-fA-F]{6}", f[6].strip()) else None
    return (mid, boss, floor, round(x, 4), round(y, 4), code.lower() if code else None), None


def parse_remove(line, dungeons):
    """A withdrawal: "NFDM|REMOVE|id|dungeon|boss|code" -> (id, boss, code), else None"""
    line = re.sub(r"^[\s>`]+", "", line)
    line = re.sub(r"[\s`]+$", "", line)
    m = re.match(r"^NFDM\|REMOVE\|(\d+)\|(.*?)\|(.*?)\|([0-9a-fA-F]{6})$", line)
    if not m:
        return None
    d = dungeons.get(int(m.group(1)))
    boss = d["bosses"].get(norm(m.group(3))) if d else None
    return (int(m.group(1)), boss, m.group(4).lower()) if boss else None


def load_ignore(path):
    """lines: `code` (everything from that player), `code|id|boss` (that player's pin for a boss), or
    `*|id|boss` (every submission for a boss: to start that boss again)"""
    out = []
    if os.path.exists(path):
        for l in open(path, encoding="utf-8"):
            l = l.split("#")[0].strip()
            if l:
                f = l.split("|")
                out.append((f[0].lower(), int(f[1]) if len(f) > 1 else None, norm(f[2]) if len(f) > 2 else None))
    return out


def is_ignored(ignore, code, mid, boss):
    for c, i, b in ignore:
        if (c == "*" or (code and c == code)) and (i is None or i == mid) and (b is None or b == norm(boss)):
            return True
    return False


def canonical(pin, dungeons):
    mid, boss, floor, x, y = pin[:5]
    code = pin[5] if len(pin) > 5 else None
    return "NFDM|%d|%s|%s|%d|%.4f|%.4f" % (mid, dungeons[mid]["name"], boss, floor, x, y) + ("|" + code if code else "")


def consensus(subs, spread):
    """subs: [(floor, x, y)] -> (floor, x, y, dropped, agreed) or None when the players don't agree.

    The floor most players chose; then the largest group of positions all within `spread` of one of them. If that
    group is more than half of the players (or there is just one player) its median is the answer and the
    others are ignored; otherwise there is no agreement."""
    floors = collections.Counter(s[0] for s in subs)
    top = max(floors.values())
    floor = min(f for f, n in floors.items() if n == top)
    pts = [(s[1], s[2]) for s in subs if s[0] == floor]
    best = []
    for c in pts:
        group = [q for q in pts if math.hypot(q[0] - c[0], q[1] - c[1]) <= spread]
        if len(group) > len(best):
            best = group
    if len(subs) > 1 and not len(best) * 2 > len(subs):
        return None
    mx, my = statistics.median(q[0] for q in best), statistics.median(q[1] for q in best)
    return floor, mx, my, len(subs) - len(best), len(best)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(path, result, dungeons):
    lines = [
        "-- Boss pin positions placed by players (Options > Help map the bosses), merged from everyone's exports.",
        "--   [instanceID] = { [\"Boss name\"] = { floor index, x 0..1 across, y 0..1 down }, ... }",
        "-- x and y are fractions of the 1002 x 668 map picture, as for the other pins. These win over every other source.",
        "-- Generated by tools/ingest_pins.py from tools/pins/submissions.txt (the median of what players sent); regenerate",
        "-- rather than edit.",
        "local _, ns = ...",
        "",
        "ns.BossPlaces = {",
    ]
    for mid in sorted(result):
        lines.append("\t[%d] = { -- %s" % (mid, dungeons[mid]["name"]))
        for boss in sorted(result[mid]):
            floor, x, y = result[mid][boss]
            lines.append("\t\t[%s] = { %d, %.4f, %.4f }," % (lua_str(boss), floor, x, y))
        lines.append("\t},")
    lines.append("}")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="text files holding pasted pin lines")
    ap.add_argument("--stdin", action="store_true", help="also read pasted text from standard input")
    ap.add_argument("--spread", type=float, default=0.10, help="largest disagreement allowed between players")
    ap.add_argument("--accept-conflicts", action="store_true", help="use the median even where players disagree")
    ap.add_argument("--min-agree", type=int, default=1, help="leave out bosses fewer than this many players agree on (use 2 for a public release)")
    ap.add_argument("--explain", action="store_true", help="show every player's pin for each boss and how far it is from the result")
    ap.add_argument("--ignore", metavar="SPEC", help="discard a player's pins: CODE, CODE|id|boss, or *|id|boss (added to tools/pins/ignore.txt)")
    ap.add_argument("--check", action="store_true", help="report only; write nothing")
    ap.add_argument("--block", action="store_true", help="print the merged pins as one block of lines, to pin in Discord for the guild to import")
    ap.add_argument("--submissions", default=SUBMISSIONS)
    ap.add_argument("--ignore-file", default=IGNORE)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    dungeons = load_dungeons()
    if a.ignore:
        os.makedirs(os.path.dirname(a.ignore_file), exist_ok=True)
        with open(a.ignore_file, "a", encoding="utf-8", newline="\n") as fh:
            fh.write(a.ignore + "\n")
        print("ignoring:", a.ignore)
    ignore = load_ignore(a.ignore_file)
    everything = []   # every valid line received, oldest first (a line sent again moves to the end: the latest wins)
    if os.path.exists(a.submissions):
        everything = [l.rstrip("\n") for l in open(a.submissions, encoding="utf-8") if l.startswith("NFDM|")]

    texts = [open(f, encoding="utf-8").read() for f in a.files]
    if a.stdin:
        texts.append(sys.stdin.read())
    added, resent, skipped, withdrawn = [], [], [], []

    def receive(line):
        if line in everything:
            everything.remove(line)
            resent.append(line)
        else:
            added.append(line)
        everything.append(line)

    for text in texts:
        for raw in text.splitlines():
            rem = parse_remove(raw, dungeons)
            if rem:
                withdrawn.append(rem)
                receive("NFDM|REMOVE|%d|%s|%s|%s" % (rem[0], dungeons[rem[0]]["name"], rem[1], rem[2]))
                continue
            pin, why = parse_line(raw, dungeons)
            if pin:
                receive(canonical(pin, dungeons))
            elif why:
                skipped.append(why)

    # one opinion per player per boss: the same contributor sending a boss again replaces their earlier pin
    latest = collections.OrderedDict()
    players = set()
    for line in everything:
        rem = parse_remove(line, dungeons)
        if rem:   # the player took the pin back
            latest.pop((rem[0], rem[1], rem[2]), None)
            continue
        pin, _ = parse_line(line, dungeons)
        if pin:
            if pin[5]:
                players.add(pin[5])
            if is_ignored(ignore, pin[5], pin[0], pin[1]):
                continue
            who = pin[5] or line   # a line without a code is its own anonymous player
            latest.pop((pin[0], pin[1], who), None)
            latest[(pin[0], pin[1], who)] = (pin[2], pin[3], pin[4])
    by_boss = collections.defaultdict(list)
    for (mid, boss, _), sub in latest.items():
        by_boss[(mid, boss)].append(sub)

    result, conflicts, singles, outliers, thin = {}, [], [], [], []
    for (mid, boss), subs in sorted(by_boss.items()):
        agreed = consensus(subs, a.spread)
        if agreed is None:
            conflicts.append((mid, boss, len(subs)))
            if not a.accept_conflicts:
                continue
            floor = collections.Counter(q[0] for q in subs).most_common(1)[0][0]
            pts = [(q[1], q[2]) for q in subs if q[0] == floor]
            agreed = (floor, statistics.median(p[0] for p in pts), statistics.median(p[1] for p in pts), 0, len(pts))
        floor, x, y, dropped, n = agreed
        if n < a.min_agree:
            thin.append((mid, boss, n))
            continue
        if dropped:
            outliers.append((mid, boss, dropped))
        if len(subs) == 1:
            singles.append((mid, boss))
        result.setdefault(mid, {})[boss] = (floor, x, y)

    print("new lines: %d, sent again: %d, withdrawals: %d, skipped: %d, players with a code: %d"
          % (len(added), len(resent), len(withdrawn), len(skipped), len(players)))
    for why in skipped:
        print("  skipped:", why)
    print("bosses with a pin: %d" % sum(len(v) for v in result.values()))
    for mid, boss, n in conflicts:
        print("  CONFLICT %s / %s: %d players, no group of them agrees within %.2f of the map%s"
              % (dungeons[mid]["name"], boss, n, a.spread, "" if a.accept_conflicts else " (left out)"))
    for mid, boss, n in outliers:
        print("  ignored %d far-off submission(s) for %s (%s): the others agree" % (n, boss, dungeons[mid]["name"]))
    for mid, boss, n in thin:
        print("  left out (needs %d players to agree, has %d): %s (%s)" % (a.min_agree, n, boss, dungeons[mid]["name"]))
    if a.explain:
        for (mid, boss), subs in sorted(by_boss.items()):
            got = result.get(mid, {}).get(boss)
            print("  %s / %s:" % (dungeons[mid]["name"], boss))
            for (m2, b2, who), sub in latest.items():
                if (m2, b2) == (mid, boss):
                    dist = "" if not got else "  %.2f from the result" % math.hypot(sub[1] - got[1], sub[2] - got[2])
                    print("      player %s: floor %d, %.4f, %.4f%s" % (who[:6] if len(who) == 6 else "(no code)", sub[0], sub[1], sub[2], dist))
            print("      -> " + ("%d, %.4f, %.4f" % got if got else "no pin"))
    if singles:
        print("  only one player so far: " + ", ".join("%s (%s)" % (b, dungeons[m]["name"]) for m, b in singles))
    if a.block:
        print("\n# Noobs Forever Dungeon Mapper boss pins")
        for mid in sorted(result):
            for boss in sorted(result[mid]):
                floor, x, y = result[mid][boss]
                print(canonical((mid, boss, floor, x, y), dungeons))
    if a.check:
        return
    os.makedirs(os.path.dirname(a.submissions), exist_ok=True)
    with open(a.submissions, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Every boss pin received, one line each (see tools/ingest_pins.py). Do not edit by hand.\n")
        fh.write("\n".join(everything) + ("\n" if everything else ""))
    write_lua(a.out, result, dungeons)
    print("wrote", os.path.relpath(a.out, ROOT))


if __name__ == "__main__":
    main()
