local _, ns = ...

-- Rare beast scanner and hunter essentials: ammo, trainer reminders, Mend Pet and Revive Pet.

local function Alert(msg, sound)
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.82, b = 0 })
  else
    UIErrorsFrame:AddMessage(msg, 0.67, 0.83, 0.45)
  end
  if sound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
end

local function IsHunter()
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

---------------------------------------------------------------------------
-- Rare beast scanner (nameplates, target and mouseover)
---------------------------------------------------------------------------
local rareSeen = {}
local function CheckRare(unit)
  if not ns.db or not ns.db.rareAlert or not unit then return end
  local ok, guid = pcall(UnitGUID, unit)
  if not ok then return end
  local npcId = ns.NpcIdFromGUID(guid)
  local b = npcId and ns.Beasts[npcId]
  if not b or not b[5] or not b[5]:find("Rare") then return end
  if UnitIsDead and UnitIsDead(unit) then return end
  local now = GetTime()
  if rareSeen[npcId] and now - rareSeen[npcId] < 600 then return end
  rareSeen[npcId] = now
  local teaches = #b[6] > 0 and (" Teaches " .. ns.TeachesText(b) .. ".") or ""
  local speed = b[9] and (" Attack speed " .. b[9] .. ".") or ""
  local msg = "Rare tameable nearby: " .. b[1] .. " (level " .. ns.LevelText(b) .. " " .. b[4] .. ")." .. speed .. teaches
  Alert(msg, ns.db.targetSound)
  ns.Print(msg .. " Type /untamed rare to point the arrow at it.")
  ns.lastRare = npcId
end

---------------------------------------------------------------------------
-- Ammo, trainer reminders, pet health
---------------------------------------------------------------------------
local ammoWarned, mendWarnAt, deadWarned = false, 0, false

local function AmmoCount()
  local slot = INVSLOT_AMMO or 0
  if not GetInventoryItemID or not GetInventoryItemID("player", slot) then return nil end
  return GetInventoryItemCount("player", slot)
end

local function CheckAmmo()
  if not ns.db.ammoWarning or not IsHunter() or InCombatLockdown() then return end
  local n = AmmoCount()
  if not n then return end
  local limit = ns.db.ammoThreshold or 200
  if n >= limit then ammoWarned = false return end
  if ammoWarned then return end
  ammoWarned = true
  local mapID, x, y = ns.PlayerMap()
  local vendor, d
  if mapID then vendor, d = ns.NearestService("A", mapID, x, y) end
  ns.Print(string.format("Low ammo: %d left.", n) .. (vendor and (" Nearest ammo vendor: " .. ns.ServiceText(vendor, d) .. ". Type /untamed ammo for an arrow.") or ""))
  Alert("Low ammo: " .. n .. " left", false)
end

function ns.PlayerMap()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos.x, pos.y
  if pos.GetXY then x, y = pos:GetXY() end
  if not x or ns.IsSecret(x) then return nil end
  return mapID, x * 100, y * 100
end

function ns.NavigateService(kind, label)
  local mapID, x, y = ns.PlayerMap()
  if not mapID then ns.Print("Can't tell where you are right now.") return end
  local s, d = ns.NearestService(kind, mapID, x, y)
  if not s then ns.Print("No " .. label .. " found on this continent.") return end
  ns.Arrow_Set(s[4], s[5], s[6], label .. ": " .. s[2])
  ns.Print(label .. ": " .. ns.ServiceText(s, d) .. ".")
end

local function CheckPetHealth(unit)
  if unit ~= "pet" or not ns.db.petHealthAlerts then return end
  if not UnitExists("pet") then return end
  local hp, max = UnitHealth("pet"), UnitHealthMax("pet")
  if ns.IsSecret(hp) or ns.IsSecret(max) or not max or max == 0 then return end
  if UnitIsDead("pet") then
    if not deadWarned then deadWarned = true; Alert("Your pet died. Revive Pet!", true) end
    return
  end
  deadWarned = false
  if InCombatLockdown() and hp / max < 0.35 and GetTime() > mendWarnAt then
    mendWarnAt = GetTime() + 8
    UIErrorsFrame:AddMessage("Mend Pet! (" .. math.floor(hp * 100 / max) .. "%)", 0.4, 1, 0.4)
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_LEVEL_UP",
  "UNIT_HEALTH", "UNIT_INVENTORY_CHANGED", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event, arg1)
  if not ns.db then return end
  if event == "NAME_PLATE_UNIT_ADDED" then CheckRare(arg1)
  elseif event == "PLAYER_TARGET_CHANGED" then CheckRare("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then CheckRare("mouseover")
  elseif event == "UNIT_HEALTH" then CheckPetHealth(arg1)
  elseif event == "PLAYER_LEVEL_UP" then
    if ns.db.trainerReminder and IsHunter() and arg1 and arg1 % 2 == 0 then
      local mapID, x, y = ns.PlayerMap()
      local s, d
      if mapID then s, d = ns.NearestService("T", mapID, x, y) end
      ns.Print("Level " .. arg1 .. "! New hunter spell ranks are usually waiting at your trainer." ..
        (s and (" Nearest hunter trainer: " .. ns.ServiceText(s, d) .. ". Type /untamed trainer for an arrow.") or ""))
    end
  else
    CheckAmmo()
  end
end)

ns.On("LOGIN", function()
  for k, v in pairs({ rareAlert = true, ammoWarning = true, ammoThreshold = 200, trainerReminder = true, petHealthAlerts = true }) do
    if ns.db[k] == nil then ns.db[k] = v end
  end
end)

function ns.NavigateLastRare()
  if ns.lastRare then ns.Navigate(ns.lastRare) else ns.Print("No rare beast spotted yet this session.") end
end
