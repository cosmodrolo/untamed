local _, ns = ...
local L = ns.L
local C = ns.C

-- Search anything (items, NPCs, beasts) and the Supplies page (ammo, quivers, pet food).
-- The index is a Lua source string from Data\Search_*.lua, loaded the first time it's needed.

local DB
function ns.SearchDB()
  if DB then return DB end
  if not ns.SearchSource then return nil end
  local fn = (loadstring or load)(ns.SearchSource)
  DB = fn and fn() or nil
  ns.SearchSource = nil
  return DB
end

local FOOD = { "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit", "Meat", "Fish" }  -- foodType 7 raw meat, 8 raw fish

local function MyFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == "Horde" and "H" or "A"
end

local function ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  return GetItemIcon and GetItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ItemInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  return GetItemInfo(id)
end

local function QualityColor(id)
  local _, _, q = ItemInfo(id)
  if q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then return ITEM_QUALITY_COLORS[q].hex end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return C.WHITE
end

-- Distance from the player to a map point (nil when on another continent or unknown).
local function DistTo(map, x, y, pc, pe, pn)
  if not map or map == 0 then return nil end
  local c, e, n = ns.ToWorld(map, x, y)
  if not c then return nil end
  return ns.Distance(pc, pe, pn, c, e, n)
end

-- Every source of an item, nearest first. Each: { kind, label, npcName, map, x, y, inst, dist }
function ns.ItemSources(id)
  local db = ns.SearchDB()
  local it = db and db.I[id]
  if not it then return {} end
  local pc, pe, pn = ns.PlayerWorld()
  local fac = MyFaction()
  local out = {}
  local function addNpc(kind, npcId, extra)
    local n = db.N[npcId]
    if not n then return end
    if kind == "vendor" and n[8] ~= "" and not n[8]:find(fac, 1, true) then return end
    out[#out + 1] = { kind = kind, name = n[1] .. (extra or ""), map = n[5], x = n[6], y = n[7],
      inst = n[10] ~= "" and n[10] or nil, dist = DistTo(n[5], n[6], n[7], pc, pe, pn), npcId = npcId }
  end
  for _, v in ipairs(it[6] or {}) do addNpc("vendor", v) end
  for _, d in ipairs(it[7] or {}) do addNpc("drop", d) end
  for _, o in ipairs(it[9] or {}) do
    local ob = db.O[o]
    if ob then out[#out + 1] = { kind = "object", name = ob[1], map = ob[2], x = ob[3], y = ob[4], inst = ob[5] ~= "" and ob[5] or nil,
      dist = DistTo(ob[2], ob[3], ob[4], pc, pe, pn) } end
  end
  for _, q in ipairs(it[10] or {}) do
    local qq = db.Q[q]
    if qq then
      local n = db.N[qq[3]]
      out[#out + 1] = { kind = "quest", name = qq[1], giver = n and n[1], map = n and n[5], x = n and n[6], y = n and n[7],
        inst = n and n[10] ~= "" and n[10] or nil, dist = n and DistTo(n[5], n[6], n[7], pc, pe, pn), level = qq[2] }
    end
  end
  local rank = { vendor = 1, quest = 2, drop = 3, object = 4 }
  table.sort(out, function(a, b)
    if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
    if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
    return rank[a.kind] < rank[b.kind]
  end)
  return out, it
end

local KIND = { vendor = L["Sold by"], drop = L["Drops from"], object = L["Found in"], quest = L["Quest reward"] }

local function SourceLine(s)
  local where = s.inst and (C.ORANGE .. s.inst .. "|r") or (s.map and s.map ~= 0 and ns.ZoneName(s.map)) or L["unknown location"]
  local who = s.kind == "quest" and (s.name .. (s.giver and (C.GREY .. ", " .. L["from "] .. s.giver .. "|r") or "")) or s.name
  return string.format("%s%s:|r %s  %s(%s%s)|r", C.GOLD, KIND[s.kind], who, C.GREY, where, s.dist and (", " .. ns.FormatDistance(s.dist)) or "")
end

local function GoTo(s)
  if not s or not s.map or s.map == 0 then ns.Print(L["No map position for that source."]) return end
  local label = (s.kind == "quest" and s.giver or s.name) .. (s.inst and (" (" .. L["inside "] .. s.inst .. ")") or "")
  ns.Arrow_Set(s.map, s.x, s.y, label)
end

local function ItemTooltip(id)
  return function(owner)
    local srcs, it = ns.ItemSources(id)
    local lines = { (it and it[1]) or "?", itemID = id }
    if it and it[3] > 0 then lines[#lines + 1] = L["Requires level "] .. it[3] end
    if it and it[8] > #(it[7] or {}) then lines[#lines + 1] = C.GREY .. string.format(L["World drop: drops from %d different creatures."], it[8]) .. "|r" end
    for i = 1, math.min(8, #srcs) do lines[#lines + 1] = SourceLine(srcs[i]) end
    if #srcs > 8 then lines[#lines + 1] = C.GREY .. string.format(L["and %d more"], #srcs - 8) .. "|r" end
    lines[#lines + 1] = C.GREY .. L["Click: arrow to the nearest source.  Shift-click: link in chat."] .. "|r"
    return lines
  end
end

local function ItemClick(id)
  return function()
    if IsShiftKeyDown() then
      local _, link = ItemInfo(id)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
      return
    end
    local srcs = ns.ItemSources(id)
    GoTo(srcs[1])
  end
end
ns.ItemClick, ns.ItemTooltip, ns.ItemIcon, ns.QualityColor = ItemClick, ItemTooltip, ItemIcon, QualityColor

local function NpcLine(n)
  local where = n[10] ~= "" and (C.ORANGE .. n[10] .. "|r") or (n[5] ~= 0 and ns.ZoneName(n[5]) or L["unknown location"])
  return where
end

---------------------------------------------------------------------------
-- Search tab
---------------------------------------------------------------------------
do
  local list, box, kindBtn
  local KINDS = { "all", "items", "npcs" }
  local KIND_LABEL = { all = L["Everything"], items = L["Items"], npcs = L["NPCs"] }
  local kind, query = "all", ""

  local function Build(panel)
    box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(240, 20)
    box:SetPoint("TOPLEFT", 10, -3)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) query = (self:GetText() or ""):lower(); ns.UI_Refresh() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 4, 0)
    hint:SetText(L["Item, NPC or beast name"])
    box:HookScript("OnEditFocusGained", function() hint:Hide() end)
    box:HookScript("OnEditFocusLost", function(self) hint:SetShown((self:GetText() or "") == "") end)
    local idx = 1
    kindBtn = ns.MakeButton(panel, KIND_LABEL.all, 110, function()
      idx = idx % #KINDS + 1; kind = KINDS[idx]; kindBtn:SetText(KIND_LABEL[kind]); ns.UI_Refresh()
    end)
    kindBtn:SetPoint("LEFT", box, "RIGHT", 8, 0)
    list = ns.NewList(panel, 30)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if #query < 3 then
      add(0, nil, L["Search everything"], "", nil, nil, { header = true })
      add(0, nil, C.GREY .. L["Type at least 3 letters: an item (Heavy Shot, Hawkeye's Tunic), an NPC (Hogor Thunderhoof) or a beast."] .. "|r")
      add(0, nil, C.GREY .. L["Click a result for an arrow to the nearest place to get it. Hover for every source."] .. "|r")
      list:Set(rows) return
    end
    local db = ns.SearchDB()
    if not db then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local CAP = 120
    local items, npcs = {}, {}
    if kind ~= "npcs" then
      for id, it in pairs(db.I) do
        if it[1]:lower():find(query, 1, true) then items[#items + 1] = id end
      end
      table.sort(items, function(a, b)
        local x, y = db.I[a], db.I[b]
        local px, py = x[1]:lower():sub(1, #query) == query, y[1]:lower():sub(1, #query) == query
        if px ~= py then return px end
        if x[2] ~= y[2] then return x[2] > y[2] end
        return x[1] < y[1]
      end)
    end
    if kind ~= "items" then
      for id, n in pairs(db.N) do
        if n[1]:lower():find(query, 1, true) then npcs[#npcs + 1] = id end
      end
      table.sort(npcs, function(a, b) return db.N[a][1] < db.N[b][1] end)
    end
    if #items > 0 then
      add(0, nil, L["Items"], C.GREY .. #items .. "|r", nil, nil, { header = true })
      for i = 1, math.min(CAP, #items) do
        local id = items[i]
        local it = db.I[id]
        local srcs = {}
        local right
        if it[6] then right = C.GREEN .. L["vendor"] .. "|r"
        elseif it[10] then right = C.BLUE .. L["quest"] .. "|r"
        elseif it[8] > 0 then right = it[8] > #(it[7] or {}) and (C.GREY .. L["world drop"] .. "|r") or (C.WHITE .. L["drop"] .. "|r")
        else right = C.GREY .. L["container"] .. "|r" end
        add(0, ItemIcon(id), QualityColor(id) .. it[1] .. "|r", right, ItemClick(id), ItemTooltip(id),
          { mid = it[3] > 0 and (C.GREY .. L["lvl "] .. it[3] .. "|r") or "" })
      end
    end
    if #npcs > 0 then
      add(0, nil, L["NPCs"], C.GREY .. #npcs .. "|r", nil, nil, { header = true })
      local playerLevel = UnitLevel("player")
      for i = 1, math.min(CAP, #npcs) do
        local id = npcs[i]
        local n = db.N[id]
        local beast = ns.Beasts[id]
        local lvl = n[2] == n[3] and tostring(n[2]) or (n[2] .. "-" .. n[3])
        local title = n[4] ~= "" and (C.GREY .. " <" .. n[4] .. ">|r") or ""
        local click = beast and ns.BeastClick(id) or function()
          if n[5] == 0 then ns.Print(L["No map position for that NPC."]) return end
          ns.Arrow_Set(n[5], n[6], n[7], n[1] .. (n[10] ~= "" and (" (" .. L["inside "] .. n[10] .. ")") or ""))
        end
        local tip = beast and ns.BeastTooltip(id) or { n[1] .. (n[4] ~= "" and (" <" .. n[4] .. ">") or ""), L["Level "] .. lvl,
          NpcLine(n) .. (n[5] ~= 0 and string.format("  %.0f, %.0f", n[6], n[7]) or ""), C.GREY .. L["Click for an arrow."] .. "|r" }
        add(0, ns.Icon(beast and (ns.FamilyIcons[beast[4]] or "Ability_Hunter_BeastTaming") or (n[4] ~= "" and "INV_Misc_Coin_01" or "Ability_Hunter_Pathfinding")),
          (beast and C.HUNTER or C.WHITE) .. n[1] .. "|r" .. title, NpcLine(n), click, tip,
          { mid = ((n[3] > playerLevel + 2) and C.RED or C.GREY) .. lvl .. "|r" })
      end
    end
    if #items == 0 and #npcs == 0 then add(0, nil, C.GREY .. L["Nothing found."] .. "|r") end
    list:Set(rows)
  end

  function ns.SearchFor(text)
    ns.UI_Show("search")
    query = (text or ""):lower()
    if box then box:SetText(text or "") end
    ns.UI_Refresh()
  end

  ns.RegisterTab("search", L["Search"], Build, Refresh)
end

---------------------------------------------------------------------------
-- Supplies: ammo, quivers and pouches, pet food you can buy
---------------------------------------------------------------------------
local function RangedKind()
  local slot = INVSLOT_RANGED or 18
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  if not id then return nil end
  local _, _, _, _, _, classID, subID
  if C_Item and C_Item.GetItemInfoInstant then _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  elseif GetItemInfoInstant then _, _, _, _, _, classID, subID = GetItemInfoInstant(id) end
  if classID ~= 2 then return nil end
  if subID == 3 then return "bullets" end
  if subID == 2 or subID == 18 then return "arrows" end
  return nil
end

-- Nearest friendly vendor for an item.
local function NearestVendor(id, pc, pe, pn)
  local db = ns.SearchDB()
  local it = db.I[id]
  local fac = MyFaction()
  local best, bestD
  for _, v in ipairs(it[6] or {}) do
    local n = db.N[v]
    if n and n[5] ~= 0 and (n[8] == "" or n[8]:find(fac, 1, true)) then
      local d = DistTo(n[5], n[6], n[7], pc, pe, pn)
      if not best or (d and (not bestD or d < bestD)) then best, bestD = n, d end
    end
  end
  return best, bestD
end

local function VendorRow(add, id, extra, playerLevel)
  local db = ns.SearchDB()
  local it = db.I[id]
  local pc, pe, pn = ns.PlayerWorld()
  local v, d = NearestVendor(id, pc, pe, pn)
  local right
  if v then right = C.WHITE .. v[1] .. "|r" .. C.GREY .. ", " .. (v[10] ~= "" and v[10] or ns.ZoneName(v[5])) .. (d and (", " .. ns.FormatDistance(d)) or "") .. "|r"
  else right = C.GREY .. L["not sold to your faction; hover for sources"] .. "|r" end
  add(14, ItemIcon(id), QualityColor(id) .. it[1] .. "|r" .. (extra or ""), right,
    function()
      if IsShiftKeyDown() then ItemClick(id)() return end
      if v then ns.Arrow_Set(v[5], v[6], v[7], v[1]) else ItemClick(id)() end
    end, ItemTooltip(id),
    { mid = ((it[3] > playerLevel) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r" })
end

do
  local list
  local function Build(panel) list = ns.NewList(panel, 0) end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local db = ns.SearchDB()
    if not db then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local playerLevel = UnitLevel("player")

    -- Ammo
    local kind = RangedKind()
    local slot = INVSLOT_AMMO or 0
    local ammoID = GetInventoryItemID and GetInventoryItemID("player", slot)
    local count = ammoID and GetInventoryItemCount("player", slot) or 0
    add(0, ns.Icon("INV_Ammo_Arrow_02"), L["Ammo"], ammoID and (C.WHITE .. count .. "|r " .. C.GREY .. L["in your bags"] .. "|r") or (C.GREY .. L["no ammo equipped"] .. "|r"),
      nil, nil, { header = true })
    if not kind then
      add(14, nil, C.GREY .. L["Equip a bow, crossbow or gun to see ammo for it."] .. "|r")
    else
      local sub = kind == "arrows" and 2 or 3
      local ammo = {}
      for id, it in pairs(db.I) do
        if it[4] == 6 and it[5] == sub and it[6] and it[3] <= playerLevel + 5 then ammo[#ammo + 1] = id end
      end
      table.sort(ammo, function(a, b) return db.I[a][2] > db.I[b][2] end)
      local shown = 0
      for _, id in ipairs(ammo) do
        if shown >= 4 then break end
        local it = db.I[id]
        local tag = (id == ammoID) and (C.GREEN .. "  " .. L["equipped"] .. "|r") or ((it[3] > playerLevel) and (C.GREY .. "  " .. L["soon"] .. "|r") or "")
        VendorRow(add, id, tag, playerLevel)
        shown = shown + 1
      end
    end

    -- Quivers and pouches
    if kind then
      local sub = kind == "arrows" and 2 or 3
      add(0, ns.Icon(kind == "arrows" and "INV_Misc_Quiver_07" or "INV_Misc_Ammo_Bullet_01"),
        kind == "arrows" and L["Quivers"] or L["Ammo pouches"], C.GREY .. L["faster attacks and more ammo space"] .. "|r", nil, nil, { header = true })
      local bags = {}
      for id, it in pairs(db.I) do
        if it[4] == 11 and it[5] == sub and it[3] <= playerLevel + 10 then bags[#bags + 1] = id end
      end
      table.sort(bags, function(a, b) return db.I[a][2] > db.I[b][2] end)
      for i = 1, math.min(5, #bags) do
        local id = bags[i]
        local it = db.I[id]
        local srcs = ns.ItemSources(id)
        local s = srcs[1]
        add(14, ItemIcon(id), QualityColor(id) .. it[1] .. "|r", s and (C.GREY .. KIND[s.kind] .. " " .. (s.kind == "quest" and s.name or s.name) .. "|r") or (C.GREY .. L["crafted or unknown"] .. "|r"),
          ItemClick(id), ItemTooltip(id), { mid = ((it[3] > playerLevel) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r" })
      end
    end

    -- Pet food
    local petLevel = UnitExists("pet") and UnitLevel("pet") or nil
    local diet = petLevel and ns.PetDiet and ns.PetDiet() or {}
    add(0, ns.Icon("INV_Misc_Food_14"), L["Food for your pet"], petLevel and (C.GREY .. table.concat(diet, ", ") .. "|r") or "", nil,
      { L["Pet food"], L["Pets enjoy food that is no more than about 20 levels below them. Much lower food gives little or no happiness."] }, { header = true })
    if not petLevel then
      add(14, nil, C.GREY .. L["Summon your pet to see food you can buy for it."] .. "|r")
    elseif #diet == 0 then
      add(14, nil, C.GREY .. L["Diet unknown."] .. "|r")
    else
      local eats = {}
      for _, d in ipairs(diet) do eats[d] = true end
      local foods = {}
      for id, it in pairs(db.I) do
        if it[11] > 0 and it[6] and eats[FOOD[it[11]] or ""] and it[2] >= petLevel - 20 and it[3] <= playerLevel then foods[#foods + 1] = id end
      end
      if #foods == 0 then
        for id, it in pairs(db.I) do
          if it[11] > 0 and it[6] and eats[FOOD[it[11]] or ""] and it[3] <= playerLevel then foods[#foods + 1] = id end
        end
      end
      local pc, pe, pn = ns.PlayerWorld()
      local dist = {}
      for _, id in ipairs(foods) do local _, d = NearestVendor(id, pc, pe, pn); dist[id] = d or 1e9 end
      table.sort(foods, function(a, b)
        if dist[a] ~= dist[b] then return dist[a] < dist[b] end
        return db.I[a][2] > db.I[b][2]
      end)
      for i = 1, math.min(5, #foods) do VendorRow(add, foods[i], nil, playerLevel) end
      if #foods == 0 then add(14, nil, C.GREY .. L["No vendor food found for this diet."] .. "|r") end
    end
    list:Set(rows)
  end

  ns.RegisterTab("supplies", L["Supplies"], Build, Refresh)
end
