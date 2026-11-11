# Changelog: Traditional Preservation (Salt)

## Unreleased
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
