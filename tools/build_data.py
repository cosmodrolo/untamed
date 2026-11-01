#!/usr/bin/env python3
"""Build Untamed Data.lua for a flavor ("era" or "forever").

usage: build2.py SRC_DIR FLAVOR OUT_PATH [forever_pets.json]
Sources:
  vanilla-hunter-pets/index.html  (VMaNGOS tameable beasts + abilities, via shagu)
  QuestieDB                       (NPC spawns, stable/flight masters, zone ids)
  forever_pets.json               (Forever beast abilities, compiled from public sites)
"""
import re, sys, json, os

SRC, FLAVOR, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
FJSON = sys.argv[4] if len(sys.argv) > 4 else None
Q = os.path.join(SRC, "QuestieDB")
if FLAVOR == "era":
    NPCDB = os.path.join(Q, "data/Classic/classicNpcDB.lua")
    ZDIR = os.path.join(Q, "support/Zones")
else:
    NPCDB = os.path.join(Q, "data/Forever/foreverNpcDB.lua")
    ZDIR = os.path.join(Q, "support/Forever/Zones")

def log(*a): print(*a, file=sys.stderr)

# ---------------------------------------------------------------- shagu beasts
html = open(os.path.join(SRC, "vanilla-hunter-pets/index.html"), encoding="utf-8").read()
tame = {}
family = None
token_re = re.compile(r"<div class='family' id='\d+'>Pet Family: ([A-Za-z ]+)</div>|<div class='pet'>")
for m in token_re.finditer(html):
    if m.group(1):
        family = m.group(1).strip(); continue
    start = m.end()
    end = html.find("<div class='pet'>", start)
    fam_next = html.find("<div class='family'", start)
    if end == -1: end = len(html)
    if fam_next != -1 and fam_next < end: end = fam_next
    block = html[start:end]
    idm = re.search(r"\?npc=(\d+)'>([^<]+)</a>", block)
    if not idm: continue
    npc = int(idm.group(1)); name = idm.group(2).replace("&#39;", "'").replace("&amp;", "&")
    lvl = re.search(r"Level: <b>([0-9]+)(?:-([0-9]+))?</b>", block)
    lo = int(lvl.group(1)); hi = int(lvl.group(2) or lvl.group(1))
    rk = re.search(r"Level: <b>[^<]*</b> \(<span[^>]*>([^<]+)</span>\)", block)
    spd = re.search(r"Attack Speed: <b>([0-9.]+)</b>", block)
    img = re.search(r"img/([a-z]+)\.jpg", block)
    skin = None
    if img:
        s = re.sub(r"^[a-z]+?skin", "", img.group(1))
        skin = s.capitalize() if s and s != img.group(1) else None
    builds = re.findall(r"<div class='build'>(.*?)</div>", block, re.S)
    spells = []
    if builds:
        for s in re.findall(r"\[([A-Za-z' ]+?) Rank (\d+)\]", builds[-1]):
            spells.append((s[0], int(s[1])))
    tame[npc] = dict(name=name, lo=lo, hi=hi, fam=family, rank=rk.group(1) if rk else None,
                     speed=float(spd.group(1)) if spd else None, skin=skin, spells=spells)
log("shagu tameable:", len(tame))

# ---------------------------------------------------------------- forever overlay
if FLAVOR == "forever":
    for b in tame.values():
        if b["fam"] == "Owl": b["fam"] = "Bird of Prey"
        b["speed"] = None          # attack speed is a trained ability in Forever
        b["spells"] = []           # Forever ability data comes from the json only
    if FJSON:
        fj = json.load(open(FJSON, encoding="utf-8"))
        byname = {}
        for nid, b in tame.items(): byname.setdefault(b["name"].lower(), nid)
        added = matched = 0
        for fb in fj.get("beasts", []):
            nid = fb.get("npcId")
            if not nid: nid = byname.get((fb.get("name") or "").lower())
            if not nid: continue
            teaches = [(t[0], int(t[1])) for t in fb.get("teaches", []) if len(t) >= 2 and t[1] is not None]
            if nid in tame:
                b = tame[nid]; matched += 1
                if fb.get("family"): b["fam"] = fb["family"]
                b["zone"] = fb.get("zone")
                b["spells"] = sorted(set(b["spells"]) | set(teaches))
            else:
                tame[nid] = dict(name=fb.get("name"), lo=fb.get("minLevel") or 1, hi=fb.get("maxLevel") or fb.get("minLevel") or 1,
                                 fam=fb.get("family"), rank=None, speed=None, skin=None, spells=teaches, zone=fb.get("zone"))
                added += 1
        log("forever json: matched", matched, "added", added)

# ---------------------------------------------------------------- zones
zmap = {}
for line in open(os.path.join(ZDIR, "uiMapIdToAreaId.lua"), encoding="utf-8"):
    m = re.match(r"\s*\[(\d+)\]\s*=\s*(\d+),\s*--\s*(.*)", line)
    if m:
        ui, area, nm = int(m.group(1)), int(m.group(2)), m.group(3).strip()
        if 1411 <= ui <= 1458 and area not in zmap:
            zmap[area] = (ui, nm)
if FLAVOR == "forever":
    uinames = {ui: nm for ui, nm in zmap.values()}
    for line in open(os.path.join(ZDIR, "areaIdToUiMapId.lua"), encoding="utf-8"):
        m = re.match(r"\s*\[(\d+)\]\s*=\s*(\d+),\s*--\s*(.*)", line)
        if not m: continue
        area, ui, nm = int(m.group(1)), int(m.group(2)), m.group(3).strip()
        if not ((1411 <= ui <= 1458 and ui not in (1414, 1415)) or ui >= 2000): continue
        if "->" in nm: nm = nm.split("->")[-1].strip()
        nm = nm.split(":")[0].strip()
        if ui not in uinames: uinames[ui] = nm
        zmap.setdefault(area, (ui, uinames[ui]))
zone_by_name = {nm.lower(): ui for ui, nm in set(zmap.values())}
dnames = {}
for line in open(os.path.join(ZDIR, "dungeons.lua"), encoding="utf-8"):
    m = re.match(r"\s*\[(\d+)\]\s*=\s*\{\s*\"([^\"]+)\",(nil|\{[0-9,]*\}),(\d+|nil),(\{.*?\}\}|nil)", line)
    if not m: continue
    locs = []
    for z, x, y in re.findall(r"\{(\d+),\s*([0-9.]+),\s*([0-9.]+)\}", m.group(5) or ""):
        if int(z) in zmap: locs.append((zmap[int(z)][0], float(x), float(y)))
    ent = (m.group(2), locs)
    dnames[int(m.group(1))] = ent
    if m.group(3) != "nil":
        for alt in re.findall(r"\d+", m.group(3)): dnames.setdefault(int(alt), ent)

# ---------------------------------------------------------------- lua literal parser
class P:
    def __init__(s, t): s.t, s.i = t, 0
    def ws(s):
        while s.i < len(s.t) and s.t[s.i] in " \t\r\n": s.i += 1
    def val(s):
        s.ws(); c = s.t[s.i]
        if c == "{": return s.tbl()
        if c in "'\"":
            q = c; s.i += 1; out = []
            while s.t[s.i] != q:
                if s.t[s.i] == "\\": s.i += 1
                out.append(s.t[s.i]); s.i += 1
            s.i += 1; return "".join(out)
        m = re.compile(r"-?[0-9.]+(?:e-?\d+)?|nil|true|false").match(s.t, s.i)
        s.i = m.end(); v = m.group(0)
        if v == "nil": return None
        if v in ("true", "false"): return v == "true"
        return float(v) if ("." in v or "e" in v) else int(v)
    def tbl(s):
        s.i += 1; arr = []; d = {}
        while True:
            s.ws()
            if s.t[s.i] == "}": s.i += 1; break
            if s.t[s.i] == "[":
                s.i += 1; k = s.val(); s.ws(); s.i += 1; s.ws(); s.i += 1
                d[k] = s.val()
            else:
                arr.append(s.val())
            s.ws()
            if s.t[s.i] == ",": s.i += 1
        return d if d else arr

npcdb, services_raw = {}, []
for line in open(NPCDB, encoding="utf-8"):
    m = re.match(r"\[(\d+)\] = (\{.*\}),?\s*$", line)
    if not m: continue
    nid = int(m.group(1))
    flags_m = re.search(r",(\d+)\},?\s*$", line)
    flags = int(flags_m.group(1)) if flags_m else 0
    if nid in tame or (flags & (8 | 8192)):
        try:
            rec = P(m.group(2)).val()
        except Exception as e:
            log("parse fail", nid, e); continue
        if nid in tame: npcdb[nid] = rec
        if flags & (8 | 8192) and isinstance(rec, list) and "test" not in str(rec[0]).lower():
            services_raw.append((nid, rec, flags))

# ---------------------------------------------------------------- emit
def thin(points, grid=1.2, cap=45):
    seen, out = set(), []
    for x, y in points:
        k = (round(x / grid), round(y / grid))
        if k in seen: continue
        seen.add(k); out.append((x, y))
    if len(out) > cap:
        step = len(out) / cap
        out = [out[int(i * step)] for i in range(cap)]
    return out

def lstr(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'
def lval(v):
    if v is None or v is False: return "false"
    if isinstance(v, str): return lstr(v)
    if isinstance(v, float): return ("%.2f" % v).rstrip("0").rstrip(".")
    return str(v)

lines, nospawn = [], []
for nid in sorted(tame, key=lambda n: (str(tame[n]["fam"]), tame[n]["lo"], n)):
    b = tame[nid]
    rec = npcdb.get(nid)
    spawns, inst = [], None
    if rec and isinstance(rec, list) and len(rec) >= 7 and isinstance(rec[6], dict):
        for area, pts in rec[6].items():
            if area in zmap:
                pts = [p for p in pts if isinstance(p, list) and len(p) == 2 and p[0] >= 0]
                if pts:
                    spawns.append("[%d]={%s}" % (zmap[area][0], ",".join("%.1f,%.1f" % p for p in thin(pts))))
            elif area in dnames:
                inst = dnames[area][0]
                for ui, x, y in dnames[area][1]:
                    spawns.append("[%d]={%.1f,%.1f}" % (ui, x, y))
    if not spawns and b.get("zone") and b["zone"].lower() in zone_by_name and b["spells"]:
        spawns.append("[%d]={}" % zone_by_name[b["zone"].lower()])
    if not spawns:
        nospawn.append(b["name"]); continue
    sp = ",".join('%s,%d' % (lstr(a), r) for a, r in b["spells"])
    lines.append('  [%d]={%s,%d,%d,%s,%s,{%s},{%s},%s,%s,%s},' % (
        nid, lstr(b["name"]), b["lo"], b["hi"], lstr(b["fam"]), lval(b["rank"]), sp, ",".join(spawns),
        lval(inst), lval(b["speed"]), lval(b["skin"])))

svc_lines = []
for nid, rec, flags in services_raw:
    kind = "S" if flags & 8192 else "F"
    fac = rec[12] if len(rec) > 12 and rec[12] else "AH"
    sp = rec[6] if len(rec) > 6 and isinstance(rec[6], dict) else {}
    for area, pts in sp.items():
        if area in zmap and pts and isinstance(pts[0], list):
            x, y = pts[0]
            svc_lines.append('  {"%s",%s,"%s",%d,%.1f,%.1f},' % (kind, lstr(rec[0]), fac, zmap[area][0], x, y))

with open(OUT, "w", encoding="utf-8") as f:
    f.write("-- Untamed data (%s). Generated by build2.py; do not edit by hand.\n" % FLAVOR)
    f.write("-- Beasts and abilities: VMaNGOS via shagu/vanilla-hunter-pets%s.\n" % ("; Forever abilities compiled from public Forever pet guides" if FLAVOR == "forever" else ""))
    f.write("-- Spawns, stable masters, flight masters: QuestieDB (GPL-3.0).\n")
    f.write("-- Beasts: [npcId] = {name, minLvl, maxLvl, family, rankText, {ability, rank, ...}, {[uiMapID] = {x, y, ...}}, instance, attackSpeed, skin}\n")
    f.write("local _, ns = ...\n")
    f.write('ns.FLAVOR = "%s"\n' % FLAVOR)
    f.write("ns.Beasts = {\n" + "\n".join(lines) + "\n}\n")
    f.write("-- Services: {kind S=stable F=flight, name, faction, uiMapID, x, y}\n")
    f.write("ns.Services = {\n" + "\n".join(svc_lines) + "\n}\n")
    if FLAVOR == "forever" and FJSON:
        TRAINER = {"Growl", "Great Stamina", "Natural Armor", "Arcane Resistance", "Fire Resistance", "Frost Resistance",
                   "Nature Resistance", "Shadow Resistance", "Faster Attack", "Slower Attack"}
        fams = {}
        for fam, info in fj["families"].items():
            for a in info.get("abilities", []):
                if a not in TRAINER: fams.setdefault(a, []).append(fam)
        f.write("ns.ForeverAbilities = {\n")
        for a, info in sorted(fj["abilities"].items()):
            if a in TRAINER or a not in fams: continue
            rk = sorted(info.get("ranks", []), key=lambda r: r["rank"])
            lv = ",".join(str(r.get("level") or 0) for r in rk)
            tp = ",".join(str(r.get("tp") if r.get("tp") is not None else 0) for r in rk)
            note = info.get("note") or ""
            f.write('  [%s]={families={%s},levels={%s},tp={%s},source=%s,confidence=%s,note=%s},\n' % (
                lstr(a), ",".join(lstr(x) for x in sorted(fams[a])), lv, tp, lstr(info.get("source") or "beast"),
                lstr(info.get("sourceConfidence") or "high"), lstr(note)))
        f.write("}\n")
        removed = [a for a in ["Screech"] if a not in fams]
        f.write("ns.ForeverRemoved = {%s}\n" % ",".join(lstr(a) for a in removed))
        f.write("ns.ForeverDiets = {\n" + "\n".join('  [%s]={%s},' % (lstr(k), ",".join(lstr(x) for x in v.get("diet", []))) for k, v in sorted(fj["families"].items())) + "\n}\n")
    f.write("ns.ZoneNames = {\n" + "\n".join('  [%d]=%s,' % (ui, lstr(nm)) for ui, nm in sorted(set(zmap.values()))) + "\n}\n")

log("beasts written:", len(lines), "teaching:", sum(1 for b in tame.values() if b["spells"]), "no spawn:", len(nospawn))
log("services:", len(svc_lines), "S", sum(1 for l in svc_lines if '"S"' in l), "F", sum(1 for l in svc_lines if '"F"' in l))
