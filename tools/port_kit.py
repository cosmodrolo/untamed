#!/usr/bin/env python3
"""Bring OneForAll (with the OneForAll Pad controller module) into Untamed as Untamed/Kit.

OneForAll (smoergi/OneForAll_Forever, GPL-3.0-or-later) is copied in whole and renamed mechanically, so a new
OneForAll version only needs this script run again (no hand edits in Kit/: they would be lost). What is ours lives
in Kit/Gate.lua (written by this script) and in Untamed's own files.

  - each file's `local X, FLT = ...` is followed by `FLT = FLT.Kit; if not FLT then return end` (the second value is Untamed's ns)
    (Gate.lua leaves ns.Kit nil while OneForAll or OneForAll Pad is loaded, so the Kit stays idle next to them)
  - OneForAllDB / OneForAllCharDB -> UntamedKitDB / UntamedKitCharDB (Gate.lua copies OneForAll's settings over
    while OneForAll is still loaded, so switching it off keeps them); its older names point nowhere
  - frame and font names "OneForAll..." -> "UntamedKit...", the global table -> UntamedKit
  - asset paths -> Interface\\AddOns\\Untamed\\Kit\\Assets\\
  - the guild message prefix stays "OneForAll", so quest and recipe sharing still talk to guild members using OneForAll

usage: python3 tools/port_kit.py [path to the OneForAll fork clone]   (default /home/claude/src/ofa, branch pad)
Prints the TOC lines; the block between the "# Kit" markers in Untamed_Forever.toc is rewritten.
"""
import pathlib, re, shutil, sys

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/home/claude/src/ofa") / "OneForAll"
ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "Kit"
TOC = ROOT / "Untamed_Forever.toc"
LICENSE_NOTE = "Kit/ is OneForAll by Smoergi (GPL-3.0-or-later), https://github.com/smoergi/OneForAll_Forever\n"

HEADER = re.compile(r"^local ([A-Za-z_]+), *FLT *= *\.\.\.[^\n]*$", re.M)
SUBS = [
    (re.compile(r"\b_G\[ADDON\] = FLT"), "_G.UntamedKit = FLT"),
    (re.compile(r"\bOneForAllCharDB\b"), "UntamedKitCharDB"),
    (re.compile(r"\bOneForAllDB\b"), "UntamedKitDB"),
    (re.compile(r"\bForeverCompanionCharDB\b"), "UntamedKitNoLegacyCharDB"),
    (re.compile(r"\bForeverCompanionDB\b"), "UntamedKitNoLegacyDB"),
    (re.compile(r"\bForeverLibraryTrackerDB\b"), "UntamedKitNoLegacy2DB"),
    (re.compile(r"(AddOns(?:\\\\|\\|/))OneForAll(\\\\|\\|/)(?:Assets)"), r"\1Untamed\2Kit\2Assets"),
    (re.compile(r"GetAddOnMetadata\((\s*)\"OneForAll\""), r'GetAddOnMetadata(\1"Untamed"'),
    (re.compile(r"GetAddOnCPUUsage\(\"OneForAll\"\)"), 'GetAddOnCPUUsage("Untamed")'),
    (re.compile(r"\"OneForAll([A-Za-z_]+)\""), r'"UntamedKit\1"'),
    (re.compile(r"\bSLASH_ONEFORALL(\d)"), r"SLASH_UNTAMEDKIT\1"),
    (re.compile(r"\bSLASH_ONEFORALLPAD(\d)"), r"SLASH_UNTAMEDKITPAD\1"),
    (re.compile(r"SlashCmdList\.ONEFORALLPAD\b"), "SlashCmdList.UNTAMEDKITPAD"),
    (re.compile(r"SlashCmdList\.ONEFORALL\b"), "SlashCmdList.UNTAMEDKIT"),
    (re.compile(r'SlashCmdList\["ONEFORALL"\]'), 'SlashCmdList["UNTAMEDKIT"]'),
]
# plain "OneForAll" strings: names (LDB, display) become "UntamedKit"; the guild message prefix stays
KEEP_PLAIN = re.compile(r"PREFIX\s*=\s*\"OneForAll\"")
PLAIN = re.compile(r"\"OneForAll\"")

GATE = '''local ADDON, ns = ...

-- Untamed Kit: OneForAll (by Smoergi, GPL-3.0-or-later, https://github.com/smoergi/OneForAll_Forever) and the
-- OneForAll Pad controller module, inside Untamed. The files in Kit/ are made by tools/port_kit.py; do not edit them.
--
-- While OneForAll or OneForAll Pad is loaded the Kit stays idle (ns.Kit is nil and every Kit file returns at once),
-- and their settings are copied into the Kit's own saved variables each session, so the moment OneForAll is
-- switched off the Kit takes over with the same settings, books and plans.

local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local function isLoaded(name) local ok, v = pcall(loaded, name); return ok and v and true or false end
local other = (isLoaded("OneForAll") and "OneForAll") or (isLoaded("OneForAllPad") and "OneForAllPad") or nil

local function copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[copy(k, seen)] = copy(v, seen) end
  return c
end

ns.KitIdleFor = other
if other then
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterAllEvents()
    if type(OneForAllDB) == "table" then UntamedKitDB = copy(OneForAllDB) end
    if type(OneForAllCharDB) == "table" then UntamedKitCharDB = copy(OneForAllCharDB) end
  end)
  return
end

ns.Kit = { ASSET_ROOT = "Interface\\\\AddOns\\\\" .. ADDON .. "\\\\Kit\\\\Assets\\\\", DISPLAY_NAME = "Untamed Kit" }
'''


def port_lua(text):
    def head(m):
        # (no extra local: some files are at Lua's limit of 200 locals; the second ... value is Untamed's ns)
        return f"local {m.group(1)}, FLT = ...; FLT = FLT.Kit; if not FLT then return end"
    text, n = HEADER.subn(head, text, count=1)
    if n != 1:
        raise SystemExit("no FLT header")
    for rx, rep in SUBS:
        text = rx.sub(rep, text)
    out = []
    for line in text.split("\n"):
        if not KEEP_PLAIN.search(line):
            line = PLAIN.sub('"UntamedKit"', line)
        out.append(line)
    return "\n".join(out)


def main():
    if not (SRC / "OneForAll.toc").exists():
        raise SystemExit(f"no OneForAll.toc in {SRC}")
    files = []
    for line in (SRC / "OneForAll.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            files.append(line.replace("\\", "/"))
    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir()
    for rel in files:
        out = DST / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(port_lua((SRC / rel).read_text(encoding="utf-8")), encoding="utf-8", newline="\n")
    shutil.copytree(SRC / "Assets", DST / "Assets")
    for extra in ("LICENSE.txt", "THIRD_PARTY_LICENSES.txt", "README.txt", "DUNGEON_DATA_SOURCES.txt"):
        if (SRC / extra).exists():
            shutil.copy2(SRC / extra, DST / extra)
    (DST / "Gate.lua").write_text(GATE, encoding="utf-8", newline="\n")
    (DST / "SOURCE.txt").write_text(LICENSE_NOTE, encoding="utf-8")
    left = [str(p.relative_to(DST)) for p in DST.rglob("*.lua")
            if re.search(r"OneForAll(?!DB|CharDB)", re.sub(r'PREFIX\s*=\s*"OneForAll"|--[^\n]*', "", p.read_text(encoding="utf-8")))]
    lines = ["Kit\\Gate.lua"] + ["Kit\\" + r.replace("/", "\\") for r in files]
    toc = TOC.read_text(encoding="utf-8")
    block = "# Kit (tools/port_kit.py)\n" + "\n".join(lines) + "\n# /Kit\n"
    if "# Kit (tools/port_kit.py)" in toc:
        toc = re.sub(r"# Kit \(tools/port_kit.py\)\n.*?# /Kit\n", lambda m: block, toc, flags=re.S)
    else:
        toc = toc.rstrip("\n") + "\n" + block
    TOC.write_text(toc, encoding="utf-8", newline="\n")
    print(f"ported {len(files)} files")
    if left:
        print("still naming OneForAll in code:", left[:20])


main()
