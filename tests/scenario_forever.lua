local ns = NS
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
FIRE("TRAINER_SHOW")
-- Beast Training shows upgrade costs: Claw 3 costs 3 more than the pet's Claw 2 (4), so 7 in full.
assert(ns.cdb.tp.Bite[4] == 10, "new ability keeps its cost")
assert(ns.cdb.tp.Claw[3] == 7, "upgrade cost converted to full cost: " .. tostring(ns.cdb.tp.Claw[3]))
assert(not (ns.cdb.levels.Growl and ns.cdb.levels.Growl[1]), "unreadable rank is not saved as rank 1")
assert(ns.RankCost("Natural Armor", 2) == 5, "Natural Armor rank 2 is 5 training points")
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
ns.UI_Show("talents"); print("tab ok talents")
print("forever talents free", ns.FreeTalentPoints(), "next", ns.NextTalent())
-- Combat on Forever: stats and target info come back as secret values.
SECRET = setmetatable({}, { __lt = function() error("attempt to compare a secret number value") end,
  __le = function() error("attempt to compare a secret number value") end })
issecretvalue = function(v) return v == SECRET end
local realType = type; type = function(v) if v == SECRET then return "number" end return realType(v) end
local oldRD, oldSpeed, oldLevel, oldGUID = UnitRangedDamage, GetUnitSpeed, UnitLevel, UnitGUID
UnitRangedDamage = function() return SECRET end
GetUnitSpeed = function() return SECRET end
IsPlayerMoving = function() return false end
UnitLevel = function(u) if u == "target" then return SECRET end return 20 end
UnitGUID = function(u) if u == "target" then return SECRET end return oldGUID(u) end
ns.db.autoShotBar = true; ns.Combat.ShowBar(true)
ns.Combat.ShotFired(); ns.Combat.ShotFired()
FIRE("PLAYER_REGEN_DISABLED"); FIRE("PLAYER_TARGET_CHANGED")
-- loot recorded while the target GUID is hidden
ns.db.recordData = true
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return "|cffffffff|Hitem:2516::::::::1:::::::|h[Light Shot]|h|r" end
GetLootSourceInfo = function() return "Creature-0-1-2-3-299-0000000001", 1 end
FIRE("LOOT_OPENED")
-- a rare whose level is hidden
UnitClassification = function() return "rare" end
local oldG = UnitGUID; UnitGUID = function(u) if u == "mouseover" then return "Creature-0-1-2-3-61-0000000002" end return SECRET end
UnitExists = function() return true end
ns.CheckRare("mouseover")
UnitGUID = oldG
print("secret combat ok")
-- gamepad UI on: Untamed doesn't open the world map itself
InputUtil = { IsGamepadUIEnabled = function() return true end }
local opened = false
local oldToggle = ToggleWorldMap; ToggleWorldMap = function() opened = true end
WorldMapFrame.IsShown = function() return false end
ns.OpenMapTo(1429)
ToggleWorldMap = oldToggle; InputUtil = nil
print("gamepad map " .. (opened and "OPENED" or "left closed"))
UnitRangedDamage, GetUnitSpeed, UnitLevel, UnitGUID = oldRD, oldSpeed, oldLevel, oldGUID
issecretvalue = function() return false end
type = realType
-- Forever attack speeds and the All Beasts speed filter
local fast, missing = 0, 0
for _, b in pairs(ns.Beasts) do if not b[9] then missing = missing + 1 elseif b[9] <= 1.5 then fast = fast + 1 end end
print("forever speeds: fast " .. fast .. ", missing " .. missing)
assert(fast > 20 and missing == 0, "forever beasts have attack speeds")
local bf = ns.BrowserFilter(); bf.speed = "fast"; ns.UI_Show("browse"); bf.speed = "any"
-- Forever spells and gear pages
local hawk, aimed
for _, e in ipairs(ns.TrainerSpells) do
  if e[2] == 1293525 then hawk = e end
  if e[4] == "Aimed Shot" then aimed = true end
end
assert(hawk and hawk[1] == 36 and hawk[3] == -1, "forever trainer has Summon Hawk rank 2")
for _, e in ipairs(ns.TrainerSpells) do assert(e[4] ~= "Wyvern Sting" and e[4] ~= "Strider Kick", "no Classic-only or talent-only spells") end
-- the leveling build only uses talents that exist in the Forever trees, and adds up to 51 points
local bt = ns.CharacterTest and ns.CharacterTest.Builds
assert(bt, "builds exposed")
local inTree = {}
for tab, tiers in ipairs(ns.CharacterTest.Trees) do for _, tier in ipairs(tiers) do for _, t in ipairs(tier) do inTree[tab .. t[1]] = t[2] end end end
for _, b in ipairs(bt) do
  local n, per = 0, {}
  for _, st in ipairs(b.steps) do
    n = n + st[3]; per[st[1] .. st[2]] = (per[st[1] .. st[2]] or 0) + st[3]
    assert(inTree[st[1] .. st[2]], b.key .. ": " .. st[2] .. " is in the Forever tree")
    assert(per[st[1] .. st[2]] <= inTree[st[1] .. st[2]], b.key .. ": " .. st[2] .. " within max rank")
  end
  assert(n == 51, b.key .. " build is 51 points")
end
assert(aimed, "forever trainer lists talent ranks")
local n = ns.SpellsToTrain(); print("forever spells to train at 26: " .. n)
assert(n > 0, "spells to train on forever")
assert(ns.Money(-1):find("?", 1, true), "unknown cost shows ?")
ns.UI_Show("spells")
local cnt = 0 for _ in pairs(ns.GearItems) do cnt = cnt + 1 end
assert(cnt > 4000 and ns.GearItems[2825] and ns.GearItems[288930], "forever gear table merged")
ns.UI_Show("gear")
print("DONE")
