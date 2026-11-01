local _, ns = ...
local L = ns.L
local C = ns.C

-- Stable manager: remembers every pet you own (recorded whenever it is out or
-- when you visit a stable master) and shows which ranks you already know that
-- each one can use.

local function Pets()
  ns.cdb.pets = ns.cdb.pets or {}
  return ns.cdb.pets
end

-- Remember the pet that is out right now.
local function RecordActive()
  local info = ns.ScanPet()
  if not info then return end
  local key = ns.PetKey(info.name, info.family)
  local p = Pets()[key] or {}
  p.name, p.family, p.level, p.known, p.seen = info.name, info.family, info.level, info.known, time()
  p.active = true
  Pets()[key] = p
  for k, other in pairs(Pets()) do if k ~= key then other.active = nil end end
  ns.cdb.hasActivePet = true
end

-- Read the stable window (Classic Era: GetStablePetInfo; Forever: C_StableInfo).
local function ReadStable()
  local seen = {}
  local function add(name, level, family, isCurrent)
    if not name then return end
    family = ns.ToEnglish(family)
    local key = ns.PetKey(name, family)
    local p = Pets()[key] or { known = {} }
    p.name, p.family, p.level = name, family, level or p.level
    p.stabled = not isCurrent
    p.seen = time()
    Pets()[key] = p
    seen[key] = true
  end
  local hasCurrent = false
  if C_StableInfo and C_StableInfo.GetStablePetInfo then
    for i = 1, 12 do
      local ok, info = pcall(C_StableInfo.GetStablePetInfo, i)
      if ok and info then
        add(info.name, info.level, info.familyName, i == 1)
        if i == 1 then hasCurrent = true end
      end
    end
  elseif GetStablePetInfo then
    for i = 0, (NUM_PET_STABLE_SLOTS or 2) + 1 do
      local ok, _, name, level, family = pcall(GetStablePetInfo, i)
      if ok and name then
        add(name, level, family, i <= 1)
        if i <= 1 then hasCurrent = true end
      end
    end
  end
  ns.cdb.hasActivePet = hasCurrent or UnitExists("pet")
  ns.Refresh()
end

ns.On("REFRESH", function() if UnitExists("pet") then RecordActive() end end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PET_STABLE_CLOSED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PET_STABLE_CLOSED" then
    ns.cdb.hasActivePet = UnitExists("pet") and true or ns.cdb.hasActivePet
    ns.Fire("STABLE_CLOSED")
  else
    ReadStable()
  end
end)

-- Does the hunter have a pet (out, or dismissed) that would block taming?
function ns.HasActivePet()
  if UnitExists("pet") then return true end
  if C_StableInfo and C_StableInfo.GetNumActivePets then
    local ok, n = pcall(C_StableInfo.GetNumActivePets)
    if ok and type(n) == "number" then return n > 0 end
  end
  return ns.cdb.hasActivePet and true or false
end

-- Ranks you already know that this pet can use and doesn't have yet.
function ns.ReadyUpgrades(p)
  local out = {}
  for _, e in ipairs(ns.Plan(p.family, p.level, p.known or {})) do
    local best
    for _, r in ipairs(e.ranks) do if r.known and not r.tooHigh then best = r end end
    if best then out[#out + 1] = e.ability .. " " .. best.rank end
  end
  return out
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local list
local function Build(panel)
  list = ns.NewList(panel, 4)
end

local function Refresh()
  local rows = {}
  local function add(...) rows[#rows + 1] = { ... } end
  local keys = {}
  for k in pairs(Pets()) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local x, y = Pets()[a], Pets()[b]
    if (x.active and 1 or 0) ~= (y.active and 1 or 0) then return x.active and true or false end
    return (x.level or 0) > (y.level or 0)
  end)
  if #keys == 0 then
    add(0, nil, C.GREY .. "No pets recorded yet. Summon each pet once, or open the stable at a stable master.|r")
  else
    add(0, nil, L["Your pets"], C.GREY .. L["click to plan for that pet, right-click to forget"] .. "|r", nil, nil, { header = true })
  end
  for _, k in ipairs(keys) do
    local p = Pets()[k]
    local ups = ns.ReadyUpgrades(p)
    local status = p.active and (C.GREEN .. "out now|r") or (p.stabled and (C.GREY .. "in stable|r") or (C.GREY .. "seen " .. date("%b %d", p.seen or 0) .. "|r"))
    local right = (#ups > 0 and (C.GREEN .. #ups .. " ready to teach|r   ") or "") .. status
    local selected = ns.state.mode == "stable" and ns.state.key == k
    add(0, ns.Icon(ns.FamilyIcons[p.family] or "Ability_Hunter_BeastTaming"),
      string.format("%s%s|r  %s, level %d", selected and C.GOLD or C.WHITE, p.name, ns.FamilyLabel(p.family), p.level or 0), right,
      function(_, button)
        if button == "RightButton" then
          Pets()[k] = nil
          if ns.state.key == k then ns.state.mode = "pet"; ns.state.key = nil end
        else
          ns.state.mode = "stable"; ns.state.key = k
          ns.Print(L["Planning for "] .. p.name .. ". The Abilities and Planner tabs now show this pet. Click My Pet to switch back.")
        end
        ns.Refresh()
      end,
      function()
        local lines = { p.name, p.family .. ", level " .. (p.level or 0) }
        local known = {}
        for a, r in pairs(p.known or {}) do known[#known + 1] = a .. " " .. r end
        table.sort(known)
        lines[#lines + 1] = L["Knows: "] .. (#known > 0 and table.concat(known, ", ") or "unknown until it has been out once")
        if #ups > 0 then lines[#lines + 1] = C.GREEN .. L["You can teach it now: "] .. table.concat(ups, ", ") .. "|r" end
        return lines
      end)
  end
  list:Set(rows)
end

ns.RegisterTab("stable", L["Stable"], Build, Refresh)
