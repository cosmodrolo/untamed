# Data tools

These scripts regenerate the generated data files. They expect source checkouts in one folder (`SRC`):

- `SRC/QuestieDB` (git clone https://github.com/Questie/QuestieDB)
- `SRC/vanilla-hunter-pets` (git clone https://github.com/shagu/vanilla-hunter-pets)
- `SRC/cdb/Full_DB/ClassicDB_*.sql.gz` (from https://github.com/cmangos/classic-db)

```
python tools/build_data.py SRC era Data/Era.lua
python tools/build_data.py SRC forever Data/Forever.lua tools/forever_pets.json
python tools/build_foods.py SRC/cdb/Full_DB/ClassicDB_1_12_1_z2815.sql.gz Foods.lua
```
