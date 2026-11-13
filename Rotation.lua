local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Rotation tab (from Paladin Path): what to press in a fight, in order, for a Beast Mastery
-- hunter leveling with a pet; the macros that go with it (made per character, a macro of yours
-- with the same name is never touched); and where each goes on the controller.
-- Numbers behind it (Forever, Nov 13 2026): Summon Hawk shares its 6 sec cooldown with Arcane
-- Shot, at most 2 hawks at once, each lasts 18 sec, and both cost 11% of base mana (Nov 10);
-- hawks got 80% more melee damage on Nov 10. Aimed Shot shares its cooldown with Multi-Shot.
---------------------------------------------------------------------------

local function Known(name)
  local ok, info = pcall(function() return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name) end)
  if ok and info and info.spellID then
    local ok2, known = pcall(IsPlayerSpell, info.spellID)
    if ok2 and known then return true end
    if IsSpellKnown and IsSpellKnown(info.spellID) then return true end
  end
  return false
end
ns.RotationKnown = Known

-- the level a spell (or talent, from the build) comes at
local LEVEL = { ["Serpent Sting"] = 4, ["Hunter's Mark"] = 6, ["Arcane Shot"] = 6, ["Concussive Shot"] = 8, ["Aspect of the Hawk"] = 10,
  ["Mend Pet"] = 12, ["Wing Clip"] = 12, ["Multi-Shot"] = 18, ["Aimed Shot"] = 20, ["Aspect of the Cheetah"] = 20, ["Summon Hawk"] = 25,
  ["Rapid Fire"] = 26, ["Frost Trap"] = 28, ["Feign Death"] = 30, ["Bestial Wrath"] = 40 }

-- { code, the spell it's about, what it does, body }
ns.HUNTER_MACROS = {
  { "UT Open", "Hunter's Mark", L["Every pull: sends your pet, marks the target and starts Auto Shot."],
    "#showtooltip Hunter's Mark\n/petattack\n/cast Hunter's Mark\n/cast !Auto Shot" },
  { "UT Hawk", "Summon Hawk", L["Press on cooldown: hawk, hawk, then Arcane Shot (two hawks stay up). Arcane Shot alone before you have Summon Hawk."],
    "#showtooltip\n/castsequence [known:Summon Hawk] reset=target Summon Hawk, Summon Hawk, Arcane Shot\n/cast [noknown:Summon Hawk] Arcane Shot" },
  { "UT Mend", "Mend Pet", L["Heals your pet, whatever you have targeted."], "#showtooltip Mend Pet\n/cast [@pet] Mend Pet" },
  { "UT Burst", "Rapid Fire", L["Tough fights: Rapid Fire and Bestial Wrath together (each once you have it; press again if one didn't go off)."],
    "#showtooltip Rapid Fire\n/cast [known:Bestial Wrath] Bestial Wrath\n/cast Rapid Fire" },
}

-- the controller: Blizzard's gamepad bars, R2 + face buttons for the fight (Alejandro's own:
-- R2 + Cross opener, Square Serpent Sting, Triangle Summon Hawk, Circle Aimed Shot)
ns.HUNTER_PAD = {
  { "R2 + Cross", "UT Open" }, { "R2 + Square", "Serpent Sting" }, { "R2 + Triangle", "UT Hawk" }, { "R2 + Circle", "Aimed Shot" },
  { "R2 + D-pad Left", "Multi-Shot" }, { "R2 + D-pad Up", "UT Burst" }, { "R2 + D-pad Right", "Concussive Shot" }, { "R2 + D-pad Down", "UT Mend" },
  { "L2 + Square", "Aspect of the Hawk" }, { "L2 + Triangle", "Aspect of the Cheetah" }, { "L2 + Circle", "Feign Death" }, { "L2 + Cross", "Frost Trap" },
}

local STEPS = {
  { L["Pull"], {
    { "Hunter's Mark", L["UT Open: your pet goes in, the target is marked, Auto Shot starts."] },
    { "Summon Hawk", L["UT Hawk right away, then every time it lights up: two hawks attack with your pet."] },
    { "Serpent Sting", L["Only on mobs that live a while (about 10 sec or more): on quick kills it's wasted mana."] },
    { "Aimed Shot", L["Once your pet has the mob's attention (a hit or two): Aimed Shot on cooldown."] },
  } },
  { L["Packs (2 or more)"], {
    { "Multi-Shot", L["Multi-Shot instead of Aimed Shot (they share a cooldown). Hawks on the mob your pet holds."] },
    { "Concussive Shot", L["A mob that runs at you or flees: Concussive Shot."] },
  } },
  { L["Keep your pet up"], {
    { "Mend Pet", L["UT Mend when your pet drops under half health; keep Growl on autocast when you're solo."] },
    { "Rapid Fire", L["Tough mob or an add: UT Burst (Rapid Fire, and Bestial Wrath from 40)."] },
    { "Feign Death", L["Something goes wrong: Feign Death drops everything off you (from 30)."] },
  } },
  { L["Between fights"], {
    { "Aspect of the Cheetah", L["Cheetah to run, Hawk before the pull (you're dazed if hit in Cheetah)."] },
    { "Arcane Shot", L["Mana: Summon Hawk and Arcane Shot cost 11% of base mana each, so drink before you're empty; Bestial Discipline (31) and Efficiency (46) help."] },
  } },
}

local function MacroState(m)
  local i = GetMacroIndexByName and GetMacroIndexByName(m[1]) or 0
  if not i or i == 0 then return "none" end
  local _, _, body = GetMacroInfo(i)
  ns.cdb.macros = ns.cdb.macros or {}
  if not ns.cdb.macros[m[1]] then return "yours" end
  if body and body:gsub("%s+$", "") ~= m[4] then return "update" end
  return "made"
end

local function MakeOne(m)
  if InCombatLockdown() then return false, L["Macros can be made after combat."] end
  local state = MacroState(m)
  if state == "yours" or state == "made" then return false end
  local ok, err
  if state == "update" then
    ok, err = pcall(EditMacro, GetMacroIndexByName(m[1]), m[1], nil, m[4])
  else
    local _, perChar = GetNumMacros()
    ok, err = pcall(CreateMacro, m[1], 134400, m[4], (perChar or 0) < (MAX_CHARACTER_MACROS or 18))
  end
  if not ok then return false, tostring(err) end
  ns.cdb.macros = ns.cdb.macros or {}
  ns.cdb.macros[m[1]] = true
  return true
end

function ns.MakeHunterMacros()
  if InCombatLockdown() then ns.Print(L["Macros can be made after combat."]) return end
  local made, mine = 0, 0
  for _, m in ipairs(ns.HUNTER_MACROS) do
    local state = MacroState(m)
    if state == "yours" then mine = mine + 1
    else
      local ok, err = MakeOne(m)
      if ok then made = made + 1 elseif err then ns.Print(string.format(L["Couldn't make %s: %s"], m[1], err)) end
    end
  end
  ns.Print(string.format(L["Made or updated %d macros. Put them on your bars from /macro (Character Macros)."], made)
    .. (mine > 0 and (" " .. string.format(L["Left %d of yours with the same name alone."], mine)) or ""))
  if ns.UI_Refresh then ns.UI_Refresh() end
end

do
  local list
  local function Build(panel)
    local tb = ns.Toolbar(panel)
    tb:Button(L["Make the macros"], 150, function() ns.MakeHunterMacros() end)
    list = tb:List()
  end

  local function SpellIcon(name)
    local ok, info = pcall(function() return C_Spell.GetSpellInfo(name) end)
    return ok and info and info.iconID or nil
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    for _, sec in ipairs(STEPS) do
      add(0, nil, sec[1], "", nil, nil, { header = true })
      for _, st in ipairs(sec[2]) do
        local have = Known(st[1])
        add(14, SpellIcon(st[1]), (have and C.WHITE or C.GREY) .. st[2] .. "|r",
          have and "" or (C.GREY .. L["lvl "] .. (LEVEL[st[1]] or "?") .. "|r"), nil, { st[1], st[2] })
      end
    end
    add(0, nil, L["Macros"], C.GREY .. L["made per character; one of yours with the same name is left alone"] .. "|r", nil, nil, { header = true })
    for _, m in ipairs(ns.HUNTER_MACROS) do
      local state = MacroState(m)
      local right = state == "made" and (C.GREEN .. L["made"] .. "|r") or state == "update" and (C.GOLD .. L["click to update"] .. "|r")
        or state == "yours" and (C.GREY .. L["yours, left alone"] .. "|r") or (C.GOLD .. L["click to make"] .. "|r")
      add(14, SpellIcon(m[2]), C.HUNTER .. m[1] .. "|r  " .. C.GREY .. m[3] .. "|r", right, function()
        local ok, err = MakeOne(m)
        if err then ns.Print(err) end
        Refresh()
      end, { m[1], m[3], C.GREY .. m[4]:gsub("\n", "\n" .. C.GREY) .. "|r" })
    end
    add(0, nil, L["On the controller"], C.GREY .. L["drag them onto Blizzard's gamepad bars from /macro and your spellbook"] .. "|r", nil, nil, { header = true })
    for _, p in ipairs(ns.HUNTER_PAD) do
      add(14, SpellIcon(p[2]:find("^UT ") and "Hunter's Mark" or p[2]), C.GOLD .. p[1] .. "|r", C.WHITE .. p[2] .. "|r")
    end
    list:Set(rows)
  end
  ns.RegisterTab("rotation", L["Rotation"], Build, Refresh)
end
