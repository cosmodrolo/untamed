local _, ns = ...

-- Translation table: L["English text"] returns the translation, or the English text
-- when there is none. Translations are filled in per language from Locales\*.lua.
ns.L = setmetatable({}, { __index = function(t, k) return k end })
