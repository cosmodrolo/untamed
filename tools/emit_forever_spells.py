"""Write ns.TrainerSpells (WoW Forever) into Data/Hunter_Forever.lua.
Base: the Classic trainer list (tools/era_spells.lua, every spell is still in Forever's SkillLineAbility).
Changes below come from wago.tools SkillLineAbility + SpellLevels + Spell for build 1.60.1.70790.
Cost -1 = not known yet (Forever-only spells; the page shows "?")."""
import re
out = "Data/Hunter_Forever.lua"
rows = [list(m) for m in re.findall(r'^\{(\d+),(\d+),(-?\d+),"([^"]+)",(\d+)\}', open("tools/era_spells.lua").read(), re.M)]
rows = [[int(a), int(b), int(c), d, int(e)] for a, b, c, d, e in rows]
RERANK = {20909: 3, 20910: 4, 20905: 4, 20906: 5}       # Forever added lower ranks
for r in rows:
    if r[1] in RERANK: r[4] = RERANK[r[1]]
DROP = {24132, 24133}                                   # Wyvern Sting is not in Forever (talent removed)
rows = [r for r in rows if r[1] not in DROP]
# Checked against wowhead.com/forever/talent-calc/hunter: Aimed Shot and Lacerate are trainer spells now;
# Summon Hawk, Trueshot Aura, Counterattack and Sniper Shot are talents (rank 1), the trainer sells the rest.
NEW = [
    (20, 19434, "Aimed Shot", 1), (30, 24118, "Lacerate", 1),
    (36, 1293525, "Summon Hawk", 2), (48, 1293526, "Summon Hawk", 3), (60, 1293527, "Summon Hawk", 4),
    (40, 1299445, "Aspect of the Beast", 2), (50, 1299446, "Aspect of the Beast", 3), (60, 1299447, "Aspect of the Beast", 4),
    (30, 1242634, "Counterattack", 2),
    (32, 1299348, "Trueshot Aura", 2), (40, 19506, "Trueshot Aura", 3),
    (40, 24119, "Lacerate", 2), (50, 24120, "Lacerate", 3), (60, 1299332, "Lacerate", 4),
    (48, 1310785, "Sniper Shot", 2), (58, 1310786, "Sniper Shot", 3),
]
rows += [[l, i, -1, n, k] for l, i, n, k in NEW]

# What a Forever hunter trainer actually sells (recorded in game, 2026-11-06: "name|rank|level|copper",
# level 0 = already known). This list is authoritative: ranks it doesn't sell are dropped, its prices
# and levels win. Prices are what that character paid (Forever reworked trainer prices by level).
seen = {}
for line in open("tools/forever_trainer_seen.txt", encoding="utf-8").read().split("\n"):
    if not line.strip(): continue
    n, r, lv, c = line.split("|")
    seen[(n, int(r))] = (int(lv), int(c))
names_ranked = {n for (n, r) in seen if r > 0}
sold = []
for r in rows:
    key = (r[3], r[4])
    if key not in seen and r[4] == 1 and (r[3], 0) in seen and r[3] not in names_ranked:
        key = (r[3], 0)                      # Forever made it a single rank (Multi-Shot, Scorpid Sting)
    if key not in seen and r[4] == 0 and (r[3], 1) in seen:
        key = (r[3], 1); r[4] = 1            # Forever added ranks (Aspect of the Beast)
    if key not in seen:
        continue                             # not sold in Forever
    lv, c = seen[key]
    if key[1] == 0: r[4] = 0
    if lv > 0: r[0] = lv
    r[2] = c
    sold.append(r)
rows = sold
rows.sort(key=lambda r: (r[0], r[3], r[4]))
body = "-- {level, spellID, copper (-1 = unknown), English name, rank}. WoW Forever trainer (wago.tools build 1.60.1).\nns.TrainerSpells = {\n" + \
       "\n".join('{%d,%d,%d,"%s",%d},' % tuple(r) for r in rows) + "\n}\n"
src = open(out).read()
src = re.sub(r'-- \{level, spellID.*?\n\}\n', '', src, flags=re.S)
i = src.index("-- [itemID]")
open(out, "w").write(src[:i] + body + src[i:])
print(len(rows))
