# Untamed

A hunter pet guide for **World of Warcraft Classic Era** and **WoW Forever**.

Untamed looks at the pet you have out (or a family you pick), shows every ability rank it can still learn, tells you which wild beasts teach each rank, and gets you there: map and minimap pins, an on-screen arrow, the nearest stable master and flight master, and a trip planner that orders the stops for you.

## Features

- **Abilities tab.** Every rank your pet can still learn, which ranks you already know (teach them at Beast Training), and the beasts that teach the rest, with level, zone and travel advice.
- **Trip planner.** Picks the best rank your pet's level allows for each ability, the closest tameable beast for each (one beast can cover several), and orders the stops by distance. Start the route and the arrow moves to the next stop when you learn the ability.
- **Navigation arrow.** Points to the nearest spawn of any beast, stable master or flight master. No other addon needed (TomTom is supported with shift-click).
- **Stable and flight masters.** The closest ones for your faction to every beast, on the map and in tooltips.
- **Map, minimap and tooltips.** Pins for every beast your pet still needs, tooltip lines on beasts in the world, and an alert when you target one.
- **Pet browser.** Every tameable beast, searchable by name or zone, filterable by family, rares and what you can tame now, sortable by level, name and (Classic Era) attack speed.
- **Pet care.** Happiness, loyalty, experience, training points, diet, and the food in your bags your pet will eat, with a one-click Feed button that pops up when your pet is unhappy.
- **Stable manager.** Remembers every pet you own and what each can learn from ranks you already know.
- **Training point builds.** Presets and shareable build strings.
- **Rare beast scanner, ammo and trainer reminders, Mend Pet and Revive Pet alerts, and a pet leveling helper.**
- **Tame recorder.** When you tame a beast, Untamed records the abilities it really had and adds them to its data.

Open it with `/untamed` or the minimap button. `/untamed help` lists all commands.

## WoW Forever

Forever reworked hunter pets (new families, new family abilities, Owl renamed Bird of Prey). Shared abilities such as Bite, Claw, Dash, Dive and Cower are well covered. How the new family abilities (Swipe, Web, Sonic Blast and others) are learned is not confirmed publicly yet; the addon marks them as unconfirmed instead of guessing, and the tame recorder fills in real data as you play.

## Data sources and credits

- Spawn locations, stable masters and flight masters: [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0).
- Item pet food types, ammo vendors, hunter and pet trainers: [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0).
- Classic Era tameable beasts and the abilities they teach: originally extracted from the VMaNGOS database by [shagu/vanilla-hunter-pets](https://github.com/shagu/vanilla-hunter-pets).
- WoW Forever beast abilities: compiled from public Forever pet guides (see `tools/forever_pets.json` for the list of sources) and corrected by in-game observation.
- World of Warcraft and all game data are trademarks and copyrights of Blizzard Entertainment.

`tools/` holds the scripts that regenerate `Data/Era.lua`, `Data/Forever.lua` and `Foods.lua`. `tests/` runs the addon offline against a mocked WoW API (`python tests/run.py`, needs `pip install lupa`).

## License

GPL-3.0. See `LICENSE`.
