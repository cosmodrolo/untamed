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

function ns.ChestSpotsOn(mapID)
  if not mapID or not ns.ChestWorld then return nil end
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
  cache[mapID] = c
  return c
end

ns.ChestCacheClear = function() wipe(cache) end

local function KindName(k) return ns.ChestKinds and ns.ChestKinds[k] or L["Chest"] end

-- world map: the shown zone's chest spots
table.insert(ns.PinSources, function(mapID)
  if ns.db.chestPins == false or not mapID then return nil end
  local spots = ns.ChestSpotsOn(mapID)
  if not spots or #spots == 0 then return nil end
  local out = {}
  for i = 1, #spots, 3 do
    out[#out + 1] = { map = mapID, x = spots[i], y = spots[i + 1], name = KindName(spots[i + 2]), size = 10,
      border = { 0.94, 0.62, 0.15, 1 }, icon = CHEST_ICON,
      lines = { KindName(spots[i + 2]), L["A chest can appear here (not always one up)"] } }
  end
  return out
end)

-- minimap: chest spots around you
table.insert(ns.MinimapSources, function(mapID)
  if ns.db.chestPins == false or ns.db.chestMinimap == false then return nil end
  local spots = ns.ChestSpotsOn(mapID)
  if not spots then return nil end
  local out = {}
  for i = 1, #spots, 3 do out[#out + 1] = { spots[i], spots[i + 1], CHEST_ICON, KindName(spots[i + 2]), 0.94, 0.62, 0.15 } end
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
  elseif arg == "minimap" then
    ns.db.chestMinimap = ns.db.chestMinimap == false
    ns.Print(ns.db.chestMinimap and L["Chest spots show on the minimap."] or L["Chest spots are off the minimap."])
    if ns.MinimapRebuild then ns.MinimapRebuild() end
  else
    ns.Print(L["/ut chests on, off, minimap (spots on the minimap too)   |   /ut scan  what the game marks around you"])
  end
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function() CheckVignettes() end)
end
