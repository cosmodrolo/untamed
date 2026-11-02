local ADDON, ns = ...
local L = ns.L

local PREFIX = "|cffabd473Untamed|r: "
function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

local FOREVER = ns.FLAVOR == "forever"

---------------------------------------------------------------------------
-- Small API shims (Classic Era and Forever clients differ)
---------------------------------------------------------------------------
function ns.SpellName(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(id)
    return info and info.name
  elseif GetSpellInfo then
    return (GetSpellInfo(id))
  end
end

function ns.IsSecret(v) return issecretvalue and issecretvalue(v) or false end

function ns.NpcIdFromGUID(guid)
  if not guid or ns.IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" then return tonumber(id) end
end

function ns.PlayerFaction()
  local f = UnitFactionGroup("player")
  return f == "Horde" and "H" or "A"
end

---------------------------------------------------------------------------
-- Index: ability -> rank -> { npcId, ... }  (rebuilt after merging observations)
---------------------------------------------------------------------------
function ns.BuildIndex()
  ns.Teach, ns.MaxRank = {}, {}
  for npcId, b in pairs(ns.Beasts) do
    local spells = b[6]
    for i = 1, #spells, 2 do
      local ability, rank = spells[i], spells[i + 1]
      ns.Teach[ability] = ns.Teach[ability] or {}
      ns.Teach[ability][rank] = ns.Teach[ability][rank] or {}
      table.insert(ns.Teach[ability][rank], npcId)
      if rank > (ns.MaxRank[ability] or 0) then ns.MaxRank[ability] = rank end
    end
  end
  for ability, levels in pairs(ns.RankLevels) do
    if #levels > (ns.MaxRank[ability] or 0) then ns.MaxRank[ability] = #levels end
  end
  for _, ranks in pairs(ns.Teach) do
    for _, list in pairs(ranks) do
      table.sort(list, function(a, b) return ns.Beasts[a][2] < ns.Beasts[b][2] end)
    end
  end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local defaultsDB = {
  zoneAlerts = true, autoPins = true, hideTooHigh = false, minimapAngle = 200, showMinimap = true,
  tooltipInfo = true, targetAlert = true, targetSound = true, minimapPins = true, feedReminder = true,
  arrowScale = 1, autoShotBar = true, growlWarning = true, aspectReminder = true, markReminder = true, resistAlerts = true,
}
local function InitDB()
  UntamedDB = UntamedDB or {}
  for k, v in pairs(defaultsDB) do if UntamedDB[k] == nil then UntamedDB[k] = v end end
  UntamedDB.observed = UntamedDB.observed or {}
  UntamedDB.observed[ns.FLAVOR] = UntamedDB.observed[ns.FLAVOR] or {}
  UntamedCharDB = UntamedCharDB or {}
  local c = UntamedCharDB
  c.known = c.known or {}     -- [ability][rank] = true  (hunter knows it)
  c.levels = c.levels or {}   -- [ability][rank] = required pet level (read in game)
  c.tp = c.tp or {}           -- [ability][rank] = training point cost (read in game)
  c.plan = c.plan or {}       -- [ability] = false to exclude from the trip planner
  ns.db, ns.cdb = UntamedDB, UntamedCharDB
end

-- Merge beasts you tamed yourself (recorded by this addon) into the data.
local function MergeObserved()
  for npcId, o in pairs(ns.db.observed[ns.FLAVOR]) do
    local b = ns.Beasts[npcId]
    if not b then
      b = { o.name or ("Beast " .. npcId), o.level or 1, o.level or 1, o.family or "?", false, {}, {}, false, false, false }
      ns.Beasts[npcId] = b
    end
    if o.family and o.family ~= "" then b[4] = o.family end
    local have = {}
    for i = 1, #b[6], 2 do have[b[6][i] .. "#" .. b[6][i + 1]] = true end
    for ability, rank in pairs(o.spells or {}) do
      if ns.AbilityFamilies[ability] and not have[ability .. "#" .. rank] then
        table.insert(b[6], ability); table.insert(b[6], rank)
      end
    end
    if o.map and o.x and not b[7][o.map] then b[7][o.map] = { o.x, o.y } end
  end
end

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------
function ns.RankLevel(ability, rank)
  local c = ns.cdb and ns.cdb.levels[ability]
  if c and c[rank] then return c[rank], true end
  local t = ns.RankLevels[ability]
  if t and t[rank] then return t[rank], false end
  local list = ns.Teach[ability] and ns.Teach[ability][rank]
  if list and list[1] then return ns.Beasts[list[1]][2], false end
end

function ns.RankCost(ability, rank)
  local c = ns.cdb and ns.cdb.tp[ability]
  if c and c[rank] then return c[rank], true end
  local t = ns.RankTP[ability]
  if t and t[rank] then return t[rank], false end
end

function ns.HunterKnows(ability, rank)
  local k = ns.cdb and ns.cdb.known[ability]
  return k and k[rank] or false
end

function ns.LevelText(b)
  local s = (b[2] == b[3]) and tostring(b[2]) or (b[2] .. "-" .. b[3])
  if b[5] then s = s .. " " .. b[5] end
  return s
end

function ns.TeachesText(b)
  local parts = {}
  for i = 1, #b[6], 2 do parts[#parts + 1] = (ns.AbilityLabel and ns.AbilityLabel(b[6][i]) or b[6][i]) .. " " .. b[6][i + 1] end
  return table.concat(parts, ", ")
end

local function ParseRank(sub)
  if not sub or ns.IsSecret(sub) then return nil end
  return tonumber(sub:match("(%d+)"))
end

local function GetPetSpellName(i)
  if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
    return C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Pet)
  elseif GetSpellBookItemName then
    return GetSpellBookItemName(i, BOOKTYPE_PET or "pet")
  elseif GetSpellName then
    return GetSpellName(i, BOOKTYPE_PET or "pet")
  end
end

function ns.PetTrainingPoints()
  local total, used
  if C_PetInfo and C_PetInfo.GetPetTrainingPoints then total, used = C_PetInfo.GetPetTrainingPoints()
  elseif GetPetTrainingPoints then total, used = GetPetTrainingPoints() end
  if total then return total - (used or 0), total end
end

-- Returns { name, family, level, known = { [ability] = highestRank } } or nil
function ns.ScanPet()
  if not UnitExists("pet") then return nil end
  local family = ns.ToEnglish(UnitCreatureFamily("pet"))
  if not family then return nil end
  if family == "Owl" and FOREVER then family = "Bird of Prey" end
  local info = { name = UnitName("pet"), family = family, level = UnitLevel("pet"), known = {} }
  local num = HasPetSpells and HasPetSpells() or 0
  for i = 1, (num or 0) do
    local name, sub = GetPetSpellName(i)
    if name and not ns.IsSecret(name) then
      name = ns.ToEnglish(name)
      local r = ParseRank(sub) or 1
      if r > (info.known[name] or 0) then info.known[name] = r end
    end
  end
  info.tpFree = ns.PetTrainingPoints()
  return info
end

---------------------------------------------------------------------------
-- Reading Beast Training (Classic Era: craft window, Forever: trainer window)
---------------------------------------------------------------------------
local function Record(name, sub, reqLevel, tp)
  if not name or ns.IsSecret(name) then return false end
  name = ns.ToEnglish(name)
  local r = ParseRank(sub) or 1
  ns.cdb.known[name] = ns.cdb.known[name] or {}
  ns.cdb.known[name][r] = true
  if reqLevel and reqLevel > 0 then
    ns.cdb.levels[name] = ns.cdb.levels[name] or {}
    ns.cdb.levels[name][r] = reqLevel
  end
  if tp and tp > 0 then
    ns.cdb.tp[name] = ns.cdb.tp[name] or {}
    ns.cdb.tp[name][r] = tp
  end
  return true
end

function ns.ScanBeastTraining()
  if not (GetCraftDisplaySkillLine and GetNumCrafts) then return end
  local line = GetCraftDisplaySkillLine()
  if not line or (line ~= ns.SpellName(5149) and line ~= "Beast Training") then return end
  local count = 0
  for i = 1, GetNumCrafts() do
    local name, sub, kind, _, _, tp, reqLevel = GetCraftInfo(i)
    if name and kind ~= "header" and Record(name, sub, reqLevel, tp) then count = count + 1 end
  end
  if count > 0 then ns.cdb.scanned = true; ns.Refresh() end
end

function ns.ScanPetTrainer()
  if not (C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType and Enum.TrainerType.Pet) then return end
  if C_Trainer.GetTrainerType() ~= Enum.TrainerType.Pet then return end
  -- Beast Training opened from the spellbook has no NPC; a pet trainer NPC sells passives instead.
  local fromNpc = UnitExists("npc")
  local count = 0
  for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
    local name, serviceType, _, reqLevel, sub = GetTrainerServiceInfo(i)
    if name and serviceType ~= "header" then
      local tp = GetTrainerServiceCost and GetTrainerServiceCost(i)
      if fromNpc then
        local r = ParseRank(sub) or 1
        if reqLevel and reqLevel > 0 then
          ns.cdb.levels[name] = ns.cdb.levels[name] or {}; ns.cdb.levels[name][r] = reqLevel
        end
      elseif Record(name, sub, reqLevel, tp) then
        count = count + 1
      end
    end
  end
  if count > 0 then ns.cdb.scanned = true end
  ns.Refresh()
end

---------------------------------------------------------------------------
-- Planning
---------------------------------------------------------------------------
-- Returns list of { ability, current, ranks = { {rank, level, levelExact, tooHigh, known, beasts} } }
function ns.Plan(family, petLevel, knownRanks)
  local out = {}
  knownRanks = knownRanks or {}
  for _, ability in ipairs(ns.AbilityOrder) do
    local fams = ns.AbilityFamilies[ability]
    if fams and fams[family] then
      local cur = knownRanks[ability] or 0
      local entry = { ability = ability, current = cur, ranks = {} }
      for r = cur + 1, (ns.MaxRank[ability] or 0) do
        local lvl, exact = ns.RankLevel(ability, r)
        local tooHigh = petLevel and lvl and lvl > petLevel
        if not (tooHigh and ns.db.hideTooHigh) then
          table.insert(entry.ranks, {
            rank = r, level = lvl, levelExact = exact, tooHigh = tooHigh,
            known = ns.HunterKnows(ability, r),
            beasts = (ns.Teach[ability] and ns.Teach[ability][r]) or {},
          })
        end
      end
      table.insert(out, entry)
    end
  end
  return out
end

ns.state = { mode = "pet" }  -- mode = "pet" | "manual" | "stable"

function ns.Target()
  local s = ns.state
  if s.mode == "manual" and s.family then
    return { family = s.family, level = UnitLevel("player"), known = {}, manual = true }
  end
  if s.mode == "stable" and s.key and ns.cdb.pets and ns.cdb.pets[s.key] then
    local p = ns.cdb.pets[s.key]
    local cur = UnitExists("pet") and ns.PetKey(UnitName("pet"), ns.ToEnglish(UnitCreatureFamily("pet")))
    if cur ~= s.key then
      return { name = p.name, family = p.family, level = p.level, known = p.known or {}, stabled = true }
    end
  end
  return ns.ScanPet()
end

function ns.PetKey(name, family) return (name or "?") .. "|" .. (family or "?") end

-- Every beast that teaches something the current pet still needs and you don't know: [npcId] = { "Bite 3", ... }
function ns.NeededSet()
  local t = ns.Target()
  if not t then return nil end
  local need = {}
  for _, e in ipairs(ns.Plan(t.family, t.level, t.known)) do
    for _, r in ipairs(e.ranks) do
      if not r.known then
        for _, npcId in ipairs(r.beasts) do
          need[npcId] = need[npcId] or {}
          table.insert(need[npcId], e.ability .. " " .. r.rank)
        end
      end
    end
  end
  return need
end

---------------------------------------------------------------------------
-- Zone alerts
---------------------------------------------------------------------------
local lastAlert = {}
function ns.ZoneAlert(force)
  if not ns.db.zoneAlerts and not force then return end
  local t = ns.Target()
  if not t then
    if force then ns.Print(L["No pet out. Summon your pet or pick a family with /untamed."]) end
    return
  end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return end
  local playerLevel = UnitLevel("player")
  local found, seen = {}, {}
  for _, e in ipairs(ns.Plan(t.family, t.level, t.known)) do
    for _, r in ipairs(e.ranks) do
      if not r.known then
        for _, npcId in ipairs(r.beasts) do
          local b = ns.Beasts[npcId]
          if b[7][mapID] and b[2] <= playerLevel then
            local key = e.ability .. r.rank
            if not seen[key] then
              seen[key] = true
              table.insert(found, string.format("%s %d (%s %s)", e.ability, r.rank, b[1], ns.LevelText(b)))
            end
            break
          end
        end
      end
    end
  end
  local sig = mapID .. ":" .. t.family .. ":" .. #found
  if not force and lastAlert[mapID] == sig then return end
  lastAlert[mapID] = sig
  if #found == 0 then
    if force then ns.Print(L["Nothing new for your "] .. t.family .. " to learn from beasts in this zone.") end
    return
  end
  local shown = {}
  for i = 1, math.min(4, #found) do shown[i] = found[i] end
  local more = #found > 4 and string.format(" and %d more", #found - 4) or ""
  ns.Print(L["New pet skills in this zone: "] .. table.concat(shown, ", ") .. more .. ". Type /untamed to see them.")
end

---------------------------------------------------------------------------
-- Tame recorder: after you tame a beast, record what it actually knows.
---------------------------------------------------------------------------
local pendingTame
local TAME_BEAST = 1515

local function RecordTamedPet()
  local p = pendingTame
  pendingTame = nil
  if not p or not UnitExists("pet") then return end
  local info = ns.ScanPet()
  if not info then return end
  local spells = {}
  for ability, rank in pairs(info.known) do
    if ns.AbilityFamilies[ability] then spells[ability] = rank end
  end
  local obs = ns.db.observed[ns.FLAVOR]
  obs[p.npcId] = { name = p.name, level = p.level, family = info.family, spells = spells, map = p.map, x = p.x, y = p.y }
  MergeObserved()
  ns.BuildIndex()
  local list = {}
  for a, r in pairs(spells) do list[#list + 1] = a .. " " .. r end
  if #list > 0 then ns.Print(L["Recorded "] .. p.name .. ": " .. table.concat(list, ", ") .. ".") end
  ns.Refresh()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.callbacks = {}
function ns.On(event, fn) ns.callbacks[event] = ns.callbacks[event] or {}; table.insert(ns.callbacks[event], fn) end
function ns.Fire(event, ...) for _, fn in ipairs(ns.callbacks[event] or {}) do fn(...) end end

function ns.Refresh()
  ns.Fire("REFRESH")
end

local learnPatterns = {}
local function AddLearnPattern(fmt)
  if fmt then learnPatterns[#learnPatterns + 1] = "^" .. fmt:gsub("%.", "%%."):gsub("%%s", "(.+)") .. "$" end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    InitDB()
    MergeObserved()
    ns.BuildIndex()
  elseif event == "PLAYER_LOGIN" then
    AddLearnPattern(ERR_LEARN_SPELL_S)
    AddLearnPattern(ERR_LEARN_ABILITY_S)
    for _, e in ipairs({ "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "UNIT_LEVEL", "ZONE_CHANGED_NEW_AREA",
      "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START",
      "UNIT_HAPPINESS", "UNIT_PET_TRAINING_POINTS", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED" }) do
      pcall(self.RegisterEvent, self, e)
    end
    pcall(self.RegisterEvent, self, "CRAFT_SHOW")
    pcall(self.RegisterEvent, self, "CRAFT_UPDATE")
    pcall(self.RegisterEvent, self, "TRAINER_SHOW")
    pcall(self.RegisterEvent, self, "TRAINER_UPDATE")
    ns.Fire("LOGIN")
  elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    ns.ScanBeastTraining()
  elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    ns.ScanPetTrainer()
  elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(3, function() ns.ZoneAlert(false) end)
  elseif event == "UNIT_SPELLCAST_START" then
    -- arg1 unit, arg2 castGUID, arg3 spellID
    if arg1 == "player" and arg3 == TAME_BEAST then
      local guid = UnitGUID("target")
      local npcId = ns.NpcIdFromGUID(guid)
      if npcId then
        local mapID = C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        pendingTame = { npcId = npcId, name = UnitName("target"), level = UnitLevel("target"), map = mapID,
          x = pos and math.floor(pos.x * 1000) / 10, y = pos and math.floor(pos.y * 1000) / 10 }
      end
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if arg1 == "player" and arg3 == TAME_BEAST and pendingTame then
      C_Timer.After(2, RecordTamedPet)
    end
  elseif event == "CHAT_MSG_SYSTEM" then
    if ns.IsSecret(arg1) then return end
    for _, pat in ipairs(learnPatterns) do
      local what = arg1 and arg1:match(pat)
      if what then
        local name, r = what:match("^(.-) %(.-(%d+)%)$")
        if not name then name, r = what, 1 end
        name = ns.ToEnglish(name)
        if name and ns.AbilityFamilies[name] then
          ns.cdb.known[name] = ns.cdb.known[name] or {}
          ns.cdb.known[name][tonumber(r)] = true
          ns.Fire("LEARNED", name, tonumber(r))
          ns.Refresh()
        end
      end
    end
  elseif event == "UNIT_LEVEL" then
    if arg1 == "pet" then ns.Refresh() end
  elseif event == "UNIT_HAPPINESS" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED" then
    ns.Fire(event, arg1)
  else
    if event == "UNIT_PET" and arg1 ~= "player" then return end
    if ns.refreshPending then return end
    ns.refreshPending = true
    C_Timer.After(0.5, function() ns.refreshPending = false; ns.Refresh() end)
  end
end)

SLASH_UNTAMED1 = "/untamed"
SLASH_UNTAMED2 = "/ut"
SLASH_UNTAMED3 = "/psf"
SlashCmdList.UNTAMED = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  local searchText = msg:match("^search%s+(.+)$") or msg:match("^s%s+(.+)$")
  if searchText then
    ns.SearchFor(searchText)
  elseif msg == "zone" then
    ns.ZoneAlert(true)
  elseif msg == "alerts" then
    ns.db.zoneAlerts = not ns.db.zoneAlerts
    ns.Print(L["Zone alerts "] .. (ns.db.zoneAlerts and "on." or "off."))
    ns.Refresh()
  elseif msg == "clear" then
    if ns.Pins_Clear then ns.Pins_Clear() end
    if ns.Arrow_Clear then ns.Arrow_Clear() end
  elseif msg == "minimap" then
    ns.db.showMinimap = not ns.db.showMinimap
    ns.Fire("MINIMAP_TOGGLE")
  elseif msg == "ammo" then
    ns.NavigateService("A", L["Ammo vendor"])
  elseif msg == "trainer" then
    ns.NavigateService("T", L["Hunter trainer"])
  elseif msg == "pettrainer" then
    ns.NavigateService("P", L["Pet trainer"])
  elseif msg == "stable" then
    ns.NavigateService("S", L["Stable master"])
  elseif msg == "rare" then
    ns.NavigateLastRare()
  elseif msg == "next" then
    ns.Route_Next()
  elseif msg == "plan" or msg == "browse" or msg == "care" or msg == "settings" or msg == "builds" or msg == "search"
    or msg == "supplies" or msg == "spells" or msg == "talents" or msg == "gear" or msg == "quests" then
    if ns.UI_Show then ns.UI_Show(msg) end
  elseif msg == "help" then
    ns.Print("/untamed  open the window   |  /untamed plan, browse, care, settings  open a tab")
    ns.Print("/untamed search <text>  (or /ut s <text>)  find any item, NPC or beast and where to get it")
    ns.Print("/untamed zone  what your pet can learn in this zone   |  /untamed next  skip to the next route stop")
    ns.Print("/untamed ammo, trainer, pettrainer, stable  arrow to the nearest one   |  /untamed rare  arrow to the last rare seen")
    ns.Print("/untamed clear  clear map focus and the navigation arrow")
    ns.Print("/untamed alerts  toggle zone alerts   |  /untamed minimap  toggle the minimap button")
  else
    if ns.UI_Toggle then ns.UI_Toggle() end
  end
end
