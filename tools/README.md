# Data tools

The scripts here build the generated files in `Data/`. Nothing in this folder ships with the addon.

## What you need

Source checkouts in one folder, called `SRC` below:

- `SRC/QuestieDB`: `git clone https://github.com/Questie/QuestieDB`
- `SRC/cdb/full.sql`: the cmangos classic-db full dump, unzipped (https://github.com/cmangos/classic-db)
- `SRC/cdb/Full_DB/ClassicDB_*.sql.gz`: the same dump, zipped (for `build_foods.py`)

## Which script builds which file

| File in `Data/` | Script | Inputs kept in this folder |
| --- | --- | --- |
| `Forever.lua` (beasts, abilities, services) | `build_services.py`, then `build_data.py` | `forever_pets.json`, `blizzard/CreatureSpellData_*.txt`; uses `traces.py` |
| `Names_Forever.lua` (localized names) | `build_names.py` | |
| `Foods.lua` (pet food types) | `build_foods.py` | |
| `Search_Forever.lua` (items, NPCs, quests, sources) | `build_search.py` | uses `traces.py` |
| `Trash_Forever.lua` (dungeon trash loot) | `build_search.py` with `UNTAMED_TRASH_OUT` | |
| `Hunter_Forever.lua` (class quests, gear scores, trainer spells) | `build_hunter.py`, then `emit_forever_gear.py`, then `emit_forever_spells.py` | `forever_gear.txt`, `era_gear.lua`, `era_spells.lua`, `forever_trainer_seen.txt` |
| `Chests_Forever.lua` (chest spots) | `build_chests.py` | |
| `Looks_Forever.lua` (beast skins) | `build_looks.py` | `looks_groups.txt` |
| `Books_Forever.lua` (library books) | kept by hand | |

## Commands

```
python tools/build_services.py SRC/cdb/full.sql services.json
python tools/build_data.py SRC forever Data/Forever.lua tools/forever_pets.json services.json [Untamed.lua ...]
python tools/build_names.py SRC forever Data/Forever.lua Data/Names_Forever.lua
python tools/build_foods.py SRC/cdb/Full_DB/ClassicDB_1_12_1_z2815.sql.gz Data/Foods.lua

python tools/build_search.py SRC/QuestieDB forever Data/Search_Forever.lua SRC/cdb/full.sql [Untamed.lua ...]
UNTAMED_TRASH_OUT=Data/Trash_Forever.lua python tools/build_search.py SRC/QuestieDB forever /tmp/unused.lua SRC/cdb/full.sql

python tools/build_hunter.py ...          # class quests; rewrites the file, so run it first
python tools/emit_forever_gear.py         # gear scores
python tools/emit_forever_spells.py       # trainer spells

python tools/build_chests.py SRC Data/Chests_Forever.lua
python tools/build_looks.py SRC
```

Notes:

- `build_data.py` can take the same recorder files: a tameable beast Questie has no spawns for gets the spots the recorder saw it at.
- `build_search.py` can take players' `WTF/Account/<name>/SavedVariables/Untamed.lua` files as extra arguments. Vendors and loot the recorder noted in game are merged in. The shipped `Search_Forever.lua` was built with such recordings, so a build without them differs slightly.
- `blizzard/CreatureSpellData_<build>.txt`: to refresh it for a new build, open `https://wago.tools/db2/CreatureSpellData/csv?build=<build>` and convert each row to `ID:spell.spell.spell`.
- `forever_gear.txt` is computed from wago.tools ItemSparse, RandPropPoints and ItemDamage tables for WoW Forever.
- `looks_groups.txt` lists, for each creature display a beast uses, which look it belongs to and how big the game draws it. It comes from the WoW Forever client tables CreatureDisplayInfo and CreatureModelData on wago.tools.
- The `era_*.lua` inputs are the Classic lists that the Forever gear and spell lists are built on. The addon itself is WoW Forever only.

## Checking what the recorder found

```
python tools/recorded_report.py <Untamed.lua> [<Untamed.lua> ...]
```

Reads the account SavedVariables (from one or more computers) and lists what the recorder saw that the data doesn't know yet: new beasts and spots, rares, book IDs and spots, minimap marks, chests opened. Run it before a data update.

## Translations

All text the player sees goes through `L["..."]`. Run `python tools/extract_strings.py` after adding or changing text. It collects every phrase into `tools/phrases_enUS.lua`, which is imported on CurseForge (Localization > Import, Lua additive table). Translators work on the website, and the release packager writes their translations into `Locales/*.lua`.
