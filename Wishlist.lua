local _, ns = ...
local L = ns.L
local C = ns.C

-- Wishlist: Alt-click any item in Untamed to pin it. Its sources show on the world map, item
-- tooltips say it's on your wishlist, and you get a note when you're in a zone where you can get one.
-- Beasts too: /ut want <beast name> (or Alt-click a beast in the beast list). Their spawn spots show
-- on the map, the rare finder calls them out, and chat says when you're in their zone or can tame them.

local function List()
  ns.cdb.wishlist = ns.cdb.wishlist or {}
  return ns.cdb.wishlist
end

function ns.OnWishlist(id) return id and List()[id] ~= nil end

local function Beasts()
  ns.cdb.wishBeasts = ns.cdb.wishBeasts or {}
  return ns.cdb.wishBeasts
end
function ns.BeastWished(npcId) return npcId and ns.cdb and ns.cdb.wishBeasts and ns.cdb.wishBeasts[npcId] ~= nil end

function ns.WishBeast_Toggle(npcId)
  local b = ns.Beasts[npcId]
  if not b then return end
  local w = Beasts()
  if w[npcId] then
    w[npcId] = nil
    ns.Print(string.format(L["Removed %s from your wishlist."], b[1]))
  else
    w[npcId] = time()
    ns.Print(string.format(L["Added %s (level %s) to your wishlist. Its spots are on your world map."], b[1], ns.LevelText(b)))
  end
  if ns.Pins_Refresh then ns.Pins_Refresh() end
  ns.UI_Refresh()
end

-- /ut want <name>: exact name first, then the only beast whose name contains it.
function ns.WishBeast_ByName(text)
  text = (text or ""):lower():match("^%s*(.-)%s*$")
  if text == "" then ns.Print(L["/ut want <beast name>, for example /ut want broken tooth"]) return end
  local hits = {}
  for id, b in pairs(ns.Beasts) do
    local n = b[1]:lower()
    if n == text then hits = { id } break end
    if n:find(text, 1, true) then hits[#hits + 1] = id end
  end
  if #hits == 1 then ns.WishBeast_Toggle(hits[1]) return end
  if #hits == 0 then ns.Print(string.format(L["No tameable beast called \"%s\"."], text)) return end
  table.sort(hits, function(a, b) return ns.Beasts[a][1] < ns.Beasts[b][1] end)
  local names = {}
  for i = 1, math.min(#hits, 6) do names[i] = ns.Beasts[hits[i]][1] end
  ns.Print(string.format(L["More than one beast matches: %s. Type more of the name."], table.concat(names, ", ")))
end

-- Chat note when you reach the level to tame a wished beast.
do
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
  ev:SetScript("OnEvent", function(_, _, level)
    level = tonumber(level)
    if not level or not ns.cdb or not ns.cdb.wishBeasts then return end
    for id in pairs(ns.cdb.wishBeasts) do
      local b = ns.Beasts[id]
      if b and b[2] == level then
        ns.Print(string.format(L["Wishlist: you can tame %s now (%s). /ut wishlist, then click it for an arrow."], b[1], ns.ZonesText(b)))
      end
    end
  end)
end

function ns.Wishlist_Toggle(id)
  local w = List()
  local db = ns.SearchDB and ns.SearchDB()
  local name = db and db.I[id] and db.I[id][1] or ("item " .. id)
  if w[id] then
    w[id] = nil
    ns.Print(string.format(L["Removed %s from your wishlist."], name))
  else
    w[id] = time()
    ns.Print(string.format(L["Added %s to your wishlist. Its sources are on your world map."], name))
  end
  if ns.Pins_Refresh then ns.Pins_Refresh() end
  ns.UI_Refresh()
end

-- Map pins for every wishlist source with a known spot.
ns.WishlistPins = function()
  if not ns.db.wishPins or not next(List()) then return nil end
  local out = {}
  for id in pairs(List()) do
    local db = ns.SearchDB()
    local it = db and db.I[id]
    if it then
      for _, s in ipairs(ns.ItemSources(id)) do
        if s.map and s.x and s.x ~= 0 then
          out[#out + 1] = { map = s.map, x = s.x, y = s.y, name = s.kind == "quest" and (s.giver or s.name) or s.name,
            icon = ns.ItemIcon(id), lines = { it[1], (ns.SourceShort[s.kind] or "") .. ": " .. s.name .. (s.inst and (" (" .. s.inst .. ")") or "") } }
        end
      end
    end
  end
  return out
end
table.insert(ns.PinSources, ns.WishlistPins)

-- Map pins for wished beasts' spawn spots.
table.insert(ns.PinSources, function()
  if not ns.db.wishPins or not ns.cdb or not ns.cdb.wishBeasts or not next(ns.cdb.wishBeasts) then return nil end
  local out = {}
  for id in pairs(ns.cdb.wishBeasts) do
    local b = ns.Beasts[id]
    if b then
      for map, pts in pairs(b[7]) do
        for i = 1, math.min(#pts, 60), 2 do
          out[#out + 1] = { map = map, x = pts[i], y = pts[i + 1], name = b[1], size = 16, border = { 1, 0.82, 0, 1 },
            icon = ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
            lines = { b[1], L["Wishlist"] .. ": " .. ns.FamilyLabel(b[4]) .. ", " .. L["level"] .. " " .. ns.LevelText(b) } }
        end
      end
    end
  end
  return out
end)

-- Tooltip line.
local function OnItemTooltip(tt, id)
  if id and ns.OnWishlist(id) then tt:AddLine("|cffabd473Untamed:|r " .. C.GOLD .. L["on your wishlist"] .. "|r") end
end
ns.On("LOGIN", function()
  if ns.db.wishPins == nil then ns.db.wishPins = true end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      if tt == GameTooltip or tt == ItemRefTooltip then OnItemTooltip(tt, data and data.id) end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", function(tt)
      local _, link = tt:GetItem()
      OnItemTooltip(tt, link and tonumber(link:match("item:(%d+)")))
    end)
  end
end)

-- Zone note: wishlist items you can get in the zone you just entered.
local lastZone
local function ZoneNote()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map or map == lastZone then return end
  lastZone = map
  for id in pairs(Beasts()) do
    local b = ns.Beasts[id]
    if b and b[7][map] then
      ns.Print(string.format(L["Wishlist: %s lives in this zone (level %s). /ut wishlist, then click it for an arrow."], b[1], ns.LevelText(b)))
    end
  end
  if not next(List()) or not ns.SearchDBLoaded or not ns.SearchDB() then return end
  local db = ns.SearchDB()
  for id in pairs(List()) do
    for _, s in ipairs(ns.ItemSources(id)) do
      if s.map == map then
        ns.Print(string.format(L["Wishlist: %s is available here (%s: %s)."], db.I[id][1], ns.SourceShort[s.kind] or "", s.name))
        break
      end
    end
  end
end
do
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "ZONE_CHANGED_NEW_AREA")
  ev:SetScript("OnEvent", function()
    if C_Timer and C_Timer.After then C_Timer.After(5, ZoneNote) else ZoneNote() end
  end)
end

-- Wishlist page
do
  local list
  local sort = "new"
  local SORTS = { { "new", L["Newest first"] }, { "near", L["Nearest source first"] }, { "level", L["By level"] } }
  local function Build(panel)
    local tb = ns.Toolbar(panel)
    tb:Dropdown(170, SORTS, function() return sort end, function(v) sort = v end)
    tb:Check(L["Show sources on the world map"], function() return ns.db.wishPins end,
      function(v) ns.db.wishPins = v; if ns.Pins_Refresh then ns.Pins_Refresh() end end)
    list = tb:List()
  end
  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local db = ns.SearchDB and ns.SearchDB()
    local level = UnitLevel("player")
    local beasts = {}
    for id in pairs(Beasts()) do if ns.Beasts[id] then beasts[#beasts + 1] = id end end
    if #beasts > 0 then
      table.sort(beasts, function(a, b) return ns.Beasts[a][2] < ns.Beasts[b][2] end)
      add(0, nil, ns.Count(#beasts, L["beast"], L["beasts"]), C.GREY .. L["click: arrow   right-click: remove"] .. "|r", nil, nil, { header = true })
      for _, id in ipairs(beasts) do
        local b = ns.Beasts[id]
        local right = ns.ZonesText(b)
        if b[9] then right = ((b[9] < 2.0) and C.GREEN or C.GREY) .. string.format("%.1f s", b[9]) .. "|r  " .. right end
        add(0, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
          (b[5] and C.ORANGE or C.WHITE) .. b[1] .. "|r" .. C.GREY .. "  " .. ns.FamilyLabel(b[4]) .. "|r", right,
          function(_, button) if button == "RightButton" then ns.WishBeast_Toggle(id) else ns.Navigate(id) end end,
          ns.BeastTooltip(id), { mid = ((b[2] > level) and C.RED or C.GREY) .. L["lvl "] .. ns.LevelText(b) .. "|r" })
      end
    end
    local ids = {}
    for id in pairs(List()) do ids[#ids + 1] = id end
    if #ids == 0 and #beasts > 0 then list:Set(rows) return end
    if #ids == 0 then
      add(0, nil, C.GREY .. L["Your wishlist is empty. Alt-click an item anywhere in Untamed (Search, Gear, Supplies, Dungeons) to add it, or type /ut want and a beast's name."] .. "|r")
      list:Set(rows) return
    end
    local dist = {}
    if sort == "near" then for _, id in ipairs(ids) do local s = ns.ItemSources(id)[1]; dist[id] = s and s.dist or 1e9 end end
    table.sort(ids, function(a, b)
      if sort == "near" and dist[a] ~= dist[b] then return dist[a] < dist[b] end
      if sort == "level" then
        local x, y = db and db.I[a], db and db.I[b]
        if x and y and x[3] ~= y[3] then return x[3] < y[3] end
      end
      return (List()[a] or 0) > (List()[b] or 0)
    end)
    add(0, nil, ns.Count(#ids, L["item"], L["items"]), C.GREY .. L["click: arrow   right-click: remove"] .. "|r", nil, nil, { header = true })
    for _, id in ipairs(ids) do
      local it = db and db.I[id]
      local have = ns.HaveItem and ns.HaveItem(id)
      if have == nil then have = (GetItemCount and GetItemCount(id) or 0) > 0 end
      add(0, ns.ItemIcon(id), ns.QualityColor(id) .. (it and it[1] or ("item " .. id)) .. "|r" .. (have and (C.GREEN .. "  " .. L["you have it"] .. "|r") or ""),
        it and ns.SourceSummary(id) or "",
        function(_, button) if button == "RightButton" then ns.Wishlist_Toggle(id) else ns.ItemClick(id)() end end,
        ns.ItemTooltip(id), { mid = it and it[3] > 0 and (((it[3] > level) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r") or "" })
    end
    list:Set(rows)
  end
  ns.RegisterTab("wishlist", L["Wishlist"], Build, Refresh)
end
