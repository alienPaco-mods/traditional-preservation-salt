# Changelog: Traditional Preservation (Salt)

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
  (user, step 90); soil and springs each have their own outline, so joined springs make one pool. `TPS` console reads
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
