# Traditional Preservation (Salt): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPS.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPS.licks()` | Lists all 15 licks without giving away where they are: whether each has been placed, how many tiles and diggings left, or for an unplaced one its attempt count. A lick places the first time its ground loads. Safe to show on a stream or screenshot. |
| `TPS.licks(true)` | The same, plus each lick's coordinates and distance, an unplaced one's target square, its region and the nearest town. |
| `TPS.tp(n)` | Teleports you to lick `n`: its first tile if placed, or its target square if not, so it places as you arrive. |
| `TPS.nearest()` | The nearest lick, with distance and compass direction. |
| `TPS.here()` | The lick tile under you: diggings left and hours until the next one regrows. |
| `TPS.tiles(n)` | For each tile of lick `n` (or the nearest placed one): whether its ground object is there, which edge sprite it uses, its diggings, and every other object on that square in drawing order. Use it when a lick looks wrong or tiles seem missing. |
| `TPS.refill(n)` | Fills every tile of lick `n` (or the lick you're standing on) to 5 diggings. |
| `TPS.empty(n)` | Digs every tile of lick `n` (or the one you're on) out to 0, to test the worked-out look and regrowth. |
| `TPS.regrow(hours)` | Winds every lick's regrowth clock forward. `TPS.regrow(168)` is one week, one digging per tile. |
| `TPS.seed()` | This save's lick seed and the regrowth setting. |

Changes to tiles show on the ground within an in-game minute.

**Typical check of placement:** `TPS.licks(true)`, then `TPS.tp(3)` to an unplaced one, wait a moment, and run `TPS.licks()` again. It should now say PLACED with 3 to 7 tiles.

**Typical check of regrowth:** stand on a lick, `TPS.empty()`, `TPS.here()`, then `TPS.regrow(168)` and `TPS.here()` again. It should show 1 digging back.
