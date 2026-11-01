local ns = NS
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
FIRE("TRAINER_SHOW")
print("flavor", ns.FLAVOR, "fams", #ns.Families, "order", table.concat(ns.AbilityOrder, ","))
print("knows Bite4", ns.HunterKnows("Bite", 4), "Screech?", ns.AbilityFamilies["Screech"])
for _, tab in ipairs({ "abilities", "plan", "browse", "care", "settings" }) do ns.UI_Show(tab); print("tab ok", tab) end
local plan = ns.Plan("Bear", 14, { Claw = 2 })
for _, e in ipairs(plan) do local p = {} for _, r in ipairs(e.ranks) do p[#p+1] = r.rank .. ":" .. #r.beasts end print(e.ability, table.concat(p, " ")) end
local trip = ns.BuildTrip(ns.Target()); print("trip stops", #trip.stops, "teach", #trip.teach)
ns.Navigate(250926)
TOOLTIP_LINES = {}; TARGET_ID = 1797
for _, f in ipairs(POSTCALLS) do f(GameTooltip) end
print("tooltip", TOOLTIP_LINES[#TOOLTIP_LINES])
print("food", ns.EdibleFood()[1] and ns.EdibleFood()[1][6])
print("DONE")
