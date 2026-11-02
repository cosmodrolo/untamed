local _, ns = ...
local L = ns.L
local C = ns.C

-- All Beasts: every tameable beast, with filters for family, the ability it teaches, where it is,
-- whether you can tame it now, and rares.
local list
local filter = { family = "any", text = "", tameable = false, rare = false, teaches = "any", where = "any", sort = "level" }

local function FamilyOptions()
  local o = { { "any", L["All families"] } }
  for _, f in ipairs(ns.Families) do o[#o + 1] = { f, ns.FamilyLabel(f) } end
  return o
end
local function TeachOptions()
  local o = { { "any", L["Teaches anything or nothing"] }, { "some", L["Teaches an ability"] } }
  for _, a in ipairs(ns.AbilityOrder) do
    if ns.AbilityFamilies[a] and a ~= "Cower" then o[#o + 1] = { a, ns.AbilityLabel(a) } end
  end
  return o
end
local WHERE = { { "any", L["Anywhere"] }, { "zone", L["This zone"] }, { "near", L["My continent, nearest first"] } }
local SORTS = { { "level", L["Sort: Level"] }, { "name", L["Sort: Name"] }, { "speed", L["Sort: Attack speed"] } }

local function Build(panel)
  local tb = ns.Toolbar(panel)
  tb:Search(L["Name or zone"], 140, function(t) filter.text = t end)
  tb:Dropdown(130, FamilyOptions, function() return filter.family end, function(v) filter.family = v end)
  tb:Dropdown(170, TeachOptions, function() return filter.teaches end, function(v) filter.teaches = v end,
    { L["Teaches"], L["Pick an ability to see every beast that teaches it."] })
  tb:Row()
  tb:Dropdown(170, WHERE, function() return filter.where end, function(v) filter.where = v end)
  tb:Dropdown(140, ns.FLAVOR == "forever" and { SORTS[1], SORTS[2] } or SORTS, function() return filter.sort end, function(v) filter.sort = v end)
  tb:Check(L["Tameable now"], function() return filter.tameable end, function(v) filter.tameable = v end)
  tb:Check(L["Rares only"], function() return filter.rare end, function(v) filter.rare = v end)
  list = tb:List()
end

local function Matches(b, playerLevel, zone)
  if filter.family ~= "any" and b[4] ~= filter.family then return false end
  if filter.tameable and b[2] > playerLevel then return false end
  if filter.rare and not (b[5] and b[5]:find("Rare")) then return false end
  if filter.teaches == "some" and #b[6] == 0 then return false end
  if filter.teaches ~= "any" and filter.teaches ~= "some" then
    local hit = false
    for i = 1, #b[6], 2 do if b[6][i] == filter.teaches then hit = true end end
    if not hit then return false end
  end
  if filter.where == "zone" and not (zone and b[7][zone]) then return false end
  if filter.text ~= "" then
    local hay = b[1]:lower() .. " " .. (b[8] or ""):lower()
    for mapID in pairs(b[7]) do hay = hay .. " " .. (ns.ZoneName(mapID)):lower() end
    if not hay:find(filter.text, 1, true) then return false end
  end
  return true
end

local function Refresh()
  local playerLevel = UnitLevel("player")
  local zone = ns.PlayerMap and ns.PlayerMap()
  local ids, dist = {}, {}
  for id, b in pairs(ns.Beasts) do
    if Matches(b, playerLevel, zone) then
      if filter.where == "near" then
        local _, _, _, d = ns.NearestSpawn(id)
        if d then dist[id] = d; ids[#ids + 1] = id end
      else
        ids[#ids + 1] = id
      end
    end
  end
  local B = ns.Beasts
  table.sort(ids, function(a, b)
    local x, y = B[a], B[b]
    if filter.where == "near" and dist[a] ~= dist[b] then return dist[a] < dist[b] end
    if filter.sort == "name" then return x[1] < y[1] end
    if filter.sort == "speed" and (x[9] or 9) ~= (y[9] or 9) then return (x[9] or 9) < (y[9] or 9) end
    if x[2] ~= y[2] then return x[2] < y[2] end
    return x[1] < y[1]
  end)
  local rows = {}
  rows[1] = { 0, nil, #ids .. L[" beasts"], C.GREY .. L["click for arrow, right-click for map"] .. "|r", nil, nil, { header = true } }
  for i = 1, math.min(#ids, 400) do
    local id = ids[i]
    local b = B[id]
    local lv = (b[2] > playerLevel) and C.RED or C.WHITE
    local left = string.format("%s%s|r", b[5] and C.ORANGE or C.WHITE, b[1]) .. C.GREY .. "  " .. ns.FamilyLabel(b[4]) .. "|r"
    local right = ns.ZonesText(b)
    if dist[id] then right = right .. C.GREY .. ", " .. ns.FormatDistance(dist[id]) .. "|r" end
    if b[9] then right = C.GREY .. b[9] .. "s|r  " .. right end
    rows[#rows + 1] = { 0, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"), left, right, ns.BeastClick(id), ns.BeastTooltip(id), { mid = lv .. ns.LevelText(b) .. "|r" } }
  end
  if #ids == 0 then rows[#rows + 1] = { 0, nil, C.GREY .. L["No beasts match. Try fewer filters."] .. "|r" } end
  list:Set(rows)
end

function ns.BrowserFilter() return filter end
ns.RegisterTab("browse", L["All Beasts"], Build, Refresh)
