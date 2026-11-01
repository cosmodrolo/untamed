local ns = NS
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
FIRE("CRAFT_SHOW")
print("flavor", ns.FLAVOR, "order", table.concat(ns.AbilityOrder, ","))
-- geo
local c, e, n = ns.ToWorld(1429, 50, 50)
local c2, e2, n2 = ns.ToWorld(1429, 60, 50)
print("geo east delta", e2 - e, "north delta", select(3, ns.ToWorld(1429, 50, 40)) - n)
-- arrow
ns.Navigate(ns.Teach["Furious Howl"][1][1])
TICK(2)
print("arrow target", ns.Arrow_Target() and ns.Arrow_Target().label)
-- open UI, each tab
for _, tab in ipairs({ "abilities", "plan", "browse", "care", "settings" }) do
  ns.UI_Show(tab)
  print("tab ok", tab)
end
-- planner content
ns.UI_Show("plan")
local trip = ns.BuildTrip(ns.Target())
print("trip stops", #trip.stops, "teach", #trip.teach, "tp", trip.tpNeed)
for i, s in ipairs(trip.stops) do
  local g = {}
  for _, x in ipairs(s.goals) do g[#g + 1] = x.ability .. x.rank end
  print(" stop", i, ns.Beasts[s.npcId][1], ns.ZoneNames[s.mapID], s.dist and math.floor(s.dist), table.concat(g, " "),
    s.stable and s.stable[2], s.flight and s.flight[2])
end
ns.db.planForPlayerLevel = true
local trip2 = ns.BuildTrip(ns.Target())
print("trip (player level) stops", #trip2.stops)
-- tooltip
TARGET_ID = 299
TOOLTIP_LINES = {}
GameTooltip._scripts.OnTooltipSetUnit(GameTooltip)
print("tooltip:", clean(TOOLTIP_LINES[#TOOLTIP_LINES]))
-- target alert: pick a beast the pet needs in data
local need = ns.NeededSet()
local someId; for id in pairs(need) do someId = id break end
TARGET_ID = someId
FIRE("PLAYER_TARGET_CHANGED")
-- pins
WorldMapFrame:SetMapID(1429)
ns.Pins_Focus(ns.Teach["Cower"][2], "Cower 2", true)
print("pins on map", C_Map.GetBestMapForUnit(), #PINS)
local svc = 0; for _, p in ipairs(PINS) do if p.info.service then svc = svc + 1 end end
print("service pins", svc)
if PINS[1] then PINS[1]:OnMouseEnter(); PINS[1]:OnClick("LeftButton") end
-- minimap pins
TICK(3)
-- pet care
PET.happy = 2
FIRE("UNIT_HAPPINESS", "pet")
local food = ns.EdibleFood()
print("food", #food, food[1] and food[1][6], UntamedFeedButton._attr.macrotext)
-- tame recorder
TARGET_ID = 99999; TARGET_NAME = "Test Beast"
FIRE("UNIT_SPELLCAST_START", "player", "x", 1515)
PET.spells = { { "Bite", "Rank 5" }, { "Dash", "Rank 2" } }
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 1515)
print("observed", ns.Beasts[99999] and ns.TeachesText(ns.Beasts[99999]))
-- route advance
ns.UI_Show("plan")
FIRE("CHAT_MSG_SYSTEM", "You have learned a new ability: Furious Howl (Rank 2).")
-- browser filter
ns.UI_Show("browse")
SlashCmdList.UNTAMED("help")
print("DONE")
