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
  if DB and ns.MergeRecorded then ns.MergeRecorded(DB) end
  ns.SearchSource = nil
  return DB
end

function ns.SearchDBLoaded() return DB end

local FOOD = { "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit", "Meat", "Fish" }  -- foodType 7 raw meat, 8 raw fish

local function MyFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return f == "Horde" and "H" or "A"
end

-- Race bit for quest race masks (0 = any race).
local RACE_BIT = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local ALLIANCE_RACES, HORDE_RACES = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128
local function QuestForMe(mask)
  if not mask or mask == 0 then return true end
  local _, race = UnitRace("player")
  local bit = RACE_BIT[race or ""]
  if not bit then return true end
  -- A mask covering one whole faction means "this faction"; otherwise it's race-specific.
  return math.floor(mask / bit) % 2 == 1
end
ns.QuestForMe = QuestForMe

-- Reputation: faction names (the game gives localized names; these are fallbacks) and which side each belongs to.
local FACTION_NAME = { [889] = "Warsong Outriders", [890] = "Silverwing Sentinels", [729] = "Frostwolf Clan", [730] = "Stormpike Guard",
  [509] = "The League of Arathor", [510] = "The Defilers", [529] = "Argent Dawn", [609] = "Cenarion Circle", [59] = "Thorium Brotherhood",
  [270] = "Zandalar Tribe", [576] = "Timbermaw Hold", [749] = "Hydraxian Waterlords", [910] = "Brood of Nozdormu", [87] = "Bloodsail Buccaneers",
  [21] = "Booty Bay", [369] = "Gadgetzan", [470] = "Ratchet", [577] = "Everlook", [349] = "Ravenholdt", [809] = "Shen'dralar",
  [72] = "Stormwind", [47] = "Ironforge", [69] = "Darnassus", [54] = "Gnomeregan Exiles", [76] = "Orgrimmar", [81] = "Thunder Bluff",
  [530] = "Darkspear Trolls", [68] = "Undercity", [92] = "Gelkis Clan Centaur", [93] = "Magram Clan Centaur" }
local FACTION_SIDE = { [889] = "H", [729] = "H", [510] = "H", [76] = "H", [81] = "H", [530] = "H", [68] = "H",
  [890] = "A", [730] = "A", [509] = "A", [72] = "A", [47] = "A", [69] = "A", [54] = "A" }
local RANK_NAME = { [0] = "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

-- name, standing (0 hated .. 7 exalted), barMin, barMax, barValue. Classic Era: GetFactionInfoByID;
-- Forever: C_Reputation.GetFactionDataByID.
function ns.FactionInfo(fac)
  if GetFactionInfoByID then
    local ok, name, _, standingID, barMin, barMax, barValue = pcall(GetFactionInfoByID, fac)
    if ok and type(name) == "string" and name ~= "" then return name, standingID and standingID - 1, barMin, barMax, barValue end
  end
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, fac)
    if ok and d and d.name and d.name ~= "" then
      return d.name, d.reaction and d.reaction - 1, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding
    end
  end
end

local function FactionName(fac)
  local name = ns.FactionInfo(fac)
  if type(name) ~= "string" or name == "" then name = FACTION_NAME[fac] or (L["faction "] .. fac) end
  return name
end
local function RankName(rank) return _G["FACTION_STANDING_LABEL" .. (rank + 1)] or RANK_NAME[rank] or tostring(rank) end
-- Your standing with a faction (0-7), or nil if unknown.
local function MyRank(fac)
  local _, standing = ns.FactionInfo(fac)
  if type(standing) == "number" then return standing end
end

-- Reputation needed for an item from a vendor: faction, rank (or nil). Picks your side's faction when there's a choice.
local function VendorRep(it, npcId)
  local side = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  for _, e in ipairs(it[22] or {}) do
    if e[1] == npcId then
      local pickF, pickR = e[2], e[3]
      for k = 2, #e - 1, 2 do
        if FACTION_SIDE[e[k]] == side then pickF, pickR = e[k], e[k + 1] end
      end
      return pickF, pickR
    end
  end
  if (it[20] or 0) > 0 then return it[20], it[21] end
end

-- "Needs Honored with Warsong Outriders (you: Friendly)", green when you already have it.
function ns.RepText(fac, rank, short)
  if not fac then return nil end
  local mine = MyRank(fac)
  local met = mine and mine >= rank
  local color = met and C.GREEN or C.ORANGE
  if short then return color .. RankName(rank) .. "|r" end
  return color .. string.format(L["Needs %s with %s"], RankName(rank), FactionName(fac))
    .. (mine and (C.GREY .. "  (" .. L["you: "] .. RankName(mine) .. ")") or "") .. "|r", met
end

local function ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  return GetItemIcon and GetItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ItemInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  return GetItemInfo(id)
end

local QUALITY_HEX = { [0] = "|cff9d9d9d", "|cffffffff", "|cff1eff00", "|cff0070dd", "|cffa335ee", "|cffff8000" }
local function QualityColor(id)
  local _, _, q = ItemInfo(id)
  if q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then return ITEM_QUALITY_COLORS[q].hex end
  local db = DB
  local it = db and db.I[id]
  if it and it[13] and QUALITY_HEX[it[13]] then return QUALITY_HEX[it[13]] end
  return C.WHITE
end

-- Distance from the player to a map point (nil when on another continent or unknown).
local function DistTo(map, x, y, pc, pe, pn)
  if not map or map == 0 or not x or x == 0 then return nil end
  local c, e, n = ns.ToWorld(map, x, y)
  if not c then return nil end
  return ns.Distance(pc, pe, pn, c, e, n)
end
ns.DistTo = DistTo

local function ContainerName(db, id)
  local it = db.I[id]
  return (it and it[1]) or (db.C and db.C[id]) or ("#" .. id)
end

-- Every source of an item, nearest first. Each: { kind, name, map, x, y, inst, dist, ... }
-- kinds: vendor, quest, drop, dungeon, chest, inside, crafted, fishing
function ns.ItemSources(id)
  local db = ns.SearchDB()
  local it = db and db.I[id]
  if not it then return {} end
  local pc, pe, pn = ns.PlayerWorld()
  local fac = MyFaction()
  local out = {}
  local function addNpc(kind, npcId)
    local n = db.N[npcId]
    if not n then return end
    if kind == "vendor" and n[8] ~= "" and not n[8]:find(fac, 1, true) then return end
    if kind == "drop" and n[10] ~= "" then kind = "dungeon" end
    local repF, repR
    if kind == "vendor" then repF, repR = VendorRep(it, npcId) end
    out[#out + 1] = { kind = kind, name = n[1], map = n[5], x = n[6], y = n[7], repF = repF, repR = repR,
      inst = n[10] ~= "" and n[10] or nil, dist = DistTo(n[5], n[6], n[7], pc, pe, pn), npcId = npcId }
  end
  for _, v in ipairs(it[6] or {}) do addNpc("vendor", v) end
  for _, d in ipairs(it[7] or {}) do addNpc("drop", d) end
  for _, o in ipairs(it[9] or {}) do
    local ob = db.O[o]
    if ob then
      out[#out + 1] = { kind = "chest", name = ob[1], map = ob[2], x = ob[3], y = ob[4], inst = ob[5] ~= "" and ob[5] or nil,
        spots = ob[6] or 0, dist = DistTo(ob[2], ob[3], ob[4], pc, pe, pn) }
    end
  end
  for _, q in ipairs(it[10] or {}) do
    local qq = db.Q[q]
    if qq and QuestForMe(qq[4]) then
      local n = db.N[qq[3]]
      out[#out + 1] = { kind = "quest", name = qq[1], giver = n and n[1], map = n and n[5], x = n and n[6], y = n and n[7],
        inst = n and n[10] ~= "" and n[10] or nil, dist = n and DistTo(n[5], n[6], n[7], pc, pe, pn), level = qq[2] }
    end
  end
  for _, c in ipairs(it[17] or {}) do out[#out + 1] = { kind = "inside", name = ContainerName(db, c), itemID = c } end
  if it[18] and it[18] ~= "" then out[#out + 1] = { kind = "crafted", name = it[18] } end
  for _, z in ipairs(it[19] or {}) do out[#out + 1] = { kind = "fishing", name = ns.ZoneName(z), map = z } end
  local rank = { vendor = 1, quest = 2, drop = 3, dungeon = 4, chest = 5, inside = 6, crafted = 7, fishing = 8 }
  table.sort(out, function(a, b)
    if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
    if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
    return rank[a.kind] < rank[b.kind]
  end)
  return out, it
end

-- Which ways an item can be had (fast, no distances): set of kinds plus "world" and "ah".
function ns.ItemWays(id)
  local db = ns.SearchDB()
  local it = db and db.I[id]
  local w = {}
  if not it then return w end
  local fac = MyFaction()
  local plainVendor = false
  for _, v in ipairs(it[6] or {}) do
    local n = db.N[v]
    if n and (n[8] == "" or n[8]:find(fac, 1, true)) then
      w.vendor = true
      -- Quartermasters and supply officers sell for reputation.
      local t = n[4] or ""
      if not (t:find("Quartermaster", 1, true) or t:find("Supply Officer", 1, true)) then plainVendor = true end
    end
  end
  if it[22] or (it[20] or 0) > 0 then w.rep = true
  elseif w.vendor and not plainVendor then w.repVendor = true; w.rep = true end
  for _, q in ipairs(it[10] or {}) do
    local qq = db.Q[q]
    if qq and QuestForMe(qq[4]) then w.quest = true break end
  end
  for _, d in ipairs(it[7] or {}) do
    local n = db.N[d]
    if n then if n[10] ~= "" then w.dungeon = true else w.drop = true end end
  end
  if it[8] > #(it[7] or {}) then w.world = true end
  if it[9] then w.chest = true end
  if it[17] then w.inside = true end
  if it[18] and it[18] ~= "" then w.crafted = true end
  if it[19] then w.fishing = true end
  if (it[20] or 0) > 0 then w.rep = true end
  -- Not bound on pickup and not junk: other players can sell it on the Auction House.
  if (it[15] == 0 or it[15] == 2) and (it[13] or 1) >= 2 and (it[4] == 2 or it[4] == 4) then w.ah = true end
  return w
end

local KIND = { vendor = L["Sold by"], drop = L["Drops from"], dungeon = L["Dungeon drop"], chest = L["Found in"],
  quest = L["Quest reward"], inside = L["Found inside"], crafted = L["Crafted"], fishing = L["Fishing"] }
local SHORT = { vendor = L["Vendor"], drop = L["Drop"], dungeon = L["Dungeon"], chest = L["Chest"], quest = L["Quest"],
  inside = L["Inside"], crafted = L["Crafted"], fishing = L["Fishing"] }
local KIND_COLOR = { vendor = C.GREEN, quest = C.BLUE, dungeon = C.ORANGE, drop = C.WHITE, chest = C.GOLD, inside = C.GOLD,
  crafted = C.HUNTER, fishing = C.BLUE }
ns.SourceShort, ns.SourceColor = SHORT, KIND_COLOR

local function Where(s)
  if s.inst then return C.ORANGE .. s.inst .. "|r" end
  if s.map and s.map ~= 0 then return ns.ZoneName(s.map) end
  return nil
end

local function SourceLine(s)
  local where = Where(s)
  local who = s.name
  if s.kind == "quest" then who = s.name .. (s.giver and (C.GREY .. ", " .. L["from "] .. s.giver .. "|r") or "") end
  if s.kind == "chest" and s.spots > 5 then who = who .. C.GREY .. " (" .. string.format(L["spawns in %d spots"], s.spots) .. ")|r" end
  if s.kind == "crafted" then who = s.name == "Crafted" and L["a profession"] or s.name end
  local extra = where and (where .. (s.dist and (", " .. ns.FormatDistance(s.dist)) or "")) or (s.kind == "chest" and L["random spawns"] or nil)
  local line = string.format("%s%s:|r %s%s", C.GOLD, KIND[s.kind], who, extra and (C.GREY .. "  (" .. extra .. ")|r") or "")
  if s.repF then line = line .. "  " .. ns.RepText(s.repF, s.repR, true) end
  return line
end

-- Short "how and where" for one row: nearest source.
function ns.SourceSummary(id)
  local srcs = ns.ItemSources(id)
  local s = srcs[1]
  if not s then
    local w = ns.ItemWays(id)
    if w.world then return C.GREY .. L["World drop"] .. "|r" end
    return C.GREY .. L["unknown"] .. "|r"
  end
  local where = Where(s)
  if s.kind == "inside" then where = s.name end
  if s.kind == "crafted" then where = s.name == "Crafted" and "" or s.name end
  return (KIND_COLOR[s.kind] or C.WHITE) .. SHORT[s.kind] .. "|r" .. (where and where ~= "" and (C.GREY .. ", " .. where .. "|r") or "")
    .. (s.dist and (C.GREY .. ", " .. ns.FormatDistance(s.dist) .. "|r") or "")
    .. (s.repF and ("  " .. ns.RepText(s.repF, s.repR, true)) or ""), s
end

local function GoTo(s)
  if s and s.kind == "inside" then ns.SearchFor(s.name) return end
  if not s or not s.map or s.map == 0 or not s.x or s.x == 0 then
    if s and s.map and s.map ~= 0 then ns.Print(string.format(L["%s: somewhere in %s (no exact spot known)."], s.name, ns.ZoneName(s.map)))
    else ns.Print(L["No map position for that source."]) end
    return
  end
  local label = (s.kind == "quest" and s.giver or s.name) .. (s.inst and (" (" .. L["inside "] .. s.inst .. ")") or "")
  ns.Arrow_Set(s.map, s.x, s.y, label)
end

local function ItemTooltip(id)
  return function()
    local srcs, it = ns.ItemSources(id)
    local lines = { (it and it[1]) or "?", itemID = id }
    if it and it[3] > 0 then lines[#lines + 1] = L["Requires level "] .. it[3] end
    local w = ns.ItemWays(id)
    if w.world then lines[#lines + 1] = C.GREY .. string.format(L["World drop: drops from %d different creatures."], it[8]) .. "|r" end
    if w.ah then lines[#lines + 1] = C.GREY .. L["Not bound when picked up, so you can often buy it on the Auction House."] .. "|r" end
    local shownRep = {}
    for _, s in ipairs(srcs) do
      if s.repF and not shownRep[s.repF .. ":" .. s.repR] then
        shownRep[s.repF .. ":" .. s.repR] = true
        lines[#lines + 1] = (ns.RepText(s.repF, s.repR))
      end
    end
    if w.repVendor and not next(shownRep) then
      lines[#lines + 1] = C.ORANGE .. L["Sold by a quartermaster: usually needs reputation."] .. "|r"
    end
    if it and it[16] and it[16] > 0 and w.vendor and ns.Money then lines[#lines + 1] = C.GREY .. L["Vendor price: "] .. "|r" .. ns.Money(it[16]) end
    for i = 1, math.min(8, #srcs) do lines[#lines + 1] = SourceLine(srcs[i]) end
    if #srcs > 8 then lines[#lines + 1] = C.GREY .. string.format(L["and %d more"], #srcs - 8) .. "|r" end
    if ns.OnWishlist and ns.OnWishlist(id) then lines[#lines + 1] = C.GOLD .. L["On your wishlist."] .. "|r" end
    lines[#lines + 1] = C.GREY .. L["Click: arrow to the nearest source.  Shift-click: link in chat.  Alt-click: wishlist."] .. "|r"
    return lines
  end
end

local function ItemClick(id)
  return function()
    if IsAltKeyDown and IsAltKeyDown() and ns.Wishlist_Toggle then ns.Wishlist_Toggle(id) return end
    if IsShiftKeyDown() then
      local _, link = ItemInfo(id)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
      return
    end
    local srcs = ns.ItemSources(id)
    -- Prefer a source we can point an arrow at.
    for _, s in ipairs(srcs) do if s.map and s.map ~= 0 and s.x and s.x ~= 0 then GoTo(s) return end end
    GoTo(srcs[1])
  end
end
ns.ItemClick, ns.ItemTooltip, ns.ItemIcon, ns.QualityColor = ItemClick, ItemTooltip, ItemIcon, QualityColor

local function NpcLine(n)
  local where = n[10] ~= "" and (C.ORANGE .. n[10] .. "|r") or (n[5] ~= 0 and ns.ZoneName(n[5]) or L["unknown location"])
  return where
end

-- Can the player use (wear or wield) this item?
local MELEE_OK = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [16] = true }
local RANGED_OK = { [2] = true, [3] = true, [18] = true }
function ns.CanUseItem(it, level)
  level = level or UnitLevel("player")
  if it[3] > level then return false end
  if it[4] == 4 then
    if it[5] == 3 and level < 40 then return false end
    return it[5] <= 3
  elseif it[4] == 2 then
    return MELEE_OK[it[5]] or RANGED_OK[it[5]] or false
  end
  return true
end

---------------------------------------------------------------------------
-- Search tab
---------------------------------------------------------------------------
do
  local list, box
  local f = { type = "all", kind = "any", source = "any", quality = 0, usable = false, near = false }
  local query = ""

  local TYPES = { { "all", L["Everything"] }, { "items", L["Items"] }, { "npcs", L["NPCs"] }, { "beasts", L["Tameable beasts"] }, { "vendors", L["Vendors"] } }
  local SLOT_INV = { head = { 1 }, neck = { 2 }, shoulder = { 3 }, back = { 16 }, chest = { 5, 20 }, wrist = { 9 }, hands = { 10 },
    waist = { 6 }, legs = { 7 }, feet = { 8 }, finger = { 11 }, trinket = { 12 } }
  local KINDS = {
    { "any", L["Any item"] }, { "armor", L["Armor (any slot)"] }, { "head", L["Head"] }, { "neck", L["Neck"] }, { "shoulder", L["Shoulders"] },
    { "back", L["Back"] }, { "chest", L["Chest"] }, { "wrist", L["Wrists"] }, { "hands", L["Hands"] }, { "waist", L["Waist"] },
    { "legs", L["Legs"] }, { "feet", L["Feet"] }, { "finger", L["Rings"] }, { "trinket", L["Trinkets"] },
    { "ranged", L["Bows, guns, crossbows"] }, { "melee", L["Melee weapons"] }, { "ammo", L["Ammo"] }, { "quiver", L["Quivers and pouches"] },
    { "food", L["Pet food"] }, { "bag", L["Bags"] }, { "consumable", L["Potions and food"] }, { "recipe", L["Recipes"] },
  }
  local SOURCES = { { "any", L["Any source"] }, { "vendor", L["Vendor"] }, { "quest", L["Quest"] }, { "drop", L["Open-world drop"] },
    { "dungeon", L["Dungeon"] }, { "chest", L["Chest or node"] }, { "world", L["World drop"] }, { "inside", L["Inside another item"] },
    { "crafted", L["Crafted"] }, { "fishing", L["Fishing"] }, { "rep", L["Reputation vendor"] }, { "ah", L["Auction House"] } }
  local QUALS = { { 0, L["Any quality"] }, { 2, L["Uncommon or better"] }, { 3, L["Rare or better"] }, { 4, L["Epic"] } }

  local function KindMatch(it)
    local k = f.kind
    if k == "any" then return true end
    local cls, sub, inv = it[4], it[5], it[14] or 0
    if k == "armor" then return cls == 4 end
    if SLOT_INV[k] then
      for _, v in ipairs(SLOT_INV[k]) do if inv == v then return true end end
      return false
    end
    if k == "ranged" then return cls == 2 and RANGED_OK[sub] or false end
    if k == "melee" then return cls == 2 and not RANGED_OK[sub] and sub ~= 19 and sub ~= 20 end
    if k == "ammo" then return cls == 6 end
    if k == "quiver" then return cls == 11 end
    if k == "food" then return (it[11] or 0) > 0 end
    if k == "bag" then return cls == 1 end
    if k == "consumable" then return cls == 0 end
    if k == "recipe" then return cls == 9 end
    return true
  end

  local function FiltersActive() return f.kind ~= "any" or f.source ~= "any" or f.quality > 0 or f.usable or f.type == "beasts" or f.type == "vendors" end

  local function Build(panel)
    local tb = ns.Toolbar(panel)
    box = tb:Search(L["Item, NPC or beast name"], 190, function(t) query = t end)
    tb:Dropdown(130, TYPES, function() return f.type end, function(v) f.type = v end)
    tb:Dropdown(160, KINDS, function() return f.kind end, function(v) f.kind = v end)
    tb:Row()
    tb:Dropdown(150, SOURCES, function() return f.source end, function(v) f.source = v end)
    tb:Dropdown(150, QUALS, function() return f.quality end, function(v) f.quality = v end)
    tb:Check(L["Usable by me"], function() return f.usable end, function(v) f.usable = v end,
      L["Only gear you can wear at your level (leather, mail from 40, and weapons hunters can use)."])
    tb:Check(L["Near me"], function() return f.near end, function(v) f.near = v end, L["Only things on your continent, nearest first."])
    tb:Button(L["Reset"], 60, function()
      f.type, f.kind, f.source, f.quality, f.usable, f.near = "all", "any", "any", 0, false, false
      box:SetText(""); query = ""
      ns.UI_Show("search")
    end)
    list = tb:List()
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if #query < 3 and not FiltersActive() then
      add(0, nil, L["Search everything"], "", nil, nil, { header = true })
      add(0, nil, C.GREY .. L["Type at least 3 letters: an item (Heavy Shot, Hawkeye's Tunic), an NPC (Hogor Thunderhoof) or a beast."] .. "|r")
      add(0, nil, C.GREY .. L["Or leave the box empty and just pick filters, like Bows + Vendor + Near me."] .. "|r")
      add(0, nil, C.GREY .. L["Click a result for an arrow to the nearest place to get it. Hover for every source."] .. "|r")
      list:Set(rows) return
    end
    local db = ns.SearchDB()
    if not db then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local CAP, level = 150, UnitLevel("player")
    local q = #query >= 3 and query or nil
    local pc, pe, pn = ns.PlayerWorld()
    local items, npcs, dist = {}, {}, {}

    local wantItems = f.type == "all" or f.type == "items"
    local wantNpcs = f.type ~= "items" and f.kind == "any" and f.source == "any" and f.quality == 0 and not f.usable
    if wantItems then
      for id, it in pairs(db.I) do
        if (not q or it[1]:lower():find(q, 1, true)) and KindMatch(it) and (it[13] or 1) >= f.quality
          and (not f.usable or ns.CanUseItem(it, level)) then
          if f.source == "any" or ns.ItemWays(id)[f.source] then items[#items + 1] = id end
        end
      end
      if f.near then
        if #items > 800 then
          table.sort(items, function(a, b) return db.I[a][2] > db.I[b][2] end)
          for i = #items, 801, -1 do items[i] = nil end
        end
        local kept = {}
        for _, id in ipairs(items) do
          local s = ns.ItemSources(id)[1]
          if s and s.dist then dist[id] = s.dist; kept[#kept + 1] = id end
        end
        items = kept
      end
      table.sort(items, function(a, b)
        if f.near and dist[a] ~= dist[b] then return dist[a] < dist[b] end
        local x, y = db.I[a], db.I[b]
        if q then
          local px, py = x[1]:lower():sub(1, #q) == q, y[1]:lower():sub(1, #q) == q
          if px ~= py then return px end
        end
        if x[2] ~= y[2] then return x[2] > y[2] end
        return x[1] < y[1]
      end)
    end
    if wantNpcs and (q or f.type == "beasts" or f.type == "vendors") then
      local vendors
      if f.type == "vendors" then
        vendors = {}
        for _, it in pairs(db.I) do for _, v in ipairs(it[6] or {}) do vendors[v] = true end end
      end
      for id, n in pairs(db.N) do
        if (not q or n[1]:lower():find(q, 1, true))
          and (f.type ~= "beasts" or ns.Beasts[id]) and (f.type ~= "vendors" or vendors[id]) then
          if f.near then
            local d = DistTo(n[5], n[6], n[7], pc, pe, pn)
            if d then dist[-id] = d; npcs[#npcs + 1] = id end
          else
            npcs[#npcs + 1] = id
          end
        end
      end
      table.sort(npcs, function(a, b)
        if f.near and dist[-a] ~= dist[-b] then return dist[-a] < dist[-b] end
        return db.N[a][1] < db.N[b][1]
      end)
    end

    if #items > 0 then
      add(0, nil, L["Items"], C.GREY .. #items .. (#items > CAP and (" " .. string.format(L["(showing %d)"], CAP)) or "") .. "|r", nil, nil, { header = true })
      for i = 1, math.min(CAP, #items) do
        local id = items[i]
        local it = db.I[id]
        local tooHigh = it[3] > level
        add(0, ItemIcon(id), QualityColor(id) .. it[1] .. "|r", ns.SourceSummary(id), ItemClick(id), ItemTooltip(id),
          { mid = it[3] > 0 and ((tooHigh and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r") or "" })
      end
    end
    if #npcs > 0 then
      add(0, nil, f.type == "beasts" and L["Tameable beasts"] or (f.type == "vendors" and L["Vendors"] or L["NPCs"]),
        C.GREY .. #npcs .. "|r", nil, nil, { header = true })
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
        local right = NpcLine(n) .. (dist[-id] and (C.GREY .. ", " .. ns.FormatDistance(dist[-id]) .. "|r") or "")
        add(0, ns.Icon(beast and (ns.FamilyIcons[beast[4]] or "Ability_Hunter_BeastTaming") or (n[4] ~= "" and "INV_Misc_Coin_01" or "Ability_Hunter_Pathfinding")),
          (beast and C.HUNTER or C.WHITE) .. n[1] .. "|r" .. title, right, click, tip,
          { mid = ((n[3] > level + 2) and C.RED or C.GREY) .. lvl .. "|r" })
      end
    end
    if #items == 0 and #npcs == 0 then add(0, nil, C.GREY .. L["Nothing found. Try fewer filters."] .. "|r") end
    list:Set(rows)
  end

  function ns.SearchFor(text)
    ns.UI_Show("search")
    query = (text or ""):lower()
    if box then box:SetText(text or "") end
    ns.UI_Refresh()
  end
  function ns.SearchFilters() return f end

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
      -- The quiver or pouch you have on: it sits in one of your bag slots.
      local worn, wornLevel = nil, 0
      local toInv = (C_Container and C_Container.ContainerIDToInventoryID) or ContainerIDToInventoryID
      for bag = 1, (NUM_BAG_SLOTS or 4) do
        local inv = toInv and toInv(bag)
        local bid = inv and GetInventoryItemID("player", inv)
        local bit = bid and db.I[bid]
        if bit and bit[4] == 11 and bit[2] > wornLevel then worn, wornLevel = bid, bit[2] end
      end
      if worn then
        add(14, ItemIcon(worn), QualityColor(worn) .. db.I[worn][1] .. "|r" .. C.GREEN .. "  " .. L["equipped"] .. "|r", "",
          ItemClick(worn), ItemTooltip(worn), { mid = C.GREY .. L["lvl "] .. db.I[worn][3] .. "|r" })
      end
      local bags = {}
      for id, it in pairs(db.I) do
        -- Skip ones with no known way to get them.
        if it[4] == 11 and it[5] == sub and it[3] <= playerLevel + 10 and it[2] > wornLevel and next(ns.ItemWays(id)) then bags[#bags + 1] = id end
      end
      table.sort(bags, function(a, b) return db.I[a][2] > db.I[b][2] end)
      local pc, pe, pn = ns.PlayerWorld()
      for i = 1, math.min(5, #bags) do
        local id = bags[i]
        local it = db.I[id]
        local v, d = NearestVendor(id, pc, pe, pn)
        local right
        if v then
          right = C.GREEN .. L["Buy"] .. "|r " .. (ns.Money and it[16] and it[16] > 0 and ns.Money(it[16]) or "") .. C.GREY .. ", " .. v[1] .. ", "
            .. (v[10] ~= "" and v[10] or ns.ZoneName(v[5])) .. (d and (", " .. ns.FormatDistance(d)) or "") .. "|r"
        else
          right = ns.SourceSummary(id)
        end
        add(14, ItemIcon(id), QualityColor(id) .. it[1] .. "|r", right,
          function() if v and not IsShiftKeyDown() then ns.Arrow_Set(v[5], v[6], v[7], v[1]) else ItemClick(id)() end end,
          ItemTooltip(id), { mid = ((it[3] > playerLevel) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r" })
      end
      if #bags == 0 then add(14, nil, C.GREY .. L["Nothing better than what you have for your level yet."] .. "|r") end
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
