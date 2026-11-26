-- Noobs Forever Dungeon Mapper: "live view".
-- Addons cannot read the player's position inside a dungeon, but the game's own minimap still
-- draws it. Live view simply makes the minimap bigger while you are in a dungeon and puts it
-- back when you leave. Only the minimap's own scale is changed (never its container, which
-- Blizzard's Edit Mode manages), and never during combat.
local ADDON, ns = ...

local enlarged = false
local savedScale

local function Apply(want)
    if want == enlarged then return end
    if InCombatLockdown() then return end -- PLAYER_REGEN_ENABLED calls us again after combat
    if not Minimap then return end
    if want then
        savedScale = Minimap:GetScale()
        Minimap:SetScale(ns.db.liveScale or 1.8)
    else
        Minimap:SetScale(savedScale or 1)
    end
    enlarged = want
end

-- After the player changes the Live view size: apply it now if the minimap is already enlarged.
function ns.LiveView_Rescale()
    if enlarged and Minimap and not InCombatLockdown() then Minimap:SetScale(ns.db.liveScale or 1.8) end
end

function ns.LiveView_Update()
    if not ns.db then return end
    Apply(ns.db.liveView and ns.CurrentInstance() ~= nil)
end

function ns.LiveView_Toggle()
    ns.db.liveView = not ns.db.liveView
    ns.LiveView_Update()
    if ns.db.liveView and not ns.CurrentInstance() then
        ns.Print("Live view is on. It enlarges the minimap when you enter a dungeon.")
    else
        ns.Print("Live view: " .. (ns.db.liveView and "on" or "off"))
    end
    ns.Refresh()
end
