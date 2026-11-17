-- The Blizzard look: the theme colors go in before the window is built, and the window builds with
-- the game's frame art (mocked here) and without it (art missing: our own title bar instead).
local ns = NS
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end
UntamedDB = { theme = "blizzard" }
local applied = {}
NineSliceUtil = { ApplyLayoutByName = function(frame, name) applied[name] = true end }
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
check(ns.Theme.blizzard == true and ns.Theme.accent[2] == 0.82, "the Blizzard colors are in place before anything is built")
ns.UI_Show("home")
check(applied["ButtonFrameTemplateNoPortrait"], "the window wears the game's metal frame")
check(applied["InsetFrameTemplate"], "panels wear the game's inner border")
local b = ns.MakeButton(ns.UI_Frame(), "Go", 80, function() end)
check(rawget(b, "primaryGlow") ~= nil, "buttons are the game's red ones, with a glow for the one to press")
b:SetPrimary(true); b:SetPrimary(false)
local dd = ns.MakeDropdown(ns.UI_Frame(), 120, { { "a", "A" } }, function() return "a" end, function() end)
check(rawget(dd, "primaryGlow") == nil, "dropdowns are boxes, not red buttons")
-- every look has every color, and switching puts them in place
local seen = {}
for _, th in ipairs(ns.THEMES) do
  check(not seen[th.key], "one look per key: " .. th.key); seen[th.key] = true
  if th.window then
    for _, k in ipairs({ "window", "bar", "panel", "deep", "button", "line", "accent", "ink" }) do
      check(type(th[k]) == "table" and #th[k] == 3, th.key .. " has " .. k)
    end
    ns.db.theme = th.key; ns.ApplyTheme()
    check(ns.Theme.accent[1] == th.accent[1] and (ns.Theme.blizzard == true) == (th.art == true), th.key .. " goes in place")
  end
end
check(#ns.THEMES == 6 and seen.savage and seen.midnight and seen.ember and seen.slate and seen.twilight, "six looks to choose from")
ns.db.theme = "blizzard"; ns.ApplyTheme()
check(rawget(ns.UI_Frame(), "blizzNine") ~= nil, "the frame art is on our own frame")
for _, key in ipairs({ "browse", "talents", "gear", "settings", "stable", "care" }) do ns.UI_Show(key) end
print("DONE")
