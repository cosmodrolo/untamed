local _, ns = ...
local L = ns.L
local C = ns.C

-- Combat helpers: Auto Shot timer, Growl warning, aspect and Hunter's Mark reminders, resist alerts.

local function IsHunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

local function Alert(msg, sound)
  if ns.Alert then ns.Alert(msg, sound) else print(msg) end
end

-- Localized names for the spells we watch (the client knows them in every language).
local NAMES = {}
local function Name(id)
  local n = NAMES[id]
  if n == nil then n = ns.SpellName(id) or false; NAMES[id] = n end
  return n or nil
end

---------------------------------------------------------------------------
-- Auto Shot timer
-- Classic: after each Auto Shot there is a reload (you may move), then a short
-- aim window (about 0.5 s) where moving delays the shot. The bar shows both.
---------------------------------------------------------------------------
local AUTO_SHOT = 75
local AIM = 0.5
local AIMED_SHOT = { 19434, 20900, 20901, 20902, 20903, 20904 }
local bar, shooting, lastShot, swing, aimStart

-- Forever hides stats like ranged speed during combat (secret values), so check before comparing
-- and remember the last speed we could read.
local knownSpeed
local function RangedSpeed()
  local s = UnitRangedDamage and UnitRangedDamage("player")
  if ns.IsSecret(s) or type(s) ~= "number" or s <= 0 then return nil end
  knownSpeed = s
  return s
end

-- Moving? IsPlayerMoving is never secret; GetUnitSpeed can be.
local function Moving()
  if IsPlayerMoving then
    local ok, m = pcall(IsPlayerMoving)
    if ok and not ns.IsSecret(m) then return m and true or false end
  end
  local v = GetUnitSpeed and GetUnitSpeed("player")
  if ns.IsSecret(v) or type(v) ~= "number" then return false end
  return v > 0
end

local function CreateBar()
  bar = CreateFrame("StatusBar", "UntamedAutoShotBar", UIParent)
  bar:SetSize(200, 14)
  local pos = ns.db.shotBarPos
  if pos then bar:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else bar:SetPoint("CENTER", 0, -170) end
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetMovable(true)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetClampedToScreen(true)
  bar:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
  bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.shotBarPos = { p, rp, x, y }
  end)
  bar:SetScript("OnEnter", function(self)
    ns.ShowTooltip(self, { L["Auto Shot timer"], L["Yellow: reloading, you can move freely."],
      L["Red: aiming. Stand still or your next shot is delayed."], C.GREY .. L["Shift-drag to move."] .. "|r" })
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.6)
  local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
  border:SetPoint("TOPLEFT", -3, 3)
  border:SetPoint("BOTTOMRIGHT", 3, -3)
  if border.SetBackdrop then
    border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
    border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  end
  -- marker where the aim window starts
  bar.mark = bar:CreateTexture(nil, "OVERLAY")
  bar.mark:SetSize(2, 14)
  bar.mark:SetColorTexture(1, 1, 1, 0.8)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("LEFT", 4, 0)
  bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.time:SetPoint("RIGHT", -4, 0)
  bar.text:SetText(Name(AUTO_SHOT) or "Auto Shot")
  bar:Hide()

  bar:SetScript("OnUpdate", function(self)
    if not lastShot or not swing then return end
    local now = GetTime()
    local reload = swing - AIM
    local moving = Moving()
    local t = now - lastShot
    if t < reload then
      self:SetStatusBarColor(1, 0.82, 0)
      self:SetValue(t / swing)
      self.time:SetText(string.format("%.1f", swing - t))
      aimStart = nil
    else
      -- Aim window: moving holds the shot back.
      if moving or not aimStart then aimStart = now end
      local a = math.min(AIM, now - aimStart)
      self:SetStatusBarColor(1, 0.25, 0.2)
      self:SetValue((reload + a) / swing)
      self.time:SetText(moving and L["stand still"] or string.format("%.1f", AIM - a))
    end
  end)
end

local function MarkPosition()
  if not bar or not swing then return end
  bar.mark:ClearAllPoints()
  bar.mark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * (swing - AIM) / swing, 0)
end

local function ShotFired()
  local now = GetTime()
  local speed = RangedSpeed()
  if not speed and lastShot then
    -- Speed is hidden: use the time since the last shot when it looks like a normal swing.
    local gap = now - lastShot
    if gap > 1 and gap < 4 then speed = gap end
  end
  lastShot = now
  swing = speed or swing or knownSpeed or 2.8
  aimStart = nil
  MarkPosition()
end

local function ShowBar(on)
  if not ns.db.autoShotBar then on = false end
  if on and not bar then CreateBar() end
  if bar then bar:SetShown(on and true or false) end
end

---------------------------------------------------------------------------
-- Growl warning
---------------------------------------------------------------------------
local GROWL = 2649
local lastGrowlState

-- Is Growl on autocast? Returns nil when the pet doesn't have it.
local function GrowlAutocast()
  if not UnitExists("pet") or not GetPetActionInfo then return nil end
  local growlName = Name(GROWL)
  for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
    local a = { pcall(GetPetActionInfo, i) }
    if a[1] then
      local name = a[2]
      local enabled = a[7]   -- name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled
      if type(name) == "string" and (name == growlName or ns.ToEnglish(name) == "Growl") then
        return enabled and true or false
      end
    end
  end
  return nil
end

local function CheckGrowl()
  if not ns.db.growlWarning or not IsHunter() then return end
  local on = GrowlAutocast()
  if on == nil then lastGrowlState = nil return end
  local grouped = (IsInGroup and IsInGroup()) or (GetNumGroupMembers and GetNumGroupMembers() > 0)
  local state = (grouped and on) and "group" or ((not grouped and not on) and "solo") or "ok"
  if state == lastGrowlState then return end
  lastGrowlState = state
  if state == "group" then
    Alert(C.ORANGE .. L["Growl is on while you're in a group. Turn it off so your pet doesn't take threat from the tank."] .. "|r", true)
    ns.Print(L["Growl is on autocast while you're grouped. Right-click Growl on your pet bar to turn it off."])
  elseif state == "solo" then
    ns.Print(L["Growl is off while you're solo. Right-click Growl on your pet bar to turn it back on so your pet holds threat."])
  end
end

---------------------------------------------------------------------------
-- Aspect and Hunter's Mark reminders
---------------------------------------------------------------------------
local TRAVEL_ASPECTS = { 5118, 13159 }                               -- Cheetah, Pack
local ALL_ASPECTS = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, -- Hawk
  13163, 5118, 13159, 13161, 20043, 20190, 34074 }                   -- Monkey, Cheetah, Pack, Beast, Wild, Viper
local HUNTERS_MARK = { 1130, 14323, 14324, 14325 }

-- Find a buff on the player by any of these spell IDs (by name, which works on both clients).
local function HasAura(unit, ids, filter)
  local wanted = {}
  for _, id in ipairs(ids) do local n = Name(id); if n then wanted[n] = id end end
  if AuraUtil and AuraUtil.FindAuraByName then
    for n in pairs(wanted) do
      local ok, found = pcall(AuraUtil.FindAuraByName, n, unit, filter)
      if ok and found and not ns.IsSecret(found) then return n end
    end
    return nil
  end
  local fn = filter == "HARMFUL" and UnitDebuff or UnitBuff
  if not fn then return nil end
  for i = 1, 40 do
    local ok, n = pcall(fn, unit, i)
    if not ok or not n then break end
    if not ns.IsSecret(n) and wanted[n] then return n end
  end
  return nil
end

local function CheckAspect()
  if not ns.db.aspectReminder or not IsHunter() then return end
  local travel = HasAura("player", TRAVEL_ASPECTS, "HELPFUL")
  if travel then
    Alert(C.ORANGE .. string.format(L["%s is on in combat. Switch aspects!"], travel) .. "|r", true)
  elseif (function() local l = UnitLevel("player"); return not ns.IsSecret(l) and l >= 10 end)() and not HasAura("player", ALL_ASPECTS, "HELPFUL") then
    ns.Print(L["No aspect is active."])
  end
end

local markedFor
local function CheckMark()
  if not ns.db.markReminder or not IsHunter() then return end
  if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then return end
  local guid = UnitGUID("target")
  if ns.IsSecret(guid) then guid = nil end
  if guid and guid == markedFor then return end
  local cls = UnitClassification and UnitClassification("target")
  if ns.IsSecret(cls) then cls = nil end
  local lvl = UnitLevel("target")
  local boss = cls == "worldboss" or (not ns.IsSecret(lvl) and lvl == -1)
  if not boss then return end
  if not HasAura("target", HUNTERS_MARK, "HARMFUL") then
    markedFor = guid
    Alert(C.ORANGE .. L["Boss has no Hunter's Mark."] .. "|r", false)
  end
end

---------------------------------------------------------------------------
-- Resist alerts (traps, Feign Death, Scatter Shot, Tranquilizing Shot, ...)
---------------------------------------------------------------------------
local WATCH = { 5384, 3355, 14308, 14309, 19503, 1513, 14326, 14327, 19386, 24132, 24133, 19801, 1499, 14310, 14311 }
local watchNames
local function WatchNames()
  if watchNames then return watchNames end
  watchNames = {}
  for _, id in ipairs(WATCH) do local n = Name(id); if n then watchNames[n] = true end end
  return watchNames
end

local function OnCombatLog()
  if not ns.db.resistAlerts or not CombatLogGetCurrentEventInfo then return end
  local _, sub, _, srcGUID, _, _, _, _, destName, _, _, _, spellName, _, missType = CombatLogGetCurrentEventInfo()
  if sub ~= "SPELL_MISSED" or srcGUID ~= UnitGUID("player") then return end
  if not spellName or ns.IsSecret(spellName) or not WatchNames()[spellName] then return end
  local how = (missType == "RESIST" or missType == "IMMUNE") and (missType == "IMMUNE" and L["IMMUNE"] or L["RESISTED"]) or tostring(missType or L["MISSED"])
  Alert(C.RED .. spellName .. " " .. how .. "|r" .. (destName and (C.GREY .. "  (" .. destName .. ")|r") or ""), true)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UNIT_SPELLCAST_SUCCEEDED", "PET_BAR_UPDATE",
  "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "UNIT_RANGEDDAMAGE" }) do Reg(e) end
if ns.FLAVOR ~= "forever" then Reg("COMBAT_LOG_EVENT_UNFILTERED") end

ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "START_AUTOREPEAT_SPELL" then
    shooting = true
    swing = RangedSpeed() or swing
    ShowBar(true)
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    shooting = false
    ShowBar(false)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit ~= "player" or ns.IsSecret(spellID) then return end
    if spellID == AUTO_SHOT then ShotFired()
    else
      for _, id in ipairs(AIMED_SHOT) do if spellID == id then ShotFired() break end end
    end
  elseif event == "UNIT_RANGEDDAMAGE" then
    if unit == "player" then swing = RangedSpeed() or swing; MarkPosition() end
  elseif event == "PET_BAR_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
    if event == "UNIT_PET" and unit ~= "player" then return end
    CheckGrowl()
  elseif event == "PLAYER_REGEN_DISABLED" then
    CheckAspect()
    CheckMark()
  elseif event == "PLAYER_TARGET_CHANGED" then
    if UnitAffectingCombat("player") then CheckMark() end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLog()
  end
end)

ns.On("LOGIN", function()
  if C_Timer and C_Timer.After then C_Timer.After(5, CheckGrowl) else CheckGrowl() end
end)

-- Test hooks
ns.Combat = { ShotFired = ShotFired, CheckGrowl = CheckGrowl, CheckAspect = CheckAspect, ShowBar = ShowBar }
