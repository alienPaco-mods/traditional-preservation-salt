-- Checks the deposit maths outside the game. Run from the mod folder: luajit tests/test_deposits.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
ModData = { getOrCreate = function() return {} end }
dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
local N = TraditionalPreservationSalt
local WEEK = N.REGEN_HOURS

SandboxVars = { TraditionalPreservationSalt = { RegrowthDays = 14 } }
N.applySandbox()
assert(N.REGEN_HOURS == 14 * 24, "the sandbox sets the regrowth")
SandboxVars = { TraditionalPreservationSalt = { RegrowthDays = 7 } }
N.applySandbox()
assert(N.REGEN_HOURS == WEEK, "and the default puts it back")
SandboxVars = nil

local check = H.check

for seed = 1, 2000 do
    for index, region in ipairs(N.REGIONS) do
        local x, y = N.pickTarget(seed * 977, index, 0)
        assert(x >= region.x1 and x <= region.x2 and y >= region.y1 and y <= region.y2)
    end
end
check("targets stay inside their region", true)

local x1, y1 = N.pickTarget(12345, 3, 0)
local x2, y2 = N.pickTarget(12345, 3, 0)
check("same seed gives the same target", x1 == x2 and y1 == y2)
local x3, y3 = N.pickTarget(54321, 3, 0)
check("another seed gives another target", x1 ~= x3 or y1 ~= y3)
local x4, y4 = N.pickTarget(12345, 3, 1)
check("a retry gives another target", x1 ~= x4 or y1 ~= y4)

for seed = 1, 2000 do
    local size = N.patchSize(seed * 977, 1 + seed % #N.REGIONS)
    assert(size >= N.MIN_PATCH_TILES and size <= N.MAX_PATCH_TILES)
end
check("patch sizes stay in range", true)

local site = N.newTile(0, 0, 0)
N.catchUp(site, 10 * WEEK)
check("a full deposit stays at the cap", site.units == N.MAX_UNITS)
N.takeUnit(site, 10 * WEEK)
check("digging starts the clock from the last dig", site.lastRegen == 10 * WEEK and site.units == N.MAX_UNITS - 1)
N.catchUp(site, 10 * WEEK + WEEK - 1)
check("nothing grows before a full period", site.units == N.MAX_UNITS - 1)
N.catchUp(site, 11 * WEEK)
check("one unit grows after a full period", site.units == N.MAX_UNITS)

site = N.newTile(0, 0, 0)
for _ = 1, N.MAX_UNITS do check("dig", N.takeUnit(site, 0)) end
check("an empty deposit refuses digging", not N.takeUnit(site, 0))

N.catchUp(site, WEEK * 1.5)
check("part periods are kept", site.units == 1 and site.lastRegen == WEEK)
N.catchUp(site, WEEK * 2)
check("the kept part counts next time", site.units == 2)

local a, b = N.newTile(0, 0, 0), N.newTile(0, 0, 0)
a.units, b.units = 0, 0
for hour = 1, 3 * WEEK do N.catchUp(a, hour) end
N.catchUp(b, 3 * WEEK)
check("many small checks equal one long absence", a.units == b.units and a.units == 3)

N.catchUp(b, 3 * WEEK)
check("repeat checks add nothing", b.units == 3)
N.catchUp(b, 500 * WEEK)
check("a very long absence stops at the cap", b.units == N.MAX_UNITS)
H.done()
