"""Load QuestieDB's Forever trace corrections (live data aggregated from players' QuestieTrace
recordings) as plain Python dicts: {id: {fieldName: value}}.

Trace files look like `return { [id] = { [npcKeys.spawns] = {...}, ... } }` inside a module's
Load(). We run them in Lua with stub modules whose key tables return the field name itself, so
the result is keyed by names ("spawns", "npcDrops_add", ...) and needs no index table.
"""
import os
from lupa import LuaRuntime

FILES = {"npc": "foreverNpcTraces.lua", "item": "foreverItemTraces.lua",
         "object": "foreverObjectTraces.lua", "quest": "foreverQuestTraces.lua"}

STUB = """
local names = setmetatable({}, { __index = function(_, k) return k end })
local modules = {}
QuestieLoader = {
  CreateModule = function(_, name) local m = {}; modules[name] = m; return m end,
  ImportModule = function(_, name)
    if name == "QuestieDB" then return { npcKeys = names, itemKeys = names, objectKeys = names, questKeys = names } end
    return modules[name] or {}
  end,
}
function __traces_load(src)
  modules = {}
  local chunk = assert((loadstring or load)(src))
  chunk()
  for _, m in pairs(modules) do if m.Load then return m:Load() end end
end
"""


def _py(v):
    if hasattr(v, "keys"):
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [_py(v[k]) for k in sorted(keys)]
        return {k: _py(v[k]) for k in keys}
    return v


def load(questiedb_dir, kind):
    path = os.path.join(questiedb_dir, "src/corrections/Forever/traces", FILES[kind])
    if not os.path.exists(path):
        return {}
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(STUB)
    t = lua.globals().__traces_load(open(path, encoding="utf-8").read())
    return _py(t) if t is not None else {}


if __name__ == "__main__":
    import sys
    for k in FILES:
        d = load(sys.argv[1], k)
        fields = {}
        for rec in d.values():
            for f in rec: fields[f] = fields.get(f, 0) + 1
        print(k, len(d), fields)
