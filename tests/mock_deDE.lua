-- German client
GetLocale = function() return "deDE" end
local DE_FAM = { [1] = "Wolf", [2] = "Katze", [4] = "Bär", [21] = "Schildkröte" }
C_CreatureInfo = { GetCreatureFamilyInfo = function(id) return DE_FAM[id] and { name = DE_FAM[id] } end }
local origSpell = GetSpellInfo
GetSpellInfo = function(id) if id == 17253 then return "Biss" end if id == 1742 then return "Ducken" end return origSpell(id) end
PET.family = "Katze"; PET.spells = { { "Biss", "Rang 3" }, { "Ducken", "Rang 1" } }
