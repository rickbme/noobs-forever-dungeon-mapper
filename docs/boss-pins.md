# Collecting boss pins from players

Many bosses have no pin yet (the Stockade, Ragefire Chasm, Scarlet Monastery, Scholomance, the new dungeons...).
Players who have run them know where the bosses are, so the addon lets them place pins and share them. This is
how those pins get from a player's game into everyone's.

## The short version

1. **A player places pins** in the game (Options > *Help map the bosses*, or the card that asks when they enter a
   dungeon or defeat a boss with no pin). They can map as many dungeons as they like before sharing: every pin is
   kept (per dungeon and boss) until they remove it. Then Options > **Share my boss pins**, Ctrl+A, Ctrl+C.
2. **They paste it in the guild's data channel** on Discord (`#addon-data`, open to everyone in the server).
   Each pin is one line: `NFDM|34|Stormwind Stockade|Hamhock|1|0.8000|0.4500`.
3. **The maintainer merges them** with `tools/ingest_pins.py`: it checks every line, takes the position most players
   agree on (the median of the agreeing group), flags disagreements, and writes `Data/BossPlaces.lua`.
4. **Everyone gets the result**, in two stages:
   - *Guild-only, straight away:* the maintainer pins the merged block in the channel (`--block`); members use
     Options > **Import guild pins** and paste it. It fills bosses that have no pin and never overrides a player's own
     pins. Nothing is released publicly.
   - *Public, when it is complete and checked:* `BossPlaces.lua` is committed and goes out in the next release.

## For the maintainer

Collect the pasted messages into a text file (or ask Claude to read the channel and gather the `NFDM|` lines), then:

```bash
python3 -P tools/ingest_pins.py --check pasted.txt        # report only: what is new, skipped, in conflict
python3 -P tools/ingest_pins.py pasted.txt                # add to tools/pins/submissions.txt and rebuild BossPlaces.lua
python3 -P tools/ingest_pins.py --block                   # print the merged pins as one block to pin in Discord
```

- `tools/pins/submissions.txt` is the record of every valid line received (no names), oldest first, so merging is
  repeatable: running the tool again with no files rebuilds `BossPlaces.lua` from it. A line received again moves to
  the end (latest wins).
- Bad lines are skipped with a reason (unknown dungeon or boss, a floor the dungeon doesn't have, a position off the
  map). Chat and Discord quoting around the lines is ignored.
- For each boss: the floor most players chose, then the largest group of positions within `--spread` (default 0.10 of
  the map) of one another. If that group is a majority its median is used and far-off submissions are ignored; if
  nobody agrees the boss is **left out** and listed as a CONFLICT (use `--accept-conflicts` to take the median anyway).
  A boss that only one player has placed is used but listed ("only one player so far"), so it is worth a second look.
- Then run the usual checks and commit `Data/BossPlaces.lua` and `tools/pins/submissions.txt` together.

## Several dungeons, several messages

- **One Share holds every dungeon.** The window offers the pins that are *new or moved since the player last marked
  them sent*; **Show all my pins** lists everything. After pasting in Discord the player presses **I've sent these**.
- **Discord's limit:** a message holds 2000 characters, about 25 pins. A long export is split into pages
  ("Message 1 of 3": paste each as its own message), with **< Previous** / **Next >**.
- **One player, one opinion:** each line ends with a random six-digit hex code made once per install (not a name; it
  says nothing about the player). The merge tool counts one pin per code per boss and the player's *latest* one
  replaces their earlier ones, so moving a pin and sending again doesn't make it look like two players agree.
  Lines without a code (older versions) each count as a separate anonymous player.

## Pin line format

`NFDM|<instance id>|<dungeon name>|<boss name>|<floor number>|<x 0..1 across>|<y 0..1 down>|<contributor code>`

x and y are fractions of the 1002 x 668 map picture, floor numbers are the floors as the addon lists them. The dungeon
name is only for people reading it: the id and the boss name are what counts.

## Why not automatic?

An addon can't send data out of the game, so the player copies and pastes. Pasting into Discord keeps it private to the
guild and lets the maintainer see disagreements before anything is released.
