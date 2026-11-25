local ADDON, ns = ...

-- Untamed Kit: OneForAll (by Smoergi, GPL-3.0-or-later, https://github.com/smoergi/OneForAll_Forever) and the
-- OneForAll Pad controller module, inside Untamed. The files in Kit/ are made by tools/port_kit.py; do not edit them.
--
-- While OneForAll or OneForAll Pad is loaded the Kit stays idle (ns.Kit is nil and every Kit file returns at once),
-- and their settings are copied into the Kit's own saved variables each session, so the moment OneForAll is
-- switched off the Kit takes over with the same settings, books and plans.

local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local function isLoaded(name) local ok, v = pcall(loaded, name); return ok and v and true or false end
local other = (isLoaded("OneForAll") and "OneForAll") or (isLoaded("OneForAllPad") and "OneForAllPad") or nil

local function copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[copy(k, seen)] = copy(v, seen) end
  return c
end

ns.KitIdleFor = other
if other then
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterAllEvents()
    if type(OneForAllDB) == "table" then UntamedKitDB = copy(OneForAllDB) end
    if type(OneForAllCharDB) == "table" then UntamedKitCharDB = copy(OneForAllCharDB) end
  end)
  return
end

ns.Kit = { ASSET_ROOT = "Interface\\AddOns\\" .. ADDON .. "\\Kit\\Assets\\", DISPLAY_NAME = "Untamed Kit" }
