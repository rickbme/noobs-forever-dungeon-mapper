-- Boss pin placer: lets players put (or move) a boss's pin on the map and share the result, so the
-- bosses nobody has mapped yet can be filled in by the people who have killed them.
-- Turn it on in Options ("Help map the bosses"). Then click a boss in the list and click the map.
-- Placed pins are kept in NoobsForeverDungeonMapperDB.bossPlaces and win over the built-in data; "Share my boss
-- pins" shows them as text to copy and send to the mapmakers (they go into Data/BossPlaces.lua).
local ADDON, ns = ...

local function Round(v) return math.floor(math.min(1, math.max(0, v)) * 10000 + 0.5) / 10000 end

-- Remember a boss's built-in pin the first time we change it, so removing ours can restore it.
local function Remember(boss)
    if not boss.original then boss.original = { floor = boss.floor, x = boss.x, y = boss.y } end
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
    boss.floor, boss.x, boss.y = floor, x, y
end

local function Remove(instanceID, boss)
    local t = ns.db.bossPlaces[instanceID]
    if t then t[boss.name] = nil end
    if boss.original then
        boss.floor, boss.x, boss.y = boss.original.floor, boss.original.x, boss.original.y
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

-- At login: put the player's own placed pins back on the bosses.
function ns.ApplyBossPlaces()
    for id, places in pairs(ns.db.bossPlaces) do
        local d = ns.Dungeons[id]
        if d then
            for _, b in ipairs(d.bosses) do
                local p = places[b.name]
                if p and p[1] and p[2] and p[3] then
                    Remember(b)
                    b.floor, b.x, b.y = p[1], p[2], p[3]
                end
            end
        end
    end
end

-- The placed pins as lines of text, one per boss: id|dungeon|boss|floor|x|y
function ns.ExportBossPlaces()
    local lines = {}
    for _, id in ipairs(ns.DungeonOrder) do
        local places = ns.db.bossPlaces[id]
        if places then
            for _, b in ipairs(ns.Dungeons[id].bosses) do
                local p = places[b.name]
                if p then
                    lines[#lines + 1] = ("%d|%s|%s|%d|%.4f|%.4f"):format(id, ns.Dungeons[id].name, b.name, p[1], p[2], p[3])
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
        help:SetText("Click in the box, press Ctrl+A to select everything, then Ctrl+C to copy. Paste it to the mapmakers (for example in the Noobs Forever Discord). Thank you for helping!")
        share.box = CreateFrame("EditBox", nil, share)
        share.box:SetMultiLine(true)
        share.box:SetFontObject("ChatFontNormal")
        share.box:SetSize(420, 150)
        share.box:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
        share.box:SetAutoFocus(false)
        share.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    share.box:SetText(table.concat(lines, "\n"))
    share:Show()
end
