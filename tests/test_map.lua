-- Checks the Salt Lick Map's ring (S.mapRing): it rings the lick nearest where the map is first read, its centre is
-- off the lick by at most S.MAP_RING_SHIFT so the lick is always inside, the choice stays with the map, and it follows
-- a lick that was placed away from its target. Run from the mod folder: luajit tests/test_map.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
local S = TraditionalPreservationSalt

local rolls = {}
function ZombRand(n)
    local roll = table.remove(rolls, 1) or 0
    assert(roll < n, "roll out of range")
    return roll
end

check("rings are wider than the shift, so the lick is inside", S.MAP_RING_SHIFT < S.MAP_RING_RADIUS)
check("a 120-tile ring", S.MAP_RING_RADIUS * 2 == 120)
check("the view shows past the ring", S.MAP_VIEW_RADIUS > S.MAP_RING_RADIUS)

local saltModData = S.saltModData()
check("no licks yet, no ring", S.mapRing({}, 0, 0) == nil)

saltModData.sites = {
    { region = 1, placed = false, attempt = 0, targetX = 6577, targetY = 6522 },
    { region = 2, placed = true, x = 6300, y = 8470, tiles = {} },
}

-- Read near Riverside: the Riverside lick, shifted 20 tiles due east (angle 0, full shift).
rolls = { 0, S.MAP_RING_SHIFT }
local mapData = {}
local cx, cy = S.mapRing(mapData, 6085, 5438)
check("the nearest lick", mapData.lickSite == 1)
check("shifted east by the full shift", cx == 6577 + S.MAP_RING_SHIFT and cy == 6522)

-- Read again somewhere else: the same lick and the same ring.
local again = { S.mapRing(mapData, 6300, 8470) }
check("the choice stays with the map", again[1] == cx and again[2] == cy)

-- The lick is placed a few tiles off its target: the ring follows it.
saltModData.sites[1] = { region = 1, placed = true, x = 6570, y = 6530, tiles = {} }
local fx, fy = S.mapRing(mapData, 0, 0)
check("follows the placed lick", fx == 6570 + S.MAP_RING_SHIFT and fy == 6530)

-- Every angle and shift keeps the lick inside the ring, by at least the patch's spread.
local worst = 0
for angle = 0, 359, 15 do
    for shift = 0, S.MAP_RING_SHIFT do
        rolls = { angle, shift }
        local data = {}
        local x, y = S.mapRing(data, 6300, 8470)
        worst = math.max(worst, math.sqrt((x - 6300) ^ 2 + (y - 8470) ^ 2))
    end
end
check("the lick is never further off centre than the shift", worst <= S.MAP_RING_SHIFT + 1)
check("with room for the patch inside the ring", worst + S.MAX_PATCH_TILES < S.MAP_RING_RADIUS)

-- A map given its lick where it was found keeps it wherever it is read.
rolls = { 0, 0 }
local found = {}
S.pickMapLick(found, 6890, 6019)
check("found near Riverside: the Riverside lick", found.lickSite == 1)
local rx = S.mapRing(found, 6300, 8470)
check("read near the other lick, still Riverside's", found.lickSite == 1 and rx == 6570)

-- A map read near the second lick rings that one.
rolls = { 90, 0 }
local other = {}
local ox, oy = S.mapRing(other, 6000, 9000)
check("the other lick when nearer", other.lickSite == 2 and ox == 6300 and oy == 8470)

-- The map itself (client): opening it frames the view round the ring, and the world map gains only the reveal square.
TPCoreTesting = true
function isDebugEnabled() return true end
package.preload["ISUI/Maps/ISMapDefinitions"] = function() return true end
package.loaded["TraditionalPreservationSalt"] = true
local revealed, vanillaReveals, bounds, ringBounds = nil, 0, nil, nil
LootMaps = { Init = {}, DEFAULT_MAP_DIRECTORY = "media/maps/Muldraugh, KY" }
MapUtils = { initDirectoryMapData = function() end, initDefaultStyleV3 = function() end, overlayPaper = function() end,
    revealKnownArea = function() vanillaReveals = vanillaReveals + 1 end }
WorldMapVisited = { getInstance = function()
    return { setKnownInSquares = function(_, x1, y1, x2, y2) revealed = { x1, y1, x2, y2 } end }
end }
local layer = { setMinZoom = function() end, addFill = function() end, addTexture = function() end,
    setBoundsInSquares = function(_, ...) ringBounds = { ... } end }
local mapAPI = { setBoundsInSquares = function(_, ...) bounds = { ... } end,
    getStyleAPI = function() return { newTextureLayer = function() return layer end } end }
dofile("42/media/lua/client/TraditionalPreservationSaltMap.lua")

local itemData = { lickSite = 2, shiftX = 10, shiftY = -5 }
local mapUI = { mapObj = { getModData = function() return itemData end },
    character = { getX = function() return 6000 end, getY = function() return 9000 end },
    javaObject = { getAPIv1 = function() return mapAPI end } }
LootMaps.Init[S.MAP_ID](mapUI)
local view, reveal = S.MAP_VIEW_RADIUS, S.MAP_REVEAL_RADIUS
check("the view is framed round the ring", bounds[1] == 6310 - view and bounds[2] == 8465 - view
    and bounds[3] == 6310 + view and bounds[4] == 8465 + view)
check("the ring is drawn round its centre", ringBounds[1] < 6310 - S.MAP_RING_RADIUS and ringBounds[3] > 6310 + S.MAP_RING_RADIUS)
MapUtils.revealKnownArea(mapUI)
check("a 100 by 100 reveal", reveal == 50 and revealed[3] - revealed[1] + 1 == 100 and revealed[4] - revealed[2] + 1 == 100)
check("round the ring's centre", revealed[1] == 6310 - reveal and revealed[2] == 8465 - reveal)
check("with the lick inside it", revealed[1] <= 6300 and 6300 <= revealed[3] and revealed[2] <= 8470 and 8470 <= revealed[4])
check("not vanilla's whole view", vanillaReveals == 0)
MapUtils.revealKnownArea({ mapObj = {} })
check("other maps reveal as vanilla", vanillaReveals == 1)

H.done()
