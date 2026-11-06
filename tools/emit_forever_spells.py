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
NEW = [
    (25, 1293241, "Summon Hawk", 1), (36, 1293525, "Summon Hawk", 2), (48, 1293526, "Summon Hawk", 3), (60, 1293527, "Summon Hawk", 4),
    (40, 1299445, "Aspect of the Beast", 2), (50, 1299446, "Aspect of the Beast", 3), (60, 1299447, "Aspect of the Beast", 4),
    (30, 1317257, "Strider Kick", 0),
    (30, 1242634, "Counterattack", 2),
    (32, 1299348, "Trueshot Aura", 2), (40, 19506, "Trueshot Aura", 3),
    (40, 24119, "Lacerate", 2), (50, 24120, "Lacerate", 3), (60, 1299332, "Lacerate", 4),
    (48, 1310785, "Sniper Shot", 2), (58, 1310786, "Sniper Shot", 3),
]
rows += [[l, i, -1, n, k] for l, i, n, k in NEW]
rows.sort(key=lambda r: (r[0], r[3], r[4]))
body = "-- {level, spellID, copper (-1 = unknown), English name, rank}. WoW Forever trainer (wago.tools build 1.60.1).\nns.TrainerSpells = {\n" + \
       "\n".join('{%d,%d,%d,"%s",%d},' % tuple(r) for r in rows) + "\n}\n"
src = open(out).read()
src = re.sub(r'-- \{level, spellID.*?\n\}\n', '', src, flags=re.S)
i = src.index("-- [itemID]")
open(out, "w").write(src[:i] + body + src[i:])
print(len(rows))
