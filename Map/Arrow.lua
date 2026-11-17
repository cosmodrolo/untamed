local _, ns = ...
local L = ns.L

-- On-screen navigation arrow. Drag to move, right-click to stop.
local frame, arrow, title, dist
local target   -- { mapID, x, y, label, npcId, cont, east, north, checked, arrivedAt, found }
local ARRIVE = 25
local CHECKED_RADIUS = 70   -- spawn points this close to a spot you reached count as checked
local WAIT = 8              -- seconds to look around before moving on

---------------------------------------------------------------------------
-- Spawn hopping: when you reach a spawn spot and the beast isn't there, go to the next one.
---------------------------------------------------------------------------
local Advance   -- defined below

-- Is the beast we're looking for in sight (target, mouseover or a nameplate)?
local function Spotted(npcId)
  local function is(unit)
    if not UnitExists(unit) then return false end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not guid or ns.IsSecret(guid) then return false end
    if ns.NpcIdFromGUID(guid) ~= npcId then return false end
    return not (UnitIsDead and UnitIsDead(unit))
  end
  if is("target") or is("mouseover") then return true end
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if ok and type(plates) == "table" then
      for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and is(unit) then return true end
      end
    end
  end
  return false
end

local function IsChecked(t, c, e, n)
  for _, p in ipairs(t.checked) do
    local d = ns.Distance(p[1], p[2], p[3], c, e, n)
    if d and d <= CHECKED_RADIUS then return true end
  end
  return false
end

-- Nearest spawn point you haven't checked yet. Returns mapID, x, y, cont, east, north, left (unchecked count).
local function NextSpot(t)
  local b = ns.Beasts[t.npcId]
  if not b then return nil end
  local pc, pe, pn = ns.PlayerWorld()
  local best, bestD, left = nil, nil, 0
  for mapID, pts in pairs(b[7]) do
    for i = 1, #pts, 2 do
      local c, e, n = ns.ToWorld(mapID, pts[i], pts[i + 1])
      if c and not IsChecked(t, c, e, n) then
        left = left + 1
        local d = ns.Distance(pc, pe, pn, c, e, n)
        if d and (not bestD or d < bestD) then best, bestD = { mapID, pts[i], pts[i + 1], c, e, n }, d end
      end
    end
  end
  if not best then return nil, left end
  return best, left
end

local function CanHop(t)
  return t and t.npcId and ns.Beasts[t.npcId] and ns.db.arrowNextSpot ~= false
end

local function Create()
  frame = CreateFrame("Button", "UntamedArrow", UIParent)
  frame:SetSize(120, 76)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("RightButtonUp")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.arrowPos = { p, rp, x, y }
  end)
  frame:SetScript("OnClick", function()
    if IsShiftKeyDown() and CanHop(target) then Advance(false) else ns.Arrow_Clear() end
  end)
  local pos = ns.db.arrowPos
  if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("TOP", 0, -160) end
  frame:SetScale(ns.db.arrowScale or 1)

  arrow = frame:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(44, 44)
  arrow:SetPoint("TOP", 0, 0)
  arrow:SetTexture("Interface\\AddOns\\Untamed\\Media\\Arrow")
  if arrow.SetSnapToPixelGrid then arrow:SetSnapToPixelGrid(false); arrow:SetTexelSnappingBias(0) end
  arrow:SetVertexColor(0.35, 0.95, 0.35)

  title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", arrow, "BOTTOM", 0, 0)
  title:SetWidth(220)
  dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dist:SetPoint("TOP", title, "BOTTOM", 0, -2)
  dist:SetWidth(220)

  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Untamed arrow"], 1, 0.82, 0)
    if target then GameTooltip:AddLine(target.label, 1, 1, 1, true) end
    if CanHop(target) then
      local _, left = NextSpot(target)
      GameTooltip:AddLine(string.format(L["%d spawn spots left to check"], left or 0), 1, 1, 1)
      GameTooltip:AddLine(L["Shift-right-click: next spot now"], 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(L["Drag to move. Right-click to stop."], 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local elapsed = 0
  frame:SetScript("OnUpdate", function(self, e)
    elapsed = elapsed + e
    if elapsed < 0.05 then return end
    elapsed = 0
    if not target then self:Hide() return end
    local pc, pe, pn = ns.PlayerWorld()
    local d = ns.Distance(pc, pe, pn, target.cont, target.east, target.north)
    if not d then
      arrow:Hide()
      dist:SetText("|cffff9933On " .. (ns.ZoneName(target.mapID)) .. ". Travel to that continent first.|r")
      return
    end
    arrow:Show()
    local hop = CanHop(target)
    if hop and target.arrivedAt and not target.found then
      if Spotted(target.npcId) then
        target.found = true
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
      elseif d > ARRIVE * 2 or GetTime() - target.arrivedAt >= WAIT then
        Advance(true)
        return
      end
    end
    if d <= ARRIVE or (hop and target.arrivedAt) then
      arrow:SetRotation(0)
      arrow:SetVertexColor(1, 0.82, 0)
      if target.found then
        dist:SetText("|cff40ff40" .. L["Found it! Right-click to stop."] .. "|r")
      elseif hop and target.arrivedAt then
        dist:SetText(string.format("|cff40ff40" .. L["Look around. Next spot in %d s"] .. "|r", math.max(0, math.ceil(WAIT - (GetTime() - target.arrivedAt)))))
      else
        dist:SetText("|cff40ff40You're here. Look around for it.|r")
      end
      if not target.arrived then
        target.arrived = true
        PlaySound(SOUNDKIT and SOUNDKIT.MAP_PING or 3175)
        ns.Fire("ARROW_ARRIVED", target)
        if hop then
          target.checked[#target.checked + 1] = { target.cont, target.east, target.north }
          target.arrivedAt = GetTime()
          if Spotted(target.npcId) then target.found = true end
        end
      end
      return
    end
    target.arrived = false
    -- Spotted on the way there: stop hopping.
    if hop and not target.found and d < 120 and Spotted(target.npcId) then target.found = true end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing and not ns.IsSecret(facing) then
      local bearing = math.atan2(-(target.east - pe), target.north - pn)
      local turn = bearing - facing
      arrow:SetRotation(turn)
      -- Green when you're heading at it, yellow off to the side, red when it's behind you.
      local off = math.abs(((turn + math.pi) % (2 * math.pi)) - math.pi) / math.pi
      if off < 0.5 then
        arrow:SetVertexColor(0.35 + 1.3 * off, 0.95 - 0.2 * off, 0.35 - 0.3 * off)
      else
        local t = (off - 0.5) * 2
        arrow:SetVertexColor(1, 0.85 - 0.55 * t, 0.2 + 0.05 * t)
      end
    else
      arrow:SetVertexColor(0.35, 0.95, 0.35)
    end
    dist:SetText(ns.FormatDistance(d))
  end)
end

function ns.Arrow_Set(mapID, x, y, label, npcId)
  if not frame then Create() end
  local c, e, n = ns.ToWorld(mapID, x, y)
  if not c then
    ns.Print(L["Can't navigate there (no map position). Map pins still show it."])
    return
  end
  target = { mapID = mapID, x = x, y = y, label = label, npcId = npcId, cont = c, east = e, north = n, checked = {} }
  title:SetText(label)
  frame:Show()
end

-- Move to the next unchecked spawn spot (auto after looking around, or on Shift-right-click).
Advance = function(auto)
  local t = target
  if not CanHop(t) then return end
  if not t.arrivedAt then t.checked[#t.checked + 1] = { t.cont, t.east, t.north } end
  local spot, left = NextSpot(t)
  if not spot then
    -- Every spot checked: start over from the nearest.
    t.checked = { { t.cont, t.east, t.north } }
    spot, left = NextSpot(t)
    ns.Print(string.format(L["Checked every known spot for %s. Starting over from the nearest; it may still be respawning."], ns.Beasts[t.npcId][1]))
    if not spot then return end
  elseif auto then
    ns.Print(string.format(L["%s isn't here. Heading to the next spot (%d left)."], ns.Beasts[t.npcId][1], left))
  end
  t.mapID, t.x, t.y, t.cont, t.east, t.north = spot[1], spot[2], spot[3], spot[4], spot[5], spot[6]
  t.arrived, t.arrivedAt, t.found = false, nil, false
end

function ns.Arrow_NextSpot()
  if CanHop(target) then Advance(false) else ns.Print(L["The arrow isn't pointing at a beast."]) end
end

-- Navigate to the nearest spawn of a beast.
function ns.Navigate(npcId)
  local b = ns.Beasts[npcId]
  if not b then return end
  local mapID, x, y = ns.NearestSpawn(npcId)
  if not mapID or not x then
    local zone = next(b[7])
    ns.Print(zone and (b[1] .. " is somewhere in " .. (ns.ZoneName(zone)) .. ". Exact spots aren't known yet.")
      or (L["No known location for "] .. b[1] .. "."))
    return
  end
  local label = b[1] .. (b[8] and (" (inside " .. b[8] .. ")") or "")
  ns.Arrow_Set(mapID, x, y, label, npcId)
  if ns.Pins_Focus then ns.Pins_Focus({ npcId }, b[1], false) end
end

function ns.Arrow_Clear()
  target = nil
  if frame then frame:Hide() end
end

function ns.Arrow_Target() return target end
