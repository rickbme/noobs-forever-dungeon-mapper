# Plan: from Noobs Forever Dungeon Mapper to a world map addon

Draft, 2026-11-19. Reference: https://github.com/openmap-world/openmap (MIT, code only; Blizzard art excluded).

## Open question (decides everything below)

OpenMap is already a seamless world map for WoW Forever, with dungeon maps included. What will ours do
that OpenMap doesn't? Until that is answered, this plan assumes **our own addon that reuses OpenMap's
MIT code and data where it helps, with credit**, and keeping our edge: auto-open dungeon map, boss kill tracking,
floor guessing from sub-zone text. If the answer is "nothing", forking OpenMap and contributing
upstream is cheaper than rebuilding it.

## Rules (adopted in spirit from OpenMap's AGENTS.md; written as our own AGENTS.md in phase 0)

1. True to the game: Blizzard's art and Blizzard's tables only; credit anything drawn by players.
2. Generated files are generated (`Data/*.lua` come from `tools/gen_data.py`).
3. OpenMap's code, data tables and tools are MIT and we reuse them, crediting it (CREDITS.md, file headers).
   Not covered: Blizzard art and the player-drawn art (permission needs the artist). Other addons
   (perweum, Arcaneology) are GPL: study, don't copy.
4. No secrets or personal data in the repo; releases only with the maintainer's go-ahead.
5. Don't weaken the checks to pass a change.
6. Never touch Blizzard's `WorldMapFrame` (hooks break its OnShow on this client). Own window only.
7. Secret values: never compare or do arithmetic on them; go through `ns.Safe`.

## Phase 0: groundwork (done 2026-11-19 except publishing the release)

- Add `AGENTS.md` and `docs/development.md` (rules above, verify commands, in-game-check list).
- Add `.claude/settings.json` allow rules (handoff item 3).
- Add `.github/workflows/test.yml` (luac syntax check + harness) and a tag-triggered `release.yml`
  that builds `NoobsForeverDungeonMapper-<tag>.zip` with the folder at the zip root (handoff items 1-2).
- Add a lint script (single-backslash texture paths, tabs, no global leaks).
- Publish v0.1.0-beta after `gh auth login`.
- Baseline today: all `.lua` pass `luac5.1 -p`; harness runs on Lua 5.1.

## Phase 1: make the dungeon addon real (in game, on the gaming PC)

This is the riskiest gap: the addon has never run in the live game.
- Checklist from the handoff: window layout, pin alignment, minimap button, `ENCOUNTER_END`
  firing, live view, no errors with `/console scriptErrors 1`.
- Fix what breaks; extend the harness for each bug found.

## Phase 2: dungeons parity with OpenMap

- Maps for the 9 new Forever dungeons. Options: stitch WMO minimap tiles from the client, or use
  OpenMap's player-drawn art **only with the artists' permission** (they credit the drawer in game).
- Hand-placed pins for remade dungeons (Deadmines, RFC, Stockade, SM, Scholomance).
- Multi-language sub-zone matching for floor guessing; locale file scaffolding.

## Phase 3: world map (only if the open question justifies it)

- Standalone window, never hooking `WorldMapFrame`. Zones come from the 60 Forever UiMaps.
- Stitch zone art into a seamless continent view; pan and zoom; player pin via
  `C_Map.GetPlayerMapPosition` (works outdoors, blocked in instances).
- Dungeon entrances as pins that open our dungeon window.
- Data pipeline in `tools/` like `gen_data.py`, with `--verify` against the client.
- Options panel (Ace3 or plain frames: decide; Ace3 adds bundled libs and licences).

## Phase 4: polish

- Quest and loot notes, auto-hide in combat, minimap integration, CurseForge listing (manual approval only).

## Not decided / needs the user

- The differentiator vs OpenMap (above).
- Name: keep "Noobs Forever Dungeon Mapper" or rename once it is more than dungeons.
- Whether to ask OpenMap's maintainers about sharing data or art.

## Status 2026-11-19 (maps from the game's own files)

- Ported OpenMap's minimap pipeline (`tools/map-dungeons/minimap.py`, `tools/casc/casc.py`). It reads
  the local install (`OPENMAP_WOW`, needs `pip install pillow numpy scipy` in a venv).
- Built maps for The Hall of Thanes, Ruins of Lordaeron (2 floors) and City of Dalaran. They are wired in
  by `Data/Merge.lua`; dungeons with Blizzard tiles are untouched.
- **Blocked:** the WDT files for The Drowned City, Blackmaw Hold, Shaper's Terrace, Krol'dok Stronghold
  and Alcaz Prison are encrypted in the installed build, so they can't be built until Blizzard releases
  them (re-run the tool then). Excavation Site: Wetlands has data but no good crop yet.
- Not done: boss pins on the new maps, Dalaran's blank patches (rooms with no minimap picture).

## Status 2026-11-19 (later): Reyes' maps included

- His announcement allows addon use (non-commercial, credit and watermark kept). Ported OpenMap's
  `drawn.py`; `art/drawn/dungeons/` holds his 15 maps and `Data/DungeonDrawn.lua` the tiles (35 MB of TGA).
- `Data/Merge.lua` now prefers his maps, falling back to minimap-built floors. The window shows
  "Map by Santiago Reyes - sreyesmaps.com"; Dalaran's Underbelly floor opens by sub-zone.
- Eight of the nine new dungeons now have maps. **Alcaz Prison** still has none (he lists it as planned).
- Next: boss pins on the new maps (hand-placed, maybe via an editor like OpenMap's), pins for the remade
  classic dungeons from OpenMap's `DungeonBosses.lua`, then in-game testing, then the world map (Phase 3).
- Not included yet: his sea chart and gap paintings (need his OK for the world map), OpenMap's world map code.

## Status 2026-11-19 (later still): location anchors

- Idea: since coordinates are hidden in instances, mark where you are by sub-zone ("you are here" marker
  from `Data/Anchors.lua`), plus manual placement and an in-game placer later.
- Built: `/fd probe` (`Probe.lua`) to test the game's position APIs in a live dungeon; sub-zone names
  you enter are always recorded in `NoobsForeverDungeonMapperDB.seen`; the marker moves with the sub-zone and
  turns the map to that anchor's floor. Only The Hall of Thanes has anchors so far, and its three names
  are read from Reyes' map labels, not confirmed in game.
- Next: run the probe in game, fill `Data/Anchors.lua` from `seen`, then click-to-place "I'm here".

## Status 2026-11-19 (noob-friendly UI)

- `Options.lua`: Options window (checkboxes, window size +/-, clear kills, tester options), first-run welcome
  popup, entry in the game's Options > AddOns, key bindings (`Bindings.xml`). Map window has an Options
  button; the minimap right-click menu has Options and Welcome tips. Every slash command now has a button.
- Checkboxes are drawn from classic textures (no Blizzard templates), so they can't break loading. All of
  this is untested in the live client: check the look and the AddOns-list entry first.

## Status 2026-11-19 (boss pins)

- Imported OpenMap's boss pins (MIT, `Data/DungeonBosses.lua`): Deadmines, Stratholme, Razorfen Kraul and
  Onyxia gained pins (108 -> 118 of 242). Floor layouts match ours except Blackrock Spire and Dire Maul (skipped).
- OpenMap has no pins for Ragefire Chasm, Stockade, Scarlet Monastery, Scholomance, ZF, BFD, SFK and the new
  dungeons, so: built the in-game placer (`BossPlacer.lua`, Options > "Help map the bosses") and
  "Share my boss pins". Pins players send go into `Data/BossPlaces.lua`, which beats every other source.
- Cursor-to-map conversion in the placer is untested offline; check it in game first.

## Status 2026-11-19 (world map)

- `WorldMap.lua` + generated `Data/WorldMaps.lua` (`tools/map-world/build.py`): Azeroth, Eastern Kingdoms and
  Kalimdor from the Forever client's own continent art (12 tiles each, drawn by FileDataID), with all 29
  dungeon entrances (OpenMap's `Places.lua`, new dungeons converted from zone maps). Pins checked against
  rendered previews. Reached from the dungeon window, the minimap menu, Options, `/fd world` and a key binding.
- Not yet: zone maps (zoom into a zone), your own position on the continent while outdoors
  (`C_Map.GetPlayerMapPosition` works outside instances), entrances for raids (MC, BWL, ZG, AQ) as we have no raid data.
- Risk to check: OpenMap found some non-English clients draw the game's dungeon map tiles as solid green
  squares (their `Data/Forever/Tiles.lua` copies the tiles into the addon instead). Our dungeon maps from the
  client may hit this on those languages; the continent tiles could too. Tell us if players report it.

## Status 2026-11-20 (world map opens where you are)

- Outside a dungeon the minimap button / key opens the world map on the continent the player is on, with a green
  "you are here" marker (position from `C_Map.GetPlayerMapPosition` on the continent; refreshed twice a second).
  Option "Outside dungeons, open the world map where I am" (default on) turns it off. Inside a dungeon the button
  still opens the dungeon map; clicking an entrance on the world map opens that dungeon's map (already built).
- Unverified in game: that the game answers `GetBestMapForUnit` / `GetPlayerMapPosition` for continent IDs on Forever.

## Status 2026-11-25 (guild feedback, first round)

Feedback from guild testers, and what was done:

| Item | Status |
|---|---|
| Colour dungeon levels by difficulty for the character's level | **Done**: `ns.DifficultyColor` uses the game's quest-difficulty colours on the middle of the range; in the dungeon menu, window title and world-map tooltips. |
| Bug: killed bosses show on entering but not live during a run | **Hardened, root cause not confirmed.** The kill is now recorded before any drawing, and the drawing is protected (an error there used to be able to abort the handler before the kill was saved). The game's own boss progress (dungeon finder API, `GetLFGDungeonEncounterInfo`) is read on entering, on opening the map and 2 s after a kill, and only ever adds kills. Every boss event is logged (`encounterLog`, last 40) and `/fd probe` prints the game's progress. Needs a real run to confirm which path was failing. |
| Path/route through a dungeon | **v1 done**: lines join the bosses in order on each floor (option). They are straight lines (order, not walking path); a real path needs hand-placed waypoints, which the placer could be extended to collect. "Next boss" now says which floor it is on. |
| Bug: parts of the map greyed out when viewing outside the dungeon | **Not reproduced.** No desaturation or dimming exists in the code outside a dungeon. Needs a screenshot, the dungeon's name and the game language. Candidates: killed bosses shown grey from an old run, the "viewing only" text, or missing tiles on non-English clients (see the green-squares note). |
| Quest locations inside dungeons | **Researched, see [docs/quests-research.md](docs/quests-research.md): the game has no in-dungeon quest positions.** Questie has no in-dungeon positions. Possible source: the game's `QuestPOIBlob`/`QuestPOIPoint` tables (positions on UiMaps, which the dungeon floors already use) plus quest names, and the quest log API for state. Not started. |

## Status 2026-11-25 (floor switching)

- Bug fixed: boss pins from another floor stayed on screen after switching floors. Pins are indexed by boss
  number with gaps, and the hide loop used `ipairs`, which stops at the first gap. Now `pairs`. The harness
  switches through every floor of every multi-floor dungeon and fails if any pin from another floor is shown
  (it found 39 before the fix).

## Status 2026-11-25 (world map icons)

- The red circles on the world map are replaced by dungeon entrance icons: the game's own `Dungeon` / `Raid`
  atlas (as retail does) when `C_Texture.GetAtlasInfo` finds it, else our blue swirl (muted purple for raids),
  cut from a maintainer-supplied picture by `tools/make_icons.py`. Which one shows in the Forever client is
  unverified; the checklist asks the tester.

## Status 2026-11-25 (quest research)

- Researched quest locations: no data source exists for positions inside dungeons (client tables, MoP tables and
  Questie all lack them). The quest log API can list the player's own quests and objectives, so the plan is
  "my quests here" with quest markers on bosses named in objectives (docs/quests-research.md, option 1), then
  player-placed quest spots if wanted. Built the same day, see below.

## Status 2026-11-25 (my quests here)

- `Quests.lua` + the **Quests** button: the dungeon window can show the player's own quests for the dungeon with
  their goals, and a gold ! on bosses a quest names (pin and list). Matching is by the quest log's zone heading,
  the dungeon's name in the title, or boss names in a title or goal. Recorded to `questScan` when `/fd probe log`
  is on. Untested in game: how Forever files and words dungeon quests is exactly what the matching depends on.

## Status 2026-11-25 (world map zoom)

- The continent tabs on the world map are replaced by mouse wheel zoom (wheel up over a continent zooms in on it,
  wheel down zooms out; over the sea it picks the nearest continent) plus a visible *Zoom out* button and a hint line.
  Clicking a continent still works. The cursor-to-map conversion is untested in game (same maths as the pin placer).

## Status 2026-11-25 (options page, opacity)

- The page in the game's Options > AddOns now holds all our options (a canvas page filled by the same
  `BuildOptions` as our Options window, so the two agree), not just a button. New options: map opacity (both map
  windows, 30%-100%), Live view size, put the minimap button back, reset all options. Removed the glow that marked
  the last-viewed dungeon on the world map. Still custom widgets (no Blizzard `Settings.Create*` controls), so the
  look in the game's panel and whether two columns fit its canvas are unverified.

## Status 2026-11-25 (fade while moving)

- `Fade.lua`: while the player moves (`IsPlayerMoving`, or `GetUnitSpeed` above zero for rides) the dungeon and world map
  windows fade to `moveOpacity` (default 35%, never above the normal opacity) in about a quarter of a second, and
  back when they stop; a window the mouse is over stays solid. On by default (`moveFade`), options for both. Unverified
  in the game: that `IsPlayerMoving` / `GetUnitSpeed` answer for the player on Forever and aren't secret values.

## Status 2026-11-25 (odd squares on the Deadmines map)

- Guild report (vee, with screenshots): on the Deadmines floor 1 map some whole 256 px tiles are drawn bright and the
  rest darkened, in blocks ("the weird squares that are different colors"). This is almost certainly the earlier
  "greyed out parts" bug. Checked here: all 636 Blizzard tiles in `Dungeons.lua` exist in the enUS install and
  Deadmines floor 1 renders correctly from the files, so the cause is on that player's side (game language, graphics or
  texture settings, or another addon). Not yet understood.
- Added to `/fd probe`: game language and build, and whether the client finds each tile of the floor on screen
  (`C_Texture.GetTextureInfo`). Next: get vee's probe output and language; if tiles are "not found" the fix is OpenMap's
  (copy the tiles into the addon, `Media/Textures/MapTile`, as in its `Data/Forever/Tiles.lua`).

## Status 2026-11-25 (shaded map blocks: cause found)

- Screenshots from two players (Deadmines, Gnomeregan) show whole 256 px tiles drawn darker, in blocks, while the
  rest are normal; one Gnomeregan block was fully opaque art, so not the torn-paper transparency. Cause (likely): the
  canvas's dark backdrop (`SetBackdrop`, 60% black) and the 12 tile textures were all in the BACKGROUND layer at the
  same sublevel, and WoW gives no draw order between textures in the same layer and sublevel, so some tiles could be
  drawn before the backdrop and get dimmed by it. Fix: tiles are now ARTWORK sublevel -2 and the route lines ARTWORK
  sublevel 1, so the order is explicit (dungeon and world map). Replaces the earlier re-request guess (reverted).
- Unverified in game; the fix should make the block pattern disappear on every open and every dungeon.

## Status 2026-11-25 (Stockade has no boss pins)

- Reported: the Stormwind Stockade map shows no boss locations. Cause: a data gap, not a bug. No source has them: the
  Stockade's art is the Cataclysm/Mists remake (its three skull markers are the remake's bosses), and Forever's bosses are
  the classic five (Targorr the Dread, Kam Deepfury, Hamhock, Dextren Ward, Bazil Thredd), so OpenMap and the game's
  journal have none to match. Same for Ragefire Chasm, Scarlet Monastery, Scholomance and the new dungeons (the list
  of dungeons with unpinned bosses is in HANDOFF's pin notes). The map window now says why and how to add them.
- To fix properly: a player places the pins with Options > Help map the bosses and sends "Share my boss pins"; the lines
  go into `Data/BossPlaces.lua`.

## Status 2026-11-25 (skull boss pins)

- Boss pins on the dungeon map are now the game's skull (the raid target icon sheet, `UI-RaidTargetingIcons`, skull at
  texcoords 0.75-1, 0.25-0.5) tinted by state (red, gold next, grey killed) on a soft dark disc, with the boss number in the
  corner and a tick when defeated. Unverified in game: legibility on the parchment and that the icon sheet path is the same
  in the Forever client.

## Status 2026-11-25 (mapmaker mode: undo and editing)

- Problem: a wrong boss pin couldn't be undone, and in mapmaker mode a right-click ticked the boss as killed. Now: a
  toolbar (Undo, Remove pin, Done) shows over the map in mapmaker mode; Undo has a history of 40 changes (place, move,
  remove); pins can be dragged to move; right-click on your own pin removes it; kills can't be toggled while mapping
  (normal mode is unchanged). Your own pins have a blue ring and "Placed by you" in the tooltip. Untested in game: the
  drag (cursor maths is the same as placing).

## Status 2026-11-25 (asking players to map bosses)

- Two cards (one frame, `NoobsForeverDungeonMapperAsk`): on entering a dungeon with unpinned bosses ("Help map the
  bosses?", 4 s after arriving, once per dungeon per session, not in combat or over the welcome window), and after
  defeating a boss that has no pin ("click the map where you fought it", waits for combat to end, once per boss per
  session). Yes turns mapmaker mode on (and, after a kill, starts placing that boss). A "Don't ask me again" box and an
  Options switch (`askToMap`, default on) control both.
- Auto-placing the pin where the kill happened isn't possible with what we know: inside instances the game hides the
  player's position (`/fd probe` will confirm), and a sub-zone gives only an area (only the Hall of Thanes has anchors).
  If the probe shows `UnitPosition` works in a dungeon, a precise auto-pin becomes possible (world position -> floor
  needs each floor's UiMapAssignment bounds; not in our data yet).

## Status 2026-11-25 (collecting boss pins from the guild)

- Pipeline (docs/boss-pins.md): players Share -> paste `NFDM|...` lines in a guild-only Discord data channel ->
  the maintainer runs `tools/ingest_pins.py` (validates, takes the agreeing majority's median, flags conflicts, writes
  `Data/BossPlaces.lua` from `tools/pins/submissions.txt`) -> `--block` gives a block to pin in the channel that members
  paste into Options > Import guild pins (guild-only layer: fills gaps, own pins win, removable) -> later, public release.
- In the addon: exported lines now start with `NFDM|`; `Import guild pins` window; guild pins are stored in
  `guildPins`, shown with a purple ring.

## Status 2026-11-25 (sharing explained plainly)

- Decision: keep copy and paste as the way pins get from the game to the guild (`#addon-data`); no file reading or
  in-game sync for now. The Share and Import windows now spell out three plain steps and say nothing is sent
  automatically; placing a pin prints one short line, with the longer explanation only for the first pin of a session.
  The ask cards are unchanged (short, once per dungeon / boss, with a Don't ask me again box).

## Status 2026-11-25 (several dungeons before sharing)

- Pins were already kept per dungeon and boss across sessions and exported together. Added: a random contributor code on
  each line (`NFDM|...|code`), "sent" tracking (`sentPins`: new or moved pins only, Show all / I've sent these), pages that
  fit Discord's 2000-character message, and in `tools/ingest_pins.py` one opinion per contributor with the latest winning
  (submissions kept oldest first; a line sent again moves to the end). Docs: docs/boss-pins.md.

## Status 2026-11-25 (judging and withdrawing pins)

- A player can withdraw a pin they already sent: removing it adds a `NFDM|REMOVE|id|dungeon|boss|code` line to the next
  Share (cleared by "I've sent these"; a new pin for the boss cancels it). `tools/ingest_pins.py` applies withdrawals and
  gained `--explain`, `--min-agree N`, `--ignore SPEC` (tools/pins/ignore.txt). Redundancy rule: the agreeing majority wins,
  a boss nobody agrees on is left out, release publicly with `--min-agree 2`. See docs/boss-pins.md.
