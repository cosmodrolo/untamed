"""From cmangos classic-db (GPL-3.0): ammo vendors (sell arrows/bullets), hunter trainers, pet trainers,
and pet ability spell IDs per rank (for localization)."""
import re, sys, json
SQL, OUT = sys.argv[1], sys.argv[2]
def rows(line):
    i = line.index("VALUES") + 6; n = len(line)
    while i < n:
        while i < n and line[i] != "(": i += 1
        if i >= n: break
        i += 1; vals = []; cur = []; inq = False
        while True:
            c = line[i]
            if inq:
                if c == "\\": cur.append(line[i+1]); i += 2; continue
                if c == "'": inq = False
                else: cur.append(c)
            else:
                if c == "'": inq = True
                elif c == ",": vals.append("".join(cur)); cur = []
                elif c == ")": vals.append("".join(cur)); i += 1; break
                else: cur.append(c)
            i += 1
        yield vals
want = {"item_template", "npc_vendor", "npc_vendor_template", "creature_template", "spell_template"}
T = {k: [] for k in want}
for line in open(SQL, encoding="utf-8", errors="replace"):
    m = re.match(r"INSERT INTO `(\w+)`", line)
    if m and m.group(1) in want: T[m.group(1)].extend(rows(line))
ammo = {int(v[0]): int(v[13]) for v in T["item_template"] if v[1] == "6" and int(v[9]) > 0}   # class 6 projectile, BuyPrice>0 -> itemlevel
tmpl = {}
for v in T["npc_vendor_template"]: tmpl.setdefault(int(v[0]), set()).add(int(v[1]))
vend = {}
for v in T["npc_vendor"]: vend.setdefault(int(v[0]), set()).add(int(v[1]))
ammoV, hunterT, petT = {}, [], []
for v in T["creature_template"]:
    e = int(v[0]); items = set(vend.get(e, set()))
    vt = int(v[76]) if v[76] else 0
    items |= tmpl.get(vt, set())
    sold = [i for i in items if i in ammo]
    if sold: ammoV[e] = max(ammo[i] for i in sold)
    ttype, tclass = int(v[71]), int(v[73])
    if ttype == 0 and tclass == 3: hunterT.append(e)
    if ttype == 3: petT.append(e)
ABIL = {"Bite", "Claw", "Charge", "Cower", "Dash", "Dive", "Furious Howl", "Lightning Breath", "Prowl", "Scorpid Poison",
        "Screech", "Shell Shield", "Thunderstomp", "Growl", "Natural Armor", "Great Stamina", "Arcane Resistance",
        "Fire Resistance", "Frost Resistance", "Nature Resistance", "Shadow Resistance", "Beast Training", "Feed Pet"}
spells = {}
for v in T["spell_template"]:
    if v[119] in ABIL:
        spells.setdefault(v[119], []).append(int(v[0]))
spells = {k: sorted(x)[:1] for k, x in spells.items()}
json.dump({"ammo": ammoV, "hunterTrainer": hunterT, "petTrainer": petT, "spellIds": spells}, open(OUT, "w"))
print("ammo vendors", len(ammoV), "hunter trainers", len(hunterT), "pet trainers", len(petT), "spells", len(spells), file=sys.stderr)
print(spells, file=sys.stderr)
