# Changelog

## v2.8.3
- Talents now work on WoW Forever. Untamed reads Forever's talent tree, shows your progress through the leveling or raid build with Forever's talent names (Deadly Aspects, Lethal Attacks), counts your unspent points, and the next talent glows green in Forever's talent window.
- Home's "Spend talent points" reminder works on Forever too.

## v2.8.2
- Forever pet data now includes beastmaster.io's field-confirmed "comes with" abilities: 61 more beasts that teach (first known sources for Sonic Blast, Tendon Rip, Pinch, Dismember, Mine!, Web 2, Swipe 2 and Dust Cloud 2), 13 corrections (Vuldren Alpha teaches Bite 2, Gray Fox teaches Trickster's Dance, Mystmane teaches Swipe), and three Zephras Isle beasts with empty spellbooks removed.
- Forever beasts that Questie doesn't place yet get map spots from beastmaster.io, so the arrow and map pins work for them (29 beasts, including Gray Fox, Maddened Rotclaw and the Zephras Isle bears).
- Checked against Blizzard's Forever client tables (build 1.60.1.70790): every pet ability rank, its level, and each family's diet match.

## v2.8.1
- Checked against WoW Forever build 1.60.1 (70790), today's launch update: every game function and event Untamed uses exists, or Untamed already falls back safely.
- Forever: reputation names and standings now come from C_Reputation.GetFactionDataByID (Forever doesn't have GetFactionInfoByID), so the Reputation page and vendor reputation tags show real names and your standing.

## v2.8.0
- New Home page, shown when you open Untamed (you can turn that off): a live "Right now" checklist (open Beast Training, feed your pet, spells to train and their cost, talent points to spend, ranks ready to teach, the next beast to tame, easy gear upgrades, low ammo), each a click away from the right page, plus a short guide to how Untamed is organized and handy tricks.
- Fixed: pet food on Supplies found nothing, because most food items had no food type in the item data. Food types now come from the game database.
- Fixed: choosing your own pet in the Stable showed "Viewing: Rake" and "Back to my pet". It's simply "My pet" now.
- Fixed: the Reputation page listed the other faction's battleground rewards too.
- Hunter Quests: quests given by several trainers (like The Hunter's Path) show once, from the nearest trainer, and disappear once you've done any version or moved past it.
- Supplies: quivers and pouches with no known source are no longer listed.
- Shorter text in the right-hand column on Gear and Wishlist, so it isn't cut off (full details stay in the tooltip).
- The Beast Training tip only shows on the My Pet pages.
- Proper singular and plural ("1 item", "1 spell", "1 point to spend").

## v2.7.1
- Layout pass: every page now has the same kind of toolbar along the top (dropdowns, checkboxes, buttons), and every control updates when the page does.
- Abilities: show every rank, only ranks still to learn, only beasts you can tame now, or only ranks ready to teach your pet; hide ranks above your pet's level; collapse or expand all.
- "Browser" is now "All Beasts", with dropdowns for family, the ability a beast teaches (for example every beast that teaches Bite 6), where it is (this zone, or your continent nearest first) and sort order.
- Rares: a "Tameable only" filter.
- Search: tidier two-row toolbar and a Reset button.
- Dungeons: filter loot by slot and show only upgrades.
- Spells: a dropdown for What's next or Every level, and an arrow to the nearest hunter trainer.
- Reputation: pick a faction.
- Hunter Quests: show not done, available now, or all.
- Wishlist: sort by newest, nearest source or level.
- The Taming group now flows Find a Pet, All Beasts, Planner, Rares. Clearer descriptions under every page title.

## v2.7.0
- Beast abilities now come from Blizzard's own Classic Era client data (CreatureSpellData), linked to beasts through cmangos. The old data from shagu's pet list is gone. Every beast it listed matched Blizzard's data exactly.
- Rare finder: alerts for every rare, not just tameable ones, with a pop-up that has a Target button and an Arrow button, an optional skull marker, and map vignettes where the game shows them. New Rares page lists every rare in your zone, near your level, or ones you've seen, with when you saw them.
- Restock: a button beside the vendor window tops up ammo and pet food to amounts you choose (or automatically). It buys the best ammo for your weapon and the best food your pet eats from that vendor.
- Wishlist: Alt-click any item in Untamed to add it. Its sources show on the world map, its tooltip says it's on your wishlist, and you get a note when you enter a zone where you can get it.
- Dungeons page: each dungeon's level range and entrance, the best hunter loot for you with who drops it, the creatures that drop gear, and tameable beasts inside.
- Reputation page: every faction with hunter rewards, your standing and progress, what each rank unlocks, and how to earn it.
- Auction House: wishlist items glow gold and gear upgrades glow green with the score gain in Browse results.
- The sidebar has four groups now: My Pet, Taming, Gear and Hunter.

## v2.6.2
- Reputation: vendor items show the exact reputation they need (for example "Revered, Silverwing Sentinels"), in green when you already have it and orange when you don't, with your current standing in the tooltip. When a vendor accepts either faction's reputation, your side's is shown.
- Gear: new "Dungeons only" and "Reputation rewards" filters.
- Search: new "Reputation vendor" source filter.

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
