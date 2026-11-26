# Noobs Forever Dungeon Mapper

A World of Warcraft: Forever addon from the **Noobs Forever** guild that opens the dungeon's map as soon as
you walk into a dungeon. It shows every floor, numbered boss pins, and which bosses you have already killed.
Work in progress (beta): it has not been tested in the live game yet.

- **Automatic**: zone into a dungeon and the map opens on the right floor. Leave and it closes.
- **Minimap button**: left-click shows or hides the map whenever you want it, so it never has to
  stay in your way. Right-click picks any dungeon, and dragging moves the button around the minimap.
  Close the map with the button, the X or Escape, and it stays closed until you enter the next dungeon.
- **Blizzard's own maps** for the 20 classic dungeons and Onyxia's Lair (53 floors). The Forever
  client has no dungeon maps of its own, but it still ships the old map textures. The addon draws
  them by file ID, so no artwork is bundled for these.
- **Maps for Forever's new dungeons**, drawn by [Santiago Reyes](https://sreyesmaps.com) (Atlas de Azeroth:
  Forever) and used with his permission, with his watermark and credit kept on the map. Dungeons without
  one use floors built from the game's own minimap pictures where the client has them.
- **Boss pins and progress**: 118 of the 242 bosses have pins on the map so far, and you can help place the rest (see below). Every boss is in the list beside it,
  in the game's order. Kills are picked up from the game's encounter events. The next boss pulses
  gold, killed bosses turn grey, and right-clicking a boss toggles it by hand.
- **Floor following**: the map turns to the floor named after the area you walk into, to the
  floor of a boss when you pull it, and to the floor of the next boss after a kill.
- **Live view (optional)**: enlarges the minimap while you are in a dungeon (see below).
- **Browse anywhere**: `/fd list` (or right-click in the addon compartment) opens any dungeon's map.
- **World map**: outside a dungeon, the minimap button opens the world map on the continent you are standing on,
  with a green marker where you are (the game only tells addons your position outdoors). Every dungeon and raid
  entrance is marked on it. Scroll the mouse wheel to zoom in on a continent and back out (or click a continent,
  or use the *Zoom out* button). In a dungeon, use the **World map** button (or the minimap button's right-click menu,
  or `/fd world`) to zoom out to Azeroth or either continent. Hover an entrance for levels and
  boss progress, click it to open that dungeon's map. The map art is the game's own, drawn from the client.
- **Difficulty colours**: dungeon levels are coloured like the game's quests, for your level (red too hard,
  orange, yellow about right, green easy, grey trivial).
- **Boss route**: lines join the bosses in order on each floor so you know where to go next (an option turns
  them off). They show the order, not the exact path to walk.
- **My quests here**: the **Quests** button switches the boss list to the quests in your quest log that belong to
  this dungeon, with their goals. A quest that names a boss puts a gold **!** on that boss. (The game has no
  data for where quest goals are inside dungeons, so this uses your own quest log; see
  [docs/quests-research.md](docs/quests-research.md).)
- **Options in the game's menu**: *Esc > Options > AddOns > Noobs Forever Dungeon Mapper* has every option
  (also from the map's *Options* button): what opens by itself, the boss-order lines, the minimap button, Live
  view and its size, window size, and **map opacity** to make the maps see-through, plus reset buttons.
- **No typing needed**: everything has a button. The map window has **Options** and **Dungeons**
  buttons, the minimap button's right-click menu lists every dungeon plus Options, and a short welcome
  popup explains the basics the first time you play. There is also an entry in the game's
  Options > AddOns list and a key binding (Options > Keybindings > AddOns). The slash commands below
  are optional shortcuts.

## "You are here"

Since patch 7.1, Blizzard blocks addons from reading the player's position inside instances:
`C_Map.GetPlayerMapPosition`, `UnitPosition` and `GetPlayerFacing` are expected to return nothing there
(`/fd probe` checks this in your client). So the addon never pretends to know exactly where you stand.
Instead, a blue marker shows the **area** you are in, from the sub-zone name, where we have mapped it.
It uses what the game does allow:

| Signal | What it gives you |
|---|---|
| `GetInstanceInfo()` | which dungeon you are in |
| `GetSubZoneText()` | the named area you stand in. Shown under the map, moves the "you are here" marker, and switches floors. |
| `ENCOUNTER_START` / `ENCOUNTER_END` | the boss you are fighting and kills, which mark your progress through the dungeon |
| the minimap | the game still draws your live position here. **Live view** enlarges it inside dungeons. |

Live view only changes the minimap's own scale, never Blizzard's Edit Mode container, and never
in combat. Your normal size comes back when you leave the dungeon. Turn it on with the
**Live view** button or `/fd live`.

## Install

**Players:** download the addon zip from the
[Releases page](https://github.com/rickbme/noobs-forever-dungeon-mapper/releases) (the file named
`NoobsForeverDungeonMapper-<version>.zip` under *Assets*). It contains only the addon and a short
`HOW-TO-INSTALL.txt`, nothing else.

> Don't use the green *Code > Download ZIP* button: that gives you the source code and tools, not the addon.

1. Close the game. Open the game's folder (the one that holds `_forever_`) and go into
   `_forever_\Interface\AddOns`. Delete any older `NoobsForeverDungeonMapper` or `ForeverDungeons` folder there.
2. Copy the `NoobsForeverDungeonMapper` folder from the zip into `AddOns`. Inside it you should see
   `NoobsForeverDungeonMapper.toc` straight away (not another folder).
3. Start the game and make sure *Noobs Forever Dungeon Mapper* is ticked in the AddOns list at the
   character screen. A full restart is needed the first time: it comes with new picture files.

**Developers:** clone the repository; the addon folder is `NoobsForeverDungeonMapper/`. Build the same zip
with `python3 -P tools/package.py v<version>`.

## Commands

| Command | |
|---|---|
| `/fd` (or `/nfdm`) | show or hide the map (current dungeon, or the last one viewed) |
| `/fd list` | pick any dungeon to view |
| `/fd world` | show or hide the world map |
| `/fd options` | open the options window |
| `/fd welcome` | show the welcome tips again |
| `/fd reset` | clear boss kills for the current dungeon (also done automatically when the game resets it) |
| `/fd auto` | toggle opening the map automatically |
| `/fd follow` | toggle turning to the next boss's floor after a kill |
| `/fd live` | toggle live view (enlarged minimap in dungeons) |
| `/fd button` | show or hide the minimap button |
| `/fd scale 1.2` | map window size, 0.5 to 2 |
| `/fd probe` | check which position data the game gives addons in a dungeon (`probe log` records sub-zone changes) |

## Coverage

| | Dungeons |
|---|---|
| Map + boss pins | Wailing Caverns, Shadowfang Keep (2 of 8 pinned), Blackfathom Deeps, Razorfen Kraul, Gnomeregan, Razorfen Downs, Uldaman, Zul'Farrak, Maraudon, Sunken Temple, Blackrock Depths, Dire Maul, Blackrock Spire, Stratholme |
| Map, boss list without pins | Ragefire Chasm, Deadmines, Stockade, Scarlet Monastery, Scholomance, Onyxia's Lair |
| Map by Santiago Reyes, boss list without pins | The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran (and The Underbelly), The Drowned City, Krol'dok Stronghold, Blackmaw Hold, The Shaper's Terrace |
| Boss list only (no map yet) | Alcaz Prison |

Pins are missing for bosses nobody has mapped yet, mostly in the remade dungeons (Ragefire Chasm, Stockade,
Scarlet Monastery, Scholomance and others) and in the new ones. Their only public positions belong to later
remakes with different layouts, so we place them by hand instead.

### Help map the bosses

Options > *Help map the bosses*: click a boss in the map's list, then click where it is on the map. Your pin
appears at once and is saved. *Share my boss pins* shows your pins as text to copy and send to us (for example
in the Noobs Forever Discord), and we add them for everyone.

## How the data is made

`NoobsForeverDungeonMapper/Data/Dungeons.lua` is generated by `tools/gen_data.py` from the public game-data
tables on [wago.tools](https://wago.tools):

- **Forever client** (latest `wowf` build): instance IDs and names, boss lists (`DungeonEncounter`), named areas (`AreaTable`).
- **Mists of Pandaria Classic client**: dungeon map definitions (`UiMap*`, `UiMapArtTile`) and
  boss pin positions (`JournalEncounter`). Pins are only kept when the boss name matches a Forever boss.

```bash
python3 tools/gen_data.py --verify
```

This regenerates the data after a game patch. `--verify` checks that every floor's map texture
exists in the current Forever build.

## Testing

```bash
lua5.1 tools/test/harness.lua
```

This runs the addon against a stub of the WoW API and plays through a dungeon run: entering,
floor changes, kills, wipes, secret values, reset messages, live view in and out of combat, and
leaving. It checks logic only; how the window looks has to be checked in game.

## Ideas for later

See [PLAN.md](PLAN.md). In short: boss pins for the new and remade dungeons, more "you are here" areas
(filled in from what the probe records in game), a click-to-place marker, quest and loot notes, and a
world map.

## Credits and research

- **[Santiago Reyes](https://sreyesmaps.com)**: the maps of Forever's new dungeons, from his project
  [Atlas de Azeroth: Forever](https://sreyesmaps.com/post/proyecto-atlas-de-azeroth-forever). Not covered
  by this repository's licence; used as his announcement allows. Thank you!
- **[OpenMap](https://github.com/openmap-world/openmap)** (MIT): this addon is modelled on it, and some of
  its tools are adapted here. See [CREDITS.md](CREDITS.md) for the details and the licence text.
- Map art and game data: Blizzard Entertainment, loaded from the game client (or cut from it, see
  `NoobsForeverDungeonMapper/Media/NOTICE.md`).
- Game data mirror: [wago.tools](https://wago.tools).
- API reference: [Warcraft Wiki](https://warcraft.wiki.gg) and Blizzard's UI source
  ([Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), `forever` branch).
- Approaches studied (no code copied; both are GPL): [Dungeon Crawler Forever](https://github.com/perweum/dungeon-crawler-forever)
  and [WoW Handbook](https://github.com/Arcaneology/WowHandbookAddon).

World of Warcraft is a trademark of Blizzard Entertainment. This project is not affiliated with Blizzard.
