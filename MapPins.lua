local _, ns = ...
local L = ns.L

-- World map pins.
--   focus: set by picking a rank, beast or planner stop (bigger gold pins)
--   auto:  every beast that teaches something your pet still needs (small pins)
--   stable/flight masters for the focused beasts are shown too, plus other features' points.
--
-- Gamepad safety (WoW Forever's controller UI). Blizzard's map navigation rebuilds itself inside
-- whatever code creates a frame in the open map, and a map closed in that state kills the face
-- buttons until /reload (GamepadGuard caught Untamed doing this through its old data provider).
-- So, like ForeverMapPins:
--  * the only frame inside the world map is one overlay, made at login while the map is closed;
--  * pins are textures, never frames: no CreateFrame while the map is open, nothing navigable;
--  * no data providers, hooks or callbacks on the map, and nothing written onto Blizzard frames;
--    map changes are found by polling while the map is visible;
--  * on a controller Untamed never changes the map's zone itself.
local focus = nil   -- { npcs = { [npcId] = true }, label = "..." }
ns.PinSources = ns.PinSources or {}
local AUTO_CAP = 12
local REFRESH_THROTTLE = 0.5
local FALLBACK_OVERLAY_LEVEL = 2100

local overlay, canvas, tip
local pins, used = {}, 0      -- pool of { icon, border, x, y, size, info }
local view = {}               -- what is drawn: map, canvas size and scale
local dirty, lastRefresh = true, 0

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function AcquirePin()
  used = used + 1
  local p = pins[used]
  if not p then
    p = { border = overlay:CreateTexture(nil, "ARTWORK", nil, 1), icon = overlay:CreateTexture(nil, "ARTWORK", nil, 2) }
    p.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pins[used] = p
  end
  return p
end

local function AddPin(info, size, iconPath, r, g, b, a)
  local p = AcquirePin()
  p.x, p.y, p.size, p.info = info.x, info.y, size, info
  p.icon:SetTexture(iconPath)
  p.border:SetVertexColor(r, g, b, a or 1)
  -- Focused pins draw above the small automatic ones.
  local layer = info.focus and 5 or (info.beast and 1 or 3)
  p.border:SetDrawLayer("ARTWORK", layer); p.icon:SetDrawLayer("ARTWORK", layer + 1)
  p.icon:Show(); p.border:Show()
end

local function Layout()
  local width, height, scale = canvas:GetWidth(), canvas:GetHeight(), canvas:GetScale()
  if not width or width <= 0 or not scale or scale <= 0 then return end
  for i = 1, used do
    local p = pins[i]
    local s = p.size / scale                      -- the same size on screen at any zoom
    local x, y = p.x / 100 * width, -p.y / 100 * height
    p.icon:ClearAllPoints(); p.icon:SetPoint("CENTER", overlay, "TOPLEFT", x, y); p.icon:SetSize(s, s)
    local e = 1.5 / scale
    p.border:ClearAllPoints(); p.border:SetPoint("CENTER", overlay, "TOPLEFT", x, y); p.border:SetSize(s + e * 2, s + e * 2)
  end
  view.width, view.height, view.scale = width, height, scale
end

local function AddBeastPins(mapID, npcId, isFocus, need, cap)
  local b = ns.Beasts[npcId]
  local pts = b and b[7][mapID]
  if not pts then return end
  local n = #pts / 2
  local step = (cap and n > cap) and (n / cap) or 1
  local i = 0
  local icon = "Interface\\Icons\\" .. (ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming")
  while i < n do
    local idx = math.floor(i) * 2 + 1
    local info = { x = pts[idx], y = pts[idx + 1], beast = b, npcId = npcId, focus = isFocus, need = need }
    if isFocus then AddPin(info, 16, icon, 1, 0.82, 0) else AddPin(info, 11, icon, 0, 0, 0, 0.9) end
    i = i + step
  end
end

local function AddServicePins(mapID)
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
            AddPin({ x = s[5], y = s[6], service = kind, name = s[2] }, 14,
              kind == "S" and "Interface\\Icons\\Ability_Hunter_BeastCall" or "Interface\\Icons\\Ability_Mount_Gryphon_01", 0.3, 0.6, 1)
          end
        end
      end
    end
  end
end

local function Refresh()
  used = 0
  local mapID = WorldMapFrame:GetMapID()
  if mapID then
    local need = ns.NeededSet() or {}
    if focus then
      for npcId in pairs(focus.npcs) do AddBeastPins(mapID, npcId, true, need[npcId], nil) end
      AddServicePins(mapID)
    end
    -- Other features add their own points (wishlist sources, ...): { {map, x, y, name, icon, lines, border}, ... }
    for _, src in ipairs(ns.PinSources) do
      local ok, pts = pcall(src)
      if ok and pts then
        for _, p in ipairs(pts) do
          if p.map == mapID and p.x and p.x ~= 0 then
            local c = p.border or { 0.64, 0.21, 0.93, 1 }
            AddPin({ point = true, x = p.x, y = p.y, name = p.name, lines = p.lines }, p.size or 14,
              p.icon or "Interface\\Icons\\INV_Misc_QuestionMark", c[1], c[2], c[3], c[4])
          end
        end
      end
    end
    if ns.db.autoPins then
      for npcId, list in pairs(need) do
        if not (focus and focus.npcs[npcId]) then AddBeastPins(mapID, npcId, false, list, AUTO_CAP) end
      end
    end
  end
  for i = used + 1, #pins do pins[i].icon:Hide(); pins[i].border:Hide() end
  view.mapID, dirty, lastRefresh = mapID, false, GetTime()
  Layout()
end

---------------------------------------------------------------------------
-- Info box for the pin under the controller crosshair (or the mouse)
---------------------------------------------------------------------------
local PICK_RADIUS = 14

local function CursorScreenPosition()
  local sc = _G.SoftCursor
  if sc and sc:IsShown() then
    local x, y = sc:GetCenter()
    if x then local s = sc:GetEffectiveScale(); return x * s, y * s end
  end
  if WorldMapFrame.ScrollContainer:IsMouseOver() then return GetCursorPosition() end
end

local function PickPin()
  local cx, cy = CursorScreenPosition()
  if not cx then return nil end
  local radius = PICK_RADIUS * UIParent:GetEffectiveScale()
  local best, bestD = nil, radius * radius
  for i = 1, used do
    local x, y = pins[i].icon:GetCenter()
    if x then
      local s = pins[i].icon:GetEffectiveScale()
      local dx, dy = x * s - cx, y * s - cy
      local d = dx * dx + dy * dy
      if d < bestD then best, bestD = pins[i], d end
    end
  end
  return best, cx, cy
end

local function Describe(info)
  local out = {}
  local function add(text, r, g, b) out[#out + 1] = { text, r or 1, g or 1, b or 1 } end
  if info.point then
    for i, line in ipairs(info.lines or { info.name }) do if i == 1 then add(line, 1, 0.82, 0) else add(line) end end
  elseif info.service then
    add(info.name, 1, 0.82, 0)
    add(info.service == "S" and L["Stable Master"] or L["Flight Master"])
  else
    local b = info.beast
    add(b[1], 1, 0.82, 0)
    add(string.format("Level %s %s", ns.LevelText(b), b[4]))
    if b[8] then add(L["Inside "] .. b[8] .. " (entrance shown)", 1, 0.5, 0.25) end
    if #b[6] > 0 then add(L["Teaches: "] .. ns.TeachesText(b), 0.67, 0.83, 0.45) end
    if info.need and #info.need > 0 then add(L["Your pet needs: "] .. table.concat(info.need, ", "), 0.4, 1, 0.4) end
    if b[2] > UnitLevel("player") then add(L["Too high for you to tame right now"], 1, 0.3, 0.3) end
  end
  return out
end

local tipLines = {}
local shownInfo
local function UpdateTip()
  local pin, cx, cy = PickPin()
  if not pin then tip:Hide(); shownInfo = nil; return end
  if pin.info ~= shownInfo then
    shownInfo = pin.info
    local rows, w, h = Describe(pin.info), 0, 8
    for i, row in ipairs(rows) do
      local fs = tipLines[i]
      if not fs then
        fs = tip:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormal" or "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(true); fs:SetWidth(240)
        tipLines[i] = fs
      end
      fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 8, -h)
      fs:SetText(row[1]); fs:SetTextColor(row[2], row[3], row[4]); fs:Show()
      w = math.max(w, math.min(240, fs:GetStringWidth() or 0)); h = h + (fs:GetStringHeight() or 12) + 2
    end
    for i = #rows + 1, #tipLines do tipLines[i]:Hide() end
    tip:SetSize(w + 16, h + 6)
  end
  local s = UIParent:GetEffectiveScale()
  tip:ClearAllPoints()
  tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cx / s + 18, cy / s + 12)
  tip:Show()
end

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local function OnUpdate()
  local mapID = WorldMapFrame:GetMapID()
  if mapID ~= view.mapID or (dirty and GetTime() - lastRefresh >= REFRESH_THROTTLE) then
    Refresh()
  elseif canvas:GetWidth() ~= view.width or canvas:GetHeight() ~= view.height or canvas:GetScale() ~= view.scale then
    Layout()
  end
  UpdateTip()
end

-- Blizzard map pins use absolute frame levels from 2000 up; sit just above the area layers (explored
-- areas, fog, quest blobs) so outdoor zones don't cover the pins. Plain table reads only.
local function OverlayFrameLevel()
  local m = WorldMapFrame.pinFrameLevelsManager
  local defs = type(m) == "table" and m.definitions
  local d = type(defs) == "table" and defs.PIN_FRAME_LEVEL_MAP_HIGHLIGHT
  if type(d) == "table" and type(d.startLevel) == "number" then return d.startLevel + (d.range or 1) end
  return FALLBACK_OVERLAY_LEVEL
end

-- Must run while the world map is closed.
local function Init()
  if overlay then return true end
  canvas = WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
  if not canvas or WorldMapFrame:IsShown() then return false end
  overlay = CreateFrame("Frame", nil, canvas)
  overlay:SetAllPoints(canvas)
  overlay:SetFrameLevel(OverlayFrameLevel())
  overlay:EnableMouse(false)
  overlay:SetScript("OnUpdate", OnUpdate)          -- only runs while the map is shown
  overlay:SetScript("OnHide", function() if tip then tip:Hide() end end)
  tip = CreateFrame("Frame", "UntamedMapInfo", UIParent, "BackdropTemplate")
  tip:SetFrameStrata("TOOLTIP")
  tip:EnableMouse(false)
  if tip.SetBackdrop then
    tip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tip:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
  end
  tip:Hide()
  return true
end

ns.On("LOGIN", function()
  if not Init() then
    -- The map was open at login: try again once it's closed.
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self) if Init() then self:SetScript("OnUpdate", nil) end end)
  end
end)

function ns.Pins_Refresh() dirty = true end
ns.On("REFRESH", ns.Pins_Refresh)

-- For tests and /ut debugging: the pins currently drawn.
function ns.Pins_Drawn()
  local out = {}
  for i = 1, used do out[i] = pins[i].info end
  return out
end

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

local function GamepadUI()
  return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() or false
end
local function ZoneName(mapID)
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or ""
end

-- With the controller UI on, opening the map or changing its zone from addon code runs Blizzard's
-- map navigation inside Untamed's code, so Untamed only sets the pins and tells you where to look.
function ns.OpenMapTo(mapID)
  if not mapID then return end
  if GamepadUI() then
    ns.Print(L["Pins set. Open your map to "] .. ZoneName(mapID) .. ".")
    return
  end
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
