-- WoW API mock for smoke-testing Untamed (v2)
local NILKEYS = { TitleText = true, text = true, Text = true, GetUnit = false }
local function newObj(name)
  local o = { _name = name, _shown = false, _scripts = {}, _attr = {} }
  local mt = {}
  mt.__index = function(t, k)
    if NILKEYS[k] then return nil end
    if k == "IsShown" then return function(self) return self._shown end end
    if k == "Show" then return function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end end
    if k == "Hide" then return function(self) self._shown = false end end
    if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
    if k == "SetScript" then return function(self, s, f) self._scripts[s] = f end end
    if k == "HookScript" then return function(self, s, f) self._scripts[s] = f end end
    if k == "GetScript" then return function(self, s) return self._scripts[s] end end
    if k == "GetChecked" then return function() return true end end
    if k == "SetText" then return function(self, s) self._text = s end end
    if k == "GetText" then return function(self) return self._text end end
    if k == "SetAttribute" then return function(self, a, v) self._attr[a] = v end end
    if k == "GetAttribute" then return function(self, a) return self._attr[a] end end
    if k == "GetWidth" then return function() return 140 end end
    if k == "GetZoom" then return function() return 0 end end
    if k == "NumLines" then return function() return 3 end end
    if k == "GetFrameLevel" then return function() return 1 end end
    if k == "CreateTexture" or k == "CreateFontString" then return function() return newObj("child") end end
    return function() end
  end
  return setmetatable(o, mt)
end
EVENT_FRAMES = {}
CreateFrame = function(kind, name, parent, template)
  local o = newObj(name)
  if name then _G[name] = o end
  EVENT_FRAMES[#EVENT_FRAMES + 1] = o
  return o
end
function FIRE(event, ...)
  for _, f in ipairs(EVENT_FRAMES) do if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end end
end
function TICK(n) for _ = 1, n or 1 do for _, f in ipairs(EVENT_FRAMES) do if f._scripts.OnUpdate then f._scripts.OnUpdate(f, 0.2) end end end end
UIParent = newObj("UIParent"); Minimap = newObj("Minimap")
Minimap.GetCenter = function() return 0, 0 end
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, s) local out = {} for p in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = p end return unpack(out) end
GetTime = function() return os.clock() end
IsIndoors = function() return false end
GetCVar = function() return "0" end
function CreateFromMixins(...) local t = {} for i = 1, select("#", ...) do for k, v in pairs(select(i, ...)) do t[k] = v end end return t end
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
MapCanvasPinMixin = { SetPosition = function(self, x, y) self.x, self.y = x, y end, SetSize = function() end,
  UseFrameLevelType = function() end, SetScalingLimits = function() end, GetMap = function(self) return self._map end }
MapCanvasDataProviderMixin = {}
PINS = {}
WorldMapFrame = newObj("WorldMapFrame")
local mapID = 1429
PLAYERPOS = { x = 0.42, y = 0.65 }
WorldMapFrame.SetMapID = function(self, id) mapID = id end
WorldMapFrame.AddDataProvider = function(self, p)
  local map
  map = {
    GetMapID = function() return mapID end,
    RemoveAllPinsByTemplate = function() PINS = {} end,
    AcquirePin = function(_, tmpl, info)
      local pin = CreateFromMixins(UntamedPinMixin)
      pin.Icon = newObj("i"); pin.Border = newObj("b"); pin._map = map
      pin:OnLoad(); pin:OnAcquired(info); PINS[#PINS + 1] = pin
    end,
  }
  p.GetMap = function() return map end
end
ToggleWorldMap = function() WorldMapFrame._shown = true end
InCombatLockdown = function() return false end
-- fake continent geometry: each zone is a 4000x4000 yard square laid out by id
local function zoneOrigin(id) local k = id - 1411; return (k % 8) * 4000, math.floor(k / 8) * 4000 end
C_Map = {
  GetBestMapForUnit = function() return mapID end,
  GetPlayerMapPosition = function() return CreateVector2D(PLAYERPOS.x, PLAYERPOS.y) end,
  GetWorldPosFromMapPos = function(id, v)
    local ox, oy = zoneOrigin(id)
    local cont = (id >= 1411 and id <= 1415) and 1 or ((id % 2) + 1)
    cont = 1
    -- world: a = north (minus south), b = west (minus east)
    return cont, CreateVector2D(-(oy + v.y * 4000), -(ox + v.x * 4000))
  end,
}
C_Timer = { After = function(_, f) f() end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. m:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end }
GameTooltip = newObj("GameTooltip")
TOOLTIP_LINES = {}
GameTooltip.AddLine = function(_, l) TOOLTIP_LINES[#TOOLTIP_LINES + 1] = l end
GameTooltip.HasScript = function() return true end
GameTooltip.GetUnit = function() return "Wolf", "mouseover" end
SlashCmdList = {}
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
BOOKTYPE_PET = "pet"
IsShiftKeyDown = function() return false end
PlaySound = function() end
SOUNDKIT = { RAID_WARNING = 1, MAP_PING = 2 }
RaidNotice_AddMessage = function(_, m) print("[raidwarn] " .. m) end
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = {} }
UIErrorsFrame = newObj("err")
GetPlayerFacing = function() return 0 end
UnitFactionGroup = function() return "Alliance" end
NUM_BAG_SLOTS = 4
BAGS = { [0] = { [1] = { 2672, 5 }, [2] = { 4540, 10 }, [3] = { 117, 3 } } }
C_Container = {
  GetContainerNumSlots = function(bag) return BAGS[bag] and 3 or 0 end,
  GetContainerItemInfo = function(bag, slot) local i = BAGS[bag] and BAGS[bag][slot]; if i then return { itemID = i[1], stackCount = i[2] } end end,
}
ITEMS = { [2672] = { "Stringy Wolf Meat", 10 }, [4540] = { "Tough Hunk of Bread", 5 }, [117] = { "Tough Jerky", 5 } }
GetItemInfo = function(id) local i = ITEMS[id]; if i then return i[1], nil, nil, i[2] end end
GetPetHappiness = function() return PET.happy or 3, 100, 1 end
GetPetFoodTypes = function() return "Meat" end
GetPetLoyalty = function() return "Loyalty Level 3" end
GetPetExperience = function() return 300, 1000 end

PET = { exists = true, family = "Wolf", level = 24, spells = { { "Bite", "Rank 3" }, { "Growl", "Rank 3" }, { "Cower", "Rank 1" } } }
UnitExists = function(u) return (u == "pet" and PET.exists) or u == "target" or u == "mouseover" end
UnitCreatureFamily = function() return PET.family end
UnitLevel = function(u) if u == "pet" then return PET.level end return 26 end
UnitName = function(u) if u == "target" then return TARGET_NAME or "Beast" end return "Ruff" end
TARGET_ID = 299
UnitGUID = function(u) return "Creature-0-1-0-1-" .. TARGET_ID .. "-0000" end
HasPetSpells = function() return #PET.spells, "PET" end
GetSpellBookItemName = function(i) local s = PET.spells[i]; return s[1], s[2] end
GetPetTrainingPoints = function() return 60, 40 end
GetSpellInfo = function(id) if id == 5149 then return "Beast Training" end if id == 6991 then return "Feed Pet" end end
CRAFTS = { { "Bite", "Rank 1", "available", 0, nil, 1, 1 }, { "Bite", "Rank 2", "available", 0, nil, 4, 8 }, { "Bite", "Rank 4", "available", 0, nil, 10, 24 }, { "Dash", "Rank 1", "available", 0, nil, 15, 30 } }
GetCraftDisplaySkillLine = function() return "Beast Training" end
GetNumCrafts = function() return #CRAFTS end
GetCraftInfo = function(i) return unpack(CRAFTS[i]) end
