-- /fd probe: finds out what the game really tells an addon inside a dungeon.
-- The notes say player coordinates are blocked in instances; this checks it in the live client.
--   /fd probe        run every check once and print the results
--   /fd probe log    toggle recording each sub-zone change (and whether any position API answered)
--   /fd probe clear  forget the recorded results
-- Results are kept in NoobsForeverDungeonMapperDB.probe, so they can be read from the SavedVariables file
-- (WTF/Account/<account>/SavedVariables/NoobsForeverDungeonMapper.lua) after logging out.
local _, ns = ...

local MAX_LOG = 300

local function Describe(...)
    local n = select("#", ...)
    if n == 0 then return "nil" end
    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        if v == nil then
            parts[i] = "nil"
        elseif issecretvalue and issecretvalue(v) then
            parts[i] = "SECRET"
        elseif type(v) == "number" then
            parts[i] = ("%.4f"):format(v)
        else
            parts[i] = tostring(v)
        end
    end
    return table.concat(parts, ", ")
end

local function MapID()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- { label, function returning the API's values }
local CHECKS = {
    { "C_Map.GetBestMapForUnit", function() return MapID() end },
    { "C_Map.GetPlayerMapPosition", function()
        local m = MapID()
        if not (m and C_Map.GetPlayerMapPosition) then return nil end
        local p = C_Map.GetPlayerMapPosition(m, "player")
        if not p then return nil end
        return p:GetXY()
    end, position = true },
    { "UnitPosition", function() return UnitPosition("player") end, position = true },
    { "GetPlayerFacing", function() return GetPlayerFacing() end, position = true },
    { "GetUnitSpeed", function() return GetUnitSpeed("player") end },
    { "IsIndoors", function() return IsIndoors() end },
    { "GetZoneText", function() return GetZoneText() end },
    { "GetRealZoneText", function() return GetRealZoneText() end },
    { "GetSubZoneText", function() return GetSubZoneText() end },
    { "GetMinimapZoneText", function() return GetMinimapZoneText() end },
    { "GetInstanceInfo (dungeon finder ID)", function() return select(10, GetInstanceInfo()) end },
    { "GetLFGDungeonNumEncounters", function()
        local id = select(10, GetInstanceInfo())
        if not (id and GetLFGDungeonNumEncounters) then return nil end
        return GetLFGDungeonNumEncounters(id)
    end },
}

-- The game's boss progress for the dungeon we are in: "Name = down" or "up", or nil if it isn't available.
local function BossProgress()
    if not (GetLFGDungeonNumEncounters and GetLFGDungeonEncounterInfo) then return nil end
    local id = ns.Safe(select(10, GetInstanceInfo()))
    if type(id) ~= "number" or id == 0 then return nil end
    local ok, n = pcall(GetLFGDungeonNumEncounters, id)
    if not (ok and type(ns.Safe(n)) == "number") then return nil end
    local parts = {}
    for i = 1, n do
        local ok2, name, _, killed = pcall(GetLFGDungeonEncounterInfo, id, i)
        parts[#parts + 1] = ("%s = %s"):format(tostring(ok2 and ns.Safe(name) or "?"), (ok2 and ns.Safe(killed)) and "down" or "up")
    end
    return table.concat(parts, "; ")
end

local function Pack(...) return { n = select("#", ...), ... } end

-- Runs every check; returns a list of { label, text, gotNumber } and whether any position API answered.
local function Run()
    local results, anyPosition = {}, false
    for _, c in ipairs(CHECKS) do
        local r = Pack(pcall(c[2]))
        local line, gotNumber
        if r[1] then
            line = Describe(unpack(r, 2, r.n))
            for i = 2, r.n do
                local v = r[i]
                if c.position and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then gotNumber = true end
            end
        else
            line = "error: " .. tostring(r[2])
        end
        if gotNumber then anyPosition = true end
        results[#results + 1] = { c[1], line, gotNumber }
    end
    return results, anyPosition
end

local function Store()
    ns.db.probe = ns.db.probe or { log = {} }
    return ns.db.probe
end

-- Whether this client can find the picture tiles of the floor on screen (a tile it can't find draws as a wrong-
-- coloured square). Reported by /fd probe together with the game's language and build.
local function TileReport()
    local id, floor = ns.ViewedInstance(), ns.ViewedFloor()
    local d = id and ns.Dungeons[id]
    local f = d and floor and d.floors[floor]
    if not f then return "open a dungeon's map first, then run this again" end
    if not (C_Texture and C_Texture.GetTextureInfo) then return "can't be checked on this client" end
    local missing = {}
    for i, tile in ipairs(f.tiles) do
        local ok, info = pcall(C_Texture.GetTextureInfo, tile)
        if not (ok and type(info) == "table" and info.width) then missing[#missing + 1] = i end
    end
    if #missing == 0 then return ("all %d tiles of %s found"):format(#f.tiles, f.name) end
    return ("%s: tiles not found: %s (of %d)"):format(f.name, table.concat(missing, ", "), #f.tiles)
end

function ns.Probe(arg)
    arg = arg or ""
    if arg == "clear" then
        ns.db.probe = nil
        ns.db.seen = {}
        ns.Print("Probe results cleared.")
    elseif arg == "log" then
        ns.db.probeLog = not ns.db.probeLog
        ns.Print("Recording sub-zone changes: " .. (ns.db.probeLog and "on" or "off"))
    else
        local results, any = Run()
        local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        ns.Print(("Probe in %s (instance %s):"):format(tostring(ns.Safe(name)), tostring(ns.Safe(instanceID))))
        for _, r in ipairs(results) do ns.Print("  " .. r[1] .. " = " .. r[2]) end
        ns.Print(any and "|cff20ff20A position API answered with numbers.|r"
            or "|cffffd100No position API gave a number: only sub-zone anchors are possible here.|r")
        local locale, build = GetLocale and GetLocale() or "?", select(2, GetBuildInfo())
        local tiles = TileReport()
        ns.Print(("  Game language %s, build %s"):format(tostring(locale), tostring(build)))
        ns.Print("  Map tiles: " .. tiles)
        local progress = BossProgress()
        ns.Print("  Boss progress from the game: " .. (progress or "not available"))
        local store = Store()
        store.last = { t = time(), instance = ns.Safe(instanceID), anyPosition = any, results = {}, bossProgress = progress, locale = locale, build = build, tiles = tiles }
        for _, r in ipairs(results) do store.last.results[r[1]] = r[2] end
    end
end

-- Called from Core.lua on every zone change inside a known dungeon.
function ns.RecordSubzone(instanceID)
    local sub = ns.Safe(GetSubZoneText())
    if not sub or sub == "" then return end
    ns.db.seen[instanceID] = ns.db.seen[instanceID] or {}
    ns.db.seen[instanceID][sub] = (ns.db.seen[instanceID][sub] or 0) + 1
    if ns.db.probeLog then
        local _, any = Run()
        local log = Store().log
        log[#log + 1] = {
            t = time(), instance = instanceID, sub = sub, zone = ns.Safe(GetZoneText()),
            minimap = ns.Safe(GetMinimapZoneText()), anyPosition = any,
        }
        while #log > MAX_LOG do table.remove(log, 1) end
    end
end

-- Every boss fight event as the game sent it (kept always, last 40): what the id, name and result
-- were, whether they were secret values, and which boss we matched. Read it from the saved variables
-- when a kill goes missing.
local MAX_ENCOUNTERS = 40
function ns.RecordEncounter(kind, id, name, success, boss)
    ns.db.encounterLog = ns.db.encounterLog or {}
    local log = ns.db.encounterLog
    log[#log + 1] = {
        t = time(), kind = kind, id = Describe(id), name = Describe(name), success = Describe(success),
        matched = boss and boss.name or "NO MATCH", instance = ns.Safe(select(8, GetInstanceInfo())),
    }
    while #log > MAX_ENCOUNTERS do table.remove(log, 1) end
end
