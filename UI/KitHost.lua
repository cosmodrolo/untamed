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
  panel:SetScript("OnShow", function(self) ns.KitTall(true); ns.UI_Host(self) end)
  panel:SetScript("OnHide", function() ns.KitTall(false) end)
  return panel
end })

-- Height per tab: the Kit's pages are laid out for its normal height (690), Untamed's need more. On the Untamed tab
-- the window takes Untamed's own height (ns.db.kitTabH, default 830, set by dragging the window's bottom edge while
-- on this tab); on the Kit's tabs it goes back to the Kit's own (UntamedKitDB.window.height, untouched here).
local BASE_H, UNTAMED_H = 690, 830
local kitH -- the Kit's height while we are on our tab
function ns.KitTall(on)
  local win = _G.UntamedKitFrame
  if not win then return end
  local w = type(UntamedKitDB) == "table" and type(UntamedKitDB.window) == "table" and UntamedKitDB.window or nil
  if on then
    if kitH then return end
    kitH = (w and type(w.height) == "number") and w.height or BASE_H
    local fit = math.floor((UIParent:GetHeight() or 0) * UIParent:GetEffectiveScale() / win:GetEffectiveScale()) - 20
    if fit < BASE_H then fit = UNTAMED_H end
    win:SetHeight(math.max(BASE_H, math.min(ns.db.kitTabH or UNTAMED_H, fit)))
  elseif kitH then
    local mine = win:GetHeight()
    if mine and math.abs(mine - (ns.db.kitTabH or UNTAMED_H)) >= 1 then ns.db.kitTabH = math.floor(mine + 0.5) end
    if w then w.height = (kitH > BASE_H) and kitH or nil end
    win:SetHeight(kitH)
    kitH = nil
  end
end

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
  if panel and panel:IsVisible() then ns.KitTall(true); ns.UI_Host(panel) end
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
  -- once (2.47.3): the Kit's own height goes back to normal; it had been stretched for Untamed's pages before the
  -- Untamed tab got its own height
  if not ns.db.kitHeightReset and type(UntamedKitDB) == "table" and type(UntamedKitDB.window) == "table" then
    ns.db.kitHeightReset = true
    UntamedKitDB.window.height = nil
  end
  if type(UntamedKitCharDB) ~= "table" then return end
  if not UntamedKitCharDB.untamedTabsSet then
    UntamedKitCharDB.untamedTabsSet = true
    if UI.SetTabVisible then pcall(UI.SetTabVisible, "pets", false) end
  end
end)
