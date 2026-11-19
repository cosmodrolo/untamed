# Untamed

A hunter companion for **WoW Forever**, built to be used with a controller.

Untamed started as a pet ability finder and grew into the one window a hunter opens for everything: which beast to tame and where it is, what your pets can still learn, which gear to chase, which talent to take next, and where the chests and library books are.

Open it with `/ut` (or `/untamed`) or the minimap button. `/ut help` lists the commands worth knowing, `/ut help all` lists every one.

## What's in the window

Six sections along the top, plus Settings. With a controller: D-pad moves, Cross selects, Circle goes back, Square is the second action, L1 and R1 change sections.

| Section | Pages | What it's for |
| --- | --- | --- |
| **Today** | Today | What's worth doing right now: your pet's state, abilities in reach, upgrades nearby. |
| **Bestiary** | Bestiary, Find a Pet, Rares, Planner | Every tameable beast with its 3D model, what it teaches, attack speed and where it lives. Looks shows every skin a family comes in. Find a Pet suggests beasts by role. Planner orders a taming trip by distance. |
| **My Pets** | Abilities, Builds, Pet Care, Stable | Every ability rank your pet can still learn and which beasts teach it, training point builds, feeding and happiness, and every pet you own. |
| **Hunter** | Spells, Talents, Rotation, Hunter Quests | What to train, a suggested talent build beside the talent trees (each build names where it comes from; the glow and level-up tips can be switched off), a rotation with ready-made macros, and the class quests. |
| **Gear** | Gear, Wishlist, Dungeons, Reputation, Supplies | Your next upgrades by slot with a rank and how to get each one, your weakest slot, dungeon loot, reputation rewards, and ammo and pet food. |
| **World** | Search, Library books | Find any item, NPC or beast and where to get it. The library books you still need. |

## Outside the window

- **Map and minimap.** Marks for the beasts your pet needs, treasure chest spots, library books and wishlist sources. Works on Blizzard's world map and on OpenMap's Gamepad UI mode.
- **Arrow.** Points to the nearest spawn of whatever you picked: a beast, a chest, a book, a vendor.
- **Range meter.** Under your character: melee, too close to shoot, in range or too far, with the distance in yards. A red Hawk icon shows while you fight with Aspect of the Cheetah or Pack on.
- **Bag marks.** A green arrow on gear that beats what you wear, a lock on soulbound items, a coin on items worth selling.
- **Quest reward advice.** When a quest offers a choice of rewards, a small box under the quest window says which to take.
- **Item tooltips.** How much better an item is than what you wear, and its rank for your level.
- **Alerts.** Rare beasts, a chest or book nearby, an upgrade dropping in a dungeon (with a loot card), Growl on in a group, a boss without Hunter's Mark, whether Feign Death worked.
- **Macros.** One click makes the hunter macros from the Rotation page. `Care` is one button for your pet: revive, call, mend, or feed, whichever it needs.
- **Restock.** A button on the vendor window fills your quiver and tops up pet food.
- **Recorder.** Notes the vendors, loot, beasts and chests you come across, and uses them right away to fill gaps on your own map. It stays on your computer: nothing is sent anywhere, and it keeps only its newest entries so the saved file stays small. It can be turned off in Settings.
- **Self-check.** `/ut doctor` tests each part against the game and says what isn't working.

## Something wrong or missing?

Tell us in the CurseForge comments or open an issue at https://github.com/cosmodrolo/untamed/issues. A screenshot and the zone help a lot.

## Built for the gamepad UI

WoW Forever's gamepad UI breaks ("face buttons stop working") when an addon creates or changes anything inside one of Blizzard's own windows. Untamed is built around that:

- Everything Untamed draws is its own frame on the screen, made at login. Marks on the map, the bags and the quest window are drawn on Untamed's own layer by reading where Blizzard's buttons are, never by attaching to them.
- Nothing is read or shown during a fight that the game hides from addons (buffs, exact pet distance), so nothing errors in combat.
- Options live in Untamed's own Settings page, not in Blizzard's Settings panel.

The one exception is the Restock button on the vendor window, which has to sit there to be reachable with a controller.

## Layout of this repository

```
Untamed_Forever.toc   load order
Bindings.xml          key bindings
Core/      Init, Core (saved settings, slash commands), Locale, Geo (distances), Alerts, Recorder, Doctor
Data/      generated data: beasts, names, items and sources, hunter gear and spells, foods, chests, books, looks
Map/       MapPins (world map and OpenMap), Minimap, Arrow, OpenMap (its menu)
Pets/      Abilities, Browser (the Bestiary), Stable, Recommend, Rares, Planner, Builds, PetCare, Leveling
Hunter/    Character (spells, talents, gear, quests), GearLive, Rotation, Combat, HUD, Range, Restock, Bags, QuestAdvice, LootCard
World/     Search (items and where they come from), Wishlist, Books, Chests, Dungeons, Reputation
UI/        UI (the window, theme and widgets), Pad (controller navigation), Home (Today), Tabs (Pet Care and Settings)
Locales/   translations (written by the release packager)
Media/     icons
tests/     offline tests against a mocked WoW API
tools/     scripts that build Data/ (see tools/README.md)
```

`CHANGELOG.md` has an entry for every version.

## Tests

```
pip install lupa
python tests/run.py
```

Seven scenarios load the addon exactly as the game does (from the TOC) against a mocked WoW API and exercise each page and feature. They run on every push.

## Data sources and credits

- Spawn locations, items, quests, vendors, flight and stable masters, localized names: [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0).
- Tameable beasts, pet food types, trainers, chest spots, drop tables and which display each beast uses: [cmangos classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).
- Which abilities each beast teaches: Blizzard's client table CreatureSpellData (build 1.15.9.70576), exported with [wago.tools](https://wago.tools).
- WoW Forever item stats, trainer spells and creature displays: WoW Forever client tables (build 1.60.1), exported with [wago.tools](https://wago.tools).
- WoW Forever beast abilities: compiled from public Forever pet guides, with field-confirmed abilities and spawn points from [beastmaster.io](https://beastmaster.io/forever) (sources listed in `tools/forever_pets.json`).
- Family damage, armor and health modifiers: [Icy Veins Classic hunter pet guide](https://www.icy-veins.com/wow-classic/hunter-dps-pets-guide).
- Talent builds: the leveling build is Untamed's own pick from wowhead.com's Forever talent numbers and Blizzard's hotfix notes; the raid build follows Feor's Marksmanship guide on mobalytics.gg. They are suggestions: Settings, Gear, spells and talents turns off the talent glow and the level-up tip.
- Library book locations: kept by hand from public guides.
- No code or data is taken from other addons.
- World of Warcraft and all game data are trademarks and copyrights of Blizzard Entertainment.

## License

GPL-3.0. See `LICENSE`.
