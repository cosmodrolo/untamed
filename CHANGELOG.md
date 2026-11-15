# Changelog

## v2.19.1
- Fixed an error flood from the pet watch in fights (Range.lua:327): Forever hides whether your pet's target is your target during combat, and the check compared that hidden answer. Hidden answers are now skipped everywhere in the range meter and hunter display, and if the display ever errors again it reports once and rests 10 seconds instead of flooding.

## v2.19.0
- Library books (replaces the Library Books addon): a Library books tab with every book, where it is and whether it's in your bags or handed in, your count toward the 10, 20 and 25 book rewards, and an arrow to any of them (or to your librarian). Books you still need are on the world map, OpenMap and the minimap (purple). When you come within 300 yards of one you still need, you get a heads-up with the distance and direction. Picking one up and handing it in are noted automatically; right-click a book to mark one you handed in before. /ut books, /ut book (arrow to the nearest), /ut librarian.
- Treasure chests (replaces RareScanner's chest part): every spot a Battered, Solid or other random world chest or footlocker can appear, on the world map, OpenMap and the minimap (small orange icons; a chest is up at only some of them at a time). If the game marks a chest on your minimap, you get a heads-up. /ut chests off hides the spots, /ut chests minimap toggles them on the minimap, /ut scan lists what the game marks around you.
- Rares on the map: every rare in the zone you're looking at (red, tameable ones green), at the spot you last saw it if you have.
- OpenMap: Untamed's icons show on its stitched map, and OpenMap's menu gets switches for library books, chest spots, rares and wishlist.
- The recorder notes more for future data updates: beasts and rares you see (level, family, where), every spot you open a chest at, what the game marks on your minimap, and library books (where you found each, its item and quest IDs). /ut recorded shows the counts.

## v2.18.0
- The hunter display: everything you need in a fight in one block under your character, so you can turn ForeverAuras off for your hunter. Top to bottom: the range meter and pet watch; Serpent Sting timer, hawk tracker and Hunter's Mark (a red ! when your target has no Mark in a fight); your fight cooldowns (Summon Hawk, Aimed Shot, Multi-Shot, Rapid Fire, Bestial Wrath, Concussive Shot) and escapes (Feign Death, Frost Trap, Freezing Trap, Disengage), only the ones you know, with the seconds left on each; and reminders that pop in to the right only when something's missing (Well Fed food out of fights, Aspect of the Hawk in a fight, your pet). Cooldowns use the game's own timers, so they keep working with Forever's hidden combat numbers.
- One command moves it all: /ut hud move, then /ut hud lock. Also /ut hud scale 1.2, reset, off, on, and always (cooldowns outside fights too). /ut range move and /ut hawks move now move the whole display.

## v2.17.0
- Range meter above your character while you target an enemy: Melee (red), Dead zone (orange, too close for Auto Shot: step back or Disengage), In range (green) or Too far (grey), with the distance in yards as a band (for example 15-35 yd). WoW doesn't tell addons the exact distance to an enemy, so the band comes from the game's own range checks on every hunter spell you know, plus the 10, 11 and 28 yard checks outside combat. /ut range move, lock, reset, off, on; /ut range alerts shows it only when you're too close or too far.
- Pet watch under it in fights: your pet's health bar (works with Forever's hidden combat numbers) with "Mend Pet" when it's low, the exact distance to your pet, a warning with sound when it's more than 30 yards away (it ran off chasing something; /ut range leash 25 to change), and a note when it fights a different mob than your target. /ut range pet off turns it off.
- New macro Back (Rotation tab, "Make the macros"): calls your pet off a chase (passive and follow). Open now sets it back to defensive before sending it in.
- Feign Death says whether it dropped you out of combat.

## v2.16.0
- Feed Pet button (and the "your pet is not happy" note) now suggests your lowest level food that still makes your pet fully happy (food under 10 levels below your pet), so your best food and buff food stay in your bags. If you have nothing that close to your pet's level, it picks your highest level food as before.
- Beasts on your wishlist: type /ut want and a beast's name (for example /ut want broken tooth), or Alt-click a beast in the beast list. It shows at the top of the Wishlist tab (click for an arrow, right-click to remove), its spots are on your world map with a gold border, chat tells you when you enter its zone and when you reach the level to tame it, and the rare finder adds "On your wishlist!" when it spots it. /ut wishlist opens the tab.

## v2.15.1
- Hawk tracker keeps a hawk's time when you leave a fight and start another (it used to clear both slots at the end of every fight). Hawks still out after a fight stay on the tracker until their 18 seconds run out.
- Pet families from Blizzard's Nov 9 hotfix: Vulgara the Insatiable is now a Fox (was Wolf) and Shriekling Fledgling and Shriekling Matriarch are Birds of Prey (were Raptors).
- Data update: beast spawn points refreshed from QuestieDB's newest Forever recordings (46 beasts got more or corrected spots, for example the Gloomrise spiders, Highland Spider and Marsh and Elder Crocolisk), and the item, NPC and quest search rebuilt with QuestieDB's latest data and your newest vendor and drop recordings (about 1,500 more entries).
- 18 new beasts from beastmaster.io (now 641), most of them in the Riverglades: Ombassa (elite cat, Dash 2), the Wildplains cats (Cower 4), Plains Coyote and Plains Prowler (Bite 5), the Paletusk boars (Charge 4, Bite 5), Freshwater Crocolisk (Dismember 3), Sand and Shore Crawler (Pinch 3 and 4), Venomweb Spitter (Web 3), the Plains Buzzards (Claw 5) and Roving Tallstrider (Dust Cloud 3); plus Crazed Sandstrider in Desolace (Dust Cloud 3) and Riding Wolf.
- Higher ranks of the new family abilities now have teachers: Swipe 3 (Ironfur Bears), Pinch 3 (Silt Crawler), Dismember 2 and 3 (Saltwater and Young Sawtooth Crocolisk, Drywallow Vicejaw), Tendon Rip 2 and 3 (Steelsnap, Blisterpaw Hyena), Mine! 3 (Marsh Owl), Savage Rend 3 (Jungle Stalkers, Highland Fleshstalker, the Bloodfen raptors) and Web 3 (Darkmist and Darkfang spiders, Sorrow Spinner). King Bangalash teaches Prowl 2, not Dash 2.
- Rotation tab: Volley's note says moving stops it (Nov 11 hotfix).
- Checked game builds 70888 and 70938 in Blizzard's own tables: hunter talents unchanged; Arcane Shot and Summon Hawk cost 11% of base mana (Nov 10 hotfix); Volley no longer procs; pet Great Stamina now adds health directly (30 to 400) instead of stamina, about the same total.

## v2.15.0
- Hawk tracker: two slots under your character for your Summon Hawk hawks, each with its seconds left (red in the last 3), a sweep and a bar. Shown in a fight, empty slots dimmed so a missing hawk stands out; a third hawk replaces the oldest; cleared when the fight ends. /ut hawks move, lock, reset, off, on.

## v2.14.2
- Macro names are 4 letters or less so they read on the controller layout: Open, Hawk, Serp, Aim, Mult, Arc, Conc, Brst, Vol, Mend, Rev, Call, Feed, Rapt, Mong, Wing, Dis, FD, Frst, Frz, Imm, Expl, Scar, AspH, AspC, AspM, AspP, AspW, TSA. Macros made with the old "UT ..." names are renamed in place the next time you press Make the macros, so they stay on your bars.

## v2.14.1
- Macros for every ability you put on a bar (29, in groups: the fight, your pet, up close, traps and escapes, aspects and buffs). "/cast" with no rank always casts your best rank, so they upgrade themselves when you train a new one. The controller layout now uses them and covers L2 + D-pad too.

## v2.14.0
- New leveling build, Untamed's own pick for the strongest pet (31/20/0): Endurance Training 5, Focused Fire 2, Deadly Aspects 3, Unleashed Fury 5, Summon Hawk, Ferocity 5, Bestial Discipline 2, Spirit Bond 2, Frenzy 5, Bestial Wrath, then Lethal Attacks 5, Efficiency 5, Careful Aim 5, Improved Stings 3, Rapid Killing 2. Worked out from the Forever talent numbers and the Nov 10 hotfixes (pet health back to 115%, hawks +80% melee damage, Summon Hawk and Arcane Shot 11% of base mana).
- Rotation tab: what to press in a fight (pull, packs, keeping your pet up, between fights), spells you don't have yet dimmed with their level; macros UT Open (pet attack, Hunter's Mark, Auto Shot), UT Hawk (hawk, hawk, Arcane Shot), UT Mend (Mend Pet on your pet), UT Burst (Rapid Fire and Bestial Wrath), made per character with one click (a macro of yours with the same name is left alone); and where each goes on the controller.

## v2.13.0
- New leveling talent build: Wowhead's Beast Mastery leveling build for Forever (Docoda, updated Nov 4 2026), 31/16/4, one point per level from 10 to 60. Pathfinding and Improved Revive Pet count for the 3 Endurance Training points, so the old build's picks aren't flagged.
- The Talents tab now shows, for every step, the talent window's own text for those ranks and a line on why it's in the build (hover a step); the next one has its reason right under it.
- Off the build: a talent with more points than the build has at your level shows at the top of the Talents tab and once in chat (at login and when you spend a point).
- Each level from 10, chat says where your talent point goes.
- Dungeon loot card (from Paladin Path): entering a dungeon shows each boss and the hunter gear it drops for you, upgrades marked with their gain, gear you already own greyed with a check. Fades after 45 sec or at the first pull; /ut loot keeps it up, /ut loot move places it, /ut loot size 80, /ut loot reset, /ut loot stay, /ut loot off. Needs Dungeon Journal (ForeverDungeonJournal).
- Need alert: when an upgrade from your list comes up for a roll, a NEED banner, a sound and a chat line (/ut loot need turns it off).

## v2.12.1
- Hunter trainer prices are now the full prices. The list came from a trainer whose city you were Honored with, so every spell showed 10% less than most trainers charge (Beast Lore 64.8s instead of 72s). Untamed now ships full prices, and a cheaper price it sees at a trainer where you have a discount no longer lowers the list.
- Data update: the item, NPC and quest search rebuilt with QuestieDB's latest Forever fixes and your newest vendor and drop recordings. No beast spawns changed; beastmaster.io and the game build (1.60.1.70862) have nothing new.

## v2.12.0
- Controller fix (found with GamepadGuard): world map pins are rebuilt so they can't poison the face buttons. Before, Untamed added its pins through a map data provider that made pin frames inside the open map, so Blizzard's controller navigation rebuilt itself inside Untamed's code and closing the map with the controller blocked "SetPreferredGamepadInteractTarget" and killed the face buttons until /reload. Now the pins are plain images on one overlay made at login, with no hooks or data providers on the map.
- Hover a pin with the controller crosshair (or the mouse) to see Untamed's info box: beast, level, what it teaches and what your pet needs. Clicking a map pin to set the arrow is gone; set it from Untamed's window instead.
- With the controller UI on, Untamed never opens the map or changes its zone itself; it tells you which zone to open.
- Removed Untamed's page from Blizzard's Settings window (an addon page there poisons the face buttons when Settings closes). All settings are on Untamed's own Settings tab.
- Data update: beast spawn points refreshed from the latest QuestieDB update for Forever (47 beasts moved, none added or removed), and the item, NPC and quest search rebuilt with your latest vendor and drop recordings. Checked beastmaster.io (no new pet data) and the new game build 1.60.1.70862 (no hunter spell or pet family changes).

## v2.11.8
- Fixed the next-talent glow staying on screen as a small green square after closing the talent window. It now hides itself whenever its talent button isn't visible.

## v2.11.7
- Every dropdown sizes itself to its longest choice, and labels never wrap onto two lines. If a toolbar row runs out of room, the next control moves to a new row. Buttons grow to fit their text too.
- The Feed button grows to fit the food's name (out of combat, since it's a secure button).

## v2.11.6
- Gamepad taint fix: Untamed no longer writes its own fields onto Blizzard frames (the unit tooltip and the talent window), and the next-talent glow is no longer parented inside the talent window. One of these could get Untamed blamed for "SetPreferredGamepadInteractTarget()" when opening a controller radial menu.
- Unit tooltips skip beasts whose identity is hidden in combat on WoW Forever.

## v2.11.5
- Spells page uses a real WoW Forever hunter trainer list (recorded in game): 124 spells, every one with its Forever price and level. Forever reworked trainer prices (everything at a level costs the same, for example 67s 50c at 28 and 3g 78s at 60).
- Multi-Shot and Scorpid Sting are a single rank in Forever, and the trainer doesn't sell Lacerate, so those old ranks are gone from the list. Aspect of the Beast now has ranks 1 to 4.

## v2.11.4
- Visiting a hunter trainer saves what each spell rank costs and fills in the "?" costs on the Spells page (and the level, if Forever moved it).
- 56 more Forever beasts from beastmaster.io (now 623). Includes the Gloomrise spiders and Broodmother Valraxx in Mulgore, the Ruins of Lordaeron spiders (Spider and Deep Widow teach Web 1), the Excavation Site: Wetlands beasts (Dismember 2 and Savage Rend 2 teachers), Ghostfang, Matriarch Bristlefur, Slydris, Chakuyak, Carnage, and Classic beasts like Echeyakee, Ishamuhale, Arikara, Shy-Rotam, Deathmaw and Enraged Stanley.
- Beasts with only a known zone or dungeon (no exact spots yet) are now listed instead of skipped. Elite and rare tags carry over from beastmaster.io.

## v2.11.3
- Fixed training point costs read from Beast Training. The game shows what it costs to upgrade from your pet's current rank, not the full cost; Untamed now adds the current rank's cost back. Forever's training point costs match Classic, so the earlier "Natural Armor rank 2 costs 4" change is undone (it costs 5; your pet only needed 4 more).
- Fixed trainer entries with no readable rank being saved as rank 1 (Growl rank 1 showed level 20). Old scans are cleared once so they're read again correctly.

## v2.11.2
- Fixed a login warning ("Couldn't open embeds.xml"). Untamed no longer lists optional libraries it doesn't ship; the minimap button still uses LibDBIcon when another addon provides it.
- Find a Pet uses family damage, armor and health bonuses again, now read from WoW Forever's own client data (each family's passive spell). Forever kept the Classic values, added Bird of Prey (same as the old Owl) and Fox (same as Wolf). The old "based on abilities only" note is gone.
- Checked against Forever's client tables: which families learn each ability and the pet level for every rank (including Swipe, Pinch, Dismember, Web, Mine! and Thunderstomp rank 4) already matched Forever.
- Tank preset on the Builds tab includes Forever's new defensive abilities, Dust Cloud and Trickster's Dance.

## v2.11.1
- Talents page uses WoW Forever's real talent trees (checked against wowhead's Forever talent calculator), all three trees, including the new talents like Focused Fire, Summon Hawk, Careful Aim, Rapid Killing, Lone Wolf, Improved Stings, Predator's Edge, Expose Prey and Strider Kick.
- New Forever builds: Leveling (Beast Mastery, 31/20/0) from Kargoz's 1-60 leveling guide, and Raid (Marksmanship, 7/32/12) from Feor's Marksmanship guide (both on mobalytics.gg).
- Spells page fixes from the same check: Aimed Shot rank 1 (level 20) and Lacerate rank 1 (level 30) are trainer spells in Forever. Summon Hawk, Trueshot Aura, Counterattack and Sniper Shot ranks show "needs talent" until you have the talent. Wyvern Sting and Strider Kick are no longer listed as trainer spells.

## v2.11.0
- Spells page works on WoW Forever. It uses Forever's own trainer data, including the new spells: Summon Hawk (ranks 1 to 4 at 25, 36, 48 and 60), Aspect of the Beast ranks 2 to 4, Strider Kick, and the extra ranks of Trueshot Aura, Counterattack, Lacerate and Sniper Shot. Costs for Forever-only spells show "?" until we know them.
- Higher ranks of talent spells (Aimed Shot, Trueshot Aura, Lacerate and others) show "needs talent" and are not counted as "train now" unless you have the talent.
- Gear page, gear upgrade alerts, the gear line on item tooltips, and dungeon and reputation gear lists work on WoW Forever. Scores use Forever's own item stats (2,646 items Forever changed or added), and Classic values for items Forever left alone.
- Classic Era support is removed. Untamed is now a WoW Forever addon only. If your Forever AddOns\Untamed folder still has Untamed.toc, Untamed_Vanilla.toc or Data\*_Era.lua files, you can delete them.

## v2.10.0
- All Beasts: new attack speed filter (fast, faster than normal, normal, slow). Forever beasts now have real attack speeds (field-confirmed from beastmaster.io, 2.0 s for the rest), shown on each row in green (faster) or orange (slower), and sorting by attack speed works on Forever.
- Find a Pet prefers faster beasts for damage on Forever too, now that the speeds are known.
- Talents on Forever: Untamed now finds your talent tree the same way Forever's own talent window does. If the page is still empty, it shows why, and /ut talents prints what it can see.
- Search includes your latest recordings (72 vendor and 46 drop links).

## v2.9.3
- Fixed: recording loot in combat errored ("attempt to compare a secret string value") when Forever hid your target's ID. The recorder now checks before comparing.
- Gamepad: with Forever's gamepad UI on, Untamed no longer opens the world map itself (that could pass taint into the gamepad bars and block "SetPreferredGamepadInteractTarget"). It sets the pins, tells you to open your map, and jumps to the zone when you do. Mouse and keyboard work as before.
- The rare scanner skips hidden (secret) IDs and levels instead of risking an error in combat.
- Forever data: Prairie Wolf Alpha teaches only Bite 2 (beastmaster.io). Search includes your latest recordings.

## v2.9.2 (Forever)
- Uses QuestieDB 1.0.11's live Forever traces (data gathered from players since launch). Search now knows 1,241 more Forever NPCs and 107 objects with their real spots, 785 new Forever items, and about 4,600 more "drops from" links.
- 28 tameable beasts now use live spawn spots instead of database guesses, including Gray Fox, Maddened Rotclaw, Vuldren Alpha and the Zephras Isle beasts.
- Your own recordings are built in: 58 vendor and 27 drop links found while playing (for example Nordun Steadysight's ammo in Goldshire).
- From now on Untamed is developed for WoW Forever only.

## v2.9.1
- The arrow now hops between spawn spots. When you reach a spot and the beast isn't your target, under your mouse or on a nameplate, it shows a short countdown, then points to the next closest spot you haven't checked (right away if you walk off). Once it sees the beast it stays put and says "Found it". When every spot is checked it starts over from the nearest.
- Skip ahead any time: Shift-right-click the arrow, type /ut spot, or bind a key (Key Bindings > AddOns > Arrow: next spawn spot). The arrow's tooltip shows how many spots are left.
- New setting: "Arrow moves on to the next spawn spot" (on by default).

## v2.9.0
- Roomier, easier to follow layout on every page: taller rows with larger text and icons, bigger section headings with a gold rule and space above them, wider columns, more space between toolbar controls, and a divider under the toolbar.
- Page titles are larger, with the description on its own line under the title.
- Wider sidebar with larger buttons and group headings. It now fits itself to the window height, so Settings never runs off the bottom on a short window.
- The window opens larger by default (up to 1000 x 800, never bigger than your screen). Sizes saved by older versions are reset once so you get the new size.
- Forever data from beastmaster.io: Strider Clutchmother (Darkshore, rare) teaches Bite 3 and Dust Cloud 1; Highlands Ursera teaches Claw 1, not Claw 2.

## v2.8.7
- Fixed: world map pins could still trigger a blocked SetPassThroughButtons call (seen after a Beast Training scan). Untamed's pins now skip that call, like TomTom and HandyNotes do.
- Forever: Natural Armor rank 2 costs 4 training points (read from the Beast Training window), not 5.

## v2.8.6
- Fixed: the rare pop-up couldn't hide itself in combat ("UntamedRareToast:Hide() blocked"), because its Target button was anchored to it. The button now sits at the pop-up's screen position without being attached.
- Fixed: refreshing Untamed's world map pins during combat was blocked on Forever. Pin updates now wait until combat ends.

## v2.8.5
- Fixed: a rare spotted during combat (like Mother Fang) caused an "action blocked" error from the rare pop-up's Target button. The pop-up is now built at login, and its Target button is kept apart from it so the pop-up can show in combat. The button appears as soon as combat ends.

## v2.8.4
- Fixed on Forever: the Auto Shot bar threw errors every shot in combat. Forever hides your ranged attack speed and movement speed during combat, so Untamed now remembers your speed from out of combat, measures the time between shots, and checks movement with a function Forever doesn't hide.
- The Hunter's Mark boss check and aspect reminder no longer error when Forever hides your target's level or ID in combat.

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
