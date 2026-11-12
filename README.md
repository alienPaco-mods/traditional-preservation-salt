# Traditional Preservation (Salt) — Build 42 prototype (v0.1.14)

**Status: experimental.** Back up your save before enabling.

## Install

Copy this folder to `~/Zomboid/mods/TraditionalPreservationSalt`. The game does not follow a symlinked mod folder reliably, so use a real copy. If you use Long Term Preservation Extended, copy `~/MODS/TraditionalPreservationSaltLTP` there too.

Traditional Preservation (Salt) requires **TP Core** (`TraditionalPreservationCore`), the series' shared mod. **Traditional Preservation (Salt) - LTP Bridge** is optional and requires both.

## How it works

1. **Find a salt lick**: 3 to 7 tiles on natural ground, part dark mineral soil flecked with white, part **brine springs** (shallow blue-grey pools in a rim of salt). A lick of 3 or 4 tiles has 1 soil tile, one of 5 to 7 has 2; every tile touches one of its own kind. There are 15 in the world, one per region, in woodland, most of them near water. Every town has one within about 1,500 tiles.
2. **Dig Saline Soil** (right-click a soil tile): needs a shovel and an empty sack. Takes 3 in-game minutes and gives a 5 kg Sack of Saline Soil. Hovering the option shows how many diggings the spot has left. Each tile holds 5 diggings and regrows one a week by default, even while you are away. A tile with nothing left turns paler and loses most of its white flecks until it regrows.
   **Or fill at a spring** (right-click a spring tile, **Fill with Spring Brine**, about 1 in-game minute, no tools): fills the container in your hand, else a metal bucket, else any empty container, or one already holding spring brine. Spring brine is weak: a full 10 L bucket is 1 L of Brine and 9 L of tainted water, and boils to 1 Evaporated Salt. A spring holds 30 L (three buckets) and fills back 10 L a day by default, even while you are away; drawn dry, it shows mud until it refills. The soil is the cheap salt and runs out; the springs never do, but every salt from them costs a whole boil.
3. **Prepare Leaching Charge**: sack of soil + a full metal bucket of water (clean or tainted), spring brine or brine from the vat. You get your sack back.
4. **Build a Leaching Vat** (Carpentry 3): 6 planks, 12 nails, a cloth filter, a hammer and a saw (both kept). Outdoors only, not under a roof: leaching is wet, muddy work.
5. **Leach Brine**: load the charge into the vat and start it. After 2 in-game hours you take out a bucket of brine: the soil adds 5 L of Brine to what the liquid held (water 0 → 5, spring brine 1 → 6). A full bucket of brine can be the next charge's liquid too: stronger brine takes up less (under 5 L adds 5, 5-7 adds 3, 8-9 adds 2, to 10, saturated, which is refused). Water goes 0 → 5 → 8 → 10, spring brine 1 → 6 → 9 → 10. The clock keeps running while you are away. While it runs the vat shows the soil and a bucket under the keel, and when it finishes it shows spent soil and a full bucket until you take the bucket out.
6. **Boil the brine**: put the bucket of brine into a fire, stove or oven (drag it, or the loot window). It becomes a Bucket of Boiling Brine and boils once the heat is lit. Any amount with a litre of Brine or more boils; taken off the heat unboiled it is the same bucket of brine again and the boil starts over. A bucket's tooltip shows its strength (Weak, Brine, Strong, Saturated) and the salt it boils to. Scraping gives 1 Evaporated Salt per litre of Brine (1 from a spring, 5, 8 or 10 from the vat). It turns into a Bucket of Salt Crust in about 4 in-game hours on a fire and about 2 in an oven turned all the way up, and burns fuel as normal.
7. **Scrape Salt Crust**: needs a knife or meat cleaver (kept) and gives 1 Evaporated Salt per litre of Brine (5 from one pass of water), the bucket that went in (plain or forged) and 10 Cooking XP. Building the vat gives 15 Carpentry XP, and refilling a shaker with Evaporated Salt 3 Cooking XP (refilling from a bag gives none).

**Packaging salt**: Create Bag of Salt turns 10 Evaporated Salt and an empty paper bag into a Bag of Salt, which holds all the salt from those 10 portions (50 uses) and counts as salt itself. Bags don't unpack, but they refill shakers (below), and a used-up bag leaves its paper bag behind (always a plain one). Pack Box of Salt Bags takes 5 full bags, and the box unpacks to 5 bags. The box itself isn't tagged as salt. Packaging saves weight: 10 loose salt weigh 1.0, a bag 0.8, and a box of 5 bags 3.5.

Evaporated Salt counts as salt in any recipe that takes salt, with no other mods needed.

**Refilling shakers**: vanilla bread, pizza, pie dough, biscuits, guacamole and jarring ask for the vanilla Salt shaker itself, not just any salt, so they refuse Evaporated Salt. A used-up vanilla Salt shaker now leaves a Shaker (Empty) behind, and **Refill Salt Shaker with Evaporated Salt** turns it and 2 full Evaporated Salt into a real vanilla shaker that works in all of them. **Refill Salt Shaker from a Bag of Salt** does the same with 10 of the bag's 50 uses, from a full or part-used bag. A part-used shaker can't be refilled until it is used up.

## With the LTP Bridge

LTP's filling recipes ask for LTP's own crushed salt, not just any salt, so the bridge adds its own versions that take Evaporated Salt. They use the same amounts and give the same items. Evaporated Salt can be part-used and crushed salt can't, so all three refuse part-used salt. LTP's empty shaker is the same item as this mod's, so LTP's refill recipes take it too:

- **Make Jar of Evaporated Salt**: jar, lid, label, a writing tool and 2 Evaporated Salt, to a jar of salt.
- **Pack Salt Sack**: 50 evaporated or crushed salt + an empty sack, to a sack of crushed salt. A sack with items in it is refused.
- **Create Bag of Salt (Mixed)**: 10 evaporated or crushed salt in any mix + an empty paper bag, to a Bag of Salt. Bags don't unpack, so crushed salt put in a bag can't be turned back into crushed salt.

There is no direct recipe from Evaporated Salt to crushed salt, but LTP's own unpack recipes still give crushed salt from those jars and sacks.

LTP's curing recipe takes any salt, so salt from opened jars and sacks cures meat through LTP's own recipe.

## Tuning

**Salt lick regrowth (days)** is under Traditional Preservation (Salt) in the sandbox options: days for a soil tile to regrow one digging (7), and it scales a spring's refill with it (10 L a day at 7). Deposit and spring values are at the top of `42/media/lua/shared/TraditionalPreservationSalt.lua`. Recipe values are in `42/media/scripts/TraditionalPreservationSalt.txt`.

`tools/find_regions.py` recomputes salt-lick regions from the vanilla world map (needs Pillow and numpy). `tools/build_tileset.py` repaints the vat, the mineral patch, the brine springs (running and drawn dry), the item icons, the empty shaker and the bucket model textures (needs Pillow and the game files). It also writes the generated `42/media/lua/shared/TraditionalPreservationSalt/Tiles.lua`, the tile numbers the Lua reads (don't edit it by hand), and `luajit tests/test_tiles.lua` checks the entity scripts against it. `luajit tests/test_deposits.lua` checks the deposit maths, `luajit tests/test_patches.lua` patch placement and the soil and spring split, `luajit tests/test_leach.lua` the vat timer, `luajit tests/test_shaker.lua` the empties a used-up shaker or bag leaves, and `luajit tests/test_console.lua` the debug commands.

## Debug commands

In debug mode, `TPS.help()` in the Lua console lists commands for testing this mod. They are described in `DEVHELP.md`.

## Known prototype caveats

- The tiledef number 5171 must be unique among your active mods.
- Vat and deposit art is generated. The soil sack reuses the vanilla sandbag icon. Evaporated Salt uses vanilla's poultice mesh with a salt texture.
- Scraping gives back the bucket that went in, plain or forged. Brine and crust made before 0.1.8 give a plain metal bucket.
- The empty shaker is vanilla's mesh and icon with the salt painted out, and keeps that look with LTP loaded. A shaker used up in a station's recipe, rather than by hand, leaves no empty shaker, and no station uses vanilla salt in these mods.
- Multiplayer is not supported. This mod is singleplayer only for now.

## Test plan

Already passed: deposit maths and vat timer (offline), world load with and without LTP, and seed and site records surviving a restart (headless server). The steps below need the real game. Steps 12 and 15 are expected to pass from reading the engine, but have not been seen running.

**Deposits**
1. In a debug or test save, teleport to a region in `REGIONS`. A patch of 3 to 7 touching tiles appears within a minute of the ground loading, on natural ground with no building, road, tree or water.
2. Leave until the chunk unloads, then return: same squares, exactly one patch.
3. Save, quit, reload: same squares, same remaining counts.
4. Load an existing save where the area has been visited: the patch still appears.
5. Dig one tile 5 times: its option then greys out and says the spot is worked out, the tile turns paler with fewer flecks and the same outline within an in-game minute, and the other tiles can still be dug.
6. Advance 7 in-game days: that tile gets one digging back and its dark colour and flecks return. Advance 3 more weeks away from the site: three more, with no double counting after a reload.
7. Each dig consumes one empty sack and gives one soil sack. A sack with items in it is refused. Cancelling mid-dig costs nothing.
8. The dig takes 3 in-game minutes at your Day Length.

**Vat**

9. Vat appears in the build menu at Carpentry 3 and consumes the listed materials. It can't be built indoors or under a roof, and an empty vat picked up outdoors can't be put down indoors either. Rotating while placing switches between its two facings, and each one blocks the square and opens the vat window.
10. Prepare Leaching Charge needs 10 L of clean water, tainted water or a mix in one metal bucket, consumes the bucket and water, and gives the charge and the empty sack.
11. The charge goes in the vat, the progress bar runs, and it finishes in 2 in-game hours. Soil and bucket appear when it starts, and cancelling removes them. Check this on both facings.
12. Save and reload mid-run: progress is kept. Walk away until the chunk unloads and come back after 2 in-game hours: the brine is ready.
13. The vat gives a bucket of brine fluid. The finished look stays until the bucket is taken, then the vat is empty again. A second batch in the same vat takes the full 2 hours too. An empty vat can be picked up, rotated while placing it, and still works, with the right overlays on either facing. A vat with anything in it, or running, cannot be picked up or rotated.

**Boiling and salt**

14. The Leaching Charge, Bucket of Boiling Brine and Bucket of Salt Crust show their contents in their icons and when dropped on the ground. Boiling brine cooks only on a lit, fuelled heat source, and pauses when the heat goes out.
15. It turns into Bucket of Salt Crust: about 4 in-game hours on a campfire, less in a hot oven.
16. Scraping needs a knife or meat cleaver, which is kept and may wear slightly, and gives 5 Evaporated Salt and an empty bucket.
17. Evaporated Salt works in a soup or stew as seasoning.

**Salt packaging**

18. Create Bag of Salt uses 10 full Evaporated Salt and one paper bag (plain, Jays or Spiffos), and refuses part-used salt and a paper bag with items in it. The bag shows its icon and model, seasons a soup and cures meat. Pack Box of Salt Bags uses 5 full bags and refuses a part-used bag. The box shows a parcel, is not accepted as salt, and double-clicking it unpacks 5 bags.

**Salt shakers**

19. Using up a vanilla Salt shaker by seasoning food, and in a hand craft such as Make Bread Dough or Pack Fish in Salt, leaves exactly one Shaker (Empty). A shaker with uses left leaves nothing. Refill Salt Shaker with Evaporated Salt uses 2 full salt and the empty shaker, gives a full shaker that Make Bread Dough accepts, and refuses part-used salt. Refill Salt Shaker from a Bag of Salt takes 10 uses from a full bag (40 left) and from a part-used one; a bag with fewer than 10 left isn't enough on its own (whether two such bags combine is the engine's call: note what it does). Using up a Bag of Salt, by seasoning or in a hand craft (the last shaker refill, Pack Fish in Salt), leaves exactly one plain Paper Bag. With LTP loaded, curing that uses up a shaker gives one empty shaker, not two, and LTP's own refill accepts it.

**LTP bridge**

20. Make Jar of Evaporated Salt uses the jar, lid, label and 2 salt, keeps the writing tool, and gives a jar that opens and unpacks like LTP's own. It refuses part-used salt, but still accepts a used pen and a worn lid.
21. Pack Salt Sack gives a sack that opens and unpacks to 50 crushed salt, and refuses part-used salt and a sack with items in it. Create Bag of Salt (Mixed) accepts 10 crushed salt, and a mix of both, and gives a Bag of Salt.
22. Cure meat from an opened jar and an opened sack. Also check whether Evaporated Salt counts directly for `item 5 tags[Salt]`, and how many it takes.

**Regression**

23. `console.txt` shows no repeating Lua errors after an hour of play.
24. No vanilla or LTP recipe or loot table has changed. This mod adds no distributions.
