local _, ns = ...
local L = ns.L
local C = ns.C

-- Trip planner: for each ability your pet can use, find the best rank its level
-- allows, pick the closest tameable beast that teaches it (one beast can cover
-- several), and order the stops by distance with stable and flight masters.

local route = nil   -- { stops = {...}, index = n } while L["Start route"] is active

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

  -- The full route: stable your pet first (only one pet can be out), then each beast,
  -- then take your pet back from the stable master nearest the last beast.
  trip.route = {}
  local petOut = not t.manual and ns.HasActivePet()
  if #ordered > 0 and petOut then
    local first = ordered[1]
    local best, bestCost, bestD
    local fac = ns.PlayerFaction()
    local fc, fe, fn
    if first.mapID then fc, fe, fn = ns.ToWorld(first.mapID, first.x, first.y) end
    for _, sv in ipairs(ns.Services) do
      if sv[1] == "S" and (sv[3] == "AH" or sv[3]:find(fac, 1, true)) then
        local sc, se, sn = ns.ToWorld(sv[4], sv[5], sv[6])
        local d1 = ns.Distance(pc, pe, pn, sc, se, sn)
        local d2 = ns.Distance(sc, se, sn, fc, fe, fn)
        local cost = (d1 or 50000) + (d2 or 50000)
        if not bestCost or cost < bestCost then best, bestCost, bestD = sv, cost, d1 end
      end
    end
    if best then trip.route[#trip.route + 1] = { kind = "stable", service = best, dist = bestD } end
  end
  for _, st in ipairs(ordered) do st.kind = "beast"; trip.route[#trip.route + 1] = st end
  if #ordered > 0 and petOut then
    local last = ordered[#ordered]
    if last.stable then trip.route[#trip.route + 1] = { kind = "return", service = last.stable, dist = last.stableD } end
  end
  return trip
end

local function GoalsText(goals)
  local t = {}
  for _, g in ipairs(goals) do t[#t + 1] = ns.AbilityLabel(g.ability) .. " " .. g.rank end
  return table.concat(t, ", ")
end

local function NavigateStop(s)
  if s.kind == "stable" or s.kind == "return" then
    local sv = s.service
    ns.Arrow_Set(sv[4], sv[5], sv[6], (s.kind == "stable" and "Stable your pet: " or "Get your pet back: ") .. sv[2])
    if s.kind == "stable" then
      ns.Print(L["First stop: stable your pet with "] .. sv[2] .. " in " .. ns.ZoneName(sv[4]) .. ". You can only tame with no pet out.")
    else
      ns.Print(L["Last stop: abandon the tamed beast, then take your pet back from "] .. sv[2] .. " in " .. ns.ZoneName(sv[4]) .. ".")
    end
    return
  end
  local b = ns.Beasts[s.npcId]
  if s.mapID then ns.Arrow_Set(s.mapID, s.x, s.y, b[1] .. " (" .. GoalsText(s.goals) .. ")", s.npcId) end
  ns.Pins_Focus({ s.npcId }, b[1], false)
end

local function Advance(msg)
  if not route then return end
  route.index = route.index + 1
  local nxt = route.stops[route.index]
  if nxt then
    if msg then ns.Print(msg) end
    NavigateStop(nxt)
  else
    ns.Print(L["Route complete! Teach your pet its new ranks at Beast Training."])
    route = nil
    ns.Arrow_Clear()
  end
  ns.Refresh()
end

local function StartRoute(trip)
  if #trip.route == 0 then ns.Print(L["Nothing to travel for right now."]) return end
  route = { stops = trip.route, index = 1 }
  NavigateStop(route.stops[1])
  ns.Print(L["Route started: "] .. #route.stops .. " stops. It moves on by itself as you go.")
end

function ns.Route_Next()
  if route then Advance(L["Skipped to the next stop."]) else ns.Print(L["No route running. Start one from the Planner tab."]) end
end

ns.On("LEARNED", function(ability, rank)
  if not route then return end
  local s = route.stops[route.index]
  if not s or s.kind ~= "beast" then return end
  for _, g in ipairs(s.goals) do
    if g.ability == ability and rank >= g.rank then g.done = true end
  end
  for _, g in ipairs(s.goals) do if not g.done then return end end
  local nxt = route.stops[route.index + 1]
  if nxt and nxt.kind == "beast" then
    Advance(L["Learned it! Abandon the tamed beast (right-click its portrait), then head to "] .. ns.Beasts[nxt.npcId][1] .. ".")
  else
    Advance(L["Learned it!"])
  end
end)

-- Stable steps finish when you close the stable window in the right state.
ns.On("STABLE_CLOSED", function()
  if not route then return end
  local s = route.stops[route.index]
  if not s then return end
  if s.kind == "stable" and not UnitExists("pet") then
    ns.cdb.hasActivePet = false
    Advance(L["Pet stabled. On to the first beast!"])
  elseif s.kind == "return" and UnitExists("pet") then
    Advance(nil)
  end
end)

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local list, lastTrip

local function Build(panel)
  ns.MakeButton(panel, L["Start Route"], 110, function() if lastTrip then StartRoute(lastTrip) end end):SetPoint("TOPLEFT", 4, -2)
  ns.MakeButton(panel, L["Pin All Stops"], 110, function()
    if not lastTrip then return end
    local ids = {}
    for _, s in ipairs(lastTrip.stops) do ids[#ids + 1] = s.npcId end
    if #ids > 0 then ns.Pins_Focus(ids, L["Trip planner stops"], true) end
  end):SetPoint("TOPLEFT", 118, -2)
  ns.MakeButton(panel, L["Next Stop"], 90, function() ns.Route_Next() end):SetPoint("TOPLEFT", 232, -2)
  ns.MakeButton(panel, L["Stop Route"], 90, function() route = nil; ns.Arrow_Clear(); ns.Refresh() end):SetPoint("TOPLEFT", 326, -2)
  ns.MakeCheck(panel, L["Plan for my level"], 424, -2,
    function() return ns.db.planForPlayerLevel end, function(v) ns.db.planForPlayerLevel = v end,
    L["Plan ranks for your own level instead of your pet's current level (your pet will level up to use them)."])
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
    string.format("%s%d stop%s|r", C.WHITE, #trip.stops, #trip.stops == 1 and "" or "s"), nil, nil, { header = true })
  add(14, nil, string.format("Training points needed: about %d%s", trip.tpNeed,
    tpFree and string.format("   (%s%d free now|r)", tpFree >= trip.tpNeed and C.GREEN or C.ORANGE, tpFree) or ""), "", nil,
    { L["Training points"], L["Estimated from rank costs. Your pet earns more training points as it levels and as its loyalty grows."] })
  add(14, nil, C.GREY .. "The route stables your pet first, then each beast, then brings you back for your pet.|r", "", nil,
    { L["How taming for abilities works"], "You can only have one pet out. Stable your pet at a stable master (or keep a free stable slot), tame the beast, fight with it until you see \"You have learned a new ability\", then abandon it and get your pet back. Teach the new rank at Beast Training." })

  if #trip.teach > 0 then
    add(0, nil, L["Teach now at Beast Training"], "", nil, nil, { header = true })
    for _, g in ipairs(trip.teach) do
      local tp = ns.RankCost(g.ability, g.rank)
      add(14, ns.Icon(ns.AbilityIcons[g.ability] or "Ability_Hunter_BeastTraining"), C.GREEN .. g.ability .. " Rank " .. g.rank .. "|r",
        tp and (C.GREY .. tp .. " TP|r") or "")
    end
  end

  if #trip.stops > 0 then
    add(0, nil, L["Route (closest first)"], route and (C.GREEN .. "running: stop " .. route.index .. " of " .. #route.stops .. "|r") or "", nil, nil, { header = true })
    local n = 0
    for _, s in ipairs(trip.route) do
      n = n + 1
      local current = route and route.stops[route.index] and route.stops[route.index].kind == s.kind
        and (s.kind ~= "beast" or route.stops[route.index].npcId == s.npcId)
      local numColor = current and C.GREEN or C.WHITE
      if s.kind == "stable" or s.kind == "return" then
        local sv = s.service
        local label = s.kind == "stable" and "Stable your pet" or "Abandon the tamed beast and take your pet back"
        add(4, ns.Icon("Ability_Hunter_BeastCall"), string.format("%s%d. %s|r", numColor, n, label),
          C.BLUE .. sv[2] .. ", " .. ns.ZoneName(sv[4]) .. "|r",
          function() NavigateStop(s) end,
          { label, sv[2] .. " (Stable Master), " .. ns.ZoneName(sv[4]) .. string.format(" %.0f, %.0f", sv[5], sv[6]),
            s.kind == "stable" and "You can't tame while you have a pet, even a dismissed one. This stable master is the best stop on the way to your first beast."
              or L["When you're done learning, abandon the last tamed beast and collect your pet here."],
            L["Click for an arrow."] })
        if s.dist then add(26, nil, C.GREY .. ns.FormatDistance(s.dist) .. " from you|r", "") end
      else
        local b = ns.Beasts[s.npcId]
        add(4, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"),
          string.format("%s%d. %s|r", numColor, n, b[1]),
          C.HUNTER .. GoalsText(s.goals) .. "|r",
          function(_, button)
            if button == "RightButton" then ns.Pins_Focus({ s.npcId }, b[1], true) else NavigateStop(s) end
          end, ns.BeastTooltip(s.npcId, { C.HUNTER .. L["For your pet: "] .. GoalsText(s.goals) .. "|r" }),
          { mid = C.GREY .. ns.LevelText(b) .. "|r" })
        add(26, nil, C.GREY .. (s.mapID and ns.ZoneName(s.mapID) .. string.format(" %.0f, %.0f", s.x, s.y) or "location unknown") .. "|r",
          C.GREY .. (s.dist and ns.FormatDistance(s.dist) or "") .. "|r")
        if s.flight then
          add(26, ns.Icon("Ability_Mount_Gryphon_01"), C.BLUE .. L["Fly: "] .. s.flight[2] .. ", " .. ns.ZoneName(s.flight[4]) .. "|r",
            C.GREY .. ns.FormatDistance(s.flightD) .. "|r", function() ns.Arrow_Set(s.flight[4], s.flight[5], s.flight[6], L["Flight: "] .. s.flight[2]) end,
            { L["Nearest flight master"], L["Closest flight master to this beast for your faction. Click for an arrow."] })
        end
      end
    end
  elseif #trip.teach == 0 then
    add(0, nil, C.GREEN .. "Nothing to learn right now. Your pet is up to date for its level.|r")
  end

  if #trip.skipped > 0 then
    add(0, nil, C.ORANGE .. L["No tameable beast yet for: "] .. table.concat(trip.skipped, ", ") .. "|r")
  end

  add(0, nil, L["Abilities in this plan"], C.GREY .. L["click to include or skip"] .. "|r", nil, nil, { header = true })
  for _, ab in ipairs(ns.AbilityOrder) do
    local fams = ns.AbilityFamilies[ab]
    if fams and fams[t.family] then
      local on = ns.cdb.plan[ab] ~= false
      add(14, ns.Icon(ns.AbilityIcons[ab] or "Ability_Hunter_BeastTaming"), (on and C.WHITE or C.GREY) .. ns.AbilityLabel(ab) .. "|r",
        on and (C.GREEN .. L["included"] .. "|r") or (C.GREY .. L["skipped"] .. "|r"),
        function() if on then ns.cdb.plan[ab] = false else ns.cdb.plan[ab] = nil end; ns.UI_Refresh() end)
    end
  end
  list:Set(rows)
end

ns.RegisterTab("plan", L["Planner"], Build, Refresh)
