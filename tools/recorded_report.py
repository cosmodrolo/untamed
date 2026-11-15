#!/usr/bin/env python3
"""What Untamed's recorder has noted that the shipped data doesn't know yet.

usage: recorded_report.py SAVEDVARIABLES_Untamed.lua [more Untamed.lua files ...]
Reads one or more copies of the account SavedVariables (both computers), merges what they
recorded and prints, without changing anything:
  * beasts seen in game that aren't in Data/Forever.lua (new tames for forever_pets.json),
    and known beasts seen on maps the data doesn't list for them
  * rares seen (and where), library books found (spots, item and quest IDs),
    things the game marked on the minimap, chests opened (where)
Vendors and loot are already folded in by build_search.py.
"""
import re, sys, os
import lupa.lua51 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = L.LuaRuntime(unpack_returned_tuples=True)

def load(path):
    lua.execute("UntamedDB = nil")
    lua.execute(open(path, encoding="utf-8").read())
    db = lua.globals().UntamedDB
    rec = db and db["recorded"]
    return rec and rec["forever"]

def tolist(t): return [t[i] for i in range(1, len(t) + 1)] if t else []

known = {}
for line in open(os.path.join(ROOT, "Data", "Forever.lua"), encoding="utf-8"):
    m = re.match(r'  \[(\d+)\]=\{"([^"]*)",\d+,\d+,"[^"]*",[^,]*,\{[^}]*\},(\{.*?\}\}|\{\})', line)
    if m: known[int(m.group(1))] = (m.group(2), set(int(x) for x in re.findall(r"\[(\d+)\]=", m.group(3))))
books = [m.group(1) for m in re.finditer(r'name = "([^"]+)"', open(os.path.join(ROOT, "Data", "Books_Forever.lua"), encoding="utf-8").read())]

merged = {"beasts": {}, "rares": {}, "books": {}, "marks": {}, "drops": {}}
for path in sys.argv[1:]:
    r = load(path)
    if not r: print("nothing recorded in", path); continue
    for k in merged:
        t = r[k]
        if not t: continue
        for key in t:
            v = t[key]
            cur = merged[k].setdefault(key, {"spots": [], "rec": v})
            sp = tolist(v["spots"]) if v["spots"] else []
            cur["spots"] += [tuple(sp[i:i + 3]) for i in range(0, len(sp), 3)]

print("== Beasts seen that the data doesn't have")
for nid, v in sorted(merged["beasts"].items()):
    rec = v["rec"]
    if int(nid) not in known:
        print(f"  {nid} {rec['name']} family={rec['fam']} level={rec['lo']}-{rec['hi']} spots={sorted(set(v['spots']))[:6]}")
print("== Known beasts seen on maps the data doesn't list")
for nid, v in sorted(merged["beasts"].items()):
    if int(nid) in known:
        maps = {int(s[0]) for s in v["spots"]} - known[int(nid)][1]
        if maps: print(f"  {nid} {known[int(nid)][0]} on {sorted(maps)}")
print("== Rares seen")
for nid, v in sorted(merged["rares"].items()):
    print(f"  {nid} {v['rec']['name']} level={v['rec']['lo']} at {sorted(set(v['spots']))[:4]}")
print("== Library books")
for name, v in sorted(merged["books"].items()):
    rec = v["rec"]
    flag = "" if name in books else "  (NOT in Books_Forever.lua)"
    print(f"  {name}: item={rec['item']} quest={rec['quest']} found at {v['spots']}{flag}")
print("== Minimap marks")
for key, v in sorted(merged["marks"].items(), key=lambda t: str(t[0])):
    print(f"  {key} {v['rec']['name']} ({v['rec']['atlas']}) at {sorted(set(v['spots']))[:4]}")
print("== Chests opened")
for key, v in sorted(merged["drops"].items(), key=lambda t: str(t[0])):
    if str(key).startswith("o") and v["spots"]:
        print(f"  {key} {v['rec']['name']} at {sorted(set(v['spots']))[:8]}")
