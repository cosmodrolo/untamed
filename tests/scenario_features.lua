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

-- Any rare, not just tameable ones
local oldCls = UnitClassification
UnitClassification = function() return "rare" end
TARGET_ID = 61   -- Thuros Lightfingers, a rare humanoid
FIRE("PLAYER_TARGET_CHANGED")
check(ns.lastRare == 61, "non-tameable rare spotted")
check(_G.UntamedRareToast and _G.UntamedRareToast:IsShown(), "rare pop-up shown")
ns.NavigateLastRare()
UnitClassification = oldCls
ns.UI_Show("rares")

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
-- Search filters and new sources
local f = ns.SearchFilters()
f.kind = "ranged"; f.source = "vendor"; f.usable = true; f.near = true
ns.SearchFor("")
f.kind = "any"; f.source = "any"; f.usable = false; f.near = false; f.type = "beasts"
ns.SearchFor("")
f.type = "vendors"; ns.SearchFor("")
f.type = "all"
local w = ns.ItemWays(3021)
check(w.chest, "ranger bow comes from chests")
local summ = ns.SourceSummary(3021)
print("  ranger bow:", summ)
check(summ:find("Chest") ~= nil, "chest source shows a place")
local clam = ns.ItemWays(5503)
check(clam.inside, "clam meat found inside clams")
for _, k in ipairs({ "all", "items" }) do f.type = k; ns.SearchFor("clam") end

-- Recorder: vendor and loot recordings merge into the index
ns.RecorderTest.RecordVendor()
ns.RecorderTest.RecordLoot()
local db2 = ns.SearchDB()
local vend = db2.I[11362][6]
local hasJin = false
for _, v in ipairs(vend) do if v == 3410 then hasJin = true end end
check(hasJin, "Jin'sora sells Medium Quiver")
check(db2.I[99001] and db2.I[99001][6][1] == 3410, "recorded vendor item merged")
check(db2.I[99002] and db2.I[99002][7][1] == 3018, "recorded loot merged")
local v, d, n = ns.RecordedCounts()
check(v == 1 and d == 1 and n == 2, "recorded counts")
SlashCmdList.UNTAMED("recorded")

-- Reputation
local rtip = ns.ItemTooltip(20438)()
local found
for _, l in ipairs(rtip) do if type(l) == "string" and l:find("Revered") and l:find("Silverwing") then found = l end end
print("  rep line:", found)
check(found ~= nil, "outrunner's bow needs Revered with Silverwing Sentinels (Alliance)")
if ns.GearItems then check(ns.GearBestFor("RANGED", 1, 60, 0, "dungeon", false) ~= nil, "dungeon-only gear filter") end

-- Restock: a vendor selling Jagged Arrow (11285) and a Medium Quiver
GetMerchantNumItems = function() return 2 end
GetMerchantItemID = function(i) return ({ 11285, 11362 })[i] end
GetMerchantItemInfo = function(i) return ({ "Jagged Arrow", "Medium Quiver" })[i], nil, ({ 1000, 1000 })[i], ({ 200, 1 })[i] end
UnitLevel = (function(old) return function(u) if u == "player" then return 45 end return old(u) end end)(UnitLevel)
local plan = ns.RestockTest.Plan()
check(#plan >= 1 and plan[1].id == 11285, "restock plans Jagged Arrow")
BOUGHT = {}
ns.Restock()
check(#BOUGHT == 5, "restock buys 5 stacks of 200 for 1000 arrows (" .. #BOUGHT .. ")")

-- Wishlist
ALT = true
IsAltKeyDown = function() return ALT end
ns.ItemClick(3021)()
ALT = false
check(ns.OnWishlist(3021), "alt-click adds to wishlist")
-- world map pins: drawn as textures on one overlay, with no frames made in the open map and no map hooks
WorldMapFrame._shown = true
ns.Pins_Focus({ 2384 }, "Starving Mountain Lion", false)
WorldMapFrame.SetMapID(WorldMapFrame, 1424)
TICK(2)
local drawn = ns.Pins_Drawn()
check(#drawn > 0 and drawn[1].npcId == 2384, "focused beast drawn on the map (" .. #drawn .. " pins)")
check(MAP_FRAMES_WHILE_OPEN == 0, "no frames created inside the open map")
check(WorldMapFrame._scripts.OnShow == nil, "Untamed doesn't hook the world map")
InputUtil = { IsGamepadUIEnabled = function() return true end }
WorldMapFrame.SetMapID(WorldMapFrame, 1429)
ns.OpenMapTo(1424)
check(WorldMapFrame:GetMapID() == 1429, "controller UI: Untamed never changes the map's zone")
InputUtil = nil
WorldMapFrame._shown = false
local pins = ns.WishlistPins()
check(pins and #pins > 0, "wishlist sources become map pins (" .. (pins and #pins or 0) .. ")")
ns.UI_Show("wishlist")

-- Dungeons
ns.UI_Show("dungeons")
local di = ns.DungeonInfo("The Deadmines")
local nb = 0 for _ in pairs(di.bosses) do nb = nb + 1 end
print("  deadmines: bosses", nb, "beasts", #di.beasts, "entrance", di.entrance and ns.ZoneName(di.entrance[1]))
check(nb > 3 and di.entrance, "dungeon guide finds Deadmines bosses and entrance")

-- Reputation and Auction House
ns.UI_Show("reputation")
local rw = ns.RepTest.Rewards()
local nf = 0 for _ in pairs(rw) do nf = nf + 1 end
check(nf > 5, "reputation rewards found for " .. nf .. " factions")
check(rw[889] == nil and rw[890] ~= nil, "only your side's battleground faction (Alliance here)")
local outrunnerHorde = false
for _, ids in pairs(rw[890] or {}) do for _, id in ipairs(ids) do if ns.SearchDB().I[id][1] == "Outrider's Bow" then outrunnerHorde = true end end end
print("  Alliance sees Outrider's Bow:", outrunnerHorde)
NUM_BROWSE_TO_DISPLAY = 2
BrowseScrollFrame = CreateFrame("Frame")
FauxScrollFrame_GetOffset = function() return 0 end
for i = 1, 2 do local b = CreateFrame("Button", "BrowseButton" .. i); b.GetName = function() return "BrowseButton" .. i end; b:Show() end
GetAuctionItemInfo = function(_, i) local id = ({ 3021, 2504 })[i]; return "x", nil, 1, 2, true, 1, nil, 1, 1, 1, 0, nil, nil, nil, nil, 0, id, true end
ns.AuctionTest.Update()

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
  ns.GearAlertTest.AlertNewLevel(20)
  ns.GearAlertTest.AlertZone()
  local id = ns.GearBestFor("RANGED", 1, 20, 0, "easy", false)
  print("  best easy ranged by 20:", id, id and ns.SearchDB().I[id][1])
  check(id ~= nil, "easy ranged upgrade found")
  check(#lines == 1, "gear tooltip line for item " .. tostring(bestId) .. ": " .. tostring(lines[1]))
end
-- Layout pass: every page builds and refreshes, and the new filters work
local bf = ns.BrowserFilter()
bf.teaches = "Bite"; bf.where = "near"; bf.family = "Wolf"
ns.UI_Show("browse")
bf.teaches = "any"; bf.where = "any"; bf.family = "any"
ns.UI_Show("home")
for _, k in ipairs({ "home", "abilities", "builds", "care", "stable", "recommend", "browse", "plan", "rares", "search", "wishlist", "gear",
  "dungeons", "supplies", "spells", "talents", "reputation", "quests", "settings" }) do ns.UI_Show(k) end
check(true, "every page opens")
-- Library books: names, bags, hand-ins, map, page
check(ns.BookFor("Archmage Antonidas") and ns.BookFor("Archmage Antonidas").name:find("Autobiography"), "quest title finds its book")
check(ns.BookFor("Tough Jerky") == nil, "food is not a book")
local oldInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bag, slot)
  if bag == 0 and slot == 1 then return { itemID = 999001, stackCount = 1, hyperlink = "|cffffffff|Hitem:999001|h[Goaz Scrolls]|h|r" } end
  return oldInfo(bag, slot)
end
FIRE("BAG_UPDATE_DELAYED")
local goaz
for _, b in ipairs(ns.Books) do if b.name == "Goaz Scrolls" then goaz = b end end
check(ns.BookStatus(goaz) == "bags", "book in your bags")
C_QuestLog.GetTitleForQuestID = function(id) if id == 78146 then return "Goaz Scrolls" end end
FIRE("QUEST_TURNED_IN", 78146)
check(ns.BookStatus(goaz) == "done", "book handed in")
C_Container.GetContainerItemInfo = oldInfo
local nbook = 0
for _, src in ipairs(ns.PinSources) do local ok, p = pcall(src, 1429); if ok and p then for _, q in ipairs(p) do if q.icon and q.icon:find("Book_09") then nbook = nbook + 1 end end end end
check(nbook > 10, "books you still need are on the map (" .. nbook .. ")")
ns.UI_Show("books")
ns.BookArrow(); ns.LibrarianArrow()

-- books handed in before: found among your completed quests
C_QuestLog.GetAllCompletedQuestIDs = function() return { 3108, 79092, 5 } end
local loaded = false
C_QuestLog.GetTitleForQuestID = function(id)
  if id == 79092 then if loaded then return "Fury of the Land" end return nil end
  if id == 3108 then return "Etched Sigil" end
end
C_QuestLog.RequestLoadQuestByID = function() loaded = true end
ns.BooksScanCompleted(true)
TICK(40)
local fury
for _, b in ipairs(ns.Books) do if b.name == "Fury of the Land" then fury = b end end
check(ns.BookStatus(fury) == "done", "a book handed in before is found among completed quests")

-- Chest spots: world positions turned into map spots
local function origin(id) local k = id - 1411; return (k % 8) * 4000, math.floor(k / 8) * 4000 end
C_Map.GetMapPosFromWorldPos = function(cont, v, id)
  local ox, oy = origin(id)
  return id, CreateVector2D((-v.y - ox) / 4000, (-v.x - oy) / 4000)
end
local ox, oy = origin(1429)
ns.ChestWorld[1] = { 1, -(oy + 2000), -(ox + 1000), 2, -(oy + 100), -(ox + 3900), 1, -(oy + 9999), -(ox + 1000) }
ns.ChestCacheClear()
local spots = ns.ChestSpotsOn(1429)
check(#spots == 6 and math.floor(spots[1]) == 25 and math.floor(spots[2]) == 50, "chest spots on the map (" .. #spots / 3 .. ")")
ns.ScanReport()
-- near a chest spot, and a chest as the interact target
local heard = {}
local keepAlert = ns.Alert
ns.Alert = function(m) heard[#heard + 1] = m end
local realToWorld, realPW = ns.ToWorld, ns.PlayerWorld
ns.ToWorld = function(map, x, y) return 0, x * 10, y * 10 end
ns.PlayerWorld = function() return 0, spots[1] * 10 + 30, spots[2] * 10 end
ns.ChestTest.CheckNearSpots()
check(heard[1] and heard[1]:find("Chest spot nearby") and heard[1]:find("30 yd"), "near a chest spot: " .. tostring(heard[1]))
ns.ChestTest.CheckNearSpots()
check(#heard == 1, "the same spot doesn't nag")
ns.ToWorld, ns.PlayerWorld = realToWorld, realPW
local oldExists, oldGUID, oldName = UnitExists, UnitGUID, UnitName
UnitExists = function(u) return u == "softinteract" or oldExists(u) end
UnitGUID = function(u) if u == "softinteract" then return "GameObject-0-1-1-1-2855-0000ABCD" end return oldGUID(u) end
UnitName = function(u) if u == "softinteract" then return "Solid Chest" end return oldName(u) end
FIRE("PLAYER_SOFT_INTERACT_CHANGED")
check(heard[2] and heard[2]:find("Chest right here"), "chest as the interact target")
UnitExists, UnitGUID, UnitName = oldExists, oldGUID, oldName
ns.Alert = keepAlert
C_VignetteInfo = { GetVignettes = function() return { "v1" } end,
  GetVignetteInfo = function() return { name = "Battered Chest", atlasName = "VignetteLoot", objectGUID = "GameObject-0-1-1-1-2843-0000ABCD" } end }
local said
local oldAlert = ns.Alert
ns.Alert = function(m) said = m end
FIRE("VIGNETTES_UPDATED")
check(said and said:find("Battered Chest"), "chest marked on the minimap: alert")
ns.Alert = oldAlert

-- Recorder: beasts and rares you see, books, minimap marks
UnitIsPlayer = function() return false end
UnitGUID = function(u) return "Creature-0-1-1-1-2850-0000ABCD" end
UnitClassification = function() return "rare" end
UnitCreatureFamily = function() return "Cat" end
ns.RecorderTest.RecordUnit("target", true)
local r = ns.db.recorded[ns.FLAVOR]
check(r.beasts[2850] and r.rares[2850] and #r.beasts[2850].spots == 3, "a rare cat you target is noted with its spot")
check(r.books["Goaz Scrolls"] and r.books["Goaz Scrolls"].quest == 78146, "book quest ID noted")
check(next(r.marks) ~= nil, "minimap marks noted")
local v, d, n, x = ns.RecordedCounts()
check(x and x.beasts >= 1, "counts include sightings")
print("DONE")
