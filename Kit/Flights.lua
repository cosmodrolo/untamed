local _, FLT = ...; FLT = FLT.Kit; if not FLT then return end
local L = FLT.L or setmetatable({}, { __index = function(_, k) return k end }) -- (tests without Locales)

-- Flight times (6.1.5, user 05.11.): from the length of the flight paths in the client data (Data/FlightPaths.lua,
-- yards / taxi speed, summed over the stops of the route), corrected by the flights you take: per route "From>To" the
-- measured time is kept in UntamedKitDB.flightTimes and used first; the ratio measured / computed
-- (UntamedKitDB.flightFactor) corrects the other routes. Without path data: an estimate from the straight distance on
-- the flight map (UntamedKitDB.flightPace), marked "about".
-- Shows: a small bar with the destination and the time left while flying, and the time in the tooltip of the
-- destinations on the flight map. Option "Flight times" (QoL > World Map). A 1 s ticker runs only while flying.

local Q = FLT.QoL
local function on() return Q and Q.Get and Q.Get("flightTimes") end
local function db()
  if type(UntamedKitDB) ~= "table" then return nil end
  UntamedKitDB.flightTimes = UntamedKitDB.flightTimes or {}
  return UntamedKitDB
end

-- the flight map: name and position of the node you stand at, and of node i
local function currentNode()
  if not (NumTaxiNodes and TaxiNodeGetType) then return nil end
  for i = 1, NumTaxiNodes() do
    if TaxiNodeGetType(i) == "CURRENT" then return i end
  end
end
local function nodeName(i) local n = TaxiNodeName and TaxiNodeName(i); return type(n) == "string" and n or nil end
-- node ID of flight map slot i (user 05.11.: the German client has other node names - Undercity -> Silverpine counted
-- up): from C_TaxiMap.GetAllTaxiNodes of the flight map, else the English name
local slotIDs, slotMap = {}, nil
local function nodeID(i)
  if not i then return nil end
  local map = GetTaxiMapID and GetTaxiMapID()
  if map ~= slotMap then
    wipe(slotIDs); slotMap = map
    local ok, list = pcall(function() return map and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_TaxiMap.GetAllTaxiNodes(map) end)
    if ok and type(list) == "table" then
      for _, n in ipairs(list) do if n.slotIndex and n.nodeID then slotIDs[n.slotIndex] = n.nodeID end end
    end
  end
  return slotIDs[i] or (FLT.FLIGHT_NODES and FLT.FLIGHT_NODES[nodeName(i) or ""])
end
local function dist(a, b)
  if not TaxiNodePosition then return nil end
  local ax, ay = TaxiNodePosition(a); local bx, by = TaxiNodePosition(b)
  if not (ax and bx) then return nil end
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- seconds of a route from the path data: each stop of the route (GetNumRoutes / TaxiGetNodeSlot), or the direct path
local SPEED, OVERHEAD = 30, 3 -- taxi speed in yards per second; take-off and landing
local function pathSecs(a, b)
  local p = a and b and FLT.FLIGHT_PATHS and FLT.FLIGHT_PATHS[a] and FLT.FLIGHT_PATHS[a][b]
  if not p then return nil end
  if type(p) == "table" then return p[1] / SPEED + (p[2] or 0) / 1000 end
  return p / SPEED
end
local function dataTime(i, from, to)
  local total
  local ok, n = pcall(function() return GetNumRoutes and GetNumRoutes(i) end)
  if ok and n and n > 0 and TaxiGetNodeSlot then
    total = 0
    for r = 1, n do
      local s = pathSecs(nodeID(TaxiGetNodeSlot(i, r, true)), nodeID(TaxiGetNodeSlot(i, r, false)))
      if not s then total = nil; break end
      total = total + s
    end
  end
  total = total or pathSecs(nodeID(currentNode()), nodeID(i))
  return total and (total + OVERHEAD)
end

-- seconds for node i from here: measured, from the path data, or estimated ("about"); nil = nothing known
local function timeTo(i)
  local d = db(); local cur = currentNode()
  if not (d and cur) or i == cur then return nil end
  local from, to = nodeName(cur), nodeName(i)
  if not (from and to) then return nil end
  local t = d.flightTimes[from .. ">" .. to]
  if t then return t, false end
  local raw = dataTime(i, from, to)
  if raw then return raw * (d.flightFactor or 1), false, raw end
  local pace, dd = d.flightPace, dist(cur, i)
  if pace and dd and dd > 0 then return dd * pace, true end
end
local function fmt(s) s = math.floor(s + 0.5); return string.format("%d:%02d", math.floor(s / 60), s % 60) end
FLT.FlightTimeTo = timeTo -- tests

-- the flight that was picked, and the one in the air
local picked, flight
local function onTake(i)
  if not on() then return end
  local cur = currentNode()
  local from, to = cur and nodeName(cur), nodeName(i)
  if not (from and to) then return end
  local est, about, raw = timeTo(i)
  picked = { from = from, to = to, d = cur and dist(cur, i), est = est, about = about, raw = raw }
end
if hooksecurefunc and TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i) FLT.SafeCall("Flights", onTake, i) end) end

-- the small window while flying (user 05.11.): the flight master icon and the time left; drag to move (kept in
-- UntamedKitDB.qol.flightPos), the destination in its tooltip
local bar
local function makeBar()
  local UI = FLT.UI
  bar = CreateFrame("Frame", "UntamedKitFlightTimer", UIParent)
  bar:SetSize(96, 30); bar:SetFrameStrata("MEDIUM"); bar:SetClampedToScreen(true)
  bar:SetMovable(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
  local pos = Q and Q.Get and Q.Get("flightPos")
  if type(pos) == "table" then bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2]) else bar:SetPoint("TOP", UIParent, "TOP", 0, -110) end
  if UI and UI.FramedPanel then UI.FramedPanel(bar) end
  bar.icon = bar:CreateTexture(nil, "ARTWORK"); bar.icon:SetSize(20, 20); bar.icon:SetPoint("LEFT", 6, 0)
  FLT.SetTex(bar.icon, "Interface\\Minimap\\Tracking\\FlightMaster")
  bar.text = FLT.NewFS(bar, nil, "OVERLAY", "GameFontHighlight"); bar.text:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
  bar.fill = bar:CreateTexture(nil, "OVERLAY"); bar.fill:SetColorTexture(1, 0.78, 0.25, 0.9); bar.fill:SetHeight(2)
  bar.fill:SetPoint("BOTTOMLEFT", 6, 4)
  bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
  bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if x and y and Q and Q.Set then Q.Set("flightPos", { math.floor(x + 0.5), math.floor(y + 0.5) }) end
  end)
  bar:SetScript("OnEnter", function(self)
    if not flight then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(flight.to, 1, 0.82, 0)
    GameTooltip:AddLine(L["Drag to move."], 0.75, 0.75, 0.75); GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar:Hide()
end
local ticker
local function paint()
  if not (flight and bar) then return end
  local t = (GetTime and GetTime() or 0) - flight.start
  if flight.est then
    local left = math.max(0, flight.est - t)
    bar.text:SetText((flight.about and "~" or "") .. fmt(left))
    bar.fill:SetWidth(math.max(1, 84 * (1 - math.min(1, t / flight.est)))); bar.fill:Show()
  else
    bar.text:SetText("|cff9d9d9d" .. fmt(t) .. "|r")
    bar.fill:Hide()
  end
end
local function stopTicker() if ticker then ticker:Cancel(); ticker = nil end end
local function landed()
  stopTicker()
  if bar then bar:Hide() end
  local f = flight; flight = nil
  if not f then return end
  local t = (GetTime and GetTime() or 0) - f.start
  local d = db()
  if not d or t < 5 or f.noKeep then return end
  -- a flight far off its estimate was cut short or broke off (e.g. a disconnect): not kept
  if f.est and not f.about and (t < f.est * 0.6 or t > f.est * 1.6) then return end
  local key = f.from .. ">" .. f.to
  local old = d.flightTimes[key]
  d.flightTimes[key] = old and (old * 0.5 + t * 0.5) or t
  if f.raw and f.raw > 0 then -- how far the path data is off (taxi speed, stops): corrects the other routes
    local k = t / f.raw
    if k > 0.6 and k < 1.6 then d.flightFactor = d.flightFactor and (d.flightFactor * 0.8 + k * 0.2) or k end
  end
  if f.d and f.d > 0 then
    local pace = t / f.d
    d.flightPace = d.flightPace and (d.flightPace * 0.8 + pace * 0.2) or pace
  end
end
local function takeOff()
  if not (picked and on()) then return end
  flight = picked; picked = nil
  flight.start = GetTime and GetTime() or 0
  if not bar then makeBar() end
  -- no time known for this route (user 05.11.: counting up looked wrong): no window, the flight is still measured
  paint(); bar:SetShown(flight.est and true or false)
  stopTicker()
  -- every second: paint, and notice the landing (user 05.11.: the window stayed - the control event alone is not
  -- reliable on the live client)
  if C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(1, function()
      local f = flight
      if not f then return end
      local t = (GetTime and GetTime() or 0) - f.start
      -- landed: off the taxi, or (user 05.11.: the window stayed - UnitOnTaxi did not change on the live client) no
      -- longer moving at taxi speed (taxis fly about 30 yards/s, running or riding is below 20); fallback: well past
      -- the expected time
      local speed = GetUnitSpeed and GetUnitSpeed("player")
      if type(speed) == "number" and speed >= 20 then f.fast = true end -- the speed rule only once it was seen flying fast
      local off = (UnitOnTaxi and not UnitOnTaxi("player"))
        or (f.fast and type(speed) == "number" and speed < 20)
      if off then FLT.SafeCall("Flights", landed)
      elseif f.est and t > f.est + 15 then f.noKeep = true; FLT.SafeCall("Flights", landed) -- landing not seen: not kept
      else paint() end
    end)
  end
end

-- the flight map tooltip (classic TaxiFrame buttons)
local function tipFor(button)
  if not on() or not (button and button.GetID) then return end
  local t, about = timeTo(button:GetID())
  if not t then return end
  GameTooltip:AddLine(string.format(about and L["Flight time: about %s"] or L["Flight time: %s"], fmt(t)), 1, 0.82, 0)
  GameTooltip:Show()
end
if hooksecurefunc and type(TaxiNodeOnButtonEnter) == "function" then
  hooksecurefunc("TaxiNodeOnButtonEnter", function(b) FLT.SafeCall("Flights", tipFor, b) end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  FLT.SafeCall("Flights", function()
    if event == "PLAYER_CONTROL_LOST" then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() if UnitOnTaxi and UnitOnTaxi("player") then takeOff() end end)
      end
    elseif event == "PLAYER_CONTROL_GAINED" and flight and C_Timer and C_Timer.After then
      C_Timer.After(0.5, function() if flight and not (UnitOnTaxi and UnitOnTaxi("player")) then landed() end end)
    elseif flight and not (UnitOnTaxi and UnitOnTaxi("player")) then
      landed()
    end
  end)
end)
