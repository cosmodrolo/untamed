local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Library books: where each one is, which you've picked up and handed in, and a heads-up when
-- you're close to one you still need. Replaces the Library Books addon.
--  * In your bags: read from your bags (by name; the item ID is noted the first time).
--  * Handed in: noted when you turn in the book's quest at the librarian (QUEST_TURNED_IN), or
--    marked by hand (right-click a book) for ones you handed in before.
--  * Map: books you still need on the world map, OpenMap and the minimap (textures only).
--  * Nearby: when you come within ns.db.bookRadius yards (300) of a book you still need.
-- /ut books opens the tab, /ut book gives an arrow to the nearest one, /ut librarian to yours.
---------------------------------------------------------------------------

local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local warned = {}        -- [book name] = time of the last nearby alert
local bagged = {}        -- [book name] = count in bags (refreshed on BAG_UPDATE_DELAYED)

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end

local function Done()
  ns.cdb.booksDone = ns.cdb.booksDone or {}
  return ns.cdb.booksDone
end

local function Norm(s) return (s or ""):lower():gsub("[%p%s]", "") end
local byNorm = {}
for _, b in ipairs(ns.Books or {}) do byNorm[Norm(b.name)] = b end

-- a quest or item title to the book it is ("Archmage Antonidas" -> the Autobiography)
local function BookFor(title)
  if not title or ns.IsSecret(title) then return nil end
  local n = Norm(title)
  if n == "" then return nil end
  if byNorm[n] then return byNorm[n] end
  for key, b in pairs(byNorm) do
    if #n >= 6 and (key:sub(1, #n) == n or n:sub(1, #key) == key) then return b end
  end
end
ns.BookFor = BookFor

local function MyFaction()
  return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
end

local function Wanted(b)
  if Done()[b.name] then return false end
  if b.fac and b.fac ~= MyFaction() then return false end
  return true
end

-- bags: book items by name
local function ScanBags()
  wipe(bagged)
  if not C_Container then return end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and Plain(info.hyperlink)
      local name = link and link:match("%[(.-)%]")
      local b = name and BookFor(name)
      if b then
        bagged[b.name] = (bagged[b.name] or 0) + (info.stackCount or 1)
        ns.cdb.bookItems = ns.cdb.bookItems or {}
        if info.itemID and not ns.cdb.bookItems[b.name] then
          ns.cdb.bookItems[b.name] = info.itemID
          if ns.RecordBook then ns.RecordBook(b.name, "item", info.itemID) end
        end
      end
    end
  end
end

function ns.BookStatus(b)
  if Done()[b.name] then return "done" end
  if bagged[b.name] then return "bags" end
  return "out"
end

function ns.BooksCount()
  local done, bags = 0, 0
  for _, b in ipairs(ns.Books) do
    local s = ns.BookStatus(b)
    if s == "done" then done = done + 1 elseif s == "bags" then bags = bags + 1 end
  end
  return done, bags
end

-- nearest spot of a book you still need: book, spot, distance
local function Nearest(onlyWanted)
  local pc, pe, pn = ns.PlayerWorld()
  if not pc then return nil end
  local best, bs, bd
  for _, b in ipairs(ns.Books) do
    if (not onlyWanted or (Wanted(b) and not bagged[b.name])) then
      for _, s in ipairs(b.spots) do
        local c, e, n = ns.ToWorld(s[1], s[2], s[3])
        local d = ns.Distance(pc, pe, pn, c, e, n)
        if d and (not bd or d < bd) then best, bs, bd = b, s, d end
      end
    end
  end
  return best, bs, bd
end
ns.NearestBook = Nearest

local DIRS = { "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest" }
local function Direction(s)
  local pc, pe, pn = ns.PlayerWorld()
  local c, e, n = ns.ToWorld(s[1], s[2], s[3])
  if not pc or not c or pc ~= c then return "" end
  local ang = math.atan2(e - pe, n - pn)
  local i = math.floor((ang / (2 * math.pi) * 8) + 0.5) % 8
  return L[DIRS[i + 1]]
end

function ns.BookArrow()
  local b, s, d = Nearest(true)
  if not b then ns.Print(L["No library book you still need on this continent."]) return end
  ns.Arrow_Set(s[1], s[2], s[3], b.name)
  ns.Print(string.format(L["%s: %s, %s (%s)."], b.name, ns.ZoneName and ns.ZoneName(s[1]) or "", ns.FormatDistance(d), s[4] or ""))
end

function ns.LibrarianArrow()
  local lib = ns.Librarians[MyFaction()]
  ns.Arrow_Set(lib.map, lib.x, lib.y, lib.name)
  ns.Print(string.format(L["%s, %s."], lib.name, lib.where))
end

-- the nearby alert (every 3 s, out of fights)
local function CheckNearby()
  if ns.db.bookAlerts == false or InCombatLockdown() then return end
  local b, s, d = Nearest(true)
  if not b or not d or d > (ns.db.bookRadius or 300) then return end
  if UnitLevel("player") + 5 < (b.lvl or 1) then return end
  local now = GetTime()
  if warned[b.name] and now - warned[b.name] < 900 then return end
  warned[b.name] = now
  local dir = Direction(s)
  ns.Alert(C.GOLD .. L["Library book nearby: "] .. "|r" .. b.name .. C.GREY .. string.format("  %d %s %s", d, L["yd"], dir) .. "|r", true)
  ns.Print(string.format(L["Library book nearby: %s, %d yards %s (%s). Type /ut book for an arrow."], b.name, d, dir, s[4] or ""))
end

-- a reminder in your capital when you carry books to hand in
local function CapitalNote()
  local lib = ns.Librarians[MyFaction()]
  local map = C_Map.GetBestMapForUnit("player")
  if map ~= lib.map then return end
  local _, bags = ns.BooksCount()
  if bags > 0 then
    ns.Print(string.format(L["You have %d library book(s) to hand in to %s (%s). Type /ut librarian for an arrow."], bags, lib.name, lib.where))
  end
end

-- handed in: the book's quest at the librarian
local function OnTurnedIn(questID)
  if not questID or ns.IsSecret(questID) then return end
  local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
  local b = BookFor(title)
  if not b then return end
  Done()[b.name] = questID
  if ns.RecordBook then ns.RecordBook(b.name, "quest", questID) end
  local done = ns.BooksCount()
  ns.Print(string.format(L["Library book handed in: %s (%d so far)."], b.name, done))
  for _, m in ipairs(ns.BookMilestones) do
    if done == m[1] then ns.Print(string.format(L["That's %d books: the librarian has a reward quest for you (%s)."], m[1], m[3])) end
  end
  if ns.Pins_Refresh then ns.Pins_Refresh() end
end

-- Books handed in before Untamed was watching: go through the quests the game says you've
-- completed and match their titles to the books. Titles load a few at a time, so this runs
-- in small steps after login (and with /ut books scan).
local scan
local function TitleOf(id)
  local t
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, v = pcall(C_QuestLog.GetTitleForQuestID, id)
    if ok then t = v end
  end
  if not t and C_QuestLog and C_QuestLog.GetQuestInfo then
    local ok, v = pcall(C_QuestLog.GetQuestInfo, id)
    if ok then t = v end
  end
  if t and not ns.IsSecret(t) and t ~= "" then return t end
end

local function ScanCheck(id)
  local title = TitleOf(id)
  if not title then return false end
  local b = BookFor(title)
  if b and not Done()[b.name] then
    Done()[b.name] = id
    scan.found = scan.found + 1
    if ns.RecordBook then ns.RecordBook(b.name, "quest", id) end
  end
  return true
end

local function ScanFinish()
  local found, loud = scan.found, scan.loud
  scan = nil
  ns.cdb.booksScanned = time()
  if found > 0 or loud then
    local done = ns.BooksCount()
    ns.Print(string.format(L["Library books: found %d you handed in before. %d handed in so far."], found, done))
  end
  if ns.Pins_Refresh then ns.Pins_Refresh() end
  if ns.MinimapRebuild then ns.MinimapRebuild() end
  ns.UI_Refresh()
end

function ns.BooksScanCompleted(loud)
  if scan then return end
  local ids
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
    local ok, v = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    if ok and type(v) == "table" then ids = v end
  end
  if not ids and GetQuestsCompleted then
    local ok, v = pcall(GetQuestsCompleted)
    if ok and type(v) == "table" then
      ids = {}
      for id in pairs(v) do ids[#ids + 1] = id end
    end
  end
  if not ids or #ids == 0 then
    if loud then ns.Print(L["The game didn't give a list of your completed quests. Right-click a book in the list to mark it handed in."]) end
    return
  end
  scan = { ids = ids, i = 0, waiting = {}, nwait = 0, found = 0, loud = loud, pass = 1 }
  if loud then ns.Print(string.format(L["Checking your %d completed quests for library books..."], #ids)) end
  local driver = CreateFrame("Frame")
  local t = 0
  driver:SetScript("OnUpdate", function(self, e)
    t = t + e
    if t < 0.1 then return end
    t = 0
    if not scan then self:SetScript("OnUpdate", nil) return end
    for _ = 1, 40 do
      scan.i = scan.i + 1
      local id = scan.ids[scan.i]
      if not id then break end
      if not ScanCheck(id) then
        scan.waiting[#scan.waiting + 1] = id
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, id) end
      end
    end
    if scan.i >= #scan.ids then
      -- titles that weren't loaded yet: two more passes, a few seconds apart
      if #scan.waiting > 0 and scan.pass < 3 then
        scan.ids, scan.waiting, scan.i, scan.pass = scan.waiting, {}, 0, scan.pass + 1
        t = -3
      else
        self:SetScript("OnUpdate", nil)
        ScanFinish()
      end
    end
  end)
end

-- map pins: books you still need
table.insert(ns.PinSources, function()
  if ns.db.bookPins == false then return nil end
  local out = {}
  for _, b in ipairs(ns.Books) do
    if Wanted(b) and not bagged[b.name] then
      for _, s in ipairs(b.spots) do
        out[#out + 1] = { map = s[1], x = s[2], y = s[3], name = b.name, size = 15, border = { 0.55, 0.47, 0.87, 1 }, icon = BOOK_ICON,
          lines = { b.name, L["Library book"] .. (b.lvl and (", " .. L["level"] .. " " .. b.lvl .. "+") or ""), s[4] or "", b.special and (C.ORANGE .. b.special .. "|r") or nil } }
      end
    end
  end
  local lib = ns.Librarians[MyFaction()]
  out[#out + 1] = { map = lib.map, x = lib.x, y = lib.y, name = lib.name, size = 15, border = { 0.55, 0.47, 0.87, 1 },
    icon = "Interface\\Icons\\INV_Misc_Book_11", lines = { lib.name, L["Librarian: hand in your library books"] } }
  return out
end)

-- minimap: books you still need in this zone
table.insert(ns.MinimapSources, function(mapID)
  if ns.db.bookPins == false then return nil end
  local out = {}
  for _, b in ipairs(ns.Books) do
    if Wanted(b) and not bagged[b.name] then
      for _, s in ipairs(b.spots) do
        if s[1] == mapID then out[#out + 1] = { s[2], s[3], BOOK_ICON, b.name, 0.55, 0.47, 0.87 } end
      end
    end
  end
  return out
end)

---------------------------------------------------------------------------
-- Books page
---------------------------------------------------------------------------
do
  local list, j
  local opt = { show = "need" }
  local SHOW = { { "need", L["Still to get"] }, { "all", L["All books"] } }
  local function Build(panel)
    j = ns.TipJournal(panel, L["Library books"], L["Arrow to it"])
    local tb = ns.Toolbar(j.left)
    tb:Dropdown(150, SHOW, function() return opt.show end, function(v) opt.show = v end)
    tb:Check(L["Alert when one is near"], function() return ns.db.bookAlerts ~= false end, function(v) ns.db.bookAlerts = v end)
    tb:Button(L["Find handed-in books"], 150, function() ns.BooksScanCompleted(true) end,
      { L["Find handed-in books"], L["Goes through the quests you've completed and marks the library books you already handed in."] })
    tb:Check(L["Show on the map"], function() return ns.db.bookPins ~= false end,
      function(v) ns.db.bookPins = v; if ns.Pins_Refresh then ns.Pins_Refresh() end end)
    list = tb:List()
    j.list = list
  end
  local function Refresh()
    ScanBags()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local done, bags = ns.BooksCount()
    local total = 0
    for _, b in ipairs(ns.Books) do if not b.special and (not b.fac or b.fac == MyFaction()) then total = total + 1 end end
    local nextM
    for _, m in ipairs(ns.BookMilestones) do if done < m[1] then nextM = m break end end
    local lib = ns.Librarians[MyFaction()]
    add(0, ns.Icon("INV_Misc_Book_11"), string.format(L["%d of %d handed in"], done, total) .. (bags > 0 and (C.GREEN .. string.format(L["   %d in your bags"], bags) .. "|r") or ""),
      C.GREY .. (nextM and string.format(L["next reward at %d"], nextM[1]) or L["all rewards earned"]) .. "|r",
      function() ns.LibrarianArrow() end,
      { L["Library books"], string.format(L["Hand them in one at a time to %s (%s)."], lib.name, lib.where),
        L["Rewards at 10, 20 and 25 books."], L["Click for an arrow to the librarian."] }, { header = true })
    local pc, pe, pn = ns.PlayerWorld()
    local items = {}
    for _, b in ipairs(ns.Books) do
      local st = ns.BookStatus(b)
      if (opt.show == "all" or st ~= "done") and (not b.fac or b.fac == MyFaction()) then
        local bd, bs
        for _, s in ipairs(b.spots) do
          local c, e, n = ns.ToWorld(s[1], s[2], s[3])
          local d = ns.Distance(pc, pe, pn, c, e, n)
          if d and (not bd or d < bd) then bd, bs = d, s end
        end
        items[#items + 1] = { b = b, st = st, d = bd, s = bs or b.spots[1] }
      end
    end
    local rank = { bags = 1, out = 2, done = 3 }
    table.sort(items, function(x, y)
      if rank[x.st] ~= rank[y.st] then return rank[x.st] < rank[y.st] end
      if (x.d ~= nil) ~= (y.d ~= nil) then return x.d ~= nil end
      if x.d and y.d then return x.d < y.d end
      return (x.b.lvl or 0) < (y.b.lvl or 0)
    end)
    local level = UnitLevel("player")
    for _, it in ipairs(items) do
      local b, s = it.b, it.s
      local where = (ns.ZoneName and ns.ZoneName(s[1]) or "") .. (it.d and (", " .. ns.FormatDistance(it.d)) or "")
      local right
      if it.st == "done" then right = C.GREEN .. L["Handed in"] .. "|r"
      elseif it.st == "bags" then right = C.HUNTER .. L["In your bags"] .. "|r"
      else right = C.GREY .. where .. "|r" end
      local color = (it.st == "done" and C.GREY) or ((b.lvl or 1) > level + 3 and C.RED) or C.WHITE
      add(0, ns.Icon("INV_Misc_Book_09"), color .. b.name .. "|r" .. (b.special and (C.ORANGE .. "  *|r") or ""), right,
        function(_, button)
          if button == "RightButton" then
            Done()[b.name] = (not Done()[b.name]) and true or nil
            ns.UI_Refresh()
            if ns.Pins_Refresh then ns.Pins_Refresh() end
          elseif it.st == "bags" then ns.LibrarianArrow()
          else ns.Arrow_Set(s[1], s[2], s[3], b.name) end
        end,
        { b.name, where, s[4] or "", b.special and (C.ORANGE .. b.special .. "|r") or "",
          L["Level "] .. (b.lvl or 1) .. "+", C.GREY .. L["Click for an arrow. Right-click to mark it handed in (or not)."] .. "|r" },
        { mid = C.GREY .. (b.lvl or 1) .. "+|r" })
    end
    j:SetTipRows(rows)
  end
  ns.RegisterTab("books", L["Library books"], Build, Refresh)
end

do
  local ev = CreateFrame("Frame")
  local tick = 0
  for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" then
      ScanBags()
      C_Timer.After(8, function() ns.BooksScanCompleted(false) end)
      ev:SetScript("OnUpdate", function(_, e)
        tick = tick + e
        if tick < 3 then return end
        tick = 0
        CheckNearby()
      end)
    elseif event == "BAG_UPDATE_DELAYED" then
      local before = {}
      for k, v in pairs(bagged) do before[k] = v end
      ScanBags()
      for name in pairs(bagged) do
        if not before[name] then
          ns.Print(string.format(L["Library book picked up: %s. Hand it in to %s."], name, ns.Librarians[MyFaction()].name))
          if ns.RecordBook then ns.RecordBook(name, "found") end
          if ns.Pins_Refresh then ns.Pins_Refresh() end
        end
      end
    elseif event == "QUEST_TURNED_IN" then
      OnTurnedIn(a1)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      C_Timer.After(4, CapitalNote)
    end
  end)
end
