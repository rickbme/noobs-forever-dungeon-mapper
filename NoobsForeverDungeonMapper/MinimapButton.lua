-- Noobs Forever Dungeon Mapper: minimap button.
-- Left-click toggles the map, right-click picks a dungeon, drag moves the button around the
-- minimap's edge. Uses the classic minimap-button textures, which the Forever client still has.
local ADDON, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local button

local atan2 = math.atan2 or function(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    return y > 0 and math.pi / 2 or (y < 0 and -math.pi / 2 or 0)
end

local function Place()
    local angle = math.rad(ns.db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimapAngle = math.deg(atan2(cy / scale - my, cx / scale - mx))
    Place()
end

local function Create()
    button = CreateFrame("Button", "NoobsForeverDungeonMapperMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    -- The ring sits in the top-left of this texture, as with Blizzard's own minimap buttons.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", 1, -1) end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("CENTER") end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        icon:SetPoint("CENTER")
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then ns.ShowDungeonMenu(self) else ns.ToggleMap() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Noobs Forever Dungeon Mapper")
        GameTooltip:AddLine("Left-click: show or hide the map", 1, 1, 1)
        GameTooltip:AddLine("Right-click: pick a dungeon, the world map, or the options", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    Place()
end

function ns.MinimapButton_Update()
    if not (ns.db and Minimap) then return end
    if ns.db.minimapButton == false then
        if button then button:Hide() end
        return
    end
    if not button then Create() end
    button:Show()
end

function ns.MinimapButton_Toggle()
    ns.db.minimapButton = ns.db.minimapButton == false
    ns.MinimapButton_Update()
    ns.Print("Minimap button: " .. (ns.db.minimapButton and "shown" or "hidden (use /fd to open the map)"))
end

-- Back to the normal spot on the minimap's edge, and shown.
function ns.MinimapButton_Reset()
    ns.db.minimapAngle = ns.DEFAULTS.minimapAngle
    ns.db.minimapButton = true
    ns.MinimapButton_Update()
    if button then Place() end
    if ns.OptionsRefresh then ns.OptionsRefresh() end
end
