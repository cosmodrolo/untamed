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
SERVICES = { { "Bite", "available", nil, 24, "Rank 4", 10 }, { "Swipe", "available", nil, 12, "Rank 1", 0 },
  { "Claw", "available", nil, 16, "Rank 3", 3 }, { "Growl", "used", nil, 20, nil, 0 } }
GetNumTrainerServices = function() return #SERVICES end
GetTrainerServiceInfo = function(i) local s = SERVICES[i]; return s[1], s[2], s[3], s[4], s[5] end
GetTrainerServiceCost = function(i) return SERVICES[i][6] end
GameTooltip.HasScript = function() return false end
POSTCALLS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(t, f) POSTCALLS[#POSTCALLS + 1] = f end }
issecretvalue = function() return false end
UnitExists = function(u) return (u == "pet" and PET.exists) or u == "target" or u == "mouseover" end
PET.family = "Bear"; PET.spells = { { "Claw", "Rank 2" }, { "Growl", "Rank 2" } }; PET.level = 14
-- Forever talents: a trait tree instead of GetTalentInfo / UnitCharacterPoints.
UnitCharacterPoints = nil; GetNumTalents = nil; GetTalentInfo = nil
SPELLS[19552] = "Deadly Aspects"; SPELLS[19583] = "Endurance Training"; SPELLS[19426] = "Lethal Attacks"
C_Spell.GetSpellName = function(id) return SPELLS[id] end
TRAIT_NODES = { [101] = { spell = 19552, rank = 2, max = 5 }, [102] = { spell = 19583, rank = 0, max = 5 }, [201] = { spell = 19426, rank = 0, max = 5 } }
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 9 } } end,
  GetTreeNodes = function() return { 101, 102, 201 } end,
  GetNodeInfo = function(_, n) local t = TRAIT_NODES[n]; return { entryIDs = { n }, activeRank = t.rank, maxRanks = t.max } end,
  GetEntryInfo = function(_, e) return { definitionID = e } end,
  GetDefinitionInfo = function(d) return { spellID = TRAIT_NODES[d].spell } end,
  GetTreeCurrencyInfo = function() return { { quantity = 3 } } end,
}
