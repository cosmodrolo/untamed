local _, ns = ...
local L = ns.L
local C = ns.C

-- Pet browser: every tameable beast, filterable and sortable.
local list, search, famBtn, sortBtn
local filter = { family = nil, text = "", tameable = false, rare = false, teaches = false, sort = "level" }
local SORTS = { "level", "name", "speed" }
local SORT_LABEL = { level = L["Sort: Level"], name = L["Sort: Name"], speed = L["Sort: Speed"] }

local function Build(panel)
  search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  search:SetSize(140, 20)
  search:SetPoint("TOPLEFT", 10, -3)
  search:SetAutoFocus(false)
  search:SetScript("OnTextChanged", function(self) filter.text = (self:GetText() or ""):lower(); ns.UI_Refresh() end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", 4, 0)
  hint:SetText(L["Search name or zone"])
  search:HookScript("OnEditFocusGained", function() hint:Hide() end)
  search:HookScript("OnEditFocusLost", function(self) hint:SetShown((self:GetText() or "") == "") end)

  local famList = { false }
  for _, f in ipairs(ns.Families) do famList[#famList + 1] = f end
  local famIdx = 1
  famBtn = ns.MakeButton(panel, L["All families"], 110, function(_, button)
    famIdx = famIdx + (button == "RightButton" and -1 or 1)
    if famIdx > #famList then famIdx = 1 elseif famIdx < 1 then famIdx = #famList end
    filter.family = famList[famIdx] or nil
    famBtn:SetText(filter.family and ns.FamilyLabel(filter.family) or L["All families"])
    ns.UI_Refresh()
  end)
  famBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  famBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
  famBtn:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { "Family filter", "Left-click: next family. Right-click: previous." }) end)
  famBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local sortIdx = 1
  sortBtn = ns.MakeButton(panel, SORT_LABEL.level, 96, function()
    sortIdx = sortIdx % #SORTS + 1
    if ns.FLAVOR == "forever" and SORTS[sortIdx] == "speed" then sortIdx = sortIdx % #SORTS + 1 end
    filter.sort = SORTS[sortIdx]
    sortBtn:SetText(SORT_LABEL[filter.sort])
    ns.UI_Refresh()
  end)
  sortBtn:SetPoint("LEFT", famBtn, "RIGHT", 4, 0)

  ns.MakeCheck(panel, L["Tameable now"], 4, -26, function() return filter.tameable end, function(v) filter.tameable = v end)
  ns.MakeCheck(panel, L["Rares only"], 124, -26, function() return filter.rare end, function(v) filter.rare = v end)
  ns.MakeCheck(panel, L["Teaches abilities"], 234, -26, function() return filter.teaches end, function(v) filter.teaches = v end)
  list = ns.NewList(panel, 52)
end

local function Matches(b, playerLevel)
  if filter.family and b[4] ~= filter.family then return false end
  if filter.tameable and b[2] > playerLevel then return false end
  if filter.rare and not (b[5] and b[5]:find("Rare")) then return false end
  if filter.teaches and #b[6] == 0 then return false end
  if filter.text ~= "" then
    local hay = b[1]:lower() .. " " .. (b[8] or ""):lower()
    for mapID in pairs(b[7]) do hay = hay .. " " .. (ns.ZoneName(mapID)):lower() end
    if not hay:find(filter.text, 1, true) then return false end
  end
  return true
end

local function Refresh()
  local playerLevel = UnitLevel("player")
  local ids = {}
  for id, b in pairs(ns.Beasts) do if Matches(b, playerLevel) then ids[#ids + 1] = id end end
  local B = ns.Beasts
  table.sort(ids, function(a, b)
    local x, y = B[a], B[b]
    if filter.sort == "name" then return x[1] < y[1] end
    if filter.sort == "speed" and (x[9] or 9) ~= (y[9] or 9) then return (x[9] or 9) < (y[9] or 9) end
    if x[2] ~= y[2] then return x[2] < y[2] end
    return x[1] < y[1]
  end)
  local rows = {}
  rows[1] = { 0, nil, #ids .. L[" beasts"], C.GREY .. L["click for arrow, right-click for map"] .. "|r", nil, nil, { header = true } }
  for i = 1, math.min(#ids, 400) do
    local id = ids[i]
    local b = B[id]
    local lv = (b[2] > playerLevel) and C.RED or C.WHITE
    local left = string.format("%s%s|r", b[5] and C.ORANGE or C.WHITE, b[1])
    local right = ns.ZonesText(b)
    if b[9] then right = C.GREY .. b[9] .. "s|r  " .. right end
    rows[#rows + 1] = { 0, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"), left, right, ns.BeastClick(id), ns.BeastTooltip(id), { mid = lv .. ns.LevelText(b) .. "|r" } }
  end
  list:Set(rows)
end

ns.RegisterTab("browse", L["Browser"], Build, Refresh)
