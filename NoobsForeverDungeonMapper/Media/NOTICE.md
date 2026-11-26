# Where these textures come from

`Textures/MapDungeonMinimap/` is cut from World of Warcraft's own minimap pictures (Blizzard
Entertainment's art, not covered by this repo's MIT licence), laid out by
`tools/map-dungeons/minimap.py` from the game install. Rebuild it with that script; don't edit by hand.

`Textures/DungeonPortal.tga` and `DungeonPortalRaid.tga` (the world map's entrance icons, used when the game
has no icon of its own) are cut from `art/icons/dungeon-portal.png`, a picture supplied by the project
maintainer for this addon, by `tools/make_icons.py`. They are not Blizzard art.
