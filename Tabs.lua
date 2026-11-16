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
-- Settings, a section at a time: sections down the left, the section's switches on the right, each
-- with a line saying what it does in plain words. `on = true` marks a switch that is on until you
-- turn it off (nothing saved yet counts as on).
local function Repaint()
  if ns.Pins_Refresh then ns.Pins_Refresh() end
  if ns.MinimapRebuild then ns.MinimapRebuild() end
  if ns.RangePaint then ns.RangePaint() end
  if ns.HawkPaint then ns.HawkPaint() end
end

local SECTIONS = {
  { key = "basics", title = L["Basics"], icon = "INV_Misc_Gear_01",
    blurb = L["The few things most people change. Everything else works well left alone."],
    items = {
      { "check", L["Play a sound with alerts"], "targetSound", L["A short sound when Untamed has something to tell you (a rare, a beast your pet needs, a chest)."] },
      { "check", L["Show the minimap button"], "showMinimap", L["The Untamed button on your minimap. /ut opens the window either way."] },
      { "check", L["Open on the Today page"], "openHome", L["Untamed opens on Today (what's worth doing now) instead of the page you left."] },
      { "check", L["Use the controller in this window"], "pad", L["D-pad moves, Cross selects, Circle goes back, L1 and R1 change sections. Your buttons go back to the game when the window closes or a fight starts."], on = true,
        after = function(v) if ns.PadCommand then ns.PadCommand(v and "on" or "off") end end },
      { "button", L["Reset this window's size"], function() if ns.UI_ResetWindow then ns.UI_ResetWindow() end end, L["Back to its starting size, in the middle of the screen. Also /ut window reset."] },
    } },
  { key = "display", title = L["Under your character"], icon = "Ability_Hunter_SniperShot",
    blurb = L["The hunter display: what you watch in a fight, placed just below your character."],
    items = {
      { "check", L["Show the hunter display"], "hud", L["Cooldowns for your main shots and traps, your Serpent Sting and Hunter's Mark timers, and reminders (no aspect on, pet not out, no food buff)."], on = true,
        after = function(v) if ns.HUDCommand then ns.HUDCommand(v and "on" or "off") end end },
      { "check", L["Keep cooldowns on screen outside fights"], "hudAlways", L["Normally the cooldown rows only show while you're fighting."] },
      { "check", L["Show the aspect I have on"], "hudAspect", L["A small icon for your current aspect. In a fight without Aspect of the Hawk it turns into a red Hawk warning."], on = true, after = Repaint },
      { "check", L["Range meter"], "rangeMeter", L["Says whether your target is in melee, too close to shoot, in range or too far, with the distance in yards."], on = true, after = Repaint },
      { "choose", L["Show the range meter"], "rangeMode", { { "always", L["Whenever I target an enemy"] }, { "alerts", L["Only when I'm too close or too far"] } }, "always" },
      { "check", L["Pet watch"], "petWatch", L["Your pet's health and how far it is from you, with a warning when it runs off."], on = true, after = Repaint },
      { "check", L["Hawk timers"], "hawkTracker", L["How long each hawk from Summon Hawk has left."], on = true, after = Repaint },
      { "check", L["Feign Death check"], "feignHelper", L["Tells you whether Feign Death worked."], on = true },
      { "check", L["Auto Shot timer bar"], "autoShotBar", L["A bar that fills between shots. Red means stand still. Shift-drag the bar to move it."] },
      { "button", L["Move the display"], function() if ns.HUDCommand then ns.HUDCommand("move") end end,
        L["Drag it where you want it. Press the button again (or type /ut hud lock) when you're done."] },
      { "button", L["Put it back"], function() if ns.HUDCommand then ns.HUDCommand("reset") end end, L["Back to its place under your character, at normal size."] },
    } },
  { key = "beasts", title = L["Beasts and rares"], icon = "Ability_Hunter_BeastTaming",
    blurb = L["How Untamed tells you about beasts worth taming and rare creatures nearby."],
    items = {
      { "check", L["Tell me when a zone has beasts for my pet"], "zoneAlerts", L["A chat line when you enter a zone with beasts that teach your pet something new."] },
      { "check", L["Alert when I target a beast my pet needs"], "targetAlert", L["Targeting a beast that teaches a rank you don't know says so on screen."] },
      { "check", L["Show what a beast teaches on its tooltip"], "tooltipInfo", L["Hovering a beast shows its family, what it teaches and its attack speed."] },
      { "check", L["Alert when a rare is nearby"], "rareAlert", L["Untamed watches nameplates, your target and your mouseover. Turn on enemy nameplates to spot rares from further away."] },
      { "check", L["Only rares I can tame"], "rareTameableOnly", L["Skips rares that aren't beasts."] },
      { "check", L["Rare pop-up with a Target button"], "rareToast", L["A small box with the rare's name and a button that targets it. Drag it to move it."] },
      { "check", L["Put a skull on rares"], "rareMark", L["Marks a rare with a skull the first time you see it, if it isn't marked yet."] },
      { "check", L["Hide ranks my pet is too low for"], "hideTooHigh", L["Abilities and plans leave out ranks above your pet's level."] },
      { "check", L["Move the arrow on when a beast isn't there"], "arrowNextSpot", L["Reach a spot with no beast and the arrow points to the next closest spot after a few seconds."] },
    } },
  { key = "fight", title = L["In a fight"], icon = "Ability_Hunter_RunningShot",
    blurb = L["Short warnings about mistakes that are easy to make in combat."],
    items = {
      { "check", L["Warn when Growl is on in a group"], "growlWarning", L["Your pet taunting in a dungeon pulls the boss off the tank."] },
      { "check", L["Aspect reminder"], "aspectReminder", L["Warns when you start a fight with Cheetah or Pack on (one hit dazes you), or with no aspect at all."] },
      { "check", L["Hunter's Mark reminder on bosses"], "markReminder", L["A nudge when a boss has no Hunter's Mark."] },
    } },
  { key = "map", title = L["Map and minimap"], icon = "INV_Misc_Map_01",
    blurb = L["What Untamed draws on your world map (and OpenMap) and around your minimap."],
    items = {
      { "check", L["Beasts my pet needs, on the world map"], "autoPins", L["Every spot of every beast that teaches your pet something new, in the zone you're looking at."], after = Repaint },
      { "check", L["Beasts my pet needs, on the minimap"], "minimapPins", L["The same beasts as dots around your minimap when they're close."], after = Repaint },
      { "check", L["Chest spots on the map"], "chestPins", L["Every place a treasure chest can appear. A chest isn't always up at every spot."], on = true, after = Repaint },
      { "check", L["Chest spots on the minimap"], "chestMinimap", L["Orange dots around your minimap for chest spots nearby."], on = true, after = Repaint },
      { "check", L["Library books on the map"], "bookPins", L["Where the library books you still need are."], on = true, after = Repaint },
      { "check", L["Wishlist sources on the map"], "wishPins", L["Where to get the items and beasts on your wishlist."], after = Repaint },
    } },
  { key = "treasure", title = L["Treasure and books"], icon = "INV_Box_02",
    blurb = L["Heads-ups for chests and library books as you travel."],
    items = {
      { "check", L["Tell me about chests"], "chestAlerts", L["An alert when a chest is right in front of you (your interact target)."], on = true },
      { "check", L["Also near a chest spot"], "chestNear", L["A quieter note when you pass within 60 yards of a place a chest can appear. Once per spot every 20 minutes."], on = true },
      { "check", L["Tell me when a library book is near"], "bookAlerts", L["An alert within 300 yards of a book you haven't handed in."], on = true },
    } },
  { key = "pet", title = L["Pet care and supplies"], icon = "INV_Misc_Food_14",
    blurb = L["Keeping your pet fed and alive, and your quiver full."],
    items = {
      { "check", L["Feed reminder with a Feed button"], "feedReminder", L["When your pet isn't happy, a button appears that feeds it the cheapest food that still helps."] },
      { "check", L["Mend Pet and Revive Pet alerts"], "petHealthAlerts", L["Says so on screen when your pet is low on health or has died."] },
      { "check", L["Low ammo warning"], "ammoWarning", L["Warns below 200 arrows or bullets and points you to the nearest ammo vendor."] },
      { "check", L["Restock when I open a vendor"], "autoRestock", L["Buys ammo and pet food up to the amounts below without asking. Off: use the Restock button beside the vendor window."] },
      { "choose", L["Ammo to carry"], "ammoTarget", { { 0, L["Fill my quiver"] }, { 400, "400" }, { 800, "800" }, { 1000, "1000" }, { 1400, "1400" }, { 2000, "2000" } }, 0 },
      { "choose", L["Pet food to carry"], "foodTarget", { { 5, "5" }, { 10, "10" }, { 20, "20" }, { 40, "40" } }, 20 },
    } },
  { key = "gear", title = L["Gear, spells and talents"], icon = "INV_Weapon_Bow_07",
    blurb = L["Help with upgrades, loot, and what to train or spend points on."],
    items = {
      { "check", L["Upgrade line on item tooltips"], "gearTooltip", L["Item tooltips say how much better (or worse) the item is than what you wear."] },
      { "check", L["Tell me about new upgrades"], "gearAlerts", L["A chat line when you level into an upgrade, or arrive in a zone where a vendor sells one."] },
      { "check", L["Upgrade arrows in your bags"], "bagUp", L["A green arrow on gear in your bags that beats what you wear."], on = true },
      { "check", L["Locks on soulbound items"], "bagLock", L["A small lock on bag items that are bound to you: they can't be traded or auctioned."], on = true },
      { "check", L["Coins on items you can sell"], "bagCoin", L["A small coin on unbound gear, bags, trade goods and recipes: the things worth trading or putting on the Auction House. Ammo, food and potions get none."], on = true },
      { "check", L["Quest reward advice"], "questAdvice", L["When a quest lets you pick a reward, a small box beside the quest window says which one to take: the biggest upgrade, or the one that sells for most."], on = true },
      { "check", L["Loot card in dungeons"], "lootCard", L["Targeting a boss shows which of its drops are upgrades for you."], on = true },
      { "check", L["Tell me when to roll Need"], "needAlert", L["When an upgrade for you drops in a group, Untamed says so."], on = true },
      { "check", L["Remind me to train on level up"], "trainerReminder", L["A chat line listing the new spell ranks your level unlocked."] },
      { "check", L["Glow on the next talent"], "talentGlow", L["The talent window highlights where the next point of your chosen build goes."] },
      { "check", L["Tell me the next talent on level up"], "talentPath", L["A chat line saying where to spend the point you just earned."] },
    } },
  { key = "data", title = L["Your data"], icon = "INV_Misc_Note_01",
    blurb = L["Untamed learns from what you see in the game. This is where that lives."],
    items = {
      { "check", L["Note vendors, loot and beasts as I play"], "recordData", L["Who sells what and where, what drops from what, the beasts and chests you come across. Untamed uses it right away to fill gaps, and you can share it to improve the data. /ut recorded shows how much there is."] },
      { "button", L["Export my tame data"], function()
          local text, n = ns.ExportObserved()
          ns.TextPopup(L["Export tame data ("] .. n .. " beasts)", text)
        end, L["When you tame a beast, Untamed notes the abilities it really had. Export that to share corrections."] },
      { "button", L["Import tame data"], function() ns.TextPopup(L["Import tame data"], "", ns.ImportObserved) end, L["Paste data someone else exported."] },
      { "button", L["Check that everything works"], function() if ns.Doctor then ns.Doctor() end end, L["Prints what the game answers for each part of Untamed (the same as /ut doctor). Red lines are worth reporting."] },
      { "button", L["How much memory?"], function() if ns.MemoryReport then ns.MemoryReport() end end, L["Prints how much memory Untamed is using."] },
    } },
}

local function BuildSettings(panel, top)
  local T = ns.Theme
  local current = "basics"
  local side = CreateFrame("Frame", nil, panel)
  side:SetPoint("TOPLEFT", 0, top or -2)
  side:SetPoint("BOTTOMLEFT", 0, 4)
  side:SetWidth(240)
  local scroll = ns.MakeScroll(panel, 250, top or -2, 0, 4)
  local host = CreateFrame("Frame", nil, scroll)
  host:SetSize(480, 1)
  scroll:SetScrollChild(host)
  scroll:SetScript("OnSizeChanged", function(_, w) host:SetWidth(w) end)
  ns.Skin(scroll, T.deep, 0.55, T.line, 0.6)

  local pages, buttons = {}, {}
  local function Show(key)
    current = key
    for k, p in pairs(pages) do p:SetShown(k == key) end
    for k, b in pairs(buttons) do b:SetSelected(k == key) end
    host:SetHeight(pages[key].height)
    scroll:SetVerticalScroll(0)
    if scroll.Sync then scroll.Sync() end
    ns.RefreshControls()
  end

  for i, sec in ipairs(SECTIONS) do
    local b = ns.MakeFlatButton(side, 32)
    b.icon:SetTexture(ns.Icon(sec.icon))
    b.text:SetText(sec.title)
    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 34)
    b:SetPoint("RIGHT", side, "RIGHT", -4, 0)
    b:SetScript("OnClick", function() Show(sec.key) end)
    buttons[sec.key] = b

    local page = CreateFrame("Frame", nil, host)
    page:SetPoint("TOPLEFT", 0, 0)
    page:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    page:SetHeight(10)
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(sec.title)
    local blurb = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    blurb:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetText(ns.C.GREY .. sec.blurb .. "|r")
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", 16, -58)
    rule:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(T.line[1], T.line[2], T.line[3], 0.9)
    local y = -72
    local function Note(text, x, yy)
      local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("TOPLEFT", x, yy)
      fs:SetPoint("RIGHT", page, "RIGHT", -20, 0)
      fs:SetJustifyH("LEFT")
      fs:SetJustifyV("TOP")
      fs:SetHeight(26)
      fs:SetText(ns.C.GREY .. text .. "|r")
    end
    for _, it in ipairs(sec.items) do
      local kind = it[1]
      if kind == "check" then
        local label, key, desc = it[2], it[3], it[4]
        local c = ns.MakeCheck(page, label, 14, y,
          function() if it.on then return ns.db[key] ~= false end return ns.db[key] and true or false end,
          function(v) ns.db[key] = v; if it.after then it.after(v) end end)
        c.label:SetFontObject("GameFontHighlight")
        if desc then Note(desc, 42, y - 22) end
        y = y - (desc and 56 or 30)
      elseif kind == "choose" then
        local label, key, options, default = it[2], it[3], it[4], it[5]
        local fs = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 42, y - 5)
        fs:SetText(label)
        local d = ns.MakeDropdown(page, 230, options, function() local v = ns.db[key]; if v == nil then v = default end return v end,
          function(v) ns.db[key] = v; if ns.RangePaint then ns.RangePaint() end end)
        d:SetPoint("TOPLEFT", 240, y)
        y = y - 34
      elseif kind == "button" then
        local b2 = ns.MakeButton(page, it[2], 200, it[3])
        b2:SetPoint("TOPLEFT", 16, y)
        if it[4] then Note(it[4], 230, y - 5) end
        y = y - 38
      end
    end
    page.height = -y + 20
    page:SetHeight(page.height)
    page:Hide()
    pages[sec.key] = page
  end
  panel:HookScript("OnShow", function() Show(current) end)
  Show(current)
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
