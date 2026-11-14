local ns = NS
FIRE("ADDON_LOADED", "Untamed"); FIRE("PLAYER_LOGIN")
BAGS = { [0] = { [1] = { 5503, 4 }, [2] = { 12205, 6 }, [3] = { 4540, 2 } } }
ITEMS[5503] = { "Clam Meat", 15 }; ITEMS[12205] = { "White Spider Meat", 40 }
GetPetFoodTypes = function() return "Meat", "Fish" end
local t = {} for _, f in ipairs(ns.EdibleFood()) do t[#t+1] = f[6] end print("cat eats:", table.concat(t, ", "))
GetPetFoodTypes = function() return "Meat" end
t = {} for _, f in ipairs(ns.EdibleFood()) do t[#t+1] = f[6] end print("spider eats:", table.concat(t, ", "))
-- feed order: cheapest food that still gives full happiness first (pet level 30: 25 and 40 are full, 15 is not)
PET.level = 30
BAGS = { [0] = { [1] = { 5503, 4 }, [2] = { 12205, 6 }, [3] = { 3730, 3 } } }
ITEMS[3730] = { "Big Bear Meat", 25 }
local canEat = C_PetInfo.CanPetEatItem
C_PetInfo.CanPetEatItem = function(id) return id == 5503 or id == 12205 or id == 3730 end
GetPetFoodTypes = function() return "Meat", "Fish" end
t = {} for _, f in ipairs(ns.EdibleFood()) do t[#t+1] = f[6] end
assert(t[1] == "Big Bear Meat" and t[2] == "White Spider Meat" and t[3] == "Clam Meat", "feed order: " .. table.concat(t, ", "))
PET.level = 60
assert(ns.EdibleFood()[1][6] == "White Spider Meat", "nothing close enough: highest level first")
ns.UI_Show("care"); print("care tab ok")
print("DONE")
