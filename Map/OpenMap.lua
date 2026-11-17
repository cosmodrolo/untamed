local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- OpenMap: Untamed's map icons show on its stitched map (MapPins.lua places them through
-- OpenMapAPI), and each group gets a switch in OpenMap's own menu ("Other addons").
-- Read only: nothing here changes OpenMap's settings.
---------------------------------------------------------------------------

local GROUPS = {
  { id = "untamedBooks", key = "bookPins", label = L["Untamed: library books"], icon = "Interface\\Icons\\INV_Misc_Book_09" },
  { id = "untamedChests", key = "chestPins", label = L["Untamed: chest spots"], icon = "Interface\\Icons\\INV_Box_02" },
  { id = "untamedRares", key = "rarePins", label = L["Untamed: rares"], icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
  { id = "untamedWishlist", key = "wishPins", label = L["Untamed: wishlist"], icon = "Interface\\Icons\\INV_Misc_Note_01" },
}

ns.On("LOGIN", function()
  local api = _G.OpenMapAPI
  if not (api and api.RegisterMenuToggle) then return end
  for _, g in ipairs(GROUPS) do
    pcall(api.RegisterMenuToggle, "Untamed", {
      id = g.id, label = g.label, icon = g.icon, tab = "show", section = "Untamed",
      get = function() return ns.db[g.key] ~= false end,
      set = function(v)
        ns.db[g.key] = v and true or false
        if ns.Pins_Refresh then ns.Pins_Refresh() end
        if ns.MinimapRebuild then ns.MinimapRebuild() end
      end,
    })
  end
end)
