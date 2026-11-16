local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Tab: Pet Care (happiness, diet, food, leveling)
---------------------------------------------------------------------------
do
  local page, feedBtn
  local function Tile(parent, label, anchor, first)
    local t = {}
    t.label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.label:SetText(label)
    if first then t.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16) else t.label:SetPoint("TOPLEFT", anchor.label, "BOTTOMLEFT", 0, -30) end
    t.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
    t.value:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    t.value:SetJustifyH("LEFT")
    t.value:SetWordWrap(false)
    return t
  end
  local function Para(parent, title, anchor, gap)
    local h = ns.MakeHeading(parent, title)
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -18)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
    fs:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(5)
    return fs, h
  end

  local function Build(panel)
    page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 4, -4)
    page:SetPoint("BOTTOMRIGHT", -4, 4)
    ns.Skin(page, ns.Theme.deep, 0.55, ns.Theme.line, 0.6)
    page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    page.empty:SetPoint("CENTER")
    page.empty:SetText(L["Summon your pet to see its care info."])
    local body = CreateFrame("Frame", nil, page)
    body:SetAllPoints()
    page.body = body
    page.box = ns.MakeModelBox(body, 210)
    page.box:SetPoint("TOPLEFT", 12, -12)
    page.name = body:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    page.name:SetPoint("TOPLEFT", page.box, "TOPRIGHT", 14, -2)
    page.sub = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.sub:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -5)
    page.happy = Tile(body, L["Happiness"], page.sub, true)
    page.xp = Tile(body, L["Experience"], page.happy)
    page.tp = Tile(body, L["Training points"], page.xp)
    page.diet = Tile(body, L["Diet"], page.tp)
    feedBtn = ns.CreateFeedButton(body, "UntamedTabFeedButton", 220, 24)
    feedBtn:SetPoint("TOPLEFT", page.box, "BOTTOMLEFT", 0, -12)
    page.food = Para(body, L["Food in your bags it will eat"], feedBtn)
    page.level = Para(body, L["Where to level your pet"], page.food)
  end

  local function Refresh()
    local info = ns.PetCareInfo()
    page.empty:SetShown(not info)
    page.body:SetShown(info and true or false)
    if not info then return end
    local family = ns.ToEnglish and ns.ToEnglish(UnitCreatureFamily("pet")) or UnitCreatureFamily("pet")
    page.box:Unit("pet", ns.Icon(ns.FamilyIcons[family] or "Ability_Hunter_BeastTaming"))
    page.name:SetText(UnitName("pet") or L["Pet"])
    local petLevel, playerLevel = UnitLevel("pet"), UnitLevel("player")
    page.sub:SetText(string.format("%s   %s %d%s", ns.FamilyLabel(family or "?"), L["level"], petLevel or 0,
      info.loyalty and (C.GREY .. "   " .. L["loyalty"] .. " " .. info.loyalty .. "|r") or ""))
    page.happy.value:SetText(info.happyText .. (info.damage and (C.GREY .. "   " .. string.format(L["%d%% damage"], info.damage) .. "|r") or ""))
    if info.xp and info.nextXP and info.nextXP > 0 then
      local rate, eta = ns.PetXPRate()
      page.xp.value:SetText(string.format("%d / %d   %d%%", info.xp, info.nextXP, info.xp * 100 / info.nextXP)
        .. (rate and (C.GREY .. "   " .. string.format(L["%d an hour"], rate) .. (eta and (", " .. string.format(L["next level in about %d min"], eta)) or "") .. "|r") or ""))
    else
      page.xp.value:SetText(C.GREY .. "-|r")
    end
    page.tp.value:SetText(info.tpFree and string.format(L["%d free of %d"], info.tpFree, info.tpTotal or 0) or (C.GREY .. "-|r"))
    page.diet.value:SetText(#info.diet > 0 and table.concat(info.diet, ", ") or "?")

    local lines = {}
    for i, f in ipairs(info.food) do
      if i > 8 then lines[#lines + 1] = C.GREY .. string.format(L["and %d more"], #info.food - 8) .. "|r" break end
      lines[#lines + 1] = string.format("%s%s|r%s   x%d   %s %d|r%s", C.WHITE, f[6], C.GREY, f[4], L["item level"], f[5],
        i == 1 and (C.GREEN .. "   " .. L["fed first"] .. "|r") or "")
    end
    page.food:SetText(#lines > 0 and table.concat(lines, "\n") or (C.RED .. L["None. Buy or loot something from its diet."] .. "|r"))

    lines = {}
    if petLevel and petLevel > 0 then
      if petLevel >= playerLevel then
        lines[1] = C.GREY .. L["Your pet is at your level and gains no more experience until you level."] .. "|r"
      else
        local zones, lo = ns.LevelingZones(petLevel, playerLevel)
        lines[1] = C.GREY .. string.format(L["Mobs level %d and up give it experience (never above your own level)."], lo) .. "|r"
        for i = 1, math.min(5, #zones) do
          local z = zones[i]
          lines[#lines + 1] = C.WHITE .. ns.ZoneName(z.mapID) .. "|r" .. C.GREY .. "   " .. string.format(L["mobs %d-%d"], z.min, z.max) .. "|r"
        end
      end
    end
    page.level:SetText(table.concat(lines, "\n"))
  end
  ns.RegisterTab("care", L["Pet Care"], Build, Refresh)
end

---------------------------------------------------------------------------
-- Data sharing: export and import tame recordings
---------------------------------------------------------------------------
local function Clean(s) return (tostring(s or ""):gsub("[;,:|=]", "")) end

function ns.ExportObserved()
  local parts = { "UNTAMED-DATA1", ns.FLAVOR }
  for npcId, o in pairs(ns.db.observed[ns.FLAVOR]) do
    local sp = {}
    for a, r in pairs(o.spells or {}) do sp[#sp + 1] = Clean(a) .. "=" .. r end
    parts[#parts + 1] = table.concat({ npcId, Clean(o.family), o.level or 0, Clean(o.name), o.map or 0, o.x or 0, o.y or 0 }, ",") .. ":" .. table.concat(sp, "|")
  end
  return table.concat(parts, ";"), #parts - 2
end

function ns.ImportObserved(text)
  local entries = { strsplit(";", text or "") }
  if entries[1] ~= "UNTAMED-DATA1" then ns.Print(L["That doesn't look like Untamed tame data."]) return end
  if entries[2] ~= ns.FLAVOR then ns.Print(L["That data is for "] .. tostring(entries[2]) .. ", not this game version.") return end
  local n = 0
  for i = 3, #entries do
    local head, body = entries[i]:match("^([^:]*):(.*)$")
    if head then
      local id, fam, lvl, name, map, x, y = strsplit(",", head)
      id = tonumber(id)
      if id then
        local spells = {}
        for a, r in body:gmatch("([^|=]+)=(%d+)") do spells[a] = tonumber(r) end
        ns.db.observed[ns.FLAVOR][id] = { name = name, family = fam, level = tonumber(lvl), spells = spells,
          map = tonumber(map) ~= 0 and tonumber(map) or nil, x = tonumber(x), y = tonumber(y) }
        n = n + 1
      end
    end
  end
  ns.Print(L["Imported "] .. n .. " recorded beasts. /reload to merge them into the lists.")
end

---------------------------------------------------------------------------
-- Settings (in the Untamed window and in the game's Options > AddOns)
---------------------------------------------------------------------------
local function BuildSettings(panel, top)
  -- Everything sits in a scroll area so the list can grow.
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, top or -2)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local host = CreateFrame("Frame", nil, scroll)
  host:SetSize(480, 1)
  scroll:SetScrollChild(host)
  scroll:SetScript("OnSizeChanged", function(_, w) host:SetWidth(w) end)

  local y = -4
  local function heading(text)
    if y < -10 then y = y - 8 end
    local h = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 8, y)
    h:SetText(text)
    local line = host:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 8, y - 16)
    line:SetPoint("RIGHT", host, "RIGHT", -8, 0)
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.25)
    y = y - 22
  end
  local function choose(label, key, options, default)
    local fs = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 16, y - 5)
    fs:SetText(label)
    local d = ns.MakeDropdown(host, 110, options, function() return ns.db[key] or default end, function(v) ns.db[key] = v end)
    d:SetPoint("TOPLEFT", 230, y)
    y = y - 26
  end
  local function check(label, key, tip)
    ns.MakeCheck(host, label, 12, y, function() return ns.db[key] end, function(v) ns.db[key] = v end, tip)
    y = y - 24
  end

  heading(L["Taming and maps"])
  check(L["Zone alerts in chat"], "zoneAlerts", L["Print a message when you enter a zone with beasts that teach your pet something new."])
  check(L["World map: pins for every beast my pet needs"], "autoPins")
  check(L["Minimap: pins for nearby beasts my pet needs"], "minimapPins")
  check(L["Tooltips: show what a beast teaches"], "tooltipInfo")
  check(L["Alert when I target a beast my pet needs"], "targetAlert")
  check(L["Alert when a rare is nearby"], "rareAlert", L["Watches nameplates, your target and mouseover. Turn on enemy nameplates to spot rares from further away."])
  check(L["Only tameable rares"], "rareTameableOnly")
  check(L["Rare pop-up with a Target button"], "rareToast", L["Drag the pop-up to move it."])
  check(L["Put a skull on rares"], "rareMark", L["Marks a rare with a skull when you first see it, if it isn't marked yet."])
  check(L["Hide ranks above my pet's level"], "hideTooHigh")
  check(L["Arrow moves on to the next spawn spot"], "arrowNextSpot", L["When you reach a spot and the beast isn't there, the arrow points to the next closest spot after a few seconds. Shift-right-click the arrow (or /ut spot) to skip ahead."])

  heading(L["Combat"])
  check(L["Auto Shot timer bar"], "autoShotBar", L["Shows while Auto Shot is on. Red means stand still. Shift-drag the bar to move it."])
  check(L["Warn when Growl is on in a group"], "growlWarning")
  check(L["Aspect reminders in combat"], "aspectReminder", L["Warns when Cheetah or Pack is on in combat, or no aspect is on."])
  check(L["Hunter's Mark reminder on bosses"], "markReminder")
  check(L["Alert when traps, Feign Death or Tranquilizing Shot are resisted"], "resistAlerts")

  heading(L["Pet and supplies"])
  check(L["Feed reminder and pop-up Feed button"], "feedReminder")
  check(L["Mend Pet and Revive Pet alerts"], "petHealthAlerts")
  check(L["Restock automatically when I open a vendor"], "autoRestock", L["Otherwise use the Restock button beside the vendor window."])
  choose(L["Restock ammo up to"], "ammoTarget", { { 400, "400" }, { 800, "800" }, { 1000, "1000" }, { 1400, "1400" }, { 2000, "2000" } }, 1000)
  choose(L["Restock pet food up to"], "foodTarget", { { 5, "5" }, { 10, "10" }, { 20, "20" }, { 40, "40" } }, 20)
  check(L["Low ammo warning"], "ammoWarning", L["Warns below 200 arrows or bullets and points you to the nearest ammo vendor."])
  check(L["New spell ranks reminder on level up"], "trainerReminder")

  heading(L["Character"])
  check(L["Gear upgrade line on item tooltips"], "gearTooltip")
  check(L["Mark upgrades and wishlist items at the Auction House"], "ahHelper")
  check(L["Tell me about new gear upgrades"], "gearAlerts", L["When you level up, and when you arrive in a zone where a vendor sells an upgrade."])
  check(L["Glow on the next talent in the talent window"], "talentGlow")

  heading(L["General"])
  check(L["Play a sound with alerts"], "targetSound")
  check(L["Show minimap button"], "showMinimap")

  heading(L["Share data"])
  check(L["Record vendors and loot as I play"], "recordData",
    L["Notes who sells what, where and for how much, and what drops from what. Untamed uses it right away to fill gaps in its data, and you can share it to improve Untamed for everyone. Type /ut recorded to see how much has been recorded."])
  local exp = ns.MakeButton(host, L["Export my tame data"], 160, function()
    local text, n = ns.ExportObserved()
    ns.TextPopup(L["Export tame data ("] .. n .. " beasts)", text)
  end)
  exp:SetPoint("TOPLEFT", 12, y)
  local imp = ns.MakeButton(host, L["Import tame data"], 160, function()
    ns.TextPopup(L["Import tame data"], "", ns.ImportObserved)
  end)
  imp:SetPoint("LEFT", exp, "RIGHT", 6, 0)
  y = y - 30
  local note = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 12, y)
  note:SetPoint("RIGHT", host, "RIGHT", -12, 0)
  note:SetJustifyH("LEFT")
  note:SetText(C.GREY .. L["When you tame a beast, Untamed records the abilities it really had. Export that data to share corrections."] ..
    (ns.FLAVOR == "forever" and " This matters most on Forever, where public data is still incomplete." or "") ..
    "\nKey bindings: Options > Keybindings > AddOns > Untamed.   Type /untamed help for slash commands.|r")
  host:SetHeight(-y + 60)
end
ns.BuildSettings = BuildSettings

ns.RegisterTab("settings", L["Settings"], function(panel) BuildSettings(panel) end, function() end)
ns.On("REFRESH", function() ns.Fire("MINIMAP_TOGGLE") end)

-- No page in Blizzard's Settings window: on WoW Forever's controller UI an addon page there
-- poisons the face buttons when Settings closes. Untamed's settings live on its own Settings tab.

---------------------------------------------------------------------------
-- Data broker launcher (button collectors and LibDBIcon, when present)
---------------------------------------------------------------------------
ns.On("LOGIN", function()
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  if not LDB then return end
  local launcher = LDB:NewDataObject("Untamed", {
    type = "launcher", text = "Untamed", icon = "Interface\\AddOns\\Untamed\\Media\\Icon",
    OnClick = function(_, button) if button == "RightButton" then ns.ZoneAlert(true) else ns.UI_Toggle() end end,
    OnTooltipShow = function(tt)
      tt:AddLine("|cffabd473Untamed|r")
      tt:AddLine(L["Left-click: open window"], 1, 1, 1)
      tt:AddLine(L["Right-click: check this zone"], 1, 1, 1)
    end,
  })
  local icon = LibStub("LibDBIcon-1.0", true)
  if icon then
    ns.db.ldbIcon = ns.db.ldbIcon or { hide = not ns.db.showMinimap }
    icon:Register("Untamed", launcher, ns.db.ldbIcon)
    ns.usingLDBIcon = true
    ns.Fire("MINIMAP_TOGGLE")
  end
end)

---------------------------------------------------------------------------
-- Key bindings (Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_UNTAMED = "Untamed"
BINDING_NAME_UNTAMED_TOGGLE = L["Open or close the window"]
BINDING_NAME_UNTAMED_NEXT = L["Next route stop"]
BINDING_NAME_UNTAMED_CLEAR = L["Clear the arrow and map focus"]
BINDING_NAME_UNTAMED_NEXTSPOT = L["Arrow: next spawn spot"]
BINDING_NAME_UNTAMED_ZONE = L["Check this zone"]
function Untamed_Toggle() ns.UI_Toggle() end
function Untamed_NextStop() ns.Route_Next() end
function Untamed_Clear() ns.Pins_Clear(); ns.Arrow_Clear() end
function Untamed_NextSpot() ns.Arrow_NextSpot() end
function Untamed_Zone() ns.ZoneAlert(true) end
