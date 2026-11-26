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
  player-placed quest spots if wanted. Nothing built yet.
