local _, ns = ...
local L = ns.L
local C = ns.C

-- Wishlist: Alt-click any item in Untamed to pin it. Its sources show on the world map, item
-- tooltips say it's on your wishlist, and you get a note when you're in a zone where you can get one.

local function List()
  ns.cdb.wishlist = ns.cdb.wishlist or {}
  return ns.cdb.wishlist
end

function ns.OnWishlist(id) return id and List()[id] ~= nil end

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
table.insert(ns.PinSources, function()
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
  if not next(List()) or not ns.SearchDBLoaded or not ns.SearchDB() then return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map or map == lastZone then return end
  lastZone = map
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
  local function Build(panel)
    ns.MakeCheck(panel, L["Show sources on the world map"], 4, -2, function() return ns.db.wishPins end,
      function(v) ns.db.wishPins = v; if ns.Pins_Refresh then ns.Pins_Refresh() end end)
    list = ns.NewList(panel, 30)
  end
  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local db = ns.SearchDB and ns.SearchDB()
    local ids = {}
    for id in pairs(List()) do ids[#ids + 1] = id end
    if #ids == 0 then
      add(0, nil, C.GREY .. L["Your wishlist is empty. Alt-click an item anywhere in Untamed (Search, Gear, Supplies, Dungeons) to add it."] .. "|r")
      list:Set(rows) return
    end
    table.sort(ids, function(a, b) return (List()[a] or 0) > (List()[b] or 0) end)
    add(0, nil, string.format(L["%d items"], #ids), C.GREY .. L["click: arrow   right-click: remove"] .. "|r", nil, nil, { header = true })
    local level = UnitLevel("player")
    for _, id in ipairs(ids) do
      local it = db and db.I[id]
      local have = (GetItemCount and GetItemCount(id) or 0) > 0
      add(0, ns.ItemIcon(id), ns.QualityColor(id) .. (it and it[1] or ("item " .. id)) .. "|r" .. (have and (C.GREEN .. "  " .. L["you have it"] .. "|r") or ""),
        it and ns.SourceSummary(id) or "",
        function(_, button) if button == "RightButton" then ns.Wishlist_Toggle(id) else ns.ItemClick(id)() end end,
        ns.ItemTooltip(id), { mid = it and it[3] > 0 and (((it[3] > level) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r") or "" })
    end
    list:Set(rows)
  end
  ns.RegisterTab("wishlist", L["Wishlist"], Build, Refresh)
end
