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
    local b = ns.MakeButton(panel, L["Show every level"], 140, function(self)
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
    for _, lvl in ipairs(levels) do
      local show = showAll or (lvl <= playerLevel + 6 and lvl >= playerLevel - 20)
      local group = byLevel[lvl]
      local anyMissing = false
      for _, e in ipairs(group) do if lvl <= playerLevel and not Known(e[2]) then anyMissing = true end end
      if show or anyMissing then
        local total = 0
        for _, e in ipairs(group) do total = total + e[3] end
        local lvlColor = lvl <= playerLevel and C.GOLD or C.GREY
        add(0, nil, lvlColor .. L["Level "] .. lvl .. "|r", Money(total), nil, nil, { header = lvl == playerLevel + 1 or lvl == playerLevel })
        for _, e in ipairs(group) do
          local id, cost, name, rank = e[2], e[3], e[4], e[5]
          local label = ns.SpellName(id) or name
          local known = Known(id)
          local status
          if known then status = C.GREEN .. L["known"] .. "|r"
          elseif lvl > playerLevel then status = C.GREY .. L["later"] .. "|r"
          elseif OPTIONAL[name] then status = C.GREY .. L["optional"] .. "|r"
          else status = C.ORANGE .. L["train now"] .. "|r" end
          local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id)) or nil
          add(14, icon, (known and C.GREY or C.WHITE) .. label .. "|r" .. (rank > 0 and (C.GREY .. "  " .. L["Rank "] .. rank .. "|r") or ""),
            status .. "   " .. Money(cost), nil,
            { label .. (rank > 0 and (" " .. L["Rank "] .. rank) or ""), L["Trainer level "] .. lvl .. ", " .. Money(cost),
              OPTIONAL[name] and (C.GREY .. L["Many hunters skip this while leveling to save gold and buy it later if they need it."] .. "|r") or "" })
        end
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

local function CanWear(g, level)
  if g[2] > level then return false end
  if g[4] == 1 and level < 40 then return false end
  return true
end

do
  local list
  local function Build(panel) list = ns.NewList(panel, 0) end
  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    if not ERA or not ns.GearItems then NotForever(add, L["The gear guide"]); list:Set(rows) return end
    local level = UnitLevel("player")
    local db = ns.SearchDB and ns.SearchDB()
    add(0, nil, C.GREY .. L["Best items for your level by a simple hunter score: agility and attack power first, then hit, crit and ranged weapon damage."] .. "|r", "", nil,
      { L["How the score works"], L["Agility x2.4, attack power x1, 1% crit x20, 1% hit x18, stamina x0.5, intellect x0.3, ranged weapon DPS x14."],
        L["It's a quick guide, not a full simulation. Set bonuses and procs aren't counted."] })
    -- Bucket items by slot once.
    local bySlot = {}
    for id, g in pairs(ns.GearItems) do
      if CanWear(g, level + 3) and (not db or db.I[id]) then
        bySlot[g[1]] = bySlot[g[1]] or {}
        table.insert(bySlot[g[1]], id)
      end
    end
    for _, s in ipairs(SLOTS) do
      local slot = s[1]
      local worn = WornScore(slot)
      local wornID = GetInventoryItemID("player", s[2])
      local wornName = wornID and (ns.QualityColor(wornID) .. (ns.SearchDB() and ns.SearchDB().I[wornID] and ns.SearchDB().I[wornID][1] or (GetItemInfo(wornID) or "?")) .. "|r") or (C.GREY .. L["empty"] .. "|r")
      add(0, nil, SLOT_LABEL[slot], wornName .. C.GREY .. "  (" .. worn .. ")|r", nil, nil, { header = true })
      local ids = bySlot[slot] or {}
      table.sort(ids, function(a, b) return ns.GearItems[a][3] > ns.GearItems[b][3] end)
      local shown = 0
      for _, id in ipairs(ids) do
        if shown >= 3 then break end
        local g = ns.GearItems[id]
        if g[3] > worn then
          local soon = g[2] > level
          local srcs = ns.ItemSources(id)
          local s1 = srcs[1]
          local where = s1 and ((s1.kind == "vendor" and C.GREEN or C.GREY) .. (s1.inst or (s1.map and s1.map ~= 0 and ns.ZoneName(s1.map)) or "") .. "|r") or (C.GREY .. L["crafted"] .. "|r")
          add(14, ns.ItemIcon(id), ns.QualityColor(id) .. (db and db.I[id] and db.I[id][1] or "?") .. "|r" .. C.GREEN .. "  +" .. (g[3] - worn) .. "|r" .. (soon and (C.GREY .. "  " .. L["soon"] .. "|r") or ""),
            where, ns.ItemClick(id), ns.ItemTooltip(id), { mid = ((soon and C.RED) or C.GREY) .. L["lvl "] .. g[2] .. "|r" })
          shown = shown + 1
        end
      end
      if shown == 0 then add(14, nil, C.GREY .. L["Nothing better found for your level."] .. "|r") end
    end
    list:Set(rows)
  end
  ns.RegisterTab("gear", L["Gear"], Build, Refresh)
end

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
