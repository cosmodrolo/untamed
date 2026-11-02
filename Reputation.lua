local _, ns = ...
local L = ns.L
local C = ns.C

-- Reputation tracker: every faction with hunter rewards, your standing, what each rank unlocks,
-- and how to earn it. Rewards come from the search index (vendor reputation and item requirements).

local HOW = {
  [529] = "Kill undead in the Plaguelands and turn in Scourgestones at Light's Hope Chapel.",
  [609] = "Do Silithus quests, kill Twilight cultists and turn in their texts at Cenarion Hold.",
  [59] = "Turn in Dark Iron ore, fiery cores and lava cores to Lokhtos Darkbargainer in Blackrock Depths.",
  [576] = "Kill Deadwood (Felwood) and Winterfall (Winterspring) furbolgs and turn in their feathers and beads.",
  [270] = "Kill trolls in Zul'Gurub and turn in coins and bijous at Yojamba Isle.",
  [749] = "Do the Hydraxian quests in Azshara, then clear Molten Core.",
  [910] = "Kill bosses in the Temple of Ahn'Qiraj.",
  [889] = "Win and capture flags in Warsong Gulch.", [890] = "Win and capture flags in Warsong Gulch.",
  [729] = "Play Alterac Valley and turn in its quests.", [730] = "Play Alterac Valley and turn in its quests.",
  [509] = "Win and hold bases in Arathi Basin.", [510] = "Win and hold bases in Arathi Basin.",
  [87] = "Kill Booty Bay and other Steamwheedle goblins (this lowers your standing with them).",
  [809] = "Turn in librams and Dire Maul books at the Shen'dralar in Dire Maul.",
  [21] = "Do Steamwheedle quests and kill Bloodsail pirates.", [369] = "Do Steamwheedle quests and kill Bloodsail pirates.",
  [470] = "Do Steamwheedle quests and kill Bloodsail pirates.", [577] = "Do Steamwheedle quests and kill Bloodsail pirates.",
}
local SIDE = { [889] = "H", [729] = "H", [510] = "H", [76] = "H", [81] = "H", [530] = "H", [68] = "H",
  [890] = "A", [730] = "A", [509] = "A", [72] = "A", [47] = "A", [69] = "A", [54] = "A" }

-- [faction] = { [rank] = { itemIds } } for your side.
local cache
local function Rewards()
  if cache then return cache end
  local db = ns.SearchDB and ns.SearchDB()
  if not db then return {} end
  local side = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
  local out = {}
  local function add(fac, rank, id)
    if SIDE[fac] and SIDE[fac] ~= side then return end
    out[fac] = out[fac] or {}
    out[fac][rank] = out[fac][rank] or {}
    for _, x in ipairs(out[fac][rank]) do if x == id then return end end
    table.insert(out[fac][rank], id)
  end
  for id, it in pairs(db.I) do
    if (it[13] or 1) >= 2 or it[4] == 6 or it[4] == 11 then
      if (it[20] or 0) > 0 then add(it[20], it[21], id) end
      for _, e in ipairs(it[22] or {}) do
        for k = 2, #e - 1, 2 do add(e[k], e[k + 1], id) end
      end
    end
  end
  cache = out
  return out
end

local function Standing(fac)
  if not GetFactionInfoByID then return nil end
  local ok, name, _, standingID, barMin, barMax, barValue = pcall(GetFactionInfoByID, fac)
  if not ok or not name then return nil end
  return name, standingID and standingID - 1, barMin, barMax, barValue
end

do
  local list
  local opt = { onlyGear = true, fac = "all" }
  local function FactionOptions()
    local o = { { "all", L["All factions"] } }
    local names = {}
    for fac in pairs(Rewards()) do
      local name = GetFactionInfoByID and GetFactionInfoByID(fac)
      names[#names + 1] = { fac, (type(name) == "string" and name ~= "") and name or ("Faction " .. fac) }
    end
    table.sort(names, function(a, b) return a[2] < b[2] end)
    for _, n in ipairs(names) do o[#o + 1] = n end
    return o
  end
  local function Build(panel)
    local tb = ns.Toolbar(panel)
    tb:Dropdown(210, FactionOptions, function() return opt.fac end, function(v) opt.fac = v end)
    tb:Check(L["Only gear I can use"], function() return opt.onlyGear end, function(v) opt.onlyGear = v end)
    list = tb:List()
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local db = ns.SearchDB and ns.SearchDB()
    if not db then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local level = UnitLevel("player")
    local rewards = Rewards()
    local facs = {}
    for fac, ranks in pairs(rewards) do
      local best, count = 0, 0
      for _, ids in pairs(ranks) do
        for _, id in ipairs(ids) do
          local g = ns.GearItems and ns.GearItems[id]
          local usable = g and ns.CanUseItem(db.I[id], 60)
          if not opt.onlyGear or usable then
            count = count + 1
            if g then best = math.max(best, g[3] - (ns.GearWornScore and ns.GearWornScore(g[1]) or 0)) end
          end
        end
      end
      if count > 0 and (opt.fac == "all" or opt.fac == fac) then facs[#facs + 1] = { fac = fac, best = best, count = count } end
    end
    table.sort(facs, function(a, b) return a.best > b.best end)
    if #facs == 0 then add(0, nil, C.GREY .. L["No reputation rewards found."] .. "|r") end
    for _, f in ipairs(facs) do
      local name, mine, barMin, barMax, barValue = Standing(f.fac)
      name = name or ("Faction " .. f.fac)
      local standing = mine and (_G["FACTION_STANDING_LABEL" .. (mine + 1)] or tostring(mine)) or L["not met yet"]
      local progress = (barMax and barMin and barMax > barMin) and string.format("  %d/%d", (barValue or 0) - barMin, barMax - barMin) or ""
      add(0, ns.Icon("INV_Misc_Token_ArgentDawn"), name, C.WHITE .. standing .. "|r" .. C.GREY .. progress .. "|r", nil,
        { name, L["Your standing: "] .. standing .. progress, HOW[f.fac] and (L["How to earn it: "] .. L[HOW[f.fac]]) or "" }, { header = true })
      if HOW[f.fac] then add(14, nil, C.GREY .. L[HOW[f.fac]] .. "|r") end
      local ranks = {}
      for r in pairs(rewards[f.fac]) do ranks[#ranks + 1] = r end
      table.sort(ranks)
      for _, r in ipairs(ranks) do
        local ids = {}
        for _, id in ipairs(rewards[f.fac][r]) do
          local g = ns.GearItems and ns.GearItems[id]
          if not opt.onlyGear or (g and ns.CanUseItem(db.I[id], 60)) then ids[#ids + 1] = id end
        end
        table.sort(ids, function(a, b)
          local ga, gb = ns.GearItems and ns.GearItems[a], ns.GearItems and ns.GearItems[b]
          return (ga and ga[3] or 0) > (gb and gb[3] or 0)
        end)
        local met = mine and mine >= r
        for i = 1, math.min(6, #ids) do
          local id = ids[i]
          local it = db.I[id]
          local g = ns.GearItems and ns.GearItems[id]
          local gain = g and (g[3] - (ns.GearWornScore and ns.GearWornScore(g[1]) or 0)) or 0
          local rankName = _G["FACTION_STANDING_LABEL" .. (r + 1)] or tostring(r)
          add(28, ns.ItemIcon(id), ns.QualityColor(id) .. it[1] .. "|r" .. (gain > 0 and (C.GREEN .. "  +" .. gain .. "|r") or ""),
            (met and C.GREEN or C.ORANGE) .. rankName .. "|r", ns.ItemClick(id), ns.ItemTooltip(id),
            { mid = ((it[3] > level) and C.RED or C.GREY) .. L["lvl "] .. it[3] .. "|r" })
        end
      end
    end
    list:Set(rows)
  end
  ns.RegisterTab("reputation", L["Reputation"], Build, Refresh)
end

ns.RepTest = { Rewards = Rewards }
