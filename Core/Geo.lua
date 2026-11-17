local _, ns = ...

-- Converts zone map coordinates (0-100) into yards on a continent, so we can
-- measure distances across zones and point an arrow. Axis orientation is
-- worked out from the game itself, once per continent.

local axes = {}        -- [continentID] = { eastIdx, eastSign, northIdx, northSign }
local cache = {}       -- [mapID .. ":" .. x .. ":" .. y] = { cont, east, north }

local function rawWorld(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
  if not ok or not cont or not pos then return nil end
  local a, b
  if pos.GetXY then a, b = pos:GetXY() else a, b = pos.x, pos.y end
  if not a or ns.IsSecret(a) then return nil end
  return cont, a, b
end

local function calibrate(mapID, cont)
  if axes[cont] then return axes[cont] end
  local _, a0, b0 = rawWorld(mapID, 0.4, 0.4)
  local _, a1, b1 = rawWorld(mapID, 0.6, 0.4)   -- moved east
  local _, a2, b2 = rawWorld(mapID, 0.4, 0.6)   -- moved south
  if not (a0 and a1 and a2) then return nil end
  local ax = {}
  if math.abs(a1 - a0) > math.abs(b1 - b0) then
    ax.eastIdx, ax.eastSign = 1, (a1 > a0) and 1 or -1
  else
    ax.eastIdx, ax.eastSign = 2, (b1 > b0) and 1 or -1
  end
  if math.abs(a2 - a0) > math.abs(b2 - b0) then
    ax.northIdx, ax.northSign = 1, (a2 > a0) and -1 or 1
  else
    ax.northIdx, ax.northSign = 2, (b2 > b0) and -1 or 1
  end
  axes[cont] = ax
  return ax
end

-- x, y in 0-100 map percent. Returns continentID, eastYards, northYards
function ns.ToWorld(mapID, x, y)
  local key = mapID .. ":" .. x .. ":" .. y
  local c = cache[key]
  if c then return c[1], c[2], c[3] end
  local cont, a, b = rawWorld(mapID, x / 100, y / 100)
  if not cont then return nil end
  local ax = calibrate(mapID, cont)
  if not ax then return nil end
  local v = { a, b }
  local east, north = v[ax.eastIdx] * ax.eastSign, v[ax.northIdx] * ax.northSign
  cache[key] = { cont, east, north }
  return cont, east, north
end

function ns.PlayerWorld()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local px, py
  if pos.GetXY then px, py = pos:GetXY() else px, py = pos.x, pos.y end
  if not px or ns.IsSecret(px) then return nil end
  local cont, a, b = rawWorld(mapID, px, py)   -- not cached: player moves
  if not cont then return nil end
  local ax = calibrate(mapID, cont)
  if not ax then return nil end
  local v = { a, b }
  return cont, v[ax.eastIdx] * ax.eastSign, v[ax.northIdx] * ax.northSign, mapID, px * 100, py * 100
end

function ns.Distance(c1, e1, n1, c2, e2, n2)
  if not (c1 and c2) or c1 ~= c2 then return nil end
  local de, dn = e2 - e1, n2 - n1
  return math.sqrt(de * de + dn * dn)
end

function ns.FormatDistance(d)
  if not d then return "other continent" end
  if d < 1000 then return string.format("%d yd", d) end
  return string.format("%.1fk yd", d / 1000)
end

-- Nearest spawn of a beast to the player (or to a given world point).
-- Returns mapID, x, y, distance (distance nil if on another continent or unknown)
function ns.NearestSpawn(npcId, fromC, fromE, fromN)
  local b = ns.Beasts[npcId]
  if not b then return nil end
  if not fromC then fromC, fromE, fromN = ns.PlayerWorld() end
  local bestMap, bx, by, bestD
  for mapID, pts in pairs(b[7]) do
    for i = 1, #pts, 2 do
      local c, e, n = ns.ToWorld(mapID, pts[i], pts[i + 1])
      local d = ns.Distance(fromC, fromE, fromN, c, e, n)
      if d and (not bestD or d < bestD) then bestMap, bx, by, bestD = mapID, pts[i], pts[i + 1], d end
      if not bestMap then bestMap, bx, by = mapID, pts[i], pts[i + 1] end
    end
  end
  return bestMap, bx, by, bestD
end

-- Nearest stable master ("S") or flight master ("F") for your faction to a map point.
function ns.NearestService(kind, mapID, x, y)
  local fac = ns.PlayerFaction()
  local c, e, n = ns.ToWorld(mapID, x, y)
  local best, bestD
  for _, s in ipairs(ns.Services) do
    if s[1] == kind and (s[3] == "AH" or s[3]:find(fac, 1, true)) then
      local sc, se, sn = ns.ToWorld(s[4], s[5], s[6])
      local d = ns.Distance(c, e, n, sc, se, sn)
      if d and (not bestD or d < bestD) then best, bestD = s, d end
    end
  end
  return best, bestD
end

function ns.ServiceText(s, d)
  if not s then return "none found on this continent" end
  return string.format("%s, %s (%s away)", s[2], ns.ZoneName(s[4]), ns.FormatDistance(d))
end
