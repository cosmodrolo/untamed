local _, ns = ...
local C = ns.C

-- Trip planner: for each ability your pet can use, find the best rank its level
-- allows, pick the closest tameable beast that teaches it (one beast can cover
-- several), and order the stops by distance with stable and flight masters.

local route = nil   -- { stops = {...}, index = n } while "Start route" is active

local function Tameable(npcId, playerLevel)
  local b = ns.Beasts[npcId]
  return b and b[2] <= playerLevel
end

function ns.BuildTrip(t)
  local playerLevel = UnitLevel("player")
  local planLevel = ns.db.planForPlayerLevel and playerLevel or t.level or playerLevel
  local trip = { goals = {}, teach = {}, stops = {}, skipped = {}, planLevel = planLevel, tpNeed = 0 }
  for _, e in ipairs(ns.Plan(t.family, planLevel, t.known)) do
    local fa = ns.ForeverAbilities and ns.ForeverAbilities[e.ability]
    if ns.cdb.plan[e.ability] ~= false and not (fa and fa.source == "innate") then
      local best
      for _, r in ipairs(e.ranks) do
        if not r.tooHigh then
          local ok = r.known
          if not ok then for _, id in ipairs(r.beasts) do if Tameable(id, playerLevel) then ok = true break end end end
          if ok then best = r end
        end
      end
      if best then
        local cost = ns.RankCost(e.ability, best.rank)
        local curCost = e.current > 0 and ns.RankCost(e.ability, e.current) or 0
        if cost then trip.tpNeed = trip.tpNeed + math.max(0, cost - (curCost or 0)) end
        local g = { ability = e.ability, rank = best.rank, known = best.known }
        if best.known then
          trip.teach[#trip.teach + 1] = g
        else
          g.beasts = {}
          for _, id in ipairs(best.beasts) do if Tameable(id, playerLevel) then g.beasts[#g.beasts + 1] = id end end
          trip.goals[#trip.goals + 1] = g
        end
      elseif #e.ranks > 0 and not e.ranks[1].tooHigh then
        trip.skipped[#trip.skipped + 1] = e.ability
      end
    end
  end

  -- Choose beasts: greedy, prefer a beast covering the most goals, then the closest.
  local pc, pe, pn = ns.PlayerWorld()
  local open = {}
  for _, g in ipairs(trip.goals) do open[g] = true end
  local distCache = {}
  local function dist(id)
    if distCache[id] == nil then
      local _, _, _, d = ns.NearestSpawn(id, pc, pe, pn)
      distCache[id] = d or 1e9
    end
    return distCache[id]
  end
  while next(open) do
    local cover = {}
    for g in pairs(open) do
      for _, id in ipairs(g.beasts) do cover[id] = cover[id] or {}; table.insert(cover[id], g) end
    end
    local bestId, bestN, bestD
    for id, gs in pairs(cover) do
      local d = dist(id)
      if not bestId or #gs > bestN or (#gs == bestN and d < bestD) then bestId, bestN, bestD = id, #gs, d end
    end
    if not bestId then break end
    local stop = { npcId = bestId, goals = cover[bestId] }
    for _, g in ipairs(stop.goals) do open[g] = nil end
    trip.stops[#trip.stops + 1] = stop
  end

  -- Order stops: nearest neighbour from where you stand; other continents last.
  local ordered, cc, ce, cn = {}, pc, pe, pn
  local remaining = {}
  for _, s in ipairs(trip.stops) do remaining[#remaining + 1] = s end
  while #remaining > 0 do
    local bi, bd, bm, bx, by
    for i, s in ipairs(remaining) do
      local m, x, y, d = ns.NearestSpawn(s.npcId, cc, ce, cn)
      d = d or 1e9
      if not bi or d < bd then bi, bd, bm, bx, by = i, d, m, x, y end
    end
    local s = table.remove(remaining, bi)
    s.mapID, s.x, s.y, s.dist = bm, bx, by, bd < 1e9 and bd or nil
    if bm then
      s.stable, s.stableD = ns.NearestService("S", bm, bx, by)
      s.flight, s.flightD = ns.NearestService("F", bm, bx, by)
      local c2, e2, n2 = ns.ToWorld(bm, bx, by)
      if c2 then cc, ce, cn = c2, e2, n2 end
    end
    ordered[#ordered + 1] = s
  end
  trip.stops = ordered
  return trip
end

local function GoalsText(goals)
  local t = {}
  for _, g in ipairs(goals) do t[#t + 1] = g.ability .. " " .. g.rank end
  return table.concat(t, ", ")
end

local function NavigateStop(s)
  local b = ns.Beasts[s.npcId]
  if s.mapID then ns.Arrow_Set(s.mapID, s.x, s.y, b[1] .. " (" .. GoalsText(s.goals) .. ")", s.npcId) end
  ns.Pins_Focus({ s.npcId }, b[1], false)
end

local function StartRoute(trip)
  if #trip.stops == 0 then ns.Print("Nothing to travel for right now.") return end
  route = { stops = trip.stops, index = 1 }
  NavigateStop(route.stops[1])
  ns.Print("Route started: stop 1 of " .. #route.stops .. ". It moves on when you learn the ability.")
end

ns.On("LEARNED", function(ability, rank)
  if not route then return end
  local s = route.stops[route.index]
  if not s then return end
  for _, g in ipairs(s.goals) do
    if g.ability == ability and rank >= g.rank then g.done = true end
  end
  for _, g in ipairs(s.goals) do if not g.done then return end end
  route.index = route.index + 1
  local nxt = route.stops[route.index]
  if nxt then
    ns.Print("Stop done. Next: " .. ns.Beasts[nxt.npcId][1] .. ". Abandon the tamed beast and get your pet back from a stable master when you're ready.")
    NavigateStop(nxt)
  else
    ns.Print("Route complete! Get your pet from a stable master and teach it everything at Beast Training.")
    route = nil
    ns.Arrow_Clear()
  end
end)

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local list, lastTrip

local function Build(panel)
  ns.MakeButton(panel, "Start Route", 110, function() if lastTrip then StartRoute(lastTrip) end end):SetPoint("TOPLEFT", 4, -2)
  ns.MakeButton(panel, "Pin All Stops", 110, function()
    if not lastTrip then return end
    local ids = {}
    for _, s in ipairs(lastTrip.stops) do ids[#ids + 1] = s.npcId end
    if #ids > 0 then ns.Pins_Focus(ids, "Trip planner stops", true) end
  end):SetPoint("TOPLEFT", 118, -2)
  ns.MakeButton(panel, "Stop Route", 100, function() route = nil; ns.Arrow_Clear() end):SetPoint("TOPLEFT", 232, -2)
  ns.MakeCheck(panel, "Plan for my level", 340, -2,
    function() return ns.db.planForPlayerLevel end, function(v) ns.db.planForPlayerLevel = v end,
    "Plan ranks for your own level instead of your pet's current level (your pet will level up to use them).")
  list = ns.NewList(panel, 30)
end

local function Refresh(panel, t)
  local rows = {}
  local function add(...) rows[#rows + 1] = { ... } end
  if not t then
    add(0, nil, C.GREY .. "Summon your pet or pick a family to plan a trip.|r")
    list:Set(rows)
    return
  end
  local trip = ns.BuildTrip(t)
  lastTrip = trip
  local tpFree = t.tpFree
  add(0, ns.Icon("Ability_Hunter_BeastTaming"),
    string.format("%sTrip for your %s|r (ranks up to pet level %d)", C.GOLD, t.family, trip.planLevel),
    string.format("%s%d stop%s|r", C.WHITE, #trip.stops, #trip.stops == 1 and "" or "s"))
  add(14, nil, string.format("Training points needed: about %d%s", trip.tpNeed,
    tpFree and string.format("   (%s%d free now|r)", tpFree >= trip.tpNeed and C.GREEN or C.ORANGE, tpFree) or ""), "", nil,
    { "Training points", "Estimated from rank costs. Your pet earns more training points as it levels and as its loyalty grows." })
  add(14, nil, C.GREY .. "Before each tame: stable your pet. After you learn the ability, abandon the tamed beast and take your pet back.|r", "", nil,
    { "How taming for abilities works", "You can only have one pet out. Stable your pet at a stable master (or keep a free stable slot), tame the beast, fight with it until you see \"You have learned a new ability\", then abandon it and get your pet back. Teach the new rank at Beast Training." })

  if #trip.teach > 0 then
    add(0, nil, C.GOLD .. "Teach now at Beast Training|r")
    for _, g in ipairs(trip.teach) do
      local tp = ns.RankCost(g.ability, g.rank)
      add(14, ns.Icon(ns.AbilityIcons[g.ability] or "Ability_Hunter_BeastTraining"), C.GREEN .. g.ability .. " Rank " .. g.rank .. "|r",
        tp and (C.GREY .. tp .. " TP|r") or "")
    end
  end

  if #trip.stops > 0 then
    add(0, nil, C.GOLD .. "Stops (closest first)|r")
    for i, s in ipairs(trip.stops) do
      local b = ns.Beasts[s.npcId]
      local current = route and route.stops[route.index] and route.stops[route.index].npcId == s.npcId
      add(4, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
        string.format("%s%d. %s|r %s", current and C.GREEN or C.WHITE, i, b[1], C.GREY .. ns.LevelText(b) .. "|r"),
        C.HUNTER .. GoalsText(s.goals) .. "|r",
        function(_, button)
          if button == "RightButton" then ns.Pins_Focus({ s.npcId }, b[1], true) else NavigateStop(s) end
        end, ns.BeastTooltip(s.npcId, { C.HUNTER .. "For your pet: " .. GoalsText(s.goals) .. "|r" }))
      add(26, nil, C.GREY .. (s.mapID and (ns.ZoneNames[s.mapID] or "?") .. string.format(" %.0f, %.0f", s.x, s.y) or "location unknown") .. "|r",
        C.GREY .. (s.dist and ns.FormatDistance(s.dist) or "") .. "|r")
      if s.stable then
        add(26, ns.Icon("Ability_Hunter_BeastCall"), C.BLUE .. "Stable: " .. s.stable[2] .. ", " .. (ns.ZoneNames[s.stable[4]] or "?") .. "|r",
          C.GREY .. ns.FormatDistance(s.stableD) .. "|r", function() ns.Arrow_Set(s.stable[4], s.stable[5], s.stable[6], "Stable: " .. s.stable[2]) end,
          { "Nearest stable master", "Closest stable master to this beast for your faction. Click for an arrow." })
      end
      if s.flight then
        add(26, ns.Icon("Ability_Mount_Gryphon_01"), C.BLUE .. "Fly: " .. s.flight[2] .. ", " .. (ns.ZoneNames[s.flight[4]] or "?") .. "|r",
          C.GREY .. ns.FormatDistance(s.flightD) .. "|r", function() ns.Arrow_Set(s.flight[4], s.flight[5], s.flight[6], "Flight: " .. s.flight[2]) end,
          { "Nearest flight master", "Closest flight master to this beast for your faction. Click for an arrow." })
      end
    end
  elseif #trip.teach == 0 then
    add(0, nil, C.GREEN .. "Nothing to learn right now. Your pet is up to date for its level.|r")
  end

  if #trip.skipped > 0 then
    add(0, nil, C.ORANGE .. "No tameable beast yet for: " .. table.concat(trip.skipped, ", ") .. "|r")
  end

  add(0, nil, C.GOLD .. "Abilities in this plan|r", C.GREY .. "click to include or skip|r")
  for _, ab in ipairs(ns.AbilityOrder) do
    local fams = ns.AbilityFamilies[ab]
    if fams and fams[t.family] then
      local on = ns.cdb.plan[ab] ~= false
      add(14, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTaming"), (on and C.WHITE .. "[x] " or C.GREY .. "[  ] ") .. ab .. "|r", "",
        function() if on then ns.cdb.plan[ab] = false else ns.cdb.plan[ab] = nil end; ns.UI_Refresh() end)
    end
  end
  list:Set(rows)
end

ns.RegisterTab("plan", "Planner", Build, Refresh)
