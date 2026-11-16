local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Bag marks: a green arrow on gear that beats what you wear, a lock on soulbound items, a coin on
-- items you can still sell or trade.
--
-- Gamepad safety (the reason this is built the way it is):
--   * Nothing is created inside Blizzard's bags and nothing is attached to them. Our one frame
--     hangs on UIParent and is made at login, while the bags are closed. The marks are textures
--     on that frame, so SmartNavigation's CreateFrame hook never sees them.
--   * We only READ from the bag buttons (where they are, which bag and slot), never write a field.
--   * We wait a moment after a bag opens or changes before reading positions, so the game has
--     already laid the bag out itself and our read doesn't trigger any of Blizzard's layout code.
--   * In a fight the marks hide.
---------------------------------------------------------------------------

local MEDIA = "Interface\\AddOns\\Untamed\\Media\\"
local FRAMES = { "ContainerFrameCombinedBags" }
for i = 1, 13 do FRAMES[#FRAMES + 1] = "ContainerFrame" .. i end

local sheet, pool, used = nil, {}, 0
local cache = {}          -- [bag * 1000 + slot] = { up = bool, lock = bool, coin = bool } or false
local settleUntil = 0     -- don't read positions before this time
local wasOpen = false

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end

local SELL_CLASS = { [1] = true, [2] = true, [3] = true, [4] = true, [7] = true, [9] = true }

local function On(key) return ns.db and ns.db[key] ~= false end

-- What marks one bag slot gets. Pure data: no frames touched.
local function Marks(bag, slot)
  local key = bag * 1000 + slot
  local m = cache[key]
  if m ~= nil then return m end
  m = false
  local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
  if ok and type(info) == "table" and not ns.IsSecret(info) then
    local id = Plain(info.itemID)
    if id then
      local bound = Plain(info.isBound) and true or false
      local quality = Plain(info.quality)
      local link = Plain(info.hyperlink)
      -- worth selling: bags, weapons, gems, armor, trade goods, recipes; green or better odds and ends.
      -- Ammo, food, drink, potions, reagents, quest items and keys get no coin.
      local sellable = false
      local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
      if instant then
        local okI, _, _, _, _, _, classID = pcall(instant, id)
        if okI and type(classID) == "number" then
          sellable = SELL_CLASS[classID] or (classID == 15 and (quality or 0) >= 2) or false
        end
      end
      local gain = ns.GearGain and ns.GearGain(id, link)
      m = {
        up = (gain and gain > 0) or false,
        lock = bound,
        coin = (not bound) and sellable and (quality or 1) >= 1,
      }
    end
  end
  cache[key] = m
  return m
end
ns.BagMarksFor = function(bag, slot) cache[bag * 1000 + slot] = nil; return Marks(bag, slot) end

local function Tex(file)
  used = used + 1
  local t = pool[used]
  if not t then
    t = sheet:CreateTexture(nil, "OVERLAY")
    pool[used] = t
  end
  t:SetTexture(MEDIA .. file)
  return t
end

local function Place(t, x, y, size)
  t:ClearAllPoints()
  t:SetSize(size, size)
  t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  t:Show()
end

local function HideAll()
  for i = 1, #pool do pool[i]:Hide() end
  used = 0
end

local function AnyOpen()
  for _, name in ipairs(FRAMES) do
    local f = _G[name]
    if f and f.IsShown and f:IsShown() then return true end
  end
  return false
end

-- Read where each visible bag slot sits and draw its marks there.
local function Draw()
  HideAll()
  local ui = Plain(UIParent:GetEffectiveScale())
  if not ui or ui <= 0 then return end
  local showUp, showLock, showCoin = On("bagUp"), On("bagLock"), On("bagCoin")
  for _, name in ipairs(FRAMES) do
    local f = _G[name]
    local items = f and f.IsShown and f:IsShown() and f.Items
    if type(items) == "table" then
      for _, b in pairs(items) do
        if type(b) == "table" and b.IsVisible and b:IsVisible() then
          local slot = Plain(b:GetID())
          local bag = b.GetBagID and Plain(b:GetBagID())
          local cx, cy = b:GetCenter()
          local w, sc = Plain(b:GetWidth()), Plain(b:GetEffectiveScale())
          cx, cy = Plain(cx), Plain(cy)
          if slot and bag and cx and cy and w and sc then
            local m = Marks(bag, slot)
            if m then
              local k = sc / ui
              local x, y, half = cx * k, cy * k, w * k / 2
              local size = math.max(10, w * k * 0.42)
              local inset = half - size / 2 + 1
              if m.up and showUp then Place(Tex("BagUp"), x - inset, y + inset, size) end
              if m.lock and showLock then Place(Tex("BagLock"), x + inset, y + inset, size * 0.8)
              elseif m.coin and showCoin then Place(Tex("BagCoin"), x + inset, y + inset, size * 0.8) end
            end
          end
        end
      end
    end
  end
end

local function Tick()
  if not sheet then return end
  if not (On("bagUp") or On("bagLock") or On("bagCoin")) or (InCombatLockdown and InCombatLockdown()) or not AnyOpen() then
    if wasOpen then HideAll(); sheet:Hide(); wasOpen = false end
    return
  end
  local now = GetTime()
  if not wasOpen then
    wasOpen = true
    settleUntil = now + 0.3
    return
  end
  if now < settleUntil then return end
  sheet:Show()
  local ok, err = pcall(Draw)
  if not ok then
    HideAll()
    if not ns.bagMarkError then ns.bagMarkError = tostring(err) end
  end
end
ns.BagMarksTick = Tick

local function Changed(_, event)
  wipe(cache)
  -- the bag's contents moved: let the game lay it out again before we read positions
  if event == nil or event == "BAG_UPDATE_DELAYED" then
    settleUntil = GetTime() + 0.2
    if wasOpen then HideAll() end
  end
end

ns.On("LOGIN", function()
  sheet = CreateFrame("Frame", "UntamedBagMarks", UIParent)
  sheet:SetAllPoints(UIParent)
  sheet:SetFrameStrata("HIGH")
  sheet:EnableMouse(false)
  sheet:Hide()

  local driver = CreateFrame("Frame")
  local acc = 0
  driver:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    Tick()
  end)
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED", "ITEM_LOCK_CHANGED" }) do
    pcall(driver.RegisterEvent, driver, e)
  end
  driver:SetScript("OnEvent", Changed)
end)

-- /ut bags [arrows|locks|coins] : switch the marks
function ns.BagMarksCommand(arg)
  local keys = { arrows = "bagUp", locks = "bagLock", coins = "bagCoin" }
  local names = { bagUp = L["Upgrade arrows in your bags"], bagLock = L["Locks on soulbound items"], bagCoin = L["Coins on items you can sell"] }
  local key = keys[(arg or ""):lower():match("^%s*(%a*)") or ""]
  if key then
    ns.db[key] = ns.db[key] == false
    Changed()
    ns.Print(names[key] .. ": " .. (ns.db[key] and L["on"] or L["off"]))
    return
  end
  for _, k in ipairs({ "bagUp", "bagLock", "bagCoin" }) do
    ns.Print(names[k] .. ": " .. (On(k) and L["on"] or L["off"]))
  end
  ns.Print(L["Switch one with /ut bags arrows, /ut bags locks or /ut bags coins."])
  if ns.bagMarkError then ns.Print(L["Bag marks hit an error: "] .. ns.bagMarkError) end
end
