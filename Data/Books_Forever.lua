-- Library books in WoW Forever: where each one is, compiled by hand from public guides
-- (wowforever.be, wowforever.wclbox.com, coachcarry.com, warcraft.wiki.gg), November 2026.
-- Books are picked up from the world (one copy each), then handed in one at a time to your
-- faction's librarian; milestone rewards at 10, 20 and 25 books. Coordinates are the guides';
-- the recorder notes where you actually pick each one up, so wrong spots get fixed.
local _, ns = ...

-- lvl: the level the area is safe from (the guides' bands); fac: only that faction can loot it
-- spots: { uiMapID, x, y, note }   special: needs something extra (a key) or not confirmed yet
ns.Books = {
  { name = "Archmage Theocritus's Research Journal", lvl = 5, fac = "A", spots = { { 1429, 65.4, 70.1, "Tower of Azora, top floor, on the table" } } },
  { name = "Bewitchments and Glamours", lvl = 10, spots = { { 1436, 45.4, 70.5, "Moonbrook, first house coming from the east" } } },
  { name = "Rumi of Gnomeregan: The Collected Works", lvl = 10, spots = {
      { 1436, 52.7, 53.8, "Sentinel Hill inn, behind the innkeeper" }, { 1432, 35.6, 48.9, "Thelsamar inn, upstairs on the table" } } },
  { name = "Crimes Against Anatomy", lvl = 15, spots = { { 1431, 16.7, 28.5, "Raven Hill crypt, west entrance, down the stairs to the bench" } } },
  { name = "Runes of the Sorcerer-Kings", lvl = 15, spots = { { 1432, 77.5, 14.1, "Mo'grosh ogre cave, left path" } } },
  { name = "Goaz Scrolls", lvl = 20, spots = { { 1437, 33.6, 47.9, "Whelgar's Excavation Site, lower level, keep right" } } },
  { name = "Archmage Antonidas: The Unabridged Autobiography", lvl = 1, fac = "A", spots = { { 1455, 75.7, 10.5, "Hall of Explorers, big table" } } },
  { name = "The Apothecary's Metaphysical Primer", lvl = 5, fac = "H", spots = { { 1420, 59.4, 52.3, "Brill, shelf in the alchemy shop" } } },
  { name = "The Dalaran Digest, Vol. 23", lvl = 12, spots = { { 1421, 63.5, 63.1, "Ambermill main hall, shelf in front of you" } } },
  { name = "Arcanic Systems Manual", lvl = 15, spots = { { 1413, 56.3, 8.8, "Sludge Fen oil rig, control room at the top" } } },
  { name = "Baxtan: On Destructive Magics", lvl = 12, spots = { { 1413, 62.7, 36.3, "Ratchet, engineering building near Gazlowe" } } },
  { name = "Secrets of the Dreamers", lvl = 15, spots = { { 1413, 46.0, 36.5, "Wailing Caverns outer cave (not the dungeon)" } } },
  { name = "Nar'thalas Almanac, Vol. 74", lvl = 15, spots = { { 1439, 59.6, 22.2, "Ruins of Mathystra, stairs above the water" } } },
  { name = "Fury of the Land", lvl = 20, spots = { { 1442, 74.4, 85.7, "Malaka'jin, barrel in the tent by the big totem" } } },
  { name = "The Lessons of Ta'zo", lvl = 1, fac = "H", spots = { { 1454, 38.6, 78.4, "Darkbriar Lodge, large tablet" } } },
  { name = "Basilisks: Should Petrification be Feared?", lvl = 33, spots = { { 1434, 41.3, 50.9, "Table outside the basilisk cave (path from 37.1, 48.8)" } } },
  { name = "Geomancy: The Stone-Cold Truth", lvl = 30, spots = { { 1441, 34.4, 40.0, "Darkcloud Pinnacle, main hut over the rope bridges" } } },
  { name = "Defensive Magics 101", lvl = 35, spots = { { 1416, 48.4, 57.5, "Ogre tower at the crossroads, a level 40 ogre guards it" } } },
  { name = "RwlRwlRwlRwl!", lvl = 36, spots = { { 1445, 57.1, 20.8, "Murloc camp, by the furnace" } } },
  { name = "A Web of Lies: Debunking Myths and Legends", lvl = 33, spots = { { 1417, 73.6, 65.2, "Witherbark Village, east hut by the mountain" } } },
  { name = "Demons and You", lvl = 35, spots = { { 1443, 55.1, 26.2, "Thunder Axe Fortress, big building in the inner ring" } } },
  { name = "Mummies: A Guide to the Unsavory Undead", lvl = 37, spots = { { 1418, 56.7, 39.7, "Crypt above the camp with two dwarves" } } },
  { name = "Necromancy 101", lvl = 55, spots = { { 1422, 69.2, 72.3, "Scholomance, upstairs on a table (dungeon)" } } },
  { name = "Undead Potatoes", lvl = 50, spots = { { 1422, 38.3, 54.6, "Felstone Field, upstairs in the house by the barn" } } },
  { name = "A Study of the Light", lvl = 52, spots = { { 1423, 71.8, 48.2, "Inside Light's Hope Chapel" } } },
  { name = "The Knight and the Lady", lvl = 55, spots = { { 1423, 47.3, 42.3, "Burnt house by Blackwood Lake (bats nearby)" } } },
  { name = "Scourge: Undead Menace or Misunderstood?", lvl = 57, spots = { { 1423, 26.6, 14.5, "Zone side of the bridge in front of Stratholme" } } },
  { name = "Sanguine Sorcery", lvl = 45, spots = { { 1435, 70.2, 51.9, "Temple of Atal'Hakkar, top level at the back" } } },
  { name = "Venomous Journeys", lvl = 43, spots = { { 1425, 35.8, 72.5, "Shadra'Alor, inside the half-circle wall at the first pyramid" } } },
  { name = "Northern Kalimdor - A Comprehensive Guide", lvl = 48, spots = { { 1448, 65.1, 3.2, "Timbermaw Hold tunnel, halfway, left of the bridge" } } },
  { name = "Ka-Boom!", lvl = 50, spots = { { 1452, 60.4, 37.4, "Everlook" } } },
  { name = "Stonewrought Design", lvl = 50, spots = { { 1428, 31.1, 30.1, "Blackrock Mountain, tomb by the summoning stone (Franclorn Forgewright)" } } },
  { name = "Magma or Lava?", lvl = 50, spots = { { 1428, 31.1, 30.1, "Blackrock Mountain, past Lothos Riftwaker" } } },
  { name = "A Mind of Metal", lvl = 45, spots = { { 1427, 38.1, 49.8, "Tent with a Dark Iron dwarf beside it" } } },
  { name = "Everyday Etiquette", lvl = 47, spots = { { 1447, 20.4, 62.3, "North of the flight path, before the ruins" } } },
  { name = "Legends of the Tidesages", lvl = 45, spots = { { 1446, 72.6, 47.5, "Lost Rigger Cove, bookshelf in the middle house" } } },
  { name = "Ataeric: On Arcane Curiosities", lvl = 12, special = "Not every character can loot it", spots = { { 1421, 43.4, 41.2, "The Sepulcher" } } },
  { name = "A Luddite's Guide to Caring for Your Demonic Pet", lvl = 38, special = "Needs a Rusted Cage Key (rare drop from Muckdweller murlocs)",
    spots = { { 1435, 61.5, 22.5, "Fallow Sanctuary, locked cage" } } },
  { name = "Conjurer's Codex", lvl = 50, special = "Spot not confirmed", spots = { { 1419, 55.4, 32.3, "Blasted Lands" } } },
  { name = "The Liminal and the Arcane", lvl = 44, special = "May not be in the game yet", spots = { { 1444, 50.6, 15.7, "The Twin Colossals" } } },
}

ns.Librarians = {
  A = { name = "Garion Wendell", map = 1453, x = 49.0, y = 86.3, where = "Stormwind, Mage Quarter" },
  H = { name = "Owen Thadd", map = 1458, x = 74.0, y = 32.5, where = "Undercity, Magic Quarter" },
}

-- milestone quests: books handed in, quest ID (when known)
ns.BookMilestones = { { 10, 78150, "Friend of the Library" }, { 20, 79536, "Greater Friend of the Library" }, { 25, 82208, "Greater Friend of the Library" } }
