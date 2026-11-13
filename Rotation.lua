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

-- { code, the spell it's about, what it does, body } (group = a heading). "/cast Name" with no rank
-- always casts your best rank, so a macro on your bar upgrades itself when you train a new one.
local function Plain(code, spell, what) return { code, spell, what, "#showtooltip\n/cast " .. spell } end
ns.HUNTER_MACROS = {
  { group = L["The fight"] },
  { "Open", "Hunter's Mark", L["Every pull: sends your pet, marks the target and starts Auto Shot."],
    "#showtooltip Hunter's Mark\n/petattack\n/cast Hunter's Mark\n/cast !Auto Shot" },
  { "Hawk", "Summon Hawk", L["Press on cooldown: hawk, hawk, then Arcane Shot (two hawks stay up). Arcane Shot alone before you have Summon Hawk."],
    "#showtooltip\n/castsequence [known:Summon Hawk] reset=target Summon Hawk, Summon Hawk, Arcane Shot\n/cast [noknown:Summon Hawk] Arcane Shot" },
  Plain("Serp", "Serpent Sting", L["Mobs that live a while."]),
  Plain("Aim", "Aimed Shot", L["Once your pet holds the mob."]),
  Plain("Mult", "Multi-Shot", L["Two or more mobs."]),
  Plain("Arc", "Arcane Shot", L["Arcane Shot on its own (Hawk already mixes it in)."]),
  Plain("Conc", "Concussive Shot", L["Slows a runner."]),
  { "Brst", "Rapid Fire", L["Tough fights: Rapid Fire and Bestial Wrath together (each once you have it; press again if one didn't go off)."],
    "#showtooltip Rapid Fire\n/cast [known:Bestial Wrath] Bestial Wrath\n/cast Rapid Fire" },
  Plain("Vol", "Volley", L["Big packs (from 40)."]),
  { group = L["Your pet"] },
  { "Mend", "Mend Pet", L["Heals your pet, whatever you have targeted."], "#showtooltip Mend Pet\n/cast [@pet] Mend Pet" },
  Plain("Rev", "Revive Pet", L["Brings your pet back."]),
  Plain("Call", "Call Pet", L["Calls your pet."]),
  Plain("Feed", "Feed Pet", L["Feeds your pet (pick the food in your bags)."]),
  { group = L["Up close"] },
  Plain("Rapt", "Raptor Strike", L["A mob in melee."]),
  Plain("Mong", "Mongoose Bite", L["After you dodge."]),
  Plain("Wing", "Wing Clip", L["Slows a mob in melee so you can back off."]),
  Plain("Dis", "Disengage", L["Drops your threat so your pet takes it (from 48)."]),
  { group = L["Traps and escapes"] },
  Plain("FD", "Feign Death", L["Drops everything off you (from 30)."]),
  Plain("Frst", "Frost Trap", L["Slows everything near it."]),
  Plain("Frz", "Freezing Trap", L["Freezes one mob."]),
  Plain("Imm", "Immolation Trap", L["Fire damage over time."]),
  Plain("Expl", "Explosive Trap", L["Fire damage to a pack (from 34)."]),
  Plain("Scar", "Scare Beast", L["Makes a beast flee."]),
  { group = L["Aspects and buffs"] },
  Plain("AspH", "Aspect of the Hawk", L["In fights."]),
  Plain("AspC", "Aspect of the Cheetah", L["Running between mobs (you're dazed if hit)."]),
  Plain("AspM", "Aspect of the Monkey", L["More dodge, when something's hitting you."]),
  Plain("AspP", "Aspect of the Pack", L["Group travel (from 40)."]),
  Plain("AspW", "Aspect of the Wild", L["Nature resistance for your group."]),
  Plain("TSA", "Trueshot Aura", L["Ranged Attack Power for your group."]),
}

-- the controller: Blizzard's gamepad bars, R2 + face buttons for the fight (Alejandro's own:
-- R2 + Cross opener, Square Serpent Sting, Triangle Summon Hawk, Circle Aimed Shot)
ns.HUNTER_PAD = {
  { "R2 + Cross", "Open" }, { "R2 + Square", "Serp" }, { "R2 + Triangle", "Hawk" }, { "R2 + Circle", "Aim" },
  { "R2 + D-pad Left", "Mult" }, { "R2 + D-pad Up", "Brst" }, { "R2 + D-pad Right", "Conc" }, { "R2 + D-pad Down", "Mend" },
  { "L2 + Square", "AspH" }, { "L2 + Triangle", "AspC" }, { "L2 + Circle", "FD" }, { "L2 + Cross", "Frst" },
  { "L2 + D-pad Left", "Rapt" }, { "L2 + D-pad Up", "Wing" }, { "L2 + D-pad Right", "Frz" }, { "L2 + D-pad Down", "Rev" },
}

local STEPS = {
  { L["Pull"], {
    { "Hunter's Mark", L["Open: your pet goes in, the target is marked, Auto Shot starts."] },
    { "Summon Hawk", L["Hawk right away, then every time it lights up: two hawks attack with your pet."] },
    { "Serpent Sting", L["Only on mobs that live a while (about 10 sec or more): on quick kills it's wasted mana."] },
    { "Aimed Shot", L["Once your pet has the mob's attention (a hit or two): Aimed Shot on cooldown."] },
  } },
  { L["Packs (2 or more)"], {
    { "Multi-Shot", L["Multi-Shot instead of Aimed Shot (they share a cooldown). Hawks on the mob your pet holds."] },
    { "Concussive Shot", L["A mob that runs at you or flees: Concussive Shot."] },
  } },
  { L["Keep your pet up"], {
    { "Mend Pet", L["Mend when your pet drops under half health; keep Growl on autocast when you're solo."] },
    { "Rapid Fire", L["Tough mob or an add: Brst (Rapid Fire, and Bestial Wrath from 40)."] },
    { "Feign Death", L["Something goes wrong: Feign Death drops everything off you (from 30)."] },
  } },
  { L["Between fights"], {
    { "Aspect of the Cheetah", L["Cheetah to run, Hawk before the pull (you're dazed if hit in Cheetah)."] },
    { "Arcane Shot", L["Mana: Summon Hawk and Arcane Shot cost 11% of base mana each, so drink before you're empty; Bestial Discipline (31) and Efficiency (46) help."] },
  } },
}

-- the names before 2.14.2 ("UT ..."): renamed in place, so they stay on your bars
local OLD_NAME = {
  ["Open"] = "UT Open", ["Hawk"] = "UT Hawk", ["Serp"] = "UT Sting", ["Aim"] = "UT Aimed",
  ["Mult"] = "UT Multi", ["Arc"] = "UT Arcane", ["Conc"] = "UT Concussive", ["Brst"] = "UT Burst",
  ["Vol"] = "UT Volley", ["Mend"] = "UT Mend", ["Rev"] = "UT Revive", ["Call"] = "UT Call",
  ["Feed"] = "UT Feed", ["Rapt"] = "UT Raptor", ["Mong"] = "UT Mongoose", ["Wing"] = "UT Wing Clip",
  ["Dis"] = "UT Disengage", ["FD"] = "UT Feign", ["Frst"] = "UT Frost Trap", ["Frz"] = "UT Freeze",
  ["Imm"] = "UT Immolate", ["Expl"] = "UT Explosive", ["Scar"] = "UT Scare", ["AspH"] = "UT Asp Hawk",
  ["AspC"] = "UT Asp Cheetah", ["AspM"] = "UT Asp Monkey", ["AspP"] = "UT Asp Pack", ["AspW"] = "UT Asp Wild",
  ["TSA"] = "UT Trueshot",
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

-- a macro Untamed made under its old name: renamed and updated where it is (bars keep it)
local function Migrate()
  ns.cdb.macros = ns.cdb.macros or {}
  local n = 0
  for _, m in ipairs(ns.HUNTER_MACROS) do
    local old = not m.group and OLD_NAME[m[1]]
    if old and ns.cdb.macros[old] then
      local i = GetMacroIndexByName(old) or 0
      if i > 0 and (GetMacroIndexByName(m[1]) or 0) == 0 and pcall(EditMacro, i, m[1], nil, m[4]) then
        ns.cdb.macros[m[1]] = true
        n = n + 1
      end
      ns.cdb.macros[old] = nil
    end
  end
  return n
end

function ns.MakeHunterMacros()
  if InCombatLockdown() then ns.Print(L["Macros can be made after combat."]) return end
  local renamed = Migrate()
  if renamed > 0 then ns.Print(string.format(L["Renamed %d macros to their short names; they stay where they are on your bars."], renamed)) end
  local made, mine = 0, 0
  for _, m in ipairs(ns.HUNTER_MACROS) do
    local state = not m.group and MacroState(m)
    if not state then -- a heading
    elseif state == "yours" then mine = mine + 1
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
    add(0, nil, L["Macros"], C.GREY .. L["always your best rank; one of yours with the same name is left alone"] .. "|r", nil, nil, { header = true })
    for _, m in ipairs(ns.HUNTER_MACROS) do
     if m.group then add(6, nil, C.GOLD .. m.group .. "|r") else
      local state = MacroState(m)
      local right = state == "made" and (C.GREEN .. L["made"] .. "|r") or state == "update" and (C.GOLD .. L["click to update"] .. "|r")
        or state == "yours" and (C.GREY .. L["yours, left alone"] .. "|r") or (C.GOLD .. L["click to make"] .. "|r")
      add(14, SpellIcon(m[2]), C.HUNTER .. m[1] .. "|r  " .. C.WHITE .. m[2] .. "|r" .. C.GREY .. ": " .. m[3] .. "|r", right, function()
        local ok, err = MakeOne(m)
        if err then ns.Print(err) end
        Refresh()
      end, { m[1], m[3], C.GREY .. m[4]:gsub("\n", "\n" .. C.GREY) .. "|r" })
     end
    end
    add(0, nil, L["On the controller"], C.GREY .. L["drag them onto Blizzard's gamepad bars from /macro and your spellbook"] .. "|r", nil, nil, { header = true })
    for _, p in ipairs(ns.HUNTER_PAD) do
      local spell = p[2]
      for _, m in ipairs(ns.HUNTER_MACROS) do if m[1] == p[2] then spell = m[2] end end
      add(14, SpellIcon(spell), C.GOLD .. p[1] .. "|r", C.WHITE .. p[2] .. "|r" .. C.GREY .. "  " .. spell .. "|r")
    end
    list:Set(rows)
  end
  ns.RegisterTab("rotation", L["Rotation"], Build, Refresh)
end
