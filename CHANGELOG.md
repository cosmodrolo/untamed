# Changelog

## v2.6.1
- Every vendor is now kept for each item. Before, only the first 8 were, which could leave out your faction's vendors entirely (for example Jin'sora's quivers in Orgrimmar for Horde).
- Supplies shows the quiver or ammo pouch you have on, and only lists better ones, with the price and nearest vendor.
- New recorder: Untamed notes vendors (what they sell, where, and the price) and loot (what dropped from which creature or chest) as you play, and uses it right away to fill gaps. Type /ut recorded to see the totals. You can turn it off in Settings > Share data.
- tools/build_search.py can merge players' recordings into the shipped data.

## v2.6.0
- Spells: "What's next" shows only what you can train now plus your next two trainer visits; "Every level" shows the whole list. Optional spells you skipped are listed on their own.
- Search: new filters for type (items, NPCs, tameable beasts, vendors), item kind (armor slot, ranged, melee, ammo, quivers, pet food, bags, potions, recipes), source (vendor, quest, open-world drop, dungeon, chest, world drop, inside another item, crafted, fishing, Auction House), quality, Usable by me and Near me. Filters work with an empty search box.
- Search results show where the nearest source is right in the row, including chests and nodes.
- New item sources: found inside other items (clams, lockboxes), crafted (with the profession when known) and fishing zones. Chests that spawn in many spots say so.
- Quest rewards only count when the quest is available to your race and faction. Items only sold by quartermasters are marked as needing reputation.
- Gear: an upgrade path with Now, Soon (next 5 levels) and Later sections, the best upgrade per slot in each, and how to get it (price and vendor, quest, dungeon, Auction House). Filter by slot, by how you get it (buy or quest only, no dungeons) and Near me.
- Gear alerts: a chat note when you level up into a new easy upgrade, and when you enter a zone where a vendor sells one.

## v2.5.0
- Auto Shot timer: a bar that shows the reload (move freely) and the aim window (stand still). Shift-drag to move it.
- Growl warning when Growl is on autocast in a group, and a note when it's off while solo.
- Combat reminders: Aspect of the Cheetah or Pack on in combat, no aspect at all, and no Hunter's Mark on a boss.
- Resist alerts for Feign Death, traps, Scatter Shot, Scare Beast, Wyvern Sting and Tranquilizing Shot.
- New Search page: any item, NPC or beast, with every place to get an item (vendors for your faction, drops, quests, containers) and an arrow to the nearest. Also /ut s <text>.
- New Supplies page: the best ammo for your weapon and who sells it, quivers or ammo pouches near your level, and food your pet eats with the nearest vendor.
- Settings are grouped into sections and scroll.
- New Spells page: every trainer spell by level with its cost, what you can train now and the gold you need, with spells many hunters skip while leveling marked optional.
- New Talents page: a Beast Mastery leveling build (Icy Veins) and a Marksmanship raid build, your progress through it, and a green glow on the next talent in the game's talent window.
- New Gear page: the best items for your level in every slot by a simple hunter score, where to get them, and an "upgrade for you" line on item tooltips.
- New Hunter Quests page: every hunter-only quest for your race, grouped into chains, with done, in your log and available status and arrows to the quest givers.
- The Spells, Talents and Gear pages use Classic Era data; on Forever they say so until Forever's data is available.

## v2.4.0
- Redesigned window: tabs moved to a sidebar grouped into My Pet and Taming, with Settings at the bottom.
- New header with your pet's portrait, happiness, experience and training point bars, and one "Viewing" menu to switch between your pet, any stabled pet, or a family.
- Each page has a title and short description, sunken Blizzard panels, section headings, real expand and collapse buttons, a level column and striped rows.
- Tips and the current map focus moved to a status bar at the bottom.
- The window can be resized from the bottom-right corner and remembers its size and position.
- Layout and event names are no longer marked for translation.

## v2.3.1
- New smooth navigation arrow, drawn for Untamed, that turns from green to yellow to red the further you are facing away from the target.
- Tab buttons now size themselves to fit the window, so Settings no longer runs off the edge.

## v2.3.0
- New Find a Pet tab: pick Tank, Damage, Leveling, PvP or Utility and get the best families for it (from Classic family stat bonuses and abilities), the best beasts of each family you can tame now (fastest attack, highest level, closest), and a one-click starting build.
- Beast, stable master, flight master, vendor and trainer names now show in your game language (9 languages, from QuestieDB).
- Ability and family names show in your game language, and family names are matched through the game itself so every language works.
- Translation framework: all window text can be translated on CurseForge.

## v2.2.0
- Trip planner now starts at the best stable master when you have a pet out and ends by bringing you back for it. The route moves on by itself when you stable your pet and when you learn each ability. New Next Stop button and key binding.
- Stable manager: remembers every pet you own and shows which ranks you already know that each can use. Click a pet to plan for it.
- Training point builds: Damage, Tank and PvP presets, rank-by-rank editing, and shareable build strings.
- Rare beast scanner: alerts when a rare tameable is near you (nameplates, target, mouseover). /untamed rare points the arrow at it.
- Hunter essentials: low ammo warning with the nearest ammo vendor, new spell ranks reminder with the nearest hunter trainer, Mend Pet and Revive Pet alerts. /untamed ammo, trainer, pettrainer, stable.
- Pet leveling helper: zones where your pet earns experience, plus XP per hour and time to level.
- Export and import of tame recordings to share data corrections.
- Localization groundwork: ability, family and diet names from German, French and Spanish clients are mapped to the addon's data. Zone names show in your language.
- Settings page under Options > AddOns, key bindings, and data broker support for minimap button collectors.

## v2.1.0
- Renamed from PetSkillFinder to Untamed. Slash commands: /untamed or /ut (/psf still works).

- Pet food is now accurate for every item: food types come from the game database (Classic Era) or the game itself (Forever).
- One download works in both Classic Era and WoW Forever.

## v2.0.0
- Trip planner, navigation arrow, stable and flight master advice, pet browser, pet care tab, minimap pins, tooltip and target alerts, tame recorder.
- WoW Forever support.

## v1.0.0
- First version: abilities your pet can learn, which beasts teach them, world map pins, zone alerts.
