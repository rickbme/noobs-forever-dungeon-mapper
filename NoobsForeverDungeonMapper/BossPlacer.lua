-- Boss pin placer: lets players put (or move) a boss's pin on the map and share the result, so the
-- bosses nobody has mapped yet can be filled in by the people who have killed them.
-- Turn it on in Options ("Help map the bosses"). Then click a boss in the list and click the map.
-- Placed pins are kept in NoobsForeverDungeonMapperDB.bossPlaces and win over the built-in data; "Share my boss
-- pins" shows them as text to copy and send to the mapmakers (they go into Data/BossPlaces.lua).
local ADDON, ns = ...

local function Round(v) return math.floor(math.min(1, math.max(0, v)) * 10000 + 0.5) / 10000 end

-- Remember a boss's built-in pin the first time we change it, so removing ours can restore it.
local function Remember(boss)
    if not boss.original then boss.original = { floor = boss.floor, x = boss.x, y = boss.y, fromGuild = boss.fromGuild } end
end

-- What to put back to undo a change, newest last.
local history = {}
local MAX_HISTORY = 40

local function Push(instanceID, boss)
    local t = ns.db.bossPlaces[instanceID]
    local prev = t and t[boss.name]
    history[#history + 1] = { id = instanceID, boss = boss, prev = prev and { prev[1], prev[2], prev[3] } or nil }
    while #history > MAX_HISTORY do table.remove(history, 1) end
end

local function Apply(instanceID, boss, floor, x, y)
    Remember(boss)
    x, y = Round(x), Round(y)
    ns.db.bossPlaces[instanceID] = ns.db.bossPlaces[instanceID] or {}
    ns.db.bossPlaces[instanceID][boss.name] = { floor, x, y }
    boss.floor, boss.x, boss.y, boss.fromGuild = floor, x, y, nil
end

local function Remove(instanceID, boss)
    local t = ns.db.bossPlaces[instanceID]
    if t then t[boss.name] = nil end
    if boss.original then
        boss.floor, boss.x, boss.y = boss.original.floor, boss.original.x, boss.original.y
        boss.fromGuild = boss.original.fromGuild
        boss.original = nil
    end
end

function ns.SetBossPlace(instanceID, boss, floor, x, y)
    Push(instanceID, boss)
    Apply(instanceID, boss, floor, x, y)
end

function ns.HasBossPlace(instanceID, boss)
    local t = ns.db.bossPlaces[instanceID]
    return t ~= nil and t[boss.name] ~= nil
end

-- Removes the player's own pin for a boss (the built-in one, if there is one, comes back).
function ns.ClearBossPlace(instanceID, boss)
    if not ns.HasBossPlace(instanceID, boss) then return end
    Push(instanceID, boss)
    Remove(instanceID, boss)
end

function ns.CanUndoBossPlace() return #history > 0 end

-- Takes back the last change (a pin placed, moved or removed). Returns the boss it was for, or nil.
function ns.UndoBossPlace()
    local h = table.remove(history)
    if not h then return nil end
    if h.prev then Apply(h.id, h.boss, h.prev[1], h.prev[2], h.prev[3]) else Remove(h.id, h.boss) end
    return h.boss
end

-------------------------------------------------------------------------------
-- Pins shared by the guild: pasted in from a block of lines (Options > Import guild pins). They only fill
-- bosses that have no pin of their own or from the built-in data, and the player's own pins win over them.
-------------------------------------------------------------------------------

local function ApplyGuild(boss, p)
    if boss.original then
        if boss.original.x == nil or boss.original.fromGuild then
            boss.original = { floor = p[1], x = p[2], y = p[3], fromGuild = true }
        end
    elseif boss.x == nil or boss.fromGuild then
        boss.floor, boss.x, boss.y, boss.fromGuild = p[1], p[2], p[3], true
    end
end

-- At login (and after an import): put the guild's pins on the bosses they fill.
function ns.ApplyGuildPins()
    for id, places in pairs(ns.db.guildPins) do
        local d = ns.Dungeons[id]
        if d then
            for _, b in ipairs(d.bosses) do
                local p = places[b.name]
                if p and p[1] and p[2] and p[3] then ApplyGuild(b, p) end
            end
        end
    end
end

function ns.CountGuildPins()
    local n = 0
    for _, places in pairs(ns.db.guildPins) do for _ in pairs(places) do n = n + 1 end end
    return n
end

function ns.ClearGuildPins()
    ns.db.guildPins = {}
    for _, d in pairs(ns.Dungeons) do
        for _, b in ipairs(d.bosses) do
            if b.original and b.original.fromGuild then b.original = {} end -- the player's own pin stays, nothing under it
            if b.fromGuild then b.floor, b.x, b.y, b.fromGuild = nil, nil, nil, nil end
        end
    end
end

-- One pasted line -> { id, boss, floor, x, y }. Lines that aren't pin lines (a heading, chat around them) give
-- nil; a pin line that doesn't check out gives nil and the reason. Discord's quoting and `code ticks` are ignored.
local function ParseLine(line)
    line = line:gsub("^[%s>`]+", "")
    line = line:gsub("[%s`]+$", "")
    local rest = line:match("^NFDM|(.*)$")
    if not rest then return nil end
    local f = {}
    for part in (rest .. "|"):gmatch("([^|]*)|") do f[#f + 1] = part end
    if #f < 6 then return nil, "not a complete pin line: " .. line:sub(1, 40) end
    local id, floor, x, y = tonumber(f[1]), tonumber(f[4]), tonumber(f[5]), tonumber(f[6])
    local d = id and ns.Dungeons[id]
    if not d then return nil, "unknown dungeon " .. tostring(f[1]) end
    if #d.floors == 0 then return nil, d.name .. " has no map yet" end
    local boss
    for _, b in ipairs(d.bosses) do if ns.Norm(b.name) == ns.Norm(f[3]) then boss = b end end
    if not boss then return nil, "no boss called " .. f[3] .. " in " .. d.name end
    if not (floor and floor >= 1 and floor <= #d.floors and floor == math.floor(floor)) then
        return nil, boss.name .. ": floor " .. tostring(f[4]) .. " isn't one of " .. d.name .. "'s"
    end
    if not (x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return nil, boss.name .. ": the position is off the map" end
    return { id = id, boss = boss, floor = floor, x = x, y = y }
end

-- Takes pasted text; stores and applies every good pin line. Returns how many were taken and the reasons for the
-- ones that weren't.
function ns.ImportGuildPins(text)
    local imported, skipped = 0, {}
    for line in ((text or "") .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
        local pin, why = ParseLine(line)
        if pin then
            ns.db.guildPins[pin.id] = ns.db.guildPins[pin.id] or {}
            ns.db.guildPins[pin.id][pin.boss.name] = { pin.floor, Round(pin.x), Round(pin.y) }
            imported = imported + 1
        elseif why then
            skipped[#skipped + 1] = why
        end
    end
    ns.ApplyGuildPins()
    return imported, skipped
end

-- At login: put the player's own placed pins back on the bosses (over the guild's).
function ns.ApplyBossPlaces()
    ns.ApplyGuildPins()
    for id, places in pairs(ns.db.bossPlaces) do
        local d = ns.Dungeons[id]
        if d then
            for _, b in ipairs(d.bosses) do
                local p = places[b.name]
                if p and p[1] and p[2] and p[3] then
                    Remember(b)
                    b.floor, b.x, b.y, b.fromGuild = p[1], p[2], p[3], nil
                end
            end
        end
    end
end

-- The placed pins as lines of text, one per boss: NFDM|id|dungeon|boss|floor|x|y
function ns.ExportBossPlaces()
    local lines = {}
    for _, id in ipairs(ns.DungeonOrder) do
        local places = ns.db.bossPlaces[id]
        if places then
            for _, b in ipairs(ns.Dungeons[id].bosses) do
                local p = places[b.name]
                if p then
                    lines[#lines + 1] = ("NFDM|%d|%s|%s|%d|%.4f|%.4f"):format(id, ns.Dungeons[id].name, b.name, p[1], p[2], p[3])
                end
            end
        end
    end
    return lines
end

-------------------------------------------------------------------------------
-- The "Share my boss pins" window
-------------------------------------------------------------------------------

local share

function ns.ShowShareWindow()
    local lines = ns.ExportBossPlaces()
    if #lines == 0 then
        ns.Print("You haven't placed any boss pins yet. Turn on \"Help map the bosses\" in the options first.")
        return
    end
    if not share then
        share = CreateFrame("Frame", "NoobsForeverDungeonMapperShare", UIParent, "BackdropTemplate")
        share:SetSize(460, 300)
        share:SetPoint("CENTER")
        share:SetFrameStrata("DIALOG")
        share:SetToplevel(true)
        share:EnableMouse(true)
        share:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        tinsert(UISpecialFrames, "NoobsForeverDungeonMapperShare")
        local close = CreateFrame("Button", nil, share, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local title = share:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText("Share my boss pins")
        local help = share:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        help:SetWidth(420)
        help:SetJustifyH("LEFT")
        help:SetText("Click in the box, press Ctrl+A to select everything, then Ctrl+C to copy. Paste it in the Noobs Forever Discord (the boss pins channel). Thank you for helping!")
        share.box = CreateFrame("EditBox", nil, share)
        share.box:SetMultiLine(true)
        share.box:SetFontObject("ChatFontNormal")
        share.box:SetSize(420, 150)
        share.box:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
        share.box:SetAutoFocus(false)
        share.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    share.box:SetText("# Noobs Forever Dungeon Mapper boss pins\n" .. table.concat(lines, "\n"))
    share:Show()
end

-------------------------------------------------------------------------------
-- The "Import guild pins" window
-------------------------------------------------------------------------------

local importer

function ns.ShowImportWindow()
    if not importer then
        importer = CreateFrame("Frame", "NoobsForeverDungeonMapperImport", UIParent, "BackdropTemplate")
        importer:SetSize(480, 360)
        importer:SetPoint("CENTER")
        importer:SetFrameStrata("DIALOG")
        importer:SetToplevel(true)
        importer:EnableMouse(true)
        importer:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        tinsert(UISpecialFrames, "NoobsForeverDungeonMapperImport")
        local close = CreateFrame("Button", nil, importer, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local title = importer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText("Import guild pins")
        local help = importer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        help:SetWidth(440)
        help:SetJustifyH("LEFT")
        help:SetText("Copy the guild's block of boss pins from Discord, click in the box and press Ctrl+V, then Import. They fill bosses that have no pin yet; your own pins always win.")
        importer.box = CreateFrame("EditBox", nil, importer)
        importer.box:SetMultiLine(true)
        importer.box:SetFontObject("ChatFontNormal")
        importer.box:SetMaxLetters(60000)
        importer.box:SetSize(440, 170)
        importer.box:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
        importer.box:SetAutoFocus(false)
        importer.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        importer.result = importer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        importer.result:SetPoint("BOTTOMLEFT", 20, 50)
        importer.result:SetWidth(440)
        importer.result:SetJustifyH("LEFT")
        local go = CreateFrame("Button", nil, importer, "UIPanelButtonTemplate")
        go:SetSize(120, 24)
        go:SetPoint("BOTTOMLEFT", 20, 18)
        go:SetText("Import")
        go:SetScript("OnClick", function()
            local n, skipped = ns.ImportGuildPins(importer.box:GetText())
            local text = ("Imported %d pin(s). The guild's pins now fill %d boss(es)."):format(n, ns.CountGuildPins())
            if #skipped > 0 then text = text .. ("\nSkipped %d line(s), for example: %s"):format(#skipped, skipped[1]) end
            importer.result:SetText(text)
            ns.Refresh()
        end)
        local clear = CreateFrame("Button", nil, importer, "UIPanelButtonTemplate")
        clear:SetSize(170, 24)
        clear:SetPoint("LEFT", go, "RIGHT", 10, 0)
        clear:SetText("Remove all imported pins")
        clear:SetScript("OnClick", function()
            ns.ClearGuildPins()
            importer.result:SetText("The guild's pins were removed. Your own pins are kept.")
            ns.Refresh()
        end)
        importer.go, importer.clear = go, clear
    end
    importer.result:SetText(("%d guild pin(s) are in use."):format(ns.CountGuildPins()))
    importer:Show()
end
