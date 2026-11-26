local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- The controller in Untamed's window.
--   D-pad      move to the nearest thing in that direction (buttons, rows, dropdowns, checkboxes)
--   Cross      select it (a left click)
--   Square     its second action (a right click)
--   Circle     back: close a menu, then go to the list of pages, then close the window
--   L1 / R1    previous / next section
-- The pages of a section are the list on the left: D-pad up and down there.
-- How: while the window is open and you're not in a fight, those buttons are bound to buttons of
-- Untamed's own (override bindings owned by a frame of Untamed's own). Nothing of Blizzard's
-- controller code is touched, and the buttons are handed back the moment a fight starts or the
-- window closes. Everything it moves over is Untamed's own frame. /ut pad off turns it off.
---------------------------------------------------------------------------

local KEYS = {
  PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right",
  PAD1 = "accept", PAD2 = "back", PAD3 = "alt",
  PADLSHOULDER = "secprev", PADRSHOULDER = "secnext",
}
-- L2 and R2 are left alone: the game's controller bars use them as held shifts.
local REPEAT = { up = true, down = true, left = true, right = true }

local owner = CreateFrame("Frame", "UntamedPadOwner", UIParent)
local bound, focus, ring = false, nil, nil
local status = "off"

-- Which of the rects is the best step from `f` in a direction. Rects are { l, r, t, b } in screen
-- units (t above b). Plain numbers in, an index out: tested offline.
function ns.PadPick(f, rects, dir)
  local best, bestScore
  for i, c in ipairs(rects) do
    local primary, secondary
    if dir == "down" or dir == "up" then
      if dir == "down" then primary = f.b - c.t else primary = c.b - f.t end
      secondary = math.max(0, c.l - f.r, f.l - c.r)
    else
      if dir == "right" then primary = c.l - f.r else primary = f.l - c.r end
      secondary = math.max(0, f.b - c.t, c.b - f.t)
    end
    if primary > -2 then
      -- things straight ahead win over things off to the side; ties go to the nearer center
      local score = math.max(primary, 0) + secondary * 3
        + (math.abs((c.l + c.r) - (f.l + f.r)) + math.abs((c.t + c.b) - (f.t + f.b))) * 0.001
      if not bestScore or score < bestScore then best, bestScore = i, score end
    end
  end
  return best
end

local function Rect(w)
  local l, b, wd, h = w:GetRect()
  if not l or not wd or wd < 4 or not h or h < 4 then return nil end
  local s = w:GetEffectiveScale() or 1
  return { l = l * s, r = (l + wd) * s, t = (b + h) * s, b = b * s }
end

local function ScrollOf(w)
  local p = w:GetParent()
  for _ = 1, 12 do
    if not p then return nil end
    if p.IsObjectType and p:IsObjectType("ScrollFrame") then return p end
    p = p:GetParent()
  end
  return nil
end

-- everything you can move to under `root`: shown buttons with a click, checkboxes, text boxes
local function Collect(root, out)
  for _, child in ipairs({ root:GetChildren() }) do
    if child ~= ring and child.IsShown and child:IsShown() and child.IsObjectType then
      if child:IsObjectType("Slider") or child == root.ScrollBar then
        -- scroll bars and their arrows: the D-pad scrolls lists by moving through them
      else
        local isBox = child:IsObjectType("EditBox")
        if isBox or (child:IsObjectType("Button") and child:GetScript("OnClick") and (not child.IsEnabled or child:IsEnabled())) then
          local r = Rect(child)
          if r then r.w = child; r.scroll = ScrollOf(child); out[#out + 1] = r end
        end
        if not isBox then Collect(child, out) end
      end
    end
  end
  return out
end

local function Scope()
  local popup, popupOwner = ns.UI_Popup()
  if popup then return popup, popupOwner end
  return ns.UI_Frame()
end

local function MakeRing()
  ring = CreateFrame("Frame", nil, ns.UI_Frame())
  ring:SetFrameStrata("TOOLTIP")
  local function Edge(p1, p2, w, h)
    local t = ring:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 0.82, 0.2, 1)
    t:SetPoint(p1, ring, p1, 0, 0); t:SetPoint(p2, ring, p2, 0, 0)
    if w then t:SetWidth(w) else t:SetHeight(h) end
  end
  Edge("TOPLEFT", "TOPRIGHT", nil, 2); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
  Edge("TOPLEFT", "BOTTOMLEFT", 2, nil); Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
  local glow = ring:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 0.82, 0.2, 0.10)
  ring:Hide()
  -- the thing under the ring can go away when a page redraws: the ring goes with it
  ring:SetScript("OnUpdate", function(self)
    if not focus or not focus:IsVisible() then self:Hide() end
  end)
end

local function Reveal(w)
  local sc = ScrollOf(w)
  if not (sc and sc.GetVerticalScroll and sc:GetTop() and w:GetTop()) then return end
  local cur, range = sc:GetVerticalScroll() or 0, (sc.GetVerticalScrollRange and sc:GetVerticalScrollRange()) or 0
  local new = cur
  if w:GetTop() > sc:GetTop() then new = cur - (w:GetTop() - sc:GetTop()) - 4
  elseif w:GetBottom() < sc:GetBottom() then new = cur + (sc:GetBottom() - w:GetBottom()) + 4 end
  new = math.max(0, math.min(range, new))
  if new ~= cur then sc:SetVerticalScroll(new) end
end

local function Leave()
  if focus then
    local f = focus:GetScript("OnLeave")
    if f then pcall(f, focus) end
  end
end

local function SetFocus(w)
  if not ring then MakeRing() end
  if focus ~= w then Leave() end
  focus = w
  if not w then ring:Hide() return end
  Reveal(w)
  ring:ClearAllPoints()
  ring:SetPoint("TOPLEFT", w, "TOPLEFT", -2, 2)
  ring:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 2, -2)
  ring:Show()
  -- pages can tell the controller's frame from the mouse (the Bestiary turns its pages with it)
  local f = w:GetScript("OnEnter")
  if f then
    ns.padFocusing = true
    pcall(f, w)
    ns.padFocusing = nil
  end
end

local function Find(list, w)
  for i, r in ipairs(list) do if r.w == w then return i, r end end
end

local function Under(w, anc)
  local p = w
  for _ = 1, 16 do
    if not p then return false end
    if p == anc then return true end
    p = p:GetParent()
  end
  return false
end

-- where the ring starts: the page you're on in the list on the left; in a section with one page,
-- the first thing on the page; in a menu, its first entry
local function Default(list, scope)
  local within
  if scope == ns.UI_Frame() then
    local b = ns.UI_PageButton()
    if b and Find(list, b) then return b end
    within = ns.UI_Content and ns.UI_Content()
  end
  local best
  for pass = 1, 2 do
    for _, r in ipairs(list) do
      if (pass == 2 or not within or Under(r.w, within))
        and (not best or r.t > best.t + 2 or (math.abs(r.t - best.t) <= 2 and r.l < best.l)) then best = r end
    end
    if best then break end
  end
  return best and best.w
end

local function Move(dir)
  local scope = Scope()
  if not scope then return end
  local list = Collect(scope, {})
  local _, cur = Find(list, focus)
  if not cur then SetFocus(Default(list, scope)) return end
  -- rows scrolled out of sight count only while you're moving inside that list
  local pool = {}
  for _, r in ipairs(list) do
    if r.w ~= focus then
      local ok = true
      if r.scroll then
        local st, sb = r.scroll:GetTop(), r.scroll:GetBottom()
        local s = r.scroll:GetEffectiveScale() or 1
        local mid = (r.t + r.b) / 2
        if st and sb and (mid > st * s or mid < sb * s) and r.scroll ~= cur.scroll then ok = false end
      end
      if ok then pool[#pool + 1] = r end
    end
  end
  -- a widget can say where a direction leads (the Bestiary's buttons go back to the open beast's row)
  local to = focus.padNeighbor and focus.padNeighbor[dir]
  to = to and to()
  if to and to.IsVisible and to:IsVisible() then SetFocus(to) return end
  local i = ns.PadPick(cur, pool, dir)
  if i then SetFocus(pool[i].w) end
end

local function Click(button)
  local scope = Scope()
  if not scope then return end
  local list = Collect(scope, {})
  if not Find(list, focus) then SetFocus(Default(list, scope)) return end
  local before = ns.UI_Popup()
  if focus:IsObjectType("EditBox") then
    if button == "LeftButton" then focus:SetFocus() end
  else
    local ok, err = pcall(focus.Click, focus, button)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end
  -- a menu opened: the ring goes into it; anything else that took the ring's place away: start over
  local after = ns.UI_Popup()
  if after and after ~= before then
    SetFocus(Default(Collect(after, {}), after))
  elseif focus and not focus:IsVisible() then
    local f = ns.UI_Frame()
    SetFocus(f and f:IsShown() and Default(Collect(f, {}), f) or nil)
  end
end

local function Back()
  local popup, popupOwner = ns.UI_Popup()
  if popup then
    ns.UI_ClosePopups()
    SetFocus(popupOwner and popupOwner:IsVisible() and popupOwner or nil)
    return
  end
  if focus and focus.IsObjectType and focus:IsObjectType("EditBox") and focus.HasFocus and focus:HasFocus() then
    focus:ClearFocus()
    return
  end
  local page = ns.UI_PageButton()
  if page and focus and focus ~= page and focus:IsVisible() and focus:GetParent() ~= ns.UI_Sidebar() then
    SetFocus(page)
    return
  end
  local f = ns.UI_Frame()
  if f then f:Hide() end
end

local function Step(fn, dir)
  ns.UI_ClosePopups()
  fn(dir)
  SetFocus(ns.UI_PageButton())
  if not focus then
    local f = ns.UI_Frame()
    SetFocus(Default(Collect(f, {}), f))
  end
end

local ACT = {
  up = function() Move("up") end, down = function() Move("down") end,
  left = function() Move("left") end, right = function() Move("right") end,
  accept = function() Click("LeftButton") end, alt = function() Click("RightButton") end,
  back = Back,
  secprev = function() Step(ns.UI_StepSection, -1) end, secnext = function() Step(ns.UI_StepSection, 1) end,
  pageprev = function() Step(ns.UI_StepPage, -1) end, pagenext = function() Step(ns.UI_StepPage, 1) end,
}
ns.PadAct = ACT

-- The buttons the controller is bound to. A press arrives as a click (key down, and on most setups
-- key up too); the D-pad repeats while held.
local held, heldAt, nextAt = nil, 0, 0
local pressed = {}
local function Press(action, down)
  if down then
    pressed[action] = true
    ACT[action]()
    if REPEAT[action] then held, heldAt, nextAt = action, GetTime(), GetTime() + 0.38 end
  else
    if not pressed[action] then ACT[action]() end      -- a client that only sends the release
    pressed[action] = nil
    if held == action then held = nil end
  end
end
for _, action in pairs(KEYS) do
  local b = CreateFrame("Button", "UntamedPad_" .. action, owner)
  b:RegisterForClicks("AnyDown", "AnyUp")
  b:SetScript("OnClick", function(_, _, down)
    local ok, err = pcall(Press, action, down)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end)
end
owner:SetScript("OnUpdate", function()
  if not held then return end
  local now = GetTime()
  if not bound or now - heldAt > 6 then held = nil return end
  if now >= nextAt then
    nextAt = now + 0.11
    pcall(ACT[held])
  end
end)

local function PadOn()
  if ns.db and ns.db.pad == false then return false end
  if C_GamePad and C_GamePad.IsEnabled then
    local ok, on = pcall(C_GamePad.IsEnabled)
    if ok and on ~= nil and not ns.IsSecret(on) then return on and true or false end
  end
  return GetCVar and GetCVar("GamePadEnable") == "1"
end

local function Release()
  held = nil
  if not bound then return end
  if InCombatLockdown() then return end      -- can't happen: they're handed back as a fight starts
  ClearOverrideBindings(owner)
  bound = false
  status = "released"
  if ns.UI_PadHints then ns.UI_PadHints(false) end
end

local function Apply()
  local f = ns.UI_Frame()
  if bound or not f or not f:IsShown() or InCombatLockdown() or not PadOn() then return end
  if ns.UI_Hosted and ns.UI_Hosted() then return end -- in the Kit's window its own controller support drives it
  for key, action in pairs(KEYS) do
    SetOverrideBindingClick(owner, true, key, "UntamedPad_" .. action, "LeftButton")
  end
  bound = true
  -- did the buttons really come to Untamed? (another owner's binding can win)
  local got = GetBindingAction and GetBindingAction("PAD1", true)
  status = (got and not tostring(got):find("UntamedPad_accept", 1, true)) and ("bound, but Cross goes to: " .. tostring(got)) or "bound"
  if ns.UI_PadHints then ns.UI_PadHints(true) end
end

-- The buttons are taken only once none is held: if you open the window with a button combination,
-- the game still gets to see those buttons let go (its bars would stay shifted otherwise).
local pending, pendingAt = false, 0
local function AnyHeld()
  if not (C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetDeviceMappedState) then return nil end
  local ok, state = pcall(function() return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID()) end)
  if not ok or type(state) ~= "table" or type(state.buttons) ~= "table" then return nil end
  for _, down in pairs(state.buttons) do
    if ns.IsSecret(down) then return nil end
    if down then return true end
  end
  return false
end
local waiter = CreateFrame("Frame")
waiter:Hide()
waiter:SetScript("OnUpdate", function(self)
  if not pending then self:Hide() return end
  local f = ns.UI_Frame()
  if not f or not f:IsShown() then pending = false self:Hide() return end
  if InCombatLockdown() then return end
  local heldNow = AnyHeld()
  local waited = GetTime() - pendingAt
  if heldNow == false or (heldNow == nil and waited > 0.6) or waited > 5 then
    pending = false
    self:Hide()
    Apply()
  end
end)
function ns.Pad_Open()
  pending, pendingAt = true, GetTime()
  waiter:Show()
end
function ns.Pad_Close()
  pending = false
  Leave()
  focus = nil
  if ring then ring:Hide() end
  Release()
end
function ns.Pad_Active() return bound end
function ns.Pad_Status() return status .. (PadOn() and "" or " (no controller on)") end

owner:RegisterEvent("PLAYER_REGEN_DISABLED")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- a fight is starting: the controller goes back to the game before bindings lock
    held = nil
    if bound then
      ClearOverrideBindings(owner)
      bound = false
      status = "released for the fight"
      if ring then ring:Hide() end
      if ns.UI_PadHints then ns.UI_PadHints(false) end
    end
  else
    local f = ns.UI_Frame()
    if f and f:IsShown() then ns.Pad_Open() end
  end
end)

function ns.PadCommand(arg)
  if arg == "off" or arg == "on" then
    ns.db.pad = arg == "on"
    if ns.db.pad then ns.Pad_Open() else Release() end
    ns.Print(ns.db.pad and L["The controller works in Untamed's window (while it's open, out of fights)."]
      or L["The controller is left alone in Untamed's window (/ut pad on brings it back)."])
  else
    ns.Print(L["/ut pad on | off: the controller in Untamed's window. Now: "] .. ns.Pad_Status())
  end
end
