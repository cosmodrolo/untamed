local _, ns = ...
local L = ns.L

-- Adds pet-skill info to beast tooltips and alerts you when you target a beast your pet needs.

local GREEN, GREY, GOLD = "|cff40ff40", "|cff909090", "|cffabd473"

local function NeedFor(npcId)
  local need = ns.NeededSet()
  return need and need[npcId]
end

-- What we already added to each tooltip. Kept here, not on the tooltip: writing our own fields onto
-- Blizzard frames taints them, and on WoW Forever that taint reaches the gamepad controls.
local added = setmetatable({}, { __mode = "k" })

local function AddUnitLines(tooltip, unit)
  if not ns.db or not ns.db.tooltipInfo then return end
  if not unit or ns.IsSecret(unit) then return end
  local guid = UnitGUID(unit)
  if not guid or ns.IsSecret(guid) then return end
  local npcId = ns.NpcIdFromGUID(guid)
  local b = npcId and ns.Beasts[npcId]
  if not b then return end
  local a = added[tooltip]
  if a and a[1] == npcId and tooltip:IsShown() and a[2] == tooltip:NumLines() then return end
  local need = NeedFor(npcId)
  if need and #need > 0 then
    tooltip:AddLine(GOLD .. "Untamed:|r " .. GREEN .. "your pet needs " .. table.concat(need, ", ") .. "|r", 1, 1, 1, true)
  elseif #b[6] > 0 then
    tooltip:AddLine(GOLD .. "Untamed:|r " .. GREY .. "teaches " .. ns.TeachesText(b) .. "|r", 1, 1, 1, true)
  else
    tooltip:AddLine(GOLD .. "Untamed:|r " .. GREY .. "tameable " .. b[4] .. (b[9] and (", attack speed " .. b[9]) or "") .. "|r", 1, 1, 1, true)
  end
  added[tooltip] = { npcId, tooltip:NumLines() }
  tooltip:Show()
end

ns.On("LOGIN", function()
  local okScript, hasScript = pcall(GameTooltip.HasScript, GameTooltip, "OnTooltipSetUnit")
  if okScript and hasScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
      local _, unit = self:GetUnit()
      AddUnitLines(self, unit)
    end)
  elseif TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self)
      if self ~= GameTooltip then return end
      local _, unit = self:GetUnit()
      AddUnitLines(self, unit)
    end)
  end
  GameTooltip:HookScript("OnHide", function(self) added[self] = nil end)
end)

-- Target alert
local lastAlerted = {}
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:SetScript("OnEvent", function()
  if not ns.db or not ns.db.targetAlert then return end
  local npcId = ns.NpcIdFromGUID(UnitGUID("target"))
  if not npcId or not ns.Beasts[npcId] then return end
  local need = NeedFor(npcId)
  if not need or #need == 0 then return end
  local now = GetTime()
  if lastAlerted[npcId] and now - lastAlerted[npcId] < 60 then return end
  lastAlerted[npcId] = now
  local b = ns.Beasts[npcId]
  if b[2] > UnitLevel("player") then return end
  local msg = b[1] .. " teaches " .. table.concat(need, ", ") .. " for your pet!"
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.82, b = 0 })
  else
    UIErrorsFrame:AddMessage(msg, 0.67, 0.83, 0.45)
  end
  ns.Print(msg)
  if ns.db.targetSound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
end)
