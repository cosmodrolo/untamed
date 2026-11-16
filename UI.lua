local _, ns = ...
local L = ns.L

-- Layout: roomier rows and section headings (v2.9 polish).
local ROW_H = 26          -- normal row
local HEAD_H = 30         -- section heading
local HEAD_GAP = 10       -- space above a heading (not the first)
local C = ns.C
function ns.Icon(path)
  if path:find("\\", 1, true) then return path end
  return "Interface\\Icons\\" .. path
end

---------------------------------------------------------------------------
-- The look: "Savage Land". Deep jungle green panels, thin moss lines, amber for what's selected
-- or the thing to press. Every page is drawn through the helpers in this file, so the look lives
-- here: change these colors and the whole window follows.
---------------------------------------------------------------------------
local T = {
  window = { 0.062, 0.102, 0.074 },   -- the window itself
  bar    = { 0.040, 0.068, 0.048 },   -- title bar, section bar
  panel  = { 0.086, 0.141, 0.100 },   -- the list and page panels
  deep   = { 0.043, 0.074, 0.052 },   -- model boxes, pages, menus
  button = { 0.130, 0.205, 0.140 },   -- a button at rest
  line   = { 0.240, 0.350, 0.180 },   -- thin edges
  accent = { 0.940, 0.700, 0.240 },   -- amber
  ink    = { 0.230, 0.150, 0.020 },   -- text on amber
}
ns.Theme = T

-- shade a texture from one color to another (flat if this client can't)
function ns.Gradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
  if not (tex.SetGradient and CreateColor) then return false end
  tex:SetColorTexture(1, 1, 1, 1)
  return (pcall(tex.SetGradient, tex, orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)))
end

-- a fill and (optionally) a one-pixel edge on a frame of ours. `lift` shades the fill top to bottom
-- for depth: 0.3 is lighter at the top (panels, buttons), -0.5 lighter at the bottom (a lit floor).
function ns.Skin(f, fill, alpha, edge, edgeAlpha, lift)
  if not rawget(f, "skinFill") then f.skinFill = f:CreateTexture(nil, "BACKGROUND") f.skinFill:SetAllPoints() end
  f.skinFill:SetColorTexture(fill[1], fill[2], fill[3], alpha or 1)
  if lift then
    local lo, hi = 1 - math.abs(lift), 1 + math.abs(lift)
    if lift < 0 then lo, hi = hi, lo end
    ns.Gradient(f.skinFill, "VERTICAL", fill[1] * lo, fill[2] * lo, fill[3] * lo, alpha or 1, fill[1] * hi, fill[2] * hi, fill[3] * hi, alpha or 1)
  end
  if edge then
    if not rawget(f, "skinEdges") then
      f.skinEdges = {}
      for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(pts[1]); t:SetPoint(pts[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        f.skinEdges[i] = t
      end
    end
    for _, t in ipairs(f.skinEdges) do t:SetColorTexture(edge[1], edge[2], edge[3], edgeAlpha or 1) end
  end
end
local Skin = ns.Skin

-- amber brackets in the corners of a box (model boxes, cards)
function ns.Corners(f, len, alpha)
  len = len or 12
  for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
    for k = 1, 2 do
      local t = f:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], alpha or 0.85)
      t:SetPoint(c[1], f, c[1], c[2], c[3])
      if k == 1 then t:SetSize(len, 2) else t:SetSize(2, len) end
    end
  end
end

-- amber buttons carry dark text
local primaryFont
if CreateFont then
  primaryFont = CreateFont("UntamedFontOnAmber")
  if primaryFont and primaryFont.CopyFontObject then
    primaryFont:CopyFontObject(GameFontNormal)
    primaryFont:SetTextColor(T.ink[1], T.ink[2], T.ink[3])
  else
    primaryFont = nil
  end
end

---------------------------------------------------------------------------
-- Generic scrolling list
---------------------------------------------------------------------------
local function ShowTooltip(owner, tip)
  if type(tip) == "function" then tip = tip() end
  if not tip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local first = 1
  if tip.itemID and GameTooltip.SetItemByID then
    -- Real item tooltip first, then our lines (skipping the name).
    GameTooltip:SetItemByID(tip.itemID)
    GameTooltip:AddLine(" ")
    first = 2
  end
  for idx, line in ipairs(tip) do
    if idx < first then line = "" end
    if line ~= "" then
      if idx == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
  end
  GameTooltip:Show()
end
ns.ShowTooltip = ShowTooltip

local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"

-- rows: { {indent, iconPath, leftText, rightText, onClick, tooltip, opts}, ... }
-- opts (optional): header = true (section heading), toggle = true/false (expanded or collapsed),
-- mid = text for the middle column (level), toggleSpace = true (line up with toggled rows).
function ns.NewList(parent, topOffset)
  local list = { rows = {} }
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 2, -topOffset)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(440, 1)
  scroll:SetScrollChild(content)
  scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
  list.scroll, list.content = scroll, content

  local function GetRow(i)
    local r = list.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    -- headings: an amber band that fades out to the right
    r.band = r:CreateTexture(nil, "BACKGROUND")
    r.band:SetAllPoints()
    if not ns.Gradient(r.band, "HORIZONTAL", T.accent[1], T.accent[2], T.accent[3], 0.26, T.accent[1], T.accent[2], T.accent[3], 0) then
      r.band:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.09)
    end
    r.band:Hide()
    r.toggle = r:CreateTexture(nil, "ARTWORK")
    r.toggle:SetSize(14, 14)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.left:SetJustifyH("LEFT")
    r.left:SetWordWrap(false)
    r.mid = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.mid:SetJustifyH("LEFT")
    r.mid:SetWordWrap(false)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetJustifyH("RIGHT")
    r.right:SetPoint("RIGHT", -10, 0)
    r.right:SetWordWrap(false)
    r.rule = r:CreateTexture(nil, "ARTWORK")
    r.rule:SetPoint("BOTTOMLEFT", 4, 0)
    r.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    r.rule:SetHeight(1)
    r.rule:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.4)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    r:SetScript("OnEnter", function(self) if self.tooltip then ShowTooltip(self, self.tooltip) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    list.rows[i] = r
    return r
  end

  function list:Set(data)
    local stripe, y = 0, 0
    for i, d in ipairs(data) do
      local r = GetRow(i)
      local indent, iconPath, o = d[1] or 0, d[2], d[7] or {}
      if o.header and i > 1 then y = y + HEAD_GAP end
      local h = o.header and HEAD_H or ROW_H
      r:SetHeight(h)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
      y = y + h

      -- section headings: a soft gold band with a rule under it; other rows alternate a faint stripe
      if o.header then
        r.bg:Hide(); r.band:Show(); r.rule:Show(); stripe = 0
      else
        r.band:Hide()
        r.rule:Hide()
        stripe = stripe + 1
        if stripe % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.035); r.bg:Show() else r.bg:Hide() end
      end
      r.left:SetFontObject(o.header and "GameFontNormalLarge" or "GameFontHighlight")
      r.icon:SetSize(o.header and 22 or 20, o.header and 22 or 20)

      local x = 8 + indent
      r.toggle:ClearAllPoints()
      if o.toggle ~= nil then
        r.toggle:SetTexture(o.toggle and MINUS or PLUS)
        r.toggle:SetPoint("LEFT", x, 0)
        r.toggle:Show()
        x = x + 18
      else
        r.toggle:Hide()
        if o.toggleSpace then x = x + 18 end
      end
      r.icon:ClearAllPoints()
      r.left:ClearAllPoints()
      if iconPath then
        r.icon:SetTexture(iconPath); r.icon:SetPoint("LEFT", x, 0); r.icon:Show()
        r.left:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
      else
        r.icon:Hide()
        r.left:SetPoint("LEFT", x, 0)
      end

      r.right:SetText(d[4] or "")
      if o.mid then
        r.right:SetWidth(220)
        r.mid:ClearAllPoints()
        r.mid:SetPoint("RIGHT", r.right, "LEFT", -12, 0)
        r.mid:SetWidth(96)
        r.mid:SetText(o.mid)
        r.mid:Show()
        r.left:SetPoint("RIGHT", r.mid, "LEFT", -12, 0)
      else
        r.right:SetWidth(0)
        r.mid:Hide()
        r.left:SetPoint("RIGHT", r.right, "LEFT", -12, 0)
      end
      r.left:SetText(d[3] or "")
      r.onClick, r.tooltip = d[5], d[6]
      r:Show()
    end
    for j = #data + 1, #list.rows do list.rows[j]:Hide() end
    content:SetHeight(math.max(1, y + 6))
  end
  return list
end

-- Controls redraw their state whenever the window refreshes (after a reset, a slash command, ...).
local liveControls = {}
function ns.RefreshControls()
  for _, c in ipairs(liveControls) do
    if c:IsVisible() then
      if c.Update then c:Update() elseif c.getter then c:SetChecked(c.getter()) end
    end
  end
end

function ns.MakeCheck(parent, label, x, y, get, set, tip)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(22, 22)
  c:SetPoint("TOPLEFT", x, y)
  local fs = c.text or c.Text or c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetFontObject("GameFontHighlightSmall")
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", c, "RIGHT", 0, 1)
  fs:SetText(label)
  c.label = fs
  c:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); ns.Refresh() end)
  if tip then
    c:SetScript("OnEnter", function(self) ShowTooltip(self, { label, tip }) end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  c:SetChecked(get())
  c.getter = get
  liveControls[#liveControls + 1] = c
  return c
end

-- Labels on buttons and dropdowns stay on one line; the control grows to fit instead.
local function OneLine(fs)
  if not fs then return end
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetMaxLines then fs:SetMaxLines(1) end
end
ns.OneLine = OneLine

-- Width of a label in this button's font.
local function TextWidth(b, text)
  local fs = b.GetFontString and b:GetFontString()
  if not fs or not fs.GetStringWidth then return #(text or "") * 7 end
  local old = fs:GetText()
  fs:SetText(text or "")
  local w = fs:GetStringWidth() or 0
  fs:SetText(old)
  return w
end
ns.TextWidth = TextWidth

-- A flat button: moss at rest, a little lighter under the cursor. b:SetPrimary(true) makes it the
-- amber one (the thing to press on a page).
function ns.MakeButton(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 24)
  Skin(b, T.button, 1, T.line, 1, 0.22)
  if b.SetFontString then
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 0)
    b:SetFontString(fs)
  end
  if b.SetNormalFontObject then
    b:SetNormalFontObject("GameFontNormal")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetDisabledFontObject("GameFontDisable")
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.10)
  b:SetText(text)
  OneLine(b.GetFontString and b:GetFontString())
  local need = math.ceil(TextWidth(b, text)) + 24
  if need > w then b:SetWidth(need) end
  -- a pressed look: the label drops a pixel
  if b.SetPushedTextOffset then b:SetPushedTextOffset(1, -1) end
  function b:SetPrimary(on)
    if on then
      Skin(self, T.accent, 1, T.accent, 1, 0.12)
      if primaryFont and self.SetNormalFontObject then self:SetNormalFontObject(primaryFont); self:SetHighlightFontObject(primaryFont) end
    else
      Skin(self, T.button, 1, T.line, 1, 0.22)
      if self.SetNormalFontObject then self:SetNormalFontObject("GameFontNormal"); self:SetHighlightFontObject("GameFontHighlight") end
    end
  end
  b:SetScript("OnClick", onClick)
  return b
end

-- A dark box with a slowly turning 3D model, for journal pages. box:Beast(npcId, icon) shows a
-- creature, box:Unit("pet", icon) a unit; the icon stands in while the game has no model to show
-- (the first look at a beast comes up empty: it asks again until it's there).
function ns.MakeModelBox(parent, size)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(size, size)
  Skin(box, T.deep, 1, T.line, 1, -0.55)
  ns.Corners(box)
  box.icon = box:CreateTexture(nil, "BORDER")
  box.icon:SetSize(64, 64)
  box.icon:SetPoint("CENTER")
  box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  box.icon:SetAlpha(0.35)
  box.model = CreateFrame("PlayerModel", nil, box)
  box.model:SetAllPoints()
  box.facing, box.kind, box.what, box.tries, box.wait, box.picture = 0.5, false, false, 0, 0, false
  local function Apply()
    local m = box.model
    local ok
    if box.kind == "unit" then ok = m.SetUnit and pcall(m.SetUnit, m, box.what)
    elseif box.kind == "beast" then ok = m.SetCreature and pcall(m.SetCreature, m, box.what) end
    if ok and m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, 1.55) end
    if ok and m.SetFacing then pcall(m.SetFacing, m, box.facing) end
    return ok
  end
  local function Set(kind, what, icon)
    if box.picture then box.picture = false; box.icon:SetSize(64, 64); box.icon:SetAlpha(0.35) end
    box.icon:SetTexture(icon)
    if box.kind == kind and box.what == what then return end
    box.kind, box.what, box.tries, box.wait, box.facing = kind or false, what or false, 0, 0, 0.5
    if box.model.ClearModel then pcall(box.model.ClearModel, box.model) end
    local ok = what and Apply()
    box.model:SetShown(ok and true or false)
    box.icon:SetShown(not ok)
  end
  function box:Beast(npcId, icon) Set("beast", npcId, icon) end
  function box:Unit(unit, icon) Set("unit", unit, icon) end
  function box:Nothing(icon) Set(nil, nil, icon) end
  -- a plain picture instead of a model (an ability's icon)
  function box:Picture(icon)
    Set(nil, nil, icon)
    box.picture = true
    box.icon:SetSize(96, 96); box.icon:SetAlpha(1); box.icon:Show()
  end
  box.model:SetScript("OnUpdate", function(self, e)
    box.facing = (box.facing + e * 0.35) % (2 * math.pi)
    if self.SetFacing then self:SetFacing(box.facing) end
    if not self.GetModelFileID then return end
    local ok, file = pcall(self.GetModelFileID, self)
    if not ok then return end
    box.icon:SetShown(not file)
    if not file and box.what and (box.tries or 0) < 20 then
      box.wait = (box.wait or 0) + e
      if box.wait >= 0.5 then box.wait, box.tries = 0, box.tries + 1; Apply() end
    end
  end)
  return box
end

-- A small heading with a thin rule under it, for journal pages.
function ns.MakeHeading(parent, text)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h:SetText(text)
  local rule = parent:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
  rule:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
  rule:SetHeight(1)
  rule:SetColorTexture(T.line[1], T.line[2], T.line[3], 0.9)
  return h
end

-- A journal page: a list column on the left, a page on the right with a model box, a name, a
-- line under it, facts, one row of buttons, and headed paragraphs. The page follows the list:
-- j:Select(key) turns it (and the controller's frame landing on a row does the same).
--   local j = ns.MakeJournal(panel, emptyText)
--   j.left (put a toolbar and list in it; set j.list), j.box, j.name, j.sub
--   j:Tile(label), j:Buttons({ { text, width, onClick, tip }, ... }), j:Section(title) -> fontstring
--   j.onSelect = function(key) fill the page end;  rows: onClick = j:RowClick(key, again), tooltip = j:RowHover(key)
--   after list:Set(rows): j:Rows(keysByRowIndex)
function ns.MakeJournal(panel, emptyText)
  local j = { rowKeys = {} }
  j.left = CreateFrame("Frame", nil, panel)
  j.left:SetPoint("TOPLEFT", 0, 0)
  j.left:SetPoint("BOTTOMLEFT", 0, 0)
  j.left:SetWidth(340)
  local page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", j.left, "TOPRIGHT", 10, 0)
  page:SetPoint("BOTTOMRIGHT", -4, 4)
  Skin(page, T.deep, 0.55, T.line, 0.6)
  j.page = page
  j.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  j.empty:SetPoint("CENTER")
  j.empty:SetWidth(300)
  j.empty:SetText(emptyText or "")
  local body = CreateFrame("Frame", nil, page)
  body:SetAllPoints()
  j.body = body
  j.box = ns.MakeModelBox(body, 210)
  j.box:SetPoint("TOPLEFT", 12, -12)
  j.name = body:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  j.name:SetPoint("TOPLEFT", j.box, "TOPRIGHT", 14, -2)
  j.name:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  j.name:SetJustifyH("LEFT")
  j.name:SetWordWrap(false)
  j.sub = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  j.sub:SetPoint("TOPLEFT", j.name, "BOTTOMLEFT", 0, -5)
  j.sub:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  j.sub:SetJustifyH("LEFT")
  j.sub:SetWordWrap(false)

  local lastTile
  function j:Tile(label)
    local t = {}
    t.label = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.label:SetText(label)
    if lastTile then t.label:SetPoint("TOPLEFT", lastTile.label, "BOTTOMLEFT", 0, -30)
    else t.label:SetPoint("TOPLEFT", j.sub, "BOTTOMLEFT", 0, -16) end
    t.value = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
    t.value:SetPoint("RIGHT", body, "RIGHT", -10, 0)
    t.value:SetJustifyH("LEFT")
    t.value:SetWordWrap(false)
    lastTile = t
    return t
  end

  local lastBlock
  function j:Buttons(defs)
    local out, prev = {}, nil
    for i, d in ipairs(defs) do
      local b = ns.MakeButton(body, d[1], d[2], d[3])
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", j.box, "BOTTOMLEFT", 0, -12) end
      if d[4] then
        b:SetScript("OnEnter", function(self) ShowTooltip(self, d[4]) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      out[i], prev = b, b
    end
    -- on a controller, left from the buttons goes back to the open row
    if out[1] then
      out[1].padNeighbor = { left = function()
        for i, k in pairs(j.rowKeys) do if k == j.selected then return j.list and j.list.rows[i] end end
      end }
    end
    if out[1] then out[1]:SetPrimary(true) end
    lastBlock = out[1]
    return out
  end

  function j:Section(title, font)
    local h = ns.MakeHeading(body, title)
    h:SetPoint("TOPLEFT", lastBlock or j.box, "BOTTOMLEFT", 0, -18)
    local fs = body:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
    fs:SetPoint("RIGHT", body, "RIGHT", -12, 0)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(5)
    lastBlock = fs
    return fs, h
  end

  local function Paint(i, on)
    local r = j.list and j.list.rows[i]
    if not r or j.rowKeys[i] == nil then return end
    if on then r.bg:SetColorTexture(1, 0.82, 0, 0.20); r.bg:Show()
    elseif (i - 1) % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.04); r.bg:Show()
    else r.bg:Hide() end
  end
  local function Fill()
    local has = j.selected ~= nil
    j.empty:SetShown(not has)
    body:SetShown(has)
    if has and j.onSelect then j.onSelect(j.selected) end
  end
  function j:Select(key)
    if j.selected == key then return end
    for i, k in pairs(j.rowKeys) do if k == j.selected then Paint(i, false) end end
    j.selected = key
    for i, k in pairs(j.rowKeys) do if k == key then Paint(i, true) end end
    Fill()
  end
  -- after list:Set: which key each row is; keeps the page on a key that's still listed
  function j:Rows(keys, order)
    wipe(j.rowKeys)
    local keep, first = false, nil
    for i, k in pairs(keys) do j.rowKeys[i] = k; if k == j.selected then keep = true end end
    if not keep then j.selected = order and order[1] or nil end
    for i, k in pairs(j.rowKeys) do if k == j.selected then Paint(i, true) end end
    Fill()
  end
  -- a click opens the page; a click on the open one (or Cross on a controller) does `again`
  function j:RowClick(key, again, alt)
    return function(_, button)
      if button == "RightButton" then j:Select(key); if alt then alt(key) end
      elseif j.selected == key then if again then again(key) end
      else j:Select(key) end
    end
  end
  function j:RowHover(key)
    return function() if ns.padFocusing then j:Select(key) end return nil end
  end
  return j
end

-- A sunken Blizzard inset panel (falls back to a dark backdrop).
function ns.MakeInset(parent)
  local f = CreateFrame("Frame", nil, parent)
  Skin(f, T.panel, 0.92, T.line, 1, 0.12)
  return f
end

-- A flat text button for menus and the sidebar.
function ns.MakeFlatButton(parent, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(h or 20)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize((h or 20) - 6, (h or 20) - 6)
  b.icon:SetPoint("LEFT", 6, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetPoint("RIGHT", -4, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.16)
  b.sel:Hide()
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(3)
  b.bar:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
  b.bar:Hide()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  function b:SetSelected(v) self.sel:SetShown(v); self.bar:SetShown(v); self.text:SetFontObject(v and "GameFontNormal" or "GameFontHighlight") end
  return b
end

-- A dropdown button: shows the chosen option and opens a menu of options.
-- options: { { key, label }, ... } (a label of false makes a heading-less divider)
local ddMenu, ddButtons = nil, {}
function ns.MakeDropdown(parent, width, options, get, set, tip)
  local b = ns.MakeButton(parent, "", width, nil)
  local arrow = b:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  arrow:SetSize(16, 16)
  arrow:SetPoint("RIGHT", -3, 0)
  local fs = b.GetFontString and b:GetFontString()
  if fs then fs:ClearAllPoints(); fs:SetPoint("LEFT", 8, 0); fs:SetPoint("RIGHT", -18, 0); fs:SetJustifyH("LEFT"); OneLine(fs) end
  -- Wide enough for the longest choice (8 px text inset + 18 px for the arrow + a little air).
  function b:FitOptions()
    local widest = 0
    for _, o in ipairs(type(options) == "function" and options() or options) do
      widest = math.max(widest, TextWidth(self, o[2]))
    end
    local need = math.ceil(widest) + 8 + 18 + 8
    if need > self:GetWidth() then self:SetWidth(need) end
    width = math.max(width, self:GetWidth())
  end
  b:FitOptions()
  function b:Update()
    local cur = get()
    for _, o in ipairs(type(options) == "function" and options() or options) do
      if o[1] == cur then self:SetText(o[2]) return end
    end
    self:SetText("?")
  end
  b:SetScript("OnClick", function(self)
    if not ddMenu then
      ddMenu = CreateFrame("Frame", nil, UIParent)
      ddMenu:SetFrameStrata("FULLSCREEN_DIALOG")
      Skin(ddMenu, T.deep, 0.98, T.accent, 0.7)
      if false then
        ddMenu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
      end
      ddMenu:EnableMouse(true)
      ddMenu:Hide()
    end
    if ddMenu:IsShown() and ddMenu.owner == self then ddMenu:Hide() return end
    ddMenu.owner = self
    for _, x in ipairs(ddButtons) do x:Hide() end
    local opts = type(options) == "function" and options() or options
    local cols = #opts > 16 and 2 or 1
    local colW = math.max(width, 150)
    local perCol = math.ceil(#opts / cols)
    for i, o in ipairs(opts) do
      local mb = ddButtons[i]
      if not mb then mb = ns.MakeFlatButton(ddMenu, 18); ddButtons[i] = mb end
      mb:ClearAllPoints()
      local col, rowi = math.floor((i - 1) / perCol), (i - 1) % perCol
      mb:SetPoint("TOPLEFT", 6 + col * colW, -8 - rowi * 18)
      mb:SetWidth(colW - 4)
      mb.icon:SetTexture(nil)
      mb.icon:SetWidth(1)
      mb.text:SetText(o[2])
      mb:SetSelected(o[1] == get())
      mb:SetScript("OnClick", function() ddMenu:Hide(); set(o[1]); self:Update(); ns.UI_Refresh() end)
      mb:Show()
    end
    ddMenu:SetSize(cols * colW + 12, perCol * 18 + 16)
    ddMenu:ClearAllPoints()
    ddMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    ddMenu:Show()
  end)
  if tip then
    b:SetScript("OnEnter", function(self) ShowTooltip(self, tip) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b:Update()
  liveControls[#liveControls + 1] = b
  return b
end
function ns.CloseDropdown() if ddMenu then ddMenu:Hide() end end

-- Toolbar: every page lays out its controls the same way, left to right in rows of 26 px.
--   local tb = ns.Toolbar(panel)
--   tb:Search(hint, width, onChange)  tb:Dropdown(width, options, get, set, tip)  tb:Check(label, get, set, tip)
--   tb:Button(text, width, onClick)   tb:Row()   local list = tb:List()
function ns.Toolbar(panel)
  local tb = { x = 6, row = 0 }
  local function y() return -4 - tb.row * 32 end
  local function place(w)
    local pw = panel.GetWidth and panel:GetWidth() or 0
    if pw > 0 and tb.x > 6 and tb.x + w > pw - 6 then tb.row = tb.row + 1; tb.x = 6 end
    local x = tb.x; tb.x = tb.x + w + 12; return x
  end
  function tb:Row() self.row = self.row + 1; self.x = 6 end
  function tb:Search(hint, width, onChange)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(width, 22)
    box:SetPoint("TOPLEFT", place(width + 6) + 6, y() - 1)
    box:SetAutoFocus(false)
    box:SetScript("OnTextChanged", function(self) onChange((self:GetText() or ""):lower()); ns.UI_Refresh() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    h:SetPoint("LEFT", 4, 0)
    h:SetText(hint)
    box:HookScript("OnEditFocusGained", function() h:Hide() end)
    box:HookScript("OnEditFocusLost", function(self) h:SetShown((self:GetText() or "") == "") end)
    box.hint = h
    return box
  end
  function tb:Dropdown(width, options, get, set, tip)
    local d = ns.MakeDropdown(panel, width, options, get, set, tip)
    local w = d:GetWidth()
    local x = place(w)
    d:SetPoint("TOPLEFT", x, y())
    return d
  end
  function tb:Check(label, get, set, tip)
    local c = ns.MakeCheck(panel, label, tb.x, y(), get, set, tip)
    local fs = c.label
    local w = 24 + ((fs and fs.GetStringWidth and fs:GetStringWidth()) or (#label * 6))
    place(w + 4)
    return c
  end
  function tb:Button(text, width, onClick)
    local b = ns.MakeButton(panel, text, width, onClick)
    local x = place(b:GetWidth())
    b:SetPoint("TOPLEFT", x, y())
    return b
  end
  function tb:List()
    -- a thin divider between the controls and the list
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 4, -((self.row + 1) * 32 + 2))
    line:SetPoint("TOPRIGHT", -4, -((self.row + 1) * 32 + 2))
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.08)
    return ns.NewList(panel, (self.row + 1) * 32 + 8)
  end
  return tb
end

---------------------------------------------------------------------------
-- Shared helpers for beast rows
---------------------------------------------------------------------------
function ns.ZonesText(b)
  if b[8] then return C.ORANGE .. b[8] .. "|r" end
  local names = {}
  for mapID in pairs(b[7]) do names[#names + 1] = ns.ZoneName(mapID) end
  table.sort(names)
  if #names == 0 then return C.GREY .. "unknown|r" end
  if #names > 2 then return names[1] .. ", " .. names[2] .. " +" .. (#names - 2) end
  return table.concat(names, ", ")
end

-- Tooltip with travel advice for a beast (computed when you hover).
function ns.BeastTooltip(npcId, extra)
  return function()
    local b = ns.Beasts[npcId]
    local lines = { b[1], L["Level "] .. ns.LevelText(b) .. " " .. b[4] .. ((b[2] > UnitLevel("player")) and C.RED .. "  (too high to tame yet)|r" or "") }
    if #b[6] > 0 then lines[#lines + 1] = L["Teaches: "] .. ns.TeachesText(b) end
    if b[9] then lines[#lines + 1] = L["Attack speed: "] .. b[9] .. (b[10] and ("   Look: " .. b[10]) or "") end
    if b[8] then lines[#lines + 1] = C.ORANGE .. L["Inside "] .. b[8] .. ". Map pins mark the entrance.|r" end
    local mapID, x, y, d = ns.NearestSpawn(npcId)
    if mapID then
      lines[#lines + 1] = string.format("Nearest: %s %.0f, %.0f (%s)", ns.ZoneName(mapID), x, y, ns.FormatDistance(d))
      local s, sd = ns.NearestService("S", mapID, x, y)
      local f, fd = ns.NearestService("F", mapID, x, y)
      lines[#lines + 1] = C.BLUE .. L["Stable master: "] .. ns.ServiceText(s, sd) .. "|r"
      lines[#lines + 1] = C.BLUE .. L["Flight master: "] .. ns.ServiceText(f, fd) .. "|r"
    end
    if extra then for _, l in ipairs(extra) do lines[#lines + 1] = l end end
    lines[#lines + 1] = C.GREY .. "Click: arrow + map pins.  Right-click: open map.  Shift-click: TomTom.|r"
    return lines
  end
end

function ns.BeastClick(npcId)
  return function(_, button)
    if IsShiftKeyDown() then ns.Waypoint(npcId) return end
    if IsAltKeyDown() and ns.WishBeast_Toggle then ns.WishBeast_Toggle(npcId) return end
    local b = ns.Beasts[npcId]
    if button == "RightButton" then
      ns.Pins_Focus({ npcId }, b[1], true)
    else
      ns.Navigate(npcId)
    end
  end
end

---------------------------------------------------------------------------
-- Main window: header, sidebar, content and status bar
---------------------------------------------------------------------------
local frame, content, statusText, versionText
local header = {}
local tabs, activeTab = {}, nil

-- Where each tab lives in the sidebar.
local TAB_META = {
  abilities = { icon = "Ability_Hunter_BeastTraining", sub = L["What your pet can learn, and which beasts teach it"] },
  builds    = { icon = "INV_Misc_Book_09", sub = L["Plan how to spend your pet's training points"] },
  care      = { icon = "INV_Misc_Food_14", sub = L["Happiness, food and where to level your pet"] },
  stable    = { icon = "Ability_Hunter_BeastCall", sub = L["Every pet you own, and what you can teach each one"] },
  recommend = { icon = "Ability_Hunter_BeastTaming", sub = L["Pick a role and get the best family and beasts for it"] },
  plan      = { icon = "INV_Misc_Map_01", sub = L["A route to tame the beasts your pet still needs"] },
  rares     = { icon = "Ability_Hunter_SniperShot", sub = L["Rares near you, and the ones you've seen"] },
  browse    = { icon = "INV_Misc_Spyglass_03", sub = L["Every tameable beast: its model, what it teaches and where it is"] },
  search    = { icon = "INV_Misc_Spyglass_02", sub = L["Find any item, NPC or beast and where to get it"] },
  supplies  = { icon = "INV_Ammo_Arrow_02", sub = L["Ammo, quivers and food for your pet"] },
  spells    = { icon = "INV_Misc_Book_11", sub = L["What to train at each level and what it costs"] },
  talents   = { icon = "Ability_Hunter_SniperShot", sub = L["Talent builds, with the next point highlighted"] },
  rotation  = { icon = "Ability_Hunter_RunningShot", sub = L["What to press in a fight, macros and where they go on the controller"] },
  gear      = { icon = "INV_Weapon_Bow_07", sub = L["Your next upgrades, and how to get them"] },
  books     = { icon = "INV_Misc_Book_09", sub = L["Library books: where they are, and which you've handed in"] },
  wishlist  = { icon = "INV_Misc_Note_01", sub = L["Items you want, with their sources on your map"] },
  dungeons  = { icon = "INV_Misc_Key_03", sub = L["Hunter loot, bosses and beasts in each dungeon"] },
  reputation = { icon = "INV_Misc_Token_ArgentDawn", sub = L["Reputation you need for rewards you want"] },
  quests    = { icon = "INV_Misc_Note_02", sub = L["Class quests only hunters can do"] },
  home      = { icon = "Interface\\AddOns\\Untamed\\Media\\Icon", sub = L["What's worth doing right now"] },
  settings  = { icon = "INV_Misc_Gear_01", sub = L["Alerts, pins and data sharing"] },
}
-- Six sections along the top; each page lives in one of them (the list on the left shows the
-- pages of the section you're in). Settings is the gear at the right end.
local SECTIONS = {
  { key = "today",    title = L["Today"],    icon = "INV_Misc_PocketWatch_01" },
  { key = "bestiary", title = L["Bestiary"], icon = "Ability_Hunter_BeastTaming" },
  { key = "pets",     title = L["My Pets"],  icon = "Ability_Hunter_BeastCall" },
  { key = "hunter",   title = L["Hunter"],   icon = "Ability_Hunter_RunningShot" },
  { key = "gear",     title = L["Gear"],     icon = "INV_Weapon_Bow_07" },
  { key = "world",    title = L["World"],    icon = "INV_Misc_Map_01" },
}
local SECTION_OF = {
  home = { "today", 1 },
  browse = { "bestiary", 1 }, recommend = { "bestiary", 2 }, rares = { "bestiary", 3 }, plan = { "bestiary", 4 },
  abilities = { "pets", 1 }, builds = { "pets", 2 }, care = { "pets", 3 }, stable = { "pets", 4 },
  spells = { "hunter", 1 }, talents = { "hunter", 2 }, rotation = { "hunter", 3 }, quests = { "hunter", 4 },
  gear = { "gear", 1 }, wishlist = { "gear", 2 }, dungeons = { "gear", 3 }, reputation = { "gear", 4 }, supplies = { "gear", 5 },
  books = { "world", 1 }, search = { "world", 2 },
  settings = { "settings", 1 },
}
local sectionByKey = {}
for i, sec in ipairs(SECTIONS) do sec.index = i; sectionByKey[sec.key] = sec end
local activeSection
local side, sectionBar
local LayoutSidebar

function ns.RegisterTab(key, title, build, refresh)
  local meta = TAB_META[key] or { icon = "INV_Misc_QuestionMark" }
  local where = SECTION_OF[key] or { "world", 99 }
  meta.sec, meta.order = where[1], where[2]
  tabs[key] = { key = key, title = title, build = build, refresh = refresh, meta = meta }
end

-- the pages of a section, in order
local function SectionPages(secKey)
  local list = {}
  for _, t in pairs(tabs) do if t.meta.sec == secKey then list[#list + 1] = t end end
  table.sort(list, function(a, b) if a.meta.order ~= b.meta.order then return a.meta.order < b.meta.order end return a.key < b.key end)
  return list
end

local function SelectTab(key)
  if not tabs[key] then key = "abilities" end
  activeTab = key
  for k, t in pairs(tabs) do
    if t.panel then t.panel:SetShown(k == key) end
    if t.button then t.button:SetSelected(k == key) end
  end
  local t = tabs[key]
  -- the section this page lives in: its button lights up, its pages fill the list on the left
  activeSection = t.meta.sec
  ns.db.lastPage = ns.db.lastPage or {}
  ns.db.lastPage[activeSection] = key
  if sectionBar then
    for _, sec in ipairs(SECTIONS) do if sec.button then sec.button:SetSelected(sec.key == activeSection) end end
    if sectionBar.gear then sectionBar.gear:SetSelected(activeSection == "settings") end
  end
  if LayoutSidebar then LayoutSidebar() end
  content.title:SetText(t.title)
  content.sub:SetText(t.meta.sub or "")
  if not t.panel then
    t.panel = CreateFrame("Frame", nil, content)
    t.panel:SetPoint("TOPLEFT", 8, -56)
    t.panel:SetPoint("BOTTOMRIGHT", -6, 6)
    t.build(t.panel)
  end
  t.panel:Show()
  ns.UI_Refresh()
end

---------------------------------------------------------------------------
-- Header: who you're planning for, pet bars, and the "Viewing" picker
---------------------------------------------------------------------------
local function ViewingLabel()
  local s = ns.state
  if s.mode == "manual" and s.family then return L["Viewing: "] .. ns.FamilyLabel(s.family) end
  if s.mode == "stable" and s.key and ns.cdb.pets and ns.cdb.pets[s.key] then return L["Viewing: "] .. ns.cdb.pets[s.key].name end
  return L["Viewing: My pet"]
end

local menu, menuButtons = nil, {}
local function OpenMenu(anchor)
  if not menu then
    menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(270)
    Skin(menu, T.deep, 0.98, T.accent, 0.7)
    if false then
      menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    end
    menu.h1 = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    menu.h2 = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    menu:Hide()
  end
  if menu:IsShown() then menu:Hide() return end
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
  for _, b in ipairs(menuButtons) do b:Hide() end
  local n, y = 0, -10
  local function item(icon, text, x, w, onClick, selected)
    n = n + 1
    local b = menuButtons[n]
    if not b then b = ns.MakeFlatButton(menu, 20); menuButtons[n] = b end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", x, y)
    b:SetWidth(w)
    b.icon:SetTexture(ns.Icon(icon))
    b.text:SetText(text)
    b:SetSelected(selected)
    b:SetScript("OnClick", function() onClick(); menu:Hide(); ns.Refresh() end)
    b:Show()
  end
  local s = ns.state
  menu.h1:ClearAllPoints(); menu.h1:SetPoint("TOPLEFT", 12, y); menu.h1:SetText(L["Your pets"])
  y = y - 16
  item("Ability_Hunter_BeastTaming", L["The pet that is out now"], 8, 254, function() s.mode = "pet"; s.family = nil; s.key = nil end, s.mode == "pet")
  y = y - 20
  local keys = {}
  for k, p in pairs(ns.cdb.pets or {}) do if not p.active then keys[#keys + 1] = k end end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local p = ns.cdb.pets[k]
    item(ns.FamilyIcons[p.family] or "Ability_Hunter_BeastTaming",
      string.format("%s  %s(%s %d)|r", p.name, C.GREY, ns.FamilyLabel(p.family), p.level or 0), 8, 254,
      function() s.mode = "stable"; s.key = k end, s.mode == "stable" and s.key == k)
    y = y - 20
  end
  y = y - 6
  menu.h2:ClearAllPoints(); menu.h2:SetPoint("TOPLEFT", 12, y); menu.h2:SetText(L["Plan for a family"])
  y = y - 16
  for i, fam in ipairs(ns.Families) do
    local col = (i - 1) % 2
    item(ns.FamilyIcons[fam] or "Ability_Hunter_BeastTaming", ns.FamilyLabel(fam), 8 + col * 128, 126,
      function() s.mode = "manual"; s.family = fam end, s.mode == "manual" and s.family == fam)
    if col == 1 or i == #ns.Families then y = y - 20 end
  end
  menu:SetHeight(-y + 10)
  menu:Show()
end

local function MakeBar(label, y)
  local b = CreateFrame("StatusBar", nil, frame)
  b:SetSize(132, 11)
  b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -222, y)
  b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  b:SetMinMaxValues(0, 1)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.label:SetPoint("RIGHT", b, "LEFT", -6, 0)
  b.label:SetText(label)
  b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.value:SetPoint("CENTER", 0, 0)
  return b
end

local function BuildHeader()
  header.portrait = frame:CreateTexture(nil, "ARTWORK")
  header.portrait:SetSize(42, 42)
  header.portrait:SetPoint("TOPLEFT", 16, -30)
  header.ring = frame:CreateTexture(nil, "OVERLAY")
  header.ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  header.ring:SetSize(72, 72)
  header.ring:SetPoint("CENTER", header.portrait, "CENTER", 0, 0)
  header.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header.name:SetPoint("TOPLEFT", header.portrait, "TOPRIGHT", 12, -4)
  header.name:SetPoint("RIGHT", frame, "RIGHT", -420, 0)
  header.name:SetJustifyH("LEFT")
  header.name:SetWordWrap(false)
  header.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  header.sub:SetPoint("TOPLEFT", header.name, "BOTTOMLEFT", 0, -4)
  header.sub:SetPoint("RIGHT", frame, "RIGHT", -420, 0)
  header.sub:SetJustifyH("LEFT")
  header.sub:SetWordWrap(false)

  header.happy = MakeBar(L["Happiness"], -31)
  header.xp = MakeBar(L["Experience"], -46)
  header.xp:SetStatusBarColor(0.58, 0.0, 0.55)
  header.tp = MakeBar(L["Training"], -61)
  header.tp:SetStatusBarColor(0.25, 0.55, 1)

  header.viewing = ns.MakeButton(frame, "", 192, function(self) OpenMenu(self) end)
  header.viewing:SetPoint("TOPRIGHT", -14, -30)
  local arrow = header.viewing:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  arrow:SetSize(18, 18)
  arrow:SetPoint("RIGHT", -4, 0)
  header.viewing:SetScript("OnEnter", function(self)
    ShowTooltip(self, { L["Who to plan for"], L["Your pet that is out, any pet in your stable, or any family you might tame."] })
  end)
  header.viewing:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local back = ns.MakeButton(frame, L["Back to my pet"], 192, function() ns.state.mode = "pet"; ns.state.family = nil; ns.state.key = nil; ns.Refresh() end)
  back:SetPoint("TOP", header.viewing, "BOTTOM", 0, -4)
  header.back = back
end

local HAPPY_COLOR = { { 1, 0.3, 0.3 }, { 1, 0.82, 0 }, { 0.25, 0.9, 0.25 } }
local HAPPY_WORD = { L["Unhappy"], L["Content"], L["Happy"] }

local function RefreshHeader(t)
  local petOut = UnitExists("pet") and t and not t.stabled and not t.manual
  if petOut and SetPortraitTexture then
    SetPortraitTexture(header.portrait, "pet")
    header.portrait:SetTexCoord(0, 1, 0, 1)
    header.ring:Hide()
  else
    header.ring:Show()
    header.portrait:SetTexture(ns.Icon(t and ns.FamilyIcons[t.family] or "Ability_Hunter_BeastTaming"))
    header.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  if not t then
    header.name:SetText(L["No pet out"])
    header.sub:SetText(C.GREY .. L["Summon a pet, or use Viewing to pick a family."] .. "|r")
  elseif t.manual then
    header.name:SetText(ns.FamilyLabel(t.family))
    header.sub:SetText(C.GREY .. L["Planning for a new pet of this family"] .. "|r")
  else
    header.name:SetText(t.name or L["Pet"])
    header.sub:SetText(string.format("%s, %s %d   %s", ns.FamilyLabel(t.family), L["level"], t.level or 0,
      t.stabled and (C.GREY .. L["in your stable"] .. "|r") or (C.GREEN .. L["out now"] .. "|r")))
  end

  -- Bars only make sense for the pet that is out.
  local h = petOut and ns.PetHappiness and ns.PetHappiness()
  if h and (type(h) ~= "number" or (ns.IsSecret and ns.IsSecret(h))) then h = nil end
  header.happy:SetShown(h and true or false)
  if h then
    header.happy:SetValue(h / 3)
    header.happy:SetStatusBarColor(unpack(HAPPY_COLOR[h] or HAPPY_COLOR[2]))
    header.happy.value:SetText(HAPPY_WORD[h] or "")
  end
  local xp, nextXP
  if petOut and GetPetExperience then xp, nextXP = GetPetExperience() end
  header.xp:SetShown(xp and nextXP and nextXP > 0 and true or false)
  if xp and nextXP and nextXP > 0 then
    header.xp:SetValue(xp / nextXP)
    header.xp.value:SetText(string.format("%d%%", xp * 100 / nextXP))
  end
  local free, total
  if petOut and ns.PetTrainingPoints then free, total = ns.PetTrainingPoints() end
  header.tp:SetShown(free and total and total > 0 and true or false)
  if free and total and total > 0 then
    header.tp:SetValue((total - free) / total)
    header.tp.value:SetText(string.format(L["%d free"], free))
  end

  header.viewing:SetText(ViewingLabel())
  header.back:SetShown(ns.state.mode ~= "pet")
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local function SelectSection(secKey)
  local pages = SectionPages(secKey)
  if #pages == 0 then return end
  local last = ns.db.lastPage and ns.db.lastPage[secKey]
  SelectTab((last and tabs[last] and tabs[last].meta.sec == secKey) and last or pages[1].key)
end

-- The bar of sections under the header.
local function BuildSectionBar()
  sectionBar = CreateFrame("Frame", nil, frame)
  sectionBar:SetPoint("TOPLEFT", 10, -98)
  sectionBar:SetPoint("TOPRIGHT", -10, -98)
  sectionBar:SetHeight(32)
  Skin(sectionBar, T.bar, 1, nil, nil, -0.5)
  local rule = sectionBar:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
  rule:SetHeight(1)
  rule:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  local function Hint(text)
    local fs = sectionBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetText(text)
    fs:Hide()
    return fs
  end
  sectionBar.l1, sectionBar.r1 = Hint("L1"), Hint("R1")
  sectionBar.l1:SetPoint("LEFT", 8, 0)
  local x = 30
  for _, sec in ipairs(SECTIONS) do
    local b = ns.MakeFlatButton(sectionBar, 28)
    b.text:SetFontObject("GameFontNormal")
    b.icon:SetTexture(ns.Icon(sec.icon))
    b.text:SetText(sec.title)
    local w = 28 + 10 + math.max(40, (b.text.GetStringWidth and b.text:GetStringWidth()) or (#sec.title * 8)) + 12
    b:SetWidth(w)
    b:SetPoint("LEFT", x, 0)
    x = x + w + 4
    b.bar:ClearAllPoints()
    b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT")
    b.bar:SetHeight(3)
    b:SetSelected(false)
    b:SetScript("OnClick", function() SelectSection(sec.key) end)
    sec.button = b
  end
  sectionBar.r1:SetPoint("LEFT", x + 4, 0)
  local gear = ns.MakeFlatButton(sectionBar, 28)
  gear.icon:SetTexture(ns.Icon("INV_Misc_Gear_01"))
  gear.text:SetText(L["Settings"])
  gear:SetWidth(28 + 10 + math.max(50, (gear.text.GetStringWidth and gear.text:GetStringWidth()) or 60) + 8)
  gear:SetPoint("RIGHT", -4, 0)
  gear.bar:ClearAllPoints()
  gear.bar:SetPoint("BOTTOMLEFT"); gear.bar:SetPoint("BOTTOMRIGHT")
  gear.bar:SetHeight(3)
  gear:SetSelected(false)
  gear:SetScript("OnClick", function() SelectTab("settings") end)
  sectionBar.gear = gear
end

-- The list on the left: the pages of the section you're in. A section with one page has no list,
-- and its page takes the whole width.
local function BuildSidebar()
  side = ns.MakeInset(frame)
  side:SetPoint("TOPLEFT", 10, -134)
  side:SetPoint("BOTTOMLEFT", 10, 30)
  side:SetWidth(186)
  for _, t in pairs(tabs) do
    local b = ns.MakeFlatButton(side, 30)
    b.icon:SetTexture(ns.Icon(t.meta.icon))
    b.text:SetText(t.title)
    b:SetSelected(false)
    b:SetScript("OnClick", function() SelectTab(t.key) end)
    b:Hide()
    t.button = b
  end
  LayoutSidebar = function()
    for _, t in pairs(tabs) do if t.button then t.button:Hide() end end
    local pages = SectionPages(activeSection)
    local single = #pages <= 1
    side:SetShown(not single)
    if content then
      content:ClearAllPoints()
      content:SetPoint("TOPLEFT", single and 10 or 202, -134)
      content:SetPoint("BOTTOMRIGHT", -10, 30)
    end
    local y = -8
    for _, t in ipairs(pages) do
      local b = t.button
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 4, y)
      b:SetPoint("RIGHT", side, "RIGHT", -4, 0)
      b:SetSelected(t.key == activeTab)
      b:Show()
      y = y - 32
    end
  end
end

local function SaveGeometry()
  ns.db.win = ns.db.win or {}
  local w = ns.db.win
  w.w, w.h = frame:GetSize()
  local p, _, rp, x, y = frame:GetPoint()
  w.p, w.rp, w.x, w.y = p, rp, x, y
end

local function CreateMainFrame()
  frame = CreateFrame("Frame", "UntamedFrame", UIParent)
  Skin(frame, T.window, 0.97, T.line, 1, 0.45)
  -- our own title bar and close button (no Blizzard frame art)
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(23)
  Skin(bar, T.bar, 1)
  local barRule = bar:CreateTexture(nil, "ARTWORK")
  barRule:SetPoint("BOTTOMLEFT"); barRule:SetPoint("BOTTOMRIGHT")
  barRule:SetHeight(1)
  barRule:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.55)
  -- v2.9 made everything roomier: reset a window size saved by older versions once.
  if ns.db.win and ns.db.win.layout ~= 2 then ns.db.win.w, ns.db.win.h = nil, nil; ns.db.win.layout = 2 end
  local win = ns.db.win or {}
  -- Default size: roomy, but never taller or wider than the screen.
  local sw, sh = UIParent:GetWidth() or 1365, UIParent:GetHeight() or 768
  -- The journal pages (a list, and a page with a model beside it) need this much width to fit.
  local minW, minH = math.min(1160, sw - 40), math.min(700, sh - 40)
  local dw, dh = math.max(minW, math.min(1240, sw - 60)), math.max(minH, math.min(820, sh - 60))
  frame:SetSize(math.max(win.w or dw, minW), math.max(win.h or dh, minH))
  if win.p then frame:SetPoint(win.p, UIParent, win.rp, win.x, win.y) else frame:SetPoint("CENTER", 120, 40) end
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(minW, minH, 1800, 1300)
  elseif frame.SetMinResize then frame:SetMinResize(minW, minH); frame:SetMaxResize(1800, 1300) end
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveGeometry() end)
  frame:Hide()
  tinsert(UISpecialFrames, "UntamedFrame")

  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("CENTER", 10, 0)
  title:SetText("U N T A M E D")
  local mark = bar:CreateTexture(nil, "ARTWORK")
  mark:SetSize(17, 17)
  mark:SetPoint("RIGHT", title, "LEFT", -8, 0)
  mark:SetTexture("Interface\\AddOns\\Untamed\\Media\\Icon")
  local close = ns.MakeButton(bar, "X", 24, function() frame:Hide() end)
  close:SetSize(24, 19)
  close:SetPoint("RIGHT", -3, 0)

  BuildHeader()
  BuildSectionBar()
  BuildSidebar()

  content = ns.MakeInset(frame)
  content:SetPoint("TOPLEFT", 202, -134)
  content:SetPoint("BOTTOMRIGHT", -10, 30)
  content.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  content.title:SetPoint("TOPLEFT", 14, -11)
  content.sub = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  content.sub:SetPoint("TOPLEFT", content.title, "BOTTOMLEFT", 1, -4)
  content.sub:SetPoint("RIGHT", content, "RIGHT", -10, 0)
  content.sub:SetJustifyH("LEFT")
  content.sub:SetWordWrap(false)
  local line = content:CreateTexture(nil, "ARTWORK")
  line:SetPoint("TOPLEFT", 10, -50)
  line:SetPoint("TOPRIGHT", -10, -50)
  line:SetHeight(1)
  line:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  local tick = content:CreateTexture(nil, "OVERLAY")
  tick:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 1)
  tick:SetSize(90, 3)
  if not ns.Gradient(tick, "HORIZONTAL", T.accent[1], T.accent[2], T.accent[3], 1, T.accent[1], T.accent[2], T.accent[3], 0) then
    tick:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 0.9)
  end

  -- Status bar along the bottom: tips and the current map focus.
  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 16, 9)
  statusText:SetPoint("RIGHT", frame, "RIGHT", -120, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(false)
  versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  versionText:SetPoint("BOTTOMRIGHT", -28, 9)
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local v = getMeta and getMeta("Untamed", "Version")
  versionText:SetText((v and not v:find("@", 1, true)) and ("v" .. v) or "")

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -6, 6)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); SaveGeometry() end)

  frame:SetScript("OnShow", function() ns.UI_Refresh(); if ns.Pad_Open then ns.Pad_Open() end end)
  frame:SetScript("OnHide", function() if menu then menu:Hide() end; ns.CloseDropdown(); if ns.Pad_Close then ns.Pad_Close() end end)
end

-- "1 item", "3 items"
function ns.Count(n, one, many) return n .. " " .. (n == 1 and one or many) end

function ns.UI_Refresh()
  if not frame or not frame:IsShown() then return end
  -- Planning for the pet that is out is just "my pet".
  local s = ns.state
  if s.mode == "stable" and s.key and UnitExists("pet") and s.key == ns.PetKey(UnitName("pet"), ns.ToEnglish(UnitCreatureFamily("pet"))) then
    s.mode, s.key = "pet", nil
  end
  local t = ns.Target()
  RefreshHeader(t)
  local petPage = activeTab and tabs[activeTab] and tabs[activeTab].meta.sec == "pets"
  if ns.Pad_Active and ns.Pad_Active() then
    statusText:SetText(C.GREY .. L["D-pad: move    Cross: select    Square: second action    Circle: back    L1 R1: sections"] .. "|r")
  elseif not ns.cdb.scanned and petPage and UnitExists("pet") then
    statusText:SetText(C.ORANGE .. L["Tip: open Beast Training once so Untamed knows which ranks you already have."] .. "|r")
  else
    local fl = ns.Pins_GetFocusLabel()
    statusText:SetText(fl and (C.GOLD .. L["Map focus: "] .. "|r" .. fl .. C.GREY .. L["   (/untamed clear to reset)"] .. "|r")
      or (C.GREY .. L["Click a beast for an arrow and map pins. Right-click opens the map."] .. "|r"))
  end
  local tab = activeTab and tabs[activeTab]
  if tab and tab.panel and tab.refresh then tab.refresh(tab.panel, t) end
  ns.RefreshControls()
end
ns.On("REFRESH", ns.UI_Refresh)
ns.On("PETCARE", function() if frame and frame:IsShown() then ns.UI_Refresh() end end)

function ns.UI_Show(key)
  if not frame then CreateMainFrame() end
  frame:Show()
  SelectTab((key and tabs[key]) and key or activeTab or (ns.db.openHome ~= false and "home") or "abilities")
end

-- For the controller (Pad.lua): the window, an open menu and what opened it, and stepping through
-- sections and pages.
function ns.UI_Frame() return frame end
function ns.UI_Popup()
  if ddMenu and ddMenu:IsShown() then return ddMenu, ddMenu.owner end
  if menu and menu:IsShown() then return menu, header.viewing end
  return nil
end
function ns.UI_ClosePopups() if menu then menu:Hide() end; ns.CloseDropdown() end
function ns.UI_PageButton() local t = activeTab and tabs[activeTab]; return t and t.button and t.button:IsShown() and t.button or nil end
function ns.UI_Sidebar() return side end
function ns.UI_Content() return content end
function ns.UI_PadHints(on)
  if sectionBar then sectionBar.l1:SetShown(on); sectionBar.r1:SetShown(on) end
  ns.UI_Refresh()
end
function ns.UI_StepSection(dir)
  -- the six sections, then Settings, then round again
  local n = #SECTIONS + 1
  local cur = sectionByKey[activeSection]
  local i = cur and cur.index or (activeSection == "settings" and n) or (dir > 0 and 0 or 1)
  for _ = 1, n do
    i = (i - 1 + dir) % n + 1
    if i == n then
      if tabs.settings then SelectTab("settings") return end
    elseif #SectionPages(SECTIONS[i].key) > 0 then
      SelectSection(SECTIONS[i].key) return
    end
  end
end
function ns.UI_StepPage(dir)
  local pages = SectionPages(activeSection)
  if #pages < 2 then return end
  for i, t in ipairs(pages) do
    if t.key == activeTab then SelectTab(pages[(i - 1 + dir) % #pages + 1].key) return end
  end
end
function ns.UI_Sections()
  local out = {}
  for _, sec in ipairs(SECTIONS) do
    local names = {}
    for _, t in ipairs(SectionPages(sec.key)) do names[#names + 1] = t.key end
    out[#out + 1] = { sec.key, names }
  end
  return out, activeSection, activeTab
end

function ns.UI_ViewingMenu() if header.viewing then OpenMenu(header.viewing) end end

function ns.UI_Toggle()
  if frame and frame:IsShown() then frame:Hide() else ns.UI_Show() end
end

---------------------------------------------------------------------------
-- Page: Abilities. What the pet you're viewing can learn, on the left; the ability's page on the
-- right: the rank it has, every rank still ahead with its pet level and cost, and for each whether
-- you can teach it now or which beasts to tame for it.
---------------------------------------------------------------------------
do
  local list, j
  local tiles, ranksText, tipsText = {}, nil, nil
  local todoOnly = false
  local plan, target = {}, nil

  local function Entry(key)
    for _, e in ipairs(plan) do if e.ability == key then return e end end
  end

  -- the next rank worth going for: the first one you don't know that the pet can use
  local function NextRank(e)
    for _, r in ipairs(e.ranks) do if not r.known and not r.tooHigh and #r.beasts > 0 then return r end end
  end
  local function Teachable(e)
    local best
    for _, r in ipairs(e.ranks) do if r.known and not r.tooHigh then best = r end end
    return best
  end

  local function NearestTeacher(r)
    local level = UnitLevel("player")
    local best, bd
    for _, id in ipairs(r.beasts) do
      if ns.Beasts[id][2] <= level then
        local _, _, _, d = ns.NearestSpawn(id)
        d = d or 9e8
        if not bd or d < bd then best, bd = id, d end
      end
    end
    return best
  end

  local function Fill(key)
    local trainer = type(key) == "string" and key:match("^T:(.+)$")
    local ab = trainer or key
    j.box:Picture(ns.Icon(ns.AbilityIcons[ab] or (trainer and "Ability_Hunter_BeastTraining") or "Ability_Hunter_BeastTaming"))
    j.name:SetText(ns.AbilityLabel(ab))
    local who = target and (target.name or ns.FamilyLabel(target.family)) or L["Your pet"]
    local cur = target and target.known and target.known[ab] or 0
    j.sub:SetText(cur > 0 and string.format(L["%s has Rank %d"], who, cur) or string.format(L["%s doesn't know it"], who))
    local e = not trainer and Entry(ab)
    for _, b in ipairs(j.buttons) do b:SetShown(e and true or false) end
    if not e then
      tiles.next.value:SetText(C.GREY .. L["bought from pet trainers"] .. "|r")
      tiles.who.value:SetText(L["Every family"])
      ranksText:SetText(L["Buy higher ranks from any Hunter pet trainer in a capital or major town, then teach them at Beast Training."])
      tipsText:SetText("")
      return
    end
    local nxt, teach = NextRank(e), Teachable(e)
    if teach then
      local tp = ns.RankCost(ab, teach.rank)
      tiles.next.value:SetText(C.GREEN .. string.format(L["Rank %d: you know it, teach it now"], teach.rank) .. "|r" .. (tp and (C.GREY .. "   " .. tp .. " TP|r") or ""))
    elseif nxt then
      tiles.next.value:SetText(string.format(L["Rank %d: tame a beast for it"], nxt.rank) .. C.GREY .. "   " .. ns.Count(#nxt.beasts, L["beast"], L["beasts"]) .. "|r")
    elseif #e.ranks == 0 then
      tiles.next.value:SetText(C.GREEN .. ((e.current >= (ns.MaxRank[ab] or 0)) and L["maxed"] or L["best for its level"]) .. "|r")
    else
      tiles.next.value:SetText(C.GREY .. L["nothing it can use yet"] .. "|r")
    end
    local fams = {}
    for _, f in ipairs(ns.Families) do if ns.AbilityFamilies[ab] and ns.AbilityFamilies[ab][f] then fams[#fams + 1] = ns.FamilyLabel(f) end end
    tiles.who.value:SetText(#fams >= #ns.Families and L["Every family"] or table.concat(fams, ", "))
    j.buttons[1]:SetShown(nxt and NearestTeacher(nxt) and true or false)
    j.buttons[2]:SetShown(nxt and true or false)

    local level = UnitLevel("player")
    local lines = {}
    for _, r in ipairs(e.ranks) do
      local tp = ns.RankCost(ab, r.rank)
      local head = string.format("%s%s %d|r%s%s", r.tooHigh and C.GREY or C.WHITE, L["Rank"], r.rank,
        r.level and (C.GREY .. "   " .. string.format(L["pet level %d"], r.level) .. "|r") or "", tp and (C.GREY .. "   " .. tp .. " TP|r") or "")
      local status
      if r.known then
        status = r.tooHigh and (C.GREY .. L["you know it; the pet is too low"] .. "|r") or (C.GREEN .. L["you know it: teach it at Beast Training"] .. "|r")
      elseif #r.beasts == 0 then
        local fa = ns.ForeverAbilities and ns.ForeverAbilities[ab]
        status = (fa and fa.source == "innate") and (C.GREY .. L["no known teacher: may come with pet level"] .. "|r") or (C.RED .. L["no beast known yet"] .. "|r")
      else
        local names, more = {}, 0
        for _, id in ipairs(r.beasts) do
          if #names < 2 then names[#names + 1] = ((ns.Beasts[id][2] > level) and C.RED or C.GOLD) .. ns.Beasts[id][1] .. "|r" else more = more + 1 end
        end
        status = L["tame"] .. " " .. table.concat(names, ", ") .. (more > 0 and (C.GREY .. " +" .. more .. "|r") or "")
      end
      lines[#lines + 1] = head .. "\n     " .. status
      if #lines >= 6 then break end
    end
    if #lines == 0 then lines[1] = C.GREY .. L["No ranks ahead of it right now."] .. "|r" end
    if #e.ranks > 6 then lines[#lines + 1] = C.GREY .. string.format(L["and %d more ranks later"], #e.ranks - 6) .. "|r" end
    ranksText:SetText(table.concat(lines, "\n"))
    local tips = { L["You don't need lower ranks first: the highest rank your pet's level allows is enough."],
      L["Tame a beast that knows the rank, fight with it until you learn it, then teach it to any pet that can use it."] }
    local fa = ns.ForeverAbilities and ns.ForeverAbilities[ab]
    if fa and fa.note and fa.note ~= "" then tips[#tips + 1] = C.ORANGE .. fa.note .. "|r" end
    tipsText:SetText(C.GREY .. table.concat(tips, "\n") .. "|r")
  end

  local function Build(panel)
    j = ns.MakeJournal(panel, L["Summon your pet, or use Viewing at the top right to pick a family or a stabled pet."])
    local tb = ns.Toolbar(j.left)
    tb:Check(L["Still to learn only"], function() return todoOnly end, function(v) todoOnly = v end)
    tb:Row()
    tb:Check(L["Hide ranks above my pet's level"], function() return ns.db.hideTooHigh end, function(v) ns.db.hideTooHigh = v end)
    list = tb:List()
    j.list = list
    tiles.next = j:Tile(L["Next"])
    tiles.who = j:Tile(L["Who can learn it"])
    tiles.who.value:SetWordWrap(true)
    if tiles.who.value.SetMaxLines then tiles.who.value:SetMaxLines(4) end
    j.buttons = j:Buttons({
      { L["Hunt the next rank"], 150, function()
          local e = Entry(j.selected)
          local r = e and NextRank(e)
          local id = r and NearestTeacher(r)
          if id then ns.Navigate(id) end
        end, { L["Hunt the next rank"], L["An arrow to the nearest beast you can tame that teaches the next rank."] } },
      { L["Teachers on map"], 130, function()
          local e = Entry(j.selected)
          local r = e and NextRank(e)
          if r then ns.Pins_Focus(r.beasts, e.ability .. " " .. r.rank, true) end
        end },
      { L["In the Bestiary"], 120, function()
          if not Entry(j.selected) then return end
          local f = ns.BrowserFilter()
          f.family, f.fresh, f.teaches, f.where, f.rare, f.tameable = "any", false, j.selected, "any", false, false
          ns.UI_Show("browse")
        end, { L["In the Bestiary"], L["Every beast that teaches this ability."] } },
    })
    ranksText = j:Section(L["Ranks ahead"])
    tipsText = j:Section(L["Good to know"], "GameFontHighlightSmall")
    j.onSelect = Fill
  end

  local function Refresh(panel, t)
    target = t
    plan = t and ns.Plan(t.family, t.level, t.known) or {}
    local rows, keys, order = {}, {}, {}
    if t then
      rows[1] = { 0, nil, string.format(L["%s can learn"], t.name or ns.FamilyLabel(t.family)), "", nil, nil, { header = true } }
      for _, e in ipairs(plan) do
        local ab = e.ability
        local nxt, teach = NextRank(e), Teachable(e)
        if not todoOnly or nxt or teach then
          local right
          if teach then right = C.GREEN .. L["teach"] .. " " .. teach.rank .. "|r"
          elseif nxt then right = C.WHITE .. L["tame"] .. " " .. nxt.rank .. "|r"
          elseif e.current > 0 then right = C.GREY .. L["Rank"] .. " " .. e.current .. "|r"
          else right = C.GREY .. "-|r" end
          rows[#rows + 1] = { 0, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTaming"), ns.AbilityLabel(ab), right,
            j:RowClick(ab, function(k)
              local en = Entry(k)
              local r = en and NextRank(en)
              local id = r and NearestTeacher(r)
              if id then ns.Navigate(id) end
            end), j:RowHover(ab) }
          keys[#rows] = ab
          order[#order + 1] = ab
        end
      end
      if not todoOnly then
        for _, ab in ipairs(ns.TrainerAbilities) do
          local cur = t.known[ab]
          rows[#rows + 1] = { 0, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTraining"), C.GREY .. ns.AbilityLabel(ab) .. "|r",
            C.GREY .. (cur and (L["Rank"] .. " " .. cur) or L["trainer"]) .. "|r", j:RowClick("T:" .. ab), j:RowHover("T:" .. ab) }
          keys[#rows] = "T:" .. ab
          order[#order + 1] = "T:" .. ab
        end
      end
    end
    list:Set(rows)
    j:Rows(keys, order)
  end

  ns.RegisterTab("abilities", L["Abilities"], Build, Refresh)
end
