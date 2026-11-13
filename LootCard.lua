local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Dungeon loot card and the Need alert (from Paladin Path).
--   Card: entering a 5-player dungeon, each boss and the hunter gear it drops for you, upgrades
--   marked "+N" (Untamed's gear score over what you wear), gear you already own greyed with a check.
--   It fades after 45 sec or at the first pull; /ut loot keeps it up. Bosses and loot come from
--   Dungeon Journal (Exehn's ForeverDungeonJournal) while the game runs; without it, no card.
--   Need alert: an upgrade from your list comes up for a roll: a banner, a sound and a chat line.
--   Blizzard's roll windows are left alone (you still press Need there).
-- Our own frames on UIParent only (gamepad safe).
---------------------------------------------------------------------------

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local QUALITY = { [0] = "|cff9d9d9d", "|cffffffff", "|cff1eff00", "|cff0070dd", "|cffa335ee", "|cffff8000" }
local MUTED, GOLD = "|cff8f8f99", "|cffffd140"
local DEFAULT_POS = { "TOP", 0, -60 }
local DEFAULT_SCALE = 0.9
local WIDTH, CROWS = 320, 10

local function DJ()
  local dj = _G.ForeverDungeonJournal_NS
  if type(dj) == "table" and type(dj.DB) == "table" and type(dj.ORDER) == "table" then return dj end
end

local function Norm(s) return (tostring(s or ""):lower():gsub("^the ", ""):gsub("[^%a]", "")) end

-- the Dungeon Journal entry for the 5-player dungeon you're in: name, data
local function Here()
  local inside, kind = IsInInstance()
  if not inside or kind ~= "party" then return nil end
  local dj = DJ()
  if not dj then return nil end
  local want = Norm(GetInstanceInfo())
  if want == "" then return nil end
  for _, name in ipairs(dj.ORDER) do if Norm(name) == want and type(dj.DB[name]) == "table" then return name, dj.DB[name] end end
  for _, name in ipairs(dj.ORDER) do
    local n = Norm(name)
    if (n:sub(1, #want) == want or want:sub(1, #n) == n) and type(dj.DB[name]) == "table" then return name, dj.DB[name] end
  end
end
ns.LootDungeonHere = Here

-- worn, in your bags, or in your bank (the bank counts once the game has seen it)
function ns.HaveItem(id)
  id = tonumber(id)
  if not id then return false end
  local ok, worn = pcall(function() return C_Item and C_Item.IsEquippedItem and C_Item.IsEquippedItem(id) end)
  if ok and worn then return true end
  local count = 0
  pcall(function()
    local f = (C_Item and C_Item.GetItemCount) or GetItemCount
    count = f(id, true) or 0
  end)
  return count > 0
end

-- is it hunter gear for you (Untamed's gear list: usable, mail from 40), and how much better than
-- what you wear in that slot: gain (nil = not for you)
local function ForMe(id)
  local g = ns.GearItems and ns.GearItems[tonumber(id) or 0]
  if not g then return nil end
  if g[4] == 1 and (UnitLevel("player") or 1) < 40 then return nil end
  local worn = ns.GearWornScore and ns.GearWornScore(g[1]) or 0
  return g[3] - worn, g
end
ns.LootForMe = ForMe

-- each boss with its loot for you: { name, rare, loot = { { id, name, quality, gain, have } } }
local function Bosses(name, d)
  local out = {}
  for _, b in ipairs(type(d.bosses) == "table" and d.bosses or {}) do
    if type(b) == "table" and b.name and not b.trash then
      local mine = {}
      for _, it in ipairs(type(b.loot) == "table" and b.loot or {}) do
        local gain = ForMe(it[1])
        if gain then mine[#mine + 1] = { id = it[1], name = it[2], q = it[4], gain = gain, have = ns.HaveItem(it[1]) } end
      end
      table.sort(mine, function(a, c)
        if a.have ~= c.have then return not a.have end
        return a.gain > c.gain
      end)
      out[#out + 1] = { name = b.name, rare = b.rare, loot = mine }
    end
  end
  return out
end

local function Short(it)
  if it.have then return CHECK .. MUTED .. (it.name or "?") .. "|r" end
  return (QUALITY[it.q or 1] or "") .. (it.name or "?") .. "|r" .. (it.gain > 0 and ("|cff5fe07a +" .. it.gain .. "|r") or "")
end

local card, hideAt, moving, pinned

local function Place()
  local pos = ns.db.lootPos or DEFAULT_POS
  local s = ns.db.lootScale or DEFAULT_SCALE
  card:SetScale(s)
  card:ClearAllPoints()
  card:SetPoint(pos[1], UIParent, pos[1], pos[2] / s, pos[3] / s)   -- saved in screen units
end

local function Text(parent, size, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  local file = fs:GetFont()
  fs:SetFont(file or STANDARD_TEXT_FONT, size, "")
  fs:SetJustifyH("LEFT")
  return fs
end

local function Layout()
  local y = -34
  for _, r in ipairs(card.rows) do
    if r:IsShown() then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 10, y)
      local h = math.max(14, r.text:GetStringHeight() or 14)
      r:SetHeight(h)
      y = y - h - 5
    end
  end
  card:SetHeight(-y + (moving and 26 or 6))
end

local function Build()
  card = CreateFrame("Frame", "UntamedLootCard", UIParent)
  card:SetSize(WIDTH, 60)
  card:SetFrameStrata("MEDIUM")
  card:Hide()
  local bg = card:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.055, 0.058, 0.075, 0.92)
  local top = card:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(2)
  top:SetColorTexture(0.67, 0.83, 0.45, 0.9)   -- hunter green
  card:SetMovable(true)
  card:EnableMouse(false)
  card:RegisterForDrag("LeftButton")
  card:SetScript("OnDragStart", function(self) if moving then self:StartMoving() end end)
  card:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local s = self:GetScale()
    ns.db.lootPos = { "CENTER", cx * s - ux, cy * s - uy }
    Place()
  end)
  local crest = card:CreateTexture(nil, "ARTWORK")
  crest:SetSize(18, 18)
  crest:SetPoint("TOPLEFT", 10, -9)
  crest:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
  crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  card.title = Text(card, 13, "GameFontNormal")
  card.title:SetPoint("LEFT", crest, "RIGHT", 6, 0)
  card.title:SetWidth(WIDTH - 44)
  card.rows = {}
  for i = 1, CROWS do
    local r = CreateFrame("Frame", nil, card)
    r:SetSize(WIDTH - 20, 14)
    r.text = Text(r, 11)
    r.text:SetPoint("TOPLEFT")
    r.text:SetWidth(WIDTH - 20)
    r.text:SetWordWrap(true)
    r:Hide()
    card.rows[i] = r
  end
  card.hint = Text(card, 10)
  card.hint:SetPoint("BOTTOMLEFT", 10, 8)
  card.hint:Hide()
  card:SetScript("OnUpdate", function(self)
    if hideAt and not moving and GetTime() > hideAt then hideAt = nil self:Hide() end
  end)
  Place()
end

local function Fill(name, d)
  local bs = d and Bosses(name, d) or {}
  card.title:SetText(name and (GOLD .. name .. "|r  " .. MUTED .. L["loot for you"] .. "|r") or (GOLD .. L["Dungeon loot card"] .. "|r"))
  for i, r in ipairs(card.rows) do
    local b = bs[i]
    r:SetShown(b ~= nil)
    if b then
      local items = {}
      for k, it in ipairs(b.loot) do
        if k > 2 then items[#items + 1] = MUTED .. "+" .. (#b.loot - 2) .. "|r" break end
        items[#items + 1] = Short(it)
      end
      r.text:SetText("|cffffffff" .. b.name .. "|r" .. (b.rare and (MUTED .. " (" .. L["rare"] .. ")|r") or "") .. MUTED .. ":|r  "
        .. (#items > 0 and table.concat(items, MUTED .. ", |r") or (MUTED .. L["nothing for you"] .. "|r")))
    end
  end
  if not name then
    card.rows[1]:Show()
    card.rows[1].text:SetText(MUTED .. L["Each boss and the hunter gear it drops for you shows here when you enter a dungeon."] .. "|r")
  end
  Layout()
end

-- quiet: zoning in (fades after 45 sec or at the first pull, unless /ut loot stay is on);
-- /ut loot: stays up until /ut loot again or you leave the dungeon
function ns.ShowLootCard(quiet)
  local name, d = Here()
  if not name then
    if not quiet then ns.Print(DJ() and L["The loot card shows inside a dungeon. /ut loot move places it anywhere."]
      or L["The loot card needs the Dungeon Journal addon (ForeverDungeonJournal)."]) end
    return
  end
  if not card then return end
  if not quiet and pinned and card:IsShown() then
    pinned, hideAt = false, nil
    card:Hide()
    return
  end
  Fill(name, d)
  card:Show()
  pinned = (not quiet) or ns.db.lootStay == true
  hideAt = (not pinned) and (GetTime() + 45) or nil
end

function ns.LootCommand(arg)
  arg = arg or ""
  if not card then return end
  if arg == "" then ns.ShowLootCard()
  elseif arg == "move" or arg == "lock" then
    moving = (arg == "move") and not moving
    card:EnableMouse(moving)
    card.hint:SetShown(moving)
    card.hint:SetText(GOLD .. L["Drag me, then /ut loot lock"] .. "|r")
    if moving then
      Fill(Here())
      card:Show()
      ns.Print(L["Drag the loot card where you want it, then type /ut loot lock."])
    else
      Layout()
      hideAt = GetTime() + 3
    end
  elseif arg:match("^size") then
    local n = tonumber(arg:match("(%d+)"))
    if n then ns.db.lootScale = math.max(0.5, math.min(1.4, n / 100)) end
    Place() Fill(Here()) card:Show()
    if not moving then hideAt = GetTime() + 5 end
  elseif arg == "reset" then
    ns.db.lootPos, ns.db.lootScale = nil, nil
    Place() Fill(Here()) card:Show()
    hideAt = GetTime() + 5
  elseif arg == "stay" then
    ns.db.lootStay = not ns.db.lootStay
    ns.Print(ns.db.lootStay and L["The loot card now stays up the whole dungeon."] or L["The loot card now fades after 45 sec or at your first pull."])
  elseif arg == "need" then
    ns.db.needAlert = ns.db.needAlert == false
    ns.Print(ns.db.needAlert and L["The Need alert for loot rolls is on."] or L["The Need alert for loot rolls is off."])
  elseif arg == "off" or arg == "on" then
    ns.db.lootCard = arg == "on"
    ns.Print(ns.db.lootCard and L["The loot card shows when you enter a dungeon."] or L["The loot card is off (/ut loot on brings it back)."])
  end
end

---------------------------------------------------------------------------
-- Need alert
---------------------------------------------------------------------------
local banner, bannerUntil
local function BuildBanner()
  banner = CreateFrame("Frame", "UntamedNeed", UIParent)
  banner:SetSize(520, 54)
  banner:SetPoint("TOP", UIParent, "TOP", 0, -180)
  banner:SetFrameStrata("HIGH")
  banner:Hide()
  local bg = banner:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.65)
  banner.icon = banner:CreateTexture(nil, "ARTWORK")
  banner.icon:SetSize(36, 36)
  banner.icon:SetPoint("LEFT", 90, 0)
  banner.title = Text(banner, 20, "GameFontNormalLarge")
  banner.title:SetPoint("TOPLEFT", banner.icon, "TOPRIGHT", 10, 2)
  banner.title:SetWidth(360)
  banner.sub = Text(banner, 11)
  banner.sub:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -3)
  banner.sub:SetWidth(360)
  banner:SetScript("OnUpdate", function(self)
    local left = bannerUntil and (bannerUntil - GetTime()) or 0
    if left <= 0 then self:Hide() return end
    self:SetAlpha(math.min(1, left))
  end)
end

function ns.OnLootRoll(rollID)
  if ns.db.needAlert == false then return end
  local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
  if not link or (issecretvalue and issecretvalue(link)) then return end
  local id = tonumber(link:match("item:(%d+)"))
  local gain = ForMe(id)
  if not gain then return end
  if ns.HaveItem(id) then
    ns.Print(MUTED .. string.format(L["You already have %s: greed or pass."], link) .. "|r")
    return
  end
  if gain <= 0 then return end
  local tex = GetLootRollItemInfo and select(1, GetLootRollItemInfo(rollID))
  banner.icon:SetTexture(tex or 134400)
  banner.title:SetText(GOLD .. L["NEED"] .. "|r  " .. link)
  banner.sub:SetText(MUTED .. string.format(L["an upgrade for you (+%d)"], gain) .. "|r")
  bannerUntil = GetTime() + 8
  banner:SetAlpha(1)
  banner:Show()
  pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  ns.Print(GOLD .. L["Need on"] .. "|r " .. link .. MUTED .. string.format(" (" .. L["an upgrade for you (+%d)"] .. ")", gain) .. "|r")
end

do
  local ev = CreateFrame("Frame")
  local lastInstance, refreshing
  for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "START_LOOT_ROLL", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
      if select(2, UnitClass("player")) ~= "HUNTER" then ev:UnregisterAllEvents() return end
      Build() BuildBanner()
      return
    end
    if not card then return end
    if event == "PLAYER_REGEN_DISABLED" then
      if card:IsShown() and not pinned and not moving then hideAt = GetTime() + 3 end
      return
    elseif event == "START_LOOT_ROLL" then
      pcall(ns.OnLootRoll, arg)
      return
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
      if card:IsShown() and not refreshing and not moving then
        refreshing = true
        C_Timer.After(0.5, function()
          refreshing = false
          local name, d = Here()
          if name and card:IsShown() then Fill(name, d) end
        end)
      end
      return
    end
    -- PLAYER_ENTERING_WORLD
    local inside, kind = IsInInstance()
    if not inside or kind ~= "party" then
      lastInstance = nil
      if pinned and not moving then pinned = false card:Hide() end
      return
    end
    local id = select(8, GetInstanceInfo())
    if id ~= lastInstance and ns.db.lootCard ~= false then
      lastInstance = id
      C_Timer.After(3, function() ns.ShowLootCard(true) end)
    end
  end)
end
