# Changelog

## v2.42.0
Gear scores now count what your pet gets from you.
- On WoW Forever a hunter's pet shares the hunter's stats (per Wowhead's Beast Mastery guide): all of your crit chance, 30% of your armor, 10% of your attack power, and 2 health per point of stamina. The score now reflects that: crit 20 to 28 per 1%, agility 2.4 to 2.6, attack power 1 to 1.05, stamina 0.5 to 0.6, and armor counts for the first time at 0.02 per point.
- Armor is a tiebreaker on purpose. A full move from leather to mail is worth about 12 points in total, enough to pick mail when the stats are close and never enough to give up real agility for it.
- Every item in the gear list was rescored (about 4,700), so upgrade numbers and ranks shift a little everywhere. Items new in Forever that are scored in game use the same weights, with armor read from the item.

## v2.41.3
- Blizzard look: the "Viewing" picker at the top right is a dark box like the other dropdowns, not a red button.

## v2.41.2
- Data update from QuestieDB 1.1.2 (Nov 16): 62 beasts got more or corrected spawn points, and Search was rebuilt with its newest Forever items, NPCs, objects and quests plus your latest vendor and drop recordings (about 40 more entries, many corrected). Ghostmaw in the Riverglades is in Search now.

## v2.41.1
- Gear: "Weakest slot" said "Nothing worn" when the item you wear isn't in Untamed's item data (items new in Forever, such as Replica Crescent Necklace). It now names the item from the game.
- Blizzard look: dropdowns are dark boxes again instead of red buttons, the dark red box behind each button is gone, and checkboxes use the game's own box and tick.

## v2.41.0
Six looks for the window, and the Blizzard look goes further.
- Settings, Basics, "Look of the window" now offers six: Savage Land (green and amber, still the default), Blizzard, Midnight (navy and ice blue), Ember (charcoal and orange), Slate (grey and hunter green) and Twilight (purple and lilac). Type /reload after switching.
- Blizzard look: buttons are the game's red buttons (the one to press glows gold), the section tabs are grey plates with the current one in gold, and panels wear the game's inner border.
- The four new color looks keep Untamed's flat shapes and only change the colors.
- Chests: a chest you open where no spot was known becomes a spot on your map and minimap from then on (it is read from the recorder's notes, so chests you already found count). This covers the new Forever zones, which the chest data has nothing for.
- Chests: the first Riverglades spot ships with the addon (Solid Chest at 18.6, 70.7).

## v2.40.1
- Talents: in a large window the trees stayed small in a corner of an empty panel. The icons now grow with the window (up to about one and a half times bigger) and the picture sits lower when there is height to spare.
- Talents: three lines in the order list were cut off. The heading now shows the build's short name and its split, the note under the next talent is gone (it's in the tooltip), and the closing note is short with the full text in its tooltip.

## v2.40.0
A second look for the window: Blizzard.
- Settings, Basics, "Look of the window": Savage Land (the green one, still the default) or Blizzard. Type /reload after switching.
- The Blizzard look gives the window the game's own metal frame, stone backing and close button, with dark panels, bronze lines and the game's gold in place of the green and amber.
- This is the frame only, a first step: buttons, tabs, lists, dropdowns and scroll bars keep Untamed's shapes in the new colors.
- Only the art is borrowed. The window is still Untamed's own frame, not one of the game's panels, so the controller is handled exactly as before.

## v2.39.1
- Talents: the names in the order list were cut to two letters ("1. En..."). The level now sits at the right of each row and the names have the room.
- Talents: the tree picture is bigger. The list takes less width and the trees are packed closer.
- Talents: the arrow from Ferocity to Frenzy was missing (seen in the game's talent window). It is drawn, and builds are checked against it.

## v2.39.0
The Talents page shows the talent trees.
- Next to the order list there is now a picture of all three trees, laid out like the game's talent window: every talent's icon in its own row and column, with the arrows between talents that need another one first.
- Each talent in your build carries a number: its place in the order. The list on the left is numbered the same way, so "7." in the list is the icon marked 7.
- Colors: gold is where your next point goes, green is done, pale is still to come, orange has more points than the build, and talents the build skips are dimmed. Each icon shows your points in it ("2/5"), and each tree's heading shows the points you've spent there.
- Point at an icon (or move to it with the D-pad) for what the talent does, which step and levels the build takes it at, and what it needs first.
- The picture sizes itself to the window.

## v2.38.4
A sweep of everywhere gear is scored, after the suffix fix.
- Need alert on loot rolls: it scored the rolled item by its number alone, so a suffixed green ("of the Monkey") that was an upgrade got no alert. It reads the rolled item's own tooltip now.
- Suffixes that give attack power ("of Power", "of Marksmanship") are read too: their bonus is an "Equip: +14 Attack Power" line, which the first pass didn't count. Attack power that only works in a druid form or against one kind of creature is left out.
- /ut worn lists every item you wear with its score and rank, so a wrong score is easy to spot.
- Checked and already right: item tooltips, bag arrows, what you wear, ranks, the weakest slot, quest reward advice. Unchanged on purpose: the Gear, Dungeons and Reputation lists, which show items with fixed stats. Greens whose stats come only from a random suffix aren't listed there, since which suffix drops is luck.

## v2.38.3
- Gear scores missed random suffixes after all: Archer's Shoulderpads of the Beast (+5 Agility, +8 Stamina, all from its suffix) scored 0 and read as "-2 vs what you wear, rank 80 of 80". The game's stats call doesn't report a suffix on WoW Forever, which the first version (2.32.0) relied on. Untamed now also reads the "+N Stat" lines of the item's own tooltip, which is what you see, and counts whichever finds more. This covers item tooltips, bag arrows, what you wear, ranks, the weakest slot and quest reward advice.

## v2.38.2
Housekeeping. Nothing changes in game.
- The code is sorted into folders: Core, Map, Pets, Hunter, World and UI, with the generated data in Data (Foods.lua moved there too). The load order is the same.
- README rewritten for what Untamed is today: the six sections, what runs outside the window, how it stays safe on the gamepad UI, and where everything lives in the repository.
- tools/README rewritten: which script builds which data file, with the commands.
- Removed a stray compiled Python file and added a .gitignore. The addon's description in the game's AddOns list is up to date.

## v2.38.1
The hunter display is now just the range meter and one warning.
- Gone: the Serpent Sting and Hunter's Mark timers, the hawk tracker (and /ut hawks), the pet watch (pet health, distance, the "ran off" and "fighting a different mob" warnings, /ut range pet and leash), and the Food and Pet reminders. The aspect icon no longer shows your current aspect.
- Kept: the range meter, and the Hawk warning. A red Hawk icon shows under the range meter while you're in a fight with Aspect of the Cheetah (or Pack) still on, and goes when you switch. The sound and on-screen line at the start of such a fight stay too. The "No aspect is active" chat line is gone.
- Cleaned up: Hawks.lua is deleted, their switches are off the Settings page, their saved settings are removed at login, and the display no longer runs a timer five times a second: it only wakes when you cast something or a fight starts or ends.
- Not touched: the Feign Death check, the Growl warning and the Hunter's Mark reminder on bosses, which are alerts rather than parts of the display.

## v2.38.0
Two features removed, now that the game's own cooldown manager does the job.
- Gone: the cooldown rows on the hunter display (Summon Hawk, Aimed Shot, Multi-Shot, Rapid Fire, Bestial Wrath, Concussive Shot, and the Feign Death, trap and Disengage row), with their "keep on screen outside fights" switch and /ut hud always.
- Gone: the Auto Shot timer bar and its switch.
- Cleaned up after them: their code, events, saved settings (removed from your saved data at login), the self-check line for cooldown timers, and the help text.
- Staying on the hunter display: the range meter and pet watch, the Serpent Sting and Hunter's Mark timers, the hawk tracker, and the Food, aspect and Pet reminders.

## v2.37.6
- Quest reward advice: the box sat beside the quest window, right where the item tooltips open, so they covered it. It now sits under the quest window, below the controller's button prompts (beside the window only when there's no room underneath).

## v2.37.5
- Talents: the leveling build could not reach Bestial Wrath. Bestial Wrath needs Intimidation, and Intimidation needs Bestial Swiftness (the arrows in the talent window), and the build skipped both. The build now takes Bestial Swiftness and Intimidation on the way and leaves out Spirit Bond, so Bestial Wrath is the 31st point at level 40.
- Every build is now checked against the talent window's rules (points needed per tier, and the arrows) whenever Untamed is tested, so a build that can't be followed can't ship again.

## v2.37.4
- Fixed an "Untamed tried to call a protected function" error when a rare was spotted with "Put a skull on rares" on. WoW Forever doesn't let addons place raid markers, so the option is removed. The rare alert itself (sound, banner, chat line) is unchanged.

## v2.37.3
- Weakest slot: a slot is no longer called weakest when Untamed can't score what you wear there (an item new in Forever whose stats aren't in its data). Before, such an item counted as zero and came out last.
- Gear: the "For you" line was empty on the item the weakest slot points at. It shows the slot and the gain now.

## v2.37.2
- Quest reward advice: the box could stay on screen after the quest window was gone. It now also closes when a reward is taken, when a quest is accepted or handed in, when the quest window is no longer up, and after two minutes whatever happens.
- When an addon takes a quest reward for you, Untamed says which one in chat ("RXPGuides picked quest reward 2 of 3 for you."). /ut advice lists the last things the box saw: quests offered, handed in, who took each reward, and what closed the box.

## v2.37.1
- Chests: Untamed now notices when you open one. The spot you opened comes off your map, your minimap and the "chest spot nearby" alert for 30 minutes, until a chest could be back, and a chat line says so. It's remembered per character, so it survives a /reload.
- (Books already worked this way: a book in your bags or handed in is off the map and out of the alerts.)

## v2.37.0
- Gear: the list now opens with your weakest slot: the slot where what you wear ranks lowest among everything you could wear at your level, what you wear there and its rank, and the item to go and get for it (one you can buy or quest for when there is one). Rings count by the weaker of the two; trinkets are left out, since their effects don't show up in a score.

## v2.36.1
- Restock: "Ammo to carry" has a new choice, Fill my quiver, and it is the default. Untamed reads the quiver or ammo pouch you wear and buys exactly what still fits in it (a 14 slot quiver holds 2,800), in whole stacks so nothing spills into your bags. Slots holding a different kind of ammo are left alone. With no quiver worn it tops up to 1,000 as before.
- If your amount was still the old default of 1,000 it moves to Fill my quiver once; an amount you picked yourself stays.

## v2.36.0
Two steps toward not needing a second gear addon.
- Rank: every piece of hunter gear now has a place among everything you can wear in its slot at your level. Item tooltips get a line ("rank 3 of 41 for shoulders"), and an item's page in Gear says it in full under Good to know, with the name of the best one.
- Quest reward advice: when a quest lets you pick a reward, a small box beside the quest window lists the choices and marks the one to take: the biggest upgrade over what you wear (with its rank), or, when nothing is an upgrade, the one that sells for most. It shows when you read the quest and again when you hand it in. Switch: Settings, Gear, spells and talents.
- How the box stays safe on a controller: it is Untamed's own frame with no buttons, made at login. Nothing is drawn on, attached to or written to the quest window; Untamed only reads where that window is, to stand beside it.

## v2.35.0
- Gear and Search: items dropped by more than ten creatures were all called "World drop", even when nearly all of those creatures live in one dungeon. 330 such items now say which dungeon instead (Flintrock Shoulders: the ordinary mobs of Scarlet Monastery, not a boss), count as a dungeon source in the "Dungeons only" and "No dungeons" filters, and "Go get it" points at the dungeon. True world drops are unchanged.

## v2.34.6
- Looks: the size correction from 2.34.3 made the models less even, not more (the model view already allows for a display's size), so it's gone: every look is drawn from the same distance again.
- Looks: a wide window now uses its width (the same tile size in fewer rows), and at the smallest window the note under the tiles is one line instead of being cut in half.

## v2.34.5
- Looks: at a small window the tiles ran out of the bottom and right of the window. The gallery now works out the largest tile that fits the space it has (trying every number of columns), shrinks the tiles as far as needed, lays them out again when you resize the window, and can no longer draw outside the window.

## v2.34.4
- The window can no longer be made bigger than the screen (which put the resize corner out of reach), and a window saved too big is brought back inside the screen when you log in.
- /ut window reset puts the window back to its starting size in the middle of the screen. Settings, Basics has a button for it too.

## v2.34.3
- Looks: every look now fills its tile alike. The game draws some skins bigger than others (a look worn only by large beasts), so the camera stands back by the same amount, using each display's size from Blizzard's own tables. The models are also turned a little less to the side, so they sit nearer the middle.
- Looks: beasts the game gives more than one skin are filed under each of them. Checked against Blizzard's display table, only one of the six candidates really has different skins (Riding Wolf, which adds three wolf looks); for the other five the extra displays are the same skin at another size.

## v2.34.2
- Looks: the tiles are bigger. They take the largest size (up to 120) that still fits the family's looks in the space the window has, and the models stand a little further back so they sit inside the tile.

## v2.34.1
- Looks: the models in the gallery tiles are drawn closer, so they fill the tile instead of sitting small in the middle.

## v2.34.0
Looks: every skin a family comes in.
- A beast's page in the Bestiary has a new Looks button. It swaps the lower half of the page for a gallery: one small 3D model per look in that beast's family (16 for cats, 11 for wolves, 13 for spiders...), each with how many beasts wear it and their level range.
- The look of the beast you're on is lit. Pick another look and the page jumps to a beast with it: the highest one you can tame right now out in the world. Press the lit look again to step through the other beasts that wear it.
- Under the gallery: the names and levels of every beast with the current look. Details brings the normal page back.
- Good to know now says when other beasts share a beast's exact look.
- Where the looks come from: which display each beast uses (cmangos classic-db) and Blizzard's own display table for WoW Forever, which says which displays share a model and colors. 564 beasts are sorted; the 77 beasts new in Forever aren't in that data yet and the gallery says so.

## v2.33.0
One button for your pet: the Care macro.
- Make it on the Hunter section's Rotation page (the macro list, under "Your pet": click "Care"), then put it on your bars from /macro like the others.
- What a press does: your pet is dead, Revive Pet. Not out, Call Pet. In a fight, Mend Pet. Outside a fight, it feeds your pet when it isn't happy (your lowest food that still gives the most happiness), and mends it otherwise.
- A hurt pet (under 70% health) is mended before it's fed, and after a feed the button goes back to Mend Pet for 20 seconds so a second press doesn't waste food.
- If your pet died and its body is gone, the first press tries Call Pet, the game says it's dead, and the button switches to Revive Pet for the next press.
- The game doesn't let addons change a button during a fight, so the feed part is only brought up to date outside fights. In a fight the button is always Revive, Call or Mend, which the game picks by itself.

## v2.32.4
- Aspect icon, the real cause: in a fight the game answers "no such buff" for every buff, and Untamed took that as "no aspect", wiping the Hawk it had just seen you cast. It no longer reads buffs during a fight, and outside fights it looks first for the exact aspect it saw you cast.

## v2.32.3
- Aspect icon: switching to Aspect of the Hawk in the middle of a fight left the red "Hawk!" warning up. Untamed now recognises aspects by name as well as by spell number (Forever's ranks don't all carry the old numbers). /ut doctor has an Aspect line showing what it saw.

## v2.32.2
- Hunter display: more room between the Food, aspect and Pet icons, so their names no longer run together.

## v2.32.1
- The aspect icon on the hunter display now always shows the aspect you have on (Hawk, Cheetah, Monkey...) with its name. Start a fight without Aspect of the Hawk and it turns into a red "Hawk!" warning. With no aspect at all it shows a dim "No aspect". It hides while mounted. In a fight the game hides your buffs from addons, so there it goes by the last aspect it saw you cast. Switch: Settings, Under your character, "Show the aspect I have on".
- Bag coins only mark things worth selling: unbound gear, bags, gems, trade goods and recipes. Ammo, food, drink, potions, reagents, quest items and keys no longer get one.

## v2.32.0
Marks on the items in your bags, built so they can't break the controller.
- A green arrow on gear that beats what you wear, a small lock on soulbound items, and a small coin on items that aren't bound yet (so they can be traded or put on the Auction House). Grey junk and quest items get no coin.
- Each has its own switch in Settings, Gear, spells and talents (or /ut bags arrows, /ut bags locks, /ut bags coins).
- How it stays safe: the marks are pictures on Untamed's own sheet over the screen. Nothing is created inside or attached to Blizzard's bags; Untamed only reads where each slot is. The marks hide in a fight.
- Gear scores now count random suffixes ("of the Monkey", "of the Eagle") on what you wear and what's in your bags. Before, two items with the same base name scored the same whatever their suffix, which made upgrade numbers wrong for most green drops.

## v2.31.1
- Settings: the line under the page title now says how the page works instead of the old "Alerts, pins and data sharing".

## v2.31.0
Cleanup, and a Settings page a new player can read. Untamed is for WoW Forever only.
- Settings: sections down the left (Basics, Under your character, Beasts and rares, In a fight, Map and minimap, Treasure and books, Pet care and supplies, Gear, spells and talents, Your data), the section's switches on the right, each with a line saying what it does in plain words. Basics holds the few things most people change. Switches that used to exist only as chat commands are here now: the hunter display, range meter, pet watch, hawk timers, Feign Death check, the controller, chest spots and alerts, library book alerts and map marks, the loot card and Need alert. "Move the display" and "Put it back" are buttons.
- Removed, because they can't work on WoW Forever: the Auction House helper (it was written for the old auction window) and the resist alerts (Forever gives addons no combat log). Their switches are gone from Settings.
- Removed what was left from Classic Era: the old talent-window glow, the old Beast Training (craft window) reader, the Era family list, and the Era-or-Forever checks around them. The /psf command (from when the addon was called PetSkillFinder) is gone; /ut and /untamed stay.
- /ut help is eight lines now: the commands worth knowing. /ut help all lists every one (they all still work).

## v2.30.1
- Checkboxes show their mark again (since 2.30.0 a ticked box looked empty; the settings themselves were never changed).

## v2.30.0
- The last stock pieces get the Savage Land look: scroll bars are a thin dark track with an amber thumb (drag it, or use the mouse wheel; it hides when everything fits), checkboxes are a dark box with an amber square (the label is clickable too), and search boxes are flat.
- Hunter Quests: a quest that isn't part of a chain no longer shows its name twice. Spells: the page no longer repeats the cost under the description.

## v2.29.1
- Spells: a spell's page shows the game's own description of it (what the rank does), and a row keeps its status ("needs talent") instead of showing the level.
- Search: the checkboxes wrap inside the left column (one sat on top of the page), and the hints are on the empty page instead of cut-off rows.
- Library books: the heading and long book titles are no longer squeezed by notes on the right (the distance is on the book's page).
- Pages built from a picture (items, spells, abilities, quests, books) use a smaller box, so the facts sit next to it instead of under a big empty square; the "Click for ..." hints are gone from pages that have a button for it.

## v2.29.0
More pages in the journal style.
- Hunter > Spells: the spells on the left (train now, later, optional), the spell's page on the right with its cost, the trainer level and why it's marked the way it is, and an Arrow to trainer button.
- Hunter > Hunter Quests: the quest chains on the left, the quest's page on the right (levels, who starts it and where, who to turn it in to), and an Arrow to it button.
- World > Library books: the books on the left, the book's page on the right (where it is, how far, what's special about it), and an Arrow to it button. Square (or right-click) still marks a book handed in.
- World > Search: results on the left; picking an item opens the same item page as Gear and Wishlist.
- Talents, Rotation, Builds, the Planner and Settings stay as they are: they're things you work through or tick, not things you look up.

## v2.28.1
- Dungeons, Reputation, Supplies: headings keep their whole name ("Razorfen Downs", "Quivers" were cut short), and the page's "For you" line says what it is ("Drops from ...", "Needs Honored ...").

## v2.28.0
The rest of the Gear section in the journal style: Dungeons, Reputation and Supplies.
- Each keeps its list and filters on the left; picking an item opens its page on the right (icon, how to get it, every source with distance, Go get it / Wishlist / Item details). What used to stand at the end of the row (the boss that drops it, the standing it needs, the vendor that sells it) is the page's "For you" line.
- Dungeons: the dungeon's own row still gives the arrow to its entrance, and the beasts inside are still listed.
- On a controller: Cross on an item does what clicking it did (the arrow to it), Square puts it on the wishlist.

## v2.27.1
- Gear: each row names its slot again, the "For you" line no longer runs off the page, and item and ability pictures are shown at their real size (they went soft when blown up).

## v2.27.0
Gear and Wishlist in the journal style.
- Gear: your next upgrades on the left, grouped Now / Soon / Later with how much better each is; the item's page on the right: its icon, how to get it, which slot it's for and how much it beats what you wear, every source with its distance, and three buttons: Go get it, Wishlist, Item details (hover it, or move the controller onto it, for the real item tooltip).
- Wishlist: your wished beasts and items on the left, the same item page on the right. A wished beast shows its model and the basics; click it again for its full page in the Bestiary.
- On a controller: Cross on an item starts the arrow to it, Square puts it on (or takes it off) the wishlist.

## v2.26.1
- The look gets some depth: panels, buttons and the window shade from top to bottom instead of sitting flat, list headings are an amber band that fades out, model boxes have a lit floor and amber corner brackets, page titles get an amber stroke, and the title bar carries Untamed's mark.
- /ut mem says how much memory Untamed is using (also a line in /ut doctor).

## v2.26.0
A look of its own: "Savage Land".
- The window drops Blizzard's stock frame, red buttons and gold bands for deep jungle green panels with thin moss lines and amber for what's selected or the thing to press. Its own title bar and close button; flat buttons (the main one on each page is amber); flat menus; green model boxes, pages and cards.
- The look lives in one place (the colors at the top of UI.lua), so it can be tuned or swapped without touching the pages.
- Not restyled yet: checkboxes, scroll bars, the Feed button and tooltips (those are the game's own pieces).

## v2.25.0
The rest of My Pets.
- Abilities is a journal: what the pet you're viewing can learn on the left (with "teach 5" in green when you already know a rank it can use, "tame 6" when the next rank needs a beast), the ability's page on the right: the rank it has, what's next, which families can learn it, every rank ahead with its pet level and training point cost and whether to teach it or which beasts to tame, and three buttons: Hunt the next rank, Teachers on map, In the Bestiary.
- Pet Care is one page: your pet's model, happiness and what it does to damage, experience and how fast it's coming, training points, diet, the Feed button, the food in your bags it will eat (the one fed first marked), and where to level it.
- Builds is unchanged: it's a planner you tick ranks in, and a list suits that.

## v2.24.1
- The window can't be made narrower than the journal pages need (about 1160 wide, less only on a screen that small), so nothing runs off the page. A window saved smaller than that opens at the new smallest size.

## v2.24.0
The rest of the Bestiary section, in the journal style.
- Find a Pet: pick what you want the pet for (Tank, Damage, Leveling, PvP, Utility); every family is ranked on the left, and the family's page on the right shows a model, its damage, armor and health, why it suits that role, what it can learn, and the best ones to tame now. Buttons: Plan for this family, See them all (the Bestiary on that family, fastest first), Starting build.
- Rares: the rares on the left (tameable ones in green, "seen" on those you've met), the rare's page on the right: model, level, where it is and how far, when and where you last saw it, and what it is as a pet if you can tame it. Buttons: Go to it, Show on map, Its beast page.
- Today: your pet at a glance under the cards (its model, happiness, free training points, attack speed, what you can teach it now and what to tame next for it). The text in each card sits in the middle now.

## v2.23.0
- Today is a handful of cards instead of a long list: each card is something worth doing now (train spells, spend talent points, teach or feed your pet, the next beast to tame, upgrades within reach, low ammo, library books to hand in), and a click or Cross goes to the page for it. With nothing to do there's one green card saying so. The tips moved behind a "Good to know" button (hover or move onto it to read them; click to print them in chat).

## v2.22.1
- Stable page: a pet's attack speed is also read from its Faster Attack or Slower Attack passive, so renamed pets show it too (Untamed learns which speed each tier means from pets whose beast it knows). "Knows" lists its abilities only, not the pet bar's commands.
- /ut tamedfrom <beast's name> tells Untamed which beast the pet that's out was tamed from (for pets you renamed before Untamed kept track).

## v2.22.0
My Pets > Stable is a journal too.
- Your pets on the left, the pet's page on the right: its model (the real one for the pet that's out; for the others the beast it was tamed from), which beast it was tamed from and that beast's attack speed, its family's damage, armor and health, what you can teach it right now, what to tame next for it (the next rank of each ability you don't know, with the nearest beast that teaches it), a faster beast of its family if one is within reach, and what it knows.
- Three buttons: Plan for this pet (the Abilities, Builds and Planner pages switch to it), Beasts for it (opens the Bestiary on its family, on beasts that teach something new), and Forget.
- Untamed now notes which beast you tame a pet from. Pets you already have are matched by name if they kept the beast's name; renamed ones show a beast of their family as a stand-in until you tame something new.

## v2.21.2
- Bestiary: a beast's model shows the first time you open its page (the game is still fetching it then; Untamed now asks again until it's there).

## v2.21.1
- Bestiary page: the family icon no longer sits behind the model (it only stands in when the game has no model to show), the model stands back a little so long beasts fit, the switches show their whole label, the sort dropdown shares a row with the family one, and the mouse tooltip that covered the page is gone.

## v2.21.0
The Bestiary is a journal now (the second step of the overhaul). It replaces All Beasts.
- A list of beasts on the left, the beast's page on the right: its 3D model (it turns slowly), family, level, attack speed, where it's found and the nearest spot, what it teaches and whether each rank is new to you (and whether the pet you're viewing can use it), the family's damage, armor and health, its look, when you last saw it if it's a rare, and three buttons: Hunt it, Show on map, Wishlist.
- The search box reads plain words: "fast cat", "bite 6", "rare badlands", "furious howl wolves", "new" (teaches a rank you don't know), "30-40" or a single level. The Family and Teaches dropdowns and four switches (This zone, Tame now, Rare, New) do the same without typing, for the controller.
- On a controller, moving through the list turns the pages; D-pad right goes to the page's buttons and left comes back to the same beast. Cross on a beast starts the hunt, Square shows it on the map. With a mouse: click a beast to open its page, click it again for the arrow, right-click for the map.
- In the list: rares in orange, a star for wishlist beasts, "new" in green when it teaches something you don't know, the level in red when it's too high to tame.

## v2.20.1
- L1 and R1 reach Settings too: it's the stop after World.
- The Home page describes the new sections.

## v2.20.0
The first step of the overhaul: a tidier window, and the controller works in it.
- Six sections along the top instead of one long list of 21 pages: Today, Bestiary, My Pets, Hunter, Gear, World. The list on the left shows only the pages of the section you're in, and each section remembers the page you were on. Settings is the gear at the right end. The pages themselves are unchanged for now.
- The controller works in the window: D-pad moves a gold frame to the nearest button, row, dropdown or checkbox in that direction (lists scroll as you move through them, and the thing under the frame shows its tooltip), Cross selects, Square is the second action (what right-click does), Circle goes back (closes a menu, then to the list of pages, then closes the window), L1 and R1 change sections. The buttons are taken only while the window is open and you're not in a fight, and only once you've let go of every button; they go back to the game the moment a fight starts or the window closes. /ut pad off leaves the controller alone. /ut doctor says whether the buttons came through.

## v2.19.22
- The pet buff icons (for Frenzy) are taken out. Forever doesn't let addons read buffs during a fight in any form: asking errors with "Auras cannot be accessed", and the game's own notices about new buffs arrive as hidden tables that can't be opened. Frenzy still shows on Blizzard's target frame when you target your pet.

## v2.19.21
- Pet buff notices: the list of new buffs arrives hidden and can't be walked, so its entries are asked for one by one. /ut doctor says more about what came through.

## v2.19.20
- Pet buff icons in fights, second try. /ut doctor showed that Forever refuses addons every question about buffs during a fight. What still arrives is the game's notice that something was put on your pet, so in fights the icons are now fed from those notices: the newest buff or debuff on Zabu shows first (Frenzy when it procs), and goes when the game says it ended. An experiment: the game may hide parts of those notices too, and /ut doctor's "Pet buff notices" line says what came through.

## v2.19.19
- Pet buff icons: each step of drawing an icon now stands on its own, so if the game refuses one in a fight (the picture or the timer) the icon still shows, with a claw picture when the real one is refused. /ut doctor says what each step answered the last time the icons were drawn.

## v2.19.18
- The hunter display sits a bit lower so it doesn't cover your character when you zoom in (if you moved it yourself it stays where you put it; /ut hud reset goes to the new spot).
- /ut doctor shows how many points you have in Frenzy and lists your pet's buffs.

## v2.19.17
- Untamed's map icons show on OpenMap's controller view (its Gamepad UI mode). That view is OpenMap's own map drawn over Blizzard's, which hides everything Untamed drew on Blizzard's map. OpenMap puts other addons' HereBeDragons map icons on its view, so Untamed now hands it its icons in that shape: chests, books, rares, wishlist, the beast you're hunting and beasts your pet can learn from. They appear once you zoom in to zone level (the beast you're hunting shows from further out), for the zone the map is on and the zone you're in. Put the controller's cursor on an icon for its info box. The switches in OpenMap's menu turn each group off or on.

## v2.19.16
- Your pet's buffs now show as small icons with timers next to its health bar under your character, the one running out soonest first. Frenzy appears there the moment it starts and counts down. In a fight Forever hides which buff is which from addons, so Untamed shows them all (up to four) instead of picking out Frenzy; when the game does give the name, Frenzy gets a gold edge. /ut range buffs turns the icons off or on.

## v2.19.15
- Range meter: still said "Melee 5 yd" on a far target. On Forever both the spell check and the action bar say "yes" for Raptor Strike at any distance. Now a shot with a minimum range (Auto Shot) that says "in range" wins over a melee "yes", so a target you can shoot shows "In range".
- /ut doctor prints the raw range answers (Auto Shot, Raptor Strike, Wing Clip, your melee bar slot) and no longer marks the pet distance red when the game hides it in a fight.

## v2.19.14
- Full check of the addon against Forever's current game functions. Three quiet problems fixed:
  - "Do you know this spell" now goes through one shared check that asks the newer game functions first. The Spells page, the Rotation page and the cooldown icons under your character each asked on their own, and on a client without the older functions could hide spells you know.
  - Wishlist "you have it" used an older item count function that may be gone on Forever; it now uses the same count as the rest of Untamed.
  - Feed Pet picks food by how much it helps: food within 5 levels of your pet gives full happiness, within 10 half, within 14 a quarter. It picks the lowest level food inside the best group you carry, so cheap food is used first without wasting a feeding.
- New: /ut doctor. A self-check that prints what the game answers for each part of Untamed (pet spellbook, range checks, cooldowns, chest spots, books, OpenMap, the Open macro's pet bar slot). Green is fine, red is a part to report.

## v2.19.13
- Range meter: no more "Melee 5 yd" stuck on a far target. For melee abilities Forever's spell range check answers "yes" at any distance, so melee is now read from your action bar instead (the button with Raptor Strike, Wing Clip or Mongoose Bite, or a macro that shows one, like Rapt). If none of them is on your bars, point-blank shows "Too close" instead of guessing.
- Abilities page with "Hide ranks above my pet's level" checked: an ability your pet has at the best rank for its level said "nothing usable yet"; it now says "pet has Rank 5, best for its level".

## v2.19.12
- Untamed reads your pet's own abilities again. On Forever the number of spells on the pet's spellbook page comes from a newer game function; Untamed asked the old one, got nothing, and so every ability said "pet does not know it" and the plan started from rank 1. The pet's ranks are now read from its spellbook (with the rank text asked for again if it hasn't arrived yet), so the Abilities page, the plan, zone alerts and the training point math all start from what your pet really has.

## v2.19.11
- No more "go learn Bite 1" when you already know Bite 5: ranks below one you know and your pet can use now are left off the plan, the map, the zone alerts and the tame hints. Lower ranks still show for a pet that's too low for the rank you know.

## v2.19.10
- Eye macro chains now: "!" keeps a second press from ending the view (Alejandro's find), and [@cursor] places it without a click, so it works from a controller button.

## v2.19.9
- Range meter: Melee works now. Melee spells report no range of their own, and the meter skipped them, so point-blank showed "Dead zone". If the game ever won't say whether melee reaches, it shows "Too close" instead of guessing.
- Eye macro: casts Eagle Eye where the middle of your screen points ([@cursor]) instead of waiting for a click, so pressing it again while looking jumps further instead of dropping back to you.

## v2.19.8
- New macro Eye (Eagle Eye) in the Rotation tab under Scouting: press it again while you're looking to jump further from where your view is now.

## v2.19.7
- Chest alerts that work on Forever. The game doesn't mark chests on the minimap (the recorder saw none), so the old alert never fired. Now: "Chest spot nearby" when you come within 60 yards of a spot a chest can appear at, with the distance and direction (once per spot every 20 minutes, not in fights or on flights; /ut chests near turns it off, /ut chests radius 80 changes the distance), and "Chest right here" with a sound when a chest becomes your interact target (the thing Square would use), which is certain.

## v2.19.6
- Open really sets your pet back to Defensive now. Forever has no working slash command for it (/petdefensive does nothing with its Passive, Defensive and Assist modes, and there is no /petdefensiveassist), so the macro clicks the Defensive button of the pet bar instead; Untamed reads which slot that is from your pet bar and keeps the macro's text right.

## v2.19.5
- Open didn't put your pet back to defensive after Back: Forever's pet modes are Passive, Defensive (assist) and Assist, and the plain /petdefensive does nothing there. Open now uses /petdefensiveassist (the Defensive button on Forever's pet flyout). The macro updates itself after login.

## v2.19.4
- Macros Untamed made update themselves: when a macro's text changes in an update (like Open, which now sets your pet back to defensive), it's rewritten where it is a few seconds after login, so you don't have to press "Make the macros" again. Macros you wrote yourself are left alone.

## v2.19.3
- The loot card said "nothing for you" on every boss in the City of Dalaran (and would in the other new Forever dungeons): the shipped gear list was built from an older game build and didn't know those items. Gear the list doesn't know is now scored in game from the item itself (same weights), so the loot card, the Need alert, tooltips and the score of what you're wearing all cover new items, including ones added in future patches.

## v2.19.2
- Library books you handed in before are counted now: a few seconds after login Untamed goes through the quests the game says you've completed and marks the books among them. "Find handed-in books" on the Library books tab (or /ut books scan) runs it again and says what it found.

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
