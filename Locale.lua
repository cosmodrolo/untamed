local _, ns = ...

-- Game data in Untamed is keyed by English names. On other client languages the game
-- reports localized ability, family and diet names, so map those back to English.

local toEnglish = {}

-- Abilities: the client tells us each ability's localized name from its spell ID.
for english, id in pairs(ns.AbilitySpellIDs or {}) do
  local name = ns.SpellName and ns.SpellName(id)
  if name and name ~= english then toEnglish[name] = english end
end

-- Families and diets (best effort for the main European client languages).
local FAMILY = {
  deDE = { Wolf = "Wolf", Katze = "Cat", Spinne = "Spider", ["Bär"] = "Bear", Eber = "Boar", Krokilisk = "Crocolisk",
    Aasvogel = "Carrion Bird", Krebs = "Crab", Gorilla = "Gorilla", Raptor = "Raptor", Weitschreiter = "Tallstrider",
    Skorpid = "Scorpid", ["Schildkröte"] = "Turtle", Fledermaus = "Bat", ["Hyäne"] = "Hyena", Eule = "Owl",
    Windnatter = "Wind Serpent", Fuchs = "Fox", Raubvogel = "Bird of Prey" },
  frFR = { Loup = "Wolf", ["Félin"] = "Cat", ["Araignée"] = "Spider", Ours = "Bear", Sanglier = "Boar",
    Crocilisque = "Crocolisk", Charognard = "Carrion Bird", Crabe = "Crab", Gorille = "Gorilla", Raptor = "Raptor",
    ["Haut-trotteur"] = "Tallstrider", Scorpide = "Scorpid", Tortue = "Turtle", ["Chauve-souris"] = "Bat",
    ["Hyène"] = "Hyena", Chouette = "Owl", ["Serpent des vents"] = "Wind Serpent", Renard = "Fox", ["Oiseau de proie"] = "Bird of Prey" },
  esES = { Lobo = "Wolf", Felino = "Cat", ["Araña"] = "Spider", Oso = "Bear", ["Jabalí"] = "Boar", Crocolisco = "Crocolisk",
    ["Carroñero"] = "Carrion Bird", Cangrejo = "Crab", Gorila = "Gorilla", Raptor = "Raptor", Zancaalta = "Tallstrider",
    ["Escórpido"] = "Scorpid", Tortuga = "Turtle", ["Murciélago"] = "Bat", Hiena = "Hyena", ["Búho"] = "Owl",
    ["Serpiente alada"] = "Wind Serpent", Zorro = "Fox", ["Ave rapaz"] = "Bird of Prey" },
}
FAMILY.esMX = FAMILY.esES
local DIET = {
  deDE = { Fleisch = "Meat", Fisch = "Fish", ["Käse"] = "Cheese", Brot = "Bread", Pilz = "Fungus", Obst = "Fruit" },
  frFR = { Viande = "Meat", Poisson = "Fish", Fromage = "Cheese", Pain = "Bread", Champignon = "Fungus", Fruit = "Fruit" },
  esES = { Carne = "Meat", Pescado = "Fish", Queso = "Cheese", Pan = "Bread", Hongo = "Fungus", Fruta = "Fruit" },
}
DIET.esMX = DIET.esES

local locale = GetLocale and GetLocale() or "enUS"
for k, v in pairs(FAMILY[locale] or {}) do toEnglish[k] = v end
for k, v in pairs(DIET[locale] or {}) do toEnglish[k] = v end

-- Family names straight from the game when it can tell us (works in every language).
local FAMILY_IDS = { [1] = "Wolf", [2] = "Cat", [3] = "Spider", [4] = "Bear", [5] = "Boar", [6] = "Crocolisk",
  [7] = "Carrion Bird", [8] = "Crab", [9] = "Gorilla", [11] = "Raptor", [12] = "Tallstrider", [20] = "Scorpid",
  [21] = "Turtle", [24] = "Bat", [25] = "Hyena", [26] = ns.FLAVOR == "forever" and "Bird of Prey" or "Owl",
  [27] = "Wind Serpent", [46] = "Fox" }
local familyLabel, abilityLabel = {}, {}
if C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyInfo then
  for id, english in pairs(FAMILY_IDS) do
    local ok, info = pcall(C_CreatureInfo.GetCreatureFamilyInfo, id)
    if ok and info and info.name and info.name ~= "" then
      toEnglish[info.name] = english
      familyLabel[english] = info.name
    end
  end
end
for english, id in pairs(ns.AbilitySpellIDs or {}) do
  local name = ns.SpellName and ns.SpellName(id)
  if name then abilityLabel[english] = name end
end

-- Names to show the player, in their language.
function ns.FamilyLabel(english) return familyLabel[english] or english end
function ns.AbilityLabel(english) return abilityLabel[english] or english end

-- Beast and NPC names in the player's language (Data\Names_*.lua).
if ns.LocalNames then
  for id, name in pairs(ns.LocalNames) do
    local b = ns.Beasts[id]
    if b then b[1] = name end
  end
  for _, sv in ipairs(ns.Services or {}) do
    local name = sv[7] and ns.LocalNames[sv[7]]
    if name then sv[2] = name end
  end
  ns.LocalNames = nil
end

function ns.ToEnglish(name)
  if not name then return name end
  return toEnglish[name] or name
end

-- Zone names in the player's language when the game knows the map.
local zoneCache = {}
function ns.ZoneName(mapID)
  if not mapID then return "?" end
  local n = zoneCache[mapID]
  if n then return n end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  n = (info and info.name) or ns.ZoneNames[mapID] or ("Map " .. mapID)
  zoneCache[mapID] = n
  return n
end
