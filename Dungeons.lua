local _, ns = ...
local L = ns.L
local C = ns.C

-- Dungeon guide: level range, entrance arrow, hunter loot by boss (ranked by the gear score),
-- and tameable beasts inside. Loot and bosses come from the search index.

local DUNGEONS = {
  { "Ragefire Chasm", 13, 18 }, { "Wailing Caverns", 17, 24 }, { "The Deadmines", 17, 26 }, { "Shadowfang Keep", 22, 30 },
  { "Blackfathom Deeps", 24, 32 }, { "The Stockade", 24, 32 }, { "Gnomeregan", 29, 38 }, { "Razorfen Kraul", 29, 38 },
  { "Scarlet Monastery", 34, 45 }, { "Razorfen Downs", 37, 46 }, { "Uldaman", 41, 51 }, { "Zul'Farrak", 44, 54 },
  { "Maraudon", 46, 55 }, { "The Temple of Atal'Hakkar", 50, 56 }, { "Blackrock Depths", 52, 60 }, { "Blackrock Spire", 55, 60 },
  { "Dire Maul", 55, 60 }, { "Stratholme", 58, 60 }, { "Scholomance", 58, 60 },
  { "Zul'Gurub", 60, 60, true }, { "Molten Core", 60, 60, true }, { "Onyxia's Lair", 60, 60, true }, { "Blackwing Lair", 60, 60, true },
  { "Ruins of Ahn'Qiraj", 60, 60, true }, { "Temple of Ahn'Qiraj", 60, 60, true }, { "Naxxramas", 60, 60, true },
}

local cache = {}
-- Everything about one dungeon: entrance, bosses with their hunter loot, tameable beasts.
local function Info(name)
  if cache[name] then return cache[name] end
  local db = ns.SearchDB and ns.SearchDB()
  if not db then return nil end
  local npcs, entrance = {}, nil
  for id, n in pairs(db.N) do
    if n[10] == name then
      npcs[id] = true
      if not entrance and n[5] ~= 0 then entrance = { n[5], n[6], n[7] } end
    end
  end
  local bosses = {}   -- [npcId] = { itemIds }
  for itemId, it in pairs(db.I) do
    for _, d in ipairs(it[7] or {}) do
      if npcs[d] and (it[13] or 1) >= 2 and (it[4] == 2 or it[4] == 4) then
        bosses[d] = bosses[d] or {}
        table.insert(bosses[d], itemId)
      end
    end
  end
  local beasts = {}
  for id, b in pairs(ns.Beasts) do if b[8] == name or npcs[id] then beasts[#beasts + 1] = id end end
  table.sort(beasts, function(a, b) return ns.Beasts[a][2] < ns.Beasts[b][2] end)
  cache[name] = { entrance = entrance, bosses = bosses, beasts = beasts }
  return cache[name]
end
ns.DungeonInfo = Info

local function Score(id) local g = ns.GearItems and ns.GearItems[id]; return g and g[3] or 0 end
local function Worn(slot)
  return ns.GearWornScore and ns.GearWornScore(slot) or 0
end

do
  local list
  local opt = { name = nil, slot = "all", upgrades = false }
  local function Options()
    local o = {}
    for _, d in ipairs(DUNGEONS) do o[#o + 1] = { d[1], d[1] .. (d[4] and (" " .. L["(raid)"]) or (" " .. d[2] .. "-" .. d[3])) } end
    return o
  end
  local function Suggested()
    local level = UnitLevel("player")
    local best
    for _, d in ipairs(DUNGEONS) do
      if not d[4] and level >= d[2] - 2 and level <= d[3] then best = d[1] end
    end
    return best or (level >= 58 and "Stratholme") or DUNGEONS[1][1]
  end
  local function Build(panel)
    local tb = ns.Toolbar(panel)
    tb:Dropdown(250, Options, function() return opt.name or Suggested() end, function(v) opt.name = v end)
    tb:Dropdown(130, function()
      local o = { { "all", L["All slots"] } }
      for _, s in ipairs({ "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "FINGER", "TRINKET", "RANGED", "WEAPON" }) do
        o[#o + 1] = { s, ns.GearSlotLabel and ns.GearSlotLabel(s) or s }
      end
      return o
    end, function() return opt.slot end, function(v) opt.slot = v end)
    tb:Check(L["Only upgrades"], function() return opt.upgrades end, function(v) opt.upgrades = v end)
    list = tb:List()
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local name = opt.name or Suggested()
    local def
    for _, d in ipairs(DUNGEONS) do if d[1] == name then def = d end end
    local info = Info(name)
    if not info then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local db = ns.SearchDB()
    local level = UnitLevel("player")
    local lvlText = def[4] and L["Raid, level 60"] or string.format(L["Levels %d to %d"], def[2], def[3])
    local fit = def[4] and "" or ((level < def[2] - 2) and (C.RED .. "  " .. L["too high for you yet"] .. "|r") or ((level > def[3] + 3) and (C.GREY .. "  " .. L["below your level"] .. "|r") or (C.GREEN .. "  " .. L["right for your level"] .. "|r")))
    add(0, ns.Icon("INV_Misc_Key_03"), name, lvlText .. fit,
      info.entrance and function() ns.Arrow_Set(info.entrance[1], info.entrance[2], info.entrance[3], name .. " " .. L["entrance"]) end or nil,
      { name, lvlText, info.entrance and (L["Entrance: "] .. ns.ZoneName(info.entrance[1]) .. string.format(" %.0f, %.0f", info.entrance[2], info.entrance[3])) or "",
        C.GREY .. L["Click for an arrow to the entrance."] .. "|r" }, { header = true })

    -- Hunter loot, best first.
    local loot = {}
    for boss, items in pairs(info.bosses) do
      for _, id in ipairs(items) do
        local g = ns.GearItems and ns.GearItems[id]
        if g and (opt.slot == "all" or g[1] == opt.slot) and (not opt.upgrades or g[3] > Worn(g[1])) then
          loot[#loot + 1] = { id = id, boss = boss, score = g[3], slot = g[1], gain = g[3] - Worn(g[1]) }
        end
      end
    end
    table.sort(loot, function(a, b) if a.gain ~= b.gain then return a.gain > b.gain end return a.score > b.score end)
    local seenItem = {}
    add(0, nil, L["Hunter loot"], C.GREY .. L["best upgrades for you first; Alt-click to add to your wishlist"] .. "|r", nil, nil, { header = true })
    local shown = 0
    for _, e in ipairs(loot) do
      if shown >= 20 then break end
      if not seenItem[e.id] then
        seenItem[e.id] = true
        shown = shown + 1
        local it = db.I[e.id]
        local bossName = db.N[e.boss] and db.N[e.boss][1] or "?"
        local gain = e.gain > 0 and (C.GREEN .. "  +" .. e.gain .. "|r") or ""
        add(14, ns.ItemIcon(e.id), ns.QualityColor(e.id) .. it[1] .. "|r" .. gain, C.GREY .. bossName .. "|r",
          ns.ItemClick(e.id), ns.ItemTooltip(e.id), { mid = C.GREY .. (ns.GearSlotLabel and ns.GearSlotLabel(e.slot) or e.slot) .. "|r" })
      end
    end
    if shown == 0 then add(14, nil, C.GREY .. (ns.GearItems and L["No hunter gear found for this dungeon."] or L["No hunter gear data loaded."]) .. "|r") end

    -- Bosses (creatures with gear drops), most loot first.
    local bosses = {}
    for boss, items in pairs(info.bosses) do bosses[#bosses + 1] = { id = boss, n = #items } end
    table.sort(bosses, function(a, b) return a.n > b.n end)
    if #bosses > 0 then
      add(0, nil, L["Who drops gear"], C.GREY .. #bosses .. "|r", nil, nil, { header = true })
      for i = 1, math.min(15, #bosses) do
        local n = db.N[bosses[i].id]
        if n then
          add(14, ns.Icon("Ability_Hunter_SniperShot"), C.WHITE .. n[1] .. "|r", C.GREY .. ns.Count(bosses[i].n, L["item"], L["items"]) .. "|r",
            function() ns.SearchFor(n[1]) end, { n[1], L["Level "] .. (n[2] == n[3] and n[2] or (n[2] .. "-" .. n[3])), C.GREY .. L["Click to search for this name."] .. "|r" },
            { mid = C.GREY .. (n[2] == n[3] and n[2] or (n[2] .. "-" .. n[3])) .. "|r" })
        end
      end
    end

    -- Tameable beasts inside.
    if #info.beasts > 0 then
      add(0, nil, L["Tameable beasts inside"], C.GREY .. #info.beasts .. "|r", nil, nil, { header = true })
      for _, id in ipairs(info.beasts) do
        local b = ns.Beasts[id]
        add(14, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"), C.HUNTER .. b[1] .. "|r",
          #b[6] > 0 and (C.GREY .. L["teaches "] .. ns.TeachesText(b) .. "|r") or (C.GREY .. ns.FamilyLabel(b[4]) .. "|r"),
          ns.BeastClick(id), ns.BeastTooltip(id), { mid = C.GREY .. ns.LevelText(b) .. "|r" })
      end
    end
    list:Set(rows)
  end
  ns.RegisterTab("dungeons", L["Dungeons"], Build, Refresh)
end
