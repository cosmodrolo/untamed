local _, ns = ...
local L = ns.L
local C = ns.C

-- Home: what to do next (a live checklist that links to the right page) and a short guide
-- to how Untamed is organized.

local function Go(tab) return function() ns.UI_Show(tab) end end

local list

local function Build(panel)
  local tb = ns.Toolbar(panel)
  tb:Check(L["Open Untamed on this page"], function() return ns.db.openHome ~= false end, function(v) ns.db.openHome = v end)
  list = tb:List()
end

local function Refresh(panel, t)
  local rows = {}
  local function add(...) rows[#rows + 1] = { ... } end
  local level = UnitLevel("player")
  local _, class = UnitClass("player")

  -- Right now: things worth doing, each one click away.
  add(0, nil, L["Right now"], C.GREY .. L["click a line to go there"] .. "|r", nil, nil, { header = true })
  local todo = 0
  local function item(icon, text, right, tab, tip)
    todo = todo + 1
    add(14, ns.Icon(icon), text, right or "", type(tab) == "function" and tab or Go(tab), tip)
  end

  if class ~= "HUNTER" then
    item("INV_Misc_QuestionMark", C.ORANGE .. L["Untamed is made for hunters. Most pages are about your pet."] .. "|r", nil, "search")
  end
  if not UnitExists("pet") and class == "HUNTER" and level >= 10 then
    item("Ability_Hunter_BeastCall", L["No pet out: summon one, or tame your first pet."], C.GREY .. L["Find a Pet"] .. "|r", "recommend")
  end
  if UnitExists("pet") and not ns.cdb.scanned then
    item("Ability_Hunter_BeastTraining", L["Open Beast Training once (in your spellbook) so Untamed knows which ranks you have."], "", "abilities")
  end
  local h = UnitExists("pet") and ns.PetHappiness and ns.PetHappiness()
  if type(h) == "number" and h < 3 and not ns.IsSecret(h) then
    item("INV_Misc_Food_14", string.format(L["%s is hungry: feed it to keep its damage up."], UnitName("pet") or L["Your pet"]),
      h == 1 and (C.RED .. L["Unhappy"] .. "|r") or (C.GOLD .. L["Content"] .. "|r"), "care")
  end
  local nSpells, cost = 0, 0
  if ns.SpellsToTrain then nSpells, cost = ns.SpellsToTrain() end
  if nSpells > 0 then
    item("INV_Misc_Book_11", string.format(L["Train %s at your hunter trainer."], ns.Count(nSpells, L["new spell"], L["new spells"])),
      ns.Money and ns.Money(cost) or "", "spells")
  end
  local points = UnitCharacterPoints and UnitCharacterPoints("player") or 0
  if points and points > 0 then
    local nxt = ns.NextTalent and ns.NextTalent()
    item("Ability_Hunter_SniperShot", string.format(L["Spend %s."], ns.Count(points, L["talent point"], L["talent points"])),
      nxt and (C.GREY .. L["next: "] .. nxt .. "|r") or "", "talents")
  end
  if t and not t.manual then
    local teach, nextTame
    for _, e in ipairs(ns.Plan(t.family, t.level, t.known)) do
      for _, r in ipairs(e.ranks) do
        if r.known and not r.tooHigh then teach = (teach or 0) + 1 end
        if not r.known and not r.tooHigh and not nextTame then
          for _, id in ipairs(r.beasts) do
            if ns.Beasts[id][2] <= level then nextTame = { beast = id, ability = e.ability, rank = r.rank } break end
          end
        end
      end
    end
    if teach then
      item("Ability_Hunter_BeastTraining", string.format(L["Teach %s %s you already know."], t.name or L["your pet"], ns.Count(teach, L["rank"], L["ranks"])),
        C.GREY .. L["Beast Training"] .. "|r", "abilities")
    end
    if nextTame then
      local b = ns.Beasts[nextTame.beast]
      item(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming",
        string.format(L["Tame %s to learn %s %d."], b[1], ns.AbilityLabel(nextTame.ability), nextTame.rank),
        C.GREY .. ns.ZonesText(b) .. "|r", "plan")
    end
  end
  if ns.GearBestFor and ns.GearItems then
    local n = 0
    for _, slot in ipairs({ "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "FINGER", "TRINKET", "RANGED", "WEAPON" }) do
      if ns.GearBestFor(slot, 1, level, ns.GearWornScore(slot), "easy", false) then n = n + 1 end
    end
    if n > 0 then
      item("INV_Weapon_Bow_07", string.format(L["Upgrades you can buy or get from a quest now: %s."], ns.Count(n, L["slot"], L["slots"])), "", "gear")
    end
  end
  local ammoID = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_AMMO or 0)
  if class == "HUNTER" and level >= 2 then
    local count = ammoID and GetInventoryItemCount("player", INVSLOT_AMMO or 0) or 0
    if count < math.min(400, (ns.db.ammoTarget or 1000) / 2) then
      item("INV_Ammo_Arrow_02", string.format(L["Ammo is low (%d). Restock at a vendor."], count), "", "supplies")
    end
  end
  if todo == 0 then add(14, nil, C.GREEN .. L["All caught up. Nice hunting!"] .. "|r") end

  -- Where things are.
  add(0, nil, L["How Untamed is organized"], C.GREY .. L["click to open"] .. "|r", nil, nil, { header = true })
  add(14, ns.Icon("Ability_Hunter_BeastTraining"), C.GOLD .. L["My Pet"] .. "|r  " .. C.WHITE .. L["what your pet can learn, its build, food and happiness, and your stable"] .. "|r", "", Go("abilities"))
  add(14, ns.Icon("Ability_Hunter_BeastTaming"), C.GOLD .. L["Taming"] .. "|r  " .. C.WHITE .. L["which pet to tame, every beast, a taming route, and rares"] .. "|r", "", Go("recommend"))
  add(14, ns.Icon("INV_Weapon_Bow_07"), C.GOLD .. L["Gear"] .. "|r  " .. C.WHITE .. L["search anything, your wishlist, upgrades, dungeons and supplies"] .. "|r", "", Go("gear"))
  add(14, ns.Icon("INV_Misc_Book_11"), C.GOLD .. L["Hunter"] .. "|r  " .. C.WHITE .. L["spells to train, talents, reputation and class quests"] .. "|r", "", Go("spells"))

  -- Good to know.
  add(0, nil, L["Good to know"], "", nil, nil, { header = true })
  local tips = {
    L["Click a beast, item or NPC for an arrow to it. Right-click a beast to see it on the world map."],
    L["Hover anything for details: where to get it, what it teaches, what it needs."],
    L["Alt-click an item to add it to your wishlist. Shift-click to link it in chat."],
    L["Viewing (top right) switches between your pet, a stabled pet, or any family you might tame."],
    L["Type /ut s and a name to search from chat, or /ut help for every command."],
    L["Untamed notes vendors and loot as you play to fill gaps in its data (Settings > Share data)."],
  }
  for _, tip in ipairs(tips) do add(14, nil, C.GREY .. tip .. "|r") end
  list:Set(rows)
end

ns.RegisterTab("home", L["Home"], Build, Refresh)
