-- Noobs Forever Dungeon Mapper: see-through while you move.
-- While the player is walking, the map windows fade to a lower opacity so they can see where they are
-- going, and fade back when they stop. Moving is read from IsPlayerMoving / GetUnitSpeed. A map the mouse
-- is over stays at its normal opacity, so it can still be read and clicked. Options: "See the game
-- through the maps while I move" (default on) and "Opacity while moving".
local ADDON, ns = ...

local FADE_SPEED = 4      -- opacity per second: a full change takes about a quarter of a second
local CHECK_EVERY = 0.1   -- how often to ask the game whether the player is moving
local WINDOWS = { "NoobsForeverDungeonMapperFrame", "NoobsForeverDungeonMapperWorld" }

local current  -- the opacity the windows have right now
local moving = false
local sinceCheck = 0

local function IsMoving()
    if IsPlayerMoving then
        local ok, m = pcall(IsPlayerMoving)
        if ok and ns.Safe(m) then return true end
    end
    if GetUnitSpeed then
        local ok, speed = pcall(GetUnitSpeed, "player")
        speed = ok and ns.Safe(speed) or nil
        if type(speed) == "number" and speed > 0 then return true end
    end
    return false
end

local function Hovered()
    for _, name in ipairs(WINDOWS) do
        local w = _G[name]
        if w and w:IsShown() and w:IsMouseOver() then return true end
    end
    return false
end

local function AnyShown()
    for _, name in ipairs(WINDOWS) do
        local w = _G[name]
        if w and w:IsShown() then return true end
    end
    return false
end

-- The opacity the windows should have now: the normal one, or the lower "moving" one.
function ns.TargetOpacity()
    local idle = ns.db.opacity or 1
    if ns.db.moveFade ~= false and moving and not Hovered() then
        return math.min(idle, ns.db.moveOpacity or 0.35)
    end
    return idle
end

function ns.CurrentMapAlpha()
    if not current then current = ns.TargetOpacity() end
    return current
end

-- Jump to the right opacity at once (a window was just opened, or an option changed).
function ns.SnapOpacity()
    current = ns.TargetOpacity()
    ns.ApplyOpacity()
end

-- Move toward the target a little: called every frame while a map is open.
function ns.StepFade(elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck >= CHECK_EVERY then
        sinceCheck = 0
        moving = IsMoving()
    end
    local target = ns.TargetOpacity()
    if not current then current = target end
    if math.abs(current - target) < 0.001 then return end
    local step = FADE_SPEED * elapsed
    if current < target then current = math.min(target, current + step) else current = math.max(target, current - step) end
    ns.ApplyOpacity()
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if ns.db and AnyShown() then ns.StepFade(elapsed) end
end)
