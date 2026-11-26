# Quest locations in dungeons: research (2026-11-25)

Guild request: "quest locations appear in dungeons". What exists, what doesn't, and the options.

## Findings

- **The game's tables have no quest positions inside dungeons.** `QuestPOIBlob` and `QuestPOIPoint` (quest
  objectives as points on a map, keyed by `MapID`; the instance's map ID is the dungeon's ID) were checked for
  the Forever client (build 1.60.1.70959) and Mists of Pandaria Classic (5.5.4.70268):
  - Forever: 57 blobs for 22 quests, all on the two continents (`MapID` 0 and 1), none in an instance.
  - MoP Classic: 512 blobs on 25 maps, none of them one of our 29 dungeons or raids.
  Vanilla-era quest positions simply aren't in the client files: the game gets them from the server.
- **Quest titles aren't in the client tables either** (the game asks the server). They are available at runtime
  for the quests in the player's log.
- **Questie** (GPL, so we can't copy its data) has no positions inside dungeons either: a boss is "somewhere in it"
  (OpenMap's architecture notes say the same).
- **At runtime the game does let an addon read the player's quest log.** In Forever's UI source
  (Blizzard_APIDocumentationGenerated, `forever` branch) these exist: `C_QuestLog.GetNumQuestLogEntries`,
  `GetInfo` (title, questID, whether a row is a zone header), `GetQuestObjectives` (objective text and progress),
  `GetTitleForQuestID`, `IsOnQuest`, `GetQuestTagInfo`, `IsQuestFlaggedCompleted`, `GetQuestsOnMap`. None are
  marked secret for untainted code. `GetQuestsOnMap` needs a UiMap, and Forever has no UiMaps for dungeons.

So there is **no data source for where in a dungeon a quest's objective is**, but we can know **which quests the
player has for this dungeon and how far along they are**.

## Options

1. **"My quests here" (runtime only, no new data).** In the dungeon window, list the player's quests that belong
   to this dungeon (found by the quest log's zone header, or by objective text naming the dungeon's bosses), with
   their objectives and progress. Where an objective names a boss ("Kill Edwin VanCleef"), put a quest marker on
   that boss's pin and row. Cheap, accurate, nothing to maintain, and useful for finding what to kill.
2. **Player-placed quest spots.** Extend the boss pin placer: players mark where a quest giver or objective is
   and share it, like boss pins. Slow to fill (about 100 quests), but it is the only way to get real positions.
3. **Questie integration.** Read Questie's database at runtime when it is installed (the way OpenMap does). Gives
   quest givers and zones, not positions inside dungeons, and only for people who run Questie.

## Recommendation

Build option 1 now (it answers "which quests are here and where do I kill/collect for them" for the common boss
objectives), then add option 2's quest-spot placing if the guild wants real positions for the rest.

Not verified in game: that the quest log rows are grouped under the dungeon's name in Forever, and how objective
text is worded. The first version should log what it finds (as the probe does) so we can tune the matching.

## Status

Option 1 is built (Quests.lua, the **Quests** button in the dungeon window). First version, untested in game: it
matches by the quest log's zone heading, by the dungeon's name in a quest's title, and by boss names in a title or
goal (names of at least 5 letters). With `/fd probe log` on it keeps the quest log it saw in
`NoobsForeverDungeonMapperDB.questScan`, so the matching can be tuned from real quest logs.
