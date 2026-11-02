local _, ns = ...
local L = ns.L
local C = ns.C

-- Restock: a button beside the vendor window that tops up ammo and pet food.
-- Buys the best ammo for your weapon and the best food your pet eats that this vendor sells.

local AMMO_SUB = { arrows = 2, bullets = 3 }
local FOOD = { "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit", "Meat", "Fish" }

local function RangedKind()
  local id = GetInventoryItemID and GetInventoryItemID("player", INVSLOT_RANGED or 18)
  if not id then return nil end
  local _, _, _, _, _, classID, subID
  if C_Item and C_Item.GetItemInfoInstant then _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
  elseif GetItemInfoInstant then _, _, _, _, _, classID, subID = GetItemInfoInstant(id) end
  if classID ~= 2 then return nil end
  if subID == 3 then return "bullets" end
  if subID == 2 or subID == 18 then return "arrows" end
end

local function MerchantItemID(i)
  if GetMerchantItemID then return GetMerchantItemID(i) end
  local link = GetMerchantItemLink and GetMerchantItemLink(i)
  return link and tonumber(link:match("item:(%d+)"))
end

local function MerchantPrice(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    return info and info.price, info and info.stackCount or 1
  end
  local _, _, price, quantity = GetMerchantItemInfo(i)
  return price, quantity or 1
end

local function Count(id) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0 end

-- Best ammo and food this vendor sells for you: returns { {index, id, want}, ... }
local function Plan()
  local db = ns.SearchDB and ns.SearchDB()
  if not db then return {} end
  local level = UnitLevel("player")
  local kind = RangedKind()
  local petLevel = UnitExists("pet") and UnitLevel("pet") or nil
  local eats = {}
  for _, d in ipairs(ns.PetDiet and ns.PetDiet() or {}) do eats[d] = true end
  local bestAmmo, bestFood
  for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
    local id = MerchantItemID(i)
    local it = id and db.I[id]
    if it then
      if kind and it[4] == 6 and it[5] == AMMO_SUB[kind] and it[3] <= level then
        if not bestAmmo or it[2] > bestAmmo.ilvl then bestAmmo = { index = i, id = id, ilvl = it[2] } end
      elseif petLevel and (it[11] or 0) > 0 and eats[FOOD[it[11]] or ""] and it[3] <= level then
        -- Food far below the pet's level gives little happiness; prefer the highest level food.
        if not bestFood or it[2] > bestFood.ilvl then bestFood = { index = i, id = id, ilvl = it[2] } end
      end
    end
  end
  local out = {}
  if bestAmmo then
    local have = Count(bestAmmo.id)
    local target = ns.db.ammoTarget or 1000
    if have < target then out[#out + 1] = { index = bestAmmo.index, id = bestAmmo.id, want = target - have, kind = "ammo" } end
  end
  if bestFood and bestFood.ilvl >= (petLevel or 0) - 30 then
    local have = Count(bestFood.id)
    local target = ns.db.foodTarget or 20
    if have < target then out[#out + 1] = { index = bestFood.index, id = bestFood.id, want = target - have, kind = "food" } end
  end
  return out, bestAmmo, bestFood
end

function ns.Restock(quiet)
  if InCombatLockdown() then return end
  local plan = Plan()
  if #plan == 0 then
    if not quiet then ns.Print(L["You're stocked up."]) end
    return
  end
  local spent = 0
  for _, p in ipairs(plan) do
    local price, perBuy = MerchantPrice(p.index)
    perBuy = math.max(1, perBuy or 1)
    -- One purchase = one vendor click (a stack of perBuy items), like clicking the item yourself.
    local clicks = math.min(20, math.ceil(p.want / perBuy))
    local bought = 0
    for _ = 1, clicks do
      if price and price > GetMoney() then
        ns.Print(L["Not enough money to finish restocking."])
        break
      end
      BuyMerchantItem(p.index)
      spent = spent + (price or 0)
      bought = bought + perBuy
    end
    local name = (GetMerchantItemInfo and GetMerchantItemInfo(p.index)) or ("item " .. p.id)
    if bought > 0 then ns.Print(string.format(L["Bought %d %s."], bought, name)) end
  end
  if spent > 0 and ns.Money then ns.Print(L["Restock cost: "] .. ns.Money(spent)) end
end

local button
local function UpdateButton()
  if not MerchantFrame then return end
  if not button then
    button = ns.MakeButton(MerchantFrame, L["Restock"], 90, function() ns.Restock(false) end)
    button:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -4, -60)
    button:SetScript("OnEnter", function(self)
      local plan, ammo, food = Plan()
      local lines = { L["Restock"], string.format(L["Tops up ammo to %d and pet food to %d. Change these in Untamed Settings."], ns.db.ammoTarget or 1000, ns.db.foodTarget or 20) }
      for _, p in ipairs(plan) do
        local name = GetMerchantItemInfo and GetMerchantItemInfo(p.index) or p.id
        lines[#lines + 1] = C.GREEN .. string.format(L["Will buy %d %s"], p.want, name) .. "|r"
      end
      if #plan == 0 then lines[#lines + 1] = C.GREY .. L["Nothing needed from this vendor."] .. "|r" end
      ns.ShowTooltip(self, lines)
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local _, ammo, food = Plan()
  button:SetShown((ammo or food) and true or false)
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
pcall(ev.RegisterEvent, ev, "MERCHANT_UPDATE")
ev:SetScript("OnEvent", function(_, event)
  if not ns.db then return end
  local _, class = UnitClass("player")
  if class ~= "HUNTER" then return end
  if event == "MERCHANT_SHOW" then
    local function go()
      UpdateButton()
      if ns.db.autoRestock then ns.Restock(true) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, go) else go() end
  elseif button and button:IsShown() then
    -- refresh the tooltip state after purchases
  end
end)

ns.On("LOGIN", function()
  for k, v in pairs({ ammoTarget = 1000, foodTarget = 20, autoRestock = false }) do
    if ns.db[k] == nil then ns.db[k] = v end
  end
end)

ns.RestockTest = { Plan = Plan }
