local ns = NS
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end
FIRE("ADDON_LOADED", "Untamed"); FIRE("PLAYER_LOGIN")
local t = ns.ScanPet()
check(t.family == "Cat", "German family name maps to Cat")
check(t.known.Bite == 3 and t.known.Cower == 1, "German ability names map to Bite and Cower")
check(ns.Beasts[2958][1] == "Präriewolf", "beast names shown in German")
check(ns.FamilyLabel("Cat") == "Katze" and ns.AbilityLabel("Bite") == "Biss", "labels shown in German")
check(ns.L["Tank"] == "Tank", "untranslated text falls back to English")
for _, tab in ipairs({ "abilities", "plan", "recommend", "stable", "builds", "browse", "care", "settings" }) do ns.UI_Show(tab) end
local ranked = ns.RankFamilies("tank")
print("  tank picks:", ranked[1].family, ranked[2].family, ranked[3].family)
local dps = ns.RankFamilies("dps")
print("  damage picks:", dps[1].family, dps[2].family, dps[3].family)
local util = ns.RankFamilies("utility")
print("  utility picks:", util[1].family, util[2].family, util[3].family)
local beasts = ns.BestBeasts("Cat", "dps", 3)
check(#beasts > 0, "best cats found")
print("DONE")
