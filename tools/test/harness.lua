-- Offline test harness: loads the addon against a minimal stub of the WoW API and plays
-- through a dungeon run (enter, floor changes, boss kills, reset, leave).
-- Run from the repository root:  lua5.1 tools/test/harness.lua
-- This only checks the addon's own logic; it cannot show what the frames look like in game.

local ADDON = "NoobsForeverDungeonMapper"
local failures = 0
local out = print
local function check(cond, msg)
    if cond then out("  ok   " .. msg) else failures = failures + 1; out("  FAIL " .. msg) end
end

-------------------------------------------------------------------------------
-- WoW API stubs
-------------------------------------------------------------------------------
local game = { inInstance = false, instanceID = nil, instanceType = "none", subzone = "", combat = false, minimapScale = 1 }
local printed = {}

local realPrint = print
_G.print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(t, " ")
end

local function noop() end
local widgetMeta
local function NewWidget()
    local w = { shown = true, scripts = {}, points = {}, text = "", events = {} }
    return setmetatable(w, widgetMeta)
end
widgetMeta = {
    __index = function(self, k)
        local methods = {
            Show = function(s) s.shown = true end,
            Hide = function(s) s.shown = false end,
            IsShown = function(s) return s.shown end,
            SetShown = function(s, v) s.shown = not not v end,
            SetAlpha = function(s, a) s.alpha = a end,
            IsMouseOver = function(s) return rawget(s, "hovered") or false end,
            GetAlpha = function(s) return rawget(s, "alpha") or 1 end,
            SetScript = function(s, n, fn) s.scripts[n] = fn end,
            GetScript = function(s, n) return s.scripts[n] end,
            SetText = function(s, t) s.text = t end,
            GetText = function(s) return s.text end,
            SetTexture = function(s, t) s.texture = t end,
            SetEnabled = function(s, v)
                assert(type(v) == "boolean", "SetEnabled needs a boolean")
                s.enabled = v
            end,
            SetScale = function(s, v) s.scale = v end,
            GetScale = function(s) return rawget(s, "scale") or 1 end,
            GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
            GetFrameLevel = function() return 1 end,
            GetWidth = function() return 140 end,
            GetCenter = function() return 100, 100 end,
            GetEffectiveScale = function() return 1 end,
            CreateTexture = function(_, _, layer, _, sub) local w = NewWidget(); w.layer, w.subLevel = layer, sub return w end,
            CreateLine = function(_, _, layer, _, sub) local w = NewWidget(); w.layer, w.subLevel = layer, sub return w end,
            SetAtlas = function(s, a) s.atlas = a end,
            CreateFontString = function() return NewWidget() end,
            CreateMaskTexture = function() return NewWidget() end,
            CreateAnimationGroup = function() return NewWidget() end,
            CreateAnimation = function() return NewWidget() end,
            RegisterEvent = function(s, e) s.events[e] = true end,
            UnregisterEvent = function(s, e) s.events[e] = nil end,
        }
        return methods[k] or noop
    end,
}

local eventFrames = {}
function CreateFrame(kind, name)
    local w = NewWidget()
    if kind == "Frame" and not name then eventFrames[#eventFrames + 1] = w end
    if name then _G[name] = w end
    return w
end
UIParent = NewWidget()
GameTooltip = NewWidget()
GameTooltip_Hide = noop
Minimap = NewWidget()
UISpecialFrames = {}
tinsert = table.insert
-- the game's Options > AddOns registration: keep the page so the tests can look at it
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) game.settingsPanel, game.settingsName = panel, name return {} end,
    RegisterAddOnCategory = function() end,
}
SlashCmdList = {}
INSTANCE_RESET_SUCCESS = "%s has been reset."
issecretvalue = function(v) return type(v) == "table" and v.secret end
function IsInInstance() return game.inInstance, game.instanceType end
function GetInstanceInfo()
    return game.instanceName or "Azeroth", game.instanceType, 1, "Normal", 5, 0, false, game.instanceID, 5, game.lfgID
end
-- the dungeon finder's boss progress for the dungeon we are in: game.lfgBosses = { { name, killed }, ... }
function GetLFGDungeonNumEncounters(id) return game.lfgBosses and #game.lfgBosses or 0 end
function GetLFGDungeonEncounterInfo(id, i)
    local b = game.lfgBosses[i]
    return b[1], 0, b[2]
end
function UnitLevel() return game.level or 20 end
function GetQuestDifficultyColor(l)
    local d = l - (game.level or 20)
    if d >= 5 then return { r = 1, g = 0.1, b = 0.1 } end
    if d >= -2 then return { r = 1, g = 1, b = 0 } end
    return { r = 0.5, g = 0.5, b = 0.5 }
end
function GetSubZoneText() return game.subzone end
function GetZoneText() return game.instanceName or "Azeroth" end
function GetRealZoneText() return game.instanceName or "Azeroth" end
function GetMinimapZoneText() return game.subzone end
function IsIndoors() return true end
function GetUnitSpeed() return game.speed or 0, 7, 7, 4.7 end
function IsPlayerMoving() return game.moving end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70959", "Nov 1 2026", 160001 end
function UnitPosition() return nil end
function GetPlayerFacing() return nil end
-- a tiny map tree: Elwynn Forest (1429) is in the Eastern Kingdoms (1415), Durotar (1411) in Kalimdor (1414)
local mapParent = { [1429] = 1415, [1411] = 1414, [1415] = 947, [1414] = 947 }
C_Map = {
    GetBestMapForUnit = function() return game.mapID end,
    GetMapInfo = function(id) return { parentMapID = mapParent[id] or 0 } end,
    GetPlayerMapPosition = function(id)
        if game.pos and id == game.posMap then
            return { GetXY = function() return game.pos[1], game.pos[2] end }
        end
    end,
}
function InCombatLockdown() return game.combat end
local cursor = { 0, 0 }
function GetCursorPosition() return cursor[1], cursor[2] end
time = os.time

local function Fire(event, ...)
    for _, fr in ipairs(eventFrames) do
        if fr.events and fr.events[event] and fr.scripts.OnEvent then fr.scripts.OnEvent(fr, event, ...) end
    end
end

-------------------------------------------------------------------------------
-- Load the addon like the client does: each file gets (addonName, namespace)
-------------------------------------------------------------------------------
local ns = {}
for _, file in ipairs({ "Data/Dungeons.lua", "Data/DungeonDrawn.lua", "Data/DungeonMinimap.lua", "Data/WorldMaps.lua", "Data/DungeonBosses.lua", "Data/BossPlaces.lua", "Data/Merge.lua", "Data/Anchors.lua", "Core.lua", "Probe.lua", "BossPlacer.lua", "MapFrame.lua", "LiveView.lua", "MinimapButton.lua", "WorldMap.lua", "Quests.lua", "Fade.lua", "Options.lua" }) do
    local chunk = assert(loadfile("NoobsForeverDungeonMapper/" .. file))
    chunk(ADDON, ns)
end
Fire("ADDON_LOADED", ADDON)

realPrint("Data")
local n = 0
for id, d in pairs(ns.Dungeons) do
    n = n + 1
    for _, f in ipairs(d.floors) do
        check(#f.tiles == 12, d.name .. " / " .. f.name .. " has 12 tiles")
    end
    for _, b in ipairs(d.bosses) do
        if b.floor then
            check(d.floors[b.floor] and b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1,
                d.name .. " / " .. b.name .. " pin is on a real floor and inside the map")
        end
    end
end
check(n == #ns.DungeonOrder, "every dungeon is in DungeonOrder")
-- every dungeon the game has no map for gets floors from Reyes' drawings or the minimap data,
-- except the ones that are still encrypted in the client
for _, id in ipairs({ 3065, 2999, 2959, 2998, 2970, 3039, 2974, 3001 }) do
    local d = ns.Dungeons[id]
    check(#d.floors > 0, d.name .. " has floors")
    check(d.floors[1] and d.floors[1].credit == "Santiago Reyes", d.name .. " uses the drawn map and credits the artist")
end
check(#ns.Dungeons[2994].floors == 0, "Alcaz Prison has no art yet")
for id, d in pairs(ns.Dungeons) do
    for _, f in ipairs(d.floors) do
        for _, t in ipairs(f.tiles) do
            if type(t) == "string" then
                local path = t:gsub("^Interface\\AddOns\\", ""):gsub("\\", "/") .. ".tga"
                local fh = io.open("./" .. path)
                check(fh ~= nil, "tile exists: " .. path)
                if fh then fh:close() end
            end
        end
    end
end

realPrint("Minimap button")
local mb = NoobsForeverDungeonMapperMinimapButton
check(mb and mb:IsShown(), "minimap button is created and shown")
cursor[1], cursor[2] = 100, 200 -- straight above the minimap centre
mb.scripts.OnDragStart(mb)
mb.scripts.OnUpdate(mb)
mb.scripts.OnDragStop(mb)
check(math.abs(ns.db.minimapAngle - 90) < 0.01, "dragging moves the button (angle 90)")
check(mb.scripts.OnUpdate == nil, "dragging stops on release")

realPrint("Entering Blackfathom Deeps")
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 48, "Blackfathom Deeps"
Fire("PLAYER_ENTERING_WORLD")
check(NoobsForeverDungeonMapperFrame and NoobsForeverDungeonMapperFrame:IsShown(), "map opens automatically")
check(ns.ViewedInstance() == 48, "map shows Blackfathom Deeps")
check(NoobsForeverDungeonMapperFrame.title.text == "Blackfathom Deeps", "title is the dungeon name")
check(NoobsForeverDungeonMapperFrame.tiles[1].texture == ns.Dungeons[48].floors[1].tiles[1], "first floor tiles are drawn")

realPrint("Walking into a named area that is also a floor")
game.subzone = "Moonshrine Sanctum"
Fire("ZONE_CHANGED_INDOORS")
check(NoobsForeverDungeonMapperFrame.tiles[1].texture == ns.Dungeons[48].floors[2].tiles[1], "floor follows the sub-zone")
check(NoobsForeverDungeonMapperFrame.location.text:find("Moonshrine Sanctum", 1, true), "location line shows the area")

realPrint("Killing the first boss")
local first = ns.Dungeons[48].bosses[1]
Fire("ENCOUNTER_START", first.id, first.name, 1, 5)
check(NoobsForeverDungeonMapperFrame.location.text:find("Fighting", 1, true), "location line shows the fight")
Fire("ENCOUNTER_END", first.id, first.name, 1, 5, 1)
check(ns.IsKilled(48, first), "boss is marked killed")
check(select(1, ns.KillCount(48)) == 1, "kill count is 1")
check(ns.NextBoss(48) == ns.Dungeons[48].bosses[2], "next boss advances")
check(NoobsForeverDungeonMapperFrame.subtitle.text:find("1/" .. #ns.Dungeons[48].bosses, 1, true), "subtitle shows progress")

realPrint("A wipe does not count as a kill")
local second = ns.Dungeons[48].bosses[2]
Fire("ENCOUNTER_END", second.id, second.name, 1, 5, 0)
check(not ns.IsKilled(48, second), "wipe leaves the boss alive")

realPrint("Secret values are ignored, the name still matches")
Fire("ENCOUNTER_END", { secret = true }, second.name, 1, 5, 1)
check(ns.IsKilled(48, second), "kill found by name when the ID is secret")
Fire("ENCOUNTER_END", { secret = true }, { secret = true }, 1, 5, { secret = true })
check(select(1, ns.KillCount(48)) == 2, "fully secret payload changes nothing")

realPrint("BOSS_KILL after ENCOUNTER_END does not double count")
Fire("BOSS_KILL", second.id, second.name)
check(select(1, ns.KillCount(48)) == 2, "still 2 kills")

realPrint("Instance reset message")
Fire("CHAT_MSG_SYSTEM", "Blackfathom Deeps has been reset.")
check(select(1, ns.KillCount(48)) == 0, "kills cleared by the reset message")

realPrint("Live view")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("live")
check(Minimap:GetScale() == ns.db.liveScale, "minimap enlarged inside the dungeon")
game.combat = true

realPrint("Leaving the dungeon in combat")
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.subzone = false, "none", nil, nil, ""
Fire("PLAYER_ENTERING_WORLD")
check(not NoobsForeverDungeonMapperFrame:IsShown(), "map closes on leaving")
check(Minimap:GetScale() == ns.db.liveScale, "minimap left alone during combat")
game.combat = false
Fire("PLAYER_REGEN_ENABLED")
check(Minimap:GetScale() == 1, "minimap restored after combat")

realPrint("Slash command opens the last dungeon outside (world map first turned off)")
ns.db.worldFirst = false
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("")
check(NoobsForeverDungeonMapperFrame:IsShown() and ns.ViewedInstance() == 48, "/fd reopens the last viewed dungeon")
check(NoobsForeverDungeonMapperFrame.location.text:find("Viewing only", 1, true), "outside, the map says it is only a preview")

realPrint("Minimap button toggles the map")
mb.scripts.OnClick(mb, "LeftButton")
check(not NoobsForeverDungeonMapperFrame:IsShown(), "click hides the map")
mb.scripts.OnClick(mb, "LeftButton")
check(NoobsForeverDungeonMapperFrame:IsShown(), "click shows it again")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("button")
check(not mb:IsShown(), "/fd button hides the button")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("button")
check(mb:IsShown(), "/fd button shows it again")
ns.db.worldFirst = true
ns.HideMap()

realPrint("Entrance icons on the world map")
ns.ShowWorldMap(1415)
local iconPin, raidPin
for _, p in ipairs(NoobsForeverDungeonMapperWorld.pins) do
    if p:IsShown() then
        local raidOnly = true
        for _, inst in ipairs(p.instances) do if not inst[3] then raidOnly = false end end
        if raidOnly then raidPin = raidPin or p else iconPin = iconPin or p end
    end
end
check(iconPin and iconPin.icon.texture and iconPin.icon.texture:find("DungeonPortal", 1, true), "a dungeon entrance uses the swirl icon when the game has none")
check(raidPin == nil or raidPin.icon.texture:find("DungeonPortalRaid", 1, true), "a raid-only entrance uses the raid icon")
C_Texture = { GetAtlasInfo = function(name) return name == "Dungeon" or name == "Raid" end }
ns.ShowWorldMap(1415)
check(iconPin.icon.atlas == "Dungeon", "the game's own Dungeon icon is used when this client has it")
C_Texture = nil
ns.HideWorldMap()

realPrint("The mouse wheel zooms the world map")
ns.ShowWorldMap(947)
local zw = NoobsForeverDungeonMapperWorld
check(not zw.zoomOut:IsShown(), "no Zoom out button on the world map itself")
ns.WorldZoom(1, 0.72, 0.40)
check(zw.title:GetText() == "Eastern Kingdoms", "wheel up over the Eastern Kingdoms zooms in on them")
check(zw.zoomOut:IsShown(), "the Zoom out button shows on a continent")
ns.WorldZoom(1, 0.20, 0.50)
check(zw.title:GetText() == "Eastern Kingdoms", "wheel up on a continent does nothing more")
ns.WorldZoom(-1)
check(zw.title:GetText() == "Azeroth", "wheel down zooms back out")
ns.WorldZoom(-1)
check(zw.title:GetText() == "Azeroth", "wheel down on the world map does nothing")
ns.WorldZoom(1, 0.20, 0.50)
check(zw.title:GetText() == "Kalimdor", "wheel up over Kalimdor zooms in on it")
ns.WorldZoom(-1)
ns.WorldZoom(1, 0.46, 0.50)
check(zw.title:GetText() == "Kalimdor", "wheel up over the sea picks the nearest continent")
zw.zoomOut.scripts.OnClick()
check(zw.title:GetText() == "Azeroth", "the Zoom out button zooms out")
zw.scripts.OnMouseWheel(zw, 1)
check(zw.title:GetText() ~= "Azeroth", "the wheel works on the window even without a cursor position")
zw.scripts.OnMouseWheel(zw, -1)
check(zw.title:GetText() == "Azeroth", "and zooms back out")
ns.HideWorldMap()

realPrint("The map button opens the world map where the player is")
local world2
ns.HideMap(); ns.HideWorldMap()
game.mapID, game.posMap, game.pos = 1429, 1415, { 0.5, 0.4 }
mb.scripts.OnClick(mb, "LeftButton")
world2 = NoobsForeverDungeonMapperWorld
check(world2:IsShown() and world2.title:GetText() == "Eastern Kingdoms", "outside, the button opens the continent the player is on")
check(world2.me:IsShown(), "a marker shows where the player stands")
world2.scripts.OnUpdate(world2, 1)
check(world2.me:IsShown(), "the marker stays after an update")
mb.scripts.OnClick(mb, "LeftButton")
check(not world2:IsShown(), "pressing the button again hides the world map")
game.mapID, game.posMap, game.pos = 1411, 1414, { 0.3, 0.6 }
mb.scripts.OnClick(mb, "LeftButton")
check(world2.title:GetText() == "Kalimdor", "in Durotar it opens Kalimdor")
ns.ShowWorldMap(947)
check(world2.me:IsShown(), "the marker also shows on the world map")
ns.ShowWorldMap(1415)
check(not world2.me:IsShown(), "no marker on a continent the player isn't on")
game.pos = nil
ns.ShowWorldMap(1414)
check(not world2.me:IsShown(), "no marker when the game gives no position")
world2.back.scripts.OnClick()
check(not world2:IsShown() and NoobsForeverDungeonMapperFrame:IsShown(), "the Dungeon map button goes back to a dungeon")
ns.HideMap()
ns.db.worldFirst = false
mb.scripts.OnClick(mb, "LeftButton")
check(not world2:IsShown() and NoobsForeverDungeonMapperFrame:IsShown(), "with the option off, the button opens the last dungeon")
ns.db.worldFirst = true
ns.HideMap()
game.mapID, game.pos = nil, nil
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 389, "Ragefire Chasm"
Fire("PLAYER_ENTERING_WORLD")
ns.HideMap()
mb.scripts.OnClick(mb, "LeftButton")
check(NoobsForeverDungeonMapperFrame:IsShown() and not world2:IsShown(), "inside a dungeon, the button opens the dungeon's map")
game.inInstance, game.instanceType, game.instanceID, game.instanceName = false, "none", nil, nil
Fire("PLAYER_ENTERING_WORLD")
ns.HideMap()

realPrint("A new Forever dungeon without art")
ns.ShowDungeon(2994)
check(NoobsForeverDungeonMapperFrame.noArt:IsShown(), "no-art message shows")
check(not NoobsForeverDungeonMapperFrame.tiles[1]:IsShown(), "no tiles drawn")

realPrint("A new Forever dungeon with a drawn map shows the credit")
ns.ShowDungeon(3065)
check(not NoobsForeverDungeonMapperFrame.noArt:IsShown(), "no no-art message")
check(NoobsForeverDungeonMapperFrame.tiles[1]:IsShown(), "tiles drawn")
check(NoobsForeverDungeonMapperFrame.credit:GetText():find("Santiago Reyes", 1, true), "artist is credited on the map")


realPrint("You-are-here marker follows the sub-zone")
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 3065, "The Hall of Thanes"
game.subzone = "Dark Iron Ingress"
Fire("PLAYER_ENTERING_WORLD")
local here = NoobsForeverDungeonMapperFrame.here
check(here:IsShown(), "marker shows in a known area")
check(here.anchor and here.anchor.sub == "Dark Iron Ingress", "marker uses that area's anchor")
game.subzone = "Somewhere Unlisted"
Fire("ZONE_CHANGED_INDOORS")
check(not here:IsShown(), "marker hides in an area with no anchor")
check(ns.db.seen[3065]["Somewhere Unlisted"] == 1, "the new sub-zone name is recorded")

realPrint("Probe")
printed = {}
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe")
local joined = table.concat(printed, "\n")
check(joined:find("UnitPosition = nil", 1, true), "probe reports a blocked API as nil")
check(joined:find("only sub-zone anchors", 1, true), "probe says no position API answered")
check(ns.db.probe.last and ns.db.probe.last.anyPosition == false, "probe result is saved")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe log")
game.subzone = "Anvilmar's Rest"
Fire("ZONE_CHANGED_INDOORS")
check(#ns.db.probe.log == 1 and ns.db.probe.log[1].sub == "Anvilmar's Rest", "probe log records a sub-zone change")
UnitPosition = function() return 10, 20, 30, 40 end
game.subzone = "Reliquary of Kings"
Fire("ZONE_CHANGED_INDOORS")
check(ns.db.probe.log[2].anyPosition == true, "probe log notices when a position API answers")
UnitPosition = function() return nil end
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe clear")
check(ns.db.probe == nil, "probe clear forgets results")
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.subzone = false, "none", nil, nil, ""
Fire("PLAYER_ENTERING_WORLD")

realPrint("Options, welcome popup and key binding")
local welcomeFrame = NoobsForeverDungeonMapperWelcome
check(welcomeFrame and welcomeFrame:IsShown(), "the welcome popup showed on first run")
welcomeFrame.scripts.OnHide(welcomeFrame)
check(ns.db.welcomed == true, "closing the welcome popup is remembered")
NoobsForeverDungeonMapperWelcome:Hide()
ns.OpenOptions()
local optFrame = NoobsForeverDungeonMapperOptions
check(optFrame:IsShown(), "options window opens without a command argument")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("options")
check(not optFrame:IsShown(), "/fd options toggles it")
ns.OpenOptions()
ns.db.autoOpen = true
NoobsForeverDungeonMapper_Binding("options")
check(not optFrame:IsShown(), "the options key binding toggles the window")
NoobsForeverDungeonMapper_Binding("toggle")
NoobsForeverDungeonMapper_Binding("toggle")
check(BINDING_NAME_NOOBSFOREVERDUNGEONMAPPER_TOGGLE ~= nil, "key binding has a name")
ns.db.scale = 1
ns.OpenOptions()
local scaleStep = optFrame.parts.steppers.scale
check(scaleStep.value:GetText() == "100%", "window size shows as a percentage")
scaleStep.plus.scripts.OnClick()
check(ns.db.scale == 1.1 and scaleStep.value:GetText() == "110%", "+ makes the window bigger")
for i = 1, 30 do scaleStep.plus.scripts.OnClick() end
check(ns.db.scale == 2, "size stops at 200%")
ns.db.scale = 1
ns.ApplyScale()

realPrint("Options page in the game's Options > AddOns, opacity and the other options")
check(game.settingsPanel and game.settingsName == "Noobs Forever Dungeon Mapper", "the addon registers a page in the game's Options")
local page = game.settingsPanel
check(page.parts and page.parts.steppers.opacity and page.parts.steppers.scale, "the page has the same options as our window")
ns.db.opacity = 1
ns.OptionsRefresh()
local opStep = page.parts.steppers.opacity
check(opStep.value:GetText() == "100%", "opacity starts solid")
opStep.minus.scripts.OnClick()
check(ns.db.opacity == 0.9 and opStep.value:GetText() == "90%", "the page's - makes the map more see-through")
check(optFrame.parts.steppers.opacity.value:GetText() == "90%", "our window shows the same value")
ns.ShowDungeon(48, 1)
check(NoobsForeverDungeonMapperFrame:GetAlpha() == 0.9, "the dungeon map window is see-through")
ns.ShowWorldMap(1415)
check(NoobsForeverDungeonMapperWorld:GetAlpha() == 0.9, "the world map window is see-through")
for i = 1, 20 do opStep.minus.scripts.OnClick() end
check(ns.db.opacity == 0.3, "opacity stops at 30%")
for i = 1, 20 do opStep.plus.scripts.OnClick() end
check(ns.db.opacity == 1 and NoobsForeverDungeonMapperFrame:GetAlpha() == 1, "and goes back to solid")
ns.HideWorldMap()
ns.HideMap()
local liveStep = optFrame.parts.steppers.liveScale
liveStep.plus.scripts.OnClick()
check(ns.db.liveScale == 2, "the Live view size can be changed (1.8 -> 2.0)")
check(rawget(NoobsForeverDungeonMapperWorld.pins[1], "glow") == nil, "no highlight glow on the world map's entrances")
ns.db.minimapAngle = 90
ns.db.minimapButton = false
ns.MinimapButton_Reset()
check(ns.db.minimapAngle == 200 and ns.db.minimapButton == true, "the minimap button can be put back")
ns.db.autoOpen, ns.db.route, ns.db.worldFirst, ns.db.scale, ns.db.opacity, ns.db.placer = false, false, false, 1.5, 0.5, true
optFrame.parts.resetAll.scripts.OnClick()
check(ns.db.autoOpen == true and ns.db.route == true and ns.db.worldFirst == true and ns.db.scale == 1
    and ns.db.opacity == 1 and ns.db.placer == false and ns.db.liveScale == 1.8, "Reset puts every option back to normal")
check(ns.db.runs ~= nil and ns.db.bossPlaces ~= nil, "Reset keeps kills and placed pins")

ns.db.welcomed = false
Fire("PLAYER_ENTERING_WORLD")
check(NoobsForeverDungeonMapperWelcome:IsShown(), "welcome shows when it was never dismissed")
NoobsForeverDungeonMapperWelcome:Hide()

realPrint("Kills are recorded even if the drawing breaks, and the game's progress fills gaps")
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.lfgID = true, "party", 48, "Blackfathom Deeps", 99
game.lfgBosses = nil
Fire("PLAYER_ENTERING_WORLD")
ns.ResetRun(48)
local bfd = ns.Dungeons[48]
local realRefresh = ns.Refresh
ns.Refresh = function() error("simulated drawing error") end
Fire("ENCOUNTER_END", bfd.bosses[1].id, bfd.bosses[1].name, 1, 5, 1)
ns.Refresh = realRefresh
check(ns.IsKilled(48, bfd.bosses[1]), "the kill is recorded although drawing failed")
local last = ns.db.encounterLog[#ns.db.encounterLog]
check(last.kind == "end" and last.matched == bfd.bosses[1].name and last.success == "1.0000", "the encounter is logged with the match")
Fire("ENCOUNTER_END", 424242, "Some Unknown Boss", 1, 5, 1)
check(ns.db.encounterLog[#ns.db.encounterLog].matched == "NO MATCH", "an unmatched encounter is logged as NO MATCH")
game.lfgBosses = { { bfd.bosses[1].name, false }, { bfd.bosses[2].name, true } }
ns.SyncKillsFromGame(48)
check(ns.IsKilled(48, bfd.bosses[2]), "a kill the game reports is picked up")
check(ns.IsKilled(48, bfd.bosses[1]), "a kill we know of is not cleared when the game says up")
game.lfgBosses = nil
ns.SyncKillsFromGame(48)
check(ns.IsKilled(48, bfd.bosses[2]), "no game progress leaves kills alone")
ns.ResetRun(48)
game.lfgBosses = { { bfd.bosses[3].name, true } }
Fire("PLAYER_ENTERING_WORLD")
ns.ShowDungeon(48)
check(ns.IsKilled(48, bfd.bosses[3]), "opening the map in a dungeon syncs the game's progress")
game.lfgBosses = nil
ns.ResetRun(48)
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.lfgID = false, "none", nil, nil, nil
Fire("PLAYER_ENTERING_WORLD")
ns.HideMap()

realPrint("Level colours follow the difficulty for the player's level")
game.level = 20
check(ns.DifficultyColor(17, 26) == "|cffffff00", "a dungeon around your level is yellow")
check(ns.DifficultyColor(55, 60) == "|cffff1a1a", "a dungeon far above you is red")
check(ns.DifficultyColor(5, 9) == "|cff808080", "a dungeon far below you is grey")
check(ns.LevelsColored(17, 26) == "|cffffff0017-26|r" and ns.LevelsColored(60, 60):find("60|r", 1, true), "levels are coloured text")

realPrint("Switching floors clears the old floor's markers")
local stale = 0
for id, d in pairs(ns.Dungeons) do
    if #d.floors > 1 then
        local order = {}
        for fl = 1, #d.floors do order[#order + 1] = fl end
        for fl = #d.floors - 1, 1, -1 do order[#order + 1] = fl end
        for _, fl in ipairs(order) do
            ns.ShowDungeon(id, fl)
            for _, p in pairs(NoobsForeverDungeonMapperFrame.pins) do
                if p:IsShown() and p.boss.floor ~= fl then stale = stale + 1 end
            end
        end
    end
end
check(stale == 0, "no boss pin from another floor stays on screen (" .. stale .. " stale)")
ns.HideMap()

realPrint("The boss order is drawn as lines")
ns.db.route = true
ns.ShowDungeon(48, 1)
local routeFrame = NoobsForeverDungeonMapperFrame
local shown = 0
for _, l in ipairs(routeFrame.routeLines) do if l:IsShown() then shown = shown + 1 end end
check(shown > 0, "lines join the bosses of a floor that has pinned bosses")
ns.db.route = false
ns.Refresh()
shown = 0
for _, l in ipairs(routeFrame.routeLines) do if l:IsShown() then shown = shown + 1 end end
check(shown == 0, "the lines go away when the option is off")
ns.db.route = true
ns.HideMap()

realPrint("My quests here")
local realQuestLog = C_QuestLog
C_QuestLog = nil
check(#ns.QuestsFor(36) == 0, "no quest log API: no quests, no error")
local log = {
    { header = "Westfall" },
    { title = "The Defias Brotherhood", id = 100, level = 20, obj = { { "Edwin VanCleef slain: 0/1", false } } },
    { title = "Unrelated Errand", id = 102, level = 5, obj = { { "Gather 5 apples: 2/5", false } } },
    { header = "The Deadmines" },
    { title = "Collect Red Silk Bandanas", id = 101, level = 18, obj = { { "Red Silk Bandana: 3/3", true } } },
    { title = "Hidden Quest About Edwin VanCleef", id = 103, level = 18, hidden = true, obj = {} },
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, #log end,
    GetInfo = function(i)
        local e = log[i]
        return { title = e.title or e.header, questID = e.id, isHeader = e.header ~= nil, level = e.level, isHidden = e.hidden }
    end,
    GetQuestObjectives = function(id)
        for _, e in ipairs(log) do
            if e.id == id then
                local out = {}
                for _, o in ipairs(e.obj or {}) do out[#out + 1] = { text = o[1], finished = o[2] } end
                return out
            end
        end
    end,
}
local quests = ns.QuestsFor(36)
check(#quests == 2, "two quests belong to the Deadmines (a boss named in a goal, and a filing under its name)")
check(quests[1].title == "The Defias Brotherhood" and #quests[1].bosses == 1 and ns.Dungeons[36].bosses[quests[1].bosses[1]].name == "Edwin VanCleef",
    "a quest naming a boss in its goals is linked to that boss")
check(quests[2].title == "Collect Red Silk Bandanas" and quests[2].matched == "header" and quests[2].complete, "a quest filed under the dungeon's name is found, and is ready")
check(#ns.QuestsFor(389) == 0, "other dungeons get none of them")
local text = ns.QuestPanelText(quests, ns.Dungeons[36])
check(text:find("The Defias Brotherhood", 1, true) and text:find("Edwin VanCleef", 1, true) and text:find("(ready)", 1, true), "the panel text shows titles, goals, the boss and readiness")
check(ns.QuestPanelText({}, ns.Dungeons[36]):find("None of the quests", 1, true), "the panel says so when there are none")

ns.db.panel = "quests"
local vanIndex
for i, b in ipairs(ns.Dungeons[36].bosses) do if b.name == "Edwin VanCleef" then vanIndex = i end end
ns.ShowDungeon(36, ns.Dungeons[36].bosses[vanIndex].floor or 1)
local qf = NoobsForeverDungeonMapperFrame
check(qf.questPanel:IsShown() and not qf.list:IsShown(), "the quests panel replaces the boss list")
check(qf.questsBtn.text == "Quests (2)", "the button counts the quests")
check(qf.pins[vanIndex] and qf.pins[vanIndex]:IsShown() and qf.pins[vanIndex].quest:IsShown(), "the boss a quest names gets a quest marker")
qf.questsBtn.scripts.OnClick()
check(ns.db.panel == "bosses" and qf.list:IsShown() and not qf.questPanel:IsShown(), "the button switches back to the boss list")
ns.SetKilled(36, ns.Dungeons[36].bosses[vanIndex], true)
check(not qf.pins[vanIndex].quest:IsShown(), "the quest marker goes once the boss is down")
ns.ResetRun(36)
local redraws = 0
local refreshBefore = ns.Refresh
ns.Refresh = function() redraws = redraws + 1 return refreshBefore() end
Fire("QUEST_LOG_UPDATE")
check(redraws >= 1, "a quest log change redraws the window")
ns.Refresh = refreshBefore
ns.db.probeLog = true
ns.QuestsFor(36)
check(ns.db.questScan and #ns.db.questScan.quests == 3, "with recording on, the quest log is kept for tuning")
ns.db.probeLog = false
ns.db.questScan = nil
C_QuestLog = realQuestLog
ns.HideMap()

realPrint("The maps fade while the player moves")
local function Near(a, b) return math.abs(a - b) < 0.001 end
local function Settle() for i = 1, 20 do ns.StepFade(0.1) end end
ns.db.opacity, ns.db.moveFade, ns.db.moveOpacity = 1, true, 0.35
ns.ShowDungeon(48, 1)
ns.ShowWorldMap(1415)
local fdungeon, fworld = NoobsForeverDungeonMapperFrame, NoobsForeverDungeonMapperWorld
check(ns.DEFAULTS.moveFade == true and ns.DEFAULTS.moveOpacity == 0.35, "the default is on, at 35%")
Settle()
check(Near(fdungeon:GetAlpha(), 1) and Near(fworld:GetAlpha(), 1), "standing still: solid")
game.moving = true
ns.StepFade(0.1)
check(fdungeon:GetAlpha() < 1 and fdungeon:GetAlpha() > 0.35, "when moving the maps start to fade (not a sudden jump)")
Settle()
check(Near(fdungeon:GetAlpha(), 0.35) and Near(fworld:GetAlpha(), 0.35), "both maps end up see-through while moving")
game.moving = false
Settle()
check(Near(fdungeon:GetAlpha(), 1) and Near(fworld:GetAlpha(), 1), "and come back when the player stops")
game.moving = true
Settle()
fworld.hovered = true
Settle()
check(Near(fworld:GetAlpha(), 1), "a map the mouse is over stays solid while moving")
fworld.hovered = false
Settle()
check(Near(fworld:GetAlpha(), 0.35), "and fades again when the mouse leaves")
ns.db.moveFade = false
Settle()
check(Near(fdungeon:GetAlpha(), 1), "with the option off nothing fades")
ns.db.moveFade = true
ns.db.opacity = 0.8
Settle()
check(Near(fdungeon:GetAlpha(), 0.35), "moving fades to the moving opacity")
game.moving = false
Settle()
check(Near(fdungeon:GetAlpha(), 0.8), "and stopping returns to the normal opacity, not to solid")
ns.db.opacity, ns.db.moveOpacity = 0.3, 0.5
game.moving = true
Settle()
check(Near(fdungeon:GetAlpha(), 0.3), "it never gets more solid than the normal opacity while moving")
ns.db.opacity, ns.db.moveOpacity = 1, 0.35
local moveStep = NoobsForeverDungeonMapperOptions and NoobsForeverDungeonMapperOptions.parts.steppers.moveOpacity
check(moveStep ~= nil, "the options have an Opacity while I move setting")
moveStep.minus.scripts.OnClick()
check(Near(ns.db.moveOpacity, 0.3), "its - lowers it in 5% steps")
ns.db.moveOpacity = 0.35
game.moving = false
game.speed = 5
Settle()
check(Near(fdungeon:GetAlpha(), 0.35), "being carried (speed above zero) counts as moving")
game.speed = nil
local realMoving = IsPlayerMoving
IsPlayerMoving, GetUnitSpeed = nil, nil
Settle()
check(Near(fdungeon:GetAlpha(), 1), "no movement API: no fading and no error")
IsPlayerMoving = realMoving
function GetUnitSpeed() return game.speed or 0, 7, 7, 4.7 end
game.moving = false
Settle()
ns.HideWorldMap()
ns.HideMap()

realPrint("The probe checks the map tiles")
ns.ShowDungeon(48, 1)
C_Texture = { GetTextureInfo = function(t) if t == ns.Dungeons[48].floors[1].tiles[4] then return nil end return { width = 256, height = 256 } end }
printed = {}
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe")
local probeText = table.concat(printed, "\n")
check(probeText:find("tiles not found: 4", 1, true), "the probe names the tile the client can't find")
check(probeText:find("Game language enUS, build 70959", 1, true), "the probe reports the language and build")
C_Texture = { GetTextureInfo = function() return { width = 256, height = 256 } end }
printed = {}
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe")
check(table.concat(printed, "\n"):find("all 12 tiles", 1, true), "the probe says when all the tiles are found")
C_Texture = nil
ns.HideMap()
ns.db.probe = nil

realPrint("Map tiles are drawn above the canvas backdrop and below the route lines")
ns.db.route = true
ns.ShowDungeon(48, 1)
local dm = NoobsForeverDungeonMapperFrame
local tilesOK = #dm.tiles == 12
for _, t in ipairs(dm.tiles) do
    if not (rawget(t, "layer") == "ARTWORK" and rawget(t, "subLevel") == -2) then tilesOK = false end
end
check(tilesOK, "all 12 dungeon tiles are ARTWORK, sublevel -2 (not in the backdrop's BACKGROUND layer)")
local linesOK, nlines = true, 0
for _, l in ipairs(dm.routeLines) do
    nlines = nlines + 1
    if not (rawget(l, "layer") == "ARTWORK" and rawget(l, "subLevel") == 1) then linesOK = false end
end
check(nlines > 0 and linesOK, "route lines are ARTWORK sublevel 1, above the tiles")
ns.HideMap()
ns.ShowWorldMap(1415)
local wtilesOK = #NoobsForeverDungeonMapperWorld.tiles == 12
for _, t in ipairs(NoobsForeverDungeonMapperWorld.tiles) do
    if not (rawget(t, "layer") == "ARTWORK" and rawget(t, "subLevel") == -2) then wtilesOK = false end
end
check(wtilesOK, "the world map's tiles are layered the same way")
ns.HideWorldMap()

realPrint("Boss pins from OpenMap and the placer")
local pinned = 0
for _, b in ipairs(ns.Dungeons[36].bosses) do if b.x then pinned = pinned + 1 end end
check(pinned == 7, "Deadmines got 7 pins from OpenMap's data")
ns.db.placer = true
ns.ShowDungeon(389, 1)
local rfc = ns.Dungeons[389]
local oggle = rfc.bosses[1]
check(oggle.x == nil, "Ragefire Chasm's first boss starts without a pin")
ns.StartPlacing(1)
check(NoobsForeverDungeonMapperFrame.placeStatus:IsShown(), "placing shows instructions")
ns.PlaceAt(1.5, 0.2)
check(oggle.x == nil, "a click outside the map is ignored")
ns.PlaceAt(0.25, 0.4)
check(oggle.x == 0.25 and oggle.y == 0.4 and oggle.floor == 1, "the pin is placed where it was clicked")
check(ns.HasBossPlace(389, oggle), "the placed pin is saved")
local lines = ns.ExportBossPlaces()
check(#lines == 1 and lines[1]:find("389|Ragefire Chasm|" .. oggle.name .. "|1|0.2500|0.4000", 1, true), "the export line is right")
oggle.floor, oggle.x, oggle.y, oggle.original = nil, nil, nil, nil
ns.ApplyBossPlaces()
check(oggle.x == 0.25, "placed pins come back after a reload")
ns.ClearBossPlace(389, oggle)
check(oggle.x == nil and not ns.HasBossPlace(389, oggle), "removing a placed pin restores the original")
ns.db.placer = false
ns.CancelPlacing()
ns.HideMap()

realPrint("World map")
for _, m in ipairs(ns.WorldMaps) do
    check(#m.tiles == 12, m.name .. " has 12 tiles")
    for _, p in ipairs(m.pins) do
        check(p[1] >= 0 and p[1] <= 1 and p[2] >= 0 and p[2] <= 1 and #p[3] > 0, m.name .. " pin is on the map")
    end
end
local entrance = {}
for _, m in ipairs(ns.WorldMaps) do
    if m.uiMapID ~= 947 then
        for _, p in ipairs(m.pins) do for _, i in ipairs(p[3]) do entrance[i[1]] = true end end
    end
end
for _, id in ipairs(ns.DungeonOrder) do check(entrance[id], ns.Dungeons[id].name .. " has an entrance on a continent") end
ns.ShowWorldMap(1415)
local world = NoobsForeverDungeonMapperWorld
check(world:IsShown() and world.title:GetText() == "Eastern Kingdoms", "the Eastern Kingdoms map shows")
check(world.tiles[1].texture ~= nil, "continent tiles are drawn")
local deadmines
for _, p in ipairs(world.pins) do
    if p:IsShown() and p.instances[1][1] == 36 then deadmines = p end
end
check(deadmines ~= nil, "Deadmines has a pin on Eastern Kingdoms")
deadmines.scripts.OnClick(deadmines)
check(not world:IsShown() and NoobsForeverDungeonMapperFrame:IsShown() and ns.ViewedInstance() == 36, "clicking an entrance opens that dungeon")
ns.HideMap()
ns.ShowWorldMap(947)
check(world.title:GetText() == "Azeroth", "the world map shows")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("world")
check(not world:IsShown(), "/fd world toggles it")
ns.ShowWorldMap()
check(world.title:GetText() ~= nil, "it opens on a map by itself")
NoobsForeverDungeonMapper_Binding("world")
check(not world:IsShown(), "the world map key binding toggles it")

realPrint("Unknown instance prints a note")
printed = {}
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 99999, "Somewhere New"
Fire("PLAYER_ENTERING_WORLD")
check(printed[1] and printed[1]:find("No map data for Somewhere New", 1, true), "note printed")

realPrint(failures == 0 and "\nAll checks passed." or ("\n" .. failures .. " check(s) failed."))
os.exit(failures == 0 and 0 or 1)
