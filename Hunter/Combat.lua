local _, ns = ...
local L = ns.L
local C = ns.C

-- Combat helpers: Growl warning, the travel aspect warning and the Hunter's Mark reminder on bosses.

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
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
for _, e in ipairs({ "PET_BAR_UPDATE", "GROUP_ROSTER_UPDATE", "UNIT_PET", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED" }) do Reg(e) end

ev:SetScript("OnEvent", function(_, event, unit)
  if event == "PET_BAR_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
    if event == "UNIT_PET" and unit ~= "player" then return end
    CheckGrowl()
  elseif event == "PLAYER_REGEN_DISABLED" then
    CheckAspect()
    CheckMark()
  elseif event == "PLAYER_TARGET_CHANGED" then
    if UnitAffectingCombat("player") then CheckMark() end
  end
end)

ns.On("LOGIN", function()
  if C_Timer and C_Timer.After then C_Timer.After(5, CheckGrowl) else CheckGrowl() end
end)

-- Test hooks
ns.Combat = { CheckGrowl = CheckGrowl, CheckAspect = CheckAspect }
