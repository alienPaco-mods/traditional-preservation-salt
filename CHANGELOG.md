# Changelog: Traditional Preservation (Salt)

## 0.1.38
- **Forge Salt Pan works at the Primitive Forge** (user, 2026-11-22; `Tags = PrimitiveForge`, so every forge runs
  it): a flat pan beaten from two sheets, as vanilla's frying and roasting pans are. The Forged Cauldron stays at the
  Forge, as vanilla's cooking pot. README, guide, Workshop text.
- **The Salt Pan's skill matches vanilla's pans** (user, 2026-11-22): Blacksmith 2 (was 3), known without the
  magazine at Blacksmith 4 with Cooking 1 (was Cooking 2), as the Frying and Roasting Pans.

## 0.1.37
- **The brine's strength line goes through TP Core's `ItemTooltip`** (the one wrap of the tooltip's draw, now Core's so
  every mod adds lines to it). It reads as before. Needs TP Core 0.1.57.

## 0.1.36
- **In TP Core's station report** (written on each save, for the long-save log): the Leaching Vat window take part
  (`StationReport.add`). Needs TP Core 0.1.56.

## 0.1.35
- **The Leaching Vat freezes** (ROADMAP NEXT 1, frost step 4; user, session 76): at -2 C and below where it stands
  (TP Core's places and frost record, `S.VAT_FREEZE_C`), the bed and the drip wait, and go on once thawed. A lit fire
  or banked embers within 2 tiles keep it from freezing while the fuel lasts; a basement never freezes. The vat now
  knows its place (`S.stationNow`, through TP Core's `Fire.placeOf`); its record keeps a `frost` record. `TPS.vat()`
  shows its frozen hours. Vat Info's band reads **Frozen** first while liquid on the bed is frozen. No sandbox option
  (Salt has no temperature setting). Needs TP Core 0.1.52.

## 0.1.34
- **Leaching Vat Info built to the approved mock** (`art/all_info_mock.png`): a band (Tub full, Leaching with its rate
  and sacks, Brine waiting in the tub, Spent soil, Ready, Empty; worst first), the Station block (outline icon,
  Place), Holds left to right as the liquid goes: what is poured on (the soaking bed, a tank), the soil as three cells in
  the soil pattern (`TPCell_Soil`) with its salt left, and the tub (a tank), the tanks in the brine's colour with its
  strength and what it boils to, the rate over both arrows while it drains, and the Lincolnshire lore beside them. Sacks dragged onto the soil's cells go on,
  water or brine dragged onto the soaking bed pours (the drop square is gone). Draw Off Brine is a button with its icon.
- The Tub tank's line says what all its brine boils to (was a 10 L bucket's), "too little to boil yet" under a
  salt's worth, and a drip that reads 0.0 L shows no strength.
- Draw Off Brine (button, menu row and the action) needs brine that has dripped through into the tub
  (`S.DRAW_FROM_LITRES`, 0.05 L, `S.canDrawOff`): a drip that reads 0.0 L no longer leaves it enabled while the
  brine still sits on the soaking bed.
- **Throw Out Spent Soil (n)** (menu and window button, while any soil is spent; greyed while liquid soaks through):
  digs the soil with no salt left out of the bed, soil still holding salt stays (`S.throwOutSpent`, action mode
  "spent"). Fresh soil still throws spent soil out on its own.

## 0.1.33
- Temperatures in the game's text read with the degree sign ("12°C", was "12 C"), as TP Core 0.1.37's.

## 0.1.32
- Leaching Vat Info's drop square shows a Saline Soil Sack.

## 0.1.31
- The Leaching Vat's window row reads "Leaching Vat Info" (was "Vat Info"), its title "Leaching Vat".
- **The salt pan's heat is a thin bar beside its tank** in Stone Hearth Info (TP Core 0.1.35), the salt in it and
  when it will be dry under the two.
- **The salt settles in the pan's tank** (user): a white layer at its foot under the brine. None while the brine can
  still hold it (saturated: a litre of Brine in a litre), then growing as the brine boils down past that, all of it
  once dry, so a boiled-dry pan no longer shows an empty tank. A full pan of Brine's salt (30) fills it.
- **Drag buckets of brine onto the pan to pour them in** (TP Core 0.1.35's drop target): brine, watered or not, up to
  its room, as Pour Brine into Salt Pan takes; one walk, one pour a bucket. A note says so while there is room.

## 0.1.30
- **Stone Hearth Info with the salt pan** on TP Core 0.1.34's Info rules: the pan as a tank (litres, the salt in it
  under) and its heat as a thermometer (100 boils; when it will be dry under), in Holds after the wood.
## 0.1.29
- **The Leaching Vat as a soil bed** (user, session 60). The vat holds up to 3 Sacks of Saline Soil, each a layer of 5
  salt, the newest on top (**Add Saline Soil**, the empty sack back; spent soil is thrown out when new goes on).
  **Pour onto the Soil** any container of water, clean or tainted, or brine, partial pours, up to 30 L. It soaks
  through at 5 L an hour (`S.DRAIN_PER_HOUR`), each litre picking up salt at every layer by its strength (0.5 / 0.3 /
  0.2 of a litre of Brine a layer, under 5 / 5-7 / 8-9 in 10, the old charge's steps), never past saturation; salt not
  taken stays in the soil. One sack and 10 L of water still give 5 L of Brine, and brine poured back over fresh soil
  still goes 5, 8, 10; 2 sacks give 8 and 3 give saturated brine in one pass, with the rest of the salt kept for the
  next pour. A sack always yields its 5 salt (before, making strong brine lost some). The brine drips into a
  built-in 30 L tub (one salt pan); **Draw Off Brine** fills any container with what has dripped so far; a full tub
  stops the bed. Vat Info: the place, Soil, Soaking and Tub bars, Draw Off, a drop square for sacks and containers.
  The record is `tpsVat` { layers, bed, tub, hour } (`TraditionalPreservationSaltVat.lua`); `TPLeachingVat` "soil",
  "pour" and "draw"; `S.leachLiquid`, `S.fillWith`; `TPS.vat(hours)`.
- **Removed: Prepare Leaching Charge and the Leaching Charge** (item, model, icons, strings), `S.afterLeach`,
  `S.canLeach`, `S.sampleBrine` and the charge's OnTest / OnCreate.
- **Art:** an oval coopered catch tub under the spout (no metal, long side parallel to the vat's front) replaces the
  bucket; 11 looks a facing (dry, wet or spent soil; the tub empty, part-full or full) from tile 96, the sheet 15
  rows on a 2048 page. Mock: `WIP/TPCore/art/vat_tub_mock.py`.
- test_vat rewritten, test_brine. README, guide, Workshop text, DEVHELP; Balance (BuildingRecipes, CraftingRecipes,
  BalanceEval, Realism), TESTING_GUIDE 21d-21f, 22h, 23b-c.

## 0.1.28
- **Leaching Vat off CraftLogic** (ROADMAP section 12, the last workstation): no crafting window. The vat keeps its one
  charge as its own record in its movableData (`tpsVat`, `TraditionalPreservationSaltVat.lua`), on the plain game
  clock as before (2 hours, any Day Length, rain or shine), and the brine comes out the same (`S.afterLeach`). The
  right-click menu has the status, **Vat Info**, **Put In the Charge** (it starts at once; there is no Craft button now),
  **Take Out the Brine** (greyed until done, saying how long is left) and, while it runs, **Take Out the Charge** (back
  as it went in). Vat Info on TP Core's InfoWindow: place, what it holds, a bar with the time left, the Brine it comes
  out at, the buttons and a drop square for a charge. Salt's World layers the leaching and done sprites itself. A vat
  holding a charge can't be picked up (`UI.keepInPlace`). Gone: the LeachBrine recipe, its OnStart / OnUpdate / OnCreate,
  the vat's crafting-window block (`TraditionalPreservationSaltVatInfo.lua`) and the wrap of
  `ISItemSlotRemoveAction.complete` (the bucket comes out as a fluid bucket straight away). `TPLeachingVat` does the
  hand jobs; `TPS.vat(done)` and `TPS.give("charge")`. test_vat (replaces test_vat_info and test_leach), test_brine.
  README, guide, Workshop text, DEVHELP. The vat's entity script keeps its unused SpriteOverlayConfig block: dropping it stopped saves
  with a vat built from loading (ENGINE_NOTES, "Removing a component from an entity script"). A vat built before
  this keeps its saved crafting window (UiConfig, CraftLogic, Resources), which errored from the menu and left-click:
  the World removes them once (`GameEntityFactory.RemoveComponentType`) and clears its old overlay style; what its old
  slots held is lost.

## 0.1.27
- **Hand recipes work from the floor** (series recipe audit, 2026-11-19): every hand recipe but Packing has
  `CanBeDoneFromFloor`, so its inputs aren't carried into the inventory first (vanilla moves them otherwise): Prepare Leaching Charge (its 10 L bucket stays where it is), Scrape Salt Crust, both Refill Shaker, Unpack Box of Salt Bags; and the LTP add-on's Make Jar of Evaporated Salt (SaltLTP 0.1.1).

## 0.1.26
- **The salt pan's rows move the item into the inventory before the walk** (vanilla's order).

## 0.1.25
- **The salt pan's fire box holds a full bucket of brine** (2026-11-18): its tiles' `ContainerCapacity` is 15, as TP Core 0.1.10's Stone Hearth (was 10, under a full bucket's 11). Stone Hearths with the pan already fitted are raised by TP Core. Needs TP Core 0.1.10.

## 0.1.24
- **Brine turns into Bucket of Boiling Brine only once the heat is on** (2026-11-17): it used to turn as it went into any fire, stove or oven, cold or not, and read "boiling" in a cold stove. A bucket put into a heat that is on (container temperature `S.BOIL_HEAT` 1.5 or more: a stove's lowest setting, a lit or banked fire) turns at once, as before; one put into a cold heat stays a bucket of brine and turns within a game minute of the heat coming on, while a player is near (`S.boilIn`, on TP Core's `Station.onHeatNear`). Taken off the heat it is brine again; left in a heat that goes out it waits as boiling brine, as before. test_brine. README, guide, Workshop text.

## 0.1.23
- **Empty the Salt Pan** (2026-11-17): while the pan holds brine, its menu pours it all away, the salt in it too, so a pan can come off before it has boiled down (it still has to cool). Longer the more there is, as the cauldron's Empty. `SaltPan.empty`, `TPSaltPanWork` "empty"; test_salt_pan, test_salt_pan_attachment. README, guide, Workshop text.

## 0.1.22
- **Salt pan** (2026-11-17), the first Stone Hearth attachment from outside TP Core: a shallow 30 L pan of forged iron, forged at a forge (Forge Salt Pan: 2 Steel Sheets, 2 Charcoal, a ball-peen hammer and tongs or pliers, Blacksmith 3, learned from Everyday Smithing - May 1993 or researched from the pan) and fitted over a Stone Hearth's hole with 2 Clay and a mason's trowel (Fit Salt Pan, about 30 minutes; the clay is lost on Remove). Pour brine in any time (Brine and water only, up to 30 L), the salt staying behind as it boils: to the boil in about half an hour on a lit fire, then 6 L an hour off, a third of that banked; dry, it waits as a crust, even on the fire, and Scrape the Salt Pan with a knife gives 1 Evaporated Salt a litre of Brine. It comes off only empty and cool (below 40 C). The fire box under it stays open (one bucket of brine). Tiles 72-93 in Salt's tileset: the Stone Hearth with the pan, empty, steaming or crusted, by fire and facing, and the brine's tinted overlay, still and boiling (`tools/salt_pan_tiles.py`, built on TP Core's stone painter); item and status icons. New `SaltPan.lua` (the rules), `SaltPanAttachment.lua`, `TPSaltPanWork`, `client/TraditionalPreservationSaltPanUI.lua`, `S.brineAndWater`; `TPS.give("pan")`, `TPS.kit("fit" / "forge")`, `TPS.panInfo()`, `TPS.pan(l, brine, c)`. test_salt_pan, test_salt_pan_attachment. Needs TP Core 0.1.8.

## 0.1.21
- **Salt Lick Map** (2026-11-17): a found map, as rare as vanilla's Generator Magazine: weight 1 in a ranger station's desk and magazines (`RangerDesk`, `RangerMagazines`) and a camping store's books (`CampingStoreBooks`), 0.5 in a library's books and magazines (`LibraryBooks`, `LibraryMagazines`), 0.1 in an office desk (`OfficeDesk`). It opens like vanilla's town maps (`LootMaps.Init`) and shows the woods around the lick nearest where it was found, with a 120-tile pencil ring over its area; the ring's centre is up to 20 tiles off the lick, so the lick is inside but the search stays. The lick is chosen when the container fills (`OnFillContainer`), or where it is first read for a map with no spot (a vehicle's, or `TPS.give("map")`), and kept on the map. The ring is on the found map only. Reading it reveals 100 by 100 tiles round the ring's centre on the world map (`S.MAP_REVEAL_RADIUS`), not the whole 600-tile view vanilla would: TP Core's `Wrap` on `MapUtils.revealKnownArea`, for this map only. New `S.nearestSite`, `S.pickMapLick`, `S.mapRing`, `client/TraditionalPreservationSaltMap.lua`, the ring texture (`tools/draw_map_ring.py`), `tests/test_map.lua`; `test_loot` covers the lists and the fill. `TPS.give` has `map`. README, guide, Workshop text. In-game step in TP Core's `TESTING_GUIDE.md`.

## 0.1.20
- **Internal** (2026-11-16): the Bag of Salt loot goes through TP Core's `Loot.add` and names the bag by `S.BAG_ITEM`, not a second copy of its name. Same lists and weights; nothing changes in game. Needs TP Core 0.1.5.

## 0.1.19
- **Bag of Salt as loot** (2026-11-16): a full Bag of Salt is added to a restaurant kitchen's sauce and baking shelves (`StoreKitchenSauce`, `StoreKitchenBaking`) at weight 0.05 (very rare) and to a house's kitchen dry food (`KitchenDryFood`) at 0.01 (super rare); vanilla's Salt shaker there is 4 on the sauce shelf and 20 in dry food, and a bag holds five shakers' salt, so the weights are Sledgehammer and Generator Magazine rarity (0.01 to 0.1) and the loot doesn't shorten the salt reserve. New `server/TraditionalPreservationSaltLoot.lua`, `tests/test_loot.lua`. Guide, README (loot paragraph, test 24), Workshop text ("adds no loot" is gone). In-game step in TP Core's `TESTING_GUIDE.md`.

## 0.1.18
- **Naming sweep** (2026-11-16, TP Core's DEVGUIDE "How code is named"): `S.saltModData` (was `getData`), the lick generator's `roll` (`S.firstRoll`, `S.nextRoll`), a lick tile's saved `source` (soil or spring; was `kind`), `S.LICK_TILE_KEY`. Tests unchanged; nothing changes in game. Pre-release: an old test save's stations read as new, so test on a fresh save.

## 0.1.17
- **Wraps through TP Core's `Wrap`** (2026-11-16): the brine tooltip and the vat's take-out go in late and guarded. Nothing changes in game.
- **Refactor** (2026-11-16): the boiling bucket is swapped where it lies by TP Core's `Action.replaceItem` (Salt's own copy moved to Core for Dairy's burnt pots). Nothing changes in game.

## 0.1.16
- **Guide** (2026-11-15): the Saltworker's table salts a 4-weight walleye at its 28 uses (one soil tile 4 fish, was 3; a whole lick 5 to 11, was 4 to 10). Nothing changes in game.
- **Guide shortened** (2026-11-15): repeated secrets and an old-names note cut. README: a crust with no bucket noted gives a plain bucket (was "made before 0.1.8"). Nothing changes in game.
- **README** (2026-11-15): no dev-machine path. Nothing changes in game.
- **Docs and comments** (2026-11-15): decisions are stated plainly, without attributions (CHANGELOG, comments). Nothing changes in game.
- **README** (2026-11-15): an opening paragraph and a table of the two roads (saline soil, spring brine).
- **Version** (2026-11-15): the changes above are 0.1.16 (mod.info, README heading; was "Unreleased").
- **Refactor with TP Core's Stone Hearth split** (2026-11-15): the boiling brine bucket is stove food through `StoneHearth.cooksOn`. Nothing changes in game.
- **Refactor with TP Core's names** (2026-11-15): TP Core's `Hearth` is `Fire`. Nothing changes in game.
- **Refactor** (TP Core's refactor pass, step c): nothing changes in game but one fix. Dig and Fill run on TP Core's game clock helper (**`Action.startClock`, `Action.clockProgress`**; each action had its own copy); their menu rows are refused through `UI.refuse`; the dug sandbag leaves through `Action.removeItem`. Item names said once in the main file (`S.SACK_ITEM`, `S.SALT_ITEM`, `S.BAG_ITEM`, `S.EMPTY_BUCKET`, Brine's `S.CRUST_ITEM`; the Shaker and console use them), the strength marks are `S.BRINE_FROM` and `S.STRONG_FROM`, the console reads `Container.KEY`. The brine checks share one count of what isn't Brine or water, and look the three fluids up once (the tooltip asked every frame). New **`S.siteAt(x, y)`** (site and tile; `S.getTileAt` uses it) and **`S.position(site)`**; the console's own copies and its two nearest-lick searches are one. **Pre-release leftovers gone:** `S.OLD_BRINE_LITRES` (brine items from before brine was a fluid; `S.notedBrine` takes no default) and `S.isSplit` (licks placed before the springs). **Fixed (B1):** the fill action ran on a spring under 1 L, which the menu and sprite call dry; both now ask **`S.isDry`** (`S.SPRING_DRY_LITRES`). test_patches: `isDry`, `position`; the old-build checks are gone. In-game step 159 of TP Core's `TESTING_GUIDE.md`.
- **A held item swapped by the brine leaves the hands**: the brine's swap takes the old item out through TP Core's `Action.removeItem` (vanilla's `Remove`, which also empties the hands; was `DoRemoveItem`). test_brine's stand-ins have `Remove`. In-game step 158h of TP Core's `TESTING_GUIDE.md`.
- **Refactor with TP Core's small shared helpers tidy** (2026-11-14): salt that TP Core's `Uses.take` empties gives its empty shaker or paper bag through **`Uses.onEmptied(ItemTag.SALT, S.returnEmpties)`** (Core called `S.returnEmpties` by name before). The brine vat's take-out wrap `require`s vanilla's `ISItemSlotRemoveAction` plainly; the tooltip draw's protected call is commented with why it stays. Nothing changes in game; test_shaker stubs `ItemTag`; tests unchanged.
- **No station in front of a door** (after TP Core's in-game step 146b): the Leaching Vat can't be built or put down on the tile in front of a door (TP Core's `Doors`): `S.isOutdoors` asks `Doors.fits` too, and `UI.keepDoorsFree(Tiles.STATIONS)`. In-game step 147 of TP Core's `TESTING_GUIDE.md` passed (INGAME_PASS 146).
- **Guide** (2026-11-14): the boiling brine bucket is heard, and shows as the pot in TP Core's Stone Hearth.
- **Stove food** (2026-11-13): a Bucket of Boiling Brine is TP Core's stove food (`Hearth.cooksOn`), so the Stone Hearth sets its pot in the hole while it boils. Needs this TP Core.
- **Sound** (2026-11-13): a Bucket of Boiling Brine plays TP Core's `TPBoiling` while it boils (it was silent). Needs this TP Core.

## 0.1.15
- **Make Bag of Salt** (was Create Bag of Salt; sweep step F), the series' verb; the recipe's id is unchanged.
- Needs Build 42.22 or newer (`versionMin`, was 42.20: everything is checked on 42.22). Guide, README, Workshop text.

## 0.1.14
- **On TP Core's shared modules** (2026-11-12; nothing a player sees): empties come back through Core's `Handcraft`
  (in place of the mod's own wrap of `ISHandcraftAction.performRecipe`), the brine recipes read their items with
  Core's `Recipes.created` and `Recipes.consumed`, and the debug lines go through Core's `Log` (tag `[TPS]`, was
  `[TraditionalPreservationSalt]`). In-game step 101 of `TESTING_GUIDE.md`.
- Guide (2026-11-12): checked line by line against the code. A stronger liquid gains less than 5 L in the vat; a
  plus-shaped lick of five has one soil tile; what stops a bucket boiling; whole chapter numbers (the Saltworker's
  Notes are chapter 8), a Credits page.


## 0.1.13
- Debug console (2026-11-12): `TPS.give(name, n)` spawns sacks of saline soil, Evaporated Salt, a Bag of Salt and
  empty buckets, plain or forged; `TPS.brine` takes a fourth argument for a Forged Bucket. Test, DEVHELP, guide.
- Guide: no emojis (2026-11-12): the decorative bullets and margin-note marks are gone, warning signs read **Warning:**.
- **Info in the Leaching Vat's window** (2026-11-12, consistency sweep step E, TP Core's StationInfo): the place, a
  bar for the running charge with its time left (the vat goes by the clock), and what a waiting charge's liquid will
  come out at and what the finished bucket holds.

## 0.1.12
- Debug console (2026-11-12, consistency sweep): `TPS.here()` is now `TPS.tile()` (`here` means the weather place in
  the other mods). Tests, DEVHELP, guide.
- Names (2026-11-12, consistency sweep): **Bucket of Boiling Brine** (was Brine for Boiling (Bucket); not plain
  "Bucket of Brine", which is what a bucket holding the Brine fluid is called in the texts) and **Bucket of Salt
  Crust** (was Bucket with Salt Crust), as vanilla names a full bucket. Display text only.
- Guide: a lick's 1 or 2 soil tiles give 5 to 10 sacks, not 15 to 35 (the tip predated the brine springs).

## 0.1.11
- Brine spring, step 3 (2026-11-12): every lick is now soil tiles and **brine springs**: 3-4 tiles have 1 soil tile,
  5-7 have 2, picked from the lick's seed so every tile touches one of its own kind (a plus-shaped lick of 5 gets 1
  soil, an arm). A lick placed before keeps its tiles and is split on load. A spring holds 30 L and fills back 10 L a
  day at the default regrowth (scaled by Regrowth Days). Right-click a spring: **Fill with Spring Brine** (1 game
  minute) fills the container in hand, else a metal bucket, else any empty container or one already holding spring
  brine: a tenth Brine, the rest tainted water. 32 new tiles (16 running, 16 drawn dry; sheet 5 → 9 rows, old tile
  numbers kept): a spring is a blue-grey pool in a wide, patchy grey-white rim of salt and a thin band of mineral soil, no soil under it
  (step 90); soil and springs each have their own outline, so joined springs make one pool. `TPS` console reads
  springs (licks, here, tiles, refill, empty).

## 0.1.10
- Brine spring, step 2 (2026-11-12; the tooltip skips what is not an inventory item, as in the pour window): a metal bucket of brine put into a fire, stove, oven, brazier or barbecue (drag,
  loot window: TP Core's `Transfer.after`) turns into the boiling item, any amount with Brine for one salt or more,
  noting its litres; taken off the heat unboiled it is the same fluid bucket again and the boil starts over. Between
  two heats nothing changes. A microwave is left out. The boiling item is now **Brine for Boiling (Bucket)** (was
  Bucket of Brine: it holds no fluid; id unchanged). **Set Brine to Boil is gone**: the swap is the only way onto the
  heat, and every route goes through it. Tooltip line on a bucket of brine and on the boiling item: Weak brine / Brine /
  Strong brine / Saturated brine and the salt it boils to (a wrap of `ISToolTipInv.render`).

## 0.1.9
- Brine spring, step 1 (2026-11-12): brine is a fluid, **Brine**, and a bucket's strength is its Brine share (the
  rest water, clean or tainted). The vat hands back a bucket of fluid, 5 L Brine + 5 L of the charge's water. Any
  full bucket can be a charge's liquid: water, or brine to make it stronger (under 5 L Brine gains 5, 5-7 gains 3,
  8-9 gains 2, to 10 L, saturated, which is refused). New **Set Brine to Boil** puts a full bucket of any strength
  on the heat; scraping gives 1 Evaporated Salt per litre of Brine, rounded down (water once: 5, as before). The
  bucket's Brine rides in `condition:` keys through charge, boil and crust. Debug: `TPS.brine`, `TPS.buckets`.
- Docs (2026-11-11): the guide's salt-per-fish notes follow Fish 0.3.2, which charges 4 uses per started half weight
  (a panfish 4, a 4.5 walleye 36, a split 10-weight catfish 32 a half).

## 0.1.8
- Docs (2026-11-11): the guide's salt-per-fish note follows Fish 0.2.9, where a fish over 4.5 weight is split
  before salting (a 4.5 walleye takes 18, a split 10-weight catfish 16 a half).
- Docs (2026-11-11 pass against the code): README and Workshop text no longer say a forged bucket comes back plain
  (fixed in this version); the guide's salt-per-fish figures follow Fish's salt by size (2 uses is the least, a
  4 weight walleye takes 16); refill XP is named per recipe; README lists `test_shaker` and `test_console`; the
  Workshop load order starts with Traditional Preservation (Core). No change in play.
- Menu icon: Dig Saline Soil shows the sack it fills.
- Balance (series pass, F2): new **Refill Salt Shaker from a Bag of Salt**, 10 of the bag's 50 uses, part-used bags
  welcome (C7). A used-up Bag of Salt leaves a plain Paper Bag, by seasoning (`ReplaceOnUse`) and in hand crafts (the
  `performRecipe` wrap, now `S.returnEmpties` / `S.emptyFor`, was `returnEmptyShakers` / `needsEmptyShaker`) (C6).
- Balance (series pass, F1): the Leaching Vat needs a saw, kept. Scrape Salt Crust gives Cooking 10 (was 15).
- Internal: new `tests/test_console.lua` loads the debug console (TPS) and calls every command, on two stand-in
  licks, so one can't break unseen.
- Changed: digging honours the debug cheat for instant actions.
- Internal: the dig action is `TPDigSalineSoil` (was `ISDigSalineSoil`), file and class, so another mod's file of
  the same name can't replace it; the menu's tooltip helper is TP Core's.
- Fixed: a Forged Bucket used for a Leaching Charge came back from Scrape Salt Crust as a plain Metal Bucket. The
  bucket's kind is now noted on the charge, the brine and the crust (TP Core's `Container`), and scraping gives back
  the bucket that went in. Both buckets still work. Brine and crust made before this give a plain bucket, as before.
  New recipe hooks: `onChargePrepared`, `onBrineLeached`, `onCrustScraped`.
- Fixed: the salt lick's Dig menu answers vanilla's controller probe (`ISWorldObjectContextMenu.setTest()`), so a
  controller gets the interact prompt on a lick tile.

## 0.1.7
- Now requires **TP Core** (`TraditionalPreservationCore`), the Traditional Preservation series' shared mod: subscribe
  to it too. Salt no longer carries its own copy of the shared core (`TraditionalPreservationSalt/Core/` is gone);
  the leach timer and the vat's outdoor rule use TP Core's. Same timing, same saves: every deposit, modData key
  (`leachStartHour`), item and entity name is unchanged.
- Internal: the synced core copies name the core's new source path (TP Core is now a mod). Comment line only.
- Internal: the shared core's folder is now `TraditionalPreservationCore` (was `_tpcore`): comments and test
  paths only. No change in play.

## 0.1.6
- Internal: comments on the public functions that lacked one, and an updated copy of the shared core
  (comments only). No change in play.

## 0.1.5
- Internal: the code uses a `local S` alias for `TraditionalPreservationSalt`. Public names unchanged, no change in play.

## 0.1.4
- Internal: updated copy of the shared core. No change in play.

## 0.1.3
- Internal: updated copy of the shared core. No change in play.

## 0.1.2
- Internal: tile numbers come from a `Tiles.lua` the art builder writes, instead of hand-kept numbers. Same art.

## 0.1.1
- Internal: the Leaching Vat's timer and outdoor rule use the shared Traditional Preservation core. Same timing.
