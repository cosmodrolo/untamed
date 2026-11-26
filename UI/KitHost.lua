local _, ns = ...
local L = ns.L

-- One window: with the Kit loaded (Kit/, OneForAll inside Untamed), Untamed's window becomes the "Untamed" tab of the
-- Kit's window, next to Armory, Professions and Books. Nothing in Kit/ is changed: the Kit builds its tab bar from
-- UI.panels, which any code can add to. Untamed's own sections (Today, Bestiary, My Pets, Hunter, Gear, World) stay
-- as they are inside that tab. The Kit's controller support drives the whole window, Untamed's tab included
-- (Untamed's own controller code stands down while hosted, UI/Pad.lua); its menus are handed to the Kit's through
-- FLT.PadExtraMenu.

local K = ns.Kit
if not (K and K.UI and K.UI.RegisterPanel) then return end
local UI = K.UI
local KEY = "untamed"

UI.RegisterPanel({ key = KEY, label = "Untamed", order = 0.5, tabWidth = 112, create = function(parent)
  local panel = CreateFrame("Frame", nil, parent)
  if UI.PlacePanel then UI.PlacePanel(panel, parent) else panel:SetAllPoints(parent) end
  panel:SetScript("OnShow", function(self) ns.UI_Host(self) end)
  return panel
end })

-- the Kit's controller support: Untamed's open dropdown or "Viewing" menu, and closing it
K.PadExtraMenu = function()
  if not (ns.UI_Hosted and ns.UI_Hosted()) then return nil end
  return ns.UI_Popup()
end
K.PadExtraClose = function() ns.UI_ClosePopups() end

-- /ut, the minimap button and every "open this page" in Untamed: the Kit's window on the Untamed tab
local function Hosted()
  -- (the tab's OnShow does this too; called here as well so it never depends on which frame showed first)
  local panel = UI.EnsurePanel and UI.EnsurePanel(KEY)
  if panel and panel:IsVisible() then ns.UI_Host(panel) end
end
function ns.KitShow()
  if not K.OpenPanel then return false end
  K:OpenPanel(KEY)
  Hosted()
  return true
end
function ns.KitToggle()
  if not (K.OpenPanel and UI.IsWindowShown) then return false end
  if UI.IsWindowShown() and UI.ActiveTab and UI.ActiveTab() == KEY and K.ToggleUI then K:ToggleUI() else K:OpenPanel(KEY); Hosted() end
  return true
end

-- once per character: OneForAll's simpler Hunter Pets tab is hidden (Untamed's pages cover it); it can be shown
-- again from the Kit's settings like any other tab
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if type(UntamedKitCharDB) ~= "table" then return end
  if not UntamedKitCharDB.untamedTabsSet then
    UntamedKitCharDB.untamedTabsSet = true
    if UI.SetTabVisible then pcall(UI.SetTabVisible, "pets", false) end
  end
end)
