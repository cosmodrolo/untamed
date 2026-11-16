local _, ns = ...
local L = ns.L
local C = ns.C

---------------------------------------------------------------------------
-- Bestiary: every tameable beast as a journal. A list on the left (search, a few filters), the
-- beast's page on the right: its model, the facts that matter, what it teaches and whether that's
-- new to you, where it is, and Hunt / Map / Wishlist.
--   * The search box reads plain words: "fast cat", "bite 6", "rare badlands", "new", "30-40".
--   * With a controller, moving through the list turns the pages; D-pad right goes to the page's
--     buttons. With a mouse: click a beast to open its page, click it again for the arrow.
---------------------------------------------------------------------------

local list, page, left
local filter = { family = "any", text = "", tameable = false, rare = false, teaches = "any", where = "any", sort = "level", fresh = false }
local selected            -- npc id on the page
local rowIds = {}         -- [row index] = npc id
local spec = {}           -- the parsed search text

---------------------------------------------------------------------------
-- Search: plain words into filters
---------------------------------------------------------------------------
local WORDS = {
  fast = "fast", faster = "fast", quick = "fast", slow = "slow", slower = "slow",
  rare = "rare", rares = "rare", new = "fresh", tameable = "tame", now = "tame", wished = "wish", wishlist = "wish",
}

local function Plain(s) return (s:lower():gsub("[^%w%s%-']", " ")) end

-- { family =, abilities = { { name, rank? } }, fast =, slow =, rare =, fresh =, tame =, wish =, lo =, hi =, words = { ... } }
function ns.BestiaryParse(text)
  local out = { abilities = {}, words = {} }
  local s = " " .. Plain(text or "") .. " "
  -- abilities first (longest names first, so "furious howl" isn't read as two words), with a rank after
  local names = {}
  for a in pairs(ns.AbilityFamilies or {}) do names[#names + 1] = a end
  table.sort(names, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
  for _, a in ipairs(names) do
    for _, label in ipairs({ a:lower(), (ns.AbilityLabel(a) or a):lower() }) do
      local i, j = s:find(" " .. label:gsub("%p", "%%%0") .. " ", 1)
      if i then
        local rank = s:sub(j):match("^ (%d+) ")
        out.abilities[#out.abilities + 1] = { a, rank and tonumber(rank) or nil }
        s = s:sub(1, i) .. (rank and s:sub(j + #rank + 1) or s:sub(j))
        break
      end
    end
  end
  -- a family, singular or plural
  local fams = {}
  for _, f in ipairs(ns.Families or {}) do fams[#fams + 1] = f end
  table.sort(fams, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
  for _, f in ipairs(fams) do
    if not out.family then
      for _, label in ipairs({ f:lower(), (ns.FamilyLabel(f) or f):lower() }) do
        local pat = label:gsub("%p", "%%%0")
        local i, j = s:find(" " .. pat .. "s? ")
        if not i and label:sub(-1) == "y" then i, j = s:find(" " .. pat:sub(1, -2) .. "ies ") end
        if not i and label:sub(-1) == "f" then i, j = s:find(" " .. pat:sub(1, -2) .. "ves ") end
        if i then out.family = f; s = s:sub(1, i) .. s:sub(j); break end
      end
    end
  end
  for w in s:gmatch("%S+") do
    local lo, hi = w:match("^(%d+)%-(%d+)$")
    if lo then
      out.lo, out.hi = tonumber(lo), tonumber(hi)
    elseif w:match("^%d+$") then
      out.lo, out.hi = tonumber(w), tonumber(w)
    elseif WORDS[w] then
      out[WORDS[w]] = true
    elseif w ~= "lvl" and w ~= "level" then
      out.words[#out.words + 1] = w
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Which beasts
---------------------------------------------------------------------------
local function Teaches(b, ability, rank)
  for i = 1, #b[6], 2 do
    if b[6][i] == ability and (not rank or b[6][i + 1] == rank) then return true end
  end
  return false
end

local function TeachesNew(b)
  for i = 1, #b[6], 2 do
    if not ns.HunterKnows(b[6][i], b[6][i + 1]) then return true end
  end
  return false
end

local function IsRare(b) return b[5] and b[5]:find("Rare") and true or false end

local function Matches(id, b, playerLevel, zone)
  if filter.family ~= "any" and b[4] ~= filter.family then return false end
  if spec.family and b[4] ~= spec.family then return false end
  if (filter.tameable or spec.tame) and b[2] > playerLevel then return false end
  if (filter.rare or spec.rare) and not IsRare(b) then return false end
  if (filter.fresh or spec.fresh) and not TeachesNew(b) then return false end
  if spec.wish and not (ns.BeastWished and ns.BeastWished(id)) then return false end
  if spec.fast and not (b[9] and b[9] < 2.0) then return false end
  if spec.slow and not (b[9] and b[9] > 2.0) then return false end
  if spec.lo and (b[3] < spec.lo or b[2] > spec.hi) then return false end
  if filter.teaches == "some" and #b[6] == 0 then return false end
  if filter.teaches ~= "any" and filter.teaches ~= "some" and not Teaches(b, filter.teaches) then return false end
  for _, a in ipairs(spec.abilities or {}) do
    if not Teaches(b, a[1], a[2]) then return false end
  end
  if filter.where == "zone" and not (zone and b[7][zone]) then return false end
  if spec.words and #spec.words > 0 then
    local hay = b[1]:lower() .. " " .. (b[8] or ""):lower() .. " " .. (b[10] or ""):lower()
    for mapID in pairs(b[7]) do hay = hay .. " " .. (ns.ZoneName(mapID)):lower() end
    for _, w in ipairs(spec.words) do
      if not hay:find(w, 1, true) then return false end
    end
  end
  return true
end
ns.BestiaryMatches = function(text, id)
  local old = spec
  spec = ns.BestiaryParse(text)
  local ok = Matches(id, ns.Beasts[id], 60, nil)
  spec = old
  return ok
end

---------------------------------------------------------------------------
-- The page on the right
---------------------------------------------------------------------------
local function SpeedText(s)
  if not s then return C.GREY .. L["not known"] .. "|r" end
  local color = (s < 2.0) and C.GREEN or (s > 2.0 and C.ORANGE or C.WHITE)
  return color .. string.format("%.1f s", s) .. "|r"
    .. C.GREY .. "  " .. ((s < 2.0) and L["fast"] or (s > 2.0 and L["slow"] or L["normal"])) .. "|r"
end

local function Signed(n) return (n > 0 and "+" or "") .. n end

local function FillPage()
  if not page then return end
  local id = selected
  local b = id and ns.Beasts[id]
  page.empty:SetShown(not b)
  page.body:SetShown(b and true or false)
  if not b then return end

  -- the model (the family's icon sits behind it, for beasts the game hasn't shown you yet)
  page.icon:SetTexture(ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"))
  if page.modelId ~= id then
    page.modelId = id
    page.facing = 0.5
    if page.model.ClearModel then pcall(page.model.ClearModel, page.model) end
    local ok = page.model.SetCreature and pcall(page.model.SetCreature, page.model, id)
    page.model:SetShown(ok and true or false)
    if ok and page.model.SetFacing then pcall(page.model.SetFacing, page.model, page.facing) end
  end

  local playerLevel = UnitLevel("player")
  local rare = IsRare(b)
  page.name:SetText((rare and C.ORANGE or "") .. b[1] .. (rare and "|r" or ""))
  local tooHigh = b[2] > playerLevel
  page.sub:SetText(string.format("%s%s   %s %s%s", ns.FamilyLabel(b[4]), rare and (C.ORANGE .. "  " .. L["rare"] .. "|r") or "",
    L["level"], ns.LevelText(b), tooHigh and (C.RED .. "   " .. L["too high to tame yet"] .. "|r") or ""))

  page.speed.value:SetText(SpeedText(b[9]))
  local mapID, x, y, d = ns.NearestSpawn(id)
  page.where.value:SetText(ns.ZonesText(b))
  page.near.value:SetText(mapID and string.format("%s %.0f, %.0f%s", ns.ZoneName(mapID), x, y,
    d and (C.GREY .. "   " .. ns.FormatDistance(d) .. "|r") or "") or (C.GREY .. (b[8] and L["inside a dungeon"] or L["no spot known"]) .. "|r"))

  -- what it teaches, and whether that's news to you
  local t = ns.Target()
  local lines = {}
  for i = 1, #b[6], 2 do
    local a, r = b[6][i], b[6][i + 1]
    local label = (ns.AbilityLabel(a) or a) .. " " .. r
    if ns.HunterKnows(a, r) then
      lines[#lines + 1] = C.GREY .. label .. "   " .. L["you know it"] .. "|r"
    else
      local fits = t and t.family and ns.AbilityFamilies[a] and ns.AbilityFamilies[a][t.family]
      local petLevel = ns.RankLevel(a, r)
      lines[#lines + 1] = C.GREEN .. label .. "|r   " .. C.WHITE .. (fits and string.format(L["new, and %s can use it"], t.name or ns.FamilyLabel(t.family)) or L["new to you"]) .. "|r"
        .. ((petLevel and petLevel > 1) and (C.GREY .. "   " .. string.format(L["pet level %d"], petLevel) .. "|r") or "")
    end
  end
  if #lines == 0 then lines[1] = C.GREY .. L["Nothing: it comes with no abilities to learn."] .. "|r" end
  page.teaches:SetText(table.concat(lines, "\n"))

  -- good to know
  local notes = {}
  local st = ns.FamilyStats and ns.FamilyStats[b[4]]
  if st then
    notes[#notes + 1] = string.format(L["%s as a family: %s%% damage, %s%% armor, %s%% health."], ns.FamilyLabel(b[4]), Signed(st[1]), Signed(st[2]), Signed(st[3]))
  end
  if b[10] then notes[#notes + 1] = L["Look: "] .. b[10] end
  if b[8] then notes[#notes + 1] = C.ORANGE .. string.format(L["Lives inside %s."], b[8]) .. "|r" end
  if rare then
    local seen = ns.db.rareSeen and ns.db.rareSeen[ns.FLAVOR] and ns.db.rareSeen[ns.FLAVOR][id]
    local when = type(seen) == "table" and (seen.t or seen.time or seen[1]) or (type(seen) == "number" and seen) or nil
    notes[#notes + 1] = when and string.format(L["You last saw it %s."], ns.Ago(when)) or L["You haven't seen it yet. Untamed alerts you when it's near."]
  end
  if ns.BeastWished and ns.BeastWished(id) then notes[#notes + 1] = C.GOLD .. L["On your wishlist."] .. "|r" end
  page.notes:SetText(table.concat(notes, "\n"))

  page.wish:SetText((ns.BeastWished and ns.BeastWished(id)) and L["Off the wishlist"] or L["Wishlist"])
end

local function PaintRow(i, on)
  local r = list and list.rows[i]
  if not r or not rowIds[i] then return end
  if on then
    r.bg:SetColorTexture(1, 0.82, 0, 0.20); r.bg:Show()
  elseif (i - 1) % 2 == 0 then
    r.bg:SetColorTexture(1, 1, 1, 0.04); r.bg:Show()
  else
    r.bg:Hide()
  end
end

local function Select(id)
  if selected == id then return end
  for i, rid in pairs(rowIds) do if rid == selected then PaintRow(i, false) end end
  selected = id
  for i, rid in pairs(rowIds) do if rid == id then PaintRow(i, true) end end
  FillPage()
end
ns.BestiarySelect = function(id) Select(id) end
ns.BestiarySelected = function() return selected end

local function RowClick(id)
  return function(_, button)
    if IsShiftKeyDown() then ns.Waypoint(id) return end
    if IsAltKeyDown() and ns.WishBeast_Toggle then ns.WishBeast_Toggle(id) return end
    if button == "RightButton" then
      Select(id)
      ns.Pins_Focus({ id }, ns.Beasts[id][1], true)
    elseif selected == id then
      ns.Navigate(id)
    else
      Select(id)
    end
  end
end

-- the controller's frame landing on a row opens that beast's page; the mouse gets a short hint
local function RowHover(id)
  return function()
    if ns.padFocusing then Select(id) return nil end
    if selected == id then return { ns.Beasts[id][1], C.GREY .. L["Click: arrow to it.  Right-click: on the map.  Alt-click: wishlist."] .. "|r" } end
    return { ns.Beasts[id][1], C.GREY .. L["Click to open its page."] .. "|r" }
  end
end

local function Tile(parent, label)
  local t = {}
  t.label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  t.label:SetText(label)
  t.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -3)
  t.value:SetJustifyH("LEFT")
  t.value:SetWordWrap(false)
  return t
end

local function Heading(parent, text)
  local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h:SetText(text)
  local rule = parent:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
  rule:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
  rule:SetHeight(1)
  rule:SetColorTexture(1, 0.82, 0, 0.25)
  return h
end

local function BuildPage(panel)
  page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  page:SetPoint("BOTTOMRIGHT", -4, 4)
  local bg = page:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.28)

  page.empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  page.empty:SetPoint("CENTER")
  page.empty:SetText(L["Pick a beast on the left."])

  local body = CreateFrame("Frame", nil, page)
  body:SetAllPoints()
  page.body = body

  local box = CreateFrame("Frame", nil, body)
  box:SetSize(190, 190)
  box:SetPoint("TOPLEFT", 12, -12)
  local boxBg = box:CreateTexture(nil, "BACKGROUND")
  boxBg:SetAllPoints()
  boxBg:SetColorTexture(0, 0, 0, 0.45)
  page.icon = box:CreateTexture(nil, "BORDER")
  page.icon:SetSize(64, 64)
  page.icon:SetPoint("CENTER")
  page.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  page.icon:SetAlpha(0.35)
  page.model = CreateFrame("PlayerModel", nil, box)
  page.model:SetAllPoints()
  page.facing = 0.5
  -- the model turns slowly
  page.model:SetScript("OnUpdate", function(self, e)
    page.facing = (page.facing + e * 0.35) % (2 * math.pi)
    if self.SetFacing then self:SetFacing(page.facing) end
  end)

  page.name = body:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  page.name:SetPoint("TOPLEFT", box, "TOPRIGHT", 14, -2)
  page.name:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  page.name:SetJustifyH("LEFT")
  page.name:SetWordWrap(false)
  page.sub = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.sub:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -5)
  page.sub:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  page.sub:SetJustifyH("LEFT")
  page.sub:SetWordWrap(false)

  page.speed = Tile(body, L["Attack speed"])
  page.speed.label:SetPoint("TOPLEFT", page.sub, "BOTTOMLEFT", 0, -16)
  page.where = Tile(body, L["Found in"])
  page.where.label:SetPoint("TOPLEFT", page.speed.label, "BOTTOMLEFT", 0, -30)
  page.where.value:SetPoint("RIGHT", body, "RIGHT", -10, 0)
  page.near = Tile(body, L["Nearest spot"])
  page.near.label:SetPoint("TOPLEFT", page.where.label, "BOTTOMLEFT", 0, -30)
  page.near.value:SetPoint("RIGHT", body, "RIGHT", -10, 0)

  -- one row of buttons, right under the model
  page.hunt = ns.MakeButton(body, L["Hunt it"], 96, function() if selected then ns.Navigate(selected) end end)
  page.hunt:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
  page.hunt:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L["Hunt it"], L["An arrow to its nearest spot, and its spots on your map."] }) end)
  page.hunt:SetScript("OnLeave", function() GameTooltip:Hide() end)
  page.map = ns.MakeButton(body, L["Show on map"], 110, function()
    if selected then ns.Pins_Focus({ selected }, ns.Beasts[selected][1], true) end
  end)
  page.map:SetPoint("LEFT", page.hunt, "RIGHT", 6, 0)
  page.wish = ns.MakeButton(body, L["Off the wishlist"], 120, function()
    if selected and ns.WishBeast_Toggle then ns.WishBeast_Toggle(selected) end
  end)
  page.wish:SetPoint("LEFT", page.map, "RIGHT", 6, 0)
  page.wish:SetScript("OnEnter", function(self) ns.ShowTooltip(self, { L["Wishlist"], L["Keeps its spots on your map and alerts you when it's near."] }) end)
  page.wish:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- on a controller, left from the buttons goes back to this beast's row, not to whichever row is level with them
  local function BackToRow()
    for i, rid in pairs(rowIds) do if rid == selected then return list.rows[i] end end
  end
  page.hunt.padNeighbor = { left = BackToRow }

  local h1 = Heading(body, L["Teaches"])
  h1:SetPoint("TOPLEFT", page.hunt, "BOTTOMLEFT", 0, -18)
  page.teaches = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  page.teaches:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -10)
  page.teaches:SetPoint("RIGHT", body, "RIGHT", -12, 0)
  page.teaches:SetJustifyH("LEFT")
  page.teaches:SetSpacing(5)

  local h2 = Heading(body, L["Good to know"])
  h2:SetPoint("TOPLEFT", page.teaches, "BOTTOMLEFT", 0, -18)
  page.notes = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.notes:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 0, -10)
  page.notes:SetPoint("RIGHT", body, "RIGHT", -12, 0)
  page.notes:SetJustifyH("LEFT")
  page.notes:SetSpacing(5)
end

---------------------------------------------------------------------------
-- The list on the left
---------------------------------------------------------------------------
local function FamilyOptions()
  local o = { { "any", L["All families"] } }
  for _, f in ipairs(ns.Families) do o[#o + 1] = { f, ns.FamilyLabel(f) } end
  return o
end
local function TeachOptions()
  local o = { { "any", L["Any ability"] }, { "some", L["Teaches something"] } }
  for _, a in ipairs(ns.AbilityOrder) do
    if ns.AbilityFamilies[a] and a ~= "Cower" then o[#o + 1] = { a, ns.AbilityLabel(a) } end
  end
  return o
end
local SORTS = { { "level", L["By level"] }, { "name", L["By name"] }, { "speed", L["Fastest first"] }, { "near", L["Nearest first"] } }

local function Chip(parent, text, get, set, tip)
  local b = ns.MakeFlatButton(parent, 22)
  b.icon:SetTexture(nil)
  b.icon:SetWidth(1)
  b.text:SetText(text)
  b.text:SetJustifyH("CENTER")
  b:SetWidth(math.max(60, ((b.text.GetStringWidth and b.text:GetStringWidth()) or (#text * 7)) + 22))
  local edge = b:CreateTexture(nil, "BORDER")
  edge:SetAllPoints()
  edge:SetColorTexture(1, 1, 1, 0.06)
  b.bar:ClearAllPoints()
  b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT")
  b.bar:SetHeight(2)
  b.Update = function(self) self:SetSelected(get() and true or false) end
  b:SetScript("OnClick", function(self) set(not get()); self:Update(); ns.UI_Refresh() end)
  if tip then
    b:SetScript("OnEnter", function(self) ns.ShowTooltip(self, tip) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b:Update()
  return b
end

local chips = {}
local function Build(panel)
  left = CreateFrame("Frame", nil, panel)
  left:SetPoint("TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", 0, 0)
  left:SetWidth(340)

  local tb = ns.Toolbar(left)
  local box = tb:Search(L["fast cat, bite 6, rare badlands ..."], 318, function(t) filter.text = t; spec = ns.BestiaryParse(t) end)
  box:SetScript("OnEnter", function(self)
    ns.ShowTooltip(self, { L["Search"], L["Type what you're after: a name, a zone, a family, an ability and rank (bite 6), fast or slow, rare, new (teaches something you don't know), or a level range (30-40)."] })
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tb:Row()
  tb:Dropdown(150, FamilyOptions, function() return filter.family end, function(v) filter.family = v end)
  tb:Dropdown(166, TeachOptions, function() return filter.teaches end, function(v) filter.teaches = v end,
    { L["Teaches"], L["Pick an ability to see every beast that teaches it."] })
  tb:Row()
  local defs = {
    { L["This zone"], function() return filter.where == "zone" end, function(v) filter.where = v and "zone" or "any" end, { L["This zone"], L["Only beasts in the zone you're in."] } },
    { L["Tame now"], function() return filter.tameable end, function(v) filter.tameable = v end, { L["Tame now"], L["Only beasts at or under your level."] } },
    { L["Rare"], function() return filter.rare end, function(v) filter.rare = v end },
    { L["New"], function() return filter.fresh end, function(v) filter.fresh = v end, { L["New"], L["Only beasts that teach a rank you don't know yet."] } },
  }
  local x = 6
  for i, d in ipairs(defs) do
    local c = Chip(left, d[1], d[2], d[3], d[4])
    c:SetPoint("TOPLEFT", x, -4 - tb.row * 32 - 1)
    x = x + c:GetWidth() + 5
    chips[i] = c
  end
  tb:Row()
  tb:Dropdown(150, SORTS, function() return filter.sort end, function(v) filter.sort = v end)
  list = tb:List()

  BuildPage(panel)
end

local function Refresh()
  local playerLevel = UnitLevel("player")
  local zone = ns.PlayerMap and ns.PlayerMap()
  local B = ns.Beasts
  local ids, dist = {}, {}
  for id, b in pairs(B) do
    if Matches(id, b, playerLevel, zone) then
      if filter.sort == "near" then
        local _, _, _, d = ns.NearestSpawn(id)
        dist[id] = d or 9e9
      end
      ids[#ids + 1] = id
    end
  end
  table.sort(ids, function(a, b)
    local x, y = B[a], B[b]
    if filter.sort == "near" and dist[a] ~= dist[b] then return dist[a] < dist[b] end
    if filter.sort == "name" then return x[1] < y[1] end
    if filter.sort == "speed" and (x[9] or 9) ~= (y[9] or 9) then return (x[9] or 9) < (y[9] or 9) end
    if x[2] ~= y[2] then return x[2] < y[2] end
    return x[1] < y[1]
  end)

  -- keep the page on a beast that is in the list
  local keep = false
  for i = 1, math.min(#ids, 400) do if ids[i] == selected then keep = true break end end
  if not keep then selected = ids[1] end

  wipe(rowIds)
  local rows = {}
  rows[1] = { 0, nil, ns.Count(#ids, L["beast"], L["beasts"]), "", nil, nil, { header = true } }
  for i = 1, math.min(#ids, 400) do
    local id = ids[i]
    local b = B[id]
    local name = (IsRare(b) and C.ORANGE or C.WHITE) .. b[1] .. "|r"
    if ns.BeastWished and ns.BeastWished(id) then name = name .. C.GOLD .. "  *|r" end
    if TeachesNew(b) then name = name .. C.GREEN .. "  " .. L["new"] .. "|r" end
    local lv = ((b[2] > playerLevel) and C.RED or C.GREY) .. ((b[2] == b[3]) and tostring(b[2]) or (b[2] .. "-" .. b[3])) .. "|r"
    rows[#rows + 1] = { 0, ns.Icon(ns.FamilyIcons[b[4]] or "Ability_Hunter_BeastTaming"), name, lv, RowClick(id), RowHover(id) }
    rowIds[#rows] = id
  end
  if #ids == 0 then rows[#rows + 1] = { 0, nil, C.GREY .. L["No beasts match. Try fewer filters."] .. "|r" } end
  if #ids > 400 then rows[#rows + 1] = { 0, nil, C.GREY .. string.format(L["%d more: narrow the search to see them."], #ids - 400) .. "|r" } end
  list:Set(rows)
  for i, rid in pairs(rowIds) do if rid == selected then PaintRow(i, true) end end
  for _, c in ipairs(chips) do c:Update() end
  page.modelId = (page.modelId == selected) and page.modelId or nil
  FillPage()
end

function ns.BrowserFilter() return filter end
ns.RegisterTab("browse", L["Bestiary"], Build, Refresh)
