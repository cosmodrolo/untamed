#!/usr/bin/env python3
"""Build Untamed's search index (items, NPCs, objects, quests) from QuestieDB.

usage: build_search.py QUESTIEDB_DIR FLAVOR OUT_PATH [CMANGOS_SQL] [RECORDED_SAVEDVARIABLES ...]
  RECORDED: players' WTF/Account/<name>/SavedVariables/Untamed.lua files. Vendors and loot they
  recorded in game are merged in (only for items and NPCs QuestieDB knows, so names stay correct).
  FLAVOR: era | forever

The index is stored as a Lua source string (ns.SearchSource) and only turned into
tables the first time the player opens Search, so it costs no memory until used.
QuestieDB is GPL-3.0, like Untamed.
"""
import os, re, sys
from lupa import LuaRuntime

Q, FLAVOR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SQL = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] != "-" else None
RECORDED = sys.argv[5:]
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

# ------------------------------------------------------------------ cmangos extras: quality, slot, price, binding, crafting, fishing
EXTRA, CRAFT, FISH, VREP = {}, {}, {}, {}
if SQL:
    def rows(line):
        i = line.index("VALUES") + 6; n = len(line)
        while i < n:
            while i < n and line[i] != "(": i += 1
            if i >= n: break
            i += 1; vals = []; cur = []; inq = False
            while True:
                c = line[i]
                if inq:
                    if c == "\\": cur.append(line[i + 1]); i += 2; continue
                    if c == "'": inq = False
                    else: cur.append(c)
                else:
                    if c == "'": inq = True
                    elif c == ",": vals.append("".join(cur)); cur = []
                    elif c == ")": vals.append("".join(cur)); i += 1; break
                    else: cur.append(c)
                i += 1
            yield vals
    T = {"item_template": [], "spell_template": [], "fishing_loot_template": [], "npc_vendor": [], "conditions": []}
    for line in open(SQL, encoding="utf-8", errors="replace"):
        m = re.match(r"INSERT INTO `(\w+)`", line)
        if m and m.group(1) in T: T[m.group(1)].extend(rows(line))
    SP = {int(v[0]): v for v in T["spell_template"]}
    creates = {}
    for v in T["spell_template"]:
        for k in range(3):
            if v[61 + k] == "24" and v[103 + k] not in ("", "0"):
                creates[int(v[0])] = int(v[103 + k])
    PROF = {1: "Leatherworking", 2: "Tailoring", 3: "Engineering", 4: "Blacksmithing", 5: "Cooking", 6: "Alchemy",
            7: "First Aid", 8: "Enchanting", 9: "Fishing"}
    for v in T["item_template"]:
        EXTRA[int(v[0])] = (int(v[5]), int(v[10]), int(v[105] or 0), int(v[8] or 0), int(v[20] or 0), int(v[21] or 0))
        if v[1] == "9":                                   # recipe: which profession makes the item
            prof = PROF.get(int(v[2]))
            for k in range(5):
                sid = int(v[70 + 7 * k] or 0)
                sp = SP.get(sid)
                if sp and sp[61] == "36" and sp[109] not in ("", "0"): sid = int(sp[109])
                if sid in creates and prof: CRAFT[creates[sid]] = prof
    for sid, iid in creates.items():
        CRAFT.setdefault(iid, "Crafted")
    for v in T["fishing_loot_template"]:
        area, iid = int(v[0]), int(v[1])
        if iid > 0: FISH.setdefault(iid, set()).add(area)
    # Reputation a vendor wants before selling an item (conditions: type 5 = minimum rank, -1 AND, -2 OR).
    COND = {int(v[0]): v for v in T["conditions"]}
    def reps(cid, depth=0):
        c = COND.get(cid)
        if not c or depth > 5: return []
        t = int(c[1])
        if t == 5: return [(int(c[2]), int(c[3]))]
        if t in (-1, -2):
            out = []
            for k in (2, 3, 4, 5):
                if c[k] not in ("", "0"): out += reps(int(c[k]), depth + 1)
            return out
        return []
    for v in T["npc_vendor"]:
        cid = int(v[5] or 0)
        if not cid: continue
        rr = reps(cid)
        if rr: VREP.setdefault(int(v[1]), {})[int(v[0])] = rr
    log("cmangos extras", len(EXTRA), "crafted", len(CRAFT), "fishing items", len(FISH), "reputation vendor items", len(VREP))

# ------------------------------------------------------------------ data
items, npcs, objects, quests = load("Item"), load("Npc"), load("Object"), load("Quest")
log("items", len(items), "npcs", len(npcs), "objects", len(objects), "quests", len(quests))

DROP_CAP, VEND_CAP = 10, 200   # keep every vendor: a short list can miss your faction entirely
I, needN, needO, needQ, needI = {}, set(), set(), set(), set()
for iid in items.keys():
    r = items[iid]
    name = r[1]
    if not name or "test" in name.lower() or name.startswith("Monster -") or name.startswith("Deprecated"): continue
    drops = pylist(r[2]); objs = pylist(r[3]); inside = pylist(r[4]); rew = pylist(r[6]); vend = pylist(r[14])
    craft = CRAFT.get(int(iid), "")
    fish = sorted({zmap[a] for a in FISH.get(int(iid), ()) if a in zmap})[:4]
    if not (drops or objs or rew or vend or inside or craft or fish): continue
    nd = len(drops)
    drops = drops[:DROP_CAP] if nd <= DROP_CAP else []
    # Prefer chests and nodes that have a known position.
    objs.sort(key=lambda o: 0 if (objects[o] is not None and objects[o][4] is not None) else 1)
    vend = vend[:VEND_CAP]; objs = objs[:4]; rew = rew[:4]; inside = inside[:4]
    needN.update(drops); needN.update(vend); needO.update(objs); needQ.update(rew); needI.update(inside)
    q, inv, bond, price, repF, repR = EXTRA.get(int(iid), (1, 0, 0, 0, 0, 0))
    I[int(iid)] = (name, r[9] or 0, r[10] or 0, r[12] or 0, r[13] or 0, vend, drops, nd, objs, rew, r[8] or 0, r[11] or 0,
                   q, inv, bond, price, inside, craft, fish, repF, repR,
                   [[npc] + [x for fr in VREP[int(iid)][npc] for x in fr] for npc in sorted(VREP.get(int(iid), {}))])

# ------------------------------------------------------------------ player recordings
rec_v = rec_d = 0
for path in RECORDED:
    rl = LuaRuntime(unpack_returned_tuples=True)
    rl.execute(open(path, encoding="utf-8").read())
    udb = rl.globals().UntamedDB
    rec = udb["recorded"] if udb is not None else None
    r = rec[FLAVOR] if rec is not None else None
    if r is None: continue
    vendors, drops_ = r["vendors"], r["drops"]
    for npc in (list(vendors.keys()) if vendors is not None else []):
        v = vendors[npc]
        if npcs[npc] is None: continue
        its = v["items"]
        for iid in (list(its.keys()) if its is not None else []):
            it = I.get(int(iid))
            if it and int(npc) not in it[5]:
                it[5].append(int(npc)); needN.add(int(npc)); rec_v += 1
    for key in (list(drops_.keys()) if drops_ is not None else []):
        m = re.match(r"^c(\d+)$", str(key))
        if not m: continue
        nid = int(m.group(1))
        if npcs[nid] is None: continue
        its = drops_[key]["items"]
        for iid in (list(its.keys()) if its is not None else []):
            it = I.get(int(iid))
            if it and nid not in it[6] and it[7] <= DROP_CAP:
                it[6].append(nid); needN.add(nid); rec_d += 1
if RECORDED: log("merged player recordings: vendor links", rec_v, "drop links", rec_d)

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
    if pl:
        m, x, y, inst = pl
    else:
        # No exact spot (random chests, fishing pools): keep the zone if known.
        m, x, y, inst = zmap.get(r[5] or 0, 0), 0, 0, (dungeons[r[5]][0] if (r[5] or 0) in dungeons else None)
    spots = 0
    if r[4] is not None:
        for area in r[4].keys(): spots += len(pylist(r[4][area]))
    O[int(oid)] = (r[1], m, x, y, inst or "", spots)

Qd = {}
for qid in needQ:
    r = quests[qid]
    if r is None: continue
    starter = 0
    sb = r[2]
    if sb is not None and sb[1] is not None:
        c = pylist(sb[1])
        if c: starter = int(c[0]); needN.add(starter)
    Qd[int(qid)] = (r[1], r[5] or 0, starter, r[6] or 0)

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
    out.append("[%d]={%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), n(v[3]), n(v[4]), arr(v[5]), arr(v[6]), n(v[7]), arr(v[8]), arr(v[9]), n(v[10]), n(v[11]),
        n(v[12]), n(v[13]), n(v[14]), n(v[15]), arr(v[16]), s(v[17]), arr(v[18]), n(v[19]), n(v[20]),
        ("{" + ",".join(arr(x) for x in v[21]) + "}") if v[21] else "nil"))
out.append("},C={")
for k in sorted(needI):
    if k not in I and items[k] is not None: out.append("[%d]=%s," % (k, s(items[k][1])))
out.append("},N={")
for k in sorted(N):
    v = N[k]
    out.append("[%d]={%s,%s,%s,%s,%s,%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), s(v[3]), n(v[4]), n(v[5]), n(v[6]), s(v[7]), n(v[8]), s(v[9])))
out.append("},O={")
for k in sorted(O):
    v = O[k]
    out.append("[%d]={%s,%s,%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), n(v[3]), s(v[4]), n(v[5])))
out.append("},Q={")
for k in sorted(Qd):
    v = Qd[k]
    out.append("[%d]={%s,%s,%s,%s}," % (k, s(v[0]), n(v[1]), n(v[2]), n(v[3])))
out.append("}")
body = "\n".join(out)
assert "]==]" not in body
with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- Generated by tools/build_search.py from QuestieDB (GPL-3.0). Do not edit.\n")
    f.write("-- Items: {name, itemLevel, reqLevel, class, subclass, vendors, drops, dropCount, objects, questRewards, foodType, ammoType,\n")
    f.write("--         quality, inventoryType, binding, buyPrice, foundInsideItems, craftedBy, fishingZones, repFaction, repRank,\n")
    f.write("--         vendorReputation {{vendorNpc, faction, rank, faction, rank, ...}, ...} (any one faction/rank pair is enough)}\n")
    f.write("-- C: names of container items that aren't otherwise in I\n")
    f.write("-- Objects: {name, uiMapID, x, y, instance, spawnPoints}\n")
    f.write("-- NPCs: {name, minLevel, maxLevel, title, uiMapID, x, y, friendlyTo, rank, instance}\n")
    f.write("local _, ns = ...\nns.SearchSource = [==[return {\n" + body + "\n}]==]\n")
log("wrote", OUT, "items", len(I), "npcs", len(N), "objects", len(O), "quests", len(Qd), "bytes", os.path.getsize(OUT))
