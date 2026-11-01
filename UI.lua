local _, ns = ...
local L = ns.L

local ROW_H = 18
ns.C = {
  GOLD = "|cffffd100", GREEN = "|cff40ff40", GREY = "|cff909090", RED = "|cffff5050",
  WHITE = "|cffffffff", ORANGE = "|cffff9933", BLUE = "|cff66aaff", HUNTER = "|cffabd473",
}
local C = ns.C
function ns.Icon(path) return "Interface\\Icons\\" .. path end

---------------------------------------------------------------------------
-- Generic scrolling list
---------------------------------------------------------------------------
local function ShowTooltip(owner, tip)
  if type(tip) == "function" then tip = tip() end
  if not tip then return end
  GameTooltip:SetOwner(owner, L["ANCHOR_RIGHT"])
  for idx, line in ipairs(tip) do
    if idx == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 1, 1, 1, true) end
  end
  GameTooltip:Show()
end
ns.ShowTooltip = ShowTooltip

function ns.NewList(parent, topOffset)
  local list = { rows = {} }
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint(L["TOPLEFT"], 4, -topOffset)
  scroll:SetPoint(L["BOTTOMRIGHT"], -26, 4)
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
    r:RegisterForClicks(L["LeftButtonUp"], L["RightButtonUp"])
    r.icon = r:CreateTexture(nil, L["ARTWORK"])
    r.icon:SetSize(14, 14)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.left = r:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlightSmall"])
    r.left:SetJustifyH(L["LEFT"])
    r.left:SetWordWrap(false)
    r.right = r:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlightSmall"])
    r.right:SetJustifyH(L["RIGHT"])
    r.right:SetPoint(L["RIGHT"], -4, 0)
    r.right:SetWordWrap(false)
    local hl = r:CreateTexture(nil, L["HIGHLIGHT"])
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
    r:SetScript("OnEnter", function(self) if self.tooltip then ShowTooltip(self, self.tooltip) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    list.rows[i] = r
    return r
  end

  -- rows: { {indent, iconPath, leftText, rightText, onClick, tooltip}, ... }
  function list:Set(data)
    for i, d in ipairs(data) do
      local r = GetRow(i)
      local indent, iconPath = d[1] or 0, d[2]
      r:ClearAllPoints()
      r:SetPoint(L["TOPLEFT"], content, L["TOPLEFT"], 0, -(i - 1) * ROW_H)
      r:SetPoint(L["RIGHT"], content, L["RIGHT"], 0, 0)
      r.icon:ClearAllPoints()
      r.icon:SetPoint(L["LEFT"], 4 + indent, 0)
      r.left:ClearAllPoints()
      if iconPath then
        r.icon:SetTexture(iconPath); r.icon:Show()
        r.left:SetPoint(L["LEFT"], r.icon, L["RIGHT"], 4, 0)
      else
        r.icon:Hide()
        r.left:SetPoint(L["LEFT"], 4 + indent, 0)
      end
      r.left:SetPoint(L["RIGHT"], r.right, L["LEFT"], -6, 0)
      r.left:SetText(d[3] or "")
      r.right:SetText(d[4] or "")
      r.onClick, r.tooltip = d[5], d[6]
      r:Show()
    end
    for j = #data + 1, #list.rows do list.rows[j]:Hide() end
    content:SetHeight(math.max(1, #data * ROW_H))
  end
  return list
end

function ns.MakeCheck(parent, label, x, y, get, set, tip)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(22, 22)
  c:SetPoint(L["TOPLEFT"], x, y)
  local fs = c.text or c.Text or c:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlightSmall"])
  fs:SetFontObject(L["GameFontHighlightSmall"])
  fs:ClearAllPoints()
  fs:SetPoint(L["LEFT"], c, L["RIGHT"], 0, 1)
  fs:SetText(label)
  c:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); ns.Refresh() end)
  if tip then
    c:SetScript("OnEnter", function(self) ShowTooltip(self, { label, tip }) end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  c:SetChecked(get())
  return c
end

function ns.MakeButton(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
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
-- Main window and tabs
---------------------------------------------------------------------------
local frame, petLine, tipLine
local tabs, tabOrder, activeTab = {}, {}, nil

function ns.RegisterTab(key, title, build, refresh)
  tabs[key] = { key = key, title = title, build = build, refresh = refresh }
  tabOrder[#tabOrder + 1] = key
end

local function SelectTab(key)
  activeTab = key
  for _, k in ipairs(tabOrder) do
    local t = tabs[k]
    if t.panel then t.panel:SetShown(k == key) end
    if t.button then
      if k == key then t.button:LockHighlight() else t.button:UnlockHighlight() end
    end
  end
  local t = tabs[key]
  if not t.panel then
    t.panel = CreateFrame("Frame", nil, frame)
    t.panel:SetPoint(L["TOPLEFT"], 8, -112)
    t.panel:SetPoint(L["BOTTOMRIGHT"], -8, 8)
    t.build(t.panel)
  end
  t.panel:Show()
  ns.UI_Refresh()
end

function ns.UI_Refresh()
  if not frame or not frame:IsShown() then return end
  local t = ns.Target()
  if t then
    local who
    if t.stabled then
      who = string.format("%sPlanning for:|r %s  %s, level %d  %s(stabled)|r", C.GOLD, t.name, ns.FamilyLabel(t.family), t.level or 0, C.GREY)
    elseif t.manual then
      who = string.format("%sPlanning for:|r %s  %s(no pet; assumes it knows nothing)|r", C.GOLD, t.family, C.GREY)
    else
      who = string.format("%s%s|r  %s, level %d", C.GOLD, t.name or "Pet", ns.FamilyLabel(t.family), t.level or 0)
      if t.tpFree then who = who .. string.format("   %s%d TP free|r", C.GREY, t.tpFree) end
    end
    petLine:SetText(who)
    frame.petIcon:SetTexture(ns.Icon(ns.FamilyIcons[t.family] or "Ability_Hunter_BeastTaming"))
  else
    petLine:SetText(C.GREY .. "No pet out. Summon one, or click Pick Family.|r")
    frame.petIcon:SetTexture(ns.Icon("Ability_Hunter_BeastTaming"))
  end
  if not ns.cdb.scanned then
    tipLine:SetText(C.ORANGE .. "Tip: open Beast Training once so I know which ranks you already have.|r")
  else
    local fl = ns.Pins_GetFocusLabel()
    tipLine:SetText(fl and (C.GOLD .. "Map focus:|r " .. fl .. C.GREY .. "   (/untamed clear to reset)|r") or "")
  end
  local tab = activeTab and tabs[activeTab]
  if tab and tab.panel and tab.refresh then tab.refresh(tab.panel, t) end
end
ns.On(L["REFRESH"], ns.UI_Refresh)
ns.On("PETCARE", function() if activeTab == "care" then ns.UI_Refresh() end end)

local familyPicker
local function BuildFamilyPicker(anchor)
  local p = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  p:SetFrameStrata(L["DIALOG"])
  p:SetSize(250, 20 + math.ceil((#ns.Families + 1) / 2) * 22)
  p:SetPoint(L["TOPLEFT"], anchor, L["BOTTOMLEFT"], 0, -2)
  if p.SetBackdrop then
    p:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  end
  local list = { L["My current pet"] }
  for _, f in ipairs(ns.Families) do list[#list + 1] = f end
  for idx, fam in ipairs(list) do
    local b = ns.MakeButton(p, fam, 112, function()
      if idx == 1 then ns.state.mode = "pet"; ns.state.family = nil
      else ns.state.mode = "manual"; ns.state.family = fam end
      p:Hide()
      ns.Refresh()
    end)
    b:SetHeight(20)
    b:SetPoint(L["TOPLEFT"], 10 + ((idx - 1) % 2) * 116, -10 - math.floor((idx - 1) / 2) * 22)
  end
  p:Hide()
  return p
end

local function CreateMainFrame()
  frame = CreateFrame("Frame", "UntamedFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(620, 620)
  frame:SetPoint(L["CENTER"], 200, 40)
  frame:SetFrameStrata(L["HIGH"])
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag(L["LeftButton"])
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  tinsert(UISpecialFrames, "UntamedFrame")

  local title = frame.TitleText or frame:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlight"])
  if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
  title:SetText("Untamed" .. (ns.FLAVOR == "forever" and " (Forever)" or ""))

  frame.petIcon = frame:CreateTexture(nil, L["ARTWORK"])
  frame.petIcon:SetSize(28, 28)
  frame.petIcon:SetPoint(L["TOPLEFT"], 14, -32)
  frame.petIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  petLine = frame:CreateFontString(nil, L["OVERLAY"], L["GameFontNormal"])
  petLine:SetPoint(L["LEFT"], frame.petIcon, L["RIGHT"], 8, 0)
  petLine:SetPoint(L["RIGHT"], frame, L["RIGHT"], -200, 0)
  petLine:SetJustifyH(L["LEFT"])
  petLine:SetWordWrap(false)

  local pick = ns.MakeButton(frame, L["Pick Family"], 96, function() familyPicker:SetShown(not familyPicker:IsShown()) end)
  pick:SetPoint(L["TOPRIGHT"], -112, -34)
  familyPicker = BuildFamilyPicker(pick)
  local mine = ns.MakeButton(frame, L["My Pet"], 90, function() ns.state.mode = "pet"; ns.state.family = nil; ns.Refresh() end)
  mine:SetPoint(L["LEFT"], pick, L["RIGHT"], 4, 0)

  tipLine = frame:CreateFontString(nil, L["OVERLAY"], L["GameFontHighlightSmall"])
  tipLine:SetPoint(L["TOPLEFT"], 16, -64)
  tipLine:SetPoint(L["RIGHT"], frame, L["RIGHT"], -14, 0)
  tipLine:SetJustifyH(L["LEFT"])

  local prev
  for _, k in ipairs(tabOrder) do
    local t = tabs[k]
    t.button = ns.MakeButton(frame, t.title, 82, function() SelectTab(k) end)
    if prev then t.button:SetPoint(L["LEFT"], prev, L["RIGHT"], 2, 0) else t.button:SetPoint(L["TOPLEFT"], 12, -82) end
    prev = t.button
  end

  frame:SetScript("OnShow", function() ns.UI_Refresh() end)
end

function ns.UI_Show(key)
  if not frame then CreateMainFrame() end
  local map = { plan = "plan", browse = "browse", care = "care", settings = "settings", builds = "builds", stable = "stable" }
  frame:Show()
  SelectTab(map[key] or activeTab or "abilities")
end

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

  local function Build(panel)
    list = ns.NewList(panel, 4)
  end

  local function Refresh(panel, t)
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local playerLevel = UnitLevel("player")
    if t then
      for _, e in ipairs(ns.Plan(t.family, t.level, t.known)) do
        local ab = e.ability
        local maxR = ns.MaxRank[ab] or 0
        local rightTxt
        if #e.ranks == 0 then
          rightTxt = (e.current >= maxR) and (C.GREEN .. "maxed|r") or (C.GREY .. "nothing usable yet|r")
        else
          rightTxt = C.GREY .. (e.current > 0 and ("pet has Rank " .. e.current) or "pet does not know it") .. "|r"
        end
        add(0, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTaming"), C.GOLD .. (collapsed[ab] and "+ " or "- ") .. ns.AbilityLabel(ab) .. "|r", rightTxt,
          function() collapsed[ab] = not collapsed[ab]; ns.UI_Refresh() end)
        if not collapsed[ab] then
          local firstOpen = true
          for _, r in ipairs(e.ranks) do
            local key = ab .. "#" .. r.rank
            local isOpen = expanded[key]
            if isOpen == nil then
              isOpen = firstOpen and not r.known and not r.tooHigh and #r.beasts > 0
              if isOpen then firstOpen = false end
            end
            local lvlTxt = r.level and (" (pet lvl " .. (r.levelExact and "" or "~") .. r.level .. ")") or ""
            local color = r.tooHigh and C.GREY or C.WHITE
            local beasts = r.beasts
            local label = string.format("%s%s Rank %d%s|r", color, (#beasts > 0 and not r.known) and (isOpen and "- " or "+ ") or "  ", r.rank, lvlTxt)
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
              L["Click to pin these beasts on your map."] })
            if isOpen and not r.known then
              for _, npcId in ipairs(beasts) do
                local b = ns.Beasts[npcId]
                local lvColor = (b[2] > playerLevel) and C.RED or C.WHITE
                add(28, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
                  string.format("%s%s|r %s%s|r", C.WHITE, b[1], lvColor, ns.LevelText(b)), ns.ZonesText(b),
                  ns.BeastClick(npcId), ns.BeastTooltip(npcId))
              end
            end
          end
        end
      end
      add(0, ns.Icon("Ability_Hunter_BeastTraining"), C.GOLD .. (trainerOpen and "- " or "+ ") .. "From Hunter pet trainers|r",
        C.GREY .. "Growl, armor, stamina, resistances|r", function() trainerOpen = not trainerOpen; ns.UI_Refresh() end)
      if trainerOpen then
        for _, ab in ipairs(ns.TrainerAbilities) do
          local cur = t.known[ab]
          add(14, nil, C.WHITE .. ab .. "|r", C.GREY .. (cur and ("pet has Rank " .. cur) or "not learned") .. "|r", nil,
            { ab, L["Buy higher ranks from any Hunter pet trainer in a capital or major town, then teach them at Beast Training."] })
        end
      end
    end
    list:Set(rows)
  end

  ns.RegisterTab("abilities", L["Abilities"], Build, Refresh)
end
