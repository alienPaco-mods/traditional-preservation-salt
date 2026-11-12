-- Checks the debug console (TPS) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
local S = TraditionalPreservationSalt

-- Two licks: the first placed with the player on its first tile, the second still waiting for its ground.
local data = S.getData()
data.seed = 4242
data.sites = {
    { region = 1, placed = true, x = 50, y = 60, tiles = {
        { x = 50, y = 60, units = 1, lastRegen = 100 },
        { x = 51, y = 60, units = S.MAX_UNITS, lastRegen = 100 },
        { x = 52, y = 60, kind = S.SPRING, litres = 12, lastRegen = 100 },
        { x = 53, y = 60, kind = S.SPRING, litres = 30, lastRegen = 100 },
    } },
    { region = 2, placed = false, attempt = 3, targetX = 900, targetY = 60 },
}
local first = data.sites[1].tiles[1]
local player = H.player({ x = 50, y = 60 })
function player:teleportTo(x, y, z) self.teleported = { x, y, z } end
function getPlayer() return player end
-- The lick's squares aren't loaded.
function getCell() return { getGridSquare = function() return nil end } end

local TPS, run = H.checkConsole("42/media/lua/client/TraditionalPreservationSaltDev.lua", "TPS")

local plain, located = run("licks"), run("licks", true)
check("licks counts the placed ones", plain:find("1 of 2 licks placed", 1, true) ~= nil)
check("and keeps their places to itself", plain:find("50,60", 1, true) == nil and plain:find("900,60", 1, true) == nil)
check("licks(true) adds where they are", located:find("at 50,60", 1, true) ~= nil and located:find("Target 900,60", 1, true) ~= nil)

check("licks counts soil and springs", plain:find("2 soil tiles 6/10 diggings left, 2 springs 42/60 L", 1, true) ~= nil)
check("nearest finds the lick under the player", run("nearest"):find("Lick #1, 0 squares", 1, true) ~= nil)
check("tile reads the tile the player stands on", run("tile"):find("1/" .. S.MAX_UNITS .. " diggings", 1, true) ~= nil)
check("tiles says which squares aren't loaded", run("tiles", 1):find("not loaded", 1, true) ~= nil)
check("tiles with no number takes the nearest placed lick", run("tiles"):find("tile 2 at 51,60", 1, true) ~= nil)

local standOn = player.getX
function player:getX() return 52.5 end
check("here reads a spring's litres", run("tile"):find("spring, 12.0/30 L", 1, true) ~= nil)
player.getX = standOn
local spring = data.sites[1].tiles[3]
run("empty")
check("empty digs out the lick the player stands on", first.units == 0 and spring.litres == 0)
run("refill", 1)
check("refill fills a lick by its number", first.units == S.MAX_UNITS and spring.litres == S.SPRING_LITRES)
check("neither touches a lick that isn't placed", run("refill", 2):find("isn't placed", 1, true) ~= nil)

first.units, first.lastRegen = 0, 100
run("regrow", 5)
check("regrow winds the clocks forward", first.lastRegen == 95)
run("regrow")
check("and by one digging's time with no number", first.lastRegen == 95 - S.REGEN_HOURS)

run("tp", 2)
check("tp goes to an unplaced lick's target", player.teleported and player.teleported[1] == 900.5 and player.teleported[2] == 60.5)
check("and says so for a number with no lick", run("tp", 9):find("No lick 9", 1, true) ~= nil)
check("seed prints the save's seed", run("seed"):find("4242", 1, true) ~= nil)

check("give with no name lists the things", run("give"):find("forgedBucket", 1, true) ~= nil and #player.given == 0)
run("give", "sack", 2)
run("give", "forgedBucket")
check("give spawns sacks of soil and a Forged Bucket", #player.given == 3
    and player.given[1] == "TraditionalPreservationSalt.SalineSoilSack" and player.given[3] == "Base.BucketForged")

H.done()
