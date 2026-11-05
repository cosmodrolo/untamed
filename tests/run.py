"""Offline smoke tests: load the addon against a mocked WoW API (Lua 5.1 via lupa) and run each scenario.

usage: python tests/run.py
"""
import os, sys
import lupa.lua51 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, "tests")
CASES = [
    ("Untamed_Vanilla.toc", ["mock.lua"], "scenario_era.lua"),
    ("Untamed_Vanilla.toc", ["mock.lua"], "scenario_food.lua"),
    ("Untamed_Forever.toc", ["mock.lua", "mock_forever.lua"], "scenario_forever.lua"),
    ("Untamed_Vanilla.toc", ["mock.lua"], "scenario_features.lua"),
    ("Untamed_Forever.toc", ["mock.lua", "mock_forever.lua"], "scenario_features.lua"),
    ("Untamed_Vanilla.toc", ["mock.lua", "mock_deDE.lua"], "scenario_locale.lua"),
    ("Untamed_Vanilla.toc", ["mock.lua"], "scenario_combat.lua"),
    ("Untamed_Forever.toc", ["mock.lua", "mock_forever.lua"], "scenario_combat.lua"),
    ("Untamed_Vanilla.toc", ["mock.lua"], "scenario_arrow.lua"),
    ("Untamed_Forever.toc", ["mock.lua", "mock_forever.lua"], "scenario_arrow.lua"),
]

def run(toc, mocks, scenario):
    lua = L.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("unpack = unpack or table.unpack")
    for m in mocks:
        lua.execute(open(os.path.join(T, m), encoding="utf-8").read())
    lua.execute("NS = {}")
    load = lua.eval("function(code, name) local f, err = loadstring(code, '@' .. name); if not f then error(err) end; return f end")
    for line in open(os.path.join(ROOT, toc), encoding="utf-8"):
        fn = line.strip().replace("\\", "/")
        if not fn or fn.startswith("#") or fn.endswith(".xml"): continue
        load(open(os.path.join(ROOT, fn), encoding="utf-8").read(), fn)("Untamed", lua.globals().NS)
    out = []
    lua.globals().print = lambda *a: out.append(" ".join(str(x) for x in a))
    lua.execute(open(os.path.join(T, scenario), encoding="utf-8").read())
    return out

failed = 0
for toc, mocks, scen in CASES:
    try:
        out = run(toc, mocks, scen)
        ok = any("DONE" in l for l in out)
        print(("PASS" if ok else "FAIL"), toc, scen)
        if not ok: failed += 1; print("\n".join(out[-20:]))
    except Exception as e:
        failed += 1
        print("FAIL", toc, scen, e)
sys.exit(1 if failed else 0)
