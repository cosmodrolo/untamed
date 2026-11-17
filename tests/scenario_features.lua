-- New features: stable-first route, stable manager, builds, rare scanner, ammo, leveling, data sharing.
local ns = NS
local function clean(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end

FIRE("ADDON_LOADED", "Untamed")
-- OpenMap is installed (its controller view is tested with the map pins below)
OpenMapAPI = { version = 4 }
do
  local libs = {}
  LibStub = setmetatable({ NewLibrary = function(self, name) libs[name] = libs[name] or {} return libs[name] end,
    GetLibrary = function(self, name) return libs[name] end, libs = libs }, { __call = function(self, name) return libs[name] end })
end
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
check(_G.UntamedAutoShotBar == nil, "no auto shot bar any more")
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

-- The window: six sections, every page in exactly one, and the controller's step picker
do
  ns.db.lastPage = nil
  ns.UI_Show("home")
  local secs, curSec, curTab = ns.UI_Sections()
  local n, seen = 0, {}
  for _, sec in ipairs(secs) do for _, k in ipairs(sec[2]) do n = n + 1; seen[k] = true end end
  check(#secs == 6 and curSec == "today" and curTab == "home", "six sections, Home opens in Today (" .. tostring(curSec) .. ")")
  check(n >= 19 and seen.browse and seen.abilities and seen.books and seen.gear, "every page sits in a section (" .. n .. ")")
  ns.UI_StepSection(1)
  local _, s2, t2 = ns.UI_Sections()
  check(s2 == "bestiary" and t2 == "browse", "R1 goes to the Bestiary's first page (" .. tostring(t2) .. ")")
  ns.UI_StepPage(1)
  check(select(3, ns.UI_Sections()) == "recommend", "R2 goes to the section's next page")
  ns.UI_StepSection(-1); ns.UI_StepSection(1)
  check(select(3, ns.UI_Sections()) == "recommend", "a section remembers the page you were on")
  ns.UI_Show("books")
  ns.UI_StepSection(1)
  check(select(2, ns.UI_Sections()) == "settings", "R1 from the last section goes to Settings")
  ns.UI_StepSection(-1)
  check(select(2, ns.UI_Sections()) == "world", "L1 from Settings goes back to World")
  ns.UI_Show("settings")
  check(select(2, ns.UI_Sections()) == "settings", "Settings is its own place")
  ns.UI_StepSection(1)
  check(select(2, ns.UI_Sections()) == "today", "R1 from Settings goes to the first section")
  -- the picker: rects are l, r, t, b
  local side = { { l = 10, r = 190, t = 500, b = 470 }, { l = 10, r = 190, t = 468, b = 438 } }
  local rows = { { l = 200, r = 900, t = 440, b = 420 }, { l = 200, r = 900, t = 418, b = 398 } }
  local drop = { l = 210, r = 360, t = 500, b = 476 }
  local all = { side[2], rows[1], rows[2], drop }
  check(ns.PadPick(side[1], all, "down") == 1, "pad: down the list of pages")
  check(ns.PadPick(side[1], all, "right") == 4, "pad: right from the list to the page's first control")
  check(ns.PadPick(drop, { side[1], side[2], rows[1], rows[2] }, "down") == 3, "pad: down from a narrow control to the wide row under it")
  check(ns.PadPick(rows[1], { side[1], side[2], rows[2], drop }, "down") == 3, "pad: down a list row by row")
  check(ns.PadPick(rows[2], { side[1], side[2], rows[1], drop }, "down") == nil, "pad: nothing below the last row")
  check(ns.PadPick(rows[1], { side[1], side[2], rows[2], drop }, "left") == 2, "pad: left from a row back to the list of pages")
  for _, a in ipairs({ "up", "down", "left", "right", "accept", "alt", "back", "secnext", "pagenext" }) do ns.PadAct[a]() end
  check(true, "pad: every button runs without a controller")
end

-- Bestiary: plain-word search, and the page follows the list
do
  local p = ns.BestiaryParse("fast cat")
  check(p.family == "Cat" and p.fast and #p.words == 0, "search: 'fast cat' is a family and a speed")
  p = ns.BestiaryParse("bite 6")
  check(#p.abilities == 1 and p.abilities[1][1] == "Bite" and p.abilities[1][2] == 6 and not p.lo, "search: 'bite 6' is an ability and its rank")
  p = ns.BestiaryParse("rare badlands 30-40")
  check(p.rare and p.lo == 30 and p.hi == 40 and p.words[1] == "badlands", "search: rare, a zone word and a level range")
  p = ns.BestiaryParse("furious howl wolves new")
  check(#p.abilities == 1 and p.abilities[1][1] == "Furious Howl" and p.family == "Wolf" and p.fresh, "search: a two-word ability, a plural family, new")
  check(ns.BestiaryMatches("starving mountain", 2384) and not ns.BestiaryMatches("starving wolf", 2384), "search: name words must all match")
  check(ns.BestiaryMatches("cat 23", 2384) == (ns.Beasts[2384][2] <= 23 and ns.Beasts[2384][3] >= 23), "search: a level on its own")
  ns.UI_Show("browse")
  local first = ns.BestiarySelected()
  check(first ~= nil, "bestiary: opens on a beast's page")
  ns.BestiarySelect(2384)
  check(ns.BestiarySelected() == 2384, "bestiary: picking a beast turns the page")
end

-- Stable: the pets journal
do
  ns.cdb.pets = ns.cdb.pets or {}
  ns.cdb.pets["Rex|Cat"] = { name = "Rex", family = "Cat", level = 20, known = { Bite = 1 }, stabled = true, seen = 0 }
  ns.cdb.pets["Starving Mountain Lion|Cat"] = { name = "Starving Mountain Lion", family = "Cat", level = 23, known = {}, stabled = true, seen = 0 }
  ns.UI_Show("stable")
  check(ns.StableSelected() ~= nil, "stable: opens on a pet's page")
  local id, sure = ns.PetOrigin(ns.cdb.pets["Starving Mountain Lion|Cat"])
  check(id == 2384 and sure, "stable: a pet that kept its name is matched to its beast")
  local id2, sure2 = ns.PetOrigin(ns.cdb.pets["Rex|Cat"])
  check(id2 and ns.Beasts[id2][4] == "Cat" and not sure2, "stable: a renamed pet gets a stand-in of its family")
  local nextUp = ns.PetNextToLearn(ns.cdb.pets["Rex|Cat"], 5)
  check(type(nextUp) == "table" and #nextUp <= 5, "stable: what to tame next (" .. #nextUp .. ")")
  for _, n in ipairs(nextUp) do check(ns.Beasts[n.beast] and not ns.HunterKnows(n.ability, n.rank), "stable: next-to-learn is a rank you don't know") end
  local kin, mine = ns.PetFasterKin(ns.cdb.pets["Starving Mountain Lion|Cat"])
  check(kin == nil or (ns.Beasts[kin][4] == "Cat" and (not mine or ns.Beasts[kin][9] < mine)), "stable: a faster beast of the family, if there is one")
  ns.cdb.pets["Rex|Cat"], ns.cdb.pets["Starving Mountain Lion|Cat"] = nil, nil
end

-- the other journal pages build and fill
ns.UI_Show("recommend"); ns.UI_Show("rares"); ns.UI_Show("abilities"); ns.UI_Show("care"); ns.UI_Show("builds"); ns.UI_Show("gear"); ns.UI_Show("wishlist"); ns.UI_Show("dungeons"); ns.UI_Show("reputation"); ns.UI_Show("supplies"); ns.UI_Show("spells"); ns.UI_Show("quests"); ns.UI_Show("books"); ns.UI_Show("search"); ns.UI_Show("talents"); ns.UI_Show("rotation"); ns.UI_Show("plan"); ns.UI_Show("settings"); ns.UI_Show("home")
check(select(3, ns.UI_Sections()) == "home", "Find a Pet, Rares and Today open without a hitch")

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
-- OpenMap's controller view: Blizzard's canvas goes see-through, and the pins are handed over as a
-- HereBeDragons-shaped list of Untamed's own frames
do
  local child = WorldMapFrame.ScrollContainer.Child
  local lib0 = ns.Pins_Pad()
  check(lib0 == nil, "no icon list for OpenMap until its controller view is up")
  child.GetAlpha = function() return 0 end
  TICK(2)
  local lib, frames, pad = ns.Pins_Pad()
  local n, sample = 0, nil
  for icon, data in pairs(lib and lib.worldmapPins or {}) do n = n + 1; sample = sample or { icon, data } end
  check(pad and lib == LibStub.libs["HereBeDragons-Untamed-Pins-2.0"] and n > 0, "controller view: pins handed to OpenMap (" .. n .. ")")
  check(sample and sample[1].UiMapID == sample[2].uiMapID and type(sample[1].x) == "number" and sample[1].SetPoint ~= nil,
    "controller view: each icon says its map and place")
  check(MAP_FRAMES_WHILE_OPEN == 0, "controller view: still no frames created inside the open map")
  child.GetAlpha = function() return 1 end
  TICK(2)
  n = 0
  for _ in pairs(lib.worldmapPins) do n = n + 1 end
  check(n == 0 and not select(3, ns.Pins_Pad()), "controller view off: the list is emptied")
end
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

-- Character planning
for _, k in ipairs({ "spells", "talents", "gear", "quests" }) do ns.UI_Show(k) end
local T = ns.CharacterTest
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
-- opening it: the spot goes off the map and the nearby alert for a while
do
  local map = C_Map.GetBestMapForUnit("player")
  ns.ToWorld = function(m, x, y) return 0, x * 10, y * 10 end
  ns.PlayerWorld = function() return 0, spots[1] * 10 + 30, spots[2] * 10 end
  ns.chestSeenAt = GetTime()
  check(ns.ChestTest.ChestLooted() == true, "opening a chest marks its spot")
  local spots, hidden = ns.ChestSpotsOn(map), 0
  for i = 1, #spots, 3 do if ns.ChestOpened(map, i) then hidden = hidden + 1 end end
  check(hidden == 1, "one chest spot is marked opened")
  check(ns.ChestTest.ChestLooted() == false, "a second loot window right after doesn't mark another")
  ns.cdb.chestOpened = nil
  ns.ToWorld, ns.PlayerWorld = realToWorld, realPW
end
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
-- Bag marks: arrow for an upgrade, lock when bound, coin when it can still be sold
do
  local keep = C_Container.GetContainerItemInfo
  local up
  for id, g in pairs(ns.GearItems) do if g[1] == "HEAD" and g[2] <= 10 and g[4] == 0 and g[3] > 5 then up = id break end end
  local bagItems = { { itemID = up, isBound = false, quality = 2 }, { itemID = 6948, isBound = true, quality = 1 }, { itemID = 117, isBound = false, quality = 0 } }
  C_Container.GetContainerItemInfo = function(bag, slot) return bag == 0 and bagItems[slot] or nil end
  local keepInstant = C_Item.GetItemInfoInstant
  bagItems[4] = { itemID = 2512, isBound = false, quality = 1 }
  C_Item.GetItemInfoInstant = function(id)
    if id == up then return id, "Armor", "Leather", "INVTYPE_HEAD", 0, 4, 2 end
    if id == 2512 then return id, "Projectile", "Arrow", "", 0, 6, 2 end
    return keepInstant(id)
  end
  local a, b, c = ns.BagMarksFor(0, 1), ns.BagMarksFor(0, 2), ns.BagMarksFor(0, 3)
  local ammo = ns.BagMarksFor(0, 4)
  check(ammo and not ammo.coin, "bag marks: arrows get no coin")
  C_Item.GetItemInfoInstant = keepInstant
  check(a and a.up and a.coin and not a.lock, "bag marks: unbound upgrade gets the arrow and the coin")
  check(b and b.lock and not b.coin and not b.up, "bag marks: a soulbound item gets the lock")
  check(c and not c.coin and not c.lock, "bag marks: grey junk gets nothing")
  check(ns.BagMarksFor(0, 9) == false, "bag marks: empty slot")
  local s = ns.GearScoreOf(up, "item:" .. up .. ":0:0:0:0:0:0:0")
  check(s == ns.GearItems[up][3], "gear score: no suffix, same as the list")
  ns.BagMarksTick()
  ns.BagMarksCommand()
  C_Container.GetContainerItemInfo = keep
end
-- Care macro: feed when hungry and healthy, mend otherwise, revive when the pet is known dead
do
  local kE, kH, kHM, kD = UnitExists, UnitHealth, UnitHealthMax, UnitIsDead
  local kHap = C_PetInfo and C_PetInfo.GetPetHappiness
  local kGet = GetPetHappiness
  local happy = 2
  C_PetInfo = C_PetInfo or {}
  C_PetInfo.GetPetHappiness = function() return happy end
  GetPetHappiness = function() return happy end
  UnitExists = function(u) if u == "pet" then return true end return kE(u) end
  UnitIsDead = function() return false end
  UnitHealth = function() return 100 end; UnitHealthMax = function() return 100 end
  local kFood = ns.EdibleFood
  ns.EdibleFood = function() return { { 2672, 0, 1, 5, 10, "Stringy Wolf Meat" } } end
  local body, mode = ns.PetCareBody()
  check(mode == "feed" and body:find("Feed Pet", 1, true) and body:find("/use [nocombat,pet,@pet,nodead] 0 1", 1, true), "care macro: hungry pet gets fed")
  check(#body <= 255, "care macro fits in a macro")
  UnitHealth = function() return 40 end
  body, mode = ns.PetCareBody()
  check(mode == "mend" and not body:find("/use", 1, true), "care macro: a hurt pet is mended first")
  UnitHealth = function() return 100 end
  happy = 3
  body, mode = ns.PetCareBody()
  check(mode == "mend", "care macro: a happy pet is mended, not fed")
  ns.cdb.petDead = true
  body = ns.PetCareBody()
  check(body:find("[nopet] Revive Pet", 1, true), "care macro: a dead pet whose body is gone is revived, not called")
  ns.cdb.petDead = false
  check(ns.PetCareBody():find("[nopet] Call Pet", 1, true), "care macro: a dismissed pet is called")
  ns.EdibleFood = kFood
  UnitExists, UnitHealth, UnitHealthMax, UnitIsDead = kE, kH, kHM, kD
  C_PetInfo.GetPetHappiness = kHap; GetPetHappiness = kGet
end
-- Looks: a family's skins, and the gallery on a beast's page
do
  local list, unknown = ns.FamilyLooks("Cat")
  local n = 0
  for _, e in ipairs(list) do n = n + #e.ids end
  check(#list >= 10 and #list <= 25 and n > #list, "looks: cats come in a handful of looks, several beasts each")
  local e = list[1]
  check(ns.LookOf(e.ids[1]) == e.look and e.lo <= e.hi, "looks: a beast knows its look")
  check(ns.Beasts[ns.LookPick(e, 60)] ~= nil, "looks: a beast to show for a look")
  ns.UI_Show("browse")
  ns.BestiarySelect(e.ids[1])
  ns.BestiaryLooks(true)
  ns.BestiarySelect(list[2].ids[1])
  ns.BestiaryLooks(false)
  check(ns.BestiarySelected() == list[2].ids[1], "looks: the gallery opens and closes on a beast's page")
end
-- Dungeon trash loot isn't called a world drop
do
  local w = ns.ItemWays(7755)
  check(w.trash == "Scarlet Monastery" and w.dungeon and not w.world, "Flintrock Shoulders: Scarlet Monastery trash, not a world drop")
  local srcs = ns.ItemSources(7755)
  check(srcs[1] and srcs[1].kind == "dungeon" and srcs[1].inst == "Scarlet Monastery", "trash loot has the dungeon as its source")
end
-- Gear rank, and quest reward advice
do
  local up
  for id, g in pairs(ns.GearItems) do if g[1] == "HEAD" and g[2] <= 10 and g[4] == 0 and g[3] > 5 then up = id break end end
  local rank, total, best = ns.GearRank(up)
  check(rank and rank >= 1 and total >= rank and best, "gear rank: an item has a place among its slot")
  local r1 = ns.GearRank(best)
  check(r1 == 1, "gear rank: the best item is rank 1")
  local judged = ns.QuestAdviceJudge({ { id = up, name = "Hat" }, { id = 117, name = "Jerky" } })
  check(judged[1].pick == "wear" and judged[1].gain > 0 and not judged[2].pick, "quest advice: the upgrade is the pick")
  local keepInfo = C_Item.GetItemInfo
  C_Item.GetItemInfo = function(id) return "x", nil, 1, nil, nil, nil, nil, nil, nil, nil, id == 117 and 50 or 20 end
  judged = ns.QuestAdviceJudge({ { id = 4540, name = "Bread" }, { id = 117, name = "Jerky" } })
  check(judged[2].pick == "sell" and not judged[1].pick, "quest advice: nothing to wear, take the one that sells for most")
  C_Item.GetItemInfo = keepInfo
  GetNumQuestChoices = function() return 2 end
  GetQuestItemInfo = function(_, i) return i == 1 and "Hat" or "Jerky", 134400, 1, 2, true, i == 1 and up or 117 end
  GetQuestItemLink = function() return nil end
  ns.QuestAdviceTest.Fill("complete")
  ns.QuestAdviceTest.Close()
end
-- Restock: "Fill my quiver" buys what still fits in the quiver
do
  local kInv, kInstant, kInfo, kSlots = GetInventoryItemID, C_Item.GetItemInfoInstant, C_Container.GetContainerItemInfo, C_Container.GetContainerNumSlots
  GetInventoryItemID = function(u, slot) if slot == 23 then return 7371 end return kInv(u, slot) end       -- bag 4 holds a quiver
  C_Item.GetItemInfoInstant = function(id) if id == 7371 then return id, "Quiver", "Quiver", "INVTYPE_QUIVER", 0, 11, 2 end return kInstant(id) end
  C_Container.GetContainerNumSlots = function(bag) if bag == 4 then return 14 end return kSlots(bag) end
  C_Container.GetContainerItemInfo = function(bag, slot)
    if bag == 4 then
      if slot <= 3 then return { itemID = 2515, stackCount = 200 } end
      if slot == 4 then return { itemID = 2515, stackCount = 50 } end
      if slot == 5 then return { itemID = 2512, stackCount = 200 } end     -- another kind of arrow: no room there
      return nil
    end
    return kInfo(bag, slot)
  end
  local room, slots = ns.QuiverRoom(2515)
  check(slots == 14 and room == 150 + 9 * 200, "restock: room left in a 14 slot quiver")
  GetInventoryItemID, C_Item.GetItemInfoInstant, C_Container.GetContainerItemInfo, C_Container.GetContainerNumSlots = kInv, kInstant, kInfo, kSlots
  check(ns.QuiverRoom(2515) == nil, "restock: no quiver worn, no quiver amount")
end
-- Weakest slot
do
  local w = ns.GearWeakest()
  check(w and w.slot and w.rank > 1 and w.total >= w.rank and w.fix and w.gain > 0, "weakest slot: a slot, its rank and something to get")
  ns.UI_Show("gear")
end
-- Talent builds must be possible: tier gates and the arrows between talents
do
  for _, b in ipairs(ns.CharacterTest.Builds) do
    local problem = ns.CharacterTest.BuildProblem(b)
    check(problem == nil, "talent build " .. b.key .. " can be followed: " .. tostring(problem))
  end
  local bm = 0
  for _, s in ipairs(ns.CharacterTest.Builds[1].steps) do
    if s[1] == 1 then bm = bm + s[3] end
    if s[2] == "Bestial Wrath" then check(bm == 31, "leveling build reaches Bestial Wrath with point 31 (level 40): " .. bm) end
  end
end
print("DONE")
