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
print("DONE")
