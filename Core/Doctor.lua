local _, ns = ...
local C = ns.C

---------------------------------------------------------------------------
-- /ut doctor: a self-check you can run in game. It asks the game for the things Untamed relies
-- on and prints what came back, so a part that quietly gets no answer on this client shows up
-- as a red line instead of as a feature that silently does nothing. (English only: it's a
-- report to send along when something looks off.)
---------------------------------------------------------------------------

local function Line(ok, what, detail)
  local mark = (ok == nil and (C.GREY .. "?  ")) or (ok and (C.GREEN .. "ok ")) or (C.RED .. "NO ")
  ns.Print(mark .. "|r" .. what .. (detail and (C.GREY .. "  " .. tostring(detail) .. "|r") or ""))
end

local function Try(f, ...)
  if not f then return false, "function missing" end
  local ok, a, b = pcall(f, ...)
  if not ok then return false, "error: " .. tostring(a) end
  if ns.IsSecret(a) then return nil, "hidden by the game right now" end
  return true, a, b
end

-- How much memory Untamed holds right now, in MB (nil if the game won't say).
function ns.MemoryMB()
  local name = "Untamed"
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    local ok, kb = pcall(function() UpdateAddOnMemoryUsage(); return GetAddOnMemoryUsage(name) end)
    if ok and type(kb) == "number" and not ns.IsSecret(kb) and kb > 0 then return kb / 1024 end
  end
  return nil
end

function ns.MemoryReport()
  local mb = ns.MemoryMB()
  local loaded = ns.SearchDBLoaded and ns.SearchDBLoaded() and true or false
  ns.Print(mb and string.format("Untamed is using %.1f MB of memory.", mb) or "The game didn't say how much memory Untamed uses (try /ut mem again out of a fight).")
  ns.Print(C.GREY .. (loaded and "The item and NPC search data is loaded (the biggest part; it loads the first time a page or alert needs it)."
    or "The item and NPC search data isn't loaded yet (it loads the first time a page or alert needs it, and is the biggest part).") .. "|r")
end

function ns.Doctor()
  local build, iface = "?", "?"
  if GetBuildInfo then local _, b, _, i = GetBuildInfo(); build, iface = tostring(b), tostring(i) end
  ns.Print(C.GOLD .. "Untamed self-check|r  (interface " .. iface .. ", build " .. build .. ")")

  -- the pet's own abilities
  local pet = ns.ScanPet and ns.ScanPet()
  if pet then
    local n, parts = 0, {}
    for name, rank in pairs(pet.known) do n = n + 1; if #parts < 6 then parts[#parts + 1] = name .. " " .. rank end end
    Line(n > 0, "Pet spellbook read", n .. " abilities: " .. table.concat(parts, ", "))
    Line(pet.tpFree ~= nil, "Pet training points", pet.tpFree)
  else
    Line(nil, "Pet spellbook", "no pet out")
  end

  if ns.TalentRankOf then
    local fr, frMax = ns.TalentRankOf("Frenzy")
    local fe = ns.TalentRankOf("Ferocity")
    Line(fr ~= nil and fr > 0 or (fr == nil and nil) or false, "Frenzy talent", fr and (fr .. " of " .. tostring(frMax or 5) .. " points (Ferocity " .. tostring(fe or "?") .. ")") or "could not read the talent tree")
  end

  -- spells you know
  local known, total = 0, 0
  for _, name in ipairs({ "Auto Shot", "Serpent Sting", "Hunter's Mark", "Raptor Strike", "Aspect of the Hawk" }) do
    total = total + 1
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
    if info and ns.SpellKnown(info.spellID) then known = known + 1 end
  end
  Line(known > 0, "Spells you know", known .. " of " .. total .. " basic hunter spells recognized")

  -- range checks (need an enemy targeted)
  if UnitExists("target") then
    local ok, r = Try(C_Spell and C_Spell.IsSpellInRange, "Auto Shot", "target")
    Line(ok and r ~= nil, "Range check: Auto Shot", ok and tostring(r) or r)
    local okH, has = Try(C_Spell and C_Spell.SpellHasRange, "Raptor Strike")
    Line(okH, "Melee spell has its own range", okH and tostring(has) or has)
    for _, name in ipairs({ "Auto Shot", "Raptor Strike", "Wing Clip" }) do
      local info = C_Spell.GetSpellInfo(name)
      if info then
        local _, inr = Try(C_Spell.IsSpellInRange, name, "target")
        Line(nil, "  " .. name, "min " .. tostring(info.minRange) .. ", max " .. tostring(info.maxRange) .. ", in range: " .. tostring(inr))
      end
    end
    local barCheck = (C_ActionBar and C_ActionBar.IsActionInRange) or IsActionInRange
    for _, slot in ipairs(ns.RangeMeleeSlotList and ns.RangeMeleeSlotList() or {}) do
      local _, r = Try(barCheck, slot, "target")
      Line(nil, "  Bar slot " .. slot .. " in range", tostring(r))
    end
    local zone, lo, hi = ns.RangeToTarget()
    Line(zone ~= nil, "Range meter says", zone and (zone .. "  " .. ns.RangeYards(lo, hi)) or "nothing")
  else
    Line(nil, "Range checks", "target an enemy and run it again")
  end
  local slots = ns.RangeMeleeSlotList and ns.RangeMeleeSlotList() or {}
  Line(#slots > 0, "Melee button on your bars", #slots > 0 and ("slot " .. table.concat(slots, ", ")) or "none found (put Raptor Strike or the Rapt macro on a bar)")

  -- pet damage window (Blizzard's damage meter)
  local okM, avail = Try(C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable)
  Line(okM and avail == true, "Damage meter for addons", okM and tostring(avail) or tostring(avail))
  local split = ns.PetMeterSplit and ns.PetMeterSplit("Current")
  Line(split ~= nil or nil, "Pet damage split (last fight)", split and (#split.parts .. " parts, " .. split.total .. " damage") or "none yet (or secret in a fight)")
  if ns.petMeterLive then Line(ns.petMeterLive == "numbers", "Pet damage live numbers", ns.petMeterLive) end
  if ns.petMeterError then Line(false, "Pet damage window error", ns.petMeterError) end

  -- auras
  local okA = Try(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID, 13165)
  Line(okA, "Aura lookup (aspects)")

  -- map and world positions
  local map = C_Map.GetBestMapForUnit("player")
  local spots = map and ns.ChestSpotsOn and ns.ChestSpotsOn(map)
  Line(spots ~= nil and #spots > 0, "Chest spots on this map", spots and (#spots / 3) or 0)
  local pc = ns.PlayerWorld and ns.PlayerWorld()
  Line(pc ~= nil, "Your world position", pc and "ok" or "not given (indoors?)")
  local okV, list = Try(C_VignetteInfo and C_VignetteInfo.GetVignettes)
  Line(okV, "Minimap marks (rares)", okV and (#list .. " right now") or list)
  local okS = Try(UnitExists, "softinteract")
  Line(okS, "Interact target (chest right here)")

  -- books, quests, items
  local okQ, ids = Try(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
  Line(okQ and type(ids) == "table", "Completed quests list (library books)", okQ and type(ids) == "table" and (#ids .. " quests") or ids)
  if ns.BooksCount then
    local done, bags = ns.BooksCount()
    Line(true, "Library books", done .. " handed in, " .. bags .. " in your bags")
  end
  local okI = Try(C_Item and C_Item.GetItemStats, "item:2504")
  Line(okI, "Item stats (gear the list doesn't know)")

  -- other addons
  Line(_G.OpenMapAPI ~= nil, "OpenMap", _G.OpenMapAPI and "connected" or "not loaded")
  Line(_G.ForeverDungeonJournal_NS ~= nil, "Dungeon Journal (loot card)", _G.ForeverDungeonJournal_NS and "connected" or "not loaded")
  local slot = ns.cdb and ns.cdb.petDefSlot
  Line(slot ~= nil, "Pet bar Defensive slot (Open macro)", slot or "not read yet (summon your pet)")
  local mb = ns.MemoryMB()
  Line(mb and (mb < 40) or nil, "Memory", mb and string.format("%.1f MB%s", mb, (ns.SearchDBLoaded and ns.SearchDBLoaded()) and ", search data loaded" or ", search data not loaded yet") or "not given")
  if ns.Pad_Status then
    local st = ns.Pad_Status()
    Line(not st:find("goes to", 1, true) and (st:find("bound", 1, true) and true or nil), "Controller in the window", st)
  end
  if ns.HUD_AspectSeen then
    local seen, asp, id = ns.HUD_AspectSeen()
    Line(nil, "Aspect", string.format("thinks: %s (spell %s); buffs read: %s; your casts seen: %d, hidden: %d, last readable: %s",
      tostring(asp or "none"), tostring(id or "?"), tostring(seen.read or "never"), seen.casts, seen.hidden, tostring(seen.last or "none")) .. "; last aspect cast: " .. tostring(seen.aspectCast or "none"))
  end
  ns.Print(C.GREY .. "Red lines are the parts to tell Claude about.|r")
end
