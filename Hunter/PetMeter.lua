local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Pet damage window: how much of your damage your pet and hawks do.
--   It reads Blizzard's damage meter (C_DamageMeter). The meter folds pet damage into your own
--   bar and names the creature on each of its spells ("Claw (Zabu)").
--   In a fight the game keeps those numbers secret from addons: they can be shown but not added
--   up, so the window mirrors your spell rows live, the way the breakdown does.
--   When the fight ends the numbers can be read, and the window shows the split: you, your pet,
--   your hawks, for that fight and for the whole session.
-- Our own frame on UIParent only (gamepad safe).
---------------------------------------------------------------------------

local WIDTH, ROWS, ROW_H = 250, 8, 16
local DEFAULT_POS = { "RIGHT", -260, -40 }
local MUTED, GOLD = "|cff8f8f99", "|cffffd140"
local COLOR = { you = { 0.67, 0.83, 0.45 }, pet = { 0.95, 0.62, 0.25 }, other = { 0.45, 0.70, 1.0 } }

local ICON = { you = "Interface\\Icons\\ClassIcon_Hunter", pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
  other = "Interface\\Icons\\Spell_Nature_RavenForm" }

local win, moving, dirty, last = nil, false, false, 0

local function Secret(v) return ns.IsSecret(v) end

local function Enum_(group, name, fallback)
  local e = Enum and Enum[group]
  return (e and e[name]) or fallback
end

-- your own entry in the meter for a session ("Current" or "Overall"): { combatSpells, maxAmount, totalAmount }
local function MySource(kind)
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType) then return nil end
  local guid = UnitGUID and UnitGUID("player")
  if not guid then return nil end
  local ok, src = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
    Enum_("DamageMeterSessionType", kind, kind == "Overall" and 0 or 1), Enum_("DamageMeterType", "DamageDone", 0), guid)
  if ok and type(src) == "table" then return src end
end

-- Both lookups take the meter's secret spell IDs during a fight (the game allows it); the name
-- that comes back may be secret too, which is fine for showing it.
local function SpellName(id)
  local ok, name = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end)
  return ok and name or nil
end

local function SpellIcon(id)
  local ok, icon = pcall(function() return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) end)
  return ok and icon or nil
end

local function Short(n)
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
  return tostring(math.floor(n + 0.5))
end

-- Whose damage a spell row is: "you", the pet's name, or another creature (the hawks).
-- Summon Hawk shows without a creature name, but it's the hawks' damage.
local function Owner(sp)
  local who = sp.creatureName
  if type(who) == "string" and who ~= "" then return who end
  local name = SpellName(sp.spellID)
  if name and not Secret(name) and name:find(L["Hawk"], 1, true) then return L["Hawks"] end
  return "you"
end

-- The split of one session, or nil while its numbers are secret: { total, { label, amount, kind } ... }
function ns.PetMeterSplit(kind)
  local src = MySource(kind)
  if not src or type(src.combatSpells) ~= "table" then return nil end
  local by, order, total = {}, {}, 0
  local pet = UnitName and UnitName("pet")
  for _, sp in ipairs(src.combatSpells) do
    local amt = sp.totalAmount
    if Secret(amt) or Secret(sp.creatureName) then return nil end
    if type(amt) == "number" and amt > 0 then
      local who = Owner(sp)
      if who == L["Hawk"] then who = L["Hawks"] end
      if not by[who] then
        by[who] = { label = who == "you" and L["You"] or who, amount = 0,
          kind = who == "you" and "you" or ((who == pet or (not pet and who ~= L["Hawks"])) and "pet" or "other") }
        order[#order + 1] = by[who]
      end
      by[who].amount = by[who].amount + amt
      total = total + amt
    end
  end
  if total <= 0 then return nil end
  table.sort(order, function(a, b) return a.amount > b.amount end)
  return { total = total, parts = order }
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Text(parent, size, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  local file = fs:GetFont()
  fs:SetFont(file or STANDARD_TEXT_FONT, size, "")
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function Place()
  local p = ns.db.petMeterPos or DEFAULT_POS
  win:ClearAllPoints()
  win:SetPoint(p[1], UIParent, p[1], p[2], p[3])
  win:SetScale(ns.db.petMeterScale or 1)
end

local function Build()
  win = CreateFrame("Frame", "UntamedPetMeter", UIParent)
  win:SetSize(WIDTH, 40)
  win:SetFrameStrata("MEDIUM")
  win:Hide()
  local bg = win:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.055, 0.058, 0.075, 0.85)
  local top = win:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(2)
  top:SetColorTexture(0.67, 0.83, 0.45, 0.9)
  win:SetMovable(true)
  win:SetClampedToScreen(true)
  win:EnableMouse(false)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local s = self:GetScale()
    ns.db.petMeterPos = { "CENTER", cx * s - ux, cy * s - uy }
    Place()
  end)
  win.title = Text(win, 12, "GameFontNormal")
  win.title:SetPoint("TOPLEFT", 8, -6)
  win.title:SetWidth(WIDTH - 16)
  win.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("StatusBar", nil, win)
    r:SetSize(WIDTH - 16, ROW_H)
    r:SetPoint("TOPLEFT", 8, -24 - (i - 1) * (ROW_H + 2))
    r:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r:SetMinMaxValues(0, 1)
    r:SetValue(0)
    local rbg = r:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints()
    rbg:SetColorTexture(1, 1, 1, 0.05)
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(ROW_H, ROW_H)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.value = Text(r, 11)
    r.value:SetPoint("RIGHT", -4, 0)
    r.value:SetJustifyH("RIGHT")
    r.name = Text(r, 11)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    r:Hide()
    win.rows[i] = r
  end
  win.foot = Text(win, 10)
  win.foot:SetWidth(WIDTH - 16)
  win.foot:SetWordWrap(false)     -- one line: the session split is short enough at this size
  Place()
end

local function Layout(n, foot)
  win.foot:ClearAllPoints()
  win.foot:SetPoint("TOPLEFT", 8, -24 - n * (ROW_H + 2) - 2)
  win.foot:SetText(foot or "")
  local h = 24 + n * (ROW_H + 2) + (foot and foot ~= "" and (win.foot:GetStringHeight() + 6) or 2) + (moving and 4 or 0)
  win:SetHeight(h)
end

local function Pct(a, total) return math.floor(a / total * 100 + 0.5) .. "%" end

-- After the fight: you / pet / hawks, with the session's split under it.
local function FillSplit(split)
  win.title:SetText(GOLD .. L["Pet damage"] .. "|r  " .. MUTED .. L["last fight"] .. "|r")
  local n = 0
  for i, r in ipairs(win.rows) do
    local p = split.parts[i]
    r:SetShown(p ~= nil)
    if p then
      n = i
      local c = COLOR[p.kind] or COLOR.other
      r:SetStatusBarColor(c[1], c[2], c[3], 0.75)
      r:SetMinMaxValues(0, split.parts[1].amount)
      r:SetValue(p.amount)
      r.icon:SetTexture(ICON[p.kind] or ICON.other)
      r.name:SetText(p.label)
      r.value:SetText(Short(p.amount) .. "  " .. MUTED .. Pct(p.amount, split.total) .. "|r")
    end
  end
  local all = ns.PetMeterSplit("Overall")
  local foot
  if all then
    local bits = {}
    for _, p in ipairs(all.parts) do bits[#bits + 1] = p.label .. " " .. Pct(p.amount, all.total) end
    foot = MUTED .. L["Session: "] .. "|r" .. table.concat(bits, MUTED .. " / |r")
  end
  Layout(n, foot)
end

-- In a fight: your spell rows as the meter has them, numbers passed straight through.
local function FillLive(src)
  win.title:SetText(GOLD .. L["Pet damage"] .. "|r  " .. MUTED .. L["this fight"] .. "|r")
  local spells = src and src.combatSpells
  local n = 0
  for i, r in ipairs(win.rows) do
    local sp = type(spells) == "table" and spells[i]
    r:SetShown(sp ~= nil and sp ~= false)
    if sp then
      n = i
      r:SetStatusBarColor(COLOR.other[1], COLOR.other[2], COLOR.other[3], 0.6)
      pcall(r.SetMinMaxValues, r, 0, src.maxAmount)
      pcall(r.SetValue, r, sp.totalAmount)
      r.icon:SetTexture(SpellIcon(sp.spellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local name = SpellName(sp.spellID) or "?"
      local okN = pcall(r.name.SetFormattedText, r.name, "%s " .. MUTED .. "%s|r", name, sp.creatureName or "")
      if not okN then r.name:SetText(name) end
      local amt = sp.totalAmount
      local okV = AbbreviateLargeNumbers and pcall(function() r.value:SetText(AbbreviateLargeNumbers(amt)) end)
      if not okV then okV = pcall(r.value.SetFormattedText, r.value, "%d", amt) end
      if not okV then r.value:SetText("") end
      ns.petMeterLive = okV and "numbers" or "bars only"
    end
  end
  Layout(n, n == 0 and (MUTED .. L["Waiting for the first hit."] .. "|r") or nil)
end

local function Refresh()
  if not win then return end
  if ns.db.petMeter == false then win:Hide() return end
  local ok, err = pcall(function()
    local split = not InCombatLockdown() and ns.PetMeterSplit("Current")
    if split then
      FillSplit(split)
      win:Show()
    else
      local src = MySource("Current")
      if src or moving then
        FillLive(src)
        win:Show()
      elseif not moving then
        win:Hide()
      end
    end
  end)
  if not ok then ns.petMeterError = tostring(err) end
end
ns.PetMeterRefresh = Refresh

function ns.PetMeterCommand(arg)
  arg = arg or ""
  if not win then return end
  if arg == "" then
    if win:IsShown() and not moving then win:Hide() else Refresh() if not win:IsShown() then
      ns.Print(L["The pet damage window shows once you've done damage this session."]) end end
  elseif arg == "move" or arg == "lock" then
    moving = (arg == "move") and not moving
    win:EnableMouse(moving)
    if moving then
      Refresh() win:Show()
      ns.Print(L["Drag the pet damage window where you want it, then type /ut meter lock."])
    else
      Refresh()
    end
  elseif arg:match("^size") then
    local n = tonumber(arg:match("(%d+)"))
    if n then ns.db.petMeterScale = math.max(0.5, math.min(1.6, n / 100)) end
    Place()
  elseif arg == "reset" then
    ns.db.petMeterPos, ns.db.petMeterScale = nil, nil
    Place()
  elseif arg == "off" or arg == "on" then
    ns.db.petMeter = arg == "on"
    ns.Print(ns.db.petMeter and L["The pet damage window is on."] or L["The pet damage window is off (/ut meter on brings it back)."])
    Refresh()
  end
end

-- Updates come in bursts during a fight: redraw at most 4 times a second.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    local _, class = UnitClass("player")
    if class ~= "HUNTER" or not C_DamageMeter then return end
    Build()
    for _, e in ipairs({ "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_RESET",
      "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET" }) do
      pcall(self.RegisterEvent, self, e)
    end
    return
  end
  dirty = true
end)
ev:SetScript("OnUpdate", function()
  if not dirty then return end
  local now = GetTime()
  if now - last < 0.25 then return end
  dirty, last = false, now
  Refresh()
end)

ns.PetMeterTest = { Owner = Owner, Build = function() if not win then Build() end return win end, FillLive = FillLive }
