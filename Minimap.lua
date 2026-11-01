local _, ns = ...

-- Minimap pins for nearby beasts your pet needs (plus the focused ones),
-- and the minimap launcher button.

local DIAMETER = {
  outdoor = { [0] = 466 + 2 / 3, [1] = 400, [2] = 333 + 1 / 3, [3] = 266 + 2 / 3, [4] = 200, [5] = 133 + 1 / 3 },
  indoor = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
}
local MAX_PINS = 40
local pins = {}
local candidates = {}   -- { {cont, east, north, beast, npcId, focus}, ... } for the current zone
local candidateMap, candidateStamp

local function GetPin(i)
  local p = pins[i]
  if p then return p end
  p = CreateFrame("Frame", nil, Minimap)
  p:SetSize(12, 12)
  p:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  p.border = p:CreateTexture(nil, "BACKGROUND")
  p.border:SetPoint("TOPLEFT", -1, 1); p.border:SetPoint("BOTTOMRIGHT", 1, -1)
  p.border:SetColorTexture(0, 0, 0, 0.9)
  p.icon = p:CreateTexture(nil, "ARTWORK")
  p.icon:SetAllPoints()
  p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  p:EnableMouse(true)
  p:SetScript("OnEnter", function(self)
    local b = self.beast
    if not b then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(b[1], 1, 0.82, 0)
    GameTooltip:AddLine("Level " .. ns.LevelText(b) .. " " .. b[4], 1, 1, 1)
    if #b[6] > 0 then GameTooltip:AddLine("Teaches: " .. ns.TeachesText(b), 0.67, 0.83, 0.45, true) end
    GameTooltip:Show()
  end)
  p:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pins[i] = p
  return p
end

local function RebuildCandidates(mapID)
  wipe(candidates)
  candidateMap = mapID
  local need = ns.db.minimapPins and ns.NeededSet() or {}
  local focus = ns.Pins_GetFocus and ns.Pins_GetFocus()
  local list = {}
  for npcId in pairs(need) do list[npcId] = false end
  if focus then for npcId in pairs(focus.npcs) do list[npcId] = true end end
  for npcId, isFocus in pairs(list) do
    local b = ns.Beasts[npcId]
    local pts = b and b[7][mapID]
    if pts then
      for i = 1, #pts, 2 do
        local c, e, n = ns.ToWorld(mapID, pts[i], pts[i + 1])
        if c then candidates[#candidates + 1] = { c, e, n, b, npcId, isFocus } end
      end
    end
  end
  candidateStamp = GetTime()
end
ns.On("REFRESH", function() candidateMap = nil end)

local function Update()
  local shown = 0
  if ns.db.minimapPins or (ns.Pins_GetFocus and ns.Pins_GetFocus()) then
    local pc, pe, pn, mapID = ns.PlayerWorld()
    if pc then
      if mapID ~= candidateMap or GetTime() - (candidateStamp or 0) > 10 then RebuildCandidates(mapID) end
      local zoom = Minimap:GetZoom() or 0
      local diam = ((IsIndoors and IsIndoors()) and DIAMETER.indoor or DIAMETER.outdoor)[zoom] or 466
      local radiusYd = diam / 2
      local radiusPx = Minimap:GetWidth() / 2
      local rotate = ((C_CVar and C_CVar.GetCVar) or GetCVar)("rotateMinimap") == "1"
      local facing = rotate and GetPlayerFacing and GetPlayerFacing() or 0
      if ns.IsSecret(facing) then facing = 0 end
      local cosF, sinF = math.cos(facing), math.sin(facing)
      for _, c in ipairs(candidates) do
        if shown >= MAX_PINS then break end
        if c[1] == pc then
          local x, y = c[2] - pe, c[3] - pn   -- east, north (yards)
          if x * x + y * y < (radiusYd * 0.92) ^ 2 then
            if rotate then x, y = x * cosF + y * sinF, -x * sinF + y * cosF end
            shown = shown + 1
            local p = GetPin(shown)
            p.beast = c[4]
            p.icon:SetTexture("Interface\\Icons\\" .. (ns.FamilyIcons[c[4][4]] or "Ability_Hunter_BeastTaming"))
            p.border:SetColorTexture(c[6] and 1 or 0, c[6] and 0.82 or 0, 0, 0.9)
            p:ClearAllPoints()
            p:SetPoint("CENTER", Minimap, "CENTER", x / radiusYd * radiusPx, y / radiusYd * radiusPx)
            p:Show()
          end
        end
      end
    end
  end
  for i = shown + 1, #pins do pins[i]:Hide() end
end

---------------------------------------------------------------------------
-- Launcher button
---------------------------------------------------------------------------
local mm
local function UpdateButtonPos()
  local a = math.rad(ns.db.minimapAngle or 200)
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

ns.On("MINIMAP_TOGGLE", function()
  if ns.usingLDBIcon then
    if mm then mm:Hide() end
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
      ns.db.ldbIcon.hide = not ns.db.showMinimap
      if ns.db.showMinimap then icon:Show("Untamed") else icon:Hide("Untamed") end
    end
  elseif mm then
    mm:SetShown(ns.db.showMinimap and not ns.usingLDBIcon)
  end
end)

ns.On("LOGIN", function()
  mm = CreateFrame("Button", "UntamedMinimapButton", Minimap)
  mm:SetSize(31, 31)
  mm:SetFrameStrata("MEDIUM")
  mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mm:RegisterForDrag("LeftButton")
  local icon = mm:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture("Interface\\AddOns\\Untamed\\Media\\MinimapIcon")
  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.ZoneAlert(true) else ns.UI_Toggle() end
  end)
  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      UpdateButtonPos()
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Untamed", 1, 0.82, 0)
    GameTooltip:AddLine("Left-click: open window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: check this zone", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 1, 1, 1)
    GameTooltip:Show()
  end)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdateButtonPos()
  mm:SetShown(ns.db.showMinimap and not ns.usingLDBIcon)

  local ticker = CreateFrame("Frame")
  local t = 0
  ticker:SetScript("OnUpdate", function(_, e)
    t = t + e
    if t < 0.1 then return end
    t = 0
    Update()
  end)
end)
