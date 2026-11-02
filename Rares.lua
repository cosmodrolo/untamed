local _, ns = ...
local L = ns.L
local C = ns.C

-- Rare finder: spots every rare (tameable or not) on nameplates, target, mouseover and, where the
-- game has them, map vignettes. Shows a pop-up with a Target button, remembers where and when you
-- saw each rare, and lists every rare in your zone on the Rares page.

local function Seen()
  ns.db.rareSeen = ns.db.rareSeen or {}
  ns.db.rareSeen[ns.FLAVOR] = ns.db.rareSeen[ns.FLAVOR] or {}
  return ns.db.rareSeen[ns.FLAVOR]
end

local function Here()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return map end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  if not x or ns.IsSecret(x) then return map end
  return map, x * 100, y * 100
end

local function Ago(t)
  local d = time() - (t or 0)
  if d < 90 then return L["just now"] end
  if d < 5400 then return string.format(L["%d min ago"], d / 60) end
  if d < 172800 then return string.format(L["%d h ago"], d / 3600) end
  return string.format(L["%d days ago"], d / 86400)
end
ns.Ago = Ago

---------------------------------------------------------------------------
-- Pop-up with a Target button
---------------------------------------------------------------------------
local toast
local function MakeToast()
  toast = CreateFrame("Frame", "UntamedRareToast", UIParent, "BackdropTemplate")
  toast:SetSize(260, 62)
  local pos = ns.db.rareToastPos
  if pos then toast:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else toast:SetPoint("TOP", 0, -120) end
  toast:SetFrameStrata("HIGH")
  if toast.SetBackdrop then
    toast:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  end
  toast:SetMovable(true)
  toast:EnableMouse(true)
  toast:RegisterForDrag("LeftButton")
  toast:SetScript("OnDragStart", toast.StartMoving)
  toast:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.rareToastPos = { p, rp, x, y }
  end)
  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  toast.icon:SetSize(36, 36)
  toast.icon:SetPoint("LEFT", 10, 0)
  toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 8, -1)
  toast.title:SetPoint("RIGHT", -28, 0)
  toast.title:SetJustifyH("LEFT")
  toast.title:SetWordWrap(false)
  toast.sub = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  toast.sub:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
  toast.sub:SetPoint("RIGHT", -10, 0)
  toast.sub:SetJustifyH("LEFT")
  toast.sub:SetWordWrap(false)
  -- Targeting is a protected action, so the button is a secure macro button set up out of combat.
  toast.target = CreateFrame("Button", "UntamedRareTargetButton", toast, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  toast.target:SetSize(80, 18)
  toast.target:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 8, -4)
  toast.target:SetText(L["Target"])
  toast.target:SetAttribute("type", "macro")
  toast.target:RegisterForClicks("AnyUp", "AnyDown")
  toast.arrow = ns.MakeButton(toast, L["Arrow"], 70, function() ns.NavigateLastRare() end)
  toast.arrow:SetHeight(18)
  toast.arrow:SetPoint("LEFT", toast.target, "RIGHT", 4, 0)
  local close = CreateFrame("Button", nil, toast, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  toast:Hide()
end

local function ShowToast(name, sub, icon)
  if not ns.db.rareToast then return end
  if not toast then MakeToast() end
  toast.title:SetText(name)
  toast.sub:SetText(sub)
  toast.icon:SetTexture(icon or ns.Icon("Ability_Hunter_SniperShot"))
  if not InCombatLockdown() then
    toast.target:SetAttribute("macrotext", "/targetexact " .. name)
    toast.target:Enable()
  end
  toast:Show()
  toast.hideAt = GetTime() + 30
  toast:SetScript("OnUpdate", function(self) if GetTime() > (self.hideAt or 0) then self:Hide(); self:SetScript("OnUpdate", nil) end end)
end

---------------------------------------------------------------------------
-- Scanner
---------------------------------------------------------------------------
local cooldown = {}
local function Announce(npcId, name, level, classification, unit)
  local now = GetTime()
  local key = npcId or name
  if cooldown[key] and now - cooldown[key] < 600 then return end
  cooldown[key] = now
  local beast = npcId and ns.Beasts[npcId]
  local tameable = beast ~= nil
  if ns.db.rareTameableOnly and not tameable then return end
  local map, x, y = Here()
  if npcId then Seen()[npcId] = { t = time(), map = map, x = x, y = y, name = name } end
  ns.lastRare = npcId
  ns.lastRareName = name
  local lvl = (level and level > 0) and tostring(level) or "??"
  local kind = classification == "rareelite" and L["Rare elite"] or L["Rare"]
  local what
  if beast then
    what = string.format("%s %s, %s", kind, ns.FamilyLabel(beast[4]), L["tameable"])
    if #beast[6] > 0 then what = what .. ", " .. L["teaches "] .. ns.TeachesText(beast) end
  else
    what = kind
  end
  local msg = string.format("%s%s|r  %s%s %s|r", tameable and C.HUNTER or C.ORANGE, name, C.GREY, L["level"], lvl)
  if ns.Alert then ns.Alert(msg .. "  " .. what, ns.db.targetSound) end
  ns.Print(name .. " (" .. L["level"] .. " " .. lvl .. "): " .. what .. ". " .. L["Type /ut rare for an arrow."])
  ShowToast(name, C.GREY .. L["level"] .. " " .. lvl .. "  " .. "|r" .. what,
    beast and ns.Icon(ns.FamilyIcons[beast[4]] or "Ability_Hunter_BeastTaming") or nil)
  if unit and ns.db.rareMark and GetRaidTargetIndex and not GetRaidTargetIndex(unit) and SetRaidTarget then
    pcall(SetRaidTarget, unit, 8)
  end
end

function ns.CheckRare(unit)
  if not ns.db or not ns.db.rareAlert or not unit then return end
  local ok, guid = pcall(UnitGUID, unit)
  if not ok or not guid then return end
  local cls = UnitClassification and UnitClassification(unit)
  if ns.IsSecret(cls) then return end
  local npcId = ns.NpcIdFromGUID(guid)
  local beast = npcId and ns.Beasts[npcId]
  local isRare = cls == "rare" or cls == "rareelite" or (beast and beast[5] and beast[5]:find("Rare"))
  if not isRare then return end
  if UnitIsDead and UnitIsDead(unit) then return end
  if UnitIsPlayer and UnitIsPlayer(unit) then return end
  local name = UnitName(unit)
  if not name or ns.IsSecret(name) then return end
  Announce(npcId, name, UnitLevel(unit), cls, unit)
end

-- Map vignettes (only where the game shows them for rares).
local function CheckVignettes()
  if not ns.db.rareAlert or not C_VignetteInfo or not C_VignetteInfo.GetVignettes then return end
  local ok, list = pcall(C_VignetteInfo.GetVignettes)
  if not ok or type(list) ~= "table" then return end
  for _, guid in ipairs(list) do
    local ok2, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
    if ok2 and info and info.name and not ns.IsSecret(info.name) and info.objectGUID then
      local npcId = ns.NpcIdFromGUID(info.objectGUID)
      if npcId and not info.isDead then Announce(npcId, info.name, nil, "rare", nil) end
    end
  end
end

do
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if toast and toast:IsShown() and ns.lastRareName then toast.target:SetAttribute("macrotext", "/targetexact " .. ns.lastRareName) end
    else
      CheckVignettes()
    end
  end)
end

ns.On("LOGIN", function()
  for k, v in pairs({ rareToast = true, rareMark = false, rareTameableOnly = false }) do
    if ns.db[k] == nil then ns.db[k] = v end
  end
end)

function ns.NavigateLastRare()
  local id = ns.lastRare
  if id and ns.Beasts[id] then ns.Navigate(id) return end
  local s = id and Seen()[id]
  if s and s.map and s.x then ns.Arrow_Set(s.map, s.x, s.y, s.name or ns.lastRareName or L["Rare"]) return end
  local db = ns.SearchDB and ns.SearchDB()
  local n = id and db and db.N[id]
  if n and n[5] ~= 0 then ns.Arrow_Set(n[5], n[6], n[7], n[1]) return end
  ns.Print(L["No rare spotted yet this session."])
end

---------------------------------------------------------------------------
-- Rares page
---------------------------------------------------------------------------
do
  local list
  local opt = { where = "zone" }
  local WHERE = { { "zone", L["This zone"] }, { "level", L["Near my level, anywhere"] }, { "seen", L["Ones I've seen"] } }
  local function Build(panel)
    local d = ns.MakeDropdown(panel, 190, WHERE, function() return opt.where end, function(v) opt.where = v end)
    d:SetPoint("TOPLEFT", 4, -2)
    list = ns.NewList(panel, 30)
  end

  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local db = ns.SearchDB and ns.SearchDB()
    if not db then add(0, nil, C.RED .. L["Search data is missing."] .. "|r"); list:Set(rows) return end
    local map = Here()
    -- Zone maps can be sub-zones; compare against the zone the player is in.
    local zone = map
    if map and C_Map.GetMapInfo then
      local info = C_Map.GetMapInfo(map)
      while info and info.mapType and info.mapType > 3 and info.parentMapID and info.parentMapID ~= 0 do
        zone = info.parentMapID
        info = C_Map.GetMapInfo(zone)
      end
    end
    local level = UnitLevel("player")
    local seen = Seen()
    local pc, pe, pn = ns.PlayerWorld()
    local ids = {}
    for id, n in pairs(db.N) do
      if n[9] == 2 or n[9] == 4 then
        local keep
        if opt.where == "zone" then keep = (n[5] == zone or n[5] == map)
        elseif opt.where == "level" then keep = n[3] >= level - 3 and n[2] <= level + 5
        else keep = seen[id] ~= nil end
        if keep then ids[#ids + 1] = id end
      end
    end
    local dist = {}
    for _, id in ipairs(ids) do local n = db.N[id]; dist[id] = ns.DistTo and ns.DistTo(n[5], n[6], n[7], pc, pe, pn) or nil end
    table.sort(ids, function(a, b)
      local x, y = db.N[a], db.N[b]
      if opt.where == "seen" then return (seen[a].t or 0) > (seen[b].t or 0) end
      if (dist[a] ~= nil) ~= (dist[b] ~= nil) then return dist[a] ~= nil end
      if dist[a] and dist[b] and dist[a] ~= dist[b] then return dist[a] < dist[b] end
      return x[2] < y[2]
    end)
    add(0, nil, string.format(L["%d rares"], #ids), C.GREY .. L["click for an arrow"] .. "|r", nil,
      { L["Rare finder"], L["Untamed watches nameplates, your target and your mouseover for rares. Turn on enemy nameplates (V) to spot them from further away."],
        L["Tameable rares are green. Right-click a tameable one to pin it on the map."] }, { header = true })
    for i = 1, math.min(150, #ids) do
      local id = ids[i]
      local n = db.N[id]
      local beast = ns.Beasts[id]
      local s = seen[id]
      local lvl = n[2] == n[3] and tostring(n[2]) or (n[2] .. "-" .. n[3])
      local where = n[10] ~= "" and (C.ORANGE .. n[10] .. "|r") or (n[5] ~= 0 and ns.ZoneName(n[5]) or L["unknown location"])
      local right = (s and (C.GREEN .. L["seen "] .. Ago(s.t) .. "|r  ") or "") .. C.GREY .. where .. (dist[id] and (", " .. ns.FormatDistance(dist[id])) or "") .. "|r"
      local label = (beast and C.HUNTER or C.WHITE) .. n[1] .. "|r" .. (n[9] == 2 and (C.ORANGE .. "  " .. L["elite"] .. "|r") or "")
        .. (beast and (C.GREY .. "  " .. ns.FamilyLabel(beast[4]) .. "|r") or "")
      add(0, ns.Icon(beast and (ns.FamilyIcons[beast[4]] or "Ability_Hunter_BeastTaming") or "Ability_Hunter_SniperShot"), label, right,
        function(_, button)
          if beast then
            if button == "RightButton" then ns.Pins_Focus({ id }, n[1], true) else ns.Navigate(id) end
          elseif s and s.map and s.x then ns.Arrow_Set(s.map, s.x, s.y, n[1])
          elseif n[5] ~= 0 then ns.Arrow_Set(n[5], n[6], n[7], n[1]) end
        end,
        beast and ns.BeastTooltip(id, { s and (C.GREEN .. L["You saw it "] .. Ago(s.t) .. "|r") or nil })
          or { n[1], L["Level "] .. lvl .. (n[9] == 2 and (" " .. L["elite"]) or ""), where,
               s and (C.GREEN .. L["You saw it "] .. Ago(s.t) .. "|r") or "", C.GREY .. L["Click for an arrow."] .. "|r" },
        { mid = ((n[3] > level + 2) and C.RED or C.GREY) .. lvl .. "|r" })
    end
    if #ids == 0 then add(0, nil, C.GREY .. L["No rares here."] .. "|r") end
    list:Set(rows)
  end
  ns.RegisterTab("rares", L["Rares"], Build, Refresh)
end

ns.RareTest = { Announce = Announce, CheckVignettes = CheckVignettes }
