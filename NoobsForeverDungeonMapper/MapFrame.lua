-- Noobs Forever Dungeon Mapper: the map window.
-- Draws Blizzard's own dungeon map tiles (shipped in the Forever client, loaded by FileDataID),
-- a floor picker, numbered boss pins and a boss list with kill progress.
local ADDON, ns = ...

local MAP_W, MAP_H = 600, 400      -- shown size of the 1002 x 668 map area
local ART_W = 1002                 -- visible width of the legacy map art, in art pixels
local TILE = 256 * MAP_W / ART_W   -- one 256 px art tile, scaled
local LIST_W = 230
local PAD = 10
local ROW_H = 17
local MAX_ROWS = 24

local COLORS = {
    normal = { 0.70, 0.18, 0.12 },
    nextUp = { 1.00, 0.78, 0.10 },
    killed = { 0.45, 0.45, 0.45 },
    fight  = { 1.00, 0.20, 0.20 },
}

local f -- the window
local view = { instanceID = nil, floor = nil }
local fighting -- boss being fought, if any
local pins, rows = {}, {}
local routeLines = {} -- lines joining the bosses in order
local placing -- index of the boss whose pin is being placed (mapmaker mode)

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------

local function CircleTexture(parent, layer, size)
    local t = parent:CreateTexture(nil, layer)
    t:SetSize(size, size)
    t:SetColorTexture(1, 1, 1)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(t)
    t:AddMaskTexture(mask)
    return t
end

local function SmallButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

local function CreatePin(i)
    local p = CreateFrame("Button", nil, f.canvas)
    p:SetSize(22, 22)
    p:SetFrameLevel(f.canvas:GetFrameLevel() + 5)

    p.glow = CircleTexture(p, "BACKGROUND", 34)
    p.glow:SetPoint("CENTER")
    p.glow:SetVertexColor(1, 0.85, 0.2, 0.6)
    local ag = p.glow:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local s = ag:CreateAnimation("Scale")
    s:SetScaleFrom(0.6, 0.6); s:SetScaleTo(1.3, 1.3); s:SetDuration(1.1)
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.9); a:SetToAlpha(0); a:SetDuration(1.1)
    p.pulse = ag

    p.border = CircleTexture(p, "BORDER", 22)
    p.border:SetPoint("CENTER")
    p.border:SetVertexColor(0, 0, 0, 0.9)
    p.dot = CircleTexture(p, "ARTWORK", 18)
    p.dot:SetPoint("CENTER")
    p.num = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.num:SetPoint("CENTER", 0, 0)
    p.num:SetTextColor(1, 1, 1)
    p.check = p:CreateTexture(nil, "OVERLAY")
    p.check:SetSize(16, 16)
    p.check:SetPoint("CENTER")
    p.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p:SetScript("OnEnter", function(self) ns.ShowBossTooltip(self, self.boss, self.index) end)
    p:SetScript("OnLeave", GameTooltip_Hide)
    p:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.SetKilled(view.instanceID, self.boss, not ns.IsKilled(view.instanceID, self.boss))
        end
    end)
    pins[i] = p
    return p
end

local function CreateRow(i)
    local r = CreateFrame("Button", nil, f.list)
    r:SetSize(LIST_W - 8, ROW_H)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    r.check = r:CreateTexture(nil, "ARTWORK")
    r.check:SetSize(14, 14)
    r.check:SetPoint("LEFT", 2, 0)
    r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 20, 0)
    r.text:SetPoint("RIGHT", -2, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnEnter", function(self) ns.ShowBossTooltip(self, self.boss, self.index) end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.SetKilled(view.instanceID, self.boss, not ns.IsKilled(view.instanceID, self.boss))
        elseif ns.db.placer and view.floor then
            ns.StartPlacing(self.index)
        elseif self.boss.floor then
            ns.ShowDungeon(view.instanceID, self.boss.floor)
            local p = pins[self.index]
            if p and p:IsShown() then p.pulse:Play() end
        end
    end)
    rows[i] = r
    return r
end

local function Create()
    f = CreateFrame("Frame", "NoobsForeverDungeonMapperFrame", UIParent, "BackdropTemplate")
    f:SetSize(PAD * 3 + MAP_W + LIST_W, PAD * 2 + 34 + MAP_H + 64)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.point = { point, relPoint, x, y }
    end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    tinsert(UISpecialFrames, "NoobsForeverDungeonMapperFrame") -- Escape closes it

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", PAD + 4, -PAD - 2)
    f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 10, -1)

    -- Map canvas
    f.canvas = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.canvas:SetSize(MAP_W, MAP_H)
    f.canvas:SetPoint("TOPLEFT", PAD, -PAD - 30)
    f.canvas:SetClipsChildren(true)
    f.routeLines = routeLines -- (the offline tests look at them)
    f.pins = pins
    f.canvas:SetScript("OnMouseUp", function(self, button)
        if not placing then return end
        if button == "RightButton" then return ns.CancelPlacing() end
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local left, top = self:GetLeft(), self:GetTop()
        if not (scale and left and top) then return end
        ns.PlaceAt((cx / scale - left) / MAP_W, (top - cy / scale) / MAP_H)
    end)
    f.canvas:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f.canvas:SetBackdropColor(0, 0, 0, 0.6)
    f.tiles = {}
    for row = 0, 2 do
        for col = 0, 3 do
            local t = f.canvas:CreateTexture(nil, "BACKGROUND")
            t:SetSize(TILE, TILE)
            t:SetPoint("TOPLEFT", col * TILE, -row * TILE)
            f.tiles[#f.tiles + 1] = t
        end
    end
    f.placeStatus = f.canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.placeStatus:SetPoint("TOP", 0, -8)
    f.placeStatus:SetWidth(MAP_W - 40)
    f.placeStatus:SetTextColor(0.3, 0.85, 1)
    f.placeStatus:Hide()
    f.placeRemove = SmallButton(f.canvas, "Remove my pin", 110)
    f.placeRemove:SetPoint("TOP", f.placeStatus, "BOTTOM", 0, -4)
    f.placeRemove:SetFrameLevel(f.canvas:GetFrameLevel() + 10)
    f.placeRemove:SetScript("OnClick", function()
        local d = view.instanceID and ns.Dungeons[view.instanceID]
        local b = d and placing and d.bosses[placing]
        if b then ns.ClearBossPlace(view.instanceID, b) end
        ns.CancelPlacing()
    end)
    f.placeRemove:Hide()
    f.credit = f.canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.credit:SetPoint("BOTTOMRIGHT", -8, 6)
    f.credit:SetTextColor(1, 0.82, 0)
    -- "You are here": the inside of a dungeon hides coordinates, so this marks the area (Data/Anchors.lua)
    f.here = CreateFrame("Button", nil, f.canvas)
    f.here:SetSize(30, 30)
    f.here:SetFrameLevel(f.canvas:GetFrameLevel() + 8)
    f.here.ring = CircleTexture(f.here, "ARTWORK", 30)
    f.here.ring:SetPoint("CENTER")
    f.here.ring:SetVertexColor(0.2, 0.6, 1, 0.45)
    f.here.dot = CircleTexture(f.here, "OVERLAY", 10)
    f.here.dot:SetPoint("CENTER")
    f.here.dot:SetVertexColor(0.3, 0.75, 1, 1)
    f.here:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("You are in this area")
        if self.anchor then GameTooltip:AddLine(self.anchor.sub, 1, 1, 1) end
        GameTooltip:AddLine("Approximate: the game hides your exact position here.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.here:SetScript("OnLeave", GameTooltip_Hide)
    f.here:Hide()
    f.noArt = f.canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.noArt:SetPoint("CENTER")
    f.noArt:SetWidth(MAP_W - 80)
    f.noArt:SetText("No map image for this dungeon yet.\n\nThe Forever client has no map art for its new dungeons.\nThe boss list on the right still tracks your progress.")

    -- Floor picker under the map
    f.prev = SmallButton(f, "<", 28)
    f.prev:SetPoint("TOPLEFT", f.canvas, "BOTTOMLEFT", 0, -6)
    f.prev:SetScript("OnClick", function() ns.StepFloor(-1) end)
    f.next = SmallButton(f, ">", 28)
    f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
    f.next:SetScript("OnClick", function() ns.StepFloor(1) end)
    f.floorText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.floorText:SetPoint("LEFT", f.next, "RIGHT", 8, 0)

    f.location = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.location:SetPoint("TOPLEFT", f.prev, "BOTTOMLEFT", 2, -8)
    f.location:SetWidth(MAP_W)
    f.location:SetJustifyH("LEFT")

    -- Boss list
    f.list = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.list:SetSize(LIST_W, MAP_H)
    f.list:SetPoint("TOPLEFT", f.canvas, "TOPRIGHT", PAD, 0)
    f.list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f.list:SetBackdropColor(0, 0, 0, 0.35)
    f.listHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.listHint:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 2, -4)
    f.listHint:SetWidth(LIST_W)
    f.listHint:SetJustifyH("LEFT")
    f.listHint:SetText("Click: show on map. Right-click: mark killed.")
    f.listHintDefault = "Click: show on map. Right-click: mark killed."

    -- Buttons along the bottom right
    f.reset = SmallButton(f, "Reset", 70)
    f.reset:SetPoint("BOTTOMRIGHT", -PAD - 2, PAD + 2)
    f.reset:SetScript("OnClick", function() if view.instanceID then ns.ResetRun(view.instanceID) end end)
    f.reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clear this dungeon's boss kills")
        GameTooltip:Show()
    end)
    f.reset:SetScript("OnLeave", GameTooltip_Hide)
    f.live = SmallButton(f, "Live view", 80)
    f.live:SetPoint("RIGHT", f.reset, "LEFT", -4, 0)
    f.live:SetScript("OnClick", function() ns.LiveView_Toggle() end)
    f.live:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Live view")
        GameTooltip:AddLine("Enlarges the minimap while you are in a dungeon. The minimap is the only part of the game that may show your exact position inside an instance; addons cannot read it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.live:SetScript("OnLeave", GameTooltip_Hide)
    f.dungeons = SmallButton(f, "Dungeons", 80)
    f.dungeons:SetPoint("RIGHT", f.live, "LEFT", -4, 0)
    f.dungeons:SetScript("OnClick", function(self) ns.ShowDungeonMenu(self) end)
    f.world = SmallButton(f, "World map", 80)
    f.world:SetPoint("RIGHT", f.dungeons, "LEFT", -4, 0)
    f.world:SetScript("OnClick", function() f:Hide(); ns.ShowWorldMap() end)
    f.world:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("World map")
        GameTooltip:AddLine("Zoom out to see where every dungeon entrance is.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.world:SetScript("OnLeave", GameTooltip_Hide)
    f.options = SmallButton(f, "Options", 70)
    f.options:SetPoint("RIGHT", f.world, "LEFT", -4, 0)
    f.options:SetScript("OnClick", function() ns.ToggleOptions() end)
    f.options:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Options")
        GameTooltip:AddLine("Change how the map behaves. No typing needed.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f.options:SetScript("OnLeave", GameTooltip_Hide)

    if ns.db.point then
        local p = ns.db.point
        f:ClearAllPoints()
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    ns.ApplyScale()
    f:Hide()
end

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------

function ns.ShowBossTooltip(owner, boss, index)
    if not boss then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(index .. ". " .. boss.name)
    local id = view.instanceID
    if fighting == boss then
        GameTooltip:AddLine("In combat", 1, 0.3, 0.3)
    elseif ns.IsKilled(id, boss) then
        GameTooltip:AddLine("Defeated", 0.6, 0.6, 0.6)
    elseif ns.NextBoss(id) == boss then
        GameTooltip:AddLine("Next boss", 1, 0.82, 0)
    end
    local d = ns.Dungeons[id]
    if boss.floor and d.floors[boss.floor] then
        GameTooltip:AddLine("Floor: " .. d.floors[boss.floor].name, 1, 1, 1)
    elseif #d.floors > 0 then
        GameTooltip:AddLine("Position not known", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

-- The order to take the bosses in: a line from each boss's pin to the next one's, on this floor. They
-- are straight lines (the order, not the walking path), grey once the boss they leave from is down.
local function DrawRoute(d)
    for _, l in ipairs(routeLines) do l:Hide() end
    if ns.db.route == false or not view.floor or not f.canvas.CreateLine then return end
    local n = 0
    for i = 1, #d.bosses - 1 do
        local a, b = d.bosses[i], d.bosses[i + 1]
        if a.x and b.x and a.floor == view.floor and b.floor == view.floor then
            n = n + 1
            local line = routeLines[n]
            if not line then
                line = f.canvas:CreateLine(nil, "ARTWORK")
                line:SetThickness(3)
                routeLines[n] = line
            end
            if ns.IsKilled(view.instanceID, a) then
                line:SetColorTexture(0.55, 0.55, 0.55, 0.45)
            else
                line:SetColorTexture(1, 0.82, 0.1, 0.75)
            end
            line:SetStartPoint("TOPLEFT", f.canvas, a.x * MAP_W, -a.y * MAP_H)
            line:SetEndPoint("TOPLEFT", f.canvas, b.x * MAP_W, -b.y * MAP_H)
            line:Show()
        end
    end
end

local function DrawPins(d)
    -- pins are indexed by boss number, with gaps for bosses on other floors: ipairs would stop at the
    -- first gap and leave the later pins on screen, so walk them all with pairs
    for _, p in pairs(pins) do p:Hide(); p.pulse:Stop() end
    if not d.floors[view.floor] then return end
    local nextBoss = ns.NextBoss(view.instanceID)
    for i, b in ipairs(d.bosses) do
        if b.floor == view.floor and b.x then
            local p = pins[i] or CreatePin(i)
            p.boss, p.index = b, i
            p:ClearAllPoints()
            -- Pin positions are fractions of the 1002 x 668 map area.
            p:SetPoint("CENTER", f.canvas, "TOPLEFT", b.x * MAP_W, -b.y * MAP_H)
            local killed = ns.IsKilled(view.instanceID, b)
            local c = (fighting == b and COLORS.fight) or (killed and COLORS.killed)
                or (b == nextBoss and COLORS.nextUp) or COLORS.normal
            p.dot:SetVertexColor(c[1], c[2], c[3])
            p.num:SetText(killed and "" or i)
            p.num:SetTextColor(b == nextBoss and 0 or 1, b == nextBoss and 0 or 1, b == nextBoss and 0 or 1)
            p.check:SetShown(killed)
            p.glow:SetShown(b == nextBoss or fighting == b)
            if b == nextBoss or fighting == b then p.pulse:Play() end
            p:Show()
        end
    end
end

local function DrawList(d)
    local nextBoss = ns.NextBoss(view.instanceID)
    for i = 1, math.max(#rows, #d.bosses) do
        local b = d.bosses[i]
        if b and i <= MAX_ROWS then
            local r = rows[i] or CreateRow(i)
            r.boss, r.index = b, i
            local killed = ns.IsKilled(view.instanceID, b)
            local color = (fighting == b and "ffff4040") or (killed and "ff808080")
                or (b == nextBoss and "ffffd100") or "ffffffff"
            local where = ""
            if b.floor and b.floor ~= view.floor and #d.floors > 1 then where = " |cff808080(other floor)|r" end
            if ns.db.placer and not b.x then where = where .. " |cff40d0ff(no pin yet)|r" end
            if ns.db.placer and placing == i then color = "ff40d0ff" end
            r.text:SetText(("|c%s%d. %s|r%s"):format(color, i, b.name, where))
            r.check:SetShown(killed)
            r:Show()
        elseif rows[i] then
            rows[i]:Hide()
        end
    end
end

function ns.Refresh()
    if not (f and f:IsShown() and view.instanceID) then return end
    local d = ns.Dungeons[view.instanceID]
    local hasArt = #d.floors > 0
    local floor = hasArt and d.floors[view.floor]

    for i, t in ipairs(f.tiles) do
        if floor then t:SetTexture(floor.tiles[i]); t:Show() else t:Hide() end
    end
    f.noArt:SetShown(not hasArt)
    f.credit:SetText(floor and floor.credit and ("Map by " .. floor.credit .. " - sreyesmaps.com") or "")

    local killed, total = ns.KillCount(view.instanceID)
    f.title:SetText(d.name)
    local lo, hi = tostring(d.levels):match("^(%d+)%-(%d+)$")
    if not lo then lo = tostring(d.levels):match("^(%d+)$"); hi = lo end
    local levels = lo and ns.LevelsColored(tonumber(lo), tonumber(hi)) or tostring(d.levels)
    local tag = (d.raid and "Raid " or "Level ") .. levels
    f.subtitle:SetText(("%s   |cffffd100%d/%d bosses|r%s"):format(tag, killed, total, d.new and "   |cff20ff20New in Forever|r" or ""))

    f.prev:SetShown(#d.floors > 1)
    f.next:SetShown(#d.floors > 1)
    if floor then
        f.floorText:SetText(#d.floors > 1 and ("Floor %d of %d: %s"):format(view.floor, #d.floors, floor.name) or floor.name)
    else
        f.floorText:SetText("")
    end
    f.prev:SetEnabled(view.floor ~= nil and view.floor > 1)
    f.next:SetEnabled(view.floor ~= nil and view.floor < #d.floors)
    f.live:SetText(ns.db.liveView and "Live: on" or "Live view")

    DrawRoute(d)
    DrawPins(d)
    DrawList(d)
    ns.UpdateLocationText()
    ns.UpdateYouAreHere()
    ns.UpdatePlacerUI()
end

-------------------------------------------------------------------------------
-- Mapmaker mode: place a boss's pin (Options > "Help map the bosses")
-------------------------------------------------------------------------------

function ns.UpdatePlacerUI()
    if not f then return end
    local d = view.instanceID and ns.Dungeons[view.instanceID]
    local boss = d and placing and d.bosses[placing]
    f.canvas:EnableMouse(boss ~= nil)
    if boss then
        f.placeStatus:SetText(("Placing %s: click the map where it is. Right-click the map to cancel."):format(boss.name))
        f.placeStatus:Show()
        f.placeRemove:SetShown(ns.HasBossPlace(view.instanceID, boss))
    else
        f.placeStatus:Hide()
        f.placeRemove:Hide()
    end
    f.listHint:SetText(ns.db.placer and "Mapmaker mode: click a boss, then click the map. Right-click a boss: mark killed."
        or f.listHintDefault)
end

function ns.StartPlacing(index)
    if not (ns.db.placer and view.instanceID and view.floor) then return end
    placing = index
    ns.Refresh()
end

function ns.CancelPlacing()
    placing = nil
    ns.Refresh()
end

-- x and y: where the player clicked, as fractions of the map picture.
function ns.PlaceAt(x, y)
    local d = view.instanceID and ns.Dungeons[view.instanceID]
    local boss = d and placing and d.bosses[placing]
    if not (boss and view.floor) or x < 0 or x > 1 or y < 0 or y > 1 then return end
    ns.SetBossPlace(view.instanceID, boss, view.floor, x, y)
    ns.Print(("%s: pin placed. Thank you! Use \"Share my boss pins\" in the options to send it in."):format(boss.name))
    placing = nil
    ns.Refresh()
end

-- Puts the "you are here" marker on the anchor for the player's current sub-zone, if it is on this floor.
function ns.UpdateYouAreHere()
    if not (f and f.here) then return end
    f.here:Hide()
    if not (f:IsShown() and view.instanceID and view.floor) then return end
    if ns.CurrentInstance() ~= view.instanceID then return end
    local a = ns.CurrentAnchor(view.instanceID)
    if a and (a.floor or 1) == view.floor then
        f.here.anchor = a
        f.here:ClearAllPoints()
        f.here:SetPoint("CENTER", f.canvas, "TOPLEFT", a.x * MAP_W, -a.y * MAP_H)
        f.here:Show()
    end
end

-- The "where am I" line: the named area from the game, plus the next boss.
function ns.UpdateLocationText()
    if not (f and f:IsShown() and view.instanceID) then return end
    local here = ns.CurrentInstance()
    local parts = {}
    if here == view.instanceID then
        local sub = ns.Safe(GetSubZoneText())
        if sub and sub ~= "" then parts[#parts + 1] = "Area: |cffffffff" .. sub .. "|r" end
    else
        parts[#parts + 1] = "|cff808080Viewing only (you are not in this dungeon)|r"
    end
    local nextBoss, i = ns.NextBoss(view.instanceID)
    if fighting then
        parts[#parts + 1] = "Fighting: |cffff4040" .. fighting.name .. "|r"
    elseif nextBoss then
        local where = ""
        local d = ns.Dungeons[view.instanceID]
        if nextBoss.floor and view.floor and nextBoss.floor ~= view.floor and d.floors[nextBoss.floor] then
            where = " (on " .. d.floors[nextBoss.floor].name .. ")"
        end
        parts[#parts + 1] = ("Next boss: |cffffd100%d. %s%s|r"):format(i, nextBoss.name, where)
    else
        parts[#parts + 1] = "|cff20ff20All bosses defeated|r"
    end
    f.location:SetText(table.concat(parts, "     "))
end

-------------------------------------------------------------------------------
-- Public API used by Core.lua
-------------------------------------------------------------------------------

function ns.ShowDungeon(instanceID, floor)
    if ns.CurrentInstance() == instanceID then ns.SyncKillsFromGame(instanceID) end
    if not f then Create() end
    local d = ns.Dungeons[instanceID]
    if not d then return end
    if view.instanceID ~= instanceID then fighting = nil end
    view.instanceID = instanceID
    if #d.floors > 0 then
        floor = floor or ns.db.floors[instanceID] or 1
        view.floor = math.max(1, math.min(#d.floors, floor))
        ns.db.floors[instanceID] = view.floor
    else
        view.floor = nil
    end
    ns.db.lastViewed = instanceID
    f:Show()
    ns.Refresh()
end

-- Turn to a floor, but only if the map is already showing that dungeon.
function ns.ShowFloorIfViewing(instanceID, floor)
    if f and f:IsShown() and view.instanceID == instanceID then
        if view.floor ~= floor then ns.ShowDungeon(instanceID, floor) end
    elseif ns.db then
        ns.db.floors[instanceID] = floor
    end
end

function ns.StepFloor(delta)
    if view.instanceID and view.floor then ns.ShowDungeon(view.instanceID, view.floor + delta) end
end

function ns.SetFighting(boss)
    fighting = boss
    ns.Refresh()
end

function ns.ViewedInstance() return view.instanceID end

function ns.HideMap() if f then f:Hide() end end

-- The last dungeon looked at, or the list to pick one from.
function ns.ShowLastDungeon()
    if ns.db.lastViewed and ns.Dungeons[ns.db.lastViewed] then
        ns.ShowDungeon(ns.db.lastViewed)
    else
        ns.ShowDungeonMenu()
    end
end

-- The map button and key: in a dungeon, its map; outside, the world map where the player is (so a
-- dungeon icon on it leads to the dungeon's map), unless the player turned that off in the options.
function ns.ToggleMap()
    if f and f:IsShown() then return f:Hide() end
    if ns.WorldMapShown() then return ns.HideWorldMap() end
    local id = ns.CurrentInstance()
    if id then
        ns.ShowDungeon(id, ns.GuessFloor(id))
    elseif ns.db.worldFirst ~= false then
        ns.ShowWorldMap()
    else
        ns.ShowLastDungeon()
    end
end

function ns.ApplyScale()
    if f then f:SetScale(ns.db.scale or 1) end
end

function ns.ShowDungeonMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Print("Dungeons:")
        for _, id in ipairs(ns.DungeonOrder) do ns.Print(id, ns.Dungeons[id].name) end
        ns.Print("Options: /fd options")
        return
    end
    MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
        root:CreateTitle("Dungeons (colours show the difficulty for your level)")
        local raids = {}
        for _, id in ipairs(ns.DungeonOrder) do
            local d = ns.Dungeons[id]
            if d.raid then
                raids[#raids + 1] = id
            else
                local lo, hi = tostring(d.levels):match("^(%d+)%-(%d+)$")
                local levels = lo and ns.LevelsColored(tonumber(lo), tonumber(hi)) or tostring(d.levels)
                local label = ("%s (%s)%s"):format(d.name, levels, d.new and " |cff20ff20new|r" or "")
                root:CreateButton(label, function() ns.ShowDungeon(id) end)
            end
        end
        if #raids > 0 then
            root:CreateDivider()
            root:CreateTitle("Raids")
            for _, id in ipairs(raids) do
                root:CreateButton(ns.Dungeons[id].name, function() ns.ShowDungeon(id) end)
            end
        end
        root:CreateDivider()
        root:CreateButton("World map", function() ns.ShowWorldMap() end)
        root:CreateButton("Options", function() ns.OpenOptions() end)
        root:CreateButton("Welcome tips", function() ns.ShowWelcome(true) end)
    end)
end
