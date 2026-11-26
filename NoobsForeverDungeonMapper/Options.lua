-- Noobs Forever Dungeon Mapper: everything that can be done without typing a command.
--   * an Options window (opened from the map window, the minimap button's right-click menu,
--     the game's Options > AddOns list, or /fd options)
--   * a welcome popup the first time the addon runs, explaining the basics
--   * a key binding to show or hide the map (Options > Keybindings > AddOns)
-- It draws its own checkboxes from classic textures instead of a Blizzard template, so a template
-- that changed in this client cannot stop the addon from loading.
local ADDON, ns = ...

local WIDTH = 400
local opt, welcome
local checks = {}

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
    b.text:SetWidth(WIDTH - 90)
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

local function Header(parent, text, y)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 18, y)
    h:SetText(text)
    return h
end

-------------------------------------------------------------------------------
-- The options window
-------------------------------------------------------------------------------

local function CreateOptions()
    opt = CreateFrame("Frame", "NoobsForeverDungeonMapperOptions", UIParent, "BackdropTemplate")
    opt:SetSize(WIDTH, 664)
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

    local y = -64
    Header(opt, "While playing", y)
    y = y - 24
    for _, def in ipairs(SETTINGS) do
        Check(opt, def, 16, y)
        y = y - 30
    end

    y = y - 6
    Header(opt, "Map window size", y)
    opt.scaleText = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    opt.scaleText:SetPoint("TOPLEFT", 190, y)
    opt.smaller = Button(opt, "-", 28)
    opt.smaller:SetPoint("TOPLEFT", 120, y + 5)
    opt.larger = Button(opt, "+", 28)
    opt.larger:SetPoint("LEFT", opt.smaller, "RIGHT", 4, 0)
    opt.scaleText:ClearAllPoints()
    opt.scaleText:SetPoint("LEFT", opt.larger, "RIGHT", 10, 0)
    local function Step(delta)
        ns.db.scale = math.floor(math.min(2, math.max(0.5, (ns.db.scale or 1) + delta)) * 10 + 0.5) / 10
        ns.ApplyScale()
        ns.OptionsRefresh()
    end
    opt.smaller:SetScript("OnClick", function() Step(-0.1) end)
    opt.larger:SetScript("OnClick", function() Step(0.1) end)
    y = y - 40

    Header(opt, "Boss progress", y)
    y = y - 26
    opt.clear = Button(opt, "Clear boss kills for the dungeon I'm viewing", 330)
    opt.clear:SetPoint("TOPLEFT", 20, y)
    opt.clear:SetScript("OnClick", function()
        local id = ns.ViewedInstance() or ns.CurrentInstance()
        if id then
            ns.ResetRun(id)
            ns.Print("Boss kills cleared for " .. ns.Dungeons[id].name .. ".")
        else
            ns.Print("Open a dungeon's map first, then press this button.")
        end
    end)
    Tip(opt.clear, "Starts the dungeon's boss list over. This also happens by itself when the game resets the dungeon.")
    y = y - 40

    Header(opt, "Help", y)
    y = y - 26
    opt.tips = Button(opt, "Show the welcome tips", 160)
    opt.tips:SetPoint("TOPLEFT", 20, y)
    opt.tips:SetScript("OnClick", function() ns.ShowWelcome(true) end)
    opt.pick = Button(opt, "Choose a dungeon", 160)
    opt.pick:SetPoint("LEFT", opt.tips, "RIGHT", 10, 0)
    opt.pick:SetScript("OnClick", function(self) ns.ShowDungeonMenu(self) end)
    opt.world = Button(opt, "Open the world map", 330)
    opt.world:SetPoint("TOPLEFT", opt.tips, "BOTTOMLEFT", 0, -6)
    opt.world:SetScript("OnClick", function() ns.ShowWorldMap() end)
    y = y - 70

    Header(opt, "For testers and mapmakers", y)
    y = y - 24
    for _, def in ipairs(TESTER_SETTINGS) do
        Check(opt, def, 16, y)
        y = y - 30
    end
    opt.share = Button(opt, "Share my boss pins", 330)
    opt.share:SetPoint("TOPLEFT", 20, y)
    opt.share:SetScript("OnClick", function() ns.ShowShareWindow() end)
    Tip(opt.share, "Shows the pins you placed as text you can copy and send to the mapmakers.")
    y = y - 32
    opt.probe = Button(opt, "Check what the game tells addons", 330)
    opt.probe:SetPoint("TOPLEFT", 20, y)
    opt.probe:SetScript("OnClick", function() ns.Probe("") end)
    Tip(opt.probe, "Prints a short report in your chat window. Most useful while standing inside a dungeon.")

    opt:Hide()
end

function ns.OptionsRefresh()
    if not opt then return end
    for _, b in ipairs(checks) do b.mark:SetShown(b.def.get() and true or false) end
    opt.scaleText:SetText(("%d%%"):format((ns.db.scale or 1) * 100 + 0.5))
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

local function RegisterSettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "Noobs Forever Dungeon Mapper"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    note:SetText("Dungeon maps, boss progress and area markers for WoW Forever.")
    local button = Button(panel, "Open the options", 200)
    button:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)
    button:SetScript("OnClick", function()
        if HideUIPanel and SettingsPanel then HideUIPanel(SettingsPanel) end
        ns.OpenOptions()
    end)
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
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
