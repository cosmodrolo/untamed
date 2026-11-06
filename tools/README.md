# Data tools

These scripts regenerate the generated data files. They expect source checkouts in one folder (`SRC`):

- `SRC/QuestieDB` (git clone https://github.com/Questie/QuestieDB)
- `SRC/cdb/full.sql` (cmangos classic-db full dump)
- `tools/blizzard/CreatureSpellData_<build>.txt`: Blizzard's CreatureSpellData client table. To refresh it for a new build,
  open https://wago.tools/db2/CreatureSpellData/csv?build=<build> and convert each row to `ID:spell.spell.spell`.
- `SRC/cdb/Full_DB/ClassicDB_*.sql.gz` (from https://github.com/cmangos/classic-db)

```
python tools/build_services.py SRC/cdb/full.sql services.json   # full.sql = the unzipped ClassicDB dump
python tools/build_data.py SRC forever Data/Forever.lua tools/forever_pets.json services.json
python tools/build_foods.py SRC/cdb/Full_DB/ClassicDB_1_12_1_z2815.sql.gz Foods.lua
```

## Translations

All text the player sees goes through `L["..."]`. Run `python tools/extract_strings.py` to collect the phrases into
`tools/phrases_enUS.lua`, then import that file on CurseForge (Localization > Import, Lua additive table). Translators
work on the website, and the release packager writes their translations into `Locales\*.lua` automatically.
Beast and NPC names come from QuestieDB's l10n tables (`tools/build_names.py`).

Forever hunter data (Data/Hunter_Forever.lua):
```
python tools/build_hunter.py ...                 # HunterQuests
python tools/emit_forever_gear.py                # GearItems: tools/forever_gear.txt (wago.tools ItemSparse) + tools/era_gear.lua
python tools/emit_forever_spells.py              # TrainerSpells: tools/era_spells.lua + Forever changes (wago.tools)
```
Run them in this order: build_hunter rewrites the file, then gear, then spells.
