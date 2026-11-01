local _, ns = ...
local L = ns.L

-- On-screen navigation arrow. Drag to move, right-click to stop.
local frame, arrow, title, dist
local target   -- { mapID, x, y, label, npcId, cont, east, north }
local ARRIVE = 25

local function Create()
  frame = CreateFrame("Button", "UntamedArrow", UIParent)
  frame:SetSize(120, 92)
  frame:SetFrameStrata(L["MEDIUM"])
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag(L["LeftButton"])
  frame:RegisterForClicks(L["RightButtonUp"])
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.arrowPos = { p, rp, x, y }
  end)
  frame:SetScript("OnClick", function() ns.Arrow_Clear() end)
  local pos = ns.db.arrowPos
  if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("TOP", 0, -160) end
  frame:SetScale(ns.db.arrowScale or 1)

  arrow = frame:CreateTexture(nil, L["ARTWORK"])
  arrow:SetSize(56, 56)
  arrow:SetPoint("TOP", 0, 0)
  arrow:SetTexture(ns.FLAVOR == "forever" and "Interface\\Minimap\\MinimapArrow" or "Interface\\WorldMap\\WorldMapArrow")
  arrow:SetVertexColor(0.67, 0.83, 0.45)

  title = frame:CreateFontString(nil, L["OVERLAY"], L["GameFontNormal"])
  title:SetPoint("TOP", arrow, L["BOTTOM"], 0, 0)
  title:SetWidth(220)
  dist = frame:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlightSmall"])
  dist:SetPoint("TOP", title, L["BOTTOM"], 0, -2)
  dist:SetWidth(220)

  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, L["ANCHOR_BOTTOM"])
    GameTooltip:AddLine(L["Untamed arrow"], 1, 0.82, 0)
    if target then GameTooltip:AddLine(target.label, 1, 1, 1, true) end
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
    if d <= ARRIVE then
      arrow:SetRotation(0)
      arrow:SetVertexColor(1, 0.82, 0)
      dist:SetText("|cff40ff40You're here. Look around for it.|r")
      if not target.arrived then
        target.arrived = true
        PlaySound(SOUNDKIT and SOUNDKIT.MAP_PING or 3175)
        ns.Fire(L["ARROW_ARRIVED"], target)
      end
      return
    end
    target.arrived = false
    arrow:SetVertexColor(0.67, 0.83, 0.45)
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing and not ns.IsSecret(facing) then
      local bearing = math.atan2(-(target.east - pe), target.north - pn)
      arrow:SetRotation(bearing - facing)
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
  target = { mapID = mapID, x = x, y = y, label = label, npcId = npcId, cont = c, east = e, north = n }
  title:SetText(label)
  frame:Show()
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
