import gzip, re, sys
path, out = sys.argv[1], sys.argv[2]
NAMES = {1: "Meat", 2: "Fish", 3: "Cheese", 4: "Bread", 5: "Fungus", 6: "Fruit", 7: "Meat", 8: "Fish"}  # 7 raw meat, 8 raw fish
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
foods = {}
intable = False
with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
    for line in f:
        if line.startswith("INSERT INTO `item_template`"):
            for v in rows(line):
                ft = int(v[123])
                if ft in NAMES: foods[int(v[0])] = (NAMES[ft], v[3])
print(len(foods), file=sys.stderr)
for k in (5503, 12205, 7974, 4655, 5504, 2674, 1468):
    print(k, foods.get(k), file=sys.stderr)
by = {}
for i, (t, _) in foods.items(): by.setdefault(t, []).append(i)
with open(out, "w") as o:
    o.write("-- Pet food types for every item (Classic item_template.FoodType via cmangos classic-db). Generated.\nlocal _, ns = ...\nns.FoodType = {}\n")
    for t in sorted(by):
        o.write("for _, id in ipairs({%s}) do ns.FoodType[id] = %s end\n" % (",".join(map(str, sorted(by[t]))), '"' + t + '"'))
