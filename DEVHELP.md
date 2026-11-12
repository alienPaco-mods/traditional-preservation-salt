# Traditional Preservation (Salt): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPS.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPS.licks()` | Lists all 15 licks without giving away where they are: whether each has been placed, its soil tiles and diggings left and its springs and litres left, or for an unplaced one its attempt count. A lick places the first time its ground loads. Safe to show on a stream or screenshot. |
| `TPS.licks(true)` | The same, plus each lick's coordinates and distance, an unplaced one's target square, its region and the nearest town. |
| `TPS.tp(n)` | Teleports you to lick `n`: its first tile if placed, or its target square if not, so it places as you arrive. |
| `TPS.nearest()` | The nearest lick, with distance and compass direction. |
| `TPS.tile()` | The lick tile under you: a soil tile's diggings left and hours until the next one regrows, or a spring's litres and how fast it refills. |
| `TPS.tiles(n)` | For each tile of lick `n` (or the nearest placed one): whether its ground object is there, which edge sprite it uses, soil or spring with its diggings or litres, and every other object on that square in drawing order. Use it when a lick looks wrong or tiles seem missing. |
| `TPS.refill(n)` | Fills every tile of lick `n` (or the lick you're standing on): soil to 5 diggings, springs to 30 L. |
| `TPS.empty(n)` | Digs every soil tile of lick `n` (or the one you're on) out to 0 and draws its springs dry, to test the worked-out and dry looks and regrowth. |
| `TPS.regrow(hours)` | Winds every lick's regrowth clock forward. `TPS.regrow(168)` is one week: one digging per soil tile, a spring full again. |
| `TPS.seed()` | This save's lick seed and the regrowth setting. |
| `TPS.brine(litres, clean, total, forged)` | Gives a bucket with `litres` of Brine (default 1, a spring's), the rest tainted water, or clean water with `clean` true; `total` litres in all for a part-used one (default 10); `forged` true for a Forged Bucket. Says its strength and the salt it boils to. |
| `TPS.give(name, n)` | Spawns `n` of: `sack` (Sack of Saline Soil), `salt` (Evaporated Salt), `bag` (Bag of Salt), `bucket` or `forgedBucket` (both empty). `TPS.give()` lists them. |
| `TPS.buckets()` | For every bucket, charge, boiling bucket and crust in your main inventory: litres of Brine, the rest's fluid and the bucket kind noted. |

Changes to tiles show on the ground within an in-game minute.

**Typical check of placement:** `TPS.licks(true)`, then `TPS.tp(3)` to an unplaced one, wait a moment, and run `TPS.licks()` again. It should now say PLACED with 3 to 7 tiles.

**Typical check of regrowth:** stand on a lick, `TPS.empty()`, `TPS.tile()`, then `TPS.regrow(168)` and `TPS.tile()` again. It should show 1 digging back.

**Typical check of brine:** `TPS.brine(1)`, Prepare Leaching Charge with it, leach, take the bucket out and `TPS.buckets()`: it should read 6 L Brine, rest TaintedWater.
