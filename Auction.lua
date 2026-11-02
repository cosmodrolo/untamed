local _, ns = ...
local L = ns.L
local C = ns.C

-- Auction House helper (classic Auction House): marks wishlist items and gear upgrades in the
-- Browse results, and tells you once when a wishlist item is listed.

local told, tags = {}, {}

local function Tag(button)
  if tags[button] then return tags[button] end
  local icon = _G[button:GetName() .. "Item"] or button
  local t = {}
  t.glow = icon:CreateTexture(nil, "OVERLAY")
  t.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  t.glow:SetBlendMode("ADD")
  t.glow:SetSize(64, 64)
  t.glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
  t.text = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  t.text:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  tags[button] = t
  return t
end

local function Update()
  if not ns.db or ns.db.ahHelper == false or not BrowseScrollFrame or not GetAuctionItemInfo then return end
  local offset = FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(BrowseScrollFrame) or 0
  local level = UnitLevel("player")
  for i = 1, (NUM_BROWSE_TO_DISPLAY or 8) do
    local button = _G["BrowseButton" .. i]
    if button then
      local t = Tag(button)
      t.glow:Hide(); t.text:SetText("")
      if button:IsShown() then
        local itemId = select(17, GetAuctionItemInfo("list", offset + i))
        if itemId then
          if ns.OnWishlist and ns.OnWishlist(itemId) then
            t.glow:SetVertexColor(1, 0.82, 0); t.glow:Show()
            t.text:SetText(C.GOLD .. L["Wish"] .. "|r")
            if not told[itemId] then
              told[itemId] = true
              local name = GetAuctionItemInfo("list", offset + i)
              ns.Print(string.format(L["Wishlist item on the Auction House: %s."], name or itemId))
            end
          else
            local g = ns.GearItems and ns.GearItems[itemId]
            if g and g[2] <= level and (g[4] == 0 or level >= 40) then
              local gain = g[3] - (ns.GearWornScore and ns.GearWornScore(g[1]) or 0)
              if gain > 0 then
                t.glow:SetVertexColor(0.25, 1, 0.25); t.glow:Show()
                t.text:SetText(C.GREEN .. "+" .. gain .. "|r")
              end
            end
          end
        end
      end
    end
  end
end

local hooked = false
local function Hook()
  if hooked or not AuctionFrameBrowse_Update then return end
  hooked = true
  hooksecurefunc("AuctionFrameBrowse_Update", Update)
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "AUCTION_HOUSE_SHOW" or arg == "Blizzard_AuctionUI" then Hook() end
end)

ns.AuctionTest = { Update = Update, Hook = Hook }
