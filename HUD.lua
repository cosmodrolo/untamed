local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- The hunter display under your character (replaces the ForeverAuras hunter set), top to bottom:
--   range meter and pet watch (Range.lua)
--   Serpent Sting timer | hawk tracker (Hawks.lua) | Hunter's Mark       reminders (only when missing)
--   fight cooldowns: Summon Hawk, Aimed Shot, Multi-Shot, Rapid Fire, Bestial Wrath, Concussive Shot
--   escapes: Feign Death, Frost Trap, Freezing Trap, Disengage
-- Only spells you know are shown. Cooldowns use the game's own timers (they work with Forever's
-- hidden combat numbers); the Sting and Mark timers start when you cast them, and their length is
-- read from the debuff once, outside combat. One anchor: /ut hud move | lock | reset | scale 1.2 | off | on.
-- Our own frames on UIParent (gamepad safe).
---------------------------------------------------------------------------

local DEFAULT_POS = { "CENTER", 0, -222 }   -- low enough to clear your character when zoomed in
local ICON, SMALL = 34, 30

local COOLDOWNS = { "Summon Hawk", "Aimed Shot", "Multi-Shot", "Rapid Fire", "Bestial Wrath", "Concussive Shot" }
local ESCAPES = { "Feign Death", "Frost Trap", "Freezing Trap", "Disengage" }
local STING_IDS = { [1978] = true, [13549] = true, [13550] = true, [13551] = true, [13552] = true, [13553] = true, [13554] = true, [13555] = true }
local MARK_IDS = { [1130] = true, [14323] = true, [14324] = true, [14325] = true }
local HAWK_ASPECT = { [13165] = true, [14318] = true, [14319] = true, [14320] = true, [14321] = true, [14322] = true }
local OTHER_ASPECTS = { [5118] = true, [13159] = true, [13163] = true, [20043] = true, [20190] = true, [13161] = true }
local DEFAULT_DUR = { sting = 15, mark = 120 }

local hud, moving
local timers = {}   -- sting / mark: { ends, dur, guid }
local aspect        -- "hawk", "other" or nil (unknown / none)

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end
local function Bool(v, hidden) if ns.IsSecret(v) then return hidden end return v and true or false end

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

local function Icon(parent, size, name)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(size, size)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0, 0, 0, 0.8)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if name then b.icon:SetTexture(SpellIcon(name)) end
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  b.cd:SetDrawEdge(false)
  b.cd:SetHideCountdownNumbers(false)
  b.spell = name
  return b
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
  hud:SetSize(300, 200)
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

  -- slots the other parts sit in
  hud.top = CreateFrame("Frame", nil, hud)          -- range meter + pet line
  hud.top:SetSize(170, 52)
  hud.top:SetPoint("TOP")
  hud.mid = CreateFrame("Frame", nil, hud)          -- sting | hawks | mark
  hud.mid:SetSize(220, 50)
  hud.mid:SetPoint("TOP", 0, -58)

  hud.sting = Icon(hud.mid, ICON, "Serpent Sting")
  hud.sting:SetPoint("LEFT", 0, 4)
  hud.sting.cd:SetReverse(true)
  hud.mark = Icon(hud.mid, ICON, "Hunter's Mark")
  hud.mark:SetPoint("RIGHT", 0, 4)
  hud.mark.cd:SetReverse(true)
  hud.markWarn = Text(hud.mark, 18)
  hud.markWarn:SetPoint("CENTER")
  hud.markWarn:SetText("|cffff5050!|r")

  hud.rows = {}
  for i, list in ipairs({ COOLDOWNS, ESCAPES }) do
    local row = CreateFrame("Frame", nil, hud)
    row:SetSize(6 * (SMALL + 4), SMALL)
    row:SetPoint("TOP", 0, -114 - (i - 1) * (SMALL + 6))
    row.icons = {}
    for _, name in ipairs(list) do row.icons[#row.icons + 1] = Icon(row, SMALL, name) end
    hud.rows[i] = row
  end

  -- reminders, right of the timers: Food (out of combat), Aspect of the Hawk (in a fight), Pet
  hud.remind = CreateFrame("Frame", nil, hud)
  hud.remind:SetSize(3 * 32, 28)
  hud.remind:SetPoint("LEFT", hud.mid, "RIGHT", 14, 4)
  hud.remind.icons = {}
  for i, r in ipairs({ { "food", "Interface\\Icons\\INV_Misc_Food_14", L["Food"] },
                       { "aspect", nil, L["Aspect"] }, { "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", L["Pet"] } }) do
    local b = Icon(hud.remind, 28, r[2] == nil and "Aspect of the Hawk" or nil)
    if r[2] then b.icon:SetTexture(r[2]) end
    b.key = r[1]
    b.label = Text(b, 10)
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.label:SetText("|cffff9c40" .. r[3] .. "|r")
    b:Hide()
    hud.remind.icons[i] = b
  end
  Place()
end

ns.HUD_Slot = function(which) return hud and hud[which] end
ns.HUD_Moving = function() return moving end

---------------------------------------------------------------------------
-- Cooldown rows (only the spells you know)
---------------------------------------------------------------------------
local function LayoutRows()
  for _, row in ipairs(hud.rows) do
    local shown = {}
    for _, b in ipairs(row.icons) do
      if Known(b.spell) then
        b.icon:SetTexture(SpellIcon(b.spell))
        shown[#shown + 1] = b
      else
        b:Hide()
      end
    end
    local w = #shown * (SMALL + 4) - 4
    for i, b in ipairs(shown) do
      b:ClearAllPoints()
      b:SetPoint("LEFT", row, "CENTER", -w / 2 + (i - 1) * (SMALL + 4), 0)
      b:Show()
    end
    row.shown = shown
  end
end

local function SetCooldown(b)
  local done
  if C_Spell and C_Spell.GetSpellCooldownDuration then
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, b.spell, true)
    if ok and dur then
      done = pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur, true)
      if done then
        local okz, zero = pcall(dur.IsZero, dur)
        if okz and zero ~= nil and not ns.IsSecret(zero) then b.icon:SetDesaturated(not zero) end
      end
    end
  end
  if not done and C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, b.spell)
    local start, dur = ok and info and Plain(info.startTime), ok and info and Plain(info.duration)
    if start and dur and dur > 1.5 then
      b.cd:SetCooldown(start, dur)
      b.icon:SetDesaturated(true)
    elseif start then
      b.cd:Clear()
      b.icon:SetDesaturated(false)
    end
  end
end

local function UpdateCooldowns()
  if not hud then return end
  for _, row in ipairs(hud.rows) do
    for _, b in ipairs(row.shown or {}) do SetCooldown(b) end
  end
end

---------------------------------------------------------------------------
-- Serpent Sting and Hunter's Mark: started by your casts
---------------------------------------------------------------------------
local function TargetKey()
  local g = UnitGUID and UnitGUID("target")
  return Plain(g) or "target"
end

-- the debuff's real length, read once outside combat (it can differ from the default)
local function LearnDuration(which, name)
  if InCombatLockdown() or not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return end
  local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", name, "HARMFUL|PLAYER")
  local d = ok and aura and Plain(aura.duration)
  if d and d > 0 then
    ns.db.hudDur = ns.db.hudDur or {}
    ns.db.hudDur[which] = d
    local t = timers[which]
    local exp = Plain(aura.expirationTime)
    if t and exp then t.ends, t.dur = exp, d end
  end
end

local function StartTimer(which, name)
  local d = (ns.db.hudDur and ns.db.hudDur[which]) or DEFAULT_DUR[which]
  timers[which] = { ends = GetTime() + d, dur = d, guid = TargetKey() }
  C_Timer.After(0.3, function() LearnDuration(which, name) end)
end

local function TimerFor(which)
  local t = timers[which]
  if not t then return nil end
  if t.ends <= GetTime() then timers[which] = nil return nil end
  if t.guid ~= TargetKey() then return nil end
  return t
end

local function PaintTimer(b, which, alertWhenMissing)
  if not Known(b.spell) then b:Hide() return end
  b:Show()
  local t = TimerFor(which)
  if b.ends ~= (t and t.ends) then
    b.ends = t and t.ends
    if t then b.cd:SetCooldown(t.ends - t.dur, t.dur) else b.cd:Clear() end
  end
  if t then
    b:SetAlpha(1); b.icon:SetDesaturated(false)
    if which == "mark" then hud.markWarn:Hide() end
  else
    b:SetAlpha(0.45); b.icon:SetDesaturated(true)
    if which == "mark" then hud.markWarn:SetShown(alertWhenMissing and true or false) end
  end
end

---------------------------------------------------------------------------
-- Reminders
---------------------------------------------------------------------------
local function ReadAspect()
  if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
  local found
  for id in pairs(HAWK_ASPECT) do
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if ok and a and not ns.IsSecret(a) then found = "hawk" break end
    if not ok or ns.IsSecret(a) then return end   -- hidden right now: keep what we know
  end
  if not found then
    for id in pairs(OTHER_ASPECTS) do
      local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
      if ok and a and not ns.IsSecret(a) then found = "other" break end
    end
  end
  aspect = found
end

local function WellFed()
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return true end
  local name = (ns.SpellName and ns.SpellName(19705)) or "Well Fed"
  local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
  if not ok or ns.IsSecret(a) then return true end
  return a ~= nil
end

local function PaintReminders(fight)
  local mounted = Bool(IsMounted and IsMounted(), false)
  local hasPet = Bool(UnitExists("pet"), true) and not Bool(UnitIsDead("pet"), false)
  local want = {
    food = not fight and not mounted and ns.db.hudFood ~= false and not WellFed(),
    aspect = fight and Known("Aspect of the Hawk") and aspect ~= "hawk",
    pet = not hasPet and not mounted and Known("Call Pet"),
  }
  local x = 0
  for _, b in ipairs(hud.remind.icons) do
    local show = moving or want[b.key]
    b:SetShown(show and true or false)
    if show then
      b:ClearAllPoints()
      b:SetPoint("LEFT", x, 0)
      x = x + 32
    end
  end
end

---------------------------------------------------------------------------
-- Paint
---------------------------------------------------------------------------
local function Paint()
  if not hud then return end
  if ns.db.hud == false then hud:Hide() return end
  local fight = UnitAffectingCombat("player")
  if ns.IsSecret(fight) then fight = true end
  local hasTarget = Bool(UnitExists("target"), false)
  local hostile = hasTarget and Bool(UnitCanAttack("player", "target"), true)
  local dead = hasTarget and Bool(UnitIsDead("target"), false)
  hud:Show()
  local showTimers = moving or (hostile and not dead and (fight or TimerFor("sting") or TimerFor("mark")))
  if showTimers then
    PaintTimer(hud.sting, "sting", false)
    PaintTimer(hud.mark, "mark", fight)
  else
    hud.sting:Hide(); hud.mark:Hide()
  end
  local showRows = moving or fight or ns.db.hudAlways
  for _, row in ipairs(hud.rows) do row:SetShown(showRows and true or false) end
  PaintReminders(fight)
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
    if ns.HawkPaint then ns.HawkPaint() end
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
  elseif arg == "always" then
    ns.db.hudAlways = not ns.db.hudAlways
    ns.Print(ns.db.hudAlways and L["Cooldowns stay on screen outside fights too."] or L["Cooldowns show only in fights."])
    Paint()
  else
    ns.Print(L["/ut hud move, lock, reset, scale 1.2, off, on, always (cooldowns outside fights too)"])
  end
end

do
  local ev = CreateFrame("Frame")
  local tick = 0
  for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA",
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_PET", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
      if select(2, UnitClass("player")) ~= "HUNTER" then ev:UnregisterAllEvents() return end
      Build()
      LayoutRows()
      ReadAspect()
      UpdateCooldowns()
      ev:SetScript("OnUpdate", function(_, e)
        tick = tick + e
        if tick < 0.2 then return end
        tick = 0
        -- one error is reported once, then the display rests 10 seconds instead of flooding
        local ok, err = pcall(Paint)
        if not ok then
          tick = -10
          if geterrorhandler then geterrorhandler()(err) end
        end
      end)
      return
    end
    if not hud then return end
    if event == "SPELLS_CHANGED" then LayoutRows(); UpdateCooldowns()
    elseif event == "SPELL_UPDATE_COOLDOWN" then UpdateCooldowns()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      if unit == "player" and spellID and not ns.IsSecret(spellID) then
        if STING_IDS[spellID] then StartTimer("sting", "Serpent Sting")
        elseif MARK_IDS[spellID] then StartTimer("mark", "Hunter's Mark")
        elseif HAWK_ASPECT[spellID] then aspect = "hawk"
        elseif OTHER_ASPECTS[spellID] then aspect = "other" end
      end
      UpdateCooldowns()
    elseif event == "UNIT_AURA" then
      if unit == "player" then ReadAspect() end
    elseif event == "PLAYER_REGEN_ENABLED" then
      ReadAspect()
    end
    Paint()
  end)
end

-- for tests
ns.HUD_Timer = TimerFor
ns.HUD_Aspect = function() return aspect end
