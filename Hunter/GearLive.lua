local _, ns = ...

---------------------------------------------------------------------------
-- Gear the shipped list doesn't know (new Forever items, like the City of Dalaran's loot) is
-- scored in game from the item itself, with the same weights as the list:
--   agility x2.4, attack power x1, crit% x20, hit% x18, stamina x0.5, intellect x0.3,
--   ranged weapon DPS x14.
-- ns.GearItems[id] answers for those items too (same shape: slot, required level, score, isMail),
-- so the loot card, Need alert, tooltips and "what you wear" all see them. Items a hunter can't
-- equip (plate, shields, maces, wands) stay unknown. Looping over ns.GearItems still gives only
-- the shipped list.
---------------------------------------------------------------------------

local SLOT = {
  INVTYPE_HEAD = "HEAD", INVTYPE_NECK = "NECK", INVTYPE_SHOULDER = "SHOULDER", INVTYPE_CHEST = "CHEST", INVTYPE_ROBE = "CHEST",
  INVTYPE_WAIST = "WAIST", INVTYPE_LEGS = "LEGS", INVTYPE_FEET = "FEET", INVTYPE_WRIST = "WRIST", INVTYPE_HAND = "HANDS",
  INVTYPE_FINGER = "FINGER", INVTYPE_TRINKET = "TRINKET", INVTYPE_CLOAK = "BACK",
  INVTYPE_WEAPON = "WEAPON", INVTYPE_2HWEAPON = "WEAPON", INVTYPE_WEAPONMAINHAND = "WEAPON", INVTYPE_WEAPONOFFHAND = "OFFHAND",
  INVTYPE_HOLDABLE = "OFFHAND", INVTYPE_RANGED = "RANGED", INVTYPE_RANGEDRIGHT = "RANGED", INVTYPE_THROWN = "RANGED",
}
-- weapon subclasses a hunter can use: axes, bows, guns, polearms, swords, staves, fist, daggers, thrown, crossbows
local WEAPON_OK = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true,
  [13] = true, [15] = true, [16] = true, [18] = true }
-- armor: misc (rings, necks, trinkets, held items), cloth, leather, mail
local ARMOR_OK = { [0] = true, [1] = true, [2] = true, [3] = true }

local WEIGHT = {
  ITEM_MOD_AGILITY_SHORT = 2.4, ITEM_MOD_ATTACK_POWER_SHORT = 1, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 1,
  ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_INTELLECT_SHORT = 0.3,
  ITEM_MOD_CRIT_RATING_SHORT = 20, ITEM_MOD_CRIT_RANGED_RATING_SHORT = 20,
  ITEM_MOD_HIT_RATING_SHORT = 18, ITEM_MOD_HIT_RANGED_RATING_SHORT = 18,
}

local live, never, asked = {}, {}, {}

local function Stats(id)
  local f = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not f then return nil end
  local ok, t = pcall(f, "item:" .. id)
  if ok and type(t) == "table" and not ns.IsSecret(t) then return t end
end

local function Compute(id)
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not instant then return nil, true end
  local ok, _, _, _, equipLoc, _, classID, subclassID = pcall(instant, id)
  if not ok or not equipLoc or ns.IsSecret(equipLoc) then return nil, false end
  local slot = SLOT[equipLoc]
  if not slot then return nil, true end
  if classID == 2 then
    if not WEAPON_OK[subclassID] then return nil, true end
  elseif classID == 4 then
    if not ARMOR_OK[subclassID] or equipLoc == "INVTYPE_SHIELD" then return nil, true end
  else
    return nil, true
  end
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local okI, name, _, _, _, minLevel = pcall(info, id)
  local stats = Stats(id)
  if not okI or not name or not stats then
    -- the game hasn't loaded this item yet: ask once, answer when it has
    if not asked[id] and C_Item and C_Item.RequestLoadItemDataByID then
      asked[id] = true
      pcall(C_Item.RequestLoadItemDataByID, id)
    end
    return nil, false
  end
  local score = 0
  for k, v in pairs(stats) do
    local w = WEIGHT[k]
    if w and type(v) == "number" then score = score + v * w end
  end
  if slot == "RANGED" then
    local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    if type(dps) == "number" then score = score + dps * 14 end
  end
  return { slot, tonumber(minLevel) or 1, math.floor(score + 0.5), (classID == 4 and subclassID == 3) and 1 or 0, live = true }, true
end

-- A worn or carried item can have a random suffix ("of the Monkey") that the item's number alone
-- doesn't show. Its link does: score = the plain item's score + the weighted stats the suffix adds.
local function Weighted(stats, ranged)
  local score = 0
  for k, v in pairs(stats) do
    local w = WEIGHT[k]
    if w and type(v) == "number" then score = score + v * w end
  end
  if ranged and type(stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) == "number" then score = score + stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT * 14 end
  return score
end

local function LinkStats(link)
  local f = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not f then return nil end
  local ok, t = pcall(f, link)
  if ok and type(t) == "table" and not ns.IsSecret(t) then return t end
end

-- The stats on an item as its tooltip shows them ("+5 Agility"). The tooltip is what the player
-- sees, so it includes a random suffix whatever the item's link or the stats call say.
local nameToKey
local function StatNames()
  if nameToKey then return nameToKey end
  nameToKey = {}
  local english = { ITEM_MOD_AGILITY_SHORT = "Agility", ITEM_MOD_STAMINA_SHORT = "Stamina", ITEM_MOD_INTELLECT_SHORT = "Intellect",
    ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "Ranged Attack Power" }
  for key, name in pairs(english) do
    local g = _G[key]
    nameToKey[(type(g) == "string" and g or name):lower()] = key
  end
  return nameToKey
end

local function LineStats(tdata)
  if type(tdata) ~= "table" or ns.IsSecret(tdata) then return nil end
  local lines = tdata.lines
  if type(lines) ~= "table" or ns.IsSecret(lines) then return nil end
  local names, out, any = StatNames(), {}, false
  local apNames = { (type(ITEM_MOD_RANGED_ATTACK_POWER_SHORT) == "string" and ITEM_MOD_RANGED_ATTACK_POWER_SHORT or "Ranged Attack Power"):lower(),
    (type(ITEM_MOD_ATTACK_POWER_SHORT) == "string" and ITEM_MOD_ATTACK_POWER_SHORT or "Attack Power"):lower() }
  for _, line in ipairs(lines) do
    local text = type(line) == "table" and line.leftText
    if type(text) == "string" and not ns.IsSecret(text) then
      text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      local n, name = text:match("^%+(%d+)%s+(.-)%s*$")
      local key = name and names[name:lower()]
      if not key then
        -- "Equip: +14 Attack Power." (suffixes like "of Power" and "of Marksmanship"). Not the
        -- kinds that only count in a druid form or against one kind of creature.
        local low = text:lower()
        local amount = low:match("%+(%d+)")
        if amount and not low:find(" forms", 1, true) and not low:find("when fighting", 1, true) then
          local rap, ap = apNames[1], apNames[2]
          if low:find(rap, 1, true) then key, n = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", amount
          elseif low:find(ap, 1, true) then key, n = "ITEM_MOD_ATTACK_POWER_SHORT", amount end
        end
      end
      if key then out[key] = (out[key] or 0) + tonumber(n); any = true end
    end
  end
  return out, any
end
ns.GearLineStats = LineStats

local function Tip(fn, ...)
  if not (C_TooltipInfo and C_TooltipInfo[fn]) then return nil end
  local ok, t = pcall(C_TooltipInfo[fn], ...)
  return ok and t or nil
end

local plainLines = {}     -- [id] = weighted tooltip stats of the plain item (no suffix)
local linkScore = {}      -- [item string] = score
-- score, entry for an item given its number and, when there are any, its link and its tooltip
-- (tdata: what C_TooltipInfo gave for the very item in your bag or on you).
--   score = the plain item's score + what its suffix adds.
-- The suffix is measured two ways and the bigger one counts: the game's stats call on the link,
-- and the "+N Stat" lines of the tooltip compared with the plain item's tooltip.
function ns.GearScoreOf(id, link, tdata)
  id = tonumber(id)
  local g = id and ns.GearItems and ns.GearItems[id]
  if not g then return 0, nil end
  if type(link) ~= "string" or (ns.IsSecret and ns.IsSecret(link)) then link = nil end
  if not link and not tdata then return g[3], g end
  local key = link and link:match("item:[%-%d:]+")
  -- a tooltip of the very item is the best evidence there is: with one, work it out afresh
  if key and linkScore[key] and not tdata then return linkScore[key], g end
  local ranged = g[1] == "RANGED"
  local add, settled = 0, false
  if link then
    local full, plain = LinkStats(link), Stats(id)
    if full and plain then add = Weighted(full, ranged) - Weighted(plain, ranged); settled = true end
  end
  local shown = LineStats(tdata or (link and Tip("GetHyperlink", link)))
  if shown then
    local base = plainLines[id]
    if base == nil then
      local p = LineStats(Tip("GetHyperlink", "item:" .. id))
      if p then base = Weighted(p, false); plainLines[id] = base end
    end
    if base == nil then
      -- no tooltip for the plain item right now: the stats call on its number says the same thing
      local plain = Stats(id)
      if plain then base = Weighted(plain, false) end
    end
    if base then
      add = math.max(add, Weighted(shown, false) - base)
      settled = true
    end
  end
  local score = g[3] + math.max(0, math.floor(add + 0.5))
  if key and settled then linkScore[key] = math.max(score, linkScore[key] or 0) end
  if key and linkScore[key] then score = linkScore[key] end
  return score, g
end

if ns.GearItems then
  setmetatable(ns.GearItems, { __index = function(_, id)
    if type(id) ~= "number" or id <= 0 then return nil end
    if never[id] then return nil end
    local g = live[id]
    if g then return g end
    local final
    g, final = Compute(id)
    if g then live[id] = g elseif final then never[id] = true end
    return g
  end })
end

-- when the game finishes loading an item we asked for, screens that list gear refresh
do
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
  local pending
  ev:SetScript("OnEvent", function(_, _, id)
    if not id or not asked[id] or pending then return end
    pending = true
    C_Timer.After(0.5, function()
      pending = false
      if ns.LootCardRefresh then ns.LootCardRefresh() end
    end)
  end)
end
