local _, ns = ...
local C, L = ns.C, ns.L

-- Pet recommender: pick a role, get the best families for it and the best
-- actual beasts to tame near you, plus a matching starting build.

-- Classic Era family modifiers in percent: damage, armor, health (Icy Veins Classic hunter pet guide).
local STATS = {
  ["Bat"] = { 7, 0, 0 }, ["Bear"] = { -9, 5, 8 }, ["Boar"] = { -10, 9, 4 }, ["Carrion Bird"] = { 0, 5, 0 },
  ["Cat"] = { 10, 0, -2 }, ["Crab"] = { -5, 13, -4 }, ["Crocolisk"] = { 0, 10, -5 }, ["Gorilla"] = { 2, 0, 4 },
  ["Hyena"] = { 0, 5, 0 }, ["Owl"] = { 7, 0, 0 }, ["Raptor"] = { 10, 3, -5 }, ["Scorpid"] = { -6, 10, 0 },
  ["Spider"] = { 7, 0, 0 }, ["Tallstrider"] = { 0, 0, 5 }, ["Turtle"] = { -10, 13, 0 }, ["Wind Serpent"] = { 7, 0, 0 },
  ["Wolf"] = { 0, 5, 0 },
}
ns.FamilyStats = ns.FLAVOR ~= "forever" and STATS or nil

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

-- Best actual beasts of a family: tameable now, fastest attack (Classic Era), highest level, closest.
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
-- Tab
---------------------------------------------------------------------------
local list, buttons = nil, {}
local ROLE_TO_PRESET = { tank = "tank", dps = "damage", leveling = "damage", pvp = "pvp", utility = "pvp" }

local function Build(panel)
  local x = 4
  for _, r in ipairs(ROLES) do
    local b = ns.MakeButton(panel, L[r.label], 88, function() ns.db.recRole = r.key; ns.UI_Refresh() end)
    b:SetPoint("TOPLEFT", x, -2)
    b:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L[r.label], L[r.tip] }) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[r.key] = b
    x = x + 92
  end
  list = ns.NewList(panel, 36)
end

local function Refresh()
  local role = ns.db.recRole or "dps"
  for k, b in pairs(buttons) do if k == role then b:LockHighlight() else b:UnlockHighlight() end end
  local rows = {}
  local function add(...) rows[#rows + 1] = { ... } end
  local roleLabel
  for _, r in ipairs(ROLES) do if r.key == role then roleLabel = L[r.label] end end
  if ns.FLAVOR == "forever" then
    add(0, nil, C.ORANGE .. L["Forever reworked pet stats, so these picks are based on family abilities only."] .. "|r", "")
  end
  local ranked = ns.RankFamilies(role)
  add(0, nil, C.GREY .. string.format(L["Best families for %s"], roleLabel) .. "|r",
    C.GREY .. L["click a beast for an arrow"] .. "|r")
  for i = 1, math.min(4, #ranked) do
    local f = ranked[i]
    add(0, ns.Icon(ns.FamilyIcons[f.family] or "Ability_Hunter_BeastTaming"),
      string.format("%s%d. %s|r", i == 1 and C.GREEN or C.GOLD, i, ns.FamilyLabel(f.family)), C.GREY .. table.concat(f.reasons, "  |  ") .. "|r",
      function()
        ns.state.mode = "manual"; ns.state.family = f.family
        ns.cdb.builds = ns.cdb.builds or {}
        ns.Print(string.format(L["Planning for a %s. The Abilities, Planner and Builds tabs now show it."], f.family))
        ns.Refresh()
      end,
      { ns.FamilyLabel(f.family), table.concat(f.reasons, "\n"), L["Click to plan for this family."] }, { header = true })
    local beasts = ns.BestBeasts(f.family, role, 3)
    if #beasts == 0 then
      add(28, nil, C.GREY .. L["none you can tame at your level yet"] .. "|r", "")
    end
    for _, e in ipairs(beasts) do
      local b = ns.Beasts[e.id]
      local right = ns.ZonesText(b)
      if b[9] then right = C.GREY .. b[9] .. "s|r  " .. right end
      add(28, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
        string.format("%s%s|r", b[5] and C.ORANGE or C.WHITE, b[1]), right,
        ns.BeastClick(e.id), ns.BeastTooltip(e.id, {
          (b[9] and b[9] <= 1.2) and (C.GREEN .. L["Fast attack speed: great for damage."] .. "|r") or nil,
        }), { mid = C.GREY .. ns.LevelText(b) .. "|r" })
    end
  end
  add(0, ns.Icon("INV_Misc_Book_09"), L["Starting build"], C.GREY .. L["click to apply it on the Builds tab"] .. "|r", function()
    local t = ns.Target()
    if not t then ns.Print(L["Summon your pet or pick a family first."]) return end
    if ns.ApplyPreset then ns.ApplyPreset(t, ROLE_TO_PRESET[role]) end
    ns.UI_Show("builds")
  end, nil, { header = true })
  list:Set(rows)
end

ns.RegisterTab("recommend", L["Find a Pet"], Build, Refresh)
