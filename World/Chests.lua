local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Treasure chests: every spot a random world chest (Battered, Solid, footlockers ...) can appear,
-- on the world map, OpenMap and the minimap, plus a heads-up when the game shows one near you.
--  * Spots: Data/Chests_Forever.lua (world positions), turned into map spots in game with
--    C_Map.GetMapPosFromWorldPos, once per map.
--  * Live: map vignettes for objects (if Forever marks chests on the minimap; /ut scan shows
--    what the game marks around you right now).
--  * Chests you open are noted by the recorder (where, what dropped), so the spots get better.
-- /ut chests on | off, /ut scan.
---------------------------------------------------------------------------

local CHEST_ICON = "Interface\\Icons\\INV_Box_02"
local cache = {}         -- [mapID] = { x, y, kind, ... }
local alerted = {}       -- [vignette guid] = true

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end

local function Continent(mapID)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, cont = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
  return ok and Plain(cont) or nil
end

-- Chest spots found in game, in zones the data doesn't cover: [mapID] = { x, y, kind, ... }
ns.ChestFound = {
  [2548] = { 18.6, 70.7, 2 },      -- Riverglades: Solid Chest
}

function ns.ChestSpotsOn(mapID)
  if not mapID then return nil end
  ns.ChestWorld = ns.ChestWorld or {}
  local c = cache[mapID]
  if c then return c end
  c = {}
  local cont = Continent(mapID)
  local list = cont and ns.ChestWorld[cont]
  -- the data is (north, west) yards as the game's world positions take them; if a map gets no
  -- spots that way, try the other order once and keep whichever works
  local function Fill(swap)
    for i = 1, #list, 3 do
      local wx, wy = list[i + 1], list[i + 2]
      if swap then wx, wy = wy, wx end
      local ok, m, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), mapID)
      if ok and m and pos then
        local x, y
        if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
        if x and not ns.IsSecret(x) and x > 0 and x < 1 and y > 0 and y < 1 then
          c[#c + 1] = x * 100; c[#c + 1] = y * 100; c[#c + 1] = list[i]
        end
      end
    end
  end
  if list and C_Map.GetMapPosFromWorldPos then
    Fill(ns.chestSwap)
    if #c == 0 and ns.chestSwap == nil then
      Fill(true)
      if #c > 0 then ns.chestSwap = true end
    elseif #c > 0 then
      ns.chestSwap = ns.chestSwap or false
    end
  end
  -- zones the data has nothing for (the new Forever zones): chests found in game. First the ones
  -- shipped with the addon, then every spot you opened a chest at yourself (the recorder's notes).
  local function Add(x, y, kind)
    for i = 1, #c, 3 do
      if math.abs(c[i] - x) < 1.5 and math.abs(c[i + 1] - y) < 1.5 then return end
    end
    c[#c + 1] = x; c[#c + 1] = y; c[#c + 1] = kind
  end
  local found = ns.ChestFound[mapID]
  for i = 1, found and #found or 0, 3 do Add(found[i], found[i + 1], found[i + 2]) end
  local rec = ns.db and ns.db.recorded and ns.db.recorded[ns.FLAVOR]
  local drops = rec and rec.drops
  if drops and ns.ChestIds then
    local ids = {}
    for id in pairs(ns.ChestIds) do if drops["o" .. id] then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local s = drops["o" .. id].spots
      for i = 1, type(s) == "table" and #s or 0, 3 do
        if s[i] == mapID and type(s[i + 1]) == "number" and type(s[i + 2]) == "number" then Add(s[i + 1], s[i + 2], ns.ChestIds[id]) end
      end
    end
  end
  cache[mapID] = c
  return c
end

ns.ChestCacheClear = function() wipe(cache) end

-- Chests you opened: their spot is left off the map, the minimap and the "nearby" alert until a
-- chest could be back. Kept per character, by map and spot, with the time you opened it.
local RESPAWN = 30 * 60
local function Opened(mapID, i)
  local o = ns.cdb and ns.cdb.chestOpened
  local t = o and o[mapID .. ":" .. i]
  if not t then return false end
  if time() - t >= RESPAWN then o[mapID .. ":" .. i] = nil return false end
  return true
end
ns.ChestOpened = Opened

local function KindName(k) return ns.ChestKinds and ns.ChestKinds[k] or L["Chest"] end

-- world map: the shown zone's chest spots
table.insert(ns.PinSources, function(mapID)
  if ns.db.chestPins == false or not mapID then return nil end
  local spots = ns.ChestSpotsOn(mapID)
  if not spots or #spots == 0 then return nil end
  local out = {}
  for i = 1, #spots, 3 do
    if not Opened(mapID, i) then
      out[#out + 1] = { map = mapID, x = spots[i], y = spots[i + 1], name = KindName(spots[i + 2]), size = 10,
        border = { 0.94, 0.62, 0.15, 1 }, icon = CHEST_ICON,
        lines = { KindName(spots[i + 2]), L["A chest can appear here (not always one up)"] } }
    end
  end
  return out
end)

-- minimap: chest spots around you
table.insert(ns.MinimapSources, function(mapID)
  if ns.db.chestPins == false or ns.db.chestMinimap == false then return nil end
  local spots = ns.ChestSpotsOn(mapID)
  if not spots then return nil end
  local out = {}
  for i = 1, #spots, 3 do
    if not Opened(mapID, i) then out[#out + 1] = { spots[i], spots[i + 1], CHEST_ICON, KindName(spots[i + 2]), 0.94, 0.62, 0.15 } end
  end
  return out
end)

-- what the game marks on your minimap right now: rares, chests, anything
local function Vignettes()
  if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return {} end
  local ok, list = pcall(C_VignetteInfo.GetVignettes)
  if not ok or type(list) ~= "table" then return {} end
  local out = {}
  for _, guid in ipairs(list) do
    local ok2, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
    if ok2 and info then out[#out + 1] = { guid = guid, info = info } end
  end
  return out
end

local function CheckVignettes()
  if ns.db.chestAlerts == false then return end
  for _, v in ipairs(Vignettes()) do
    local info = v.info
    local og = Plain(info.objectGUID)
    local name = Plain(info.name)
    if og and name and og:match("^GameObject") and not alerted[v.guid] then
      alerted[v.guid] = true
      ns.Alert(C.GOLD .. L["Treasure nearby: "] .. "|r" .. name, true)
      ns.Print(string.format(L["Treasure nearby: %s. Look around: it's marked on your minimap."], name))
      if ns.RecordVignette then ns.RecordVignette(info) end
    elseif og and name and ns.RecordVignette then
      ns.RecordVignette(info)
    end
  end
end

function ns.ScanReport()
  local list = Vignettes()
  ns.Print(string.format(L["The game marks %d thing(s) on your minimap right now:"], #list))
  for _, v in ipairs(list) do
    local i = v.info
    ns.Print(string.format("  %s  (%s, %s)", Plain(i.name) or "?", Plain(i.atlasName) or "-", (Plain(i.objectGUID) or "-"):match("^(%a+)") or "-"))
  end
  local map = C_Map.GetBestMapForUnit("player")
  local spots = map and ns.ChestSpotsOn(map)
  ns.Print(string.format(L["Chest spots in this zone: %d."], spots and #spots / 3 or 0))
end

function ns.ChestCommand(arg)
  if arg == "off" or arg == "on" then
    ns.db.chestPins = arg == "on"
    ns.Print(ns.db.chestPins and L["Chest spots are on the map again."] or L["Chest spots are off the map (/ut chests on brings them back)."])
    if ns.Pins_Refresh then ns.Pins_Refresh() end
    if ns.MinimapRebuild then ns.MinimapRebuild() end
  elseif arg == "near" then
    ns.db.chestNear = ns.db.chestNear == false
    ns.Print(ns.db.chestNear and L["You'll get a heads-up near a chest spot."] or L["No more heads-up near chest spots (a chest right in front of you still alerts)."])
  elseif arg and arg:match("^radius %d+$") then
    ns.db.chestRadius = tonumber(arg:match("%d+"))
    ns.Print(string.format(L["Chest spots alert within %d yards."], ns.db.chestRadius))
  elseif arg == "minimap" then
    ns.db.chestMinimap = ns.db.chestMinimap == false
    ns.Print(ns.db.chestMinimap and L["Chest spots show on the minimap."] or L["Chest spots are off the minimap."])
    if ns.MinimapRebuild then ns.MinimapRebuild() end
  else
    ns.Print(L["/ut chests on, off, minimap (spots on the minimap too), near (heads-up near a spot on/off), radius 60   |   /ut scan"])
  end
end

-- Forever doesn't mark chests on the minimap, so two more ways to notice one:
--  * A chest right in front of you: the gamepad's interact target (what Square would use) is a
--    chest. This one is certain: the chest is there.
--  * A chest spot nearby: you're within ns.db.chestRadius yards (60) of a spot a chest can
--    appear at. Not certain (only some spots have a chest up), so it says "may be", once per
--    spot every 20 minutes, out of fights and not on a flight.
local nearWarned, softWarned = {}, {}
local DIRS = { "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest" }

local function CheckSoftInteract()
  if ns.db.chestAlerts == false then return end
  local okE, exists = pcall(UnitExists, "softinteract")
  if not okE or ns.IsSecret(exists) or not exists then return end
  local guid = Plain(UnitGUID("softinteract"))
  if not guid or not guid:match("^GameObject") or softWarned[guid] then return end
  local id = tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
  local name = Plain(UnitName("softinteract"))
  local isChest = (id and ns.ChestIds and ns.ChestIds[id]) ~= nil
  if not isChest and name then
    for _, k in ipairs(ns.ChestKinds or {}) do if k == name then isChest = true break end end
  end
  if not isChest then return end
  softWarned[guid] = true
  ns.chestSeenAt = GetTime()      -- a chest was your interact target just now (see ChestLooted)
  ns.Alert(C.GOLD .. L["Chest right here: "] .. "|r" .. (name or L["Chest"]), true)
  ns.Print(string.format(L["Chest right here: %s. It's your interact target."], name or L["Chest"]))
end

local function CheckNearSpots()
  if ns.db.chestAlerts == false or ns.db.chestNear == false or InCombatLockdown() then return end
  if UnitOnTaxi and UnitOnTaxi("player") then return end
  if IsInInstance and IsInInstance() then return end
  local map = C_Map.GetBestMapForUnit("player")
  local spots = map and ns.ChestSpotsOn(map)
  if not spots or #spots == 0 then return end
  local pc, pe, pn = ns.PlayerWorld()
  if not pc then return end
  local radius = ns.db.chestRadius or 60
  local best, bd, be, bn
  for i = 1, #spots, 3 do
    local c, e, n = ns.ToWorld(map, spots[i], spots[i + 1])
    local d = ns.Distance(pc, pe, pn, c, e, n)
    if d and d <= radius and (not bd or d < bd) and not Opened(map, i) then best, bd, be, bn = i, d, e, n end
  end
  if not best then return end
  local key = map .. ":" .. best
  local now = GetTime()
  if nearWarned[key] and now - nearWarned[key] < 1200 then return end
  nearWarned[key] = now
  local ang = math.atan2(be - pe, bn - pn)
  local dir = L[DIRS[math.floor((ang / (2 * math.pi) * 8) + 0.5) % 8 + 1]]
  local kind = KindName(spots[best + 2])
  ns.Alert(C.GOLD .. L["Chest spot nearby: "] .. "|r" .. kind .. C.GREY .. string.format("  %d %s %s", bd, L["yd"], dir) .. "|r", false)
  ns.Print(string.format(L["Chest spot nearby: a %s may be up %d yards %s. It's on your minimap (orange)."], kind, bd, dir))
end
-- You opened a loot window. Was it a chest? Yes when the loot comes from a chest object, or when a
-- chest was your interact target in the last few seconds. Then the nearest chest spot (within 40
-- yards) is marked opened.
local function ChestLooted()
  local isChest, fromObject = false, false
  if GetNumLootItems and GetLootSourceInfo then
    for slot = 1, (Plain(GetNumLootItems()) or 0) do
      local ok, guid = pcall(GetLootSourceInfo, slot)
      guid = ok and Plain(guid)
      if type(guid) == "string" and guid:match("^GameObject") then
        local id = tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        if id and ns.ChestIds and ns.ChestIds[id] then isChest = true; fromObject = true break end
      end
    end
  end
  if not isChest and ns.chestSeenAt and GetTime() - ns.chestSeenAt < 8 then isChest = true end
  if not isChest then return false end
  local map = C_Map.GetBestMapForUnit("player")
  local spots = map and ns.ChestSpotsOn(map)
  local pc, pe, pn = ns.PlayerWorld()
  if not spots or not pc then return false end
  local best, bd
  for i = 1, #spots, 3 do
    local c, e, n = ns.ToWorld(map, spots[i], spots[i + 1])
    local d = ns.Distance(pc, pe, pn, c, e, n)
    if d and d <= 40 and (not bd or d < bd) then best, bd = i, d end
  end
  if not best and not fromObject then return false end
  if not best then
    -- a chest where no spot was known: the recorder is noting it right now, so read the spots
    -- again in a moment and it's on your map from here on
    if C_Timer and C_Timer.After then
      C_Timer.After(1, function()
        wipe(cache)
        if ns.Pins_Refresh then ns.Pins_Refresh() end
        if ns.MinimapRebuild then ns.MinimapRebuild() end
      end)
    end
    ns.Print(L["New chest spot. It's on your map from now on."])
    return false
  end
  if Opened(map, best) then return false end
  ns.cdb.chestOpened = ns.cdb.chestOpened or {}
  ns.cdb.chestOpened[map .. ":" .. best] = time()
  ns.chestSeenAt = nil
  if ns.Pins_Refresh then ns.Pins_Refresh() end
  if ns.MinimapRebuild then ns.MinimapRebuild() end
  ns.Print(string.format(L["Chest opened. Its spot is off your map for %d minutes, until one could be back."], RESPAWN / 60))
  return true
end

ns.ChestTest = { CheckNearSpots = CheckNearSpots, CheckSoftInteract = CheckSoftInteract, ChestLooted = ChestLooted }

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED", "PLAYER_SOFT_INTERACT_CHANGED", "LOOT_OPENED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event)
    if event == "LOOT_OPENED" then pcall(ChestLooted)
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then CheckSoftInteract() else CheckVignettes() end
  end)
  local t = 0
  ev:SetScript("OnUpdate", function(_, e)
    t = t + e
    if t < 2 then return end
    t = 0
    local ok, err = pcall(CheckNearSpots)
    if not ok then t = -30; if geterrorhandler then geterrorhandler()(err) end end
  end)
end
