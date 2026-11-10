# Changelog: Traditional Preservation (Salt)

## 0.1.8
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
