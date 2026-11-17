local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Range meter: the top of the hunter display under your character (HUD.lua).
--  * Range: melee, dead zone (too close for Auto Shot), in range, too far, plus the distance as a
--    band in yards. WoW doesn't give addons the exact distance to an enemy, so the band comes from
--    the game's own range checks on your spells (each spell has its own min and max range) and,
--    when the game allows it, the interact distances (10, 11 and 28 yards).
--  * Feign Death: says whether it dropped you out of combat.
-- Our own frame (gamepad safe). /ut range off | on | alerts | always; /ut hud move moves it.
---------------------------------------------------------------------------

local DEFAULT_POS = { "CENTER", 0, 120 }
local MELEE = { "Raptor Strike", "Wing Clip", "Mongoose Bite" }
local CHECKS = { "Auto Shot", "Arcane Shot", "Serpent Sting", "Concussive Shot", "Hunter's Mark", "Scatter Shot",
  "Distracting Shot", "Scorpid Sting", "Viper Sting", "Wyvern Sting", "Tranquilizing Shot", "Scare Beast",
  "Multi-Shot", "Aimed Shot", "Summon Hawk" }
local INTERACT = { [3] = 10, [2] = 11, [4] = 28 }
local FEIGN = { [5384] = true }

local frame, moving, lastZone

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end
-- a yes/no from the game that may be hidden in combat: the fallback when it is
local function Bool(v, hidden) if ns.IsSecret(v) then return hidden end return v and true or false end

local function Text(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local file = fs:GetFont()
  fs:SetFont(file or STANDARD_TEXT_FONT, size, "OUTLINE")
  return fs
end

-- the localized name and range of one of your spells (nil if you don't know it)
local spellCache = {}
local function SpellRange(english)
  local c = spellCache[english]
  if c ~= nil then return c or nil end
  local name = english
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
  c = info and { name = info.name or name, min = Plain(info.minRange) or 0, max = Plain(info.maxRange) or 0 } or false
  if c and c.max <= 0 then c = false end
  spellCache[english] = c
  return c or nil
end

-- yes / no / nil (the game won't say), whatever shape the answer comes in (true, false, 1, 0)
local function YesNo(r)
  if r == nil or ns.IsSecret(r) then return nil end
  if r == true or r == 1 then return true end
  if r == false or r == 0 then return false end
  return nil
end

local function InRange(name)
  if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
  -- a spell without a range of its own (melee) gets no honest answer here: skip it
  if C_Spell.SpellHasRange then
    local okH, has = pcall(C_Spell.SpellHasRange, name)
    if okH and not ns.IsSecret(has) and not has then return nil end
  end
  local ok, r = pcall(C_Spell.IsSpellInRange, name, "target")
  if not ok then return nil end
  return YesNo(r)
end

-- Melee: the action bar knows (a Raptor Strike button turns red out of reach). The slots that
-- hold a melee ability, or a macro that shows one, are found once and asked directly.
local MELEE_SET = { ["Raptor Strike"] = true, ["Wing Clip"] = true, ["Mongoose Bite"] = true }
local meleeSlots
local function FindMeleeSlots()
  meleeSlots = {}
  if not GetActionInfo then return end
  for slot = 1, 180 do
    local ok, kind, id = pcall(GetActionInfo, slot)
    if ok and kind and not ns.IsSecret(kind) and id and not ns.IsSecret(id) then
      local spell
      if kind == "spell" then spell = id
      elseif kind == "macro" and GetMacroSpell then
        local okM, sid = pcall(GetMacroSpell, id)
        if okM and sid and not ns.IsSecret(sid) then spell = sid end
      end
      if spell and C_Spell and C_Spell.GetSpellName then
        local okN, n = pcall(C_Spell.GetSpellName, spell)
        if okN and n and not ns.IsSecret(n) and MELEE_SET[n] then meleeSlots[#meleeSlots + 1] = slot end
      end
    end
  end
end

local function MeleeInRange()
  if not meleeSlots then FindMeleeSlots() end
  local f = (C_ActionBar and C_ActionBar.IsActionInRange) or IsActionInRange
  if not f then return nil end
  for _, slot in ipairs(meleeSlots) do
    local ok, r = pcall(f, slot, "target")
    local yn = ok and YesNo(r)
    if yn ~= nil then return yn end
  end
  return nil
end
ns.RangeMeleeSlots = function() meleeSlots = nil end
ns.RangeMeleeSlotList = function() if not meleeSlots then FindMeleeSlots() end return meleeSlots end

-- Where the target is: zone ("melee", "dead", "range", "far") and a yard band (lo, hi).
function ns.RangeToTarget()
  if not Bool(UnitExists("target"), false) then return nil end
  if not Bool(UnitCanAttack("player", "target"), false) then return nil end
  if Bool(UnitIsDead("target"), false) then return nil end

  local facts = {}
  local melee
  -- melee: from the spell if it has a range of its own, else from the action bar
  for name in pairs(MELEE_SET) do
    if C_Spell.GetSpellInfo(name) then
      local r = InRange(name)
      if r ~= nil then melee = melee or r end
    end
  end
  if melee == nil then melee = MeleeInRange() end
  local auto, autoMin, autoMax
  for _, s in ipairs(CHECKS) do
    local sp = SpellRange(s)
    if sp then
      local r = InRange(sp.name)
      if r ~= nil then
        facts[#facts + 1] = { sp.min, sp.max, r }
        if s == "Auto Shot" then auto, autoMin, autoMax = r, sp.min, sp.max end
      end
    end
  end
  -- On Forever the melee check can say "yes" at any distance. A shot with a minimum range that
  -- says "in range" proves you're not in melee, so it wins over a melee "yes".
  if melee then
    for _, f in ipairs(facts) do
      if f[3] and f[1] >= 5 then melee = false break end
    end
  end
  ns.rangeMeleeRaw = melee
  if melee ~= nil then facts[#facts + 1] = { 0, 5, melee } end
  if not InCombatLockdown() and CheckInteractDistance then
    for i, yd in pairs(INTERACT) do
      local ok, r = pcall(CheckInteractDistance, "target", i)
      if ok and r ~= nil and not ns.IsSecret(r) then facts[#facts + 1] = { 0, yd, r and true or false } end
    end
  end
  if #facts == 0 then return nil end

  local lo, hi = 0, math.huge
  for _ = 1, 3 do
    for _, f in ipairs(facts) do
      local mn, mx, r = f[1], f[2], f[3]
      if r then
        if mn > lo then lo = mn end
        if mx < hi then hi = mx end
      elseif mn <= 0 or lo >= mn then
        if mx > lo then lo = mx end
      elseif hi <= mx then
        if mn < hi then hi = mn end
      end
    end
  end
  if lo > hi then lo = hi end

  local zone
  if melee then zone = "melee"
  elseif auto then zone = "range"
  elseif auto == false then
    if hi <= (autoMin or 8) + 0.5 then zone = (melee == nil) and "close" or "dead"
    elseif lo >= (autoMax or 35) then zone = "far"
    elseif lastZone == "melee" or lastZone == "dead" or lastZone == "close" then zone = (melee == nil) and "close" or "dead"
    else zone = "far" end
  else
    zone = (hi <= 5 and "melee") or "unknown"
  end
  return zone, lo, hi
end

local ZONES = {
  melee = { L["Melee"], { 0.89, 0.29, 0.29 }, L["Raptor Strike, Wing Clip"] },
  dead  = { L["Dead zone"], { 0.94, 0.62, 0.15 }, L["Step back or Disengage"] },
  -- too close for Auto Shot, and the game won't say whether melee reaches
  close = { L["Too close"], { 0.94, 0.62, 0.15 }, L["Melee it or step back"] },
  range = { L["In range"], { 0.39, 0.6, 0.13 }, nil },
  far   = { L["Too far"], { 0.53, 0.53, 0.5 }, L["Move closer"] },
  unknown = { L["Target"], { 0.53, 0.53, 0.5 }, nil },
}

local function Yards(lo, hi)
  lo = math.floor(lo + 0.5)
  if hi == math.huge then return lo .. "+ " .. L["yd"] end
  hi = math.floor(hi + 0.5)
  if lo == hi then return hi .. " " .. L["yd"] end
  return lo .. "-" .. hi .. " " .. L["yd"]
end
ns.RangeYards = Yards

local function Place()
  frame:ClearAllPoints()
  local slot = ns.HUD_Slot and ns.HUD_Slot("top")
  if slot then
    frame:SetParent(slot)
    frame:SetPoint("TOP", slot, "TOP")
  else
    local p = ns.db.rangePos or DEFAULT_POS
    frame:SetPoint(p[1], UIParent, p[1], p[2], p[3])
  end
end

local function Build()
  frame = CreateFrame("Frame", "UntamedRange", UIParent)
  frame:SetSize(170, 40)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.db.rangePos = { "CENTER", cx - ux, cy - uy }
    Place()
  end)
  frame:Hide()

  local r = CreateFrame("Frame", nil, frame)
  r:SetSize(150, 24)
  r:SetPoint("TOP")
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(0, 0, 0, 0.55)
  r.edge = {}
  for i, pt in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local t = r:CreateTexture(nil, "BORDER")
    t:SetPoint(pt[1]); t:SetPoint(pt[2])
    if i <= 2 then t:SetHeight(1.5) else t:SetWidth(1.5) end
    r.edge[i] = t
  end
  r.zone = Text(r, 14)
  r.zone:SetPoint("LEFT", 8, 0)
  r.yd = Text(r, 12)
  r.yd:SetPoint("RIGHT", -8, 0)
  r.hint = Text(frame, 10)
  r.hint:SetPoint("TOP", r, "BOTTOM", 0, -1)
  frame.range = r

  frame.hint = Text(frame, 11)
  frame.hint:SetPoint("BOTTOM", frame, "TOP", 0, 2)
  frame.hint:Hide()
  Place()
end

local function Paint()
  if not frame then return end
  local moving = moving or (ns.HUD_Moving and ns.HUD_Moving())
  local fight = UnitAffectingCombat("player")
  if ns.IsSecret(fight) then fight = true end

  -- range
  local r = frame.range
  local zone, lo, hi
  if ns.db.rangeMeter ~= false then zone, lo, hi = ns.RangeToTarget() end
  if zone then lastZone = zone end
  local showRange = zone and (moving or ns.db.rangeMode ~= "alerts" or zone == "dead" or zone == "close" or zone == "far" or zone == "melee")
  if moving and not zone then zone, lo, hi = "range", 8, 35 end
  if showRange or moving then
    local z = ZONES[zone]
    local c = z[2]
    r.zone:SetText(z[1])
    r.zone:SetTextColor(c[1], c[2], c[3])
    for _, t in ipairs(r.edge) do t:SetColorTexture(c[1], c[2], c[3], 1) end
    r.yd:SetText(lo and Yards(lo, hi) or "")
    r.hint:SetText(z[3] and ("|cffd3d1c7" .. z[3] .. "|r") or "")
    r:Show(); r.hint:Show()
  else
    r:Hide(); r.hint:Hide()
  end

  frame:SetShown(showRange or moving)
end
ns.RangePaint = Paint

function ns.RangeCommand(arg)
  if not frame then return end
  if (arg == "move" or arg == "lock") and ns.HUDCommand and ns.HUD_Slot("top") then
    ns.HUDCommand(arg)
  elseif arg == "move" or arg == "lock" then
    moving = arg == "move" and not moving
    frame:EnableMouse(moving)
    frame.hint:SetShown(moving)
    frame.hint:SetText("|cffffd140" .. L["Drag me, then /ut range lock"] .. "|r")
    if moving then ns.Print(L["Drag the range meter where you want it, then type /ut range lock."]) end
    Paint()
  elseif arg == "reset" then
    ns.db.rangePos = nil
    Place()
  elseif arg == "off" or arg == "on" then
    ns.db.rangeMeter = arg == "on"
    ns.Print(ns.db.rangeMeter and L["The range meter is on."] or L["The range meter is off (/ut range on brings it back)."])
    Paint()
  elseif arg == "alerts" or arg == "always" then
    ns.db.rangeMode = arg
    ns.Print(arg == "alerts" and L["The range meter only shows when you're too close or too far."] or L["The range meter shows whenever you target an enemy."])
    Paint()
  else
    ns.Print(L["/ut range off, on, alerts (only when too close or too far), always  (/ut hud move moves it)"])
  end
end

do
  local ev = CreateFrame("Frame")
  local tick = 0
  for _, e in ipairs({ "PLAYER_LOGIN", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_TARGET_CHANGED", "SPELLS_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
      if select(2, UnitClass("player")) ~= "HUNTER" then ev:UnregisterAllEvents() return end
      Build()
      ev:SetScript("OnUpdate", function(_, e)
        tick = tick + e
        if tick < 0.15 then return end
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
    if not frame then return end
    if event == "SPELLS_CHANGED" then wipe(spellCache); meleeSlots = nil
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_MACROS" then meleeSlots = nil
    elseif event == "PLAYER_TARGET_CHANGED" then lastZone = nil; Paint()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      if unit == "player" and not ns.IsSecret(spellID) and FEIGN[spellID] and ns.db.feignHelper ~= false then
        C_Timer.After(0.5, function()
          local c = UnitAffectingCombat("player")
          if ns.IsSecret(c) then return end
          if c then
            ns.Alert(C.ORANGE .. L["Feign Death: still in combat. Something is still on you."] .. "|r", true)
          else
            ns.Alert(C.GREEN .. L["Feign Death worked: you're out of combat."] .. "|r", false)
          end
        end)
      end
    else
      Paint()
    end
  end)
end
