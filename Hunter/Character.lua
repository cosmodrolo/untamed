local _, ns = ...
local L = ns.L
local C = ns.C

-- Character planning: Spells (trainer guide), Talents, Gear and Hunter Quests.

local function Money(copper)
  copper = copper or 0
  if copper < 0 then return C.GREY .. "?|r" end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  if g > 0 then out[#out + 1] = C.GOLD .. g .. "g|r" end
  if s > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
  if c > 0 or #out == 0 then out[#out + 1] = "|cffeda55f" .. c .. "c|r" end
  return table.concat(out, " ")
end
ns.Money = Money

local function Known(spellID)
  return ns.SpellKnown(spellID) == true
end

local function NoData(add, what)
  add(0, nil, C.ORANGE .. string.format(L["%s has no data loaded."], what) .. "|r")
end

---------------------------------------------------------------------------
-- Spells: what to buy at the trainer and what it costs
---------------------------------------------------------------------------
-- Spells many hunters skip while leveling to save gold (buy them later if you need them).
local OPTIONAL = {
  ["Scorpid Sting"] = true, ["Distracting Shot"] = true, ["Eyes of the Beast"] = true, ["Eagle Eye"] = true,
  ["Aspect of the Beast"] = true, ["Aspect of the Wild"] = true, ["Track Undead"] = true, ["Track Elementals"] = true,
  ["Track Demons"] = true, ["Track Giants"] = true, ["Track Dragonkin"] = true, ["Track Hidden"] = true,
  ["Explosive Trap"] = true, ["Beast Lore"] = true,
}

-- Higher ranks of talent spells: the trainer only sells them once you have the talent.
-- Any of these spell IDs known means the talent is learned.
local TALENT_SPELLS = {
  ["Summon Hawk"] = { 1293241 }, ["Trueshot Aura"] = { 1299346 }, ["Counterattack"] = { 19306 },
  ["Sniper Shot"] = { 1310687 },
}
local function NeedsTalent(name)
  local ids = TALENT_SPELLS[name]
  if not ids then return false end
  for _, id in ipairs(ids) do if Known(id) then return false end end
  return true
end
local function Cost(c) return (c and c > 0) and c or 0 end

-- For the Home page: spells you can train now (not counting optional ones).
function ns.SpellsToTrain()
  if not ns.TrainerSpells then return 0, 0 end
  local lvl, n, cost = UnitLevel("player"), 0, 0
  for _, e in ipairs(ns.TrainerSpells) do
    if e[1] <= lvl and not OPTIONAL[e[4]] and not NeedsTalent(e[4]) and not Known(e[2]) then n = n + 1; cost = cost + Cost(e[3]) end
  end
  return n, cost
end

do
  local list, j
  local showAll = false
  local function Build(panel)
    j = ns.TipJournal(panel, L["The spell guide"], L["Arrow to trainer"], function() ns.NavigateService("T", L["Hunter trainer"]) end)
    j.maxRight = 28
    local tb = ns.Toolbar(j.left)
    tb:Dropdown(190, { { false, L["What's next"] }, { true, L["Every level, 1 to 60"] } }, function() return showAll end, function(v) showAll = v end)
    list = tb:List()
    j.list = list
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if not ns.TrainerSpells then NoData(add, L["The spell guide"]); j:SetTipRows(rows) return end
    local playerLevel = UnitLevel("player")
    -- Highest rank per spell name the player knows.
    local missingNow, missingNowCost, optionalCost = 0, 0, 0
    local byLevel, levels = {}, {}
    for _, e in ipairs(ns.TrainerSpells) do
      local lvl, id, cost, name = e[1], e[2], e[3], e[4]
      local known = Known(id)
      if not byLevel[lvl] then byLevel[lvl] = {}; levels[#levels + 1] = lvl end
      table.insert(byLevel[lvl], e)
      if not known and lvl <= playerLevel and not NeedsTalent(name) then
        if OPTIONAL[name] then optionalCost = optionalCost + Cost(cost)
        else missingNow = missingNow + 1; missingNowCost = missingNowCost + Cost(cost) end
      end
    end
    table.sort(levels)
    add(0, ns.Icon("INV_Misc_Book_11"), L["Ready to train now"],
      missingNow > 0 and (C.WHITE .. ns.Count(missingNow, L["spell"], L["spells"]) .. "|r  " .. Money(missingNowCost)) or (C.GREEN .. L["all caught up"] .. "|r"),
      function() ns.NavigateService("T", L["Hunter trainer"]) end,
      { L["Ready to train now"], L["Spells and ranks you can learn at your level that you don't have yet."],
        optionalCost > 0 and (C.GREY .. L["Optional spells not counted: "] .. Money(optionalCost) .. "|r") or "",
        C.GREY .. L["Click for an arrow to the nearest hunter trainer."] .. "|r" }, { header = true })
    local function SpellRow(e, lvl, indent)
      local id, cost, name, rank = e[2], e[3], e[4], e[5]
      local label = ns.SpellName(id) or name
      local known = Known(id)
      local status
      if known then status = C.GREEN .. L["known"] .. "|r"
      elseif NeedsTalent(name) then status = C.GREY .. L["needs talent"] .. "|r"
      elseif lvl > playerLevel then status = C.GREY .. L["later"] .. "|r"
      elseif OPTIONAL[name] then status = C.GREY .. L["optional"] .. "|r"
      else status = C.ORANGE .. L["train now"] .. "|r" end
      local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id)) or nil
      add(indent or 14, icon, (known and C.GREY or C.WHITE) .. label .. "|r" .. (rank > 0 and (C.GREY .. "  " .. L["Rank "] .. rank .. "|r") or ""),
        status .. "   " .. Money(cost), nil,
        { spellID = id, label .. (rank > 0 and (" " .. L["Rank "] .. rank) or ""), "",
          OPTIONAL[name] and (C.GREY .. L["Many hunters skip this while leveling to save gold and buy it later if they need it."] .. "|r")
            or (NeedsTalent(name) and (C.GREY .. L["The trainer sells this rank once you have the talent."] .. "|r")) or "",
          cost < 0 and (C.GREY .. L["Cost not known yet for this WoW Forever spell."] .. "|r") or "" },
        { mid = C.GREY .. L["lvl "] .. lvl .. "|r" })
    end

    if showAll then
      -- Every trainer level, everything, known or not.
      for _, lvl in ipairs(levels) do
        local total = 0
        for _, e in ipairs(byLevel[lvl]) do total = total + Cost(e[3]) end
        add(0, nil, (lvl <= playerLevel and C.GOLD or C.GREY) .. L["Level "] .. lvl .. "|r", Money(total), nil, nil, { header = true })
        for _, e in ipairs(byLevel[lvl]) do SpellRow(e, lvl) end
      end
    else
      -- What's next: what you can train now, then your next two trainer visits.
      for _, lvl in ipairs(levels) do
        if lvl <= playerLevel then
          for _, e in ipairs(byLevel[lvl]) do
            if not Known(e[2]) and not OPTIONAL[e[4]] and not NeedsTalent(e[4]) then SpellRow(e, lvl) end
          end
        end
      end
      local shown = 0
      for _, lvl in ipairs(levels) do
        if lvl > playerLevel and shown < 2 then
          shown = shown + 1
          local total = 0
          for _, e in ipairs(byLevel[lvl]) do total = total + Cost(e[3]) end
          add(0, nil, string.format(L["At level %d"], lvl), Money(total), nil, nil, { header = true })
          for _, e in ipairs(byLevel[lvl]) do SpellRow(e, lvl) end
        end
      end
      local skipped = {}
      for _, lvl in ipairs(levels) do
        if lvl <= playerLevel then
          for _, e in ipairs(byLevel[lvl]) do if not Known(e[2]) and OPTIONAL[e[4]] then skipped[#skipped + 1] = { e, lvl } end end
        end
      end
      if #skipped > 0 then
        add(0, nil, L["Optional, not trained"], Money(optionalCost), nil,
          { L["Optional spells"], L["Many hunters skip these while leveling to save gold. Buy them any time you need them."] }, { header = true })
        for _, x in ipairs(skipped) do SpellRow(x[1], x[2]) end
      end
    end
    j:SetTipRows(rows)
  end
  ns.RegisterTab("spells", L["Spells"], Build, Refresh)
end

---------------------------------------------------------------------------
-- Talents: leveling and raid builds, with the next point highlighted in the talent window
---------------------------------------------------------------------------
-- WoW Forever talent trees (wowhead.com/forever/talent-calc/hunter, Nov 2026): per tab, the
-- talents per tier in column order, with max ranks. Used to know which tree a talent is in.
-- Each talent: { name, ranks, column }. Rows and columns are the talent window's own (read off the
-- Forever talent window, Nov 2026), so Untamed's tree picture matches it.
local TREES = {
  { -- Beast Mastery
    { { "Deadly Aspects", 5, 2 }, { "Endurance Training", 5, 3 } },
    { { "Focused Fire", 2, 1 }, { "Improved Aspect of the Monkey", 3, 2 }, { "Improved Revive Pet", 2, 3 } },
    { { "Pathfinding", 2, 1 }, { "Bestial Swiftness", 1, 2 }, { "Unleashed Fury", 5, 3 } },
    { { "Improved Mend Pet", 2, 1 }, { "Ferocity", 5, 3 }, { "Summon Hawk", 1, 4 } },
    { { "Spirit Bond", 2, 1 }, { "Intimidation", 1, 2 }, { "Bestial Discipline", 2, 4 } },
    { { "Frenzy", 5, 3 } },
    { { "Bestial Wrath", 1, 2 } },
  },
  { -- Marksmanship
    { { "Hawk Eye", 3, 1 }, { "Improved Concussive Shot", 5, 2 }, { "Lethal Attacks", 5, 3 } },
    { { "Improved Stings", 3, 1 }, { "Efficiency", 5, 2 }, { "Careful Aim", 5, 3 } },
    { { "Rapid Killing", 2, 1 }, { "Improved Arcane Shot", 5, 2 }, { "Lone Wolf", 1, 4 } },
    { { "Trueshot Aura", 1, 2 }, { "Mortal Shots", 5, 3 } },
    { { "Rapid Recuperation", 2, 1 }, { "Barrage", 3, 3 }, { "Scatter Shot", 1, 4 } },
    { { "Ranged Weapon Specialization", 5, 3 } },
    { { "Sniper Shot", 1, 2 } },
  },
  { -- Survival
    { { "Improved Tracking", 5, 2 }, { "Deflection", 5, 3 } },
    { { "Entrapment", 5, 1 }, { "Savage Strikes", 2, 2 }, { "Survivalist", 5, 3 }, { "Improved Wing Clip", 3, 4 } },
    { { "Clever Traps", 2, 1 }, { "Surefooted", 3, 2 }, { "Deterrence", 1, 3 } },
    { { "Survival Tactics", 2, 1 }, { "Predator's Edge", 5, 2 }, { "Counterattack", 1, 3 } },
    { { "Resourcefulness", 2, 1 }, { "Expose Prey", 2, 2 }, { "Survivalist's Discipline", 2, 3 }, { "Strider Kick", 1, 4 } },
    { { "Lightning Reflexes", 5, 3 } },
    { { "Lacerating Strikes", 1, 2 } },
  },
}
local TREE_NAME = { L["Beast Mastery"], L["Marksmanship"], L["Survival"] }

-- The arrows in the talent window: a talent that needs another one maxed first (read off the
-- Forever talent window, Nov 16 2026). A build that skips one of these can never reach its talent.
local PREREQ = {
  ["Intimidation"] = "Bestial Swiftness", ["Bestial Wrath"] = "Intimidation", ["Frenzy"] = "Ferocity",
  ["Mortal Shots"] = "Careful Aim", ["Rapid Recuperation"] = "Rapid Killing", ["Sniper Shot"] = "Trueshot Aura",
  ["Counterattack"] = "Deterrence", ["Lacerating Strikes"] = "Expose Prey",
}

-- Is a build possible? Every talent's tier needs 5 points per tier above it in the same tree, and
-- an arrow's source must be maxed first. Returns nil when fine, else what is wrong.
local function BuildProblem(build)
  local tier, max = {}, {}
  for tab, tree in ipairs(TREES) do
    for row, talents in ipairs(tree) do
      for _, t in ipairs(talents) do tier[t[1]] = row; max[t[1]] = t[2] end
    end
  end
  local spent, have = { 0, 0, 0 }, {}
  for _, s in ipairs(build.steps) do
    local tab, name, pts = s[1], s[2], s[3]
    if not tier[name] then return name .. ": not in the trees" end
    if spent[tab] < (tier[name] - 1) * 5 then return string.format("%s: needs %d points in its tree first, the build has %d", name, (tier[name] - 1) * 5, spent[tab]) end
    local need = PREREQ[name]
    if need and (have[need] or 0) < max[need] then return name .. ": needs " .. need .. " maxed first" end
    have[name] = (have[name] or 0) + pts
    if have[name] > max[name] then return name .. ": more points than it has ranks" end
    spent[tab] = spent[tab] + pts
  end
  return nil
end

-- Builds as steps of { tab, talent, points } in the order to take them.
local BUILDS = {
  {
    key = "leveling", label = L["Leveling (Beast Mastery)"], split = "31/20/0",
    source = "Untamed's own pick for the strongest pet (Nov 13 2026), from the Forever talent numbers on wowhead.com's talent changes page and the Nov 10 hotfixes",
    -- Points, by what they do per point: Ferocity with Frenzy about 4% pet damage, Frenzy about 3%,
    -- Unleashed Fury 3% (pet and hawks), Bestial Wrath 50% for 18 sec every 2 min (about 7.5% on
    -- average from 1 point), Endurance Training 3% pet health and armor (pets tank; Nov 10 cut their
    -- health back to 115%), Spirit Bond and Bestial Discipline less downtime (health, pet Focus and
    -- your mana while casting), Deadly Aspects about 2% more Auto Shot a point. Marksmanship after
    -- 40: your crit, mana (Summon Hawk and Arcane Shot cost 11% of base mana each since Nov 10) and
    -- Attack Power. Bestial Wrath needs Intimidation, which needs Bestial Swiftness (the arrows in
    -- the talent window), so both are taken on the way: 30 points, then Bestial Wrath at level 40.
    -- That leaves no room for Spirit Bond. Skipped: Spirit Bond, Pathfinding, Improved Revive Pet.
    steps = {
      { 1, "Endurance Training", 5 }, { 1, "Focused Fire", 2 }, { 1, "Deadly Aspects", 3 },
      { 1, "Unleashed Fury", 5 }, { 1, "Bestial Swiftness", 1 }, { 1, "Summon Hawk", 1 }, { 1, "Ferocity", 5 },
      { 1, "Bestial Discipline", 2 }, { 1, "Intimidation", 1 }, { 1, "Frenzy", 5 }, { 1, "Bestial Wrath", 1 },
      { 2, "Lethal Attacks", 5 }, { 2, "Efficiency", 5 }, { 2, "Careful Aim", 5 }, { 2, "Improved Stings", 3 },
      { 2, "Rapid Killing", 2 },
    },
  },
  {
    key = "raid", label = L["Raid (Marksmanship)"], split = "7/32/12",
    source = "Feor, Marksmanship Hunter Guide (mobalytics.gg, WoW Forever, Nov 2026)",
    steps = {
      { 2, "Lethal Attacks", 5 }, { 2, "Careful Aim", 5 }, { 2, "Improved Stings", 3 }, { 2, "Rapid Killing", 2 },
      { 2, "Mortal Shots", 5 }, { 2, "Trueshot Aura", 1 }, { 2, "Rapid Recuperation", 2 }, { 2, "Barrage", 3 },
      { 2, "Ranged Weapon Specialization", 5 }, { 2, "Sniper Shot", 1 },
      { 1, "Deadly Aspects", 5 }, { 1, "Focused Fire", 2 },
      { 3, "Improved Tracking", 5 }, { 3, "Savage Strikes", 2 }, { 3, "Survivalist", 3 }, { 3, "Clever Traps", 2 },
    },
  },
}

-- WoW Forever: talents live in a trait tree (C_Traits), with all three hunter trees in one config.
-- Talents are matched by their first-rank spell ID (wowhead Forever talent calculator), so it works
-- in any language.
local TALENT_SPELL = {
  [19552] = "Deadly Aspects", [19583] = "Endurance Training", [1223755] = "Focused Fire",
  [19549] = "Improved Aspect of the Monkey", [24443] = "Improved Revive Pet", [19559] = "Pathfinding",
  [19596] = "Bestial Swiftness", [19616] = "Unleashed Fury", [19572] = "Improved Mend Pet", [19598] = "Ferocity",
  [1293241] = "Summon Hawk", [19578] = "Spirit Bond", [19577] = "Intimidation", [19590] = "Bestial Discipline",
  [19621] = "Frenzy", [19574] = "Bestial Wrath",
  [19498] = "Hawk Eye", [19407] = "Improved Concussive Shot", [19426] = "Lethal Attacks", [1310661] = "Improved Stings",
  [19416] = "Efficiency", [1223984] = "Careful Aim", [415405] = "Rapid Killing", [19454] = "Improved Arcane Shot",
  [415370] = "Lone Wolf", [1299346] = "Trueshot Aura", [19485] = "Mortal Shots", [1223987] = "Rapid Recuperation",
  [19461] = "Barrage", [19503] = "Scatter Shot", [19507] = "Ranged Weapon Specialization", [1310687] = "Sniper Shot",
  [24293] = "Improved Tracking", [19295] = "Deflection", [19184] = "Entrapment", [19159] = "Savage Strikes",
  [19255] = "Survivalist", [19228] = "Improved Wing Clip", [19239] = "Clever Traps", [19290] = "Surefooted",
  [19263] = "Deterrence", [19376] = "Survival Tactics", [1310627] = "Predator's Edge", [19306] = "Counterattack",
  [440529] = "Resourcefulness", [1310532] = "Expose Prey", [1310496] = "Survivalist's Discipline",
  [1317257] = "Strider Kick", [19168] = "Lightning Reflexes", [1310533] = "Lacerating Strikes",
}
local ALIAS = {}

-- Your talent config, found the way Forever's own talent window does it (combat config for your
-- active spec group), falling back to the active config. Returns configID, treeID.
local function TraitConfig()
  if not C_Traits or not C_Traits.GetConfigInfo then return nil end
  local candidates = {}
  if C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
    local group = C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup() or 1
    candidates[#candidates + 1] = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
  end
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then candidates[#candidates + 1] = C_ClassTalents.GetActiveConfigID() end
  for _, cfg in ipairs(candidates) do
    local info = cfg and C_Traits.GetConfigInfo(cfg)
    local tree = info and info.treeIDs and info.treeIDs[1]
    if tree then return cfg, tree end
  end
  return nil
end

local function TraitName(def)
  if not def then return nil end
  if def.spellID and TALENT_SPELL[def.spellID] then return TALENT_SPELL[def.spellID], def.spellID end
  local name = def.overrideName
  if (not name or name == "") and def.spellID then
    name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(def.spellID)) or (GetSpellInfo and GetSpellInfo(def.spellID))
  end
  if not name or ns.IsSecret(name) then return nil end
  return ALIAS[name] or name, def.spellID
end

local function MapTraits()
  local map, total = { {}, {}, {} }, 0
  local cfg, tree = TraitConfig()
  if not cfg or not tree then return map, 0 end
  local tabOf = {}
  for tab = 1, 3 do for _, tier in ipairs(TREES[tab]) do for _, t in ipairs(tier) do tabOf[t[1]] = tab end end end
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
    local node = C_Traits.GetNodeInfo(cfg, nodeID)
    local entry = node and node.entryIDs and node.entryIDs[1]
    local e = entry and C_Traits.GetEntryInfo(cfg, entry)
    local key, spellID = TraitName(e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID))
    local tab = key and tabOf[key]
    if tab then
      local label = spellID and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfo and GetSpellInfo(spellID)))
      if not label or ns.IsSecret(label) then label = key end
      map[tab][key] = { node = nodeID, entry = entry, maxRank = node.maxRanks, name = label }
      total = total + 1
    end
  end
  return map, total
end

local function TraitRank(nodeID)
  local cfg = TraitConfig()
  local node = cfg and C_Traits.GetNodeInfo(cfg, nodeID)
  return node and (node.activeRank or node.currentRank) or 0
end

-- points you have in a talent (by its English name), and its most; nil if the tree can't be read
function ns.TalentRankOf(key)
  local ok, map = pcall(MapTraits)
  if not ok or not map then return nil end
  for tab = 1, 3 do
    local t = map[tab][key]
    if t then
      local okR, r = pcall(TraitRank, t.node)
      if okR and r and not ns.IsSecret(r) then return r, t.maxRank end
    end
  end
  return nil
end

-- /ut talents: what Untamed can see of your Forever talent tree (for troubleshooting).
function ns.TalentDebug()
  local ok, cfg, tree = pcall(TraitConfig)
  ns.Print(string.format("Talents: config %s, tree %s", tostring(ok and cfg), tostring(ok and tree)))
  if not ok then ns.Print("Talents error: " .. tostring(cfg)) return end
  if not cfg or not tree then ns.Print("Talents: no talent tree found yet (open the talent window once, then try again).") return end
  local nodes = C_Traits.GetTreeNodes(tree) or {}
  local ok2, map, total = pcall(MapTraits)
  if not ok2 then ns.Print("Talents error: " .. tostring(map)) return end
  ns.Print(string.format("Talents: %d nodes in the tree, %d matched to the builds.", #nodes, total))
  -- the first few unmatched names, so a rename shows up
  local shown = 0
  for _, nodeID in ipairs(nodes) do
    local node = C_Traits.GetNodeInfo(cfg, nodeID)
    local e = node and node.entryIDs and node.entryIDs[1] and C_Traits.GetEntryInfo(cfg, node.entryIDs[1])
    local def = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
    local key = TraitName(def)
    local found = false
    for tab = 1, 3 do if key and map[tab][key] then found = true end end
    if not found and shown < 6 and def then
      shown = shown + 1
      ns.Print(string.format("  not in a build: %s (spell %s)", tostring(key), tostring(def.spellID)))
    end
  end
end

-- Unspent talent points on either flavor.
function ns.FreeTalentPoints()
  if UnitCharacterPoints then return UnitCharacterPoints("player") or 0 end
  local ok, n = pcall(function()
    local cfg, tree = TraitConfig()
    if not cfg or not tree then return 0 end
    local c = C_Traits.GetTreeCurrencyInfo(cfg, tree, false)
    return c and c[1] and c[1].quantity or 0
  end)
  return ok and n or 0
end

local talentMap   -- [tab][englishName] = { index or node, maxRank, name }
local function MapTalents()
  if talentMap then return talentMap end
  local ok, map, total = pcall(MapTraits)
  if not ok then
    ns.talentError = map
    return { {}, {}, {} }
  end
  ns.talentError = nil
  if total > 0 then talentMap = map end
  return map
end

local function CurrentRank(tab, english)
  local m = MapTalents()[tab][english]
  if not m then return nil end
  local ok, rank = pcall(TraitRank, m.node)
  return ok and rank or 0, m
end

-- Walk the build: returns each step with done points, and the next talent to take.
local function BuildProgress(build)
  local want, out, nextStep = {}, {}, nil
  for i, st in ipairs(build.steps) do
    local tab, name, pts = st[1], st[2], st[3]
    want[tab .. name] = (want[tab .. name] or 0) + pts
    local target = want[tab .. name]
    local rank, m = CurrentRank(tab, name)
    for _, alt in ipairs(st.alt or {}) do
      local r = CurrentRank(tab, alt)
      if r then rank = (rank or 0) + r end
    end
    local done = rank and math.max(0, math.min(pts, rank - (target - pts))) or 0
    out[i] = { tab = tab, name = name, pts = pts, done = done, label = m and m.name or name, index = m and m.index, node = m and m.node,
      entry = m and m.entry, alt = st.alt, first = target - pts + 1 }
    if not nextStep and done < pts then nextStep = out[i] end
  end
  return out, nextStep
end

function ns.NextTalent()
  local b = ns.CharacterTest and ns.CharacterTest.SelectedBuild and ns.CharacterTest.SelectedBuild()
  if not b then return nil end
  local _, nxt = ns.CharacterTest.BuildProgress(b)
  return nxt and nxt.label
end

local function SelectedBuild()
  local key = ns.cdb.talentBuild or "leveling"
  for _, b in ipairs(BUILDS) do if b.key == key then return b end end
  return BUILDS[1]
end

-- Glow on the next talent in the game's talent window.

-- Forever: the same glow in the trait-based talent window (all three trees on one page).
local fglow
local function UpdateForeverGlow()
  local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if not tf or not tf.GetTalentButtonByNodeID then return end
  if not fglow then
    -- Parented to UIParent, not the talent window, so the gamepad UI never sees it as part of that panel.
    fglow = CreateFrame("Frame", nil, UIParent)
    local tex = fglow:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(0.67, 0.83, 0.45)
    fglow:EnableMouse(false)
    -- It lives on UIParent, so it can't rely on the talent window hiding it: while shown, check that
    -- the button it marks is still on screen and hide it the moment it isn't.
    fglow:SetScript("OnUpdate", function(self)
      local b, t = self.btn, PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
      if not (b and b:IsVisible() and t and t:IsVisible()) then self:Hide() end
    end)
  end
  fglow:Hide()
  if ns.db.talentGlow == false or not tf:IsShown() then return end
  local _, nextStep = BuildProgress(SelectedBuild())
  if not nextStep or not nextStep.node then return end
  local btn = tf:GetTalentButtonByNodeID(nextStep.node)
  if btn and btn:IsShown() then
    -- The glow lives on UIParent, so convert the button's size from the talent window's scale.
    local k = (btn:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local size = math.max(btn:GetWidth(), btn:GetHeight()) * 1.75 * k
    fglow:ClearAllPoints()
    fglow:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fglow:SetSize(size, size)
    fglow:SetFrameStrata(tf:GetFrameStrata())
    fglow:SetFrameLevel(btn:GetFrameLevel() + 5)
    fglow.btn = btn
    fglow:Show()
  end
end

local function RefreshGlow()
  pcall(UpdateForeverGlow)
end

-- Why each talent is in the build, in a line (numbers come from the talent window itself).
local WHY = {
  ["Deadly Aspects"] = L["Bursts of faster Auto Shots while Aspect of the Hawk is up."],
  ["Spirit Bond"] = L["You and your pet keep healing during and between fights: less eating and Mend Pet."],
  ["Efficiency"] = L["Your shots and stings cost less mana, so you drink less."],
  ["Focused Fire"] = L["More damage from you and your pet, as long as the pet is out."],
  ["Endurance Training"] = L["Your pet gets more health and armor: it tanks longer and dies less."],
  ["Pathfinding"] = L["Faster Aspect of the Cheetah: quicker travel between quests."],
  ["Improved Revive Pet"] = L["Revive Pet casts faster and the pet comes back healthier."],
  ["Bestial Swiftness"] = L["Your pet runs faster: it reaches mobs first and keeps up."],
  ["Unleashed Fury"] = L["More damage from your pet and your hawks."],
  ["Summon Hawk"] = L["A hawk dive-bombs your target and keeps attacking. Use it instead of most Arcane Shots."],
  ["Ferocity"] = L["Your pet and hawks crit more often (and crits trigger Frenzy)."],
  ["Intimidation"] = L["Your pet stuns the target: an emergency stop for a runner or a caster."],
  ["Bestial Discipline"] = L["Your pet gets Focus back faster (more Claw and Bite), and your mana keeps coming back while you cast."],
  ["Frenzy"] = L["After a crit, your pet attacks much faster for a few seconds."],
  ["Bestial Wrath"] = L["Your pet goes berserk: much more damage and nothing stops it. Use it on tough fights."],
  ["Lethal Attacks"] = L["More critical strikes for you."],
  ["Careful Aim"] = L["Your Intellect also gives you Attack Power."],
  ["Improved Stings"] = L["Serpent Sting hits harder."],
  ["Rapid Killing"] = L["Rapid Fire comes back sooner, and a kill makes your next shot hit harder."],
  ["Trueshot Aura"] = L["More ranged Attack Power for you and your group."],
  ["Improved Tracking"] = L["More damage to the creature type you're tracking."],
}
ns.TalentWhy = WHY

-- The talent window's own text for one rank of a talent, as the game shows it.
local function TalentText(entry, rank)
  if not (entry and C_Traits and C_Traits.GetTraitDescription) then return nil end
  local ok, d = pcall(C_Traits.GetTraitDescription, entry, rank)
  if ok and type(d) == "string" and d ~= "" and not ns.IsSecret(d) then return d end
end
ns.CharacterTalentText = TalentText

-- One entry per talent point, in the build's order: { tab, name, rank, alt }.
local function Expanded(build)
  local out, n = {}, {}
  for _, st in ipairs(build.steps) do
    for _ = 1, st[3] do
      n[st[2]] = (n[st[2]] or 0) + 1
      out[#out + 1] = { tab = st[1], name = st[2], rank = n[st[2]], alt = st.alt }
    end
  end
  return out
end

-- Talents with more points than the build has by now (how many points you've spent):
-- { { label, have, want } }. Points in a step's alternatives count as that step.
local function OffPath(build)
  local map = MapTalents()
  if not map[1]["Deadly Aspects"] then return nil end
  local have, spent = {}, 0
  for tab = 1, 3 do
    for name, m in pairs(map[tab]) do
      local ok, r = pcall(TraitRank, m.node)
      r = ok and r or 0
      if r > 0 then have[name] = { r = r, label = m.name, tab = tab } spent = spent + r end
    end
  end
  local want, group = {}, {}
  for i, e in ipairs(Expanded(build)) do
    if i > spent then break end
    local key = e.name
    if e.alt then
      key = "group:" .. e.name
      group[e.name] = true
      for _, a in ipairs(e.alt) do group[a] = e.name end
    end
    want[key] = (want[key] or 0) + 1
  end
  local out, pooled = {}, {}
  for name, h in pairs(have) do
    local g = group[name]
    if g then
      local k = "group:" .. (g == true and name or g)
      pooled[k] = (pooled[k] or 0) + h.r
    elseif h.r > (want[name] or 0) then
      out[#out + 1] = { label = h.label, have = h.r, want = want[name] or 0 }
    end
  end
  for k, r in pairs(pooled) do
    if r > (want[k] or 0) then out[#out + 1] = { label = k:sub(7) .. " " .. L["(or its alternatives)"], have = r, want = want[k] or 0 } end
  end
  table.sort(out, function(a, b) return a.label < b.label end)
  return out, spent
end
ns.CharacterOffPath = function() return OffPath(SelectedBuild()) end

-- Chat: a warning when a point goes off the build, and what's next at each level.
local lastWarn
local function CheckPath(force)
  if ns.db.talentPath == false then return end
  local ok, off = pcall(OffPath, SelectedBuild())
  if not ok or not off then return end
  local key = {}
  for _, o in ipairs(off) do key[#key + 1] = o.label .. o.have end
  key = table.concat(key, ",")
  if key == lastWarn and not force then return end
  lastWarn = key
  for _, o in ipairs(off) do
    ns.Print(C.ORANGE .. string.format(L["Off the build: %s has %d points, the build has %d by now."], o.label, o.have, o.want) .. "|r")
  end
end
ns.CharacterCheckPath = CheckPath

local function NextLine()
  local _, nxt = BuildProgress(SelectedBuild())
  if not nxt then return nil end
  return string.format(L["%s, rank %d"], nxt.label, nxt.first + nxt.done)
end

-- Hooked-already flags live here, not on Blizzard's frames (writing fields onto them taints them).
local hooked = {}

local function HookTraitFrame()
  local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if not tf or hooked.traits then return end
  hooked.traits = true
  tf:HookScript("OnShow", function()
    talentMap = nil
    if C_Timer and C_Timer.After then C_Timer.After(0.1, RefreshGlow) else RefreshGlow() end
  end)
  tf:HookScript("OnHide", function() if fglow then fglow:Hide() end end)
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
                       "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_LEVEL_UP" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_ENTERING_WORLD" then
      if not ns.pathChecked then
        ns.pathChecked = true
        C_Timer.After(8, function() talentMap = nil CheckPath(true) end)
      end
      return
    end
    if event == "ADDON_LOADED" then
      if arg == "Blizzard_PlayerSpells" then HookTraitFrame() end
    else
      talentMap = nil
      RefreshGlow()
      if event == "PLAYER_LEVEL_UP" and (tonumber(arg) or 0) >= 10 and ns.db.talentPath ~= false then
        C_Timer.After(1, function()
          local line = NextLine()
          if line then ns.Print(string.format(L["Level %d: your talent point goes to %s."], tonumber(arg), C.GOLD .. line .. "|r")) end
        end)
      elseif event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_NODE_CHANGED" then
        C_Timer.After(0.5, function() CheckPath() end)
      end
    end
  end)
end

do
  local list, buttons, tree = nil, {}, nil
  local LIST_W = 340

  -- one talent in the picture: its icon, "2/5" and its place in the build's order
  local function Node(key)
    local n = tree.nodes[key]
    if n then return n end
    n = CreateFrame("Button", nil, tree)
    n.edge = n:CreateTexture(nil, "BACKGROUND")
    n.edge:SetAllPoints()
    n.icon = n:CreateTexture(nil, "ARTWORK")
    n.icon:SetPoint("TOPLEFT", 2, -2)
    n.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    n.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    n.rank = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    n.rank:SetPoint("BOTTOMRIGHT", 3, -4)
    n.rankBg = n:CreateTexture(nil, "ARTWORK", nil, 2)
    n.rankBg:SetPoint("TOPLEFT", n.rank, "TOPLEFT", -2, 1)
    n.rankBg:SetPoint("BOTTOMRIGHT", n.rank, "BOTTOMRIGHT", 2, -1)
    n.rankBg:SetColorTexture(0, 0, 0, 0.85)
    n.order = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    n.order:SetPoint("TOPLEFT", -3, 4)
    n.orderBg = n:CreateTexture(nil, "ARTWORK", nil, 2)
    n.orderBg:SetPoint("TOPLEFT", n.order, "TOPLEFT", -2, 1)
    n.orderBg:SetPoint("BOTTOMRIGHT", n.order, "BOTTOMRIGHT", 2, -1)
    n.orderBg:SetColorTexture(0, 0, 0, 0.85)
    n:SetScript("OnClick", function() end)
    n:SetScript("OnEnter", function(self) if self.tip then ns.ShowTooltip(self, self.tip) end end)
    n:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tree.nodes[key] = n
    return n
  end

  local function FillTree(build, steps, nextStep)
    tree.fill = function() ns.UI_Refresh() end
    local map = MapTalents()
    local spellOf = {}
    for id, name in pairs(TALENT_SPELL) do spellOf[name] = id end
    -- what the build does with each talent: its place in the order, the points and the levels
    local plan, level = {}, 9
    for i, st in ipairs(steps) do
      local first = level + 1
      level = level + st.pts
      local key = st.tab .. st.name
      local p = plan[key]
      if not p then p = { order = i, pts = 0, lines = {} }; plan[key] = p end
      p.pts = p.pts + st.pts
      p.lines[#p.lines + 1] = string.format(L["Step %d: %s, at level %s"], i, ns.Count(st.pts, L["point"], L["points"]),
        st.pts > 1 and (first .. "-" .. level) or tostring(first))
      if st == nextStep then p.isNext = true end
    end
    -- the size that fits: three trees of four columns and seven rows, plus their headings
    local w, h = tree:GetWidth(), tree:GetHeight()
    if type(w) ~= "number" or w < 100 then w = 500 end
    if type(h) ~= "number" or h < 100 then h = 420 end
    local gapTree = 14
    local cell = math.floor(math.min((w - 2 * gapTree - 12) / 12, (h - 60) / 7))
    cell = math.max(26, math.min(56, cell))
    local size = cell - 7
    local treeW = cell * 4
    local x0 = math.max(8, math.floor((w - (3 * treeW + 2 * gapTree)) / 2))
    local used = 0
    for tab = 1, 3 do
      local left = x0 + (tab - 1) * (treeW + gapTree)
      local spent = 0
      for row, talents in ipairs(TREES[tab]) do
        for _, t in ipairs(talents) do
          local name, max, col = t[1], t[2], t[3]
          local key = tab .. name
          local n = Node(key)
          local m = map[tab][name]
          local have = 0
          if m then local okR, r = pcall(TraitRank, m.node); have = okR and r or 0 end
          spent = spent + have
          local p = plan[key]
          local want = p and p.pts or 0
          n:SetSize(size, size)
          n:ClearAllPoints()
          n:SetPoint("TOPLEFT", tree, "TOPLEFT", left + (col - 1) * cell + 4, -44 - (row - 1) * cell)
          local sid = spellOf[name]
          local tex = sid and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sid)
          if tex and ns.IsSecret(tex) then tex = nil end
          n.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
          local idle = want == 0 and have == 0
          n.icon:SetDesaturated(idle)
          n.icon:SetAlpha(idle and 0.35 or 1)
          local col3
          if have > want then col3 = { 1, 0.6, 0.2 }                      -- more points than the build has
          elseif p and p.isNext then col3 = ns.Theme.accent               -- the next point goes here
          elseif want > 0 and have >= want then col3 = { 0.25, 0.9, 0.3 } -- done
          elseif want > 0 then col3 = { 0.75, 0.8, 0.75 }                 -- still to come
          else col3 = { 0.2, 0.25, 0.2 } end
          n.edge:SetColorTexture(col3[1], col3[2], col3[3], idle and 0.6 or 1)
          n.rank:SetText((have >= math.max(want, 1) and want > 0 and C.GREEN or (have > 0 and C.WHITE or C.GREY)) .. have .. "/" .. max .. "|r")
          n.rank:SetShown(not idle); n.rankBg:SetShown(not idle)
          n.order:SetText(p and ((p.isNext and C.GOLD or C.WHITE) .. p.order .. "|r") or "")
          n.orderBg:SetShown(p ~= nil)
          local label = m and m.name or name
          local tip = { label, string.format(L["Rank %d of %d"], have, max) }
          local text = m and TalentText(m.entry, math.max(1, math.min(max, math.max(have, want))))
          if text then tip[#tip + 1] = C.WHITE .. text .. "|r" end
          if p then
            for _, line in ipairs(p.lines) do tip[#tip + 1] = (p.isNext and C.GOLD or C.GREY) .. line .. "|r" end
            if p.isNext then tip[#tip + 1] = C.GOLD .. L["Your next point goes here."] .. "|r" end
          else
            tip[#tip + 1] = C.GREY .. L["Not in this build."] .. "|r"
          end
          if PREREQ[name] then tip[#tip + 1] = C.GREY .. string.format(L["Needs %s first."], PREREQ[name]) .. "|r" end
          if WHY[name] then tip[#tip + 1] = C.GREEN .. WHY[name] .. "|r" end
          n.tip = tip
          n:Show()
          n.col, n.row, n.tab = col, row, tab
        end
      end
      local head = tree.heads[tab]
      if not head then
        head = tree:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tree.heads[tab] = head
      end
      head:ClearAllPoints()
      head:SetPoint("TOP", tree, "TOPLEFT", left + treeW / 2, -14)
      head:SetText(TREE_NAME[tab] .. "  " .. C.WHITE .. spent .. "|r")
    end
    -- the arrows: a talent that needs another one first
    local i = 0
    for name, need in pairs(PREREQ) do
      local a, b
      for tab = 1, 3 do
        if tree.nodes[tab .. name] and tree.nodes[tab .. need] then a, b = tree.nodes[tab .. need], tree.nodes[tab .. name] end
      end
      if a and b then
        i = i + 1
        local line = tree.links[i]
        if not line then line = tree:CreateTexture(nil, "BORDER"); tree.links[i] = line end
        local inBuild = plan[b.tab .. name] ~= nil
        line:SetColorTexture(inBuild and ns.Theme.accent[1] or 0.4, inBuild and ns.Theme.accent[2] or 0.45, inBuild and ns.Theme.accent[3] or 0.4, inBuild and 0.9 or 0.6)
        line:ClearAllPoints()
        line:SetWidth(3)
        line:SetPoint("TOP", a, "BOTTOM", 0, 0)
        line:SetPoint("BOTTOM", b, "TOP", 0, 0)
        line:Show()
      end
    end
    for k = i + 1, #tree.links do tree.links[k]:Hide() end
  end
  local function Build(panel)
    local x = 4
    for _, b in ipairs(BUILDS) do
      local btn = ns.MakeButton(panel, b.label, 170, function() ns.cdb.talentBuild = b.key; RefreshGlow(); ns.UI_Refresh() end)
      btn:SetPoint("TOPLEFT", x, -2)
      buttons[b.key] = btn
      x = x + 174
    end
    -- left: the order to take them in. right: the talent trees, as in the talent window.
    local left = CreateFrame("Frame", nil, panel)
    left:SetPoint("TOPLEFT", 0, -36)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LIST_W)
    list = ns.NewList(left, 0)
    tree = CreateFrame("Frame", nil, panel)
    tree:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    tree:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    ns.Skin(tree, ns.Theme.deep, 0.5, ns.Theme.line, 1, 0)
    tree.heads, tree.nodes, tree.links = {}, {}, {}
    local pending
    tree:SetScript("OnSizeChanged", function()
      if pending then return end
      pending = true
      C_Timer.After(0.1, function() pending = false; if tree:IsVisible() and tree.fill then tree.fill() end end)
    end)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local build = SelectedBuild()
    for k, btn in pairs(buttons) do if k == build.key then btn:LockHighlight() else btn:UnlockHighlight() end end
    local steps, nextStep = BuildProgress(build)
    local free = ns.FreeTalentPoints()
    add(0, ns.Icon(build.key == "raid" and "Ability_TrueShot" or "Ability_Druid_FerociousBite"), build.label .. "  " .. C.GREY .. build.split .. "|r",
      free and free > 0 and (C.GREEN .. ns.Count(free, L["point to spend"], L["points to spend"]) .. "|r") or "", nil,
      { build.label, L["Source: "] .. build.source, L["Open your talent window: the next talent in this build glows green."] }, { header = true })
    if not MapTalents()[1]["Deadly Aspects"] then
      add(0, nil, C.GREY .. L["Open your talent window once so Untamed can read your talents."] .. "|r")
      if ns.talentError then add(0, nil, C.RED .. L["Couldn't read your talents: "] .. tostring(ns.talentError) .. "|r") end
      add(0, nil, C.GREY .. L["Still empty? Type /ut talents and send me what it prints."] .. "|r")
    end
    local okOff, off = pcall(OffPath, build)
    if okOff and off and #off > 0 then
      add(0, nil, C.ORANGE .. L["Off the build"] .. "|r", "", nil,
        { L["Off the build"], L["These have more points than the build has at your level. Respec at your class trainer, or keep going: the build still works from here."] }, { header = true })
      for _, o in ipairs(off) do
        add(14, nil, C.ORANGE .. o.label .. "|r", C.GREY .. string.format(L["%d points, the build has %d"], o.have, o.want) .. "|r")
      end
    end
    local level = 9
    for i, st in ipairs(steps) do
      local first = level + 1
      level = level + st.pts
      local isNext = st == nextStep
      local color = st.done >= st.pts and C.GREEN or (isNext and C.GOLD or C.WHITE)
      local lvlText = st.pts > 1 and (first .. "-" .. level) or tostring(first)
      local label = st.label
      if st.alt then label = label .. C.GREY .. " " .. L["(or "] .. table.concat(st.alt, ", ") .. ")|r" end
      -- the tooltip: the talent window's own text for the ranks this step takes, and why
      local tip = { st.label, string.format(L["Levels %s, %s tree"], lvlText, TREE_NAME[st.tab]) }
      local last = st.first + st.pts - 1
      local text = TalentText(st.entry, last)
      if text then tip[#tip + 1] = (st.pts > 1 and string.format(L["At rank %d: "], last) or "") .. C.WHITE .. text .. "|r" end
      if WHY[st.name] then tip[#tip + 1] = C.GREEN .. WHY[st.name] .. "|r" end
      add(14, nil, string.format("%s%d.|r %s%s|r  %s%d/%d|r", C.GREY, i, color, label, C.GREY, st.done, st.pts),
        (isNext and (C.GOLD .. L["next"] .. "  |r") or "") .. C.GREY .. L["lvl "] .. lvlText .. "|r", nil, tip)
      if isNext and WHY[st.name] then add(28, nil, C.GREY .. WHY[st.name] .. "|r") end
    end
    add(0, nil, C.GREY .. L["Builds are common community picks. Swap points to suit your pet and playstyle."] .. "|r")
    list:Set(rows)
    local okT, errT = pcall(FillTree, build, steps, nextStep)
    if not okT then ns.talentTreeError = tostring(errT) end
  end
  ns.RegisterTab("talents", L["Talents"], Build, Refresh)
end

---------------------------------------------------------------------------
-- Gear: best items you can use now, by slot, and an upgrade line on item tooltips
---------------------------------------------------------------------------
local SLOTS = {
  { "HEAD", 1 }, { "NECK", 2 }, { "SHOULDER", 3 }, { "BACK", 15 }, { "CHEST", 5 }, { "WRIST", 9 }, { "HANDS", 10 },
  { "WAIST", 6 }, { "LEGS", 7 }, { "FEET", 8 }, { "FINGER", 11, 12 }, { "TRINKET", 13, 14 }, { "RANGED", 18 }, { "WEAPON", 16 },
}
local SLOT_LABEL = { HEAD = L["Head"], NECK = L["Neck"], SHOULDER = L["Shoulders"], BACK = L["Back"], CHEST = L["Chest"],
  WRIST = L["Wrists"], HANDS = L["Hands"], WAIST = L["Waist"], LEGS = L["Legs"], FEET = L["Feet"], FINGER = L["Rings"],
  TRINKET = L["Trinkets"], RANGED = L["Ranged"], WEAPON = L["Melee weapon"], OFFHAND = L["Off hand"] }

local function Score(id) local g = ns.GearItems and id and ns.GearItems[id]; return g and g[3] or 0 end

-- Score of the item worn in one inventory slot, random suffix included.
local wornCache = {}     -- [inventory slot] = { key, score }
local function WornAt(inv)
  local id = GetInventoryItemID("player", inv)
  if not id then return 0 end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
  if not ns.GearScoreOf then return Score(id) end
  local key = type(link) == "string" and not ns.IsSecret(link) and link or id
  local hit = wornCache[inv]
  if hit and hit[1] == key then return hit[2] end
  -- the tooltip of the very item you wear: it shows a random suffix's stats for certain
  local tdata
  if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
    local ok, t = pcall(C_TooltipInfo.GetInventoryItem, "player", inv)
    tdata = ok and t or nil
  end
  local score = (ns.GearScoreOf(id, link, tdata))
  wornCache[inv] = { key, score }
  return score
end

-- Score of what's worn in a slot (lowest of two for rings and trinkets, so upgrades replace the weaker one).
local function WornScore(slot)
  if slot == "OFFHAND" then return WornAt(17) end
  for _, s in ipairs(SLOTS) do
    if s[1] == slot then
      local a = WornAt(s[2])
      if s[3] then return math.min(a, WornAt(s[3])) end
      if slot == "WEAPON" then a = a + WornAt(17) end
      return a
    end
  end
  return 0
end

-- How much better an item is than what you wear, or nil when it isn't for you (not hunter gear,
-- mail before 40, level too high, an off-hand while you hold a two-hander).
function ns.GearGain(id, link, tdata)
  if not ns.GearScoreOf then return nil end
  local score, g = ns.GearScoreOf(id, link, tdata)
  if not g then return nil end
  local level = UnitLevel("player") or 1
  if g[2] > level or (g[4] == 1 and level < 40) then return nil end
  if g[1] == "OFFHAND" then
    local main = GetInventoryItemID("player", 16)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if main and instant then
      local ok, _, _, _, loc = pcall(instant, main)
      if ok and loc == "INVTYPE_2HWEAPON" then return nil end
    end
  end
  return score - WornScore(g[1]), g
end

ns.GearWornScore = function(slot) return WornScore(slot) end
ns.GearSlotLabel = function(slot) return SLOT_LABEL[slot] or slot end

local function CanWear(g, level)
  if g[2] > level then return false end
  if g[4] == 1 and level < 40 then return false end
  return true
end

-- Where an item stands among everything you can wear in its slot right now: rank (1 = best),
-- how many there are, and the best one. Only the shipped list is ranked against (items that exist
-- for everyone), at your level, mail from 40.
local rankPool = { level = 0 }
-- everything on the shipped list you can wear in a slot at a level: scores (best first) and the best item
local function Pool(slot, level)
  if rankPool.level ~= level then rankPool = { level = level } end
  local pool = rankPool[slot]
  if not pool then
    pool = { scores = {}, best = nil, bestScore = 0 }
    local db = ns.SearchDB and ns.SearchDB()
    for iid, gg in pairs(ns.GearItems) do
      if gg[1] == slot and gg[2] <= level and (gg[4] == 0 or level >= 40) and (not db or db.I[iid]) then
        pool.scores[#pool.scores + 1] = gg[3]
        if gg[3] > pool.bestScore then pool.best, pool.bestScore = iid, gg[3] end
      end
    end
    table.sort(pool.scores, function(a, b) return a > b end)
    rankPool[slot] = pool
  end
  return pool
end

local function RankOfScore(slot, score, level)
  local pool = Pool(slot, level)
  local rank = 1
  for _, s in ipairs(pool.scores) do if s > score then rank = rank + 1 else break end end
  return rank, math.max(#pool.scores, rank), pool.best
end

function ns.GearRank(id, link, tdata)
  if not ns.GearScoreOf then return nil end
  local score, g = ns.GearScoreOf(id, link, tdata)
  if not g then return nil end
  local rank, total, best = RankOfScore(g[1], score, UnitLevel("player") or 1)
  return rank, total, best, score
end

-- /ut worn: what Untamed makes of everything you wear, one line per slot, so a wrong score is easy to spot.
function ns.GearWornReport()
  ns.Print(L["What you wear, as Untamed scores it:"])
  local level = UnitLevel("player") or 1
  local seenInv = {}
  for _, s in ipairs(SLOTS) do
    for _, inv in ipairs({ s[2], s[3] }) do
      if inv and not seenInv[inv] then
        seenInv[inv] = true
        local id = GetInventoryItemID("player", inv)
        if id then
          local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
          local score = WornAt(inv)
          local _, g = ns.GearScoreOf(id, link)
          local rank, total = RankOfScore(s[1], score, level)
          ns.Print(string.format("%s%s|r  %s  %s", C.GREY, SLOT_LABEL[s[1]] or s[1], (type(link) == "string" and not ns.IsSecret(link)) and link or ("item " .. id),
            g and string.format(L["score %d, rank %d of %d"], score, rank, total) or (C.GREY .. L["not scored"] .. "|r")))
        end
      end
    end
  end
  local off = GetInventoryItemID("player", 17)
  if off then ns.Print(string.format("%s%s|r  %s", C.GREY, L["Off hand"], string.format(L["score %d"], WornAt(17)))) end
end

-- "Rank 3 of 41 shoulders you can wear at level 38."
function ns.GearRankText(id, link, short, tdata)
  local rank, total, best = ns.GearRank(id, link, tdata)
  if not rank then return nil end
  local g = ns.GearItems[tonumber(id)]
  local slot = (SLOT_LABEL[g[1]] or g[1]):lower()
  local level = UnitLevel("player") or 1
  if g[2] > level then return nil end
  if short then return string.format(L["rank %d of %d for %s"], rank, total, slot) end
  local text = string.format(L["Rank %d of %d for %s among what you can wear at level %d."], rank, total, slot, level)
  if rank > 1 and best then
    local db = ns.SearchDB and ns.SearchDB()
    local name = db and db.I[best] and db.I[best][1]
    if name then text = text .. " " .. string.format(L["The best is %s."], name) end
  end
  return text
end

-- How to get an item, as a short line: "Buy 1g 20s from X, Zone", "Quest: Y", "Dungeon: Z", ...
local function HowText(id)
  local db = ns.SearchDB and ns.SearchDB()
  local it = db and db.I[id]
  if not it then return C.GREY .. L["crafted or unknown"] .. "|r" end
  local summary, s = ns.SourceSummary(id)
  if s and s.kind == "vendor" and it[16] and it[16] > 0 then
    summary = C.GREEN .. L["Buy"] .. "|r " .. Money(it[16]) .. C.GREY .. ", " .. s.name .. "|r"
      .. (s.repF and ("  " .. ns.RepText(s.repF, s.repR, true)) or "")
  elseif s and s.kind == "quest" then
    summary = C.BLUE .. L["Quest"] .. "|r" .. C.GREY .. ": " .. s.name .. "|r"
  end
  local w = ns.ItemWays(id)
  if w.ah and not w.vendor and not w.quest then summary = summary .. C.GREY .. "  (" .. L["or Auction House"] .. ")|r" end
  return summary
end

local WAYS = { { "any", L["Any way"] }, { "easy", L["Buy or quest only"] }, { "nodungeon", L["No dungeons"] }, { "dungeon", L["Dungeons only"] },
  { "rep", L["Reputation rewards"] }, { "ah", L["Buy, quest or Auction House"] } }
local function WayOK(id, way)
  if way == "any" then return true end
  local w = ns.ItemWays(id)
  if way == "easy" then return (w.vendor or w.quest) and not w.rep end
  if way == "ah" then return ((w.vendor or w.quest) and not w.rep) or w.ah end
  if way == "dungeon" then return w.dungeon or false end
  if way == "rep" then return w.rep or false end
  if way == "nodungeon" then return w.vendor or w.quest or w.drop or w.chest or w.crafted or w.ah or w.fishing or w.inside or false end
  return true
end

-- Best upgrade per slot for a level window. Returns { [slot] = id }.
local function BestFor(slot, minLvl, maxLvl, beat, way, near)
  local db = ns.SearchDB and ns.SearchDB()
  local best, bestScore
  for id, g in pairs(ns.GearItems or {}) do
    if g[1] == slot and g[2] >= minLvl and g[2] <= maxLvl and g[3] > beat and (g[4] == 0 or maxLvl >= 40)
      and (not db or db.I[id]) and WayOK(id, way) then
      if (not bestScore or g[3] > bestScore) and (not near or (ns.ItemSources(id)[1] or {}).dist) then
        best, bestScore = id, g[3]
      end
    end
  end
  return best, bestScore
end
ns.GearBestFor = BestFor

-- The slot that is furthest behind for your level: what you wear there ranks lowest among what you
-- could wear, and there is something better to go and get. Returns
-- { slot, rank, total, worn = item id or nil, fix = item id, gain } or nil.
function ns.GearWeakest()
  if not ns.GearItems then return nil end
  local level = UnitLevel("player") or 1
  local worst
  for _, s in ipairs(SLOTS) do
    local slot = s[1]
    -- trinkets rarely carry stats a score can see, so they'd always look weakest
    if slot ~= "TRINKET" then
      -- for rings, the weaker of the two
      local inv, score = s[2], WornAt(s[2])
      if s[3] and WornAt(s[3]) < score then inv, score = s[3], WornAt(s[3]) end
      -- Something is worn there but Untamed can't score it (an item new in Forever whose stats the
      -- game hasn't given us): we can't call that slot weak on a guess
      local wornID = GetInventoryItemID("player", inv)
      local judged = true
      if wornID and ns.GearScoreOf then
        local _, g = ns.GearScoreOf(wornID, GetInventoryItemLink and GetInventoryItemLink("player", inv))
        judged = g ~= nil
      end
      local rank, total = RankOfScore(slot, score, level)
      if judged and total >= 3 and rank > 1 then
        local beat = WornScore(slot)
        local fix, fixScore = BestFor(slot, 1, level, beat, "easy", false)
        if not fix then fix, fixScore = BestFor(slot, 1, level, beat, "any", false) end
        if fix then
          local behind = (rank - 1) / total
          if not worst or behind > worst.behind then
            worst = { slot = slot, rank = rank, total = total, worn = GetInventoryItemID("player", inv), fix = fix, gain = fixScore - beat, behind = behind }
          end
        end
      end
    end
  end
  return worst
end


do
  local list, j, fill
  local opt = { slot = "all", way = "any", near = false }
  local info = {}        -- [item id] = { slot, gain, bucket }
  local weakInfo = {}    -- the same for the weakest slot's item, when it isn't in the list below
  local function SlotOptions()
    local o = { { "all", L["All slots"] } }
    for _, s in ipairs(SLOTS) do o[#o + 1] = { s[1], SLOT_LABEL[s[1]] } end
    return o
  end
  local function Build(panel)
    j = ns.MakeJournal(panel, L["No upgrades found with these filters."])
    local tb = ns.Toolbar(j.left)
    tb:Dropdown(140, SlotOptions, function() return opt.slot end, function(v) opt.slot = v end)
    tb:Check(L["Near me"], function() return opt.near end, function(v) opt.near = v end, L["Only upgrades you can get on your continent."])
    tb:Row()
    tb:Dropdown(200, WAYS, function() return opt.way end, function(v) opt.way = v end,
      { L["How you get it"], L["Buy or quest only skips dungeons, drops and the Auction House."] })
    list = tb:List()
    j.list = list
    fill = ns.ItemPageSetup(j)
    j.onSelect = function(id)
      local x = info[id] or weakInfo[id]
      fill(id, x and string.format("%s%s|r   %s+%d|r %s%s|r", C.WHITE, SLOT_LABEL[x.slot], C.GREEN, x.gain, C.GREY, L["over what you wear"]) or "")
    end
  end

  local function Refresh()
    local rows, keys, order = {}, {}, {}
    if not ns.GearItems then
      rows[1] = { 0, nil, C.GREY .. L["The gear guide"] .. "|r" }
      list:Set(rows); j:Rows(keys, order) return
    end
    local level = UnitLevel("player")
    local db = ns.SearchDB and ns.SearchDB()
    local buckets = {
      { L["Now"], 1, level, L["You can use these today."] },
      { L["Soon"], level + 1, math.min(60, level + 5), L["Within the next 5 levels."] },
      { L["Later"], level + 6, math.min(60, level + 10), L["6 to 10 levels from now."] },
    }
    local slots = {}
    for _, s in ipairs(SLOTS) do if opt.slot == "all" or opt.slot == s[1] then slots[#slots + 1] = s[1] end end
    local beatBy = {}
    for _, slot in ipairs(slots) do beatBy[slot] = WornScore(slot) end
    wipe(info)
    -- first of all: the slot that is furthest behind, and the thing to go and get for it
    if opt.slot == "all" then
      local okW, weak = pcall(ns.GearWeakest)
      wipe(weakInfo)
      if okW and weak then
        weakInfo[weak.fix] = { slot = weak.slot, gain = weak.gain }
        local it = db and db.I[weak.fix]
        local wornName = weak.worn and db and db.I[weak.worn] and db.I[weak.worn][1]
        rows[#rows + 1] = { 0, nil, L["Weakest slot"], C.GREY .. SLOT_LABEL[weak.slot] .. "|r", nil,
          { L["Weakest slot"], L["The slot where what you wear ranks lowest among everything you could wear at your level, and where there is something better to get."] }, { header = true } }
        rows[#rows + 1] = { 0, nil, C.WHITE .. (wornName and string.format(L["%s is rank %d of %d"], wornName, weak.rank, weak.total)
          or string.format(L["Nothing worn: rank %d of %d"], weak.rank, weak.total)) .. "|r", "" }
        rows[#rows + 1] = { 0, ns.ItemIcon(weak.fix), C.GREY .. L["Get: "] .. "|r" .. ns.QualityColor(weak.fix) .. (it and it[1] or "?") .. "|r",
          C.GREEN .. "+" .. weak.gain .. "|r", j:RowClick(weak.fix, function(k) ns.ItemClick(k)() end, function(k) if ns.Wishlist_Toggle then ns.Wishlist_Toggle(k) end end),
          j:RowHover(weak.fix) }
      end
    end
    for bi, b in ipairs(buckets) do
      if b[2] <= b[3] then
        local found = {}
        for _, slot in ipairs(slots) do
          local id, score = BestFor(slot, b[2], b[3], beatBy[slot], opt.way, opt.near)
          if id and not info[id] then
            info[id] = { slot = slot, gain = score - WornScore(slot), bucket = b[4] }
            found[#found + 1] = id
            beatBy[slot] = score   -- later buckets only show something better still
          end
        end
        if #found > 0 then
          rows[#rows + 1] = { 0, nil, b[1], C.GREY .. ((bi == 1) and "" or (L["lvl "] .. b[2] .. "-" .. b[3])) .. "|r", nil, nil, { header = true } }
          for _, id in ipairs(found) do
            local it = db and db.I[id]
            rows[#rows + 1] = { 0, ns.ItemIcon(id), ns.QualityColor(id) .. (it and it[1] or "?") .. "|r",
              C.GREY .. SLOT_LABEL[info[id].slot] .. "|r   " .. C.GREEN .. "+" .. info[id].gain .. "|r", j:RowClick(id, function(k) ns.ItemClick(k)() end, function(k) if ns.Wishlist_Toggle then ns.Wishlist_Toggle(k) end end),
              j:RowHover(id) }
            keys[#rows] = id
            order[#order + 1] = id
          end
        end
      end
    end
    if #order == 0 then rows[#rows + 1] = { 0, nil, C.GREY .. L["No upgrades found with these filters."] .. "|r" } end
    list:Set(rows)
    j:Rows(keys, order)
  end
  ns.RegisterTab("gear", L["Gear"], Build, Refresh)
end

-- Upgrade alerts: when you level up, and when you arrive in a zone with a vendor selling an upgrade.
local alerted = {}
local function SlotOf(id) local g = ns.GearItems and ns.GearItems[id]; return g and g[1] end
local function AlertNewLevel(level)
  if not ns.db.gearAlerts or not ns.GearItems then return end
  local n = 0
  for _, s in ipairs(SLOTS) do
    local id, score = BestFor(s[1], level, level, WornScore(s[1]), "easy", false)
    if id and n < 3 and not alerted[id] then
      alerted[id] = true
      n = n + 1
      local db = ns.SearchDB()
      ns.Print(string.format(L["New upgrade at level %d for your %s: %s. %s"], level, SLOT_LABEL[s[1]], db.I[id][1], HowText(id)))
    end
  end
end
local function AlertZone()
  if not ns.db.gearAlerts or not ns.GearItems then return end
  local map = ns.PlayerMap and ns.PlayerMap()
  if not map then return end
  local db = ns.SearchDB()
  if not db then return end
  local level = UnitLevel("player")
  for _, s in ipairs(SLOTS) do
    local id = BestFor(s[1], 1, level, WornScore(s[1]), "easy", true)
    if id and not alerted[id] then
      local src = ns.ItemSources(id)[1]
      if src and src.kind == "vendor" and src.map == map then
        alerted[id] = true
        ns.Print(string.format(L["Upgrade for your %s sold nearby: %s. %s"], SLOT_LABEL[s[1]], db.I[id][1], HowText(id)))
      end
    end
  end
end
do
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "PLAYER_LEVEL_UP")
  pcall(ev.RegisterEvent, ev, "ZONE_CHANGED_NEW_AREA")
  ev:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LEVEL_UP" then
      local lvl = tonumber(arg)
      if C_Timer and C_Timer.After then C_Timer.After(3, function() AlertNewLevel(lvl or UnitLevel("player")) end) else AlertNewLevel(lvl) end
    else
      if C_Timer and C_Timer.After then C_Timer.After(4, AlertZone) else AlertZone() end
    end
  end)
end
ns.GearAlertTest = { AlertNewLevel = AlertNewLevel, AlertZone = AlertZone }

-- Upgrade line on item tooltips.
local function OnItemTooltip(tt, id, data)
  if not ns.db.gearTooltip or not id or not ns.GearItems then return end
  if ns.IsSecret and ns.IsSecret(id) then return end
  local g = ns.GearItems[id]
  if not g then return end
  local link
  if tt.GetItem then local ok, _, l = pcall(tt.GetItem, tt); if ok then link = l end end
  if type(data) == "table" and not ns.IsSecret(data) and type(data.hyperlink) == "string" and not ns.IsSecret(data.hyperlink) then link = data.hyperlink end
  local worn = WornScore(g[1])
  local mine = ns.GearScoreOf and (ns.GearScoreOf(id, link, data)) or g[3]
  local diff = mine - worn
  local level = UnitLevel("player")
  local note = (g[4] == 1 and level < 40) and (" " .. L["(mail at 40)"]) or ""
  if diff > 0 then
    tt:AddLine(string.format("|cffabd473Untamed:|r %s+%d %s|r%s", C.GREEN, diff, L["upgrade for you"], note))
  elseif diff < 0 then
    tt:AddLine(string.format("|cffabd473Untamed:|r %s%d %s|r", C.GREY, diff, L["vs what you wear"]))
  end
  local okR, rankText = pcall(ns.GearRankText, id, link, true, data)
  if okR and rankText then tt:AddLine("|cffabd473Untamed:|r " .. C.GREY .. rankText .. "|r") end
end

do
  ns.On("LOGIN", function()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt == GameTooltip or tt == ItemRefTooltip then OnItemTooltip(tt, data and data.id, data) end
      end)
    elseif GameTooltip and GameTooltip.HookScript then
      GameTooltip:HookScript("OnTooltipSetItem", function(tt)
        local _, link = tt:GetItem()
        local id = link and tonumber(link:match("item:(%d+)"))
        OnItemTooltip(tt, id)
      end)
    end
  end)
end

---------------------------------------------------------------------------
-- Hunter quests
---------------------------------------------------------------------------
local RACE_BIT = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128 }

local function QuestDone(id)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) end
  return false
end
local QuestDoneAny
local function QuestInLog(id)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(id) ~= nil end
  if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
  return false
end

do
  local list, j
  local show = "open"
  local SHOW = { { "open", L["Not done yet"] }, { "now", L["Available now or in my log"] }, { "all", L["All, including done"] } }
  local function Build(panel)
    j = ns.TipJournal(panel, L["Quests only hunters can do."], L["Arrow to it"])
    local tb = ns.Toolbar(j.left)
    tb:Dropdown(210, SHOW, function() return show end, function(v) show = v end)
    list = tb:List()
    j.list = list
  end
  local function NpcGo(npcId, label)
    local db = ns.SearchDB and ns.SearchDB()
    local n = db and db.N[npcId]
    if not n or n[5] == 0 then ns.Print(L["No map position for that NPC."]) return end
    ns.Arrow_Set(n[5], n[6], n[7], (label and (label .. ": ") or "") .. n[1])
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local quests = ns.HunterQuests or {}
    local db = ns.SearchDB and ns.SearchDB()
    local _, race = UnitRace("player")
    local bit = RACE_BIT[race or ""] or 0
    local level = UnitLevel("player")
    local byId = {}
    for _, q in ipairs(quests) do byId[q[1]] = q end
    local mine = {}
    for _, q in ipairs(quests) do
      if q[5] == 0 or bit == 0 or math.floor(q[5] / bit) % 2 == 1 then mine[#mine + 1] = q end
    end
    -- Several trainers give the same quest (one per town): show it once, from the nearest giver.
    local pc, pe, pn = ns.PlayerWorld()
    local function GiverDist(q)
      local n = db and db.N[q[6]]
      return n and ns.DistTo and ns.DistTo(n[5], n[6], n[7], pc, pe, pn) or 1e9
    end
    local variants, rep, altOf = {}, {}, {}
    for _, q in ipairs(mine) do
      local key = q[2] .. "#" .. q[11] .. "#" .. q[4]
      variants[key] = variants[key] or {}
      table.insert(variants[key], q)
    end
    local reps = {}
    for _, list in pairs(variants) do
      table.sort(list, function(a, b) return GiverDist(a) < GiverDist(b) end)
      local r = list[1]
      reps[#reps + 1] = r
      rep[r[1]] = list
      for _, q in ipairs(list) do altOf[q[1]] = r[1] end
    end
    table.sort(reps, function(a, b) return a[1] < b[1] end)
    -- Done if any version is done, or the quest it leads to is.
    QuestDoneAny = function(q)
      for _, v in ipairs(rep[q[1]] or { q }) do if QuestDone(v[1]) then return true end end
      return q[11] ~= 0 and QuestDone(q[11]) or false
    end
    mine = reps

    -- Chains: start from quests with no prerequisite in our list, then follow "next".
    local seen, groups = {}, {}
    for _, q in ipairs(mine) do
      if not seen[q[1]] and not (q[10] ~= 0 and altOf[q[10]] and byId[q[10]]) then
        local chain, cur = {}, q
        while cur and not seen[cur[1]] do
          seen[cur[1]] = true
          chain[#chain + 1] = cur
          local nxt
          for _, c in ipairs(mine) do if altOf[c[10]] == cur[1] and not seen[c[1]] then nxt = c break end end
          cur = nxt
        end
        groups[#groups + 1] = chain
      end
    end
    for _, q in ipairs(mine) do if not seen[q[1]] then groups[#groups + 1] = { q } end end
    table.sort(groups, function(a, b) return a[1][4] < b[1][4] end)

    for _, chain in ipairs(groups) do
      local allDone = true
      for _, q in ipairs(chain) do if not QuestDoneAny(q) then allDone = false end end
      local head = chain[#chain]
      local anyNow = false
      for _, q in ipairs(chain) do
        if not QuestDoneAny(q) and (QuestInLog(q[1]) or q[4] <= level) then anyNow = true end
      end
      local showChain = show == "all" or (show == "open" and not allDone) or (show == "now" and anyNow)
      if showChain then
      -- a heading for chains (and for finished ones, which list no steps); a lone quest is just its row
      if #chain > 1 or allDone then
      add(0, nil, (allDone and C.GREEN or "") .. chain[1][2] .. (#chain > 1 and (C.GREY .. "  (" .. #chain .. " " .. L["steps"] .. ")|r") or "") .. "|r",
        allDone and (C.GREEN .. L["done"] .. "|r") or "", nil, nil, { header = true, mid = C.GREY .. L["lvl "] .. chain[1][4] .. "|r" })
      end
      if not allDone then
        for _, q in ipairs(chain) do
          local done, inLog = QuestDoneAny(q), QuestInLog(q[1])
          local status, color
          if done then status, color = C.GREEN .. L["done"] .. "|r", C.GREY
          elseif inLog then status, color = C.GOLD .. L["in your log"] .. "|r", C.WHITE
          elseif q[4] > level then status, color = C.GREY .. L["later"] .. "|r", C.GREY
          else status, color = C.ORANGE .. L["available"] .. "|r", C.WHITE end
          local starter = db and db.N[q[6]]
          local ender = db and db.N[q[9]]
          local startText = starter and starter[1] or (q[8] ~= 0 and db and db.I[q[8]] and (L["item: "] .. db.I[q[8]][1])) or "?"
          add(14, nil, color .. q[2] .. "|r", status, function()
              if inLog and q[9] ~= 0 then NpcGo(q[9], L["Turn in"])
              elseif q[6] ~= 0 then NpcGo(q[6], L["Quest"])
              elseif q[8] ~= 0 then ns.ItemClick(q[8])() end
            end,
            { q[2], L["Quest level "] .. q[3] .. ", " .. L["requires level "] .. q[4],
              L["Starts: "] .. startText .. (starter and starter[5] ~= 0 and (", " .. ns.ZoneName(starter[5])) or "")
                .. ((rep[q[1]] and #rep[q[1]] > 1) and (C.GREY .. "  " .. string.format(L["(or %d other trainers)"], #rep[q[1]] - 1) .. "|r") or ""),
              ender and (L["Turn in: "] .. ender[1] .. (ender[5] ~= 0 and (", " .. ns.ZoneName(ender[5])) or "")) or "",
              C.GREY .. L["Click for an arrow."] .. "|r" },
            { mid = C.GREY .. L["lvl "] .. q[4] .. "|r" })
        end
      end
      end
    end
    j:SetTipRows(rows)
  end
  ns.RegisterTab("quests", L["Hunter Quests"], Build, Refresh)
end

ns.CharacterTest = { BuildProblem = BuildProblem, BuildProgress = BuildProgress, SelectedBuild = SelectedBuild, Score = Score, OnItemTooltip = OnItemTooltip, Money = Money, Builds = BUILDS, Trees = TREES }
