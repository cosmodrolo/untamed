local _, FLT = ...; FLT = FLT.Kit; if not FLT then return end
local UI = FLT.UI

---------------------------------------------------------------------------
-- OneForAll Pad: the controller in OneForAll's window.
--   D-pad      move to the nearest thing in that direction (tabs, buttons, rows, dropdowns, checkboxes)
--   Cross      select it (a left click)
--   Square     its second action (a right click: mark a library book, ...)
--   Circle     back: close a menu, then leave a text box, then close the window
--   L1 / R1    previous / next tab
-- How: while the window is open and you're not in a fight, those buttons are bound to buttons of
-- our own (override bindings owned by a frame of our own). Nothing of Blizzard's controller code is
-- touched, and the buttons are handed back the moment a fight starts or the window closes.
-- Everything the ring moves over is OneForAll's own frame. /ofapad off turns it off.
---------------------------------------------------------------------------

local KEYS = {
  PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right",
  PAD1 = "accept", PAD2 = "back", PAD3 = "alt",
  PADLSHOULDER = "tabprev", PADRSHOULDER = "tabnext",
}
-- L2 and R2 are left alone: the game's controller bars use them as held shifts.
local REPEAT = { up = true, down = true, left = true, right = true }

local owner = CreateFrame("Frame", "UntamedKitPadOwner", UIParent)
local bound, focus, ring = false, nil, nil
local status = "off"
local Pad = {}
FLT.Pad = Pad

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100OneForAll Pad:|r " .. msg) end
local function DB()
  if type(UntamedKitDB) ~= "table" then return {} end
  UntamedKitDB.pad = UntamedKitDB.pad or {}
  return UntamedKitDB.pad
end

local function Window() return _G.UntamedKitFrame end

-- Which of the rects is the best step from `f` in a direction. Rects are { l, r, t, b } in screen
-- units (t above b). Plain numbers in, an index out.
function Pad.Pick(f, rects, dir)
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

-- a button the ring can land on: shown, enabled, and does something when clicked
local function Clickable(w)
  if not w:IsObjectType("Button") then return false end
  if w.IsEnabled and not w:IsEnabled() then return false end
  return w:GetScript("OnClick") or w:GetScript("OnMouseUp") or w:GetScript("OnMouseDown")
end

-- everything you can move to under `root`: shown buttons, checkboxes, text boxes
local function Collect(root, out)
  for _, child in ipairs({ root:GetChildren() }) do
    if child ~= ring and child.IsShown and child:IsShown() and child.IsObjectType and not child.padSkip then
      if child:IsObjectType("Slider") or (root.ScrollBar and child == root.ScrollBar) then
        -- scroll bars and their arrows: the D-pad scrolls lists by moving through them
      else
        local isBox = child:IsObjectType("EditBox")
        if isBox or Clickable(child) then
          local r = Rect(child)
          if r and r.r > 0 and r.t > 0 then r.w = child; r.scroll = ScrollOf(child); out[#out + 1] = r end
        end
        if not isBox then Collect(child, out) end
      end
    end
  end
  return out
end

local function Scope()
  -- a menu of a page another addon put into the window (FLT.PadExtraMenu, set by that addon)
  if FLT.PadExtraMenu then
    local ok, menu, menuOwner = pcall(FLT.PadExtraMenu)
    if ok and menu then return menu, menuOwner end
  end
  if UI.PadOpenMenu then
    local menu, menuOwner = UI.PadOpenMenu()
    if menu then return menu, menuOwner end
  end
  return Window()
end

local function MakeRing()
  ring = CreateFrame("Frame", nil, UIParent)
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

-- a row scrolled out of sight: scroll its list so it shows
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
  ring:SetScale(w:GetEffectiveScale() / UIParent:GetEffectiveScale())
  ring:ClearAllPoints()
  ring:SetPoint("TOPLEFT", w, "TOPLEFT", -2, 2)
  ring:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 2, -2)
  ring:Show()
  -- the item tooltips and hover info come up just as with the mouse
  local f = w:GetScript("OnEnter")
  if f then pcall(f, w) end
end

local function Find(list, w)
  for i, r in ipairs(list) do if r.w == w then return i, r end end
end

local function Under(w, anc)
  local p = w
  for _ = 1, 20 do
    if not p then return false end
    if p == anc then return true end
    p = p:GetParent()
  end
  return false
end

-- where the ring starts: the top left thing on the page you're on (in a menu, its first entry)
local function Default(list, scope)
  local within
  if scope == Window() and UI.ActiveTab and UI.EnsurePanel then
    within = UI.EnsurePanel(UI.ActiveTab())
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
  local i = Pad.Pick(cur, pool, dir)
  if i then SetFocus(pool[i].w) end
end

local function Click(button)
  local scope = Scope()
  if not scope then return end
  local list = Collect(scope, {})
  if not Find(list, focus) then SetFocus(Default(list, scope)) return end
  local before = UI.PadOpenMenu and UI.PadOpenMenu()
  if focus:IsObjectType("EditBox") then
    if button == "LeftButton" then focus:SetFocus() end
  elseif focus:GetScript("OnClick") then
    local ok, err = pcall(focus.Click, focus, button)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  else
    -- a few rows react to the mouse button itself instead of a click
    local down, up = focus:GetScript("OnMouseDown"), focus:GetScript("OnMouseUp")
    if down then pcall(down, focus, button) end
    if up then pcall(up, focus, button) end
  end
  -- a menu opened: the ring goes into it; anything else that took the ring's place away: start over
  local after = UI.PadOpenMenu and UI.PadOpenMenu()
  if after and after ~= before then
    SetFocus(Default(Collect(after, {}), after))
  elseif focus and not focus:IsVisible() then
    local f = Window()
    SetFocus(f and f:IsShown() and Default(Collect(f, {}), f) or nil)
  end
end

local function Back()
  local menu, menuOwner
  if UI.PadOpenMenu then menu, menuOwner = UI.PadOpenMenu() end
  if menu then
    UI.PadCloseMenus()
    SetFocus(menuOwner and menuOwner:IsVisible() and menuOwner or nil)
    return
  end
  if FLT.PadExtraMenu then
    local ok, extra, extraOwner = pcall(FLT.PadExtraMenu)
    if ok and extra then
      if FLT.PadExtraClose then pcall(FLT.PadExtraClose) else extra:Hide() end
      SetFocus(extraOwner and extraOwner:IsVisible() and extraOwner or nil)
      return
    end
  end
  if focus and focus.IsObjectType and focus:IsObjectType("EditBox") and focus.HasFocus and focus:HasFocus() then
    focus:ClearFocus()
    return
  end
  local f = Window()
  if f then f:Hide() end
end

-- L1 / R1: the tabs in the order you see them (hidden ones skipped)
local function StepTab(dir)
  if not (UI.OrderedPanels and UI.ActiveTab and FLT.OpenPanel) then return end
  if UI.PadCloseMenus then UI.PadCloseMenus() end
  local keys, at = {}, nil
  for _, spec in ipairs(UI.OrderedPanels()) do
    if not UI.IsTabVisible or UI.IsTabVisible(spec.key) then
      keys[#keys + 1] = spec.key
      if spec.key == UI.ActiveTab() then at = #keys end
    end
  end
  if #keys == 0 then return end
  local nextKey = keys[((at or 1) - 1 + dir) % #keys + 1]
  FLT:OpenPanel(nextKey)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      local f = Window()
      if f and f:IsShown() then SetFocus(Default(Collect(f, {}), f)) end
    end)
  end
end

local ACT = {
  up = function() Move("up") end, down = function() Move("down") end,
  left = function() Move("left") end, right = function() Move("right") end,
  accept = function() Click("LeftButton") end, alt = function() Click("RightButton") end,
  back = Back,
  tabprev = function() StepTab(-1) end, tabnext = function() StepTab(1) end,
}
Pad.Act = ACT

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
  local b = CreateFrame("Button", "UntamedKitPad_" .. action, owner)
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
  if DB().off then return false end
  if C_GamePad and C_GamePad.IsEnabled then
    local ok, on = pcall(C_GamePad.IsEnabled)
    if ok and on ~= nil and not Secret(on) then return on and true or false end
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
end

local function Apply()
  local f = Window()
  if bound or not f or not f:IsShown() or InCombatLockdown() or not PadOn() then return end
  for key, action in pairs(KEYS) do
    SetOverrideBindingClick(owner, true, key, "UntamedKitPad_" .. action, "LeftButton")
  end
  bound = true
  -- did the buttons really come to us? (another owner's binding can win)
  local got = GetBindingAction and GetBindingAction("PAD1", true)
  status = (got and not tostring(got):find("UntamedKitPad_accept", 1, true)) and ("bound, but Cross goes to: " .. tostring(got)) or "bound"
end

-- The buttons are taken only once none is held: if you open the window with a button combination,
-- the game still gets to see those buttons let go (its bars would stay shifted otherwise).
local pending, pendingAt = false, 0
local function AnyHeld()
  if not (C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetDeviceMappedState) then return nil end
  local ok, state = pcall(function() return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID()) end)
  if not ok or type(state) ~= "table" or type(state.buttons) ~= "table" then return nil end
  for _, down in pairs(state.buttons) do
    if Secret(down) then return nil end
    if down then return true end
  end
  return false
end
local waiter = CreateFrame("Frame")
waiter:Hide()
waiter:SetScript("OnUpdate", function(self)
  if not pending then self:Hide() return end
  local f = Window()
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
function Pad.Open()
  pending, pendingAt = true, GetTime()
  waiter:Show()
end
function Pad.Close()
  pending = false
  Leave()
  focus = nil
  if ring then ring:Hide() end
  Release()
end
function Pad.Active() return bound end
function Pad.Status() return status .. (PadOn() and "" or " (no controller on)") end

-- The window is built the first time it opens: hook it once it exists.
local hooked = false
local function HookWindow()
  local f = Window()
  if hooked or not f then return end
  hooked = true
  f:HookScript("OnShow", function() Pad.Open() end)
  f:HookScript("OnHide", function() Pad.Close() end)
  if f:IsShown() then Pad.Open() end
end
local finder = CreateFrame("Frame")
finder:SetScript("OnUpdate", function(self, e)
  self.t = (self.t or 0) + e
  if self.t < 0.25 then return end
  self.t = 0
  HookWindow()
  if hooked then self:SetScript("OnUpdate", nil) end
end)

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
    end
  else
    local f = Window()
    if f and f:IsShown() then Pad.Open() end
  end
end)

SLASH_UNTAMEDKITPAD1 = "/ofapad"
SlashCmdList.UNTAMEDKITPAD = function(msg)
  msg = strtrim and strtrim(msg or ""):lower() or (msg or "")
  if msg == "off" or msg == "on" then
    DB().off = (msg == "off") or nil
    if DB().off then Release() else Pad.Open() end
    Print(DB().off and "the controller is left alone in OneForAll's window (/ofapad on brings it back)."
      or "the controller works in OneForAll's window (while it's open, out of fights).")
  elseif msg == "map off" or msg == "map on" then
    DB().mapOff = (msg == "map off") or nil
    if FLT.MapLandmarks and FLT.MapLandmarks.Refresh then pcall(FLT.MapLandmarks.Refresh) end
    Print(DB().mapOff and "map icons go back on Blizzard's map canvas (not seen in OpenMap's controller view, and may upset the controller)."
      or "map icons are shown on OpenMap's controller view.")
  else
    Print("D-pad moves, Cross selects, Square is the second action, Circle goes back, L1/R1 change tabs. /ofapad on | off, /ofapad map on | off. Now: " .. Pad.Status())
    local MP = FLT.PadMap
    if MP and MP.Status then
      local owns, n = MP.Status()
      Print(owns and ("map icons on OpenMap's controller view: " .. n .. ".") or "map icons: on Blizzard's map (Gamepad UI off, OpenMap missing, or /ofapad map off).")
    end
  end
end
