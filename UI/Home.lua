local _, ns = ...
local L = ns.L
local C = ns.C

-- Home: what to do next (a live checklist that links to the right page) and a short guide
-- to how Untamed is organized.

local function Go(tab) return function() ns.UI_Show(tab) end end

-- Today is a handful of cards: each one is something worth doing now, and a click (or Cross) goes
-- to the page for it. Nothing to do: one card saying so.
local cards, holder, tipsButton = {}, nil, nil
local pet            -- the panel under the cards: your pet at a glance
local CARD_H, GAP = 86, 10

local function Card(i)
  local c = cards[i]
  if c then return c end
  c = CreateFrame("Button", nil, holder)
  c:SetHeight(CARD_H)
  ns.Skin(c, ns.Theme.button, 0.75, ns.Theme.line, 0.7, 0.3)
  c.edge = c:CreateTexture(nil, "BORDER")
  c.edge:SetPoint("TOPLEFT"); c.edge:SetPoint("BOTTOMLEFT")
  c.edge:SetWidth(3)
  c.edge:SetColorTexture(ns.Theme.accent[1], ns.Theme.accent[2], ns.Theme.accent[3], 1)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.07)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(44, 44)
  c.icon:SetPoint("LEFT", 16, 0)
  c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- the title sits just above the card's middle line and the detail just under it
  c.title:SetPoint("BOTTOMLEFT", c.icon, "RIGHT", 14, 1)
  c.title:SetPoint("RIGHT", -12, 0)
  c.title:SetJustifyH("LEFT")
  c.title:SetJustifyV("BOTTOM")
  c.title:SetWordWrap(true)
  if c.title.SetMaxLines then c.title:SetMaxLines(2) end
  c.detail = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.detail:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -5)
  c.detail:SetPoint("RIGHT", -12, 0)
  c.detail:SetJustifyH("LEFT")
  c.detail:SetWordWrap(false)
  c:SetScript("OnClick", function(self) if self.go then self.go() end end)
  cards[i] = c
  return c
end

local function Layout()
  if not holder then return end
  local w = holder:GetWidth() or 0
  if w < 50 then w = 700 end
  local cols = math.max(1, math.min(3, math.floor((w + GAP) / (330 + GAP))))
  local cw = (w - (cols - 1) * GAP) / cols
  local n = 0
  for _, c in ipairs(cards) do
    if c:IsShown() then
      local col, row = n % cols, math.floor(n / cols)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (cw + GAP), -row * (CARD_H + GAP))
      c:SetWidth(cw)
      n = n + 1
    end
  end
  if pet then
    pet:ClearAllPoints()
    pet:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -math.ceil(n / cols) * (CARD_H + GAP) - 8)
    pet:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
  end
end

local function BuildPet()
  pet = CreateFrame("Frame", nil, holder)
  pet:SetHeight(174)
  ns.Skin(pet, ns.Theme.deep, 0.55, ns.Theme.line, 0.6)
  pet.box = ns.MakeModelBox(pet, 150)
  pet.box:SetPoint("TOPLEFT", 12, -12)
  pet.name = pet:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pet.name:SetPoint("TOPLEFT", pet.box, "TOPRIGHT", 16, -2)
  pet.sub = pet:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pet.sub:SetPoint("TOPLEFT", pet.name, "BOTTOMLEFT", 0, -4)
  pet.lines = pet:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  pet.lines:SetPoint("TOPLEFT", pet.sub, "BOTTOMLEFT", 0, -12)
  pet.lines:SetPoint("RIGHT", pet, "RIGHT", -12, 0)
  pet.lines:SetJustifyH("LEFT")
  pet.lines:SetSpacing(6)
end

local HAPPY = { L["Unhappy"], L["Content"], L["Happy"] }
local HAPPY_C = { C.RED, C.GOLD, C.GREEN }
local function FillPet(t)
  if not pet then return end
  local out = UnitExists("pet") and t and not t.stabled and not t.manual
  pet:SetShown(out and true or false)
  if not out then return end
  pet.box:Unit("pet", ns.Icon(ns.FamilyIcons[t.family] or "Ability_Hunter_BeastTaming"))
  pet.name:SetText(t.name or L["Pet"])
  pet.sub:SetText(string.format("%s   %s %d", ns.FamilyLabel(t.family), L["level"], t.level or 0))
  local lines = {}
  local h = ns.PetHappiness and ns.PetHappiness()
  if type(h) == "number" and not ns.IsSecret(h) and HAPPY[h] then
    lines[#lines + 1] = C.GREY .. L["Happiness"] .. "|r   " .. HAPPY_C[h] .. HAPPY[h] .. "|r"
  end
  local free = ns.PetTrainingPoints and ns.PetTrainingPoints()
  if free and not ns.IsSecret(free) then lines[#lines + 1] = C.GREY .. L["Training"] .. "|r   " .. string.format(L["%d free"], free) end
  local p = ns.cdb.pets and ns.cdb.pets[ns.PetKey(t.name, t.family)]
  if p and ns.PetSpeed then
    local speed = ns.PetSpeed(p)
    if speed then lines[#lines + 1] = C.GREY .. L["Attack speed"] .. "|r   " .. ((speed < 2.0) and C.GREEN or C.WHITE) .. string.format("%.1f s", speed) .. "|r" end
  end
  if p and ns.ReadyUpgrades then
    local ups = ns.ReadyUpgrades(p)
    if #ups > 0 then lines[#lines + 1] = C.GREY .. L["Teach it now"] .. "|r   " .. C.GREEN .. table.concat(ups, ", ") .. "|r" end
  end
  if p and ns.PetNextToLearn then
    local n = ns.PetNextToLearn(p, 1)[1]
    if n then
      lines[#lines + 1] = C.GREY .. L["Tame next for it"] .. "|r   " .. string.format("%s %d: %s%s|r", ns.AbilityLabel(n.ability) or n.ability, n.rank, C.GOLD, ns.Beasts[n.beast][1])
    end
  end
  pet.lines:SetText(table.concat(lines, "\n"))
end

local TIPS

local function Build(panel)
  local tb = ns.Toolbar(panel)
  tb:Check(L["Open Untamed on this page"], function() return ns.db.openHome ~= false end, function(v) ns.db.openHome = v end)
  tipsButton = tb:Button(L["Good to know"], 120, function(self)
    for _, tip in ipairs(TIPS) do ns.Print(tip) end
  end)
  tipsButton:SetScript("OnEnter", function(self)
    local lines = { L["Good to know"] }
    for _, tip in ipairs(TIPS) do lines[#lines + 1] = tip; lines[#lines + 1] = " " end
    ns.ShowTooltip(self, lines)
  end)
  tipsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  holder = CreateFrame("Frame", nil, panel)
  holder:SetPoint("TOPLEFT", 6, -44)
  holder:SetPoint("BOTTOMRIGHT", -6, 6)
  holder:SetScript("OnSizeChanged", Layout)
  BuildPet()
end

local function Refresh(panel, t)
  local level = UnitLevel("player")
  local _, class = UnitClass("player")

  -- things worth doing, each one click away
  local todo = 0
  local function item(icon, text, right, tab)
    todo = todo + 1
    local c = Card(todo)
    c.icon:SetTexture(ns.Icon(icon))
    c.title:SetText(text)
    c.detail:SetText(right or "")
    c.go = type(tab) == "function" and tab or Go(tab)
    c.edge:SetColorTexture(ns.Theme.accent[1], ns.Theme.accent[2], ns.Theme.accent[3], 1)
    c:Show()
  end
  for _, c in ipairs(cards) do c:Hide() end

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
  local points = ns.FreeTalentPoints and ns.FreeTalentPoints() or 0
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
    local ammoTarget = ns.db.ammoTarget or 0
    if ammoTarget == 0 then ammoTarget = 1000 end      -- "Fill my quiver"
    if count < math.min(400, ammoTarget / 2) then
      item("INV_Ammo_Arrow_02", string.format(L["Ammo is low (%d). Restock at a vendor."], count), "", "supplies")
    end
  end
  -- library books in your bags: hand them in
  if ns.BooksCount then
    local _, inBags = ns.BooksCount()
    if inBags and inBags > 0 then
      item("INV_Misc_Book_09", string.format(L["Hand in %s at the library."], ns.Count(inBags, L["library book"], L["library books"])),
        C.GREY .. L["Library books"] .. "|r", "books")
    end
  end
  if todo == 0 then
    item("Ability_Hunter_MasterMarksman", C.GREEN .. L["All caught up. Nice hunting!"] .. "|r", C.GREY .. L["Nothing needs you right now."] .. "|r", function() end)
    cards[1].edge:SetColorTexture(0.3, 0.9, 0.3, 0.8)
  end
  FillPet(t)
  Layout()
end

TIPS = {
  L["On a controller: D-pad moves, Cross selects, Square is the second action, Circle goes back, L1 and R1 change sections."],
  L["Click a beast, item or NPC for an arrow to it. Right-click a beast to see it on the world map."],
  L["If a beast isn't at a spawn spot, the arrow moves on to the next closest one. Shift-right-click the arrow to skip ahead."],
  L["Alt-click an item to add it to your wishlist. Shift-click to link it in chat."],
  L["Viewing (top right) switches between your pet, a stabled pet, or any family you might tame."],
  L["Type /ut s and a name to search from chat, or /ut help for every command."],
  L["Untamed notes vendors, loot and chests as you play and uses them to fill gaps in its lists and your map (Settings > Your data)."],
}

ns.RegisterTab("home", L["Today"], Build, Refresh)
