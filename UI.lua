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
    r.rule:SetColorTexture(1, 0.82, 0, 0.35)
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
        r.bg:SetColorTexture(1, 0.82, 0, 0.07); r.bg:Show(); r.rule:Show(); stripe = 0
      else
        r.rule:Hide()
        stripe = stripe + 1
        if stripe % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.04); r.bg:Show() else r.bg:Hide() end
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

function ns.MakeButton(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

-- A sunken Blizzard inset panel (falls back to a dark backdrop).
function ns.MakeInset(parent)
  local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
  if ok and f then return f end
  f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0.5)
    f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  end
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
  b.sel:SetColorTexture(1, 0.82, 0, 0.14)
  b.sel:Hide()
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(3)
  b.bar:SetColorTexture(0.67, 0.83, 0.45, 1)
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
  if fs then fs:ClearAllPoints(); fs:SetPoint("LEFT", 8, 0); fs:SetPoint("RIGHT", -18, 0); fs:SetJustifyH("LEFT") end
  function b:Update()
    local cur = get()
    for _, o in ipairs(type(options) == "function" and options() or options) do
      if o[1] == cur then self:SetText(o[2]) return end
    end
    self:SetText("?")
  end
  b:SetScript("OnClick", function(self)
    if not ddMenu then
      ddMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
      ddMenu:SetFrameStrata("FULLSCREEN_DIALOG")
      if ddMenu.SetBackdrop then
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
  local function place(w) local x = tb.x; tb.x = tb.x + w + 12; return x end
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
    d:SetPoint("TOPLEFT", place(width), y())
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
    b:SetPoint("TOPLEFT", place(width), y())
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
  abilities = { group = 1, order = 1, icon = "Ability_Hunter_BeastTraining", sub = L["What your pet can learn, and which beasts teach it"] },
  builds    = { group = 1, order = 2, icon = "INV_Misc_Book_09", sub = L["Plan how to spend your pet's training points"] },
  care      = { group = 1, order = 3, icon = "INV_Misc_Food_14", sub = L["Happiness, food and where to level your pet"] },
  stable    = { group = 1, order = 4, icon = "Ability_Hunter_BeastCall", sub = L["Every pet you own, and what you can teach each one"] },
  recommend = { group = 2, order = 1, icon = "Ability_Hunter_BeastTaming", sub = L["Pick a role and get the best family and beasts for it"] },
  plan      = { group = 2, order = 3, icon = "INV_Misc_Map_01", sub = L["A route to tame the beasts your pet still needs"] },
  rares     = { group = 2, order = 4, icon = "Ability_Hunter_SniperShot", sub = L["Rares near you, and the ones you've seen"] },
  browse    = { group = 2, order = 2, icon = "INV_Misc_Spyglass_03", sub = L["Every tameable beast: filter by family, ability and place"] },
  search    = { group = 3, order = 1, icon = "INV_Misc_Spyglass_02", sub = L["Find any item, NPC or beast and where to get it"] },
  supplies  = { group = 3, order = 5, icon = "INV_Ammo_Arrow_02", sub = L["Ammo, quivers and food for your pet"] },
  spells    = { group = 4, order = 1, icon = "INV_Misc_Book_11", sub = L["What to train at each level and what it costs"] },
  talents   = { group = 4, order = 2, icon = "Ability_Hunter_SniperShot", sub = L["Talent builds, with the next point highlighted"] },
  gear      = { group = 3, order = 3, icon = "INV_Weapon_Bow_07", sub = L["Your next upgrades, and how to get them"] },
  wishlist  = { group = 3, order = 2, icon = "INV_Misc_Note_01", sub = L["Items you want, with their sources on your map"] },
  dungeons  = { group = 3, order = 4, icon = "INV_Misc_Key_03", sub = L["Hunter loot, bosses and beasts in each dungeon"] },
  reputation = { group = 4, order = 3, icon = "INV_Misc_Token_ArgentDawn", sub = L["Reputation you need for rewards you want"] },
  quests    = { group = 4, order = 4, icon = "INV_Misc_Note_02", sub = L["Class quests only hunters can do"] },
  home      = { group = 0, order = 1, icon = "Interface\\AddOns\\Untamed\\Media\\Icon", sub = L["What to do next, and how Untamed works"] },
  settings  = { group = 9, order = 1, icon = "INV_Misc_Gear_01", sub = L["Alerts, pins and data sharing"] },
}
local GROUPS = { L["My Pet"], L["Taming"], L["Gear"], L["Hunter"] }

function ns.RegisterTab(key, title, build, refresh)
  tabs[key] = { key = key, title = title, build = build, refresh = refresh, meta = TAB_META[key] or { group = 2, order = 99, icon = "INV_Misc_QuestionMark" } }
end

local function SelectTab(key)
  if not tabs[key] then key = "abilities" end
  activeTab = key
  for k, t in pairs(tabs) do
    if t.panel then t.panel:SetShown(k == key) end
    if t.button then t.button:SetSelected(k == key) end
  end
  local t = tabs[key]
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
    menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(270)
    if menu.SetBackdrop then
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
local function BuildSidebar()
  local side = ns.MakeInset(frame)
  side:SetPoint("TOPLEFT", 10, -100)
  side:SetPoint("BOTTOMLEFT", 10, 30)
  side:SetWidth(186)
  local list = {}
  for _, t in pairs(tabs) do list[#list + 1] = t end
  table.sort(list, function(a, b)
    if a.meta.group ~= b.meta.group then return a.meta.group < b.meta.group end
    return a.meta.order < b.meta.order
  end)
  -- Buttons and group headings are laid out to fit the sidebar's height: roomy when there is space,
  -- tighter on a short window, so Settings never runs off the bottom.
  local items, lastGroup = {}, nil
  for _, t in ipairs(list) do
    local g = t.meta.group
    local b = ns.MakeFlatButton(side, 26)
    if g == 9 then
      b:SetPoint("BOTTOMLEFT", 4, 6)
      b:SetPoint("BOTTOMRIGHT", -4, 6)
    else
      if g ~= lastGroup then
        if GROUPS[g] then
          local h = side:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          h:SetText(GROUPS[g])
          local rule = side:CreateTexture(nil, "ARTWORK")
          rule:SetPoint("LEFT", h, "RIGHT", 8, 0)
          rule:SetPoint("RIGHT", side, "RIGHT", -10, 0)
          rule:SetHeight(1)
          rule:SetColorTexture(1, 0.82, 0, 0.25)
          items[#items + 1] = { head = h, gap = lastGroup ~= nil }
        end
        lastGroup = g
      end
      items[#items + 1] = { button = b }
    end
    b.icon:SetTexture(ns.Icon(t.meta.icon))
    b.text:SetText(t.title)
    b:SetSelected(false)
    b:SetScript("OnClick", function() SelectTab(t.key) end)
    t.button = b
  end
  local function Layout()
    local nButtons, nHeads = 0, 0
    for _, it in ipairs(items) do if it.button then nButtons = nButtons + 1 else nHeads = nHeads + 1 end end
    local avail = (side:GetHeight() or 600) - 8 - 40   -- top padding, Settings at the bottom
    local scale = math.min(1, math.max(0.72, avail / (nButtons * 27 + nHeads * 30)))
    local step, headH, gap = math.floor(27 * scale), math.floor(20 * scale), math.floor(10 * scale)
    local y = -8
    for _, it in ipairs(items) do
      if it.head then
        if it.gap then y = y - gap end
        it.head:ClearAllPoints(); it.head:SetPoint("TOPLEFT", 12, y)
        y = y - headH
      else
        it.button:SetHeight(step - 1)
        it.button.icon:SetSize(step - 8, step - 8)
        it.button:ClearAllPoints(); it.button:SetPoint("TOPLEFT", 4, y); it.button:SetPoint("RIGHT", side, "RIGHT", -4, 0)
        y = y - step
      end
    end
  end
  side:SetScript("OnSizeChanged", Layout)
  Layout()
end

local function SaveGeometry()
  ns.db.win = ns.db.win or {}
  local w = ns.db.win
  w.w, w.h = frame:GetSize()
  local p, _, rp, x, y = frame:GetPoint()
  w.p, w.rp, w.x, w.y = p, rp, x, y
end

local function CreateMainFrame()
  frame = CreateFrame("Frame", "UntamedFrame", UIParent, "BasicFrameTemplate")
  -- v2.9 made everything roomier: reset a window size saved by older versions once.
  if ns.db.win and ns.db.win.layout ~= 2 then ns.db.win.w, ns.db.win.h = nil, nil; ns.db.win.layout = 2 end
  local win = ns.db.win or {}
  -- Default size: roomy, but never taller or wider than the screen.
  local sw, sh = UIParent:GetWidth() or 1365, UIParent:GetHeight() or 768
  local dw, dh = math.min(1000, sw - 60), math.min(800, sh - 60)
  frame:SetSize(math.max(win.w or dw, 860), math.max(win.h or dh, 640))
  if win.p then frame:SetPoint(win.p, UIParent, win.rp, win.x, win.y) else frame:SetPoint("CENTER", 120, 40) end
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then frame:SetResizeBounds(860, 640, 1600, 1200)
  elseif frame.SetMinResize then frame:SetMinResize(860, 640); frame:SetMaxResize(1600, 1200) end
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveGeometry() end)
  frame:Hide()
  tinsert(UISpecialFrames, "UntamedFrame")

  local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
  title:SetText("Untamed" .. (ns.FLAVOR == "forever" and " (Forever)" or ""))

  BuildHeader()
  BuildSidebar()

  content = ns.MakeInset(frame)
  content:SetPoint("TOPLEFT", 202, -100)
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
  line:SetColorTexture(1, 0.82, 0, 0.25)

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

  frame:SetScript("OnShow", function() ns.UI_Refresh() end)
  frame:SetScript("OnHide", function() if menu then menu:Hide() end; ns.CloseDropdown() end)
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
  local petPage = activeTab and tabs[activeTab] and tabs[activeTab].meta.group == 1
  if not ns.cdb.scanned and petPage and UnitExists("pet") then
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

function ns.UI_ViewingMenu() if header.viewing then OpenMenu(header.viewing) end end

function ns.UI_Toggle()
  if frame and frame:IsShown() then frame:Hide() else ns.UI_Show() end
end

---------------------------------------------------------------------------
-- Tab: Abilities
---------------------------------------------------------------------------
do
  local list
  local collapsed, expanded, trainerOpen = {}, {}, false

  local function RankStatus(e, r)
    if r.known then
      local tp = ns.RankCost(e.ability, r.rank)
      if r.tooHigh then return C.GREY .. L["You know it. Pet needs level "] .. r.level .. "|r" end
      return C.GREEN .. L["You know it: teach at Beast Training"] .. (tp and (" (" .. tp .. " TP)") or "") .. "|r"
    end
    local n = #r.beasts
    if n == 0 then
      local fa = ns.ForeverAbilities and ns.ForeverAbilities[e.ability]
      if fa and fa.source == "innate" then return C.GREY .. "No known teacher. May come with pet level|r" end
      return C.RED .. "No beast known yet|r"
    end
    return C.WHITE .. L["Tame 1 of "] .. n .. " beast" .. (n > 1 and "s" or "") .. "|r"
  end

  local view = "all"
  local VIEWS = { { "all", L["Every ability and rank"] }, { "todo", L["Ranks still to learn"] },
    { "now", L["Beasts I can tame now"] }, { "teach", L["Ready to teach my pet"] } }
  local function Keep(r)
    if view == "all" then return true end
    if view == "teach" then return r.known and not r.tooHigh end
    if r.known then return false end
    if view == "now" then
      local lvl = UnitLevel("player")
      for _, id in ipairs(r.beasts) do if ns.Beasts[id][2] <= lvl then return true end end
      return false
    end
    return true
  end

  local function Build(panel)
    local tb = ns.Toolbar(panel)
    tb:Dropdown(200, VIEWS, function() return view end, function(v) view = v end,
      { L["Show"], L["Ranks still to learn: hides what you or your pet already have."], L["Beasts I can tame now: only ranks taught by a beast at or below your level."],
        L["Ready to teach my pet: ranks you know that your pet can use but doesn't have yet."] })
    tb:Check(L["Hide ranks above my pet's level"], function() return ns.db.hideTooHigh end, function(v) ns.db.hideTooHigh = v end)
    tb:Button(L["Collapse all"], 100, function()
      local any = false
      for _, v in pairs(collapsed) do if v then any = true end end
      if any then wipe(collapsed) else for _, a in ipairs(ns.AbilityOrder) do collapsed[a] = true end end
      ns.UI_Refresh()
    end)
    list = tb:List()
  end

  local function Refresh(panel, t)
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local playerLevel = UnitLevel("player")
    if not t then
      add(0, nil, C.GREY .. L["Summon your pet, or use Viewing at the top right to pick a family or a stabled pet."] .. "|r")
    end
    if t then
      for _, e in ipairs(ns.Plan(t.family, t.level, t.known)) do
        local ab = e.ability
        local shownRanks = {}
        for _, r in ipairs(e.ranks) do if Keep(r) then shownRanks[#shownRanks + 1] = r end end
        if view == "all" or #shownRanks > 0 then
        local maxR = ns.MaxRank[ab] or 0
        local rightTxt
        if #e.ranks == 0 then
          rightTxt = (e.current >= maxR) and (C.GREEN .. "maxed|r") or (C.GREY .. "nothing usable yet|r")
        else
          rightTxt = C.GREY .. (e.current > 0 and ("pet has Rank " .. e.current) or "pet does not know it") .. "|r"
        end
        add(0, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTaming"), ns.AbilityLabel(ab), rightTxt,
          function() collapsed[ab] = not collapsed[ab]; ns.UI_Refresh() end, nil, { header = true, toggle = not collapsed[ab] })
        if not collapsed[ab] then
          local firstOpen = true
          for _, r in ipairs(shownRanks) do
            local key = ab .. "#" .. r.rank
            local isOpen = expanded[key]
            if isOpen == nil then
              isOpen = firstOpen and not r.known and not r.tooHigh and #r.beasts > 0
              if isOpen then firstOpen = false end
            end
            local lvlTxt = r.level and (" (pet lvl " .. (r.levelExact and "" or "~") .. r.level .. ")") or ""
            local color = r.tooHigh and C.GREY or C.WHITE
            local beasts = r.beasts
            local label = string.format("%sRank %d%s|r", color, r.rank, lvlTxt)
            local canOpen = #beasts > 0 and not r.known
            add(14, nil, label, RankStatus(e, r), function()
              expanded[key] = not isOpen
              if #beasts > 0 then ns.Pins_Focus(beasts, ab .. " " .. r.rank, false) end
              ns.UI_Refresh()
            end, { ab .. " Rank " .. r.rank,
              r.level and (L["Your pet must be level "] .. r.level .. " to use this rank" .. (r.levelExact and "." or " (approximate until you open Beast Training).")) or L["Level unknown."],
              r.known and L["You already know this rank. Teach it to your pet from the Beast Training window."]
                or L["Tame one of these beasts, then fight with it until you learn the ability. Then teach it to any pet that can use it."],
              L["You don't need lower ranks first: the highest rank your pet's level allows is enough."],
              (ns.ForeverAbilities and ns.ForeverAbilities[ab] and ns.ForeverAbilities[ab].note ~= "")
                and (C.ORANGE .. L["Forever data note: "] .. ns.ForeverAbilities[ab].note .. "|r") or "",
              L["Click to pin these beasts on your map."] }, canOpen and { toggle = isOpen and true or false } or { toggleSpace = true })
            if isOpen and not r.known then
              for _, npcId in ipairs(beasts) do
                local b = ns.Beasts[npcId]
                local lvColor = (b[2] > playerLevel) and C.RED or C.WHITE
                add(50, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
                  C.WHITE .. b[1] .. "|r", ns.ZonesText(b),
                  ns.BeastClick(npcId), ns.BeastTooltip(npcId), { mid = lvColor .. ns.LevelText(b) .. "|r" })
              end
            end
          end
        end
        end
      end
      add(0, ns.Icon("Ability_Hunter_BeastTraining"), L["From Hunter pet trainers"],
        C.GREY .. L["Growl, armor, stamina, resistances"] .. "|r", function() trainerOpen = not trainerOpen; ns.UI_Refresh() end,
        nil, { header = true, toggle = trainerOpen })
      if trainerOpen then
        for _, ab in ipairs(ns.TrainerAbilities) do
          local cur = t.known[ab]
          add(32, nil, C.WHITE .. ns.AbilityLabel(ab) .. "|r", C.GREY .. (cur and ("pet has Rank " .. cur) or "not learned") .. "|r", nil,
            { ab, L["Buy higher ranks from any Hunter pet trainer in a capital or major town, then teach them at Beast Training."] })
        end
      end
    end
    list:Set(rows)
  end

  ns.RegisterTab("abilities", L["Abilities"], Build, Refresh)
end
