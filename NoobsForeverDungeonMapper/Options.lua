-- Noobs Forever Dungeon Mapper: everything that can be done without typing a command.
--   * an Options window (opened from the map window, the minimap button's right-click menu,
--     the game's Options > AddOns list, or /fd options)
--   * a welcome popup the first time the addon runs, explaining the basics
--   * a key binding to show or hide the map (Options > Keybindings > AddOns)
-- It draws its own checkboxes from classic textures instead of a Blizzard template, so a template
-- that changed in this client cannot stop the addon from loading.
local ADDON, ns = ...

local opt, welcome

-------------------------------------------------------------------------------
-- Settings, as the player sees them
-------------------------------------------------------------------------------

local function DB(key, default)
    return function() if ns.db[key] == nil then return default end return ns.db[key] end
end

local SETTINGS = {
    { label = "Open the map by itself when I enter a dungeon",
      tip = "The map appears as soon as you zone in. You can still open it any time from the minimap button.",
      get = DB("autoOpen", true), set = function(v) ns.db.autoOpen = v end },
    { label = "Outside dungeons, open the world map where I am",
      tip = "The map button then shows the world map. Click a dungeon icon on it to open that dungeon's map. Turn off to get the last dungeon's map instead.",
      get = DB("worldFirst", true), set = function(v) ns.db.worldFirst = v end },
    { label = "Show the boss order as lines on the map",
      tip = "Lines join the bosses in the order the game lists them, to help you find your way. They show the order, not the exact path to walk.",
      get = DB("route", true), set = function(v) ns.db.route = v; ns.Refresh() end },
    { label = "Close the map when I leave the dungeon",
      get = DB("autoClose", true), set = function(v) ns.db.autoClose = v end },
    { label = "Turn to the next boss's floor after a kill",
      tip = "After you defeat a boss, the map switches to the floor of the next boss.",
      get = DB("followProgress", true), set = function(v) ns.db.followProgress = v end },
    { label = "Show the minimap button",
      tip = "If you hide it, open the map with the key binding, the AddOns list button, or /fd.",
      get = function() return ns.db.minimapButton ~= false end,
      set = function(v) ns.db.minimapButton = v; ns.MinimapButton_Update() end },
    { label = "Enlarge my minimap inside dungeons (Live view)",
      tip = "The minimap is the only place the game still shows your exact position inside a dungeon. This makes it bigger there.",
      get = DB("liveView", false),
      set = function(v) if (ns.db.liveView and true or false) ~= v then ns.LiveView_Toggle() end end },
}

local TESTER_SETTINGS = {
    { label = "Help map the bosses (place pins on the map)",
      tip = "Click a boss in the map's list, then click where it is on the map. Great for bosses that have no pin yet.",
      get = DB("placer", false), set = function(v) ns.db.placer = v; ns.CancelPlacing(); ns.Refresh() end },
    { label = "Record the area names I walk through",
      tip = "Helps the mapmakers add \"you are here\" areas. Saved in your game files; nothing is sent anywhere.",
      get = DB("probeLog", false), set = function(v) ns.db.probeLog = v end },
}

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------

local COL_W = 310   -- one column of the options
local checks, refreshers = {}, {}
ns.OptionsChecks = checks -- (the offline tests count them)

local function Backdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
end

local function Button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    return b
end

local function Tip(widget, text)
    if not text then return end
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", GameTooltip_Hide)
end

local function Check(parent, def, x, y)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b:SetPoint("TOPLEFT", x, y)
    b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    b.mark:SetAllPoints()
    b.text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
    b.text:SetWidth(COL_W - 36)
    b.text:SetJustifyH("LEFT")
    b.text:SetText(def.label)
    b.def = def
    b:SetScript("OnClick", function(self)
        self.def.set(not self.def.get())
        ns.OptionsRefresh()
    end)
    Tip(b, def.tip)
    checks[#checks + 1] = b
    return b
end

local function Header(parent, text, x, y)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", x, y)
    h:SetText(text)
    return h
end

-- A number with - and + buttons (a size, an opacity): label, buttons, current value.
local function Stepper(parent, def, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    label:SetText(def.label)
    local minus = Button(parent, "-", 26)
    minus:SetPoint("TOPLEFT", x + 158, y + 6)
    local plus = Button(parent, "+", 26)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("LEFT", plus, "RIGHT", 10, 0)
    local function Step(direction)
        local v = def.get() + direction * def.step
        def.set(math.floor(math.min(def.max, math.max(def.min, v)) * 100 + 0.5) / 100)
        ns.OptionsRefresh()
    end
    minus:SetScript("OnClick", function() Step(-1) end)
    plus:SetScript("OnClick", function() Step(1) end)
    Tip(minus, def.tip)
    Tip(plus, def.tip)
    refreshers[#refreshers + 1] = function()
        local v = def.get()
        value:SetText(def.fmt(v))
        minus:SetEnabled(v > def.min + 0.001)
        plus:SetEnabled(v < def.max - 0.001)
    end
    return { minus = minus, plus = plus, value = value }
end

local function Percent(v) return ("%d%%"):format(v * 100 + 0.5) end

local STEPPERS = {
    { key = "scale", label = "Map window size", step = 0.1, min = 0.5, max = 2, fmt = Percent,
      tip = "Makes the map windows bigger or smaller.",
      get = function() return ns.db.scale or 1 end,
      set = function(v) ns.db.scale = v; ns.ApplyScale() end },
    { key = "opacity", label = "Map opacity (lower = see-through)", step = 0.1, min = 0.3, max = 1, fmt = Percent,
      tip = "Lower numbers make the map windows see-through, so you can see the game behind them.",
      get = function() return ns.db.opacity or 1 end,
      set = function(v) ns.db.opacity = v; ns.ApplyOpacity() end },
    { key = "liveScale", label = "Live view minimap size", step = 0.2, min = 1.2, max = 2.6, fmt = Percent,
      tip = "How much bigger Live view makes your minimap inside a dungeon.",
      get = function() return ns.db.liveScale or 1.8 end,
      set = function(v) ns.db.liveScale = v; ns.LiveView_Rescale() end },
}

-- The settings that are plain on/off or numbers (not the run data, floors or placed pins).
local OPTION_KEYS = { "autoOpen", "autoClose", "followProgress", "scale", "opacity", "liveView", "liveScale",
    "minimapButton", "worldFirst", "route", "placer", "probeLog", "panel" }

local function ResetOptions()
    for _, k in ipairs(OPTION_KEYS) do
        local v = ns.DEFAULTS[k]
        ns.db[k] = type(v) == "table" and {} or v
    end
    ns.ApplyScale()
    ns.ApplyOpacity()
    ns.MinimapButton_Update()
    ns.LiveView_Update()
    ns.CancelPlacing()
    ns.Refresh()
    ns.OptionsRefresh()
    ns.Print("Options are back to normal.")
end

-- Fills a frame with all the options, in two columns. Used for our own Options window and for the
-- page in the game's Options > AddOns, so the two always agree.
local function BuildOptions(parent)
    local L, R = 18, 18 + COL_W + 24
    local parts = { steppers = {} }

    local y = -64
    Header(parent, "While playing", L, y)
    y = y - 24
    for _, def in ipairs(SETTINGS) do
        Check(parent, def, L - 2, y)
        y = y - 30
    end
    y = y - 8
    Header(parent, "Look and feel", L, y)
    y = y - 30
    for _, def in ipairs(STEPPERS) do
        parts.steppers[def.key] = Stepper(parent, def, L, y)
        y = y - 36
    end

    y = -64
    Header(parent, "Boss progress", R, y)
    y = y - 26
    local clear = Button(parent, "Clear boss kills for the dungeon I'm viewing", COL_W - 6)
    clear:SetPoint("TOPLEFT", R, y)
    clear:SetScript("OnClick", function()
        local id = ns.ViewedInstance() or ns.CurrentInstance()
        if id then
            ns.ResetRun(id)
            ns.Print("Boss kills cleared for " .. ns.Dungeons[id].name .. ".")
        else
            ns.Print("Open a dungeon's map first, then press this button.")
        end
    end)
    Tip(clear, "Starts the dungeon's boss list over. This also happens by itself when the game resets the dungeon.")
    parts.clear = clear
    y = y - 40

    Header(parent, "Minimap button", R, y)
    y = y - 26
    local reset = Button(parent, "Put the minimap button back", COL_W - 6)
    reset:SetPoint("TOPLEFT", R, y)
    reset:SetScript("OnClick", function() ns.MinimapButton_Reset() end)
    Tip(reset, "Moves the minimap button back to its normal spot and shows it.")
    y = y - 40

    Header(parent, "Help", R, y)
    y = y - 26
    local tips = Button(parent, "Show the welcome tips", COL_W - 6)
    tips:SetPoint("TOPLEFT", R, y)
    tips:SetScript("OnClick", function() ns.ShowWelcome(true) end)
    y = y - 28
    local pick = Button(parent, "Choose a dungeon", COL_W - 6)
    pick:SetPoint("TOPLEFT", R, y)
    pick:SetScript("OnClick", function(self) ns.ShowDungeonMenu(self) end)
    y = y - 28
    local world = Button(parent, "Open the world map", COL_W - 6)
    world:SetPoint("TOPLEFT", R, y)
    world:SetScript("OnClick", function() ns.ShowWorldMap() end)
    y = y - 30
    local keys = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    keys:SetPoint("TOPLEFT", R, y)
    keys:SetWidth(COL_W - 6)
    keys:SetJustifyH("LEFT")
    keys:SetText("Key bindings: Esc > Options > Keybindings > AddOns")
    y = y - 28

    Header(parent, "For testers and mapmakers", R, y)
    y = y - 24
    for _, def in ipairs(TESTER_SETTINGS) do
        Check(parent, def, R - 2, y)
        y = y - 30
    end
    local share = Button(parent, "Share my boss pins", COL_W - 6)
    share:SetPoint("TOPLEFT", R, y)
    share:SetScript("OnClick", function() ns.ShowShareWindow() end)
    Tip(share, "Shows the pins you placed as text you can copy and send to the mapmakers.")
    y = y - 28
    local probe = Button(parent, "Check what the game tells addons", COL_W - 6)
    probe:SetPoint("TOPLEFT", R, y)
    probe:SetScript("OnClick", function() ns.Probe("") end)
    Tip(probe, "Prints a short report in your chat window. Most useful while standing inside a dungeon.")
    y = y - 36

    local reset_all = Button(parent, "Reset all these options to normal", COL_W - 6)
    reset_all:SetPoint("TOPLEFT", R, y)
    reset_all:SetScript("OnClick", ResetOptions)
    Tip(reset_all, "Puts every option on this page back to how it was when you first installed. Your boss kills and placed pins are kept.")
    parts.resetAll = reset_all
    return parts
end

-------------------------------------------------------------------------------
-- The options window
-------------------------------------------------------------------------------

local function CreateOptions()
    opt = CreateFrame("Frame", "NoobsForeverDungeonMapperOptions", UIParent, "BackdropTemplate")
    opt:SetSize(2 * COL_W + 78, 540)
    opt:SetPoint("CENTER")
    opt:SetFrameStrata("DIALOG")
    opt:SetToplevel(true)
    opt:SetClampedToScreen(true)
    opt:SetMovable(true)
    opt:EnableMouse(true)
    opt:RegisterForDrag("LeftButton")
    opt:SetScript("OnDragStart", opt.StartMoving)
    opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
    Backdrop(opt)
    tinsert(UISpecialFrames, "NoobsForeverDungeonMapperOptions")

    local close = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local title = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Noobs Forever Dungeon Mapper")
    local sub = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Options. Click a box to turn something on or off; changes apply right away.")
    opt.parts = BuildOptions(opt)
    opt:Hide()
end

function ns.OptionsRefresh()
    for _, b in ipairs(checks) do b.mark:SetShown(b.def.get() and true or false) end
    for _, refresh in ipairs(refreshers) do refresh() end
end

function ns.OpenOptions()
    if not opt then CreateOptions() end
    opt:Show()
    ns.OptionsRefresh()
end

function ns.ToggleOptions()
    if opt and opt:IsShown() then opt:Hide() else ns.OpenOptions() end
end

-------------------------------------------------------------------------------
-- Welcome popup
-------------------------------------------------------------------------------

local WELCOME = table.concat({
    "|cffffd100Walk into a dungeon|r and its map opens by itself.",
    "",
    "|cffffd100The map icon on your minimap|r shows or hides the map. Outside a dungeon it opens the world map where you are: click a dungeon icon on it to see that dungeon's map. Right-click the icon for the list of dungeons and the options.",
    "",
    "|cffffd100In the map:|r click a boss on the list to find it, right-click a boss to tick it off. The blue marker shows the area you are in.",
    "",
    "|cffffd100Everything can be changed in Options.|r No typing needed.",
}, "\n")

local function CreateWelcome()
    welcome = CreateFrame("Frame", "NoobsForeverDungeonMapperWelcome", UIParent, "BackdropTemplate")
    welcome:SetSize(420, 360)
    welcome:SetPoint("CENTER", 0, 60)
    welcome:SetFrameStrata("DIALOG")
    welcome:SetToplevel(true)
    welcome:EnableMouse(true)
    Backdrop(welcome)
    tinsert(UISpecialFrames, "NoobsForeverDungeonMapperWelcome")

    local title = welcome:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Welcome to Noobs Forever Dungeon Mapper!")
    local body = welcome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 24, -52)
    body:SetWidth(372)
    body:SetJustifyH("LEFT")
    body:SetText(WELCOME)

    local function Close()
        ns.db.welcomed = true
        welcome:Hide()
    end
    local open = Button(welcome, "Pick a dungeon", 120)
    open:SetPoint("BOTTOMLEFT", 24, 22)
    open:SetScript("OnClick", function(self) ns.ShowDungeonMenu(self) end)
    local options = Button(welcome, "Options", 100)
    options:SetPoint("LEFT", open, "RIGHT", 8, 0)
    options:SetScript("OnClick", function() ns.OpenOptions() end)
    local done = Button(welcome, "Got it", 100)
    done:SetPoint("BOTTOMRIGHT", -24, 22)
    done:SetScript("OnClick", Close)
    welcome:SetScript("OnHide", function() ns.db.welcomed = true end)
    welcome:Hide()
end

-- force: show it even if the player has seen it before.
function ns.ShowWelcome(force)
    if not force and ns.db.welcomed then return end
    if not welcome then CreateWelcome() end
    welcome:Show()
end

-- Called when the player enters the world; only the first time ever.
function ns.MaybeShowWelcome()
    if ns.db and not ns.db.welcomed and not ns.CurrentInstance() then ns.ShowWelcome() end
end

-------------------------------------------------------------------------------
-- The game's own Options > AddOns list, and the key binding
-------------------------------------------------------------------------------

-- The page in the game's Options > AddOns: all of our options, laid out the same as our own window.
local function RegisterSettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "Noobs Forever Dungeon Mapper"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(panel.name)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    note:SetText("Dungeon maps, boss progress and area markers for WoW Forever. Changes apply right away.")
    panel.parts = BuildOptions(panel)
    panel:SetScript("OnShow", function() ns.OptionsRefresh() end)
    ns.settingsPanel = panel
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
    ns.OptionsRefresh()
end

BINDING_HEADER_NOOBSFOREVERDUNGEONMAPPER = "Noobs Forever Dungeon Mapper"
BINDING_NAME_NOOBSFOREVERDUNGEONMAPPER_TOGGLE = "Show or hide the dungeon map"
BINDING_NAME_NOOBSFOREVERDUNGEONMAPPER_OPTIONS = "Open the options"
BINDING_NAME_NOOBSFOREVERDUNGEONMAPPER_WORLD = "Show or hide the world map"
function NoobsForeverDungeonMapper_Binding(action)
    if action == "options" then ns.ToggleOptions()
    elseif action == "world" then ns.ToggleWorldMap()
    else ns.ToggleMap() end
end

function ns.Options_Init()
    pcall(RegisterSettingsPage) -- a change in the settings API must not stop the addon loading
end
