local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- The hunter display under your character:
--   range meter (Range.lua)
--   "Hawk!" warning: you're in a fight with a travel aspect on (Cheetah or Pack)
-- One anchor: /ut hud move | lock | reset | scale 1.2 | off | on.
-- Our own frames on UIParent (gamepad safe).
--
-- Gone on purpose (the game's own cooldown manager covers them, Nov 2026): the cooldown rows, the
-- Serpent Sting and Hunter's Mark timers, the hawk tracker, the pet watch, and the Food, aspect
-- and Pet reminders.
---------------------------------------------------------------------------

local DEFAULT_POS = { "CENTER", 0, -222 }   -- low enough to clear your character when zoomed in
local HAWK_ASPECT = { [13165] = true, [14318] = true, [14319] = true, [14320] = true, [14321] = true, [14322] = true, [25296] = true }
local TRAVEL_ASPECT = { [5118] = true, [13159] = true }                              -- Cheetah, Pack
local OTHER_ASPECTS = { [5118] = true, [13159] = true, [13163] = true, [20043] = true, [20190] = true, [13161] = true }

local hud, moving
local aspect        -- "hawk", "travel", "other" or nil (unknown / none)
local aspectID      -- the spell of the aspect that's on, when we know it

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end

local function Text(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local file = fs:GetFont()
  fs:SetFont(file or STANDARD_TEXT_FONT, size, "OUTLINE")
  return fs
end

local function SpellIcon(name)
  local t = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(name)
  return Plain(t) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Known(name)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
  if not info then return false end
  local id = Plain(info.spellID)
  local known = id and ns.SpellKnown(id)
  if known ~= nil then return known end
  return true
end

---------------------------------------------------------------------------
-- Anchor
---------------------------------------------------------------------------
local function Place()
  local p = ns.db.hudPos or DEFAULT_POS
  hud:ClearAllPoints()
  hud:SetPoint(p[1], UIParent, p[1], p[2], p[3])
  hud:SetScale(ns.db.hudScale or 1)
end

local function Build()
  hud = CreateFrame("Frame", "UntamedHUD", UIParent)
  hud:SetSize(220, 100)
  hud:SetFrameStrata("MEDIUM")
  hud:SetMovable(true)
  hud:EnableMouse(false)
  hud:RegisterForDrag("LeftButton")
  hud:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
  hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s = self:GetScale()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.db.hudPos = { "CENTER", cx - ux / s, cy - uy / s }
    Place()
  end)
  hud.box = hud:CreateTexture(nil, "BACKGROUND")
  hud.box:SetAllPoints()
  hud.box:SetColorTexture(0.2, 0.5, 1, 0.15)
  hud.box:Hide()
  hud.hint = Text(hud, 11)
  hud.hint:SetPoint("BOTTOM", hud, "TOP", 0, 2)
  hud.hint:SetText("|cffffd140" .. L["Drag me, then /ut hud lock"] .. "|r")
  hud.hint:Hide()

  hud.top = CreateFrame("Frame", nil, hud)          -- the range meter sits here
  hud.top:SetSize(170, 40)
  hud.top:SetPoint("TOP")

  -- the Hawk warning, under the range meter
  local w = CreateFrame("Frame", nil, hud)
  w:SetSize(30, 30)
  w:SetPoint("TOP", 0, -46)
  w.bg = w:CreateTexture(nil, "BACKGROUND")
  w.bg:SetAllPoints()
  w.bg:SetColorTexture(0, 0, 0, 0.8)
  w.icon = w:CreateTexture(nil, "ARTWORK")
  w.icon:SetPoint("TOPLEFT", 1, -1)
  w.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  w.icon:SetTexture(SpellIcon("Aspect of the Hawk"))
  w.label = Text(w, 11)
  w.label:SetPoint("TOP", w, "BOTTOM", 0, -1)
  w.label:SetText("|cffff5050" .. L["Hawk!"] .. "|r")
  w:Hide()
  hud.warn = w
  Place()
end

ns.HUD_Slot = function(which) return hud and rawget(hud, which) end
ns.HUD_Moving = function() return moving end

---------------------------------------------------------------------------
-- Which aspect is on
---------------------------------------------------------------------------
-- By name as well as by number: Forever's ranks don't all carry the old numbers.
local ASPECT_NAMES = { "Aspect of the Hawk", "Aspect of the Cheetah", "Aspect of the Pack", "Aspect of the Monkey",
  "Aspect of the Beast", "Aspect of the Wild" }
local KIND = { "hawk", "travel", "travel", "other", "other", "other" }
local seen = { casts = 0, hidden = 0 }   -- for /ut doctor

local function KindOf(spellID, name)
  if HAWK_ASPECT[spellID] or name == "Aspect of the Hawk" then return "hawk" end
  if TRAVEL_ASPECT[spellID] or name == "Aspect of the Cheetah" or name == "Aspect of the Pack" then return "travel" end
  return "other"
end

local function InFight()
  if InCombatLockdown and InCombatLockdown() then return true end
  local f = UnitAffectingCombat("player")
  return ns.IsSecret(f) or (f and true or false)
end

-- Read the aspect from your buffs. Only outside fights: in a fight the game answers "no such buff"
-- for everything, which would wipe what we learned from your casts.
local function ReadAspect()
  if InFight() then seen.read = "skipped (fight)" return end
  local byID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if not byID and not byName then return end
  local found, foundID
  -- the spell we saw you cast is the surest thing to look for
  if byID and aspectID then
    local ok, a = pcall(byID, aspectID)
    if not ok or ns.IsSecret(a) then seen.read = "hidden" return end
    if a then found, foundID = aspect, aspectID end
  end
  if not found and byName then
    for i, name in ipairs(ASPECT_NAMES) do
      local ok, a = pcall(byName, "player", name, "HELPFUL")
      if not ok or ns.IsSecret(a) then seen.read = "hidden" return end
      if a then found, foundID = KIND[i], Plain(a.spellId) break end
    end
  end
  if not found and byID then
    for _, set in ipairs({ HAWK_ASPECT, OTHER_ASPECTS }) do
      for id in pairs(set) do
        local ok, a = pcall(byID, id)
        if not ok or ns.IsSecret(a) then seen.read = "hidden" return end
        if a then found, foundID = KindOf(id), id break end
      end
      if found then break end
    end
  end
  seen.read = found or "none"
  aspect, aspectID = found, foundID
end

-- A spell you just cast: is it an aspect? By number first, then by its name.
local function CastAspect(spellID)
  seen.casts = seen.casts + 1
  if spellID == nil or ns.IsSecret(spellID) then seen.hidden = seen.hidden + 1 return end
  seen.last = spellID
  if HAWK_ASPECT[spellID] or OTHER_ASPECTS[spellID] then
    aspect, aspectID, seen.aspectCast = KindOf(spellID), spellID, spellID
    return
  end
  local ok, name = pcall(ns.SpellName, spellID)
  name = ok and Plain(name)
  if type(name) == "string" and name:find("^Aspect of the ") then
    aspect, aspectID, seen.aspectCast = KindOf(spellID, name), spellID, spellID
  end
end
ns.HUD_AspectSeen = function() return seen, aspect, aspectID end

---------------------------------------------------------------------------
-- Paint
---------------------------------------------------------------------------
local function Paint()
  if not hud then return end
  if ns.db.hud == false then hud:Hide() return end
  hud:Show()
  -- in a fight with Cheetah or Pack on: switch to Hawk (any hit dazes you in those)
  local warn = moving or (ns.db.hudAspect ~= false and aspect == "travel" and InFight() and Known("Aspect of the Hawk"))
  hud.warn:SetShown(warn and true or false)
end
ns.HUD_Paint = Paint

function ns.HUDCommand(arg)
  if not hud then return end
  if arg == "move" or arg == "lock" then
    moving = arg == "move" and not moving
    hud:EnableMouse(moving)
    hud.box:SetShown(moving)
    hud.hint:SetShown(moving)
    if moving then ns.Print(L["Drag the hunter display where you want it, then type /ut hud lock."]) end
    Paint()
    if ns.RangePaint then ns.RangePaint() end
  elseif arg == "reset" then
    ns.db.hudPos, ns.db.hudScale = nil, nil
    Place()
  elseif arg and arg:match("^scale [%d%.]+$") then
    local s = tonumber(arg:match("[%d%.]+$"))
    if s and s >= 0.5 and s <= 2 then ns.db.hudScale = s; Place() end
  elseif arg == "off" or arg == "on" then
    ns.db.hud = arg == "on"
    ns.Print(ns.db.hud and L["The hunter display is on."] or L["The hunter display is off (/ut hud on brings it back)."])
    Paint()
  else
    ns.Print(L["/ut hud move, lock, reset, scale 1.2, off, on"])
  end
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_LOGIN", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
      if select(2, UnitClass("player")) ~= "HUNTER" then ev:UnregisterAllEvents() return end
      Build()
      ReadAspect()
      Paint()
      return
    end
    if not hud then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if unit ~= "player" then return end
      CastAspect(spellID)
    elseif event == "UNIT_AURA" then
      if unit ~= "player" then return end
      ReadAspect()
    elseif event == "PLAYER_REGEN_ENABLED" then
      ReadAspect()
    end
    -- nothing here needs a timer any more: the warning only changes on these events
    local ok, err = pcall(Paint)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end)
end

-- for tests
ns.HUD_Aspect = function() return aspect end
