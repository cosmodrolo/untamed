-- The Blizzard look: the theme colors go in before the window is built, and the window builds with
-- the game's frame art (mocked here) and without it (art missing: our own title bar instead).
local ns = NS
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end
UntamedDB = { theme = "blizzard" }
local applied
NineSliceUtil = { ApplyLayoutByName = function(frame, name) applied = name end }
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
check(ns.Theme.blizzard == true and ns.Theme.accent[2] == 0.82, "the Blizzard colors are in place before anything is built")
ns.UI_Show("home")
check(applied == "ButtonFrameTemplateNoPortrait", "the window wears the game's metal frame")
check(rawget(ns.UI_Frame(), "blizzNine") ~= nil, "the frame art is on our own frame")
for _, key in ipairs({ "browse", "talents", "gear", "settings", "stable", "care" }) do ns.UI_Show(key) end
print("DONE")
