-- Noobs Forever Dungeon Mapper: "my quests here".
-- No game or public data says where in a dungeon a quest's objective is (docs/quests-research.md), but
-- the game does let an addon read the player's own quest log. So for a dungeon this lists the quests
-- in the log that belong to it, with their objectives, and links a quest to a boss when the quest's
-- title or an objective names that boss ("Kill Edwin VanCleef"): that boss then shows a quest marker.
-- A quest belongs to a dungeon when the quest log files it under the dungeon's name, or its title names
-- the dungeon, or its title or an objective names one of the dungeon's bosses.
local ADDON, ns = ...

local MIN_NAME = 5   -- the shortest boss or dungeon name trusted to be found inside quest text
local MAX_SHOWN = 7  -- quests listed in the panel

local function Has(hay, needle)
    hay, needle = ns.Norm(hay), ns.Norm(needle)
    return hay ~= nil and needle ~= nil and #needle >= MIN_NAME and hay:find(needle, 1, true) ~= nil
end

local function Objectives(questID)
    local out = {}
    if not (questID and C_QuestLog and C_QuestLog.GetQuestObjectives) then return out end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not (ok and type(list) == "table") then return out end
    for _, o in ipairs(list) do
        local text = ns.Safe(o.text)
        if type(text) == "string" and text ~= "" then
            out[#out + 1] = { text = text, done = ns.Safe(o.finished) and true or false }
        end
    end
    return out
end

-- Every quest in the player's log, with the zone heading it sits under.
local function ScanLog()
    local quests = {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return quests end
    local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
    n = ok and ns.Safe(n) or 0
    local header
    for i = 1, (type(n) == "number" and n or 0) do
        local ok2, info = pcall(C_QuestLog.GetInfo, i)
        if ok2 and type(info) == "table" then
            local title = ns.Safe(info.title)
            if ns.Safe(info.isHeader) then
                header = title
            elseif type(title) == "string" and not ns.Safe(info.isHidden) then
                quests[#quests + 1] = { title = title, questID = ns.Safe(info.questID), level = ns.Safe(info.level), header = header }
            end
        end
    end
    return quests
end

-- The quests in the player's log that belong to this dungeon:
--   { title, questID, level, header, objectives = { { text, done } }, bosses = { boss index, ... }, complete }
function ns.QuestsFor(instanceID)
    local d = ns.Dungeons[instanceID]
    local out = {}
    if not d then return out end
    local seen = {}
    for _, q in ipairs(ScanLog()) do
        q.objectives = Objectives(q.questID)
        q.bosses = {}
        for i, b in ipairs(d.bosses) do
            local hit = Has(q.title, b.name)
            for _, o in ipairs(q.objectives) do
                if Has(o.text, b.name) then hit = true end
            end
            if hit then q.bosses[#q.bosses + 1] = i end
        end
        local byHeader = type(q.header) == "string" and (Has(q.header, d.name) or Has(d.name, q.header))
        q.matched = (byHeader and "header") or (Has(q.title, d.name) and "title") or (#q.bosses > 0 and "boss") or nil
        if q.matched then
            local done = #q.objectives > 0
            for _, o in ipairs(q.objectives) do if not o.done then done = false end end
            q.complete = done
            out[#out + 1] = q
        end
        seen[#seen + 1] = { title = q.title, header = q.header, matched = q.matched or "no" }
    end
    -- with recording on, keep what the quest log looked like so the matching can be tuned from real data
    if ns.db and ns.db.probeLog then ns.db.questScan = { instance = instanceID, t = time(), quests = seen } end
    return out
end

-- The text of the quests panel: one block per quest, coloured for the player's level.
function ns.QuestPanelText(quests, dungeon)
    if #quests == 0 then
        return "|cff808080None of the quests in your log are for this dungeon.\n\nQuests whose title or goals name this dungeon or one of its bosses show up here.|r"
    end
    local lines = {}
    for n, q in ipairs(quests) do
        if n > MAX_SHOWN then
            lines[#lines + 1] = ("|cff808080+ %d more|r"):format(#quests - MAX_SHOWN)
            break
        end
        local level = type(q.level) == "number" and q.level > 0 and q.level or nil
        local color = level and ns.DifficultyColor(level, level) or "|cffffd100"
        lines[#lines + 1] = ("%s%s%s|r%s"):format(color, level and ("[" .. level .. "] ") or "", q.title,
            q.complete and "  |cff20ff20(ready)|r" or "")
        for _, o in ipairs(q.objectives) do
            lines[#lines + 1] = (o.done and "  |cff20ff20- " or "  |cffffffff- ") .. o.text .. "|r"
        end
        for _, i in ipairs(q.bosses) do
            lines[#lines + 1] = ("  |cffffd100! %d. %s|r"):format(i, dungeon.bosses[i].name)
        end
        lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n")
end

-- Quest events come in bursts: redraw the window once, a moment after the last one.
local pending
function ns.QuestsChanged()
    if pending then return end
    local function Redraw()
        pending = false
        pcall(ns.Refresh)
    end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0.3, Redraw) else Redraw() end
end
