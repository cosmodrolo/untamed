#!/usr/bin/env python3
"""Build Untamed's search index (items, NPCs, objects, quests) from QuestieDB.

usage: build_search.py QUESTIEDB_DIR FLAVOR OUT_PATH
  FLAVOR: era | forever

The index is stored as a Lua source string (ns.SearchSource) and only turned into
tables the first time the player opens Search, so it costs no memory until used.
QuestieDB is GPL-3.0, like Untamed.
"""
import os, re, sys
from lupa import LuaRuntime

Q, FLAVOR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
pre = "Classic/classic" if FLAVOR == "era" else "Forever/forever"
ZDIR = os.path.join(Q, "support/Zones" if FLAVOR == "era" else "support/Forever/Zones")
lua = LuaRuntime(unpack_returned_tuples=True)

def log(*a): print(*a, file=sys.stderr)

def load(kind):
    text = open(os.path.join(Q, "data", pre + kind + "DB.lua"), encoding="utf-8").read()
    body = text[text.index("[[return {") + 2: text.rindex("}]]") + 1]
    return lua.execute(body)

def pylist(t):
    if t is None: return []
    return [t[k] for k in sorted(t.keys())] if hasattr(t, "keys") else list(t)

# ------------------------------------------------------------------ zones
zmap = {}
for line in open(os.path.join(ZDIR, "uiMapIdToAreaId.lua"), encoding="utf-8"):
    m = re.match(r"\s*\[(\d+)\]\s*=\s*(\d+),", line)
    if m:
        ui, area = int(m.group(1)), int(m.group(2))
        if ((1411 <= ui <= 1458) or ui >= 2000) and area not in zmap: zmap[area] = ui
if FLAVOR == "forever":
    for line in open(os.path.join(ZDIR, "areaIdToUiMapId.lua"), encoding="utf-8"):
        m = re.match(r"\s*\[(\d+)\]\s*=\s*(\d+),", line)
        if m:
            area, ui = int(m.group(1)), int(m.group(2))
            if ((1411 <= ui <= 1458 and ui not in (1414, 1415)) or ui >= 2000): zmap.setdefault(area, ui)
dungeons = {}
for line in open(os.path.join(ZDIR, "dungeons.lua"), encoding="utf-8"):
    m = re.match(r"\s*\[(\d+)\]\s*=\s*\{\s*\"([^\"]+)\",(nil|\{[0-9,]*\}),(\d+|nil),(\{.*?\}\}|nil)", line)
    if not m: continue
    locs = [(zmap[int(z)], float(x), float(y)) for z, x, y in re.findall(r"\{(\d+),\s*([0-9.]+),\s*([0-9.]+)\}", m.group(5) or "") if int(z) in zmap]
    ent = (m.group(2), locs[0] if locs else None)
    dungeons[int(m.group(1))] = ent
    if m.group(3) != "nil":
        for alt in re.findall(r"\d+", m.group(3)): dungeons.setdefault(int(alt), ent)

def place(spawns, mainZone):
    """Best single spot: (uiMapID, x, y, instanceName or None)."""
    sp = {}
    if spawns is not None:
        for area in spawns.keys(): sp[int(area)] = pylist(spawns[area])
    order = sorted(sp, key=lambda a: (a != mainZone, -len(sp[a])))
    for area in order:
        if area in zmap and sp[area]:
            p = sp[area][0]
            return zmap[area], round(float(p[1]), 1), round(float(p[2]), 1), None
    for area in order + [mainZone]:
        if area in dungeons:
            name, loc = dungeons[area]
            if loc: return loc[0], round(loc[1], 1), round(loc[2], 1), name
            return 0, 0, 0, name
    return None

# ------------------------------------------------------------------ data
items, npcs, objects, quests = load("Item"), load("Npc"), load("Object"), load("Quest")
log("items", len(items), "npcs", len(npcs), "objects", len(objects), "quests", len(quests))

DROP_CAP, VEND_CAP = 10, 8
I, needN, needO, needQ = {}, set(), set(), set()
for iid in items.keys():
    r = items[iid]
    name = r[1]
    if not name or "test" in name.lower() or name.startswith("Monster -") or name.startswith("Deprecated"): continue
    drops = pylist(r[2]); objs = pylist(r[3]); rew = pylist(r[6]); vend = pylist(r[14])
    if not (drops or objs or rew or vend): continue
    nd = len(drops)
    drops = drops[:DROP_CAP] if nd <= DROP_CAP else []
    vend = vend[:VEND_CAP]; objs = objs[:4]; rew = rew[:4]
    needN.update(drops); needN.update(vend); needO.update(objs); needQ.update(rew)
    I[int(iid)] = (name, r[9] or 0, r[10] or 0, r[12] or 0, r[13] or 0, vend, drops, nd, objs, rew, r[8] or 0, r[11] or 0)

N = {}
for nid in npcs.keys():
    r = npcs[nid]
    name = r[1]
    if not name or name.startswith("[") or "test" in name.lower() or "trigger" in name.lower(): continue
    pl = place(r[7], r[9] or 0)
    if not pl and int(nid) not in needN: continue
    m, x, y, inst = pl or (0, 0, 0, None)
    N[int(nid)] = (name, r[4] or 0, r[5] or 0, r[14] or "", m, x, y, r[13] or "", r[6] or 0, inst or "")

O = {}
for oid in needO:
    r = objects[oid]
    if r is None: continue
    pl = place(r[4], r[5] or 0)
    m, x, y, inst = pl or (0, 0, 0, None)
    O[int(oid)] = (r[1], m, x, y, inst or "")

Qd = {}
for qid in needQ:
    r = quests[qid]
    if r is None: continue
    starter = 0
    sb = r[2]
    if sb is not None and sb[1] is not None:
        c = pylist(sb[1])
        if c: starter = int(c[0]); needN.add(starter)
    Qd[int(qid)] = (r[1], r[5] or 0, starter)

# ------------------------------------------------------------------ emit
def s(v): return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'
def n(v):
    if isinstance(v, float): return ("%.1f" % v).rstrip("0").rstrip(".")
    return str(int(v))
def arr(a): return "{" + ",".join(n(x) for x in a) + "}" if a else "nil"

out = []
out.append("I={")
for k in sorted(I):
    v = I[k]
    out.append("[%d]={%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), n(v[3]), n(v[4]), arr(v[5]), arr(v[6]), n(v[7]), arr(v[8]), arr(v[9]), n(v[10]), n(v[11])))
out.append("},N={")
for k in sorted(N):
    v = N[k]
    out.append("[%d]={%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), s(v[3]), n(v[4]), n(v[5]), n(v[6]), s(v[7]), n(v[8]), s(v[9])))
out.append("},O={")
for k in sorted(O):
    v = O[k]
    out.append("[%d]={%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), n(v[3]), s(v[4])))
out.append("},Q={")
for k in sorted(Qd):
    v = Qd[k]
    out.append("[%d]={%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2])))
out.append("}")
body = "\n".join(out)
assert "]==]" not in body
with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- Generated by tools/build_search.py from QuestieDB (GPL-3.0). Do not edit.\n")
    f.write("-- Items: {name, itemLevel, reqLevel, class, subclass, vendors, drops, dropCount, objects, questRewards, foodType, ammoType}\n")
    f.write("-- NPCs: {name, minLevel, maxLevel, title, uiMapID, x, y, friendlyTo, rank, instance}\n")
    f.write("local _, ns = ...\nns.SearchSource = [==[return {\n" + body + "\n}]==]\n")
log("wrote", OUT, "items", len(I), "npcs", len(N), "objects", len(O), "quests", len(Qd), "bytes", os.path.getsize(OUT))
