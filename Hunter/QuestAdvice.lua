local _, ns = ...
local L, C = ns.L, ns.C

---------------------------------------------------------------------------
-- Quest reward advice: when a quest lets you choose a reward, a small box says which to take.
--
-- Gamepad safety: the box is our own frame on UIParent, made at login, with no buttons in it.
-- Nothing is created on, attached to or written to Blizzard's quest window (drawing on its reward
-- buttons is what broke the controller's face buttons with other addons). We only read where the
-- quest window is, a moment after it opens, to stand beside it.
---------------------------------------------------------------------------

local box, rows = nil, {}
local shownFor            -- "detail" or "complete" while a quest window with choices is up
local tries = 0

local function Plain(v) if v == nil or ns.IsSecret(v) then return nil end return v end

-- the choices on the open quest window: { { id, link, name, icon, quality } }
local function Choices()
  local out = {}
  local n = Plain(GetNumQuestChoices and GetNumQuestChoices()) or 0
  for i = 1, n do
    local ok, name, icon, _, quality, _, itemID = pcall(GetQuestItemInfo, "choice", i)
    local link = GetQuestItemLink and select(2, pcall(GetQuestItemLink, "choice", i)) or nil
    link = type(Plain(link)) == "string" and link or nil
    local id = ok and Plain(itemID) or (link and tonumber(link:match("item:(%d+)")))
    out[#out + 1] = { id = id, link = link, name = ok and Plain(name) or nil, icon = ok and Plain(icon) or nil, quality = ok and Plain(quality) or nil }
  end
  return out
end

local function SellPrice(id)
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not info or not id then return nil end
  local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(info, id)
  return ok and Plain(price) or nil
end

-- Judge the choices. Returns rows { c = choice, gain, rank, price, pick = "wear" / "sell" / nil } and
-- whether every item's data was there.
function ns.QuestAdviceJudge(choices)
  local out, complete = {}, true
  local bestGain, bestSell
  for i, c in ipairs(choices) do
    local r = { c = c }
    if c.id then
      r.gain = ns.GearGain and ns.GearGain(c.id, c.link) or nil
      if r.gain then r.rank, r.total = ns.GearRank(c.id, c.link) end
      r.price = SellPrice(c.id)
      if r.price == nil then complete = false end
    else
      complete = false
    end
    out[i] = r
    if r.gain and r.gain > 0 and (not bestGain or r.gain > out[bestGain].gain) then bestGain = i end
    if r.price and (not bestSell or r.price > out[bestSell].price) then bestSell = i end
  end
  if bestGain then out[bestGain].pick = "wear"
  elseif bestSell and out[bestSell].price > 0 then out[bestSell].pick = "sell" end
  return out, complete
end

local function Row(i)
  local r = rows[i]
  if r then return r end
  r = {}
  r.icon = box:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(26, 26)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.icon:SetPoint("TOPLEFT", 12, -38 - (i - 1) * 40)
  r.name = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
  r.name:SetPoint("RIGHT", box, "RIGHT", -10, 0)
  r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
  r.note = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.note:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  r.note:SetPoint("RIGHT", box, "RIGHT", -10, 0)
  r.note:SetJustifyH("LEFT"); r.note:SetWordWrap(false)
  r.mark = box:CreateTexture(nil, "BACKGROUND")
  r.mark:SetPoint("TOPLEFT", 4, -34 - (i - 1) * 40)
  r.mark:SetPoint("RIGHT", box, "RIGHT", -4, 0)
  r.mark:SetHeight(36)
  r.mark:SetColorTexture(ns.Theme.accent[1], ns.Theme.accent[2], ns.Theme.accent[3], 0.18)
  rows[i] = r
  return r
end

-- Stand under the quest window (read only), clear of the item tooltips, which open to its right
-- and cover anything beside it. The controller's button prompts sit just under the window, so the
-- box starts below those. Without room underneath it goes beside the window; if the window can't
-- be read, a fixed spot.
local function Place()
  box:ClearAllPoints()
  local ok = pcall(function()
    local q = _G.QuestFrame
    if not (q and q:IsShown()) then error("no quest window") end
    local left, right, top, bottom = Plain(q:GetLeft()), Plain(q:GetRight()), Plain(q:GetTop()), Plain(q:GetBottom())
    local qs, us = Plain(q:GetEffectiveScale()), Plain(UIParent:GetEffectiveScale())
    if not (left and right and top and bottom and qs and us) then error("hidden") end
    local k = qs / us
    local under = bottom * k - 62
    if under - box:GetHeight() > 4 then
      box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.max(4, left * k + 4), under)
    else
      local x = right * k + 12
      local screenW = UIParent:GetWidth()
      if x + box:GetWidth() > screenW then x = screenW - box:GetWidth() - 8 end
      box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top * k)
    end
  end)
  if not ok then box:SetPoint("CENTER", UIParent, "CENTER", 260, 120) end
end

local function Fill()
  if not box or not shownFor then return end
  local choices = Choices()
  if #choices < 2 then box:Hide() return end
  local judged, complete = ns.QuestAdviceJudge(choices)
  local any
  for i, r in ipairs(judged) do
    local row = Row(i)
    local c = r.c
    row.icon:SetTexture(c.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.icon:Show()
    row.name:SetText(((ns.QualityColor and c.id) and ns.QualityColor(c.id) or C.WHITE) .. (c.name or "?") .. "|r"); row.name:Show()
    local note
    if r.gain and r.gain > 0 then
      note = C.GREEN .. "+" .. r.gain .. " " .. L["upgrade for you"] .. "|r"
      if r.rank then note = note .. C.GREY .. "   " .. string.format(L["rank %d of %d"], r.rank, r.total) .. "|r" end
    elseif r.gain then
      note = C.GREY .. L["not an upgrade"] .. "|r"
    else
      note = C.GREY .. L["not hunter gear"] .. "|r"
    end
    if r.price and r.price > 0 then note = note .. C.GREY .. "   " .. L["sells for "] .. "|r" .. ns.Money(r.price) end
    if r.pick == "wear" then note = C.GOLD .. L["Take this."] .. "|r  " .. note; any = true
    elseif r.pick == "sell" then note = C.GOLD .. L["Take this to sell."] .. "|r  " .. note; any = true end
    row.note:SetText(note); row.note:Show()
    row.mark:SetShown(r.pick ~= nil)
  end
  for i = #judged + 1, #rows do
    local row = rows[i]
    row.icon:Hide(); row.name:Hide(); row.note:Hide(); row.mark:Hide()
  end
  box.title:SetText(shownFor == "detail" and L["Untamed: the reward to plan on"] or L["Untamed: which reward to take"])
  box:SetHeight(46 + #judged * 40)
  Place()
  box:Show()
  -- the game is still loading an item: look again shortly (a few times)
  if not complete and tries < 6 then
    tries = tries + 1
    C_Timer.After(0.5, Fill)
  end
end

-- what happened lately, for /ut advice (why did the box stay, who took the reward)
local log = {}
local function Note(text)
  log[#log + 1] = date("%H:%M:%S") .. "  " .. text
  if #log > 14 then table.remove(log, 1) end
end

local openedAt = 0
local function Open(kind)
  Note(kind == "detail" and "quest offered" or "quest ready to hand in")
  if ns.db.questAdvice == false then return end
  shownFor, tries, openedAt = kind, 0, GetTime()
  -- a moment for the quest window to be laid out by the game before we read where it is
  C_Timer.After(0.3, function() if shownFor == kind then Fill() end end)
end

local function Close()
  shownFor = nil
  if box then box:Hide() end
end

-- Who took the reward? The game calls GetQuestReward when a reward is taken: by you (Blizzard's
-- own button) or by an addon that hands quests in for you. A look at who called it names the addon.
local function RewardTaken(choice)
  local who
  local okS, stack = pcall(debugstack, 1, 20, 0)
  if okS and type(stack) == "string" and not ns.IsSecret(stack) then
    for name in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]") do
      if name ~= "Untamed" and not name:find("^Blizzard_") then who = name break end
    end
  end
  local n = Plain(GetNumQuestChoices and GetNumQuestChoices()) or 0
  Note(string.format("reward %s of %d taken by %s", tostring(Plain(choice) or "?"), n, who or "you (the quest window)"))
  if who and n >= 2 and ns.db.questAdvice ~= false then
    ns.Print(string.format(L["%s picked quest reward %s of %d for you."], C.GOLD .. who .. "|r", tostring(Plain(choice) or "?"), n))
  end
  Close()
end
ns.QuestAdviceRewardTaken = RewardTaken

function ns.QuestAdviceCommand()
  ns.Print(L["Quest reward advice, the last things that happened:"])
  if #log == 0 then ns.Print(C.GREY .. L["Nothing yet this session."] .. "|r") end
  for _, line in ipairs(log) do ns.Print(C.GREY .. line .. "|r") end
end

ns.On("LOGIN", function()
  if select(2, UnitClass("player")) ~= "HUNTER" then return end
  box = CreateFrame("Frame", "UntamedQuestAdvice", UIParent)
  box:SetSize(330, 126)
  box:SetFrameStrata("HIGH")
  box:EnableMouse(false)
  ns.Skin(box, ns.Theme.panel, 0.95, ns.Theme.line, 1, 0.12)
  box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  box.title:SetPoint("TOPLEFT", 12, -10)
  box.title:SetTextColor(ns.Theme.accent[1], ns.Theme.accent[2], ns.Theme.accent[3])
  box:Hide()
  -- a second way out, in case the game never says the quest window closed: the box goes when the
  -- quest window is no longer up (read only), and after two minutes whatever happens
  local acc = 0
  box:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.3 then return end
    acc = 0
    local q = _G.QuestFrame
    local okV, up = pcall(function() return q and q:IsShown() end)
    if (okV and q and not up and GetTime() - openedAt > 1) or GetTime() - openedAt > 120 then
      Note("box closed: quest window gone")
      Close()
    end
  end)

  -- after the fact and read only: runs when a reward is taken, whoever took it
  if hooksecurefunc and GetQuestReward then pcall(hooksecurefunc, "GetQuestReward", function(choice) pcall(RewardTaken, choice) end) end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_PROGRESS", "QUEST_GREETING", "GOSSIP_SHOW", "PLAYER_REGEN_DISABLED",
                       "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event)
    if event == "QUEST_DETAIL" then Open("detail")
    elseif event == "QUEST_COMPLETE" then Open("complete")
    else
      if shownFor then Note("closed by " .. event) end
      Close()
    end
  end)
end)

ns.QuestAdviceTest = { Fill = function(kind) shownFor, tries = kind or "complete", 6; Fill() end, Close = Close, Box = function() return box end }
