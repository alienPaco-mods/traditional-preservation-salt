-- Traditional Preservation (Salt): constants and the deposit bookkeeping shared by the world and the menu.
-- Sites live in global ModData, so they keep counting while their chunk is unloaded.
local Weather = require "TraditionalPreservationCore/Weather"
local Container = require "TraditionalPreservationCore/Container"
local Tiles = require "TraditionalPreservationSalt/Tiles"

TraditionalPreservationSalt = TraditionalPreservationSalt or {}
local S = TraditionalPreservationSalt

S.MOD_DATA_KEY = "TraditionalPreservationSalt"
S.OBJECT_KEY = "TraditionalPreservationSaltSite"
S.SPRITE_PREFIX = Tiles.PREFIX
-- One sprite per side mask, in mask order, from the Tiles.lua that tools/build_tileset.py writes.
S.PATCH_SPRITES = Tiles.PATCH
S.WORKED_SPRITES = Tiles.WORKED

S.MAX_UNITS = 5  -- per tile
S.REGEN_HOURS = 7 * 24  -- each tile gets one unit back per week
S.MIN_PATCH_TILES = 3
S.MAX_PATCH_TILES = 7
S.HARVEST_MINUTES = 3

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
function S.nextRandom(state)
    return (state * LCG_MULTIPLIER) % LCG_MODULUS
end

local nextRandom = S.nextRandom

-- A random state from the world seed, a region and an attempt number, never 0 (the generator would stay
-- there). The first few draws are thrown away, as close seeds start out close.
function S.seedState(seed, regionIndex, attempt)
    local state = (seed + regionIndex * 7919 + attempt * 104729) % LCG_MODULUS
    if state == 0 then state = 1 end
    for _ = 1, 4 do state = nextRandom(state) end
    return state
end

-- The same seed, region and attempt always give the same square.
function S.pickTarget(seed, regionIndex, attempt)
    local region = S.REGIONS[regionIndex]
    local state = S.seedState(seed, regionIndex, attempt)
    local x = region.x1 + state % (region.x2 - region.x1 + 1)
    state = nextRandom(state)
    local y = region.y1 + state % (region.y2 - region.y1 + 1)
    return x, y
end

-- How many tiles the region's patch has, the same every time for one world.
function S.patchSize(seed, regionIndex)
    local smallest, largest = S.MIN_PATCH_TILES, S.MAX_PATCH_TILES
    return smallest + S.seedState(seed, regionIndex, 0) % (largest - smallest + 1)
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

-- A tile of a patch, full.
function S.newTile(x, y, now)
    return { x = x, y = y, units = S.MAX_UNITS, lastRegen = now }
end

local SIDES = { { 0, -1, 1 }, { 1, 0, 2 }, { 0, 1, 4 }, { -1, 0, 8 } }

-- Adds up the sides of a tile that touch another tile of the site: north 1, east 2, south 4, west 8.
function S.edgeMask(site, tile)
    local mask = 0
    for _, side in ipairs(SIDES) do
        for _, other in ipairs(site.tiles) do
            if other.x == tile.x + side[1] and other.y == tile.y + side[2] then
                mask = mask + side[3]
                break
            end
        end
    end
    return mask
end

-- The outline comes from the tile's neighbours, so a tile keeps it when it is worked out.
function S.spriteFor(site, tile)
    local sprites = tile.units > 0 and S.PATCH_SPRITES or S.WORKED_SPRITES
    return S.SPRITE_PREFIX .. sprites[S.edgeMask(site, tile) + 1]
end

-- Applies every whole regrowth period since lastRegen, keeping any part period for next time.
-- A full tile grows nothing, so its clock only starts once it has been dug.
function S.catchUp(tile, now)
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
    if S.catchUp(tile, now) <= 0 then return false end
    tile.units = tile.units - 1
    return true
end

-- Leaching is wet, muddy work done in the open, so the vat can only be built outdoors.
function S.isOutdoors(params)
    return params.square:isOutside()
end

-- Every site and tile lives in this global ModData table.
function S.getData()
    return ModData.getOrCreate(S.MOD_DATA_KEY)
end

-- The patch tile on this square, or nil.
function S.getTileAt(x, y)
    local data = S.getData()
    if not data.sites then return nil end
    for _, site in ipairs(data.sites) do
        for _, tile in ipairs(site.tiles or {}) do
            if tile.x == x and tile.y == y then
                return tile
            end
        end
    end
    return nil
end

-- The vat runs on the plain game clock, timed from here.
function S.onLeachStart(craftRecipeData)
    Weather.startClock(craftRecipeData, "leachStartHour", getGameTime():getWorldAgeHours())
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count
-- with the game clock.
function S.onLeachUpdate(craftRecipeData)
    Weather.showClock(craftRecipeData, "leachStartHour", getGameTime():getWorldAgeHours())
end

-- The bucket becomes the charge, the brine and the crust in turn. Its kind (plain or forged) is noted on each,
-- so scraping gives back the bucket that went in. The boil carries the note itself (see the core's Container).
function S.onChargePrepared(craftRecipeData)
    Container.note(craftRecipeData, "TraditionalPreservationSalt.LeachingCharge")
end

function S.onBrineLeached(craftRecipeData)
    Container.pass(craftRecipeData)
end

function S.onCrustScraped(craftRecipeData, character)
    Container.giveBack(craftRecipeData, character, "Base.BucketEmpty")
end
