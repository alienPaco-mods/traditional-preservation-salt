-- Traditional Preservation (Salt): constants and the deposit bookkeeping shared by the world and the menu.
-- Sites live in global ModData, so they keep counting while their chunk is unloaded.
local Doors = require "TraditionalPreservationCore/Doors"
local Tiles = require "TraditionalPreservationSalt/Tiles"

TraditionalPreservationSalt = TraditionalPreservationSalt or {}
local S = TraditionalPreservationSalt

S.MOD_DATA_KEY = "TraditionalPreservationSalt"
S.LICK_TILE_KEY = "TraditionalPreservationSaltSite"
S.SPRITE_PREFIX = Tiles.PREFIX
-- One sprite per side mask, in mask order, from the Tiles.lua that tools/build_tileset.py writes.
S.PATCH_SPRITES = Tiles.PATCH
S.WORKED_SPRITES = Tiles.WORKED
S.SPRING_SPRITES = Tiles.SPRING
S.SPRING_DRY_SPRITES = Tiles.SPRING_DRY

S.SACK_ITEM = "TraditionalPreservationSalt.SalineSoilSack"
S.SALT_ITEM = "TraditionalPreservationSalt.LooseSalt"
S.BAG_ITEM = "TraditionalPreservationSalt.BagOfSalt"
S.MAP_ITEM = "TraditionalPreservationSalt.SaltLickMap"
S.EMPTY_BUCKET = "Base.BucketEmpty"

S.MAX_UNITS = 5  -- per tile
S.REGEN_HOURS = 7 * 24  -- each tile gets one unit back per week
S.MIN_PATCH_TILES = 3
S.MAX_PATCH_TILES = 7
S.HARVEST_MINUTES = 3

-- A lick is soil tiles and brine springs, each kind all in one piece. 3-4 tiles have 1 soil, 5-7 have 2.
S.SOIL = "soil"
S.SPRING = "spring"
S.SPRING_LITRES = 30  -- three buckets
S.SPRING_REFILL_LITRES = 10  -- a bucket a day at the default regrowth, scaled with it
S.SPRING_BRINE_SHARE = 0.1  -- 1 L of Brine in a 10 L bucket, the rest tainted water
S.FILL_MINUTES = 1
S.SPRING_DRY_LITRES = 1  -- a spring with less can't be drawn from, and shows dry

-- A Salt Lick Map rings the area of the lick nearest where it's first read.
S.MAP_ID = "TraditionalPreservationSaltLickMap"  -- the item's Map, and its LootMaps.Init function
S.MAP_RING_RADIUS = 60  -- 120 tiles across
S.MAP_RING_SHIFT = 20  -- the ring's centre is up to this far off the lick, which stays inside it
S.MAP_VIEW_RADIUS = 300  -- how far around the ring the map shows, for roads and towns to find it by
S.MAP_REVEAL_RADIUS = 50  -- reading it reveals 100 by 100 tiles round the ring's centre on the world map, not the view

-- From tools/find_regions.py: woodland clear of buildings and roads. Saves track sites by position
-- in this list, so add new regions to the end and keep the order.
S.REGIONS = {
    { x1 = 12930, y1 = 7240, x2 = 13010, y2 = 7320 },
    { x1 = 6260, y1 = 8430, x2 = 6340, y2 = 8510 },
    { x1 = 4560, y1 = 11180, x2 = 4640, y2 = 11260 },
    { x1 = 4240, y1 = 12920, x2 = 4320, y2 = 13000 },
    { x1 = 7500, y1 = 14980, x2 = 7580, y2 = 15060 },
    { x1 = 3480, y1 = 7460, x2 = 3560, y2 = 7540 },
    { x1 = 3470, y1 = 9140, x2 = 3550, y2 = 9220 },
    { x1 = 14450, y1 = 2060, x2 = 14530, y2 = 2140 },
    { x1 = 820, y1 = 5130, x2 = 900, y2 = 5210 },  -- Brandenburg
    { x1 = 6550, y1 = 6500, x2 = 6630, y2 = 6580 },  -- Riverside
    { x1 = 12170, y1 = 5930, x2 = 12250, y2 = 6010 },  -- Valley Station
    { x1 = 10370, y1 = 11290, x2 = 10450, y2 = 11370 },  -- away from water: Muldraugh, March Ridge
    { x1 = 490, y1 = 8210, x2 = 570, y2 = 8290 },  -- away from water: Ekron
    { x1 = 8570, y1 = 10200, x2 = 8650, y2 = 10280 },  -- away from water: Rosewood
    { x1 = 2180, y1 = 12660, x2 = 2260, y2 = 12740 },  -- away from water: Irvington
}

-- Reads the sandbox's regrowth time.
function S.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationSalt
    if options and options.RegrowthDays then S.REGEN_HOURS = options.RegrowthDays * 24 end
end

local LCG_MULTIPLIER = 16807
local LCG_MODULUS = 2147483647

-- Stays inside the 2^53 a Lua double holds exactly, and Kahlua has no bit operators.
function S.nextRoll(roll)
    return (roll * LCG_MULTIPLIER) % LCG_MODULUS
end

local nextRoll = S.nextRoll

-- The first roll from the world seed, a region and an attempt number, never 0 (the generator would stay
-- there). The first few draws are thrown away, as close seeds start out close.
function S.firstRoll(seed, regionIndex, attempt)
    local roll = (seed + regionIndex * 7919 + attempt * 104729) % LCG_MODULUS
    if roll == 0 then roll = 1 end
    for _ = 1, 4 do roll = nextRoll(roll) end
    return roll
end

-- The same seed, region and attempt always give the same square.
function S.pickTarget(seed, regionIndex, attempt)
    local region = S.REGIONS[regionIndex]
    local roll = S.firstRoll(seed, regionIndex, attempt)
    local x = region.x1 + roll % (region.x2 - region.x1 + 1)
    roll = nextRoll(roll)
    local y = region.y1 + roll % (region.y2 - region.y1 + 1)
    return x, y
end

-- How many tiles the region's patch has, the same every time for one world.
function S.patchSize(seed, regionIndex)
    local smallest, largest = S.MIN_PATCH_TILES, S.MAX_PATCH_TILES
    return smallest + S.firstRoll(seed, regionIndex, 0) % (largest - smallest + 1)
end

-- A site not yet on the map: placeSite (World) puts it near its target once that area is loaded.
function S.newSite(seed, regionIndex)
    local x, y = S.pickTarget(seed, regionIndex, 0)
    return {
        region = regionIndex,
        attempt = 0,
        targetX = x,
        targetY = y,
        placed = false,
    }
end

-- A tile of a patch, full. Soil until splitTiles says otherwise.
function S.newTile(x, y, now)
    return { x = x, y = y, units = S.MAX_UNITS, lastRegen = now }
end

function S.isSpring(tile)
    return tile.source == S.SPRING
end

function S.soilCount(size)
    return size <= 4 and 1 or 2
end

local function isNeighbour(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y) == 1
end

-- Whether every spring (a tile not in soil) touches another spring.
local function noSpringAlone(tiles, soil)
    for a, tile in ipairs(tiles) do
        if not soil[a] then
            local touches = false
            for b, other in ipairs(tiles) do
                if b ~= a and not soil[b] and isNeighbour(tile, other) then
                    touches = true
                    break
                end
            end
            if not touches then return false end
        end
    end
    return true
end

-- Every way to pick count soil tiles (1, or 2 that touch) where no spring is left alone.
local function soilChoices(tiles, count)
    local choices = {}
    for a = 1, #tiles do
        if count == 1 then
            local soil = { [a] = true }
            if noSpringAlone(tiles, soil) then table.insert(choices, soil) end
        else
            for b = a + 1, #tiles do
                local soil = { [a] = true, [b] = true }
                if isNeighbour(tiles[a], tiles[b]) and noSpringAlone(tiles, soil) then
                    table.insert(choices, soil)
                end
            end
        end
    end
    return choices
end

-- Makes each tile of a placed site soil or spring, the same every time for one world. Every tile touches one of its
-- own kind, so the lick never reads as a checkerboard. A plus sign of 5 can't have 2 soil tiles
-- that way (each arm touches only the middle), so it gets 1, an arm. Springs start full.
function S.splitTiles(seed, site, now)
    local tiles = site.tiles
    local count = math.min(S.soilCount(#tiles), #tiles)
    local choices = soilChoices(tiles, count)
    if #choices == 0 then choices = soilChoices(tiles, 1) end
    if #choices == 0 then choices = { { [1] = true } } end  -- can't happen for a lick in one piece of 3 or more
    local chosen = choices[S.firstRoll(seed, site.region, 1) % #choices + 1]
    for index, tile in ipairs(tiles) do
        if chosen[index] then
            tile.source = S.SOIL
        else
            tile.source = S.SPRING
            tile.units = nil
            tile.litres = S.SPRING_LITRES
            tile.lastRegen = now
        end
    end
end

local SIDES = { { 0, -1, 1 }, { 1, 0, 2 }, { 0, 1, 4 }, { -1, 0, 8 } }

-- Adds up the sides of a tile that touch another tile of the site of the same kind: north 1, east 2, south 4, west 8.
-- Soil and springs each have their own outline, so joined springs make one pool.
function S.edgeMask(site, tile)
    local mask = 0
    for _, side in ipairs(SIDES) do
        for _, other in ipairs(site.tiles) do
            if other.x == tile.x + side[1] and other.y == tile.y + side[2] and S.isSpring(other) == S.isSpring(tile) then
                mask = mask + side[3]
                break
            end
        end
    end
    return mask
end

-- The outline comes from the tile's neighbours, so a tile keeps it when it is worked out.
function S.spriteFor(site, tile)
    local sprites
    if S.isSpring(tile) then
        sprites = tile.litres >= S.SPRING_DRY_LITRES and S.SPRING_SPRITES or S.SPRING_DRY_SPRITES
    else
        sprites = tile.units > 0 and S.PATCH_SPRITES or S.WORKED_SPRITES
    end
    return S.SPRITE_PREFIX .. sprites[S.edgeMask(site, tile) + 1]
end

-- Litres a spring gains an hour: a bucket a day at the default 7-day regrowth, slower or faster with it.
function S.springRate()
    return S.SPRING_REFILL_LITRES * 7 / S.REGEN_HOURS
end

-- A spring fills back steadily to its cap. Returns its litres.
local function springCatchUp(tile, now)
    tile.litres = math.min(S.SPRING_LITRES, tile.litres + (now - tile.lastRegen) * S.springRate())
    tile.lastRegen = now
    return tile.litres
end

-- Applies every whole regrowth period since lastRegen, keeping any part period for next time.
-- A full tile grows nothing, so its clock only starts once it has been dug. A spring gives back litres instead.
function S.catchUp(tile, now)
    if S.isSpring(tile) then return springCatchUp(tile, now) end
    local maxUnits = S.MAX_UNITS
    if tile.units < maxUnits then
        local gained = math.floor((now - tile.lastRegen) / S.REGEN_HOURS)
        if gained > 0 then
            tile.units = math.min(maxUnits, tile.units + gained)
            tile.lastRegen = tile.lastRegen + gained * S.REGEN_HOURS
        end
    end
    if tile.units >= maxUnits then
        tile.lastRegen = now
    end
    return tile.units
end

-- Digs one unit of salty soil out of a tile, after its regrowth. False when it is worked out.
function S.takeUnit(tile, now)
    if S.isSpring(tile) or S.catchUp(tile, now) <= 0 then return false end
    tile.units = tile.units - 1
    return true
end

-- Draws up to litres from a spring after its refill. Returns the litres taken, 0 when it is dry.
function S.takeBrine(tile, now, litres)
    local taken = math.min(litres, S.catchUp(tile, now))
    tile.litres = tile.litres - taken
    return taken
end

-- Whether a spring is too low to draw from, after its refill.
function S.isDry(tile, now)
    return S.catchUp(tile, now) < S.SPRING_DRY_LITRES
end

-- Leaching is wet, muddy work done in the open, so the vat can only be built outdoors; and, as every TP station, not
-- in front of a door (TP Core's Doors).
function S.isOutdoors(params)
    local name = params.tileInfo and params.tileInfo:getSpriteName()
    return params.square:isOutside() and Doors.fits(params.square, name)
end

-- Every site and tile lives in this global ModData table.
function S.saltModData()
    return ModData.getOrCreate(S.MOD_DATA_KEY)
end

-- The site and its patch tile on this square, or nil.
function S.siteAt(x, y)
    local saltModData = S.saltModData()
    if not saltModData.sites then return nil end
    for _, site in ipairs(saltModData.sites) do
        for _, tile in ipairs(site.tiles or {}) do
            if tile.x == x and tile.y == y then
                return site, tile
            end
        end
    end
    return nil
end

-- The patch tile on this square, or nil.
function S.getTileAt(x, y)
    local _, tile = S.siteAt(x, y)
    return tile
end

-- Where a site is, or where it will be looked for while it isn't placed yet.
function S.position(site)
    if site.placed then return site.x, site.y end
    return site.targetX, site.targetY
end

-- The lick nearest x, y by its number in the site list, placed or not.
function S.nearestSite(x, y)
    local best, bestDistance
    for index, site in ipairs(S.saltModData().sites or {}) do
        local sx, sy = S.position(site)
        local distance = (sx - x) ^ 2 + (sy - y) ^ 2
        if not bestDistance or distance < bestDistance then best, bestDistance = index, distance end
    end
    return best
end

-- Gives a Salt Lick Map the lick nearest x, y and a shift of up to S.MAP_RING_SHIFT, so the lick is inside the
-- ring but not at its middle. Kept on the map: a map already given one keeps it.
function S.pickMapLick(mapData, x, y)
    if mapData.lickSite then return end
    mapData.lickSite = S.nearestSite(x, y)
    if not mapData.lickSite then return end
    local angle = ZombRand(360) * math.pi / 180
    local shift = ZombRand(S.MAP_RING_SHIFT + 1)
    mapData.shiftX = math.floor(math.cos(angle) * shift + 0.5)
    mapData.shiftY = math.floor(math.sin(angle) * shift + 0.5)
end

-- The centre of a Salt Lick Map's ring. A map gets its lick where it is found (TraditionalPreservationSaltLoot);
-- one without a spot (a vehicle's, or spawned) gets it at x, y, where it is first read. The ring follows the lick if
-- it was placed away from its target since. Nil before the licks exist.
function S.mapRing(mapData, x, y)
    S.pickMapLick(mapData, x, y)
    local site = (S.saltModData().sites or {})[mapData.lickSite or 0]
    if not site then return nil end
    local sx, sy = S.position(site)
    return sx + mapData.shiftX, sy + mapData.shiftY
end

-- The charge, brine and crust recipes' OnCreate are in TraditionalPreservationSaltBrine.
