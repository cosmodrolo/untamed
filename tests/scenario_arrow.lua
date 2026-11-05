-- Arrow spawn hopping: reach a spot, the beast isn't there, the arrow moves to the next spot.
local ns = NS
local function check(cond, label) print((cond and "ok   " or "FAIL ") .. label); if not cond then error("check failed: " .. label) end end
FIRE("ADDON_LOADED", "Untamed")
FIRE("PLAYER_LOGIN")
-- a beast with several spots spread across one zone
local pick, pickMap
for id, b in pairs(ns.Beasts) do
  for m, pts in pairs(b[7]) do
    if #pts >= 8 and math.abs(pts[1] - pts[#pts - 1]) + math.abs(pts[2] - pts[#pts]) > 20 then pick, pickMap = id, m break end
  end
  if pick then break end
end
check(pick ~= nil, "found a beast with spread-out spots")
WorldMapFrame:SetMapID(pickMap)
TARGET_ID = 1   -- target something else
ns.Navigate(pick)
local t = ns.Arrow_Target()
check(t and t.npcId == pick, "arrow on the beast")
local firstX, firstY = t.x, t.y
-- walk to the spot
PLAYERPOS = { x = t.x / 100, y = t.y / 100 }
local now = 1000
GetTime = function() return now end
_G.UntamedArrow:Show(); TICK(1)
check(t.arrivedAt ~= nil, "arrived and looking around")
-- wait: not found, so it moves on
now = now + 9; TICK(1)
check(t.x ~= firstX or t.y ~= firstY, "moved to the next spot")
check(#t.checked >= 1, "first spot checked")
-- skip by hand
local secondX, secondY = t.x, t.y
ns.Arrow_NextSpot()
check(t.x ~= secondX or t.y ~= secondY, "manual skip moves on")
-- at a spot where the beast is: it stops
PLAYERPOS = { x = t.x / 100, y = t.y / 100 }
TARGET_ID = pick
TICK(1)
now = now + 30; TICK(1)
check(t.found, "found it, stays put")
print("DONE")
