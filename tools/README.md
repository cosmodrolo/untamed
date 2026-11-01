# Data tools

These scripts regenerate the generated data files. They expect source checkouts in one folder (`SRC`):

- `SRC/QuestieDB` (git clone https://github.com/Questie/QuestieDB)
- `SRC/vanilla-hunter-pets` (git clone https://github.com/shagu/vanilla-hunter-pets)
- `SRC/cdb/Full_DB/ClassicDB_*.sql.gz` (from https://github.com/cmangos/classic-db)

```
python tools/build_services.py SRC/cdb/full.sql services.json   # full.sql = the unzipped ClassicDB dump
python tools/build_data.py SRC era Data/Era.lua - services.json
python tools/build_data.py SRC forever Data/Forever.lua tools/forever_pets.json services.json
python tools/build_foods.py SRC/cdb/Full_DB/ClassicDB_1_12_1_z2815.sql.gz Foods.lua
```

## Translations

All text the player sees goes through `L["..."]`. Run `python tools/extract_strings.py` to collect the phrases into
`tools/phrases_enUS.lua`, then import that file on CurseForge (Localization > Import, Lua additive table). Translators
work on the website, and the release packager writes their translations into `Locales\*.lua` automatically.
Beast and NPC names come from QuestieDB's l10n tables (`tools/build_names.py`).
