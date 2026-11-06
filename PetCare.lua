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

-- Food in your bags your current pet will eat, best first: { {itemID, bag, slot, count, level, name} }
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
  table.sort(out, function(a, b) return a[5] > b[5] end)
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
  function b:UpdateLabel()
    if self.food then self:SetText(L["Feed: "] .. self.food[6]) else self:SetText(L["No food your pet eats"]) end
  end
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.food then
      GameTooltip:AddLine(L["Feed "] .. self.food[6], 1, 0.82, 0)
      GameTooltip:AddLine(L["You have "] .. self.food[4] .. ". Picks the highest level food your pet will eat.", 1, 1, 1, true)
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
