local _, ns = ...

-- Translation table: L["English text"] returns the translation, or the English text
-- when there is none. Translations are filled in per language from Locales\*.lua.
ns.L = setmetatable({}, { __index = function(t, k) return k end })

-- One meaning per color everywhere: GREEN = you can do it now, ORANGE = elite or dungeon,
-- GREY = information, RED = not possible yet, GOLD = headings.
ns.C = {
  GOLD = "|cffffd100", GREEN = "|cff40ff40", GREY = "|cff909090", RED = "|cffff5050",
  WHITE = "|cffffffff", ORANGE = "|cffff9933", BLUE = "|cff66aaff", HUNTER = "|cffabd473",
}
