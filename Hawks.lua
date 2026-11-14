local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Hawk tracker: two slots for your Summon Hawk hawks (at most 2 at once, 18 sec each), each with
-- its time left as a sweep, big seconds and a bar, so you can see at a glance whether both are up.
-- Driven by your own Summon Hawk casts (UNIT_SPELLCAST_SUCCEEDED, spell ID only when it isn't
-- secret); a third hawk replaces the oldest. Shown in a fight (empty slots dim, so you see a
-- missing hawk) and while a hawk is still out; cleared when the fight ends.
-- Our own frame on UIParent (gamepad safe). /ut hawks move | lock | reset | off | on.
---------------------------------------------------------------------------

local HAWK_IDS = { [1293241] = true, [1293525] = true, [1293526] = true, [1293527] = true }
local LIFE, SIZE = 18, 40
local DEFAULT_POS = { "CENTER", 0, -105 }

local frame, slots, moving
local hawks = {}   -- expiry times, oldest first

local function Text(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local file = fs:GetFont()
  fs:SetFont(file or STANDARD_TEXT_FONT, size, "OUTLINE")
  return fs
end

local function Place()
  local p = ns.db.hawkPos or DEFAULT_POS
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[1], p[2], p[3])
end

local function Build()
  frame = CreateFrame("Frame", "UntamedHawks", UIParent)
  frame:SetSize(SIZE * 2 + 8, SIZE + 10)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  frame:SetMovable(true)
  frame:EnableMouse(false)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.db.hawkPos = { "CENTER", cx - ux, cy - uy }
    Place()
  end)
  slots = {}
  for i = 1, 2 do
    local s = CreateFrame("Frame", nil, frame)
    s:SetSize(SIZE, SIZE)
    s:SetPoint("TOPLEFT", (i - 1) * (SIZE + 8), 0)
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(0, 0, 0, 0.8)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetPoint("TOPLEFT", 1, -1)
    s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(1293241)) or "Interface\\Icons\\Ability_Hunter_Pet_Owl")
    s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    s.cd:SetAllPoints(s.icon)
    s.cd:SetReverse(true)
    s.cd:SetHideCountdownNumbers(true)
    s.time = Text(s, 17)
    s.time:SetPoint("CENTER", 0, 0)
    s.bar = s:CreateTexture(nil, "OVERLAY")
    s.bar:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -3)
    s.bar:SetHeight(4)
    s.barbg = s:CreateTexture(nil, "BORDER")
    s.barbg:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -3)
    s.barbg:SetSize(SIZE, 4)
    s.barbg:SetColorTexture(0, 0, 0, 0.6)
    slots[i] = s
  end
  frame.hint = Text(frame, 11)
  frame.hint:SetPoint("TOP", frame, "BOTTOM", 0, -4)
  frame.hint:Hide()
  Place()
end

local function Paint()
  local now = GetTime()
  for i = #hawks, 1, -1 do if hawks[i] <= now then table.remove(hawks, i) end end
  local fight = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
  if ns.IsSecret(fight) then fight = true end
  if not moving and not fight and #hawks == 0 then frame:Hide() return end
  frame:Show()
  for i, s in ipairs(slots) do
    local ends = hawks[i]
    if s.ends ~= ends then
      s.ends = ends
      if ends then s.cd:SetCooldown(ends - LIFE, LIFE) else s.cd:Clear() end
    end
    if ends then
      local left = ends - now
      s.icon:SetDesaturated(false)
      s:SetAlpha(1)
      s.time:SetText((left <= 3 and "|cffff5050" or "|cffffffff") .. math.ceil(left) .. "|r")
      s.bar:SetWidth(math.max(1, SIZE * left / LIFE))
      if left <= 3 then s.bar:SetColorTexture(1, 0.3, 0.3, 1) else s.bar:SetColorTexture(0.67, 0.83, 0.45, 1) end
      s.bar:Show()
    else
      s.icon:SetDesaturated(true)
      s:SetAlpha(0.45)
      s.time:SetText("")
      s.bar:Hide()
    end
  end
end

local function OnHawk()
  if #hawks >= 2 then table.remove(hawks, 1) end
  hawks[#hawks + 1] = GetTime() + LIFE
  Paint()
end
ns.HawkCast = OnHawk   -- for tests
ns.HawkCount = function() return #hawks end

function ns.HawkCommand(arg)
  if not frame then return end
  if arg == "move" or arg == "lock" then
    moving = arg == "move" and not moving
    frame:EnableMouse(moving)
    frame.hint:SetShown(moving)
    frame.hint:SetText("|cffffd140" .. L["Drag me, then /ut hawks lock"] .. "|r")
    if moving then ns.Print(L["Drag the hawk tracker where you want it, then type /ut hawks lock."]) end
    Paint()
  elseif arg == "reset" then
    ns.db.hawkPos = nil
    Place()
  elseif arg == "off" or arg == "on" then
    ns.db.hawkTracker = arg == "on"
    if arg == "off" then frame:Hide() end
    ns.Print(ns.db.hawkTracker and L["The hawk tracker is on."] or L["The hawk tracker is off (/ut hawks on brings it back)."])
  else
    ns.Print(L["/ut hawks move, lock, reset, off or on."])
  end
end

do
  local ev = CreateFrame("Frame")
  local tick = 0
  for _, e in ipairs({ "PLAYER_LOGIN", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" then
      if select(2, UnitClass("player")) ~= "HUNTER" then ev:UnregisterAllEvents() return end
      Build()
      ev:SetScript("OnUpdate", function(_, e)
        tick = tick + e
        if tick < 0.1 then return end
        tick = 0
        if frame:IsShown() or #hawks > 0 then Paint() end
      end)
      return
    end
    if not frame or ns.db.hawkTracker == false then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if unit == "player" and not ns.IsSecret(spellID) and HAWK_IDS[spellID] then OnHawk() end
    elseif event == "PLAYER_REGEN_ENABLED" then
      wipe(hawks)
      Paint()
    else
      Paint()
    end
  end)
end
