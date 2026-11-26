local ADDON, FLT = ...; FLT = FLT.Kit; if not FLT then return end

-- OneForAll Pad: OneForAll's map icons on OpenMap's controller view.
--
-- With the game's Gamepad UI on, OpenMap draws its own map over Blizzard's and makes Blizzard's
-- canvas see-through, so icons placed on the canvas are not seen. Placing them there also creates
-- frames inside the open map, which taints the game's controller navigation (the face buttons stop
-- working after the map closes). So while FLT.PadOwnsMap() is true, MapLandmarks.lua places nothing
-- on the canvas and this file hands the same icons to OpenMap instead: our own frames, made at
-- login under UIParent, listed in a HereBeDragons-style table that OpenMap reads (its PadView.lua
-- finds every "HereBeDragons...-Pins-2.0" library through LibStub). OpenMap places them, shows them
-- and calls their OnEnter / OnLeave when the controller cursor is on them, and pin.OnClick on a press.
-- Nothing of OpenMap's or Blizzard's is changed.

local PAD_LIB = "HereBeDragons-OneForAllPad-Pins-2.0"
local MAX = 700
local SHOW_CONTINENT = 2 -- HBD_PINS_WORLDMAP_SHOW_CONTINENT: shown from a continent's map too

local MP = {}
FLT.PadMap = MP

local function L(s) return FLT.L and FLT.L[s] or s end
local function Q(key) return FLT.QoL and FLT.QoL.Get(key) end
local function DB() return UntamedKitDB and type(UntamedKitDB.pad) == "table" and UntamedKitDB.pad or {} end
local function secret(v) return issecretvalue and issecretvalue(v) end

-- The game's Gamepad UI is on and OpenMap is there to show the icons (and the player has not turned this off)
function FLT.PadOwnsMap()
  if DB().mapOff then return false end
  if not _G.OpenMapAPI then return false end
  local ok, on = pcall(function() return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() end)
  return ok and on and true or false
end

---------------------------------------------------------------------------
-- Our own tooltip (the game's GameTooltip shown from addon code on the controller view taints it;
-- OpenMap does the same for Questie's icons). It takes the calls MapLandmarks' tooltip makes.
---------------------------------------------------------------------------
local tip
local function BuildTip()
  tip = CreateFrame("Frame", "UntamedKitPadMapTip", UIParent, "BackdropTemplate")
  tip:SetFrameStrata("TOOLTIP")
  tip:SetClampedToScreen(true)
  tip:EnableMouse(false)
  if tip.SetBackdrop then
    tip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    tip:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
  end
  tip.lines, tip.n = {}, 0
  local FrameShow = tip.Show
  function tip:SetOwner(owner) self.owner = owner; self.n = 0; for _, fs in ipairs(self.lines) do fs:Hide() end end
  function tip:AddLine(text, r, g, b, wrap)
    if text == nil or secret(text) then return end
    self.n = self.n + 1
    local fs = self.lines[self.n]
    if not fs then
      fs = self:CreateFontString(nil, "ARTWORK", self.n == 1 and "GameFontNormal" or "GameFontHighlightSmall")
      fs:SetJustifyH("LEFT")
      self.lines[self.n] = fs
    end
    fs:SetText(tostring(text))
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetWidth(0)
    fs:Show()
  end
  function tip:Show()
    local w, h = 0, 0
    for i = 1, self.n do
      local fs = self.lines[i]
      local sw = fs:GetStringWidth() or 0
      if sw > 260 then fs:SetWidth(260); sw = 260 end
      if sw > w then w = sw end
    end
    local y = -8
    for i = 1, self.n do
      local fs = self.lines[i]
      fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 10, y)
      local lh = fs:GetStringHeight() or 12
      y = y - lh - 2; h = h + lh + 2
    end
    self:SetSize(w + 20, h + 14)
    self:ClearAllPoints()
    local o = self.owner
    if o and o.GetCenter and o:GetCenter() then
      self:SetPoint("BOTTOMLEFT", o, "TOPRIGHT", 4, 4)
    else
      self:SetPoint("CENTER", UIParent, "CENTER")
    end
    FrameShow(self)
  end
  tip:Hide()
end

---------------------------------------------------------------------------
-- A press: what would open a OneForAll page waits until the map is closed (opening or closing
-- Blizzard's map from our code taints the controller UI)
---------------------------------------------------------------------------
local pending
local function OpenPending()
  local p = pending
  pending = nil
  if not p then return end
  if p.book then
    FLT:OpenPanel("books")
    if FLT.UI and FLT.UI.ShowBook then FLT.UI.ShowBook(p.book) end
  elseif p.dungeon then
    FLT:OpenPanel("dungeons")
    if FLT.UI and FLT.UI.OpenDungeon then FLT.UI.OpenDungeon(p.dungeon) end
  end
end

local function Press(pin)
  local e = pin.entry
  if not e then return end
  local UI = FLT.UI
  if e.book then
    pending = { book = e.book }
  elseif e.list and e.list[1] and not (UI and UI.IsTabVisible and not UI.IsTabVisible("dungeons")) then
    pending = { dungeon = e.list[1] }
  else
    return
  end
  if FLT.Msg then FLT.Msg(L("Opens in OneForAll when you close the map.")) end
end

---------------------------------------------------------------------------
-- The icons
---------------------------------------------------------------------------
local holder, lib
local frames = {}

local function Enter(self)
  local LM = FLT.MapLandmarks
  if not (self.entry and LM and LM._PadTip and tip) then return end
  local ok = pcall(LM._PadTip, self, tip)
  if not ok then tip:Hide() end
end
local function Leave() if tip then tip:Hide() end end

local function Frame(i)
  local f = frames[i]
  if f then return f end
  f = CreateFrame("Frame", nil, holder)
  f:SetSize(20, 20)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f:SetScript("OnEnter", Enter)
  f:SetScript("OnLeave", Leave)
  f.OnClick = Press
  f:Hide()
  frames[i] = f
  return f
end

local function SetIcon(f, kind, k)
  if f.kind == kind then return end
  f.kind = kind
  if k.atlas and f.tex.SetAtlas and pcall(f.tex.SetAtlas, f.tex, k.atlas) then return end
  f.tex:SetTexture(k.file or "Interface\\Minimap\\POIIcons")
  f.tex:SetTexCoord(0, 1, 0, 1)
end

local function Lib()
  if lib then return lib end
  if not (LibStub and LibStub.NewLibrary) then return end
  local ok, l = pcall(LibStub.NewLibrary, LibStub, PAD_LIB, 1)
  if not (ok and type(l) == "table") and LibStub.GetLibrary then
    local ok2, l2 = pcall(LibStub.GetLibrary, LibStub, PAD_LIB, true)
    l = ok2 and l2 or nil
  end
  if type(l) ~= "table" then return end
  l.worldmapPins = l.worldmapPins or {}
  lib = l
  return lib
end

local function Clear()
  if lib then wipe(lib.worldmapPins) end
  for _, f in ipairs(frames) do
    if f.entry then f.entry = nil; f:Hide() end
  end
  if tip then tip:Hide() end
end

-- Every landmark OneForAll would draw, on every map (OpenMap shows the whole world and only places
-- what is in view). Same rules as MapLandmarks' LM.Refresh.
function MP.Sync()
  if not holder then return end
  local LM = FLT.MapLandmarks
  if not (FLT.PadOwnsMap() and Q("mapLandmarks") and LM and LM._PadIndex and Lib()) then Clear(); return end
  local ok, byMap, KINDS = pcall(LM._PadIndex)
  if not (ok and type(byMap) == "table") then Clear(); return end
  wipe(lib.worldmapPins)
  local n = 0
  for mapID, list in pairs(byMap) do
    for _, e in ipairs(list) do
      local k = KINDS[e.kind]
      if k and Q(k.key) ~= false and (not e.book or FLT:GetBookState(e.book) == "missing") and n < MAX then
        n = n + 1
        local f = Frame(n)
        SetIcon(f, e.kind, k)
        f:SetSize(k.w * 0.75, k.h * 0.75)
        f.entry, f.UiMapID, f.x, f.y = e, mapID, e.x, e.y
        -- entrances and books from further out too (OpenMap shows other addons' icons only zoomed in to a zone,
        -- unless they ask to be on a continent's map); ships, flight masters and the rest when zoomed in
        lib.worldmapPins[f] = { uiMapID = mapID, worldMapShowFlag = (k.top or e.book) and SHOW_CONTINENT or 0 }
      end
    end
  end
  for i = n + 1, #frames do
    local f = frames[i]
    if f.entry then f.entry = nil; f:Hide() end
  end
end

---------------------------------------------------------------------------
-- Driver: sync when the map opens and when MapLandmarks would redraw (a switch, a book's state)
---------------------------------------------------------------------------
local mapShown
local function Tick(self, elapsed)
  local shown = WorldMapFrame and WorldMapFrame:IsShown() or false
  if shown ~= mapShown then
    mapShown = shown
    if shown then MP.Sync() elseif tip then tip:Hide() end
  end
  if pending and not shown and not InCombatLockdown() then OpenPending() end
end

-- now, before MapLandmarks hands LM.Refresh to its switches at login
do
  local LM = FLT.MapLandmarks
  if LM and LM.Refresh then hooksecurefunc(LM, "Refresh", function() if holder and FLT.PadOwnsMap() then MP.Sync() end end) end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  -- the shipped copy is called OneForAllPad: it and CurseForge's OneForAll share their saved settings and globals
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  if ADDON ~= "UntamedKit" and loaded and loaded("UntamedKit") and FLT.Msg then
    FLT.Msg("|cffff6060OneForAll and OneForAll Pad are both enabled. Turn one of them off in the AddOns list and reload.|r")
  end
  holder = CreateFrame("Frame", nil, UIParent)
  holder:Hide()
  BuildTip()
  -- made now, while the map is closed: every icon frame we may need
  for i = 1, MAX do Frame(i) end
  local driver = CreateFrame("Frame", nil, UIParent)
  driver:SetScript("OnUpdate", Tick)
end)

function MP.Status()
  local n = 0
  if lib then for _ in pairs(lib.worldmapPins) do n = n + 1 end end
  return FLT.PadOwnsMap(), n
end
