local _, ns = ...
local L = ns.L

-- Diet, happiness and feeding.
local FEED_PET = 6991
local HAPPY_TEXT = { [1] = "|cffff5050Unhappy|r", [2] = "|cffffd100Content|r", [3] = "|cff40ff40Happy|r" }

local function Happiness()
  if not UnitExists("pet") then return nil end
  local h, dmg, loyaltyRate
  if C_PetInfo and C_PetInfo.GetPetHappiness then h, dmg, loyaltyRate = C_PetInfo.GetPetHappiness()
  elseif GetPetHappiness then h, dmg, loyaltyRate = GetPetHappiness() end
  return h, dmg, loyaltyRate
end
ns.PetHappiness = Happiness

local function Diet()
  local list
  if C_PetInfo and C_PetInfo.GetPetFoodTypes then list = C_PetInfo.GetPetFoodTypes()
  elseif GetPetFoodTypes then list = { GetPetFoodTypes() } end
  local out = {}
  for i, d in ipairs(list or {}) do out[i] = ns.ToEnglish(d) end
  return out
end
ns.PetDiet = Diet

local function ItemLevel(itemID)
  local _, _, _, ilvl
  if C_Item and C_Item.GetItemInfo then _, _, _, ilvl = C_Item.GetItemInfo(itemID)
  else _, _, _, ilvl = GetItemInfo(itemID) end
  return ilvl or 0
end

local function ItemName(itemID)
  if C_Item and C_Item.GetItemInfo then return (C_Item.GetItemInfo(itemID)) end
  return (GetItemInfo(itemID))
end

local function Slots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
  return GetContainerNumSlots(bag)
end

local function SlotItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount end
    return nil
  end
  local id = GetContainerItemID(bag, slot)
  local _, count = GetContainerItemInfo(bag, slot)
  return id, count
end

-- Food in your bags your current pet will eat, the one to feed first: { {itemID, bag, slot, count, level, name} }
function ns.EdibleFood()
  local out = {}
  if not UnitExists("pet") then return out end
  -- The game's own check when the client has it (Forever); otherwise the item's food type
  -- from the Classic database matched against your pet's diet.
  local diet = {}
  for _, d in ipairs(Diet()) do diet[d] = true end
  local function canEat(id)
    if C_PetInfo and C_PetInfo.CanPetEatItem then
      local ok, yes = pcall(C_PetInfo.CanPetEatItem, id)
      if ok and yes ~= nil then return yes end
    end
    local t = ns.FoodType[id]
    return t and diet[t]
  end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (Slots(bag) or 0) do
      local id, count = SlotItem(bag, slot)
      if id and canEat(id) then
        out[#out + 1] = { id, bag, slot, count or 1, ItemLevel(id), ItemName(id) or ("item " .. id) }
      end
    end
  end
  -- Cheapest food that still does the most for your pet first, so your best food (and buff food)
  -- is kept for you. How much a feeding gives depends on the food's level against your pet's:
  -- within 5 levels full, within 10 half, within 14 a quarter, lower nothing. So: the best tier
  -- you have, and inside it the lowest level food (bigger stack first on a tie).
  local petLevel = UnitLevel("pet") or 0
  if ns.IsSecret and ns.IsSecret(petLevel) then petLevel = 0 end
  local function tier(f)
    local d = petLevel - f[5]
    if d <= 5 then return 3 elseif d <= 10 then return 2 elseif d <= 14 then return 1 end
    return 0
  end
  table.sort(out, function(a, b)
    local ta, tb = tier(a), tier(b)
    if ta ~= tb then return ta > tb end
    if a[5] ~= b[5] then
      if ta == 0 then return a[5] > b[5] end   -- nothing helps: the closest to helping first
      return a[5] < b[5]
    end
    return a[4] > b[4]
  end)
  return out
end

function ns.PetCareInfo()
  if not UnitExists("pet") then return nil end
  local h, dmg, rate = Happiness()
  local loyalty
  if C_PetInfo and C_PetInfo.GetPetLoyalty then loyalty = C_PetInfo.GetPetLoyalty()
  elseif GetPetLoyalty then loyalty = GetPetLoyalty() end
  local xp, nextXP
  if GetPetExperience then xp, nextXP = GetPetExperience() end
  local tpFree, tpTotal = ns.PetTrainingPoints()
  return {
    happiness = h, happyText = HAPPY_TEXT[h or 0] or "?", damage = dmg, loyaltyRate = rate,
    loyalty = loyalty and tostring(loyalty) or nil, diet = Diet(), xp = xp, nextXP = nextXP,
    tpFree = tpFree, tpTotal = tpTotal, food = ns.EdibleFood(),
  }
end

---------------------------------------------------------------------------
-- Secure feed buttons (macro: cast Feed Pet, then use the food)
---------------------------------------------------------------------------
local feedButtons = {}

local function UpdateFeedMacro()
  if InCombatLockdown() then return end
  local food = ns.EdibleFood()[1]
  local spell = ns.SpellName(FEED_PET) or "Feed Pet"
  for _, b in ipairs(feedButtons) do
    if food then
      b:SetAttribute("type", "macro")
      b:SetAttribute("macrotext", "/cast " .. spell .. "\n/use " .. food[2] .. " " .. food[3])
      b.food = food
    else
      b:SetAttribute("type", nil)
      b:SetAttribute("macrotext", nil)
      b.food = false
    end
    if b.UpdateLabel then b:UpdateLabel() end
  end
end
ns.UpdateFeedMacro = UpdateFeedMacro

function ns.CreateFeedButton(parent, name, w, h)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  b:SetSize(w or 150, h or 22)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.food = false
  local minW = w or 150
  if ns.OneLine then ns.OneLine(b:GetFontString()) end
  function b:UpdateLabel()
    if self.food then self:SetText(L["Feed: "] .. self.food[6]) else self:SetText(L["No food your pet eats"]) end
    -- Grow to fit the food name. It's a secure button, so only resize out of combat.
    if not InCombatLockdown() then
      local fs = self:GetFontString()
      local tw = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
      self:SetWidth(math.max(minW, math.ceil(tw) + 24))
    end
  end
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.food then
      GameTooltip:AddLine(L["Feed "] .. self.food[6], 1, 0.82, 0)
      GameTooltip:AddLine(L["You have "] .. self.food[4] .. ". Picks your lowest level food that still gives your pet the most happiness, so your best food stays in your bags.", 1, 1, 1, true)
    else
      GameTooltip:AddLine(L["Nothing in your bags matches your pet's diet."], 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  feedButtons[#feedButtons + 1] = b
  UpdateFeedMacro()
  return b
end

-- Floating feed button that appears when your pet is not happy.
local floater, lastWarn
local function UpdateFloater()
  if not floater or InCombatLockdown() then return end
  local h = Happiness()
  local show = ns.db.feedReminder and h and h < 3
  floater:SetShown(show and true or false)
end

ns.On("LOGIN", function()
  floater = ns.CreateFeedButton(UIParent, "UntamedFeedButton", 170, 26)
  floater:SetPoint("TOP", 0, -120)
  floater:SetMovable(true)
  floater:SetClampedToScreen(true)
  floater:RegisterForDrag("LeftButton")
  floater:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
  floater:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  floater:Hide()
  UpdateFloater()
end)

local function OnChange(unit)
  if unit and unit ~= "pet" then return end
  UpdateFeedMacro()
  UpdateFloater()
  local h = Happiness()
  if ns.db.feedReminder and h and h < 3 and lastWarn ~= h then
    local food = ns.EdibleFood()[1]
    ns.Print(L["Your pet is "] .. (HAPPY_TEXT[h] or "not happy") .. ". " .. (food and (L["Feed it "] .. food[6] .. ".") or L["You have no food it eats."]))
  end
  lastWarn = h
  ns.Fire("PETCARE")
end
ns.On("UNIT_HAPPINESS", OnChange)
ns.On("BAG_UPDATE_DELAYED", function() UpdateFeedMacro(); ns.Fire("PETCARE") end)
ns.On("PLAYER_REGEN_ENABLED", function() UpdateFeedMacro(); UpdateFloater() end)
ns.On("REFRESH", function() UpdateFeedMacro(); UpdateFloater() end)

---------------------------------------------------------------------------
-- The Care macro: one button for your pet. Dead: Revive Pet. Not out: Call Pet. In a fight: Mend
-- Pet. Otherwise: feed it when it isn't happy, else Mend Pet.
--
-- The game decides the first three by itself when you press (macro conditions work in fights).
-- Feeding has no macro condition, so Untamed rewrites the last part of the macro outside fights:
-- "Feed Pet + this food" while the pet is hungry, "Mend Pet" the rest of the time.
---------------------------------------------------------------------------
local fedUntil = 0

local function PlainV(v) if v == nil or ns.IsSecret(v) then return nil end return v end

-- should the out-of-fight press feed? Returns the food to use, or nil.
local function WantsFeed()
  if not PlainV(UnitExists("pet")) or PlainV(UnitIsDead("pet")) then return nil end
  local h = PlainV((Happiness()))
  if not h or h >= 3 then return nil end
  if GetTime() < fedUntil then return nil end          -- it's still eating
  local hp, max = PlainV(UnitHealth("pet")), PlainV(UnitHealthMax("pet"))
  if hp and max and max > 0 and hp / max < 0.7 then return nil end   -- hurt: heal first
  return ns.EdibleFood()[1]
end

function ns.PetCareBody()
  local gone = (ns.cdb and ns.cdb.petDead) and "Revive Pet" or "Call Pet"
  local food = WantsFeed()
  local body = "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] " .. gone .. "; [combat] Mend Pet; " .. (food and "Feed Pet" or "Mend Pet")
  if food then body = body .. "\n/use [nocombat,pet,@pet,nodead] " .. food[2] .. " " .. food[3] end
  return body, food and "feed" or "mend", gone
end

ns.On("LOGIN", function()
  if select(2, UnitClass("player")) ~= "HUNTER" then return end
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_PET", "UNIT_HEALTH", "UNIT_HAPPINESS", "BAG_UPDATE_DELAYED", "UNIT_SPELLCAST_SUCCEEDED", "UI_ERROR_MESSAGE",
                       "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  local pending
  local function Later(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.5, function()
      pending = false
      if ns.UpdateHunterMacros then ns.UpdateHunterMacros(true) end
    end)
  end
  ev:SetScript("OnEvent", function(_, event, a, b, c)
    if event == "UI_ERROR_MESSAGE" then
      -- Call Pet answered "your pet is dead" (it died and its body is gone), or Revive Pet "not dead"
      local msg = PlainV(b)
      if type(msg) ~= "string" or PlainV(UnitExists("pet")) then return end
      msg = msg:lower()
      if msg:find("not dead", 1, true) then ns.cdb.petDead = false
      elseif msg:find("dead", 1, true) and msg:find("pet", 1, true) then ns.cdb.petDead = true
      else return end
      Later(0.1)
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if a ~= "player" or PlainV(c) ~= FEED_PET then return end
      fedUntil = GetTime() + 20
      C_Timer.After(20.5, function() Later(0.1) end)
    elseif (event == "UNIT_HEALTH" or event == "UNIT_HAPPINESS") and a ~= "pet" then
      return
    elseif event == "UNIT_PET" and a ~= "player" then
      return
    end
    if PlainV(UnitExists("pet")) then
      local dead = UnitIsDead("pet")
      if not ns.IsSecret(dead) then ns.cdb.petDead = dead and true or false end
    end
    Later(0.5)
  end)
  Later(6)
end)
