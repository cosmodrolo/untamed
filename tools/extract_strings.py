"""Collect every L["..."] phrase in the addon into tools/phrases_enUS.lua, for importing into
CurseForge's localization tool (Project > Localization > Import, format: Lua additive table)."""
import re, glob, os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
keys = set()
for f in glob.glob(os.path.join(root, "*.lua")):
    keys |= set(re.findall(r'L\["((?:[^"\\]|\\.)*)"\]', open(f, encoding="utf-8").read()))
out = os.path.join(root, "tools", "phrases_enUS.lua")
with open(out, "w", encoding="utf-8") as o:
    for k in sorted(keys): o.write('L["%s"] = true\n' % k)
print(len(keys), "phrases ->", out)
