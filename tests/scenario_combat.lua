-- Protected frames in combat: the real client blocks moving, showing, hiding or changing a secure
-- button in combat, anchoring one to a texture at any time, and showing a frame that has a secure child.
local ns = NS
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end
COMBAT = false
InCombatLockdown = function() return COMBAT end
local realCreate = CreateFrame
CreateFrame = function(kind, name, parent, template)
  local f = realCreate(kind, name, parent, template)
  if template and template:find("Secure") then
    local mt = getmetatable(f); local base = mt.__index
    if parent then parent._secureChild = true end
    mt.__index = function(t, k)
      local v = base(t, k)
      if k == "SetPoint" then return function(self, p, rel, ...)
        if COMBAT then error("Action[SetPoint] failed: in combat") end
        if type(rel) == "table" and rel._name == "child" then error("Action[SetPoint] failed because[Cannot anchor protected frames to regions]") end
      end end
      if k == "Show" or k == "Hide" or k == "SetAttribute" or k == "SetShown" then return function(self, ...)
        if COMBAT then error("Action[" .. k .. "] failed: protected frame in combat") end
        return v(self, ...)
      end end
      return v
    end
  end
  return f
end
-- frames with a secure child become protected: showing them in combat is blocked
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
local toast = _G.UntamedRareToast
check(toast ~= nil, "toast built at login")
check(not rawget(toast, "_secureChild"), "toast has no secure child")
-- A rare appears mid-fight
COMBAT = true
UnitClassification = function() return "rare" end
TARGET_ID = 61
FIRE("PLAYER_TARGET_CHANGED")
check(ns.lastRare == 61, "rare spotted in combat")
check(toast:IsShown(), "toast shown in combat")
check(not _G.UntamedRareTargetButton:IsShown(), "target button waits for combat to end")
-- Combat ends
COMBAT = false
FIRE("PLAYER_REGEN_ENABLED")
check(_G.UntamedRareTargetButton:IsShown(), "target button shown after combat")
check((_G.UntamedRareTargetButton:GetAttribute("macrotext") or ""):find("/targetexact"), "target button set to the rare")
print("DONE")
