local _, ns = ...
local L = ns.L
local C = ns.C

-- Character planning: Spells (trainer guide), Talents, Gear and Hunter Quests.

local ERA = ns.FLAVOR ~= "forever"

local function Money(copper)
  copper = copper or 0
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  if g > 0 then out[#out + 1] = C.GOLD .. g .. "g|r" end
  if s > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
  if c > 0 or #out == 0 then out[#out + 1] = "|cffeda55f" .. c .. "c|r" end
  return table.concat(out, " ")
end
ns.Money = Money

local function Known(spellID)
  if IsPlayerSpell then
    local ok, v = pcall(IsPlayerSpell, spellID)
    if ok and v then return true end
  end
  if IsSpellKnown then
    local ok, v = pcall(IsSpellKnown, spellID)
    if ok and v then return true end
  end
  return false
end

local function NotForever(add, what)
  add(0, nil, C.ORANGE .. string.format(L["%s uses Classic Era data. WoW Forever reworked hunters, so this page will be filled in once Forever's data is available."], what) .. "|r")
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

do
  local list
  local showAll = false
  local function Build(panel)
    local b = ns.MakeButton(panel, L["Show every level"], 160, function(self)
      showAll = not showAll
      self:SetText(showAll and L["Show what's next"] or L["Show every level"])
      ns.UI_Refresh()
    end)
    b:SetPoint("TOPLEFT", 4, -2)
    list = ns.NewList(panel, 30)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if not ERA or not ns.TrainerSpells then NotForever(add, L["The spell guide"]); list:Set(rows) return end
    local playerLevel = UnitLevel("player")
    -- Highest rank per spell name the player knows.
    local missingNow, missingNowCost, optionalCost = 0, 0, 0
    local byLevel, levels = {}, {}
    for _, e in ipairs(ns.TrainerSpells) do
      local lvl, id, cost, name = e[1], e[2], e[3], e[4]
      local known = Known(id)
      if not byLevel[lvl] then byLevel[lvl] = {}; levels[#levels + 1] = lvl end
      table.insert(byLevel[lvl], e)
      if not known and lvl <= playerLevel then
        if OPTIONAL[name] then optionalCost = optionalCost + cost
        else missingNow = missingNow + 1; missingNowCost = missingNowCost + cost end
      end
    end
    table.sort(levels)
    add(0, ns.Icon("INV_Misc_Book_11"), L["Ready to train now"],
      missingNow > 0 and (C.WHITE .. missingNow .. " " .. L["spells"] .. "|r  " .. Money(missingNowCost)) or (C.GREEN .. L["all caught up"] .. "|r"),
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
      elseif lvl > playerLevel then status = C.GREY .. L["later"] .. "|r"
      elseif OPTIONAL[name] then status = C.GREY .. L["optional"] .. "|r"
      else status = C.ORANGE .. L["train now"] .. "|r" end
      local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id)) or nil
      add(indent or 14, icon, (known and C.GREY or C.WHITE) .. label .. "|r" .. (rank > 0 and (C.GREY .. "  " .. L["Rank "] .. rank .. "|r") or ""),
        status .. "   " .. Money(cost), nil,
        { label .. (rank > 0 and (" " .. L["Rank "] .. rank) or ""), L["Trainer level "] .. lvl .. ", " .. Money(cost),
          OPTIONAL[name] and (C.GREY .. L["Many hunters skip this while leveling to save gold and buy it later if they need it."] .. "|r") or "" },
        { mid = C.GREY .. L["lvl "] .. lvl .. "|r" })
    end

    if showAll then
      -- Every trainer level, everything, known or not.
      for _, lvl in ipairs(levels) do
        local total = 0
        for _, e in ipairs(byLevel[lvl]) do total = total + e[3] end
        add(0, nil, (lvl <= playerLevel and C.GOLD or C.GREY) .. L["Level "] .. lvl .. "|r", Money(total), nil, nil, { header = true })
        for _, e in ipairs(byLevel[lvl]) do SpellRow(e, lvl) end
      end
    else
      -- What's next: what you can train now, then your next two trainer visits.
      for _, lvl in ipairs(levels) do
        if lvl <= playerLevel then
          for _, e in ipairs(byLevel[lvl]) do
            if not Known(e[2]) and not OPTIONAL[e[4]] then SpellRow(e, lvl) end
          end
        end
      end
      local shown = 0
      for _, lvl in ipairs(levels) do
        if lvl > playerLevel and shown < 2 then
          shown = shown + 1
          local total = 0
          for _, e in ipairs(byLevel[lvl]) do total = total + e[3] end
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
    list:Set(rows)
  end
  ns.RegisterTab("spells", L["Spells"], Build, Refresh)
end

---------------------------------------------------------------------------
-- Talents: leveling and raid builds, with the next point highlighted in the talent window
---------------------------------------------------------------------------
-- Tree layout (Classic Era): per tab, talents per tier in column order, with max ranks.
local TREES = {
  { -- Beast Mastery
    { { "Improved Aspect of the Hawk", 5 }, { "Endurance Training", 5 } },
    { { "Improved Eyes of the Beast", 2 }, { "Improved Aspect of the Monkey", 5 }, { "Thick Hide", 3 }, { "Improved Revive Pet", 2 } },
    { { "Pathfinding", 2 }, { "Bestial Swiftness", 1 }, { "Unleashed Fury", 5 } },
    { { "Improved Mend Pet", 2 }, { "Ferocity", 5 } },
    { { "Spirit Bond", 2 }, { "Intimidation", 1 }, { "Bestial Discipline", 2 } },
    { { "Frenzy", 5 } },
    { { "Bestial Wrath", 1 } },
  },
  { -- Marksmanship
    { { "Improved Concussive Shot", 5 }, { "Efficiency", 5 } },
    { { "Improved Hunter's Mark", 5 }, { "Lethal Shots", 5 } },
    { { "Aimed Shot", 1 }, { "Improved Arcane Shot", 5 }, { "Hawk Eye", 3 } },
    { { "Improved Serpent Sting", 5 }, { "Mortal Shots", 5 } },
    { { "Scatter Shot", 1 }, { "Barrage", 3 }, { "Improved Scorpid Sting", 3 } },
    { { "Ranged Weapon Specialization", 5 } },
    { { "Trueshot Aura", 1 } },
  },
}

-- Builds as steps of { tab, talent, points } in the order to take them.
local BUILDS = {
  {
    key = "leveling", label = L["Leveling (Beast Mastery)"], split = "31/20/0",
    source = "Icy Veins, Classic Beast Mastery Hunter Leveling Guide 1-60",
    steps = {
      { 1, "Improved Aspect of the Hawk", 5 }, { 1, "Improved Revive Pet", 2 }, { 1, "Thick Hide", 3 }, { 1, "Pathfinding", 2 },
      { 1, "Bestial Swiftness", 1 }, { 1, "Unleashed Fury", 5 }, { 1, "Ferocity", 2 }, { 1, "Intimidation", 1 },
      { 1, "Ferocity", 3 }, { 1, "Bestial Discipline", 1 }, { 1, "Frenzy", 5 }, { 1, "Bestial Wrath", 1 },
      { 2, "Improved Concussive Shot", 5 }, { 2, "Lethal Shots", 5 }, { 2, "Aimed Shot", 1 }, { 2, "Hawk Eye", 3 },
      { 2, "Efficiency", 1 }, { 2, "Mortal Shots", 5 },
    },
  },
  {
    key = "raid", label = L["Raid (Marksmanship)"], split = "20/31/0",
    source = "Icy Veins and Warcraft Tavern, Classic hunter raid builds",
    steps = {
      { 1, "Improved Aspect of the Hawk", 5 }, { 1, "Endurance Training", 5 }, { 1, "Unleashed Fury", 5 }, { 1, "Ferocity", 5 },
      { 2, "Efficiency", 5 }, { 2, "Lethal Shots", 5 }, { 2, "Improved Hunter's Mark", 3 }, { 2, "Aimed Shot", 1 },
      { 2, "Hawk Eye", 3 }, { 2, "Mortal Shots", 5 }, { 2, "Barrage", 3 }, { 2, "Ranged Weapon Specialization", 5 },
      { 2, "Trueshot Aura", 1 },
    },
  },
}

-- Find the game's talent index for one of ours: by English name, else by position in the tree.
local function TalentInfo(tab, i)
  if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
    local ok, t = pcall(C_SpecializationInfo.GetTalentInfo, { specializationIndex = tab, talentIndex = i })
    if ok and t then return t.name, t.tier, t.column, t.rank, t.maxRank end
  end
  if GetTalentInfo then
    local ok, name, _, tier, column, rank, maxRank = pcall(GetTalentInfo, tab, i)
    if ok and name then return name, tier, column, rank, maxRank end
  end
end

local talentMap   -- [tab][englishName] = { index, maxRank }
local function MapTalents()
  if talentMap then return talentMap end
  local map, total = {}, 0
  for tab = 1, 2 do
    map[tab] = {}
    local n = GetNumTalents and GetNumTalents(tab) or 0
    total = total + n
    local byTier = {}
    for i = 1, n do
      local name, tier, column, _, maxRank = TalentInfo(tab, i)
      if name then
        byTier[tier] = byTier[tier] or {}
        table.insert(byTier[tier], { i = i, name = name, column = column, maxRank = maxRank })
      end
    end
    for tier, ours in ipairs(TREES[tab]) do
      local theirs = byTier[tier] or {}
      table.sort(theirs, function(a, b) return a.column < b.column end)
      for k, t in ipairs(ours) do
        local hit
        for _, g in ipairs(theirs) do if g.name == t[1] then hit = g end end
        if not hit and #theirs == #ours and theirs[k] and theirs[k].maxRank == t[2] then hit = theirs[k] end
        if hit then map[tab][t[1]] = { index = hit.i, maxRank = hit.maxRank, name = hit.name } end
      end
    end
  end
  if total > 0 then talentMap = map end
  return map
end

local function CurrentRank(tab, english)
  local m = MapTalents()[tab][english]
  if not m then return nil end
  local _, _, _, rank = TalentInfo(tab, m.index)
  return rank or 0, m
end

-- Walk the build: returns each step with done points, and the next talent to take.
local function BuildProgress(build)
  local want, out, nextStep = {}, {}, nil
  for i, st in ipairs(build.steps) do
    local tab, name, pts = st[1], st[2], st[3]
    want[tab .. name] = (want[tab .. name] or 0) + pts
    local target = want[tab .. name]
    local rank, m = CurrentRank(tab, name)
    local done = rank and math.max(0, math.min(pts, rank - (target - pts))) or 0
    out[i] = { tab = tab, name = name, pts = pts, done = done, label = m and m.name or name, index = m and m.index }
    if not nextStep and done < pts then nextStep = out[i] end
  end
  return out, nextStep
end

local function SelectedBuild()
  local key = ns.cdb.talentBuild or "leveling"
  for _, b in ipairs(BUILDS) do if b.key == key then return b end end
  return BUILDS[1]
end

-- Glow on the next talent in the game's talent window.
local glow
local function UpdateGlow()
  if not ERA or not PlayerTalentFrame then return end
  if not glow then
    glow = PlayerTalentFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.67, 0.83, 0.45)
    glow:SetSize(66, 66)
  end
  glow:Hide()
  if ns.db.talentGlow == false then return end
  local _, nextStep = BuildProgress(SelectedBuild())
  if not nextStep or not nextStep.index then return end
  local tab = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(PlayerTalentFrame)
  if tab ~= nextStep.tab then return end
  local btn = _G["PlayerTalentFrameTalent" .. nextStep.index]
  if btn and btn:IsShown() then
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
    glow:Show()
  end
end

local function HookTalentFrame()
  if not PlayerTalentFrame or PlayerTalentFrame.untamedHooked then return end
  PlayerTalentFrame.untamedHooked = true
  PlayerTalentFrame:HookScript("OnShow", UpdateGlow)
  if PlayerTalentFrame_Update then hooksecurefunc("PlayerTalentFrame_Update", UpdateGlow) end
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then if arg == "Blizzard_TalentUI" then HookTalentFrame() end
    elseif event ~= "ADDON_LOADED" then talentMap = nil; UpdateGlow() end
  end)
end

do
  local list, buttons = nil, {}
  local function Build(panel)
    local x = 4
    for _, b in ipairs(BUILDS) do
      local btn = ns.MakeButton(panel, b.label, 170, function() ns.cdb.talentBuild = b.key; UpdateGlow(); ns.UI_Refresh() end)
      btn:SetPoint("TOPLEFT", x, -2)
      buttons[b.key] = btn
      x = x + 174
    end
    list = ns.NewList(panel, 30)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if not ERA then NotForever(add, L["The talent guide"]); list:Set(rows) return end
    local build = SelectedBuild()
    for k, btn in pairs(buttons) do if k == build.key then btn:LockHighlight() else btn:UnlockHighlight() end end
    local steps, nextStep = BuildProgress(build)
    local free = UnitCharacterPoints and UnitCharacterPoints("player") or 0
    add(0, ns.Icon(build.key == "raid" and "Ability_TrueShot" or "Ability_Druid_FerociousBite"), build.label .. "  " .. C.GREY .. build.split .. "|r",
      free and free > 0 and (C.GREEN .. free .. " " .. L["points to spend"] .. "|r") or "", nil,
      { build.label, L["Source: "] .. build.source, L["Open your talent window: the next talent in this build glows green."] }, { header = true })
    if not MapTalents()[1]["Improved Aspect of the Hawk"] then
      add(0, nil, C.GREY .. L["Open your talent window once so Untamed can read your talents."] .. "|r")
    end
    local level = 9
    for i, st in ipairs(steps) do
      local first = level + 1
      level = level + st.pts
      local isNext = st == nextStep
      local color = st.done >= st.pts and C.GREEN or (isNext and C.GOLD or C.WHITE)
      local lvlText = st.pts > 1 and (first .. "-" .. level) or tostring(first)
      add(14, nil, string.format("%s%s|r  %s%d/%d|r", color, st.label, C.GREY, st.done, st.pts),
        (st.tab == 1 and L["Beast Mastery"] or L["Marksmanship"]) .. (isNext and (C.GOLD .. "   " .. L["next"] .. "|r") or ""), nil, nil,
        { mid = C.GREY .. L["lvl "] .. lvlText .. "|r" })
    end
    add(0, nil, C.GREY .. L["Builds are common community picks. Swap points to suit your pet and playstyle."] .. "|r")
    list:Set(rows)
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

-- Score of what's worn in a slot (lowest of two for rings and trinkets, so upgrades replace the weaker one).
local function WornScore(slot)
  for _, s in ipairs(SLOTS) do
    if s[1] == slot then
      local a = Score(GetInventoryItemID("player", s[2]))
      if s[3] then return math.min(a, Score(GetInventoryItemID("player", s[3]))) end
      if slot == "WEAPON" then a = a + Score(GetInventoryItemID("player", 17)) end
      return a
    end
  end
  return 0
end

ns.GearWornScore = function(slot) return WornScore(slot) end
ns.GearSlotLabel = function(slot) return SLOT_LABEL[slot] or slot end

local function CanWear(g, level)
  if g[2] > level then return false end
  if g[4] == 1 and level < 40 then return false end
  return true
end

-- How to get an item, as a short line: "Buy 1g 20s from X, Zone", "Quest: Y", "Dungeon: Z", ...
local function HowText(id)
  local db = ns.SearchDB and ns.SearchDB()
  local it = db and db.I[id]
  if not it then return C.GREY .. L["crafted or unknown"] .. "|r" end
  local summary, s = ns.SourceSummary(id)
  if s and s.kind == "vendor" and it[16] and it[16] > 0 then
    summary = C.GREEN .. L["Buy"] .. "|r " .. Money(it[16]) .. C.GREY .. ", " .. s.name .. (s.map and s.map ~= 0 and (", " .. ns.ZoneName(s.map)) or "")
      .. (s.dist and (", " .. ns.FormatDistance(s.dist)) or "") .. "|r" .. (s.repF and ("  " .. ns.RepText(s.repF, s.repR, true)) or "")
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

do
  local list
  local opt = { slot = "all", way = "any", near = false }
  local function SlotOptions()
    local o = { { "all", L["All slots"] } }
    for _, s in ipairs(SLOTS) do o[#o + 1] = { s[1], SLOT_LABEL[s[1]] } end
    return o
  end
  local function Build(panel)
    local sd = ns.MakeDropdown(panel, 140, SlotOptions, function() return opt.slot end, function(v) opt.slot = v end)
    sd:SetPoint("TOPLEFT", 4, -2)
    local wd = ns.MakeDropdown(panel, 190, WAYS, function() return opt.way end, function(v) opt.way = v end,
      { L["How you get it"], L["Buy or quest only skips dungeons, drops and the Auction House."] })
    wd:SetPoint("LEFT", sd, "RIGHT", 4, 0)
    ns.MakeCheck(panel, L["Near me"], 344, -2, function() return opt.near end, function(v) opt.near = v end,
      L["Only upgrades you can get on your continent."])
    list = ns.NewList(panel, 30)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if not ERA or not ns.GearItems then NotForever(add, L["The gear guide"]); list:Set(rows) return end
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
    local any = false
    for bi, b in ipairs(buckets) do
      if b[2] <= b[3] then
        local bucketRows = {}
        for _, slot in ipairs(slots) do
          local id, score = BestFor(slot, b[2], b[3], beatBy[slot], opt.way, opt.near)
          if id then
            local worn = WornScore(slot)
            local it = db and db.I[id]
            bucketRows[#bucketRows + 1] = { 14, ns.ItemIcon(id),
              string.format("%s%s|r  %s%s|r  %s+%d|r", C.GREY, SLOT_LABEL[slot], ns.QualityColor(id), it and it[1] or "?", C.GREEN, score - worn),
              HowText(id), ns.ItemClick(id), ns.ItemTooltip(id),
              { mid = ((bi > 1) and C.ORANGE or C.GREY) .. L["lvl "] .. ns.GearItems[id][2] .. "|r" } }
            beatBy[slot] = score   -- later buckets only show something better still
          end
        end
        add(0, nil, b[1], C.GREY .. b[4] .. "|r", nil, nil, { header = true })
        if #bucketRows == 0 then
          add(14, nil, C.GREY .. L["No upgrades found with these filters."] .. "|r")
        else
          any = true
          for _, r in ipairs(bucketRows) do rows[#rows + 1] = r end
        end
      end
    end
    add(0, nil, C.GREY .. L["Score: agility x2.4, attack power x1, 1% crit x20, 1% hit x18, stamina x0.5, ranged DPS x14. Set bonuses and procs aren't counted."] .. "|r")
    list:Set(rows)
  end
  ns.RegisterTab("gear", L["Gear"], Build, Refresh)
end

-- Upgrade alerts: when you level up, and when you arrive in a zone with a vendor selling an upgrade.
local alerted = {}
local function SlotOf(id) local g = ns.GearItems and ns.GearItems[id]; return g and g[1] end
local function AlertNewLevel(level)
  if not ERA or not ns.db.gearAlerts or not ns.GearItems then return end
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
  if not ERA or not ns.db.gearAlerts or not ns.GearItems then return end
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
local function OnItemTooltip(tt, id)
  if not ns.db.gearTooltip or not id or not ns.GearItems then return end
  local g = ns.GearItems[id]
  if not g then return end
  local worn = WornScore(g[1])
  local diff = g[3] - worn
  local level = UnitLevel("player")
  local note = (g[4] == 1 and level < 40) and (" " .. L["(mail at 40)"]) or ""
  if diff > 0 then
    tt:AddLine(string.format("|cffabd473Untamed:|r %s+%d %s|r%s", C.GREEN, diff, L["upgrade for you"], note))
  elseif diff < 0 then
    tt:AddLine(string.format("|cffabd473Untamed:|r %s%d %s|r", C.GREY, diff, L["vs what you wear"]))
  end
end

if ERA then
  ns.On("LOGIN", function()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt == GameTooltip or tt == ItemRefTooltip then OnItemTooltip(tt, data and data.id) end
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
local function QuestInLog(id)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(id) ~= nil end
  if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
  return false
end

do
  local list
  local function Build(panel) list = ns.NewList(panel, 0) end
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
    -- Chains: start from quests with no prerequisite in our list, then follow "next".
    local seen, groups = {}, {}
    for _, q in ipairs(mine) do
      if not seen[q[1]] and not (q[10] ~= 0 and byId[q[10]]) then
        local chain, cur = {}, q
        while cur and not seen[cur[1]] do
          seen[cur[1]] = true
          chain[#chain + 1] = cur
          local nxt
          for _, c in ipairs(mine) do if c[10] == cur[1] and not seen[c[1]] then nxt = c break end end
          cur = nxt
        end
        groups[#groups + 1] = chain
      end
    end
    for _, q in ipairs(mine) do if not seen[q[1]] then groups[#groups + 1] = { q } end end
    table.sort(groups, function(a, b) return a[1][4] < b[1][4] end)

    add(0, nil, C.GREY .. L["Quests only hunters can do. Click a quest for an arrow to who starts it (or who to turn it in to)."] .. "|r")
    for _, chain in ipairs(groups) do
      local allDone = true
      for _, q in ipairs(chain) do if not QuestDone(q[1]) then allDone = false end end
      local head = chain[#chain]
      add(0, nil, (allDone and C.GREEN or "") .. chain[1][2] .. (#chain > 1 and (C.GREY .. "  (" .. #chain .. " " .. L["steps"] .. ")|r") or "") .. "|r",
        allDone and (C.GREEN .. L["done"] .. "|r") or "", nil, nil, { header = true, mid = C.GREY .. L["lvl "] .. chain[1][4] .. "|r" })
      if not allDone then
        for _, q in ipairs(chain) do
          local done, inLog = QuestDone(q[1]), QuestInLog(q[1])
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
              L["Starts: "] .. startText .. (starter and starter[5] ~= 0 and (", " .. ns.ZoneName(starter[5])) or ""),
              ender and (L["Turn in: "] .. ender[1] .. (ender[5] ~= 0 and (", " .. ns.ZoneName(ender[5])) or "")) or "",
              C.GREY .. L["Click for an arrow."] .. "|r" },
            { mid = C.GREY .. L["lvl "] .. q[4] .. "|r" })
        end
      end
    end
    list:Set(rows)
  end
  ns.RegisterTab("quests", L["Hunter Quests"], Build, Refresh)
end

ns.CharacterTest = { BuildProgress = BuildProgress, SelectedBuild = SelectedBuild, Score = Score, OnItemTooltip = OnItemTooltip, Money = Money }
