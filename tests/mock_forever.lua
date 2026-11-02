-- Forever (modern client) differences
GetSpellInfo = nil; GetCraftDisplaySkillLine = nil; GetNumCrafts = nil; GetCraftInfo = nil
GetPetHappiness = nil; GetPetFoodTypes = nil; GetPetTrainingPoints = nil; GetSpellBookItemName = nil
C_Spell = { GetSpellInfo = function(id) local n = SPELLS and SPELLS[id] if n then return { name = n } end end }
Enum = { SpellBookSpellBank = { Pet = 1 }, TrainerType = { Pet = 3 }, TooltipDataType = { Unit = 2 } }
C_SpellBook = { GetSpellBookItemName = function(i) local s = PET.spells[i]; return s[1], s[2] end }
C_PetInfo = {
  GetPetHappiness = function() return PET.happy or 3, 100, 1 end,
  GetPetFoodTypes = function() return { "Meat" } end,
  GetPetTrainingPoints = function() return 60, 40 end,
  GetPetLoyalty = function() return "Loyal" end,
  CanPetEatItem = function(id) return id == 2672 or id == 117 end,
}
C_Item = { GetItemInfo = function(id) local i = ITEMS[id]; if i then return i[1], nil, nil, i[2] end end }
C_Trainer = { GetTrainerType = function() return 3 end }
SERVICES = { { "Bite", "available", nil, 24, "Rank 4", 10 }, { "Swipe", "available", nil, 12, "Rank 1", 0 } }
GetNumTrainerServices = function() return #SERVICES end
GetTrainerServiceInfo = function(i) local s = SERVICES[i]; return s[1], s[2], s[3], s[4], s[5] end
GetTrainerServiceCost = function(i) return SERVICES[i][6] end
GameTooltip.HasScript = function() return false end
POSTCALLS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(t, f) POSTCALLS[#POSTCALLS + 1] = f end }
issecretvalue = function() return false end
UnitExists = function(u) return (u == "pet" and PET.exists) or u == "target" or u == "mouseover" end
PET.family = "Bear"; PET.spells = { { "Claw", "Rank 2" }, { "Growl", "Rank 2" } }; PET.level = 14
