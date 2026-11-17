local _, ns = ...
local C, L = ns.C, ns.L

-- Pet recommender: pick a role, get the best families for it and the best
-- actual beasts to tame near you, plus a matching starting build.

-- Family modifiers in percent: damage, armor, health. From WoW Forever's client data (each family's
-- "Tamed Pet Passive" spell, wago.tools build 1.60.1.70790). Forever kept the Classic values; Fox
-- shares Wolf's passive and Bird of Prey has the old Owl one. Pets also scale with your gear in Forever.
local STATS = {
  ["Bat"] = { 7, 0, 0 }, ["Bear"] = { -9, 5, 8 }, ["Bird of Prey"] = { 7, 0, 0 }, ["Boar"] = { -10, 9, 4 },
  ["Carrion Bird"] = { 0, 5, 0 }, ["Cat"] = { 10, 0, -2 }, ["Crab"] = { -5, 13, -4 }, ["Crocolisk"] = { 0, 10, -5 },
  ["Fox"] = { 0, 5, 0 }, ["Gorilla"] = { 2, 0, 4 }, ["Hyena"] = { 0, 5, 0 }, ["Raptor"] = { 10, 3, -5 },
  ["Scorpid"] = { -6, 10, 0 }, ["Spider"] = { 7, 0, 0 }, ["Tallstrider"] = { 0, 0, 5 }, ["Turtle"] = { -10, 13, 0 },
  ["Wind Serpent"] = { 7, 0, 0 }, ["Wolf"] = { 0, 5, 0 },
}
ns.FamilyStats = STATS

-- What each ability brings to a role (points added to a family's score).
local ABILITY_ROLE = {
  ["Shell Shield"] = { tank = 6 }, ["Thunderstomp"] = { tank = 5, utility = 2 }, ["Growl"] = { tank = 1 },
  ["Charge"] = { utility = 4, pvp = 3 }, ["Furious Howl"] = { utility = 6, dps = 2 }, ["Screech"] = { utility = 4, tank = 2 },
  ["Demoralizing Screech"] = { utility = 4, tank = 2 }, ["Prowl"] = { utility = 3, pvp = 3, dps = 1 },
  ["Lightning Breath"] = { dps = 3, utility = 2 }, ["Scorpid Poison"] = { dps = 2, pvp = 2 },
  ["Dash"] = { pvp = 3, utility = 1 }, ["Dive"] = { pvp = 3, utility = 1 }, ["Bite"] = { dps = 1, leveling = 1 },
  ["Claw"] = { dps = 1, leveling = 1 },
  -- WoW Forever family abilities
  ["Swipe"] = { dps = 3, tank = 2 }, ["Savage Rend"] = { dps = 4 }, ["Tendon Rip"] = { utility = 4, pvp = 4 },
  ["Web"] = { utility = 4, pvp = 4 }, ["Dust Cloud"] = { tank = 3, utility = 2 }, ["Pinch"] = { dps = 2 },
  ["Dismember"] = { dps = 4 }, ["Mine!"] = { utility = 3 }, ["Sonic Blast"] = { utility = 4, pvp = 4 },
  ["Trickster's Dance"] = { tank = 3, pvp = 2 },
}

local ROLES = {
  { key = "tank", label = "Tank", tip = "Holds threat and survives: armor and health bonuses, taunts and defensive abilities." },
  { key = "dps", label = "Damage", tip = "Most damage: damage bonus, fast attacks and damage abilities." },
  { key = "leveling", label = "Leveling", tip = "Solo questing: good damage with enough toughness, and both Bite and Claw if possible." },
  { key = "pvp", label = "PvP", tip = "Fast attacks, mobility and control." },
  { key = "utility", label = "Utility", tip = "Group buffs, debuffs, interrupts and stealth." },
}

local function FamilyAbilities(family)
  local out = {}
  for _, a in ipairs(ns.AbilityOrder) do
    local f = ns.AbilityFamilies[a]
    if f and f[family] and a ~= "Cower" then out[#out + 1] = a end
  end
  return out
end

-- Score every family for a role. Returns sorted { family, score, reasons }.
function ns.RankFamilies(role)
  local out = {}
  for _, fam in ipairs(ns.Families) do
    local score, reasons = 0, {}
    local st = ns.FamilyStats and ns.FamilyStats[fam]
    if st then
      local dmg, arm, hp = st[1], st[2], st[3]
      if role == "tank" then score = score + arm * 0.8 + hp * 1.0 + dmg * 0.2
      elseif role == "dps" then score = score + dmg * 1.5 + (arm + hp) * 0.1
      elseif role == "leveling" then score = score + dmg * 0.9 + (arm + hp) * 0.5
      elseif role == "pvp" then score = score + dmg * 1.0 + hp * 0.5 + arm * 0.2
      else score = score + (dmg + arm + hp) * 0.1 end
      local parts = {}
      if dmg ~= 0 then parts[#parts + 1] = string.format("%+d%% %s", dmg, L["damage"]) end
      if arm ~= 0 then parts[#parts + 1] = string.format("%+d%% %s", arm, L["armor"]) end
      if hp ~= 0 then parts[#parts + 1] = string.format("%+d%% %s", hp, L["health"]) end
      if #parts > 0 then reasons[#reasons + 1] = table.concat(parts, ", ") end
    end
    local abil = FamilyAbilities(fam)
    local hasBite, hasClaw = false, false
    local good = {}
    for _, a in ipairs(abil) do
      local r = ABILITY_ROLE[a]
      if a == "Bite" then hasBite = true elseif a == "Claw" then hasClaw = true end
      if r and r[role] and r[role] > 1 then score = score + r[role]; good[#good + 1] = ns.AbilityLabel(a)
      elseif r and r[role] then score = score + r[role] end
    end
    if role == "leveling" and hasBite and hasClaw then score = score + 3; good[#good + 1] = L["Bite and Claw"] end
    if #good > 0 then reasons[#reasons + 1] = table.concat(good, ", ") end
    out[#out + 1] = { family = fam, score = score, reasons = reasons }
  end
  table.sort(out, function(a, b) return a.score > b.score end)
  return out
end

-- Best actual beasts of a family: tameable now, fastest attack, highest level, closest.
function ns.BestBeasts(family, role, maxCount)
  local playerLevel = UnitLevel("player")
  local pc, pe, pn = ns.PlayerWorld()
  local list = {}
  for id, b in pairs(ns.Beasts) do
    if b[4] == family and b[2] <= playerLevel and next(b[7]) then
      local _, _, _, d = ns.NearestSpawn(id, pc, pe, pn)
      list[#list + 1] = { id = id, speed = b[9] or 2.0, level = b[3], dist = d or 1e9, rare = b[5] and b[5]:find("Rare") }
    end
  end
  local speedMatters = role ~= "tank" and role ~= "utility"
  table.sort(list, function(a, b)
    if speedMatters and a.speed ~= b.speed then return a.speed < b.speed end
    if math.abs(a.level - b.level) > 4 then return a.level > b.level end
    return a.dist < b.dist
  end)
  local out = {}
  for i = 1, math.min(maxCount or 4, #list) do out[i] = list[i] end
  return out
end

---------------------------------------------------------------------------
-- Page: pick what you want the pet for; the families are ranked on the left, and the family's
-- page on the right says why, what it can learn, and the best ones to tame now.
---------------------------------------------------------------------------
local list, j, chips = nil, nil, {}
local tiles, why, learns, best = {}, nil, nil, nil
local ranked = {}
local ROLE_TO_PRESET = { tank = "tank", dps = "damage", leveling = "damage", pvp = "pvp", utility = "pvp" }

local function CountTameable(family)
  local n, level = 0, UnitLevel("player")
  for _, b in pairs(ns.Beasts) do if b[4] == family and b[2] <= level and next(b[7]) then n = n + 1 end end
  return n
end
local function Role() return ns.db.recRole or "dps" end
local function RoleLabel()
  for _, r in ipairs(ROLES) do if r.key == Role() then return L[r.label] end end
end

local function PlanFor(family)
  ns.state.mode = "manual"; ns.state.family = family
  ns.cdb.builds = ns.cdb.builds or {}
  ns.Print(string.format(L["Planning for a %s. The Abilities, Planner and Builds tabs now show it."], ns.FamilyLabel(family)))
  ns.Refresh()
end

local function Fill(family)
  local entry
  for _, f in ipairs(ranked) do if f.family == family then entry = f end end
  if not entry then return end
  local icon = ns.Icon(ns.FamilyIcons[family] or "Ability_Hunter_BeastTaming")
  local beasts = ns.BestBeasts(family, Role(), 4)
  if beasts[1] then j.box:Beast(beasts[1].id, icon) else
    -- none tameable yet: any beast of the family, to show what it looks like
    local any
    for id, b in pairs(ns.Beasts) do if b[4] == family and (not any or id < any) then any = id end end
    if any then j.box:Beast(any, icon) else j.box:Nothing(icon) end
  end
  j.name:SetText(ns.FamilyLabel(family))
  j.sub:SetText(string.format(L["Number %d of %d for %s"], entry.rank, #ranked, RoleLabel()))
  local st = ns.FamilyStats and ns.FamilyStats[family]
  local function S(n) return ((n > 0 and C.GREEN .. "+") or (n < 0 and C.ORANGE) or C.GREY) .. n .. "%|r" end
  tiles.stats.value:SetText(st and string.format("%s %s    %s %s    %s %s", S(st[1]), L["damage"], S(st[2]), L["armor"], S(st[3]), L["health"]) or "")
  tiles.count.value:SetText(string.format(L["%d you can tame now"], CountTameable(family)))

  why:SetText(#entry.reasons > 0 and table.concat(entry.reasons, "\n") or (C.GREY .. L["Nothing stands out for this."] .. "|r"))
  local abil = {}
  for _, a in ipairs(FamilyAbilities(family)) do abil[#abil + 1] = ns.AbilityLabel(a) end
  learns:SetText(#abil > 0 and table.concat(abil, ",  ") or (C.GREY .. L["Only the abilities every pet has."] .. "|r"))
  local lines = {}
  for _, e in ipairs(beasts) do
    local b = ns.Beasts[e.id]
    lines[#lines + 1] = string.format("%s%s|r   %s%s %s|r%s   %s%s|r", b[5] and C.ORANGE or C.GOLD, b[1], C.WHITE, L["level"], ns.LevelText(b),
      b[9] and (((b[9] < 2.0) and C.GREEN or C.GREY) .. string.format("   %.1f s|r", b[9])) or "", C.GREY, ns.ZonesText(b))
  end
  best:SetText(#lines > 0 and table.concat(lines, "\n") or (C.GREY .. L["none you can tame at your level yet"] .. "|r"))
end

local function Build(panel)
  j = ns.MakeJournal(panel, "")
  -- what for: five switches, one on at a time
  local x, y = 6, -5
  for _, r in ipairs(ROLES) do
    local b = ns.MakeFlatButton(j.left, 22)
    b.icon:SetTexture(nil); b.icon:SetWidth(1)
    b.text:ClearAllPoints(); b.text:SetPoint("CENTER")
    b.text:SetText(L[r.label])
    local edge = b:CreateTexture(nil, "BORDER")
    edge:SetAllPoints()
    edge:SetColorTexture(1, 1, 1, 0.06)
    b.bar:ClearAllPoints(); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT"); b.bar:SetHeight(2)
    b:SetSelected(true)
    local w = math.max(50, ((b.text.GetStringWidth and b.text:GetStringWidth()) or (#L[r.label] * 8)) + 20)
    if x + w > 334 then x, y = 6, y - 27 end
    b:SetWidth(w)
    b:SetPoint("TOPLEFT", x, y)
    x = x + w + 5
    b:SetScript("OnClick", function() ns.db.recRole = r.key; ns.UI_Refresh() end)
    b:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L[r.label], L[r.tip] }) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chips[r.key] = b
  end
  list = ns.NewList(j.left, -y + 30)
  j.list = list

  tiles.stats = j:Tile(L["As a family"])
  tiles.count = j:Tile(L["Within reach"])
  j:Buttons({
    { L["Plan for this family"], 150, function() if j.selected then PlanFor(j.selected) end end,
      { L["Plan for this family"], L["The Abilities, Builds and Planner pages show a pet of this family."] } },
    { L["See them all"], 110, function()
        if not j.selected then return end
        local f = ns.BrowserFilter()
        f.family, f.fresh, f.teaches, f.where, f.rare, f.tameable, f.sort = j.selected, false, "any", "any", false, true, "speed"
        ns.UI_Show("browse")
      end, { L["See them all"], L["Opens the Bestiary on this family: the ones you can tame now, fastest first."] } },
    { L["Starting build"], 120, function()
        if j.selected then PlanFor(j.selected) end
        local t = ns.Target()
        if t and ns.ApplyPreset then ns.ApplyPreset(t, ROLE_TO_PRESET[Role()]) end
        ns.UI_Show("builds")
      end, { L["Starting build"], L["Plans for this family and opens Builds with a build for the role you picked."] } },
  })
  why = j:Section(L["Why"])
  learns = j:Section(L["It can learn"], "GameFontHighlightSmall")
  best = j:Section(L["Best to tame now"])
  j.onSelect = Fill
end

local function Refresh()
  local role = Role()
  for k, b in pairs(chips) do b:SetSelected(k == role) end
  ranked = ns.RankFamilies(role)
  local rows, keys, order = {}, {}, {}
  rows[1] = { 0, nil, string.format(L["Best families for %s"], RoleLabel()), "", nil, nil, { header = true } }
  for i, f in ipairs(ranked) do
    f.rank = i
    local n = CountTameable(f.family)
    rows[#rows + 1] = { 0, ns.Icon(ns.FamilyIcons[f.family] or "Ability_Hunter_BeastTaming"),
      string.format("%s%d.  %s|r", i <= 3 and C.GREEN or C.WHITE, i, ns.FamilyLabel(f.family)),
      n > 0 and (C.GREY .. n .. "|r") or (C.RED .. "0|r"),
      j:RowClick(f.family, PlanFor), j:RowHover(f.family) }
    keys[#rows] = f.family
    order[#order + 1] = f.family
  end
  list:Set(rows)
  j:Rows(keys, order)
  if j.selected then Fill(j.selected) end
end

ns.RegisterTab("recommend", L["Find a Pet"], Build, Refresh)
