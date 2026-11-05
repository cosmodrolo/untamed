local _, ns = ...
local FOREVER = ns.FLAVOR == "forever"

local function set(...) local t = {} for i = 1, select("#", ...) do t[select(i, ...)] = true end return t end

if FOREVER then
  ns.Families = {
    "Bat", "Bear", "Bird of Prey", "Boar", "Carrion Bird", "Cat", "Crab", "Crocolisk", "Fox", "Gorilla",
    "Hyena", "Raptor", "Scorpid", "Spider", "Tallstrider", "Turtle", "Wind Serpent", "Wolf",
  }
else
  ns.Families = {
    "Bat", "Bear", "Boar", "Carrion Bird", "Cat", "Crab", "Crocolisk", "Gorilla", "Hyena",
    "Owl", "Raptor", "Scorpid", "Spider", "Tallstrider", "Turtle", "Wind Serpent", "Wolf",
  }
end
local ALL = {}
for _, f in ipairs(ns.Families) do ALL[f] = true end

ns.FamilyIcons = {
  ["Bat"] = "Ability_Hunter_Pet_Bat", ["Bear"] = "Ability_Hunter_Pet_Bear", ["Boar"] = "Ability_Hunter_Pet_Boar",
  ["Carrion Bird"] = "Ability_Hunter_Pet_Vulture", ["Cat"] = "Ability_Hunter_Pet_Cat", ["Crab"] = "Ability_Hunter_Pet_Crab",
  ["Crocolisk"] = "Ability_Hunter_Pet_Crocolisk", ["Gorilla"] = "Ability_Hunter_Pet_Gorilla", ["Hyena"] = "Ability_Hunter_Pet_Hyena",
  ["Owl"] = "Ability_Hunter_Pet_Owl", ["Bird of Prey"] = "Ability_Hunter_Pet_Owl", ["Raptor"] = "Ability_Hunter_Pet_Raptor",
  ["Scorpid"] = "Ability_Hunter_Pet_Scorpid", ["Spider"] = "Ability_Hunter_Pet_Spider", ["Tallstrider"] = "Ability_Hunter_Pet_TallStrider",
  ["Turtle"] = "Ability_Hunter_Pet_Turtle", ["Wind Serpent"] = "Ability_Hunter_Pet_WindSerpent", ["Wolf"] = "Ability_Hunter_Pet_Wolf",
  ["Fox"] = "Ability_Hunter_Pet_Wolf",
}

ns.AbilityIcons = {
  ["Bite"] = "Ability_Racial_Cannibalize", ["Claw"] = "Ability_Druid_Rake", ["Charge"] = "Ability_Hunter_Pet_Boar",
  ["Dash"] = "Ability_Druid_Dash", ["Dive"] = "Spell_Shadow_BurningSpirit", ["Furious Howl"] = "Ability_Hunter_Pet_Wolf",
  ["Lightning Breath"] = "Spell_Nature_Lightning", ["Prowl"] = "Ability_Ambush", ["Scorpid Poison"] = "Ability_PoisonSting",
  ["Screech"] = "Ability_Hunter_Pet_Bat", ["Shell Shield"] = "Ability_Hunter_Pet_Turtle", ["Thunderstomp"] = "Ability_Hunter_Pet_Gorilla",
  ["Cower"] = "Ability_Druid_Cower", ["Growl"] = "Ability_Physical_Taunt",
}

-- Classic Era: which families can use each beast-taught ability.
ns.AbilityFamilies = {
  ["Bite"] = set("Bat", "Bear", "Boar", "Carrion Bird", "Cat", "Crocolisk", "Gorilla", "Hyena", "Raptor", "Spider", "Tallstrider", "Turtle", "Wind Serpent", "Wolf"),
  ["Claw"] = set("Bear", "Carrion Bird", "Cat", "Crab", "Owl", "Raptor", "Scorpid"),
  ["Charge"] = set("Boar"),
  ["Dash"] = set("Boar", "Cat", "Hyena", "Tallstrider", "Wolf"),
  ["Dive"] = set("Bat", "Carrion Bird", "Owl", "Wind Serpent"),
  ["Furious Howl"] = set("Wolf"),
  ["Lightning Breath"] = set("Wind Serpent"),
  ["Prowl"] = set("Cat"),
  ["Scorpid Poison"] = set("Scorpid"),
  ["Screech"] = set("Bat", "Carrion Bird", "Owl"),
  ["Shell Shield"] = set("Turtle"),
  ["Thunderstomp"] = set("Gorilla"),
  ["Cower"] = ALL,
}

-- Required pet level per rank. Values read in game from Beast Training win over these.
ns.RankLevels = {
  ["Bite"] = { 1, 8, 16, 24, 32, 40, 48, 56 },
  ["Claw"] = { 1, 8, 16, 24, 32, 40, 48, 56 },
  ["Charge"] = { 1, 12, 24, 36, 48, 60 },
  ["Dash"] = { 30, 40, 50 },
  ["Dive"] = { 30, 40, 50 },
  ["Furious Howl"] = { 10, 24, 40, 56 },
  ["Lightning Breath"] = { 1, 12, 24, 36, 48, 60 },
  ["Prowl"] = { 30, 40, 50 },
  ["Scorpid Poison"] = { 8, 24, 40, 56 },
  ["Screech"] = { 8, 24, 48, 56 },
  ["Shell Shield"] = { 20 },
  ["Thunderstomp"] = { 30, 40, 50 },
  ["Cower"] = { 5, 15, 25, 35, 45, 55 },
}

-- Training point cost per rank (where known). Values read in game win over these.
ns.RankTP = {
  ["Bite"] = { 1, 4, 7, 10, 13, 17, 21, 25 },
  ["Claw"] = { 1, 4, 7, 10, 13, 17, 21, 25 },
  ["Charge"] = { 5, 9, 13, 17, 21, 25 },
  ["Dash"] = { 15, 20, 25 },
  ["Dive"] = { 15, 20, 25 },
  ["Furious Howl"] = { 10, 15, 20, 25 },
  ["Lightning Breath"] = { 1, 5, 10, 15, 20, 25 },
  ["Scorpid Poison"] = { 10, 15, 20, 25 },
  ["Shell Shield"] = { 15 },
  ["Thunderstomp"] = { 15, 20, 25 },
  ["Cower"] = { 8, 10, 12, 14, 16, 18 },
}

-- Pet trainer abilities (levels and training points; values read in game win over these).
do
  local R = { 5, 15, 45, 90 }
  local trainer = {
    ["Growl"] = { { 1, 10, 20, 30, 40, 50, 60 }, { 0, 0, 0, 0, 0, 0, 0 } },
    ["Natural Armor"] = { { 1, 12, 18, 24, 30, 36, 42, 48, 54, 60 }, { 1, 5, 10, 15, 25, 50, 75, 100, 125, 150 } },
    ["Great Stamina"] = { { 1, 12, 18, 24, 30, 36, 42, 48, 54, 60 }, { 5, 10, 15, 25, 50, 75, 100, 125, 150, 185 } },
    ["Arcane Resistance"] = { { 20, 30, 40, 50 }, R }, ["Fire Resistance"] = { { 20, 30, 40, 50 }, R },
    ["Frost Resistance"] = { { 20, 30, 40, 50 }, R }, ["Nature Resistance"] = { { 20, 30, 40, 50 }, R },
    ["Shadow Resistance"] = { { 20, 30, 40, 50 }, R },
  }
  for ability, v in pairs(trainer) do ns.RankLevels[ability] = v[1]; ns.RankTP[ability] = v[2] end
  -- Forever, seen in Beast Training (2026-11-05): Natural Armor rank 2 costs 4 training points, not 5.
  if FOREVER then ns.RankTP["Natural Armor"][2] = 4 end
end

ns.TrainerAbilities = {
  "Growl", "Natural Armor", "Great Stamina",
  "Arcane Resistance", "Fire Resistance", "Frost Resistance", "Nature Resistance", "Shadow Resistance",
}

-- Forever overrides come from the data file (built from public Forever pet guides).
if FOREVER and ns.ForeverAbilities then
  for ability, info in pairs(ns.ForeverAbilities) do
    if info.families then ns.AbilityFamilies[ability] = set(unpack(info.families)) end
    if info.levels then ns.RankLevels[ability] = info.levels end
    if info.tp then ns.RankTP[ability] = info.tp end
    if info.icon then ns.AbilityIcons[ability] = info.icon end
  end
  if ns.ForeverRemoved then
    for _, ability in ipairs(ns.ForeverRemoved) do ns.AbilityFamilies[ability] = nil end
  end
end

-- Display order: anything with families, Bite/Claw first, Cower last.
do
  local order, seen = { "Bite", "Claw" }, { Bite = true, Claw = true, Cower = true }
  local rest = {}
  for ability in pairs(ns.AbilityFamilies) do if not seen[ability] then rest[#rest + 1] = ability end end
  table.sort(rest)
  for _, a in ipairs(rest) do order[#order + 1] = a end
  order[#order + 1] = "Cower"
  ns.AbilityOrder = {}
  for _, a in ipairs(order) do if ns.AbilityFamilies[a] then ns.AbilityOrder[#ns.AbilityOrder + 1] = a end end
end

-- Pet food types: Foods.lua (every item, from the Classic database). Forever asks the game directly.
