-- New features: stable-first route, stable manager, builds, rare scanner, ammo, leveling, data sharing.
local ns = NS
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end

FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
FIRE("CRAFT_SHOW")

-- Planner: with a pet out, the route starts at a stable master and ends with picking the pet back up.
local trip = ns.BuildTrip(ns.Target())
check(#trip.route >= 3, "route has stops")
check(trip.route[1].kind == "stable", "route starts at a stable master")
check(trip.route[#trip.route].kind == "return", "route ends by taking the pet back")
print("  first stop:", trip.route[1].service[2], ns.ZoneName(trip.route[1].service[4]))
ns.UI_Show("plan")

-- Manual family planning has no pet to stable.
ns.state.mode = "manual"; ns.state.family = "Cat"
local trip2 = ns.BuildTrip(ns.Target())
check(trip2.route[1] == nil or trip2.route[1].kind == "beast", "no stable stop when planning without a pet")
ns.state.mode = "pet"; ns.state.family = nil

-- Route advances: stable closed with no pet out -> next stop is a beast.
ns.UI_Show("plan")
local startBtn
-- Start the route through the public path
ns.Route_Next()  -- no route yet: prints a hint
local planner_trip = ns.BuildTrip(ns.Target())
-- simulate Start Route by calling the internal flow via keybinding equivalent
ns.Fire("STABLE_CLOSED")

-- Stable manager: reading the stable records both pets.
FIRE("PET_STABLE_SHOW")
local n = 0 for _ in pairs(ns.cdb.pets) do n = n + 1 end
check(n >= 2, "stable manager recorded pets (" .. n .. ")")
check(ns.cdb.pets["Slasher|Cat"] ~= nil, "stabled cat recorded")
ns.state.mode = "stable"; ns.state.key = "Slasher|Cat"
local t = ns.Target()
check(t.family == "Cat" and t.stabled, "planning for a stabled pet")
ns.UI_Show("stable"); ns.UI_Show("abilities")
ns.state.mode = "pet"; ns.state.key = nil

-- Builds: damage preset fits a wolf and costs something.
ns.UI_Show("builds")
local wolf = ns.Target()
ns.cdb.builds = ns.cdb.builds or {}
local cost = ns.BuildCost({ Bite = 4, Dash = 1 })
check(cost == 10 + 15, "build cost adds training points (" .. cost .. ")")

-- Rare scanner
TARGET_ID = 2850   -- Broken Tooth (Rare)
FIRE("PLAYER_TARGET_CHANGED")
check(ns.lastRare == 2850, "rare beast spotted")

-- Ammo warning (150 < 200)
FIRE("BAG_UPDATE_DELAYED")

-- Leveling zones for a level 24 pet
local zones, lo = ns.LevelingZones(24, 26)
check(#zones > 0 and lo == 18, "leveling zones found, mobs give XP from level " .. lo)
print("  best zone:", ns.ZoneName(zones[1].mapID))
ns.UI_Show("care")

-- Data sharing round trip
ns.db.observed[ns.FLAVOR][99999] = { name = "Test, Beast", family = "Wolf", level = 10, spells = { Bite = 2 }, map = 1429, x = 40, y = 60 }
local text = ns.ExportObserved()
ns.db.observed[ns.FLAVOR][99999] = nil
ns.ImportObserved(text)
check(ns.db.observed[ns.FLAVOR][99999] and ns.db.observed[ns.FLAVOR][99999].spells.Bite == 2, "export and import round trip")

-- Key bindings and settings panel
Untamed_Toggle(); Untamed_Toggle(); Untamed_Clear(); Untamed_Zone(); Untamed_NextStop()
ns.UI_Show("settings")
ns.UI_Show("recommend")
ns.UI_ViewingMenu(); ns.UI_ViewingMenu()
check(ns.ToEnglish("Bite") == "Bite", "locale passthrough")
-- Combat helpers
FIRE("START_AUTOREPEAT_SPELL")
check(_G.UntamedAutoShotBar and _G.UntamedAutoShotBar:IsShown(), "auto shot bar shows")
FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 75)
TICK(3)
FIRE("STOP_AUTOREPEAT_SPELL")
check(not _G.UntamedAutoShotBar:IsShown(), "auto shot bar hides")
GROUPED = true; GROWL_AUTO = true
ALERTS = 0
local oldAlert = ns.Alert
ns.Alert = function(msg) ALERTS = ALERTS + 1; print("  alert:", msg) end
FIRE("GROUP_ROSTER_UPDATE")
check(ALERTS == 1, "growl warning in a group")
FIRE("GROUP_ROSTER_UPDATE")
check(ALERTS == 1, "growl warning not repeated")
CHEETAH_ON = true
FIRE("PLAYER_REGEN_DISABLED")
check(ALERTS >= 2, "cheetah in combat warning")
ns.Alert = oldAlert
GROUPED = false; CHEETAH_ON = false
-- Search and supplies
local db = ns.SearchDB()
check(db and db.I[11285] and db.N[3018], "search index loads")
local srcs = ns.ItemSources(11285)
check(#srcs > 0, "jagged arrow has sources (" .. #srcs .. ")")
print("  nearest:", srcs[1].kind, srcs[1].name, srcs[1].map and ns.ZoneName(srcs[1].map))
ns.UI_Show("search")
ns.UI_Show("supplies")
ns.SearchFor("arrow")
ns.SearchFor("hogor")
SlashCmdList.UNTAMED("s heavy shot")
local tip = ns.ItemTooltip(11285)()
check(tip.itemID == 11285 and #tip > 2, "item tooltip with sources")
-- Character planning
for _, k in ipairs({ "spells", "talents", "gear", "quests" }) do ns.UI_Show(k) end
local T = ns.CharacterTest
if ns.FLAVOR ~= "forever" then
  local steps, nxt = T.BuildProgress(T.SelectedBuild())
  check(steps[1].done == 5 and nxt and nxt.name == "Improved Revive Pet" and nxt.done == 1, "talent build progress, next is Improved Revive Pet")
  check(T.Money(12345):find("1g") ~= nil, "money format")
  local lines = {}
  local tt = { AddLine = function(_, l) lines[#lines + 1] = l end }
  local best, bestId = 0
  for id, g in pairs(ns.GearItems) do if g[1] == "RANGED" and g[2] <= 30 and g[3] > best then best, bestId = g[3], id end end
  T.OnItemTooltip(tt, bestId)
  check(#lines == 1, "gear tooltip line for item " .. tostring(bestId) .. ": " .. tostring(lines[1]))
end
print("DONE")
