local _, ns = ...
local L = ns.L
local C = ns.C

-- Stable manager: remembers every pet you own (recorded whenever it is out or
-- when you visit a stable master) and shows which ranks you already know that
-- each one can use.

local function Pets()
  ns.cdb.pets = ns.cdb.pets or {}
  return ns.cdb.pets
end

-- Which beast a pet was tamed from: noted when you cast Tame Beast (the beast you had targeted), and
-- pinned to the pet that shows up right after. Older pets: a beast of the same name and family.
local taming = {}
function ns.PetOrigin(p)
  if not p then return nil end
  if p.from and ns.Beasts[p.from] then return p.from, true end
  for id, b in pairs(ns.Beasts) do
    if b[1] == p.name and b[4] == p.family then return id, true end
  end
  -- not known: a beast of its family near its level, to have something to show
  local best, bd
  for id, b in pairs(ns.Beasts) do
    if b[4] == p.family then
      local d = math.abs(((b[2] + b[3]) / 2) - (p.level or 1))
      if not bd or d < bd or (d == bd and id < best) then best, bd = id, d end
    end
  end
  return best, false
end

-- A pet's attack speed. From the beast it was tamed from when that's known; else from its
-- "Faster Attack" / "Slower Attack" passive, once Untamed has seen which speed that tier means (it
-- learns that from pets whose beast it does know; tier VI = 1.2 s was read off a Starving Mountain Lion).
local TIER_SEED = { ["Faster Attack VI"] = 1.2 }
local function SpeedTier(p)
  for a in pairs(p.known or {}) do
    if a:find("^Faster Attack") or a:find("^Slower Attack") then return a end
  end
end
function ns.PetSpeed(p)
  local from, sure = ns.PetOrigin(p)
  local tier = SpeedTier(p)
  ns.db.speedTiers = ns.db.speedTiers or {}
  if sure and from and ns.Beasts[from][9] then
    if tier then ns.db.speedTiers[tier] = ns.Beasts[from][9] end
    return ns.Beasts[from][9]
  end
  if tier then return ns.db.speedTiers[tier] or TIER_SEED[tier], tier end
  if p.known and next(p.known) and not tier then return 2.0 end     -- read, and no speed passive: the normal 2.0
  return nil
end

-- /ut tamedfrom <beast>: tell Untamed which beast the pet that's out was tamed from
function ns.PetSetOrigin(text)
  text = (text or ""):lower():match("^%s*(.-)%s*$")
  local info = UnitExists("pet") and ns.ScanPet()
  if not info then ns.Print(L["Call the pet first, then: /ut tamedfrom <beast's name>"]) return end
  local p = Pets()[ns.PetKey(info.name, info.family)]
  if not p then return end
  if text == "" then
    local from, sure = ns.PetOrigin(p)
    ns.Print(sure and string.format(L["%s was tamed from %s."], p.name, ns.Beasts[from][1]) or L["Not known yet. Type: /ut tamedfrom <beast's name>"])
    return
  end
  local exact, partial, n = nil, nil, 0
  for id, b in pairs(ns.Beasts) do
    if b[4] == info.family then
      local name = b[1]:lower()
      if name == text then exact = id elseif name:find(text, 1, true) then partial = id; n = n + 1 end
    end
  end
  local id = exact or (n == 1 and partial) or nil
  if not id then
    if n > 1 then ns.Print(string.format(L["%d %s beasts match '%s': type more of the name."], n, ns.FamilyLabel(info.family), text))
    else ns.Print(string.format(L["No %s beast is called '%s'."], ns.FamilyLabel(info.family), text)) end
    return
  end
  p.from = id
  ns.Print(string.format(L["Noted: %s was tamed from %s."], p.name, ns.Beasts[id][1]))
  ns.Refresh()
end

-- Remember the pet that is out right now.
local function RecordActive()
  local info = ns.ScanPet()
  if not info then return end
  local key = ns.PetKey(info.name, info.family)
  local isNew = Pets()[key] == nil
  local p = Pets()[key] or {}
  if taming.id and (isNew or not p.from) and GetTime() - (taming.at or 0) < 45 then
    local b = ns.Beasts[taming.id]
    if b and b[4] == info.family then p.from = taming.id; taming.id = nil end
  end
  p.name, p.family, p.level, p.known, p.seen = info.name, info.family, info.level, info.known, time()
  p.active = true
  Pets()[key] = p
  for k, other in pairs(Pets()) do if k ~= key then other.active = nil end end
  ns.cdb.hasActivePet = true
end

-- Read the stable window (Classic Era: GetStablePetInfo; Forever: C_StableInfo).
local function ReadStable()
  local seen = {}
  local function add(name, level, family, isCurrent)
    if not name then return end
    family = ns.ToEnglish(family)
    local key = ns.PetKey(name, family)
    local p = Pets()[key] or { known = {} }
    p.name, p.family, p.level = name, family, level or p.level
    p.stabled = not isCurrent
    p.seen = time()
    Pets()[key] = p
    seen[key] = true
  end
  local hasCurrent = false
  if C_StableInfo and C_StableInfo.GetStablePetInfo then
    for i = 1, 12 do
      local ok, info = pcall(C_StableInfo.GetStablePetInfo, i)
      if ok and info then
        add(info.name, info.level, info.familyName, i == 1)
        if i == 1 then hasCurrent = true end
      end
    end
  elseif GetStablePetInfo then
    for i = 0, (NUM_PET_STABLE_SLOTS or 2) + 1 do
      local ok, _, name, level, family = pcall(GetStablePetInfo, i)
      if ok and name then
        add(name, level, family, i <= 1)
        if i <= 1 then hasCurrent = true end
      end
    end
  end
  ns.cdb.hasActivePet = hasCurrent or UnitExists("pet")
  ns.Refresh()
end

ns.On("REFRESH", function() if UnitExists("pet") then RecordActive() end end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PET_STABLE_CLOSED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_START" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, unit, _, spellID)
  if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_START" then
    if unit ~= "player" or not spellID or ns.IsSecret(spellID) or spellID ~= 1515 then return end
    local ok, guid = pcall(UnitGUID, "target")
    local id = ok and guid and not ns.IsSecret(guid) and ns.NpcIdFromGUID(guid)
    if id and ns.Beasts[id] then taming.id, taming.at = id, GetTime() end
    return
  end
  if event == "PET_STABLE_CLOSED" then
    ns.cdb.hasActivePet = UnitExists("pet") and true or ns.cdb.hasActivePet
    ns.Fire("STABLE_CLOSED")
  else
    ReadStable()
  end
end)

-- Does the hunter have a pet (out, or dismissed) that would block taming?
function ns.HasActivePet()
  if UnitExists("pet") then return true end
  if C_StableInfo and C_StableInfo.GetNumActivePets then
    local ok, n = pcall(C_StableInfo.GetNumActivePets)
    if ok and type(n) == "number" then return n > 0 end
  end
  return ns.cdb.hasActivePet and true or false
end

-- Ranks you already know that this pet can use and doesn't have yet.
function ns.ReadyUpgrades(p)
  local out = {}
  for _, e in ipairs(ns.Plan(p.family, p.level, p.known or {})) do
    local best
    for _, r in ipairs(e.ranks) do if r.known and not r.tooHigh then best = r end end
    if best then out[#out + 1] = e.ability .. " " .. best.rank end
  end
  return out
end

---------------------------------------------------------------------------
-- Page: your pets as a journal. The list on the left, the pet's page on the right: its model,
-- what it knows, what you can teach it right now, what to tame next for it, and whether a faster
-- beast of its family is within reach.
---------------------------------------------------------------------------
local list, page, left
local selected
local rowKeys = {}

local function Keys()
  local keys = {}
  for k in pairs(Pets()) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local x, y = Pets()[a], Pets()[b]
    if (x.active and 1 or 0) ~= (y.active and 1 or 0) then return x.active and true or false end
    if (x.level or 0) ~= (y.level or 0) then return (x.level or 0) > (y.level or 0) end
    return a < b
  end)
  return keys
end

-- what to tame next for a pet: the next rank of each ability you don't know yet, with a beast for it
function ns.PetNextToLearn(p, max)
  local out = {}
  local playerLevel = UnitLevel("player")
  for _, e in ipairs(ns.Plan(p.family, p.level, p.known or {})) do
    for _, r in ipairs(e.ranks) do
      if not r.known and not r.tooHigh and r.beasts and #r.beasts > 0 then
        local best, bd
        for _, id in ipairs(r.beasts) do
          local b = ns.Beasts[id]
          if b and b[2] <= playerLevel then
            local _, _, _, d = ns.NearestSpawn(id)
            d = d or 9e8
            if not bd or d < bd then best, bd = id, d end
          end
        end
        if best then out[#out + 1] = { ability = e.ability, rank = r.rank, beast = best, dist = bd < 9e8 and bd or nil } end
        break
      end
    end
    if max and #out >= max then break end
  end
  return out
end

-- a faster beast of the same family you could tame now (nil if this one is already as fast as it gets)
function ns.PetFasterKin(p)
  local mine = ns.PetSpeed(p)
  local playerLevel = UnitLevel("player")
  local best
  for id, b in pairs(ns.Beasts) do
    if b[4] == p.family and b[9] and b[2] <= playerLevel and (not mine or b[9] < mine) then
      if not best or b[9] < ns.Beasts[best][9] or (b[9] == ns.Beasts[best][9] and b[3] > ns.Beasts[best][3]) then best = id end
    end
  end
  return best, mine
end

local function FillPage()
  if not page then return end
  local p = selected and Pets()[selected]
  page.empty:SetShown(not p)
  page.body:SetShown(p and true or false)
  if not p then return end
  local icon = ns.Icon(ns.FamilyIcons[p.family] or "Ability_Hunter_BeastTaming")
  local from, sure = ns.PetOrigin(p)
  if p.active and UnitExists("pet") then page.box:Unit("pet", icon)
  elseif from then page.box:Beast(from, icon)
  else page.box:Nothing(icon) end

  page.name:SetText(p.name or "?")
  local status = p.active and (C.GREEN .. L["out now"] .. "|r") or (p.stabled and (C.GREY .. L["in your stable"] .. "|r")
    or (C.GREY .. string.format(L["last seen %s"], date("%b %d", p.seen or 0)) .. "|r"))
  page.sub:SetText(string.format("%s   %s %d   %s", ns.FamilyLabel(p.family), L["level"], p.level or 0, status))

  page.origin.value:SetText(from and sure and (ns.Beasts[from][1] .. C.GREY .. "   " .. ns.ZonesText(ns.Beasts[from]) .. "|r")
    or (C.GREY .. (p.active and L["not known: type /ut tamedfrom and its name"] or L["not known (Untamed notes it when you tame a beast)"]) .. "|r"))
  local speed, tier = ns.PetSpeed(p)
  page.speed.value:SetText(speed and (((speed < 2.0) and C.GREEN or (speed > 2.0 and C.ORANGE or C.WHITE)) .. string.format("%.1f s", speed) .. "|r")
    or (C.GREY .. (tier and (tier .. ": " .. L["speed not learned yet"]) or L["not known"]) .. "|r"))
  local st = ns.FamilyStats and ns.FamilyStats[p.family]
  local function S(n) return (n > 0 and "+" or "") .. n end
  page.family.value:SetText(st and string.format(L["%s%% damage, %s%% armor, %s%% health"], S(st[1]), S(st[2]), S(st[3])) or "")

  -- its abilities, not the pet bar's commands (Attack, Follow, Stay ...) or the speed passive
  local known = {}
  for a, r in pairs(p.known or {}) do
    if ns.AbilityFamilies[a] or ns.RankLevel(a, r) then known[#known + 1] = (ns.AbilityLabel(a) or a) .. " " .. r end
  end
  table.sort(known)
  page.knows:SetText(#known > 0 and table.concat(known, ",  ") or (C.GREY .. L["Not read yet: summon it once."] .. "|r"))

  local ups = ns.ReadyUpgrades(p)
  local lines = {}
  for _, u in ipairs(ups) do lines[#lines + 1] = C.GREEN .. u .. "|r" end
  page.ready:SetText(#lines > 0 and (table.concat(lines, ",  ") .. "\n" .. C.GREY .. L["You know these ranks already: teach them in Beast Training."] .. "|r")
    or (C.GREY .. L["Nothing waiting: it has every rank you know that it can use."] .. "|r"))

  lines = {}
  for _, n in ipairs(ns.PetNextToLearn(p, 5)) do
    local b = ns.Beasts[n.beast]
    lines[#lines + 1] = string.format("%s%s %d|r   %s%s|r%s", C.WHITE, ns.AbilityLabel(n.ability) or n.ability, n.rank, C.GOLD, b[1],
      C.GREY .. "   " .. ns.ZonesText(b) .. (n.dist and (", " .. ns.FormatDistance(n.dist)) or "") .. "|r")
  end
  local kin, mine = ns.PetFasterKin(p)
  if kin and (not mine or ns.Beasts[kin][9] < mine) then
    local b = ns.Beasts[kin]
    lines[#lines + 1] = C.GREY .. string.format(mine and L["A faster %s you could tame: %s (%.1f s), %s."] or L["The fastest %s you could tame: %s (%.1f s), %s."],
      ns.FamilyLabel(p.family), C.GOLD .. b[1] .. "|r" .. C.GREY, b[9], ns.ZonesText(b)) .. "|r"
  end
  page.next:SetText(#lines > 0 and table.concat(lines, "\n") or (C.GREY .. L["Nothing left to tame for it at your level."] .. "|r"))

  local viewing = (ns.state.mode == "stable" and ns.state.key == selected) or (ns.state.mode == "pet" and p.active)
  page.plan:SetText(viewing and L["Planning for it"] or L["Plan for this pet"])
end

local function PaintRow(i, on)
  local r = list and list.rows[i]
  if not r or not rowKeys[i] then return end
  if on then r.bg:SetColorTexture(1, 0.82, 0, 0.20); r.bg:Show()
  elseif (i - 1) % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.04); r.bg:Show()
  else r.bg:Hide() end
end

local function Select(key)
  if selected == key then return end
  for i, k in pairs(rowKeys) do if k == selected then PaintRow(i, false) end end
  selected = key
  for i, k in pairs(rowKeys) do if k == key then PaintRow(i, true) end end
  FillPage()
end
ns.StableSelected = function() return selected end

local function PlanFor(key)
  local p = Pets()[key]
  if not p then return end
  if p.active then ns.state.mode, ns.state.key, ns.state.family = "pet", nil, nil
  else ns.state.mode, ns.state.key = "stable", key end
  ns.Print(string.format(L["Planning for %s: the Abilities, Builds and Planner pages now show this pet."], p.name))
  ns.Refresh()
end

local function Tile(parent, label)
  local t = {}
  t.label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  t.label:SetText(label)
  t.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
  t.value:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
  t.value:SetJustifyH("LEFT")
  t.value:SetWordWrap(false)
  return t
end

local function Para(parent, anchor, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  fs:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
  fs:SetJustifyH("LEFT")
  fs:SetSpacing(5)
  return fs
end

local function Build(panel)
  left = CreateFrame("Frame", nil, panel)
  left:SetPoint("TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", 0, 0)
  left:SetWidth(340)
  list = ns.NewList(left, 4)

  page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  page:SetPoint("BOTTOMRIGHT", -4, 4)
  local bg = page:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.28)
  page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  page.empty:SetPoint("CENTER")
  page.empty:SetWidth(300)
  page.empty:SetText(L["No pets recorded yet. Summon each pet once, or open the stable at a stable master."])
  local body = CreateFrame("Frame", nil, page)
  body:SetAllPoints()
  page.body = body

  page.box = ns.MakeModelBox(body, 210)
  page.box:SetPoint("TOPLEFT", 12, -12)
  page.name = body:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  page.name:SetPoint("TOPLEFT", page.box, "TOPRIGHT", 14, -2)
  page.name:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  page.name:SetJustifyH("LEFT")
  page.name:SetWordWrap(false)
  page.sub = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.sub:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -5)
  page.sub:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  page.sub:SetJustifyH("LEFT")
  page.sub:SetWordWrap(false)
  page.origin = Tile(body, L["Tamed from"])
  page.origin.label:SetPoint("TOPLEFT", page.sub, "BOTTOMLEFT", 0, -16)
  page.speed = Tile(body, L["Attack speed"])
  page.speed.label:SetPoint("TOPLEFT", page.origin.label, "BOTTOMLEFT", 0, -30)
  page.family = Tile(body, L["Its family"])
  page.family.label:SetPoint("TOPLEFT", page.speed.label, "BOTTOMLEFT", 0, -30)

  page.plan = ns.MakeButton(body, L["Plan for this pet"], 130, function() if selected then PlanFor(selected) end end)
  page.plan:SetPoint("TOPLEFT", page.box, "BOTTOMLEFT", 0, -12)
  page.plan:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L["Plan for this pet"], L["The Abilities, Builds and Planner pages show this pet instead of the one that is out."] }) end)
  page.plan:SetScript("OnLeave", function() GameTooltip:Hide() end)
  page.find = ns.MakeButton(body, L["Beasts for it"], 110, function()
    local p = selected and Pets()[selected]
    if not p then return end
    local f = ns.BrowserFilter()
    f.family, f.fresh, f.teaches, f.where, f.rare = p.family, true, "any", "any", false
    ns.UI_Show("browse")
  end)
  page.find:SetPoint("LEFT", page.plan, "RIGHT", 6, 0)
  page.find:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L["Beasts for it"], L["Opens the Bestiary on its family, showing beasts that teach a rank you don't know."] }) end)
  page.find:SetScript("OnLeave", function() GameTooltip:Hide() end)
  page.forget = ns.MakeButton(body, L["Forget"], 80, function()
    if not selected then return end
    Pets()[selected] = nil
    if ns.state.key == selected then ns.state.mode, ns.state.key = "pet", nil end
    selected = nil
    ns.Refresh()
  end)
  page.forget:SetPoint("LEFT", page.find, "RIGHT", 6, 0)
  page.forget:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L["Forget"], L["Takes this pet off the list (for pets you've abandoned). It comes back if you summon it."] }) end)
  page.forget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local function BackToRow()
    for i, k in pairs(rowKeys) do if k == selected then return list.rows[i] end end
  end
  page.plan.padNeighbor = { left = BackToRow }

  local h1 = ns.MakeHeading(body, L["Teach it now"])
  h1:SetPoint("TOPLEFT", page.plan, "BOTTOMLEFT", 0, -18)
  page.ready = Para(body, h1)
  local h2 = ns.MakeHeading(body, L["Tame next for it"])
  h2:SetPoint("TOPLEFT", page.ready, "BOTTOMLEFT", 0, -18)
  page.next = Para(body, h2)
  local h3 = ns.MakeHeading(body, L["Knows"])
  h3:SetPoint("TOPLEFT", page.next, "BOTTOMLEFT", 0, -18)
  page.knows = Para(body, h3, "GameFontHighlightSmall")
end

local function Refresh()
  local keys = Keys()
  local keep = false
  for _, k in ipairs(keys) do if k == selected then keep = true end end
  if not keep then selected = keys[1] end
  wipe(rowKeys)
  local rows = {}
  if #keys > 0 then rows[1] = { 0, nil, ns.Count(#keys, L["pet"], L["pets"]), "", nil, nil, { header = true } } end
  for _, k in ipairs(keys) do
    local p = Pets()[k]
    local ups = ns.ReadyUpgrades(p)
    local name = (p.active and C.GREEN or C.WHITE) .. (p.name or "?") .. "|r" .. C.GREY .. "  " .. ns.FamilyLabel(p.family) .. "|r"
    if #ups > 0 then name = name .. C.GREEN .. "  " .. string.format(L["%d to teach"], #ups) .. "|r" end
    rows[#rows + 1] = { 0, ns.Icon(ns.FamilyIcons[p.family] or "Ability_Hunter_BeastTaming"), name, C.GREY .. (p.level or 0) .. "|r",
      function(_, button)
        if button == "RightButton" or selected == k then PlanFor(k) else Select(k) end
      end,
      function() if ns.padFocusing then Select(k) end return nil end }
    rowKeys[#rows] = k
  end
  list:Set(rows)
  for i, k in pairs(rowKeys) do if k == selected then PaintRow(i, true) end end
  FillPage()
end

ns.RegisterTab("stable", L["Stable"], Build, Refresh)
