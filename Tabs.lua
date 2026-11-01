local _, ns = ...
local C = ns.C

---------------------------------------------------------------------------
-- Tab: Pet Care
---------------------------------------------------------------------------
do
  local list, feedBtn
  local function Build(panel)
    feedBtn = ns.CreateFeedButton(panel, "UntamedTabFeedButton", 220, 22)
    feedBtn:SetPoint("TOPLEFT", 4, -2)
    list = ns.NewList(panel, 30)
  end
  local function Refresh()
    local rows = {}
    local function add(...) rows[#rows + 1] = { ... } end
    local info = ns.PetCareInfo()
    if not info then
      add(0, nil, C.GREY .. "Summon your pet to see its care info.|r")
      list:Set(rows)
      return
    end
    add(0, ns.Icon("Ability_Hunter_BeastTraining"), C.GOLD .. "Happiness|r", info.happyText ..
      (info.damage and (C.GREY .. "  (" .. info.damage .. "% damage)|r") or ""), nil,
      { "Happiness", "Happy pets deal 125% damage, content 100%, unhappy 75%. Unhappy pets lose loyalty and can run away." })
    if info.loyalty then add(0, nil, C.GOLD .. "Loyalty|r", C.WHITE .. info.loyalty .. "|r") end
    if info.xp and info.nextXP and info.nextXP > 0 then
      add(0, nil, C.GOLD .. "Experience|r", string.format("%s%d / %d (%d%%)|r", C.WHITE, info.xp, info.nextXP, info.xp * 100 / info.nextXP))
    end
    if info.tpFree then add(0, nil, C.GOLD .. "Training points|r", string.format("%s%d free of %d|r", C.WHITE, info.tpFree, info.tpTotal or 0)) end
    add(0, nil, C.GOLD .. "Diet|r", C.WHITE .. (#info.diet > 0 and table.concat(info.diet, ", ") or "?") .. "|r")
    add(0, nil, C.GOLD .. "Food in your bags it will eat|r", C.GREY .. (#info.food == 0 and "none" or "") .. "|r")
    for _, f in ipairs(info.food) do
      add(14, nil, C.WHITE .. f[6] .. "|r", C.GREY .. "x" .. f[4] .. "   item level " .. f[5] .. "|r")
    end
    add(0, nil, C.GREY .. "A Feed button pops up on screen when your pet is not happy (toggle in Settings).|r")
    list:Set(rows)
  end
  ns.RegisterTab("care", "Pet Care", Build, Refresh)
end

---------------------------------------------------------------------------
-- Tab: Settings
---------------------------------------------------------------------------
do
  local function Build(panel)
    local y = -4
    local function check(label, key, tip)
      ns.MakeCheck(panel, label, 8, y, function() return ns.db[key] end, function(v) ns.db[key] = v end, tip)
      y = y - 26
    end
    check("Zone alerts in chat", "zoneAlerts", "Print a message when you enter a zone with beasts that teach your pet something new.")
    check("World map: pins for every beast my pet needs", "autoPins", "Small pins for all needed beasts, in addition to the ones you focus.")
    check("Minimap: pins for nearby beasts my pet needs", "minimapPins")
    check("Tooltips: show what a beast teaches", "tooltipInfo")
    check("Alert when I target a beast my pet needs", "targetAlert")
    check("Play a sound with that alert", "targetSound")
    check("Feed reminder and pop-up Feed button", "feedReminder")
    check("Hide ranks above my pet's level", "hideTooHigh")
    check("Show minimap button", "showMinimap")
    y = y - 10
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 12, y)
    note:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    note:SetJustifyH("LEFT")
    note:SetText(C.GREY .. "When you tame a beast, Untamed records the abilities it really had and adds them to its data, so the lists improve as you play." ..
      (ns.FLAVOR == "forever" and " This matters most on Forever, where public data is still incomplete." or "") ..
      "\n\nSlash commands: /untamed, /untamed plan, /untamed browse, /untamed care, /untamed zone, /untamed clear|r")
  end
  ns.RegisterTab("settings", "Settings", Build, function() end)
  ns.On("REFRESH", function() ns.Fire("MINIMAP_TOGGLE") end)
end
