"""Append ns.GearItems (WoW Forever) to Data/Hunter_Forever.lua from tools/forever_gear.txt.
forever_gear.txt is computed from wago.tools ItemSparse/RandPropPoints/ItemDamage* for build 1.60.1.70790.
Token: base36 id delta, slot letter A-O, optional ! for mail, base36 required level, '.', base36 score."""
import re, sys
SLOTS = "HEAD NECK SHOULDER CHEST WAIST LEGS FEET WRIST HANDS FINGER TRINKET BACK WEAPON OFFHAND RANGED".split()
out = sys.argv[1] if len(sys.argv) > 1 else "Data/Hunter_Forever.lua"
src = open(out).read()
src = src.split("-- [itemID] = {slot")[0].rstrip() + "\n"
rows, iid = [], 0
for t in open("tools/forever_gear.txt").read().split():
    m = re.match(r'^([0-9a-z]+)([A-O])(!?)([0-9a-z]+)\.([0-9a-z]+)$', t)
    iid += int(m.group(1), 36)
    rows.append('[%d]={"%s",%d,%d,%d},' % (iid, SLOTS[ord(m.group(2)) - 65], int(m.group(4), 36), int(m.group(5), 36), 1 if m.group(3) else 0))
# Items Wago's Forever table doesn't list are unchanged from Classic: keep the Classic Era values for them.
have = {int(r[1:r.index("]")]) for r in rows}
era = open("tools/era_gear.lua").read() if __import__("os").path.exists("tools/era_gear.lua") else ""
for m in re.finditer(r'^\[(\d+)\]=\{.*\},$', era, re.M):
    if int(m.group(1)) not in have: rows.append(m.group(0))
rows.sort(key=lambda r: int(r[1:r.index("]")]))
src += ("-- [itemID] = {slot, requiredLevel, score, isMail}. Built from WoW Forever item data (wago.tools, build 1.60.1).\n"
        "-- Score: agility x2.4, attack power x1, crit% x20, hit% x18, stamina x0.5, intellect x0.3, ranged weapon DPS x14.\n"
        "ns.GearItems = {\n" + "\n".join(rows) + "\n}\n")
open(out, "w").write(src)
print(len(rows))
