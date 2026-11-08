-- Traditional Preservation (Salt): constants and the deposit bookkeeping shared by the world and the menu.
-- Sites live in global ModData, so they keep counting while their chunk is unloaded.
TraditionalPreservationSalt = TraditionalPreservationSalt or {}

TraditionalPreservationSalt.MOD_DATA_KEY = "TraditionalPreservationSalt"
TraditionalPreservationSalt.OBJECT_KEY = "TraditionalPreservationSaltSite"
TraditionalPreservationSalt.SPRITE_PREFIX = "traditionalpreservationsalt_01_"
-- One sprite per side mask, in mask order. Must match tools/build_tileset.py.
TraditionalPreservationSalt.PATCH_SPRITES = { 1, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }
TraditionalPreservationSalt.WORKED_SPRITES = { 6, 7, 8, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37 }

TraditionalPreservationSalt.MAX_UNITS = 5  -- per tile
TraditionalPreservationSalt.REGEN_HOURS = 7 * 24  -- each tile gets one unit back per week
TraditionalPreservationSalt.MIN_PATCH_TILES = 3
TraditionalPreservationSalt.MAX_PATCH_TILES = 7
TraditionalPreservationSalt.HARVEST_MINUTES = 3

-- From tools/find_regions.py: woodland clear of buildings and roads. Saves track sites by position
-- in this list, so add new regions to the end and keep the order.
TraditionalPreservationSalt.REGIONS = {
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

function TraditionalPreservationSalt.applySandbox()
    local options = SandboxVars and SandboxVars.TraditionalPreservationSalt
    if options and options.RegrowthDays then TraditionalPreservationSalt.REGEN_HOURS = options.RegrowthDays * 24 end
end

local LCG_MULTIPLIER = 16807
local LCG_MODULUS = 2147483647

-- Stays inside the 2^53 a Lua double holds exactly, and Kahlua has no bit operators.
function TraditionalPreservationSalt.nextRandom(state)
    return (state * LCG_MULTIPLIER) % LCG_MODULUS
end

local nextRandom = TraditionalPreservationSalt.nextRandom

function TraditionalPreservationSalt.seedState(seed, regionIndex, attempt)
    local state = (seed + regionIndex * 7919 + attempt * 104729) % LCG_MODULUS
    if state == 0 then state = 1 end
    for _ = 1, 4 do state = nextRandom(state) end
    return state
end

-- The same seed, region and attempt always give the same square.
function TraditionalPreservationSalt.pickTarget(seed, regionIndex, attempt)
    local region = TraditionalPreservationSalt.REGIONS[regionIndex]
    local state = TraditionalPreservationSalt.seedState(seed, regionIndex, attempt)
    local x = region.x1 + state % (region.x2 - region.x1 + 1)
    state = nextRandom(state)
    local y = region.y1 + state % (region.y2 - region.y1 + 1)
    return x, y
end

function TraditionalPreservationSalt.patchSize(seed, regionIndex)
    local smallest, largest = TraditionalPreservationSalt.MIN_PATCH_TILES, TraditionalPreservationSalt.MAX_PATCH_TILES
    return smallest + TraditionalPreservationSalt.seedState(seed, regionIndex, 0) % (largest - smallest + 1)
end

function TraditionalPreservationSalt.newSite(seed, regionIndex)
    local x, y = TraditionalPreservationSalt.pickTarget(seed, regionIndex, 0)
    return {
        region = regionIndex,
        attempt = 0,
        targetX = x,
        targetY = y,
        placed = false,
    }
end

function TraditionalPreservationSalt.newTile(x, y, now)
    return { x = x, y = y, units = TraditionalPreservationSalt.MAX_UNITS, lastRegen = now }
end

local SIDES = { { 0, -1, 1 }, { 1, 0, 2 }, { 0, 1, 4 }, { -1, 0, 8 } }

-- Adds up the sides of a tile that touch another tile of the site: north 1, east 2, south 4, west 8.
function TraditionalPreservationSalt.edgeMask(site, tile)
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
function TraditionalPreservationSalt.spriteFor(site, tile)
    local sprites = tile.units > 0 and TraditionalPreservationSalt.PATCH_SPRITES or TraditionalPreservationSalt.WORKED_SPRITES
    return TraditionalPreservationSalt.SPRITE_PREFIX .. sprites[TraditionalPreservationSalt.edgeMask(site, tile) + 1]
end

-- Applies every whole regrowth period since lastRegen, keeping any part period for next time.
-- A full tile grows nothing, so its clock only starts once it has been dug.
function TraditionalPreservationSalt.catchUp(tile, now)
    local maxUnits = TraditionalPreservationSalt.MAX_UNITS
    if tile.units < maxUnits then
        local gained = math.floor((now - tile.lastRegen) / TraditionalPreservationSalt.REGEN_HOURS)
        if gained > 0 then
            tile.units = math.min(maxUnits, tile.units + gained)
            tile.lastRegen = tile.lastRegen + gained * TraditionalPreservationSalt.REGEN_HOURS
        end
    end
    if tile.units >= maxUnits then
        tile.lastRegen = now
    end
    return tile.units
end

function TraditionalPreservationSalt.takeUnit(tile, now)
    if TraditionalPreservationSalt.catchUp(tile, now) <= 0 then return false end
    tile.units = tile.units - 1
    return true
end

-- Leaching is wet, muddy work done in the open, so the vat can only be built outdoors.
function TraditionalPreservationSalt.isOutdoors(params)
    return params.square:isOutside()
end

function TraditionalPreservationSalt.getData()
    return ModData.getOrCreate(TraditionalPreservationSalt.MOD_DATA_KEY)
end

function TraditionalPreservationSalt.getTileAt(x, y)
    local data = TraditionalPreservationSalt.getData()
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

local SECONDS_PER_HOUR = 3600

-- The engine pools recipe data without clearing its ModData, so every run must set this.
function TraditionalPreservationSalt.onLeachStart(craftRecipeData)
    craftRecipeData:getModData().leachStartHour = getGameTime():getWorldAgeHours()
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count
-- with the game clock. The start hour saves with the recipe.
function TraditionalPreservationSalt.onLeachUpdate(craftRecipeData)
    local startHour = craftRecipeData:getModData().leachStartHour
    if not startHour then return end

    local elapsed = (getGameTime():getWorldAgeHours() - startHour) * SECONDS_PER_HOUR
    craftRecipeData:setElapsedTime(math.min(elapsed, craftRecipeData:getRecipe():getTime()))
end
