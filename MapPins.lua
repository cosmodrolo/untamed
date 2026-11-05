local _, ns = ...
local L = ns.L

-- World map pins.
--   focus: set by clicking a rank, beast or planner stop (bigger gold pins)
--   auto:  every beast that teaches something your pet still needs (small pins)
--   stable/flight masters for the focused beasts are shown too.
local focus = nil   -- { npcs = { [npcId] = true }, label = "..." }
ns.PinSources = ns.PinSources or {}
local provider
local AUTO_CAP = 12

---------------------------------------------------------------------------
-- Pin mixin (no OnLoad/OnEnter scripts in XML: the map canvas wires those)
---------------------------------------------------------------------------
UntamedPinMixin = CreateFromMixins(MapCanvasPinMixin)

function UntamedPinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
  self:SetScalingLimits(1, 1.0, 1.25)
end

function UntamedPinMixin:OnAcquired(info)
  self.info = info
  self:SetPosition(info.x / 100, info.y / 100)
  if info.point then
    self:SetSize(info.size or 14, info.size or 14)
    self.Icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.Border:SetVertexColor(unpack(info.border or { 0.64, 0.21, 0.93, 1 }))
    return
  end
  if info.service then
    self:SetSize(14, 14)
    self.Icon:SetTexture(info.service == "S" and "Interface\\Icons\\Ability_Hunter_BeastCall" or "Interface\\Icons\\Ability_Mount_Gryphon_01")
    self.Border:SetVertexColor(0.3, 0.6, 1, 1)
    return
  end
  local size = info.focus and 16 or 11
  self:SetSize(size, size)
  self.Icon:SetTexture("Interface\\Icons\\" .. (ns.FamilyIcons[info.beast[4]] or "Ability_Hunter_BeastTaming"))
  if info.focus then self.Border:SetVertexColor(1, 0.82, 0, 1) else self.Border:SetVertexColor(0, 0, 0, 0.9) end
end

function UntamedPinMixin:OnMouseEnter()
  local info = self.info
  if not info then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if info.point then
    for i, line in ipairs(info.lines or { info.name }) do
      if i == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:AddLine(L["Click: navigate here"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
    return
  end
  if info.service then
    GameTooltip:AddLine(info.name, 1, 0.82, 0)
    GameTooltip:AddLine(info.service == "S" and L["Stable Master"] or L["Flight Master"], 1, 1, 1)
    GameTooltip:AddLine(L["Click: navigate here"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
    return
  end
  local b = info.beast
  GameTooltip:AddLine(b[1], 1, 0.82, 0)
  GameTooltip:AddLine(string.format("Level %s %s", ns.LevelText(b), b[4]), 1, 1, 1)
  if b[8] then GameTooltip:AddLine(L["Inside "] .. b[8] .. " (entrance shown)", 1, 0.5, 0.25) end
  if #b[6] > 0 then GameTooltip:AddLine(L["Teaches: "] .. ns.TeachesText(b), 0.67, 0.83, 0.45, true) end
  if info.need and #info.need > 0 then
    GameTooltip:AddLine(L["Your pet needs: "] .. table.concat(info.need, ", "), 0.4, 1, 0.4, true)
  end
  if b[2] > UnitLevel("player") then GameTooltip:AddLine(L["Too high for you to tame right now"], 1, 0.3, 0.3) end
  GameTooltip:AddLine(L["Click: navigate here"], 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

function UntamedPinMixin:OnMouseLeave() GameTooltip:Hide() end

function UntamedPinMixin:OnClick(button)
  local info = self.info
  if not info or button ~= "LeftButton" then return end
  local mapID = self:GetMap():GetMapID()
  if info.point or info.service then
    ns.Arrow_Set(mapID, info.x, info.y, info.name, nil)
  else
    ns.Arrow_Set(mapID, info.x, info.y, info.beast[1], info.npcId)
  end
end

---------------------------------------------------------------------------
-- Data provider
---------------------------------------------------------------------------
local function AddBeastPins(map, mapID, npcId, isFocus, need, cap)
  local b = ns.Beasts[npcId]
  local pts = b and b[7][mapID]
  if not pts then return end
  local n = #pts / 2
  local step = (cap and n > cap) and (n / cap) or 1
  local i = 0
  while i < n do
    local idx = math.floor(i) * 2 + 1
    map:AcquirePin("UntamedPinTemplate", { x = pts[idx], y = pts[idx + 1], beast = b, npcId = npcId, focus = isFocus, need = need })
    i = i + step
  end
end

local function AddServicePins(map, mapID)
  if not focus then return end
  local shown = {}
  for npcId in pairs(focus.npcs) do
    local b = ns.Beasts[npcId]
    for m, pts in pairs(b and b[7] or {}) do
      if pts[1] then
        for _, kind in ipairs({ "S", "F" }) do
          local s = ns.NearestService(kind, m, pts[1], pts[2])
          if s and s[4] == mapID and not shown[s] then
            shown[s] = true
            map:AcquirePin("UntamedPinTemplate", { x = s[5], y = s[6], service = kind, name = s[2] })
          end
        end
      end
    end
  end
end

-- Adding pins in combat is blocked on Forever (the map canvas calls a protected function), so pin
-- refreshes wait until combat ends.
local pendingRefresh
local function RefreshAll(self)
  if InCombatLockdown and InCombatLockdown() then pendingRefresh = true return end
  pendingRefresh = false
  local map = self:GetMap()
  map:RemoveAllPinsByTemplate("UntamedPinTemplate")
  local mapID = map:GetMapID()
  if not mapID then return end
  local need = ns.NeededSet() or {}
  if focus then
    for npcId in pairs(focus.npcs) do AddBeastPins(map, mapID, npcId, true, need[npcId], nil) end
    AddServicePins(map, mapID)
  end
  -- Other features add their own pins (wishlist sources, ...): each source returns
  -- { {map, x, y, name, icon, lines, border}, ... }
  for _, src in ipairs(ns.PinSources) do
    local ok, pts = pcall(src)
    if ok and pts then
      for _, p in ipairs(pts) do
        if p.map == mapID and p.x and p.x ~= 0 then
          map:AcquirePin("UntamedPinTemplate", { point = true, x = p.x, y = p.y, name = p.name, icon = p.icon, lines = p.lines, border = p.border })
        end
      end
    end
  end
  if ns.db.autoPins then
    for npcId, list in pairs(need) do
      if not (focus and focus.npcs[npcId]) then AddBeastPins(map, mapID, npcId, false, list, AUTO_CAP) end
    end
  end
end

ns.On("LOGIN", function()
  if not WorldMapFrame or not WorldMapFrame.AddDataProvider then return end
  provider = CreateFromMixins(MapCanvasDataProviderMixin)
  provider.RefreshAllData = RefreshAll
  provider.RemoveAllData = function(self) self:GetMap():RemoveAllPinsByTemplate("UntamedPinTemplate") end
  WorldMapFrame:AddDataProvider(provider)
end)

function ns.Pins_Refresh()
  if provider and provider:GetMap() then provider:RefreshAllData() end
end
do
  local f = CreateFrame("Frame")
  pcall(f.RegisterEvent, f, "PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function() if pendingRefresh then ns.Pins_Refresh() end end)
end
ns.On("REFRESH", ns.Pins_Refresh)

function ns.Pins_Clear()
  focus = nil
  ns.Refresh()
end

function ns.Pins_GetFocusLabel() return focus and focus.label end
function ns.Pins_GetFocus() return focus end

local function BestZone(npcList)
  local here = C_Map.GetBestMapForUnit("player")
  local counts = {}
  for _, npcId in ipairs(npcList) do
    for mapID, pts in pairs(ns.Beasts[npcId][7]) do counts[mapID] = (counts[mapID] or 0) + #pts end
  end
  if here and counts[here] then return here end
  local best, n = nil, 0
  for mapID, c in pairs(counts) do if c > n then best, n = mapID, c end end
  return best
end

function ns.OpenMapTo(mapID)
  if not mapID then return end
  if InCombatLockdown() then ns.Print(L["Pins set. Open your map after combat."]) return end
  if not WorldMapFrame:IsShown() then ToggleWorldMap() end
  WorldMapFrame:SetMapID(mapID)
end

function ns.Pins_Focus(npcList, label, openMap)
  focus = { npcs = {}, label = label }
  for _, id in ipairs(npcList) do focus.npcs[id] = true end
  if openMap then
    local mapID = BestZone(npcList)
    if mapID then ns.OpenMapTo(mapID) else ns.Print(L["No known spawn location for "] .. label .. ".") end
  end
  ns.Refresh()
end

-- Optional TomTom waypoint at the nearest spawn.
function ns.Waypoint(npcId)
  local b = ns.Beasts[npcId]
  if not (TomTom and TomTom.AddWaypoint) then ns.Navigate(npcId) return end
  local mapID, x, y = ns.NearestSpawn(npcId)
  if mapID then TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = b[1] }) end
end
