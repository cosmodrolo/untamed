local _, ns = ...

-- Pet leveling helper: zones whose mobs give your pet experience, and experience per hour.

-- Typical mob level range per zone (uiMapID = {min, max}).
local ZONES = {
  [1429] = { 1, 10 }, [1426] = { 1, 10 }, [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1438] = { 1, 10 }, [1420] = { 1, 10 },
  [1436] = { 10, 20 }, [1432] = { 10, 20 }, [1439] = { 10, 20 }, [1413] = { 10, 25 }, [1421] = { 10, 20 },
  [1433] = { 15, 25 }, [1442] = { 15, 27 }, [1440] = { 18, 30 }, [1431] = { 18, 30 }, [1437] = { 20, 30 },
  [1424] = { 20, 30 }, [1441] = { 25, 35 }, [1416] = { 30, 40 }, [1417] = { 30, 40 }, [1443] = { 30, 40 },
  [1434] = { 30, 45 }, [1445] = { 35, 45 }, [1418] = { 35, 45 }, [1435] = { 35, 45 }, [1444] = { 40, 50 },
  [1425] = { 40, 50 }, [1446] = { 40, 50 }, [1427] = { 43, 50 }, [1447] = { 45, 55 }, [1419] = { 45, 55 },
  [1449] = { 48, 55 }, [1448] = { 48, 55 }, [1428] = { 50, 58 }, [1422] = { 51, 58 }, [1423] = { 53, 60 },
  [1452] = { 53, 60 }, [1451] = { 55, 60 }, [1430] = { 55, 60 },
}

-- Highest mob level that gives no experience ("grey") for a given level.
function ns.GreyLevel(level)
  if level <= 5 then return 0 end
  if level < 40 then return level - math.floor(level / 10) - 5 end
  if level < 60 then return level - math.floor(level / 5) - 1 end
  return 48
end

-- Zones where your pet earns experience, best match first.
function ns.LevelingZones(petLevel, playerLevel)
  local lo = ns.GreyLevel(petLevel) + 1
  local hi = math.min(petLevel + 3, playerLevel + 2)
  local out = {}
  for mapID, r in pairs(ZONES) do
    if r[2] >= lo and r[1] <= hi then
      local mid = (r[1] + r[2]) / 2
      local score = math.abs(math.max(r[1], math.min(r[2], petLevel + 1)) - (petLevel + 1)) + math.abs(mid - petLevel) * 0.1
      out[#out + 1] = { mapID = mapID, min = r[1], max = r[2], score = score }
    end
  end
  table.sort(out, function(a, b) return a.score < b.score end)
  return out, lo
end

-- Experience per hour for the pet that is out.
local track = nil   -- { start, gained, lastXP, lastNext, pet }
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "UNIT_PET_EXPERIENCE")
ev:SetScript("OnEvent", function()
  if not GetPetExperience or not UnitExists("pet") then return end
  local xp, nextXP = GetPetExperience()
  if not xp then return end
  local name = UnitName("pet")
  if not track or track.pet ~= name then
    track = { start = GetTime(), gained = 0, lastXP = xp, lastNext = nextXP, pet = name }
    return
  end
  local delta = xp - track.lastXP
  if delta < 0 then delta = (track.lastNext - track.lastXP) + xp end   -- leveled up
  track.gained = track.gained + math.max(0, delta)
  track.lastXP, track.lastNext = xp, nextXP
end)

function ns.PetXPRate()
  if not track or track.gained == 0 then return nil end
  local hours = (GetTime() - track.start) / 3600
  if hours < 1 / 60 then return nil end
  local rate = track.gained / hours
  local xp, nextXP = GetPetExperience()
  local eta = (nextXP and xp and rate > 0) and ((nextXP - xp) / rate * 60) or nil
  return rate, eta
end
