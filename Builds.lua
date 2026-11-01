local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Copy/paste popup (used for build strings and data sharing)
---------------------------------------------------------------------------
local popup
function ns.TextPopup(title, text, onAccept)
  if not popup then
    popup = CreateFrame("Frame", "UntamedTextPopup", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(460, 260)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    tinsert(UISpecialFrames, "UntamedTextPopup")
    popup.title = popup.TitleText or popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not popup.TitleText then popup.title:SetPoint("TOP", 0, -5) end
    popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.hint:SetPoint("TOPLEFT", 14, -30)
    popup.hint:SetPoint("RIGHT", -14, 0)
    popup.hint:SetJustifyH("LEFT")
    local sf = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -50)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(400)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() popup:Hide() end)
    sf:SetScrollChild(eb)
    popup.edit = eb
    popup.ok = ns.MakeButton(popup, L["Import"], 100, function()
      if popup.onAccept then popup.onAccept(popup.edit:GetText() or "") end
      popup:Hide()
    end)
    popup.ok:SetPoint("BOTTOMRIGHT", -14, 12)
    ns.MakeButton(popup, L["Close"], 90, function() popup:Hide() end):SetPoint("RIGHT", popup.ok, "LEFT", -6, 0)
  end
  popup.title:SetText(title)
  popup.onAccept = onAccept
  popup.ok:SetShown(onAccept ~= nil)
  popup.hint:SetText(onAccept and L["Paste the text below, then click Import."] or L["Press Ctrl+C to copy. The text is already selected."])
  popup.edit:SetText(text or "")
  popup:Show()
  popup.edit:SetFocus()
  popup.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Training point builds
---------------------------------------------------------------------------
local function BuildFor(family)
  ns.cdb.builds = ns.cdb.builds or {}
  ns.cdb.builds[family] = ns.cdb.builds[family] or {}
  return ns.cdb.builds[family]
end

-- Abilities this family can have in a build (beast-taught plus trainer abilities).
local function BuildAbilities(family)
  local out = {}
  for _, a in ipairs(ns.AbilityOrder) do
    local f = ns.AbilityFamilies[a]
    if f and f[family] then out[#out + 1] = a end
  end
  for _, a in ipairs(ns.TrainerAbilities) do out[#out + 1] = a end
  return out
end

-- Highest rank of an ability usable at a pet level.
local function MaxUsable(ability, level)
  local best = 0
  for r = 1, (ns.MaxRank[ability] or 0) do
    local lvl = ns.RankLevel(ability, r)
    if lvl and lvl <= level then best = r end
  end
  return best
end

local SPECIAL_DEFENSIVE = { ["Shell Shield"] = true, ["Thunderstomp"] = true, ["Cower"] = false }

local function Preset(family, level, role)
  local b = {}
  local abilities = BuildAbilities(family)
  local has = {}
  for _, a in ipairs(abilities) do has[a] = true end
  local function take(a) if has[a] then b[a] = MaxUsable(a, level) end end
  if role == "damage" or role == "pvp" then
    take("Bite"); take("Claw"); take("Dash"); take("Dive")
    for _, a in ipairs(abilities) do
      local fams = ns.AbilityFamilies[a]
      local n = 0
      if fams then for _ in pairs(fams) do n = n + 1 end end
      if fams and n <= 4 and a ~= "Dash" and a ~= "Dive" and not SPECIAL_DEFENSIVE[a] then take(a) end
    end
    if role == "pvp" then take("Great Stamina") else take("Growl") end
  elseif role == "tank" then
    take("Growl"); take("Bite"); take("Claw"); take("Natural Armor"); take("Great Stamina")
    for a in pairs(SPECIAL_DEFENSIVE) do if SPECIAL_DEFENSIVE[a] then take(a) end end
  end
  for a, r in pairs(b) do if r == 0 then b[a] = nil end end
  return b
end

function ns.ApplyPreset(t, role)
  ns.cdb.builds = ns.cdb.builds or {}
  ns.cdb.builds[t.family] = Preset(t.family, ns.db.planForPlayerLevel and UnitLevel("player") or t.level or UnitLevel("player"), role)
  ns.Refresh()
end

function ns.BuildCost(build)
  local total, unknown = 0, false
  for a, r in pairs(build) do
    local c = ns.RankCost(a, r)
    if c then total = total + c else unknown = true end
  end
  return total, unknown
end

local function ExportBuild(family, build)
  local parts = {}
  for a, r in pairs(build) do parts[#parts + 1] = a:gsub("[=,:]", "") .. "=" .. r end
  table.sort(parts)
  return "UT1:" .. family .. ":" .. table.concat(parts, ",")
end

local function ImportBuild(text)
  local family, body = text:match("UT1:([^:]+):(.*)")
  if not family then ns.Print(L["That doesn't look like an Untamed build string."]) return end
  local b = {}
  for a, r in body:gmatch("([^=,]+)=(%d+)") do b[strtrim(a)] = tonumber(r) end
  ns.cdb.builds = ns.cdb.builds or {}
  ns.cdb.builds[family] = b
  ns.Print(L["Imported a "] .. family .. " build.")
  ns.Refresh()
end

local list
local function Build(panel)
  local function presetBtn(label, role, x, tip)
    local btn = ns.MakeButton(panel, label, 80, function()
      local t = ns.Target()
      if not t then return end
      ns.cdb.builds = ns.cdb.builds or {}
      ns.cdb.builds[t.family] = Preset(t.family, ns.db.planForPlayerLevel and UnitLevel("player") or t.level or UnitLevel("player"), role)
      ns.Refresh()
    end)
    btn:SetPoint("TOPLEFT", x, -2)
    btn:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { label .. " preset", tip }) end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  presetBtn(L["Damage"], "damage", 4, L["Bite or Claw, your family's signature ability, and Dash or Dive, all at the best rank for its level."])
  presetBtn(L["Tank"], "tank", 88, L["Growl, Natural Armor, Great Stamina and your family's defensive ability."])
  presetBtn("PvP", "pvp", 172, L["Damage plus Great Stamina and mobility."])
  ns.MakeButton(panel, L["Clear"], 70, function()
    local t = ns.Target(); if t then ns.cdb.builds[t.family] = {}; ns.Refresh() end
  end):SetPoint("TOPLEFT", 256, -2)
  ns.MakeButton(panel, L["Export"], 76, function()
    local t = ns.Target(); if t then ns.TextPopup(L["Export build"], ExportBuild(t.family, BuildFor(t.family))) end
  end):SetPoint("TOPLEFT", 330, -2)
  ns.MakeButton(panel, L["Import"], 76, function()
    ns.TextPopup(L["Import build"], "", ImportBuild)
  end):SetPoint("TOPLEFT", 410, -2)
  list = ns.NewList(panel, 30)
end

local function Refresh(panel, t)
  local rows = {}
  local function add(...) rows[#rows + 1] = { ... } end
  if not t then
    add(0, nil, C.GREY .. "Summon your pet or pick a family to plan a build.|r")
    list:Set(rows) return
  end
  local level = ns.db.planForPlayerLevel and UnitLevel("player") or t.level or UnitLevel("player")
  local build = BuildFor(t.family)
  local cost, unknown = ns.BuildCost(build)
  local _, totalTP = ns.PetTrainingPoints()
  if t.manual or t.stabled then totalTP = nil end
  local fits = totalTP and cost <= totalTP
  add(0, ns.Icon(ns.FamilyIcons[t.family] or "Ability_Hunter_BeastTaming"),
    string.format("%s%s build|r (pet level %d)", C.GOLD, t.family, level),
    string.format("%s%d%s TP|r%s", totalTP and (fits and C.GREEN or C.RED) or C.WHITE, cost, unknown and "+" or "",
      totalTP and (" of " .. totalTP) or ""),
    nil, { L["Training points"], L["Total cost of the ranks in this build"] .. (totalTP and (", against the " .. totalTP .. " training points your pet has in total.") or "."),
      unknown and L["Some costs are unknown until you open Beast Training once (shown as +)."] or "",
      L["Pets gain training points as they level and as their loyalty grows."] }, { header = true })
  add(0, nil, C.GREY .. "Left-click a row to raise its rank, right-click to lower it.|r", "")
  for _, a in ipairs(BuildAbilities(t.family)) do
    local r = build[a] or 0
    local max = MaxUsable(a, level)
    local have = t.known and t.known[a] or 0
    local c = r > 0 and ns.RankCost(a, r)
    local right
    if r > 0 then
      right = (c and (C.WHITE .. c .. " TP|r") or (C.GREY .. "? TP|r"))
      if r > have and not ns.HunterKnows(a, r) and ns.AbilityFamilies[a] then right = C.ORANGE .. "tame to learn|r  " .. right end
    else
      right = C.GREY .. "not in build|r"
    end
    add(0, ns.Icon(ns.AbilityIcons[a] or "Ability_Hunter_BeastTraining"),
      string.format("%s%s|r", r > 0 and C.WHITE or C.GREY, ns.AbilityLabel(a)),
      right,
      function(_, button)
        if button == "RightButton" then build[a] = (r > 1) and (r - 1) or nil
        else build[a] = math.min(r + 1, math.max(max, 1)) end
        ns.Refresh()
      end,
      { a, L["Best rank at pet level "] .. level .. ": " .. (max > 0 and max or "none yet"),
        have > 0 and (L["Your pet has Rank "] .. have) or L["Your pet doesn't have it."] },
      { mid = r > 0 and (C.WHITE .. L["Rank "] .. r .. "|r") or "" })
  end
  list:Set(rows)
end

ns.RegisterTab("builds", L["Builds"], Build, Refresh)
