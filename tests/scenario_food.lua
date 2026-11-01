local ns = NS
FIRE("ADDON_LOADED", "Untamed"); FIRE("PLAYER_LOGIN")
BAGS = { [0] = { [1] = { 5503, 4 }, [2] = { 12205, 6 }, [3] = { 4540, 2 } } }
ITEMS[5503] = { "Clam Meat", 15 }; ITEMS[12205] = { "White Spider Meat", 40 }
GetPetFoodTypes = function() return "Meat", "Fish" end
local t = {} for _, f in ipairs(ns.EdibleFood()) do t[#t+1] = f[6] end print("cat eats:", table.concat(t, ", "))
GetPetFoodTypes = function() return "Meat" end
t = {} for _, f in ipairs(ns.EdibleFood()) do t[#t+1] = f[6] end print("spider eats:", table.concat(t, ", "))
ns.UI_Show("care"); print("care tab ok")
print("DONE")
