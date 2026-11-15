local _, ns = ...
local L = ns.L
local C = ns.C

-- Recorder: notes what the game tells us as you play, so the data fixes itself.
--   Vendors: who sells what, where, and for how much (when you open a vendor).
--   Loot: what dropped from which creature or chest, and where (when you loot; every spot a
--     chest was opened at).
--   Beasts and rares you see (nameplates, target, mouseover): level, family and where.
--   What the game marks on your minimap (vignettes), library books (where you found each one,
--     its item and quest IDs). Each list is capped so the saved file stays small.
-- Your copy uses this right away; it's also saved for sharing (Settings > Share data).

local function Store()
  ns.db.recorded = ns.db.recorded or {}
  local r = ns.db.recorded[ns.FLAVOR]
  if not r then r = { vendors = {}, drops = {}, objects = {} }; ns.db.recorded[ns.FLAVOR] = r end
  r.vendors = r.vendors or {}; r.drops = r.drops or {}; r.objects = r.objects or {}
  r.beasts = r.beasts or {}; r.rares = r.rares or {}; r.marks = r.marks or {}; r.books = r.books or {}
  return r
end

-- "Creature-0-4372-1-11-3410-00004A1F2B" -> "Creature", 3410
local function ParseGUID(guid)
  if not guid or ns.IsSecret(guid) then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  return kind, tonumber(id)
end

local function Here()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return map end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  if not x or ns.IsSecret(x) then return map end
  return map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

local function ItemIDFromLink(link)
  return link and tonumber(link:match("item:(%d+)"))
end

local function MyFactionLetter()
  return (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
end

---------------------------------------------------------------------------
-- Merge recordings into the search index (called when the index loads, and live)
---------------------------------------------------------------------------
local function EnsureItem(db, id)
  local it = db.I[id]
  if it then return it end
  local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or (GetItemInfo and GetItemInfo(id)) or ("item " .. id)
  local _, _, _, _, _, classID, subID
  if C_Item and C_Item.GetItemInfoInstant then _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  elseif GetItemInfoInstant then _, _, _, _, _, classID, subID = GetItemInfoInstant(id) end
  it = { name, 0, 0, classID or 15, subID or 0, nil, nil, 0, nil, nil, 0, 0, 1, 0, 0, 0, nil, "", nil, 0, 0 }
  db.I[id] = it
  return it
end

local function AddUnique(list, v)
  for _, x in ipairs(list) do if x == v then return list end end
  list[#list + 1] = v
  return list
end

local function MergeVendor(db, npcId, v)
  local n = db.N[npcId]
  if not n then
    db.N[npcId] = { v.name or ("NPC " .. npcId), 0, 0, "", v.map or 0, v.x or 0, v.y or 0, v.fac or "", 0, "" }
  elseif (n[5] == 0 or n[6] == 0) and v.map and v.x then
    n[5], n[6], n[7] = v.map, v.x, v.y
  end
  for itemId, price in pairs(v.items or {}) do
    local it = EnsureItem(db, itemId)
    it[6] = AddUnique(it[6] or {}, npcId)
    if price and price > 0 and (it[16] or 0) == 0 then it[16] = price end
  end
end

local function MergeDrop(db, key, rec)
  local kind, id = key:match("^(%a)(%d+)$")
  id = tonumber(id)
  if not id then return end
  if kind == "c" then
    if not db.N[id] then db.N[id] = { rec.name or ("NPC " .. id), 0, 0, "", rec.map or 0, rec.x or 0, rec.y or 0, "", 0, "" } end
    for itemId in pairs(rec.items or {}) do
      local it = EnsureItem(db, itemId)
      local before = #(it[7] or {})
      it[7] = AddUnique(it[7] or {}, id)
      if #it[7] > before then it[8] = math.max(it[8] or 0, #it[7]) end
    end
  elseif kind == "o" then
    if not db.O[id] then db.O[id] = { rec.name or L["Container"], rec.map or 0, rec.x or 0, rec.y or 0, "", 1 } end
    for itemId in pairs(rec.items or {}) do
      local it = EnsureItem(db, itemId)
      it[9] = AddUnique(it[9] or {}, id)
    end
  end
end

function ns.MergeRecorded(db)
  local r = ns.db and ns.db.recorded and ns.db.recorded[ns.FLAVOR]
  if not r then return end
  for npcId, v in pairs(r.vendors or {}) do MergeVendor(db, npcId, v) end
  for key, rec in pairs(r.drops or {}) do MergeDrop(db, key, rec) end
end

local function LiveDB() return ns.SearchDBLoaded and ns.SearchDBLoaded() end

---------------------------------------------------------------------------
-- Vendors
---------------------------------------------------------------------------
local function RecordVendor()
  if not ns.db.recordData then return end
  local kind, npcId = ParseGUID(UnitGUID("npc"))
  if kind ~= "Creature" or not npcId then return end
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  if n == 0 then return end
  local map, x, y = Here()
  local v = { name = UnitName("npc"), map = map, x = x, y = y, fac = MyFactionLetter(), items = {}, seen = time() }
  for i = 1, n do
    local id = GetMerchantItemID and GetMerchantItemID(i) or ItemIDFromLink(GetMerchantItemLink and GetMerchantItemLink(i))
    if id then
      local price
      if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        price = info and info.price
      elseif GetMerchantItemInfo then
        local _, _, p = GetMerchantItemInfo(i)
        price = p
      end
      v.items[id] = price or 0
    end
  end
  Store().vendors[npcId] = v
  local db = LiveDB()
  if db then MergeVendor(db, npcId, v) end
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------
local function RecordLoot()
  if not ns.db.recordData or not GetNumLootItems or not GetLootSourceInfo then return end
  local map, x, y = Here()
  local drops = Store().drops
  local db = LiveDB()
  for slot = 1, GetNumLootItems() do
    local id = ItemIDFromLink(GetLootSlotLink and GetLootSlotLink(slot))
    if id then
      local src = { GetLootSourceInfo(slot) }
      for k = 1, #src, 2 do
        local kind, sid = ParseGUID(src[k])
        local key = (kind == "Creature" and "c" or (kind == "GameObject" and "o")) and ((kind == "Creature" and "c" or "o") .. sid)
        if key then
          local rec = drops[key]
          if not rec then
            local name
            if kind == "Creature" and UnitExists("target") then
              -- Forever can hide the target's GUID and name in combat (secret values): don't compare those.
              local tg = UnitGUID("target")
              if not ns.IsSecret(tg) and tg == src[k] then
                local n = UnitName("target")
                if not ns.IsSecret(n) then name = n end
              end
            end
            rec = { name = name, map = map, x = x, y = y, items = {} }
            drops[key] = rec
          end
          rec.items[id] = (rec.items[id] or 0) + 1
          if kind == "GameObject" and map and x then
            rec.spots = rec.spots or {}
            ns.RecordSpot(rec.spots, map, x, y, 60)
          end
          if db then MergeDrop(db, key, rec) end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Spots: { map, x, y, map, x, y, ... }, one per ~1.5% of a map, capped
---------------------------------------------------------------------------
function ns.RecordSpot(list, map, x, y, cap)
  if not (map and x and y) then return end
  for i = 1, #list, 3 do
    if list[i] == map and math.abs(list[i + 1] - x) < 1.5 and math.abs(list[i + 2] - y) < 1.5 then return end
  end
  if #list >= (cap or 30) * 3 then return end
  list[#list + 1] = map; list[#list + 1] = x; list[#list + 1] = y
end

---------------------------------------------------------------------------
-- Beasts and rares you see
---------------------------------------------------------------------------
local lastSeen = {}   -- [npcId] = time, to keep nameplate spam down
local function RecordUnit(unit, exact)
  if not ns.db.recordData or not unit or not UnitExists(unit) then return end
  local okp, isPlayer = pcall(UnitIsPlayer, unit)
  if not okp or ns.IsSecret(isPlayer) or isPlayer then return end
  local guid = UnitGUID(unit)
  local kind, npcId = ParseGUID(guid)
  if kind ~= "Creature" or not npcId then return end
  local now = GetTime()
  if lastSeen[npcId] and now - lastSeen[npcId] < 20 then return end
  lastSeen[npcId] = now
  local cls = UnitClassification and UnitClassification(unit)
  if ns.IsSecret(cls) then cls = nil end
  local family = UnitCreatureFamily and UnitCreatureFamily(unit)
  if ns.IsSecret(family) then family = nil end
  local ctype = UnitCreatureType and UnitCreatureType(unit)
  if ns.IsSecret(ctype) then ctype = nil end
  local rare = cls == "rare" or cls == "rareelite"
  local beast = family ~= nil or ns.Beasts[npcId] ~= nil
  if not rare and not beast then return end
  local name = UnitName(unit)
  if ns.IsSecret(name) then name = nil end
  local level = UnitLevel(unit)
  if ns.IsSecret(level) then level = nil end
  local map, x, y = Here()
  local store = Store()
  local function Note(t)
    local rec = t[npcId]
    if not rec then rec = { spots = {} }; t[npcId] = rec end
    rec.name = name or rec.name
    rec.fam = family and ns.ToEnglish and ns.ToEnglish(family) or family or rec.fam
    rec.cls = cls or rec.cls
    if level and level > 0 then
      rec.lo = math.min(rec.lo or level, level); rec.hi = math.max(rec.hi or level, level)
    end
    rec.t = time()
    -- the player's spot: the beast is within a nameplate's range of it (exact when targeted)
    ns.RecordSpot(rec.spots, map, x, y, exact and 40 or 25)
  end
  if beast then Note(store.beasts) end
  if rare then Note(store.rares) end
end

---------------------------------------------------------------------------
-- What the game marks on the minimap, and library books
---------------------------------------------------------------------------
function ns.RecordVignette(info)
  if not ns.db.recordData or not info then return end
  local name, atlas, og = info.name, info.atlasName, info.objectGUID
  if ns.IsSecret(name) or ns.IsSecret(atlas) or ns.IsSecret(og) then return end
  local kind, id = ParseGUID(og)
  local key = (kind and id) and (kind .. ":" .. id) or (name or "?")
  local marks = Store().marks
  local rec = marks[key]
  if not rec then
    local n = 0
    for _ in pairs(marks) do n = n + 1 end
    if n >= 300 then return end
    rec = { name = name, atlas = atlas, kind = kind, id = id, spots = {} }
    marks[key] = rec
  end
  local map, x, y = Here()
  ns.RecordSpot(rec.spots, map, x, y, 20)
  rec.t = time()
end

function ns.RecordBook(name, what, value)
  if not ns.db.recordData or not name then return end
  local books = Store().books
  local rec = books[name] or { spots = {} }
  books[name] = rec
  if what == "item" then rec.item = value
  elseif what == "quest" then rec.quest = value
  elseif what == "found" then
    local map, x, y = Here()
    ns.RecordSpot(rec.spots, map, x, y, 5)
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "MERCHANT_SHOW", "LOOT_OPENED", "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then RecordUnit(unit, false)
  elseif event == "PLAYER_TARGET_CHANGED" then RecordUnit("target", true)
  elseif event == "UPDATE_MOUSEOVER_UNIT" then RecordUnit("mouseover", true)
  elseif event == "MERCHANT_SHOW" then
    if C_Timer and C_Timer.After then C_Timer.After(0.3, RecordVendor) else RecordVendor() end
  elseif event == "LOOT_OPENED" then
    RecordLoot()
  end
end)

-- Counts for Settings and /ut recorded
function ns.RecordedCounts()
  local r = ns.db.recorded and ns.db.recorded[ns.FLAVOR] or {}
  local v, d, items = 0, 0, 0
  for _, x in pairs(r.vendors or {}) do v = v + 1; for _ in pairs(x.items or {}) do items = items + 1 end end
  for _ in pairs(r.drops or {}) do d = d + 1 end
  local extra = {}
  for _, k in ipairs({ "beasts", "rares", "marks", "books" }) do
    local n = 0
    for _ in pairs(r[k] or {}) do n = n + 1 end
    extra[k] = n
  end
  return v, d, items, extra
end

ns.RecorderTest = { RecordVendor = RecordVendor, RecordLoot = RecordLoot, ParseGUID = ParseGUID, RecordUnit = RecordUnit }
