-- Checks patch placement against a fake world. Run from the mod folder: luajit tests/test_patches.lua
local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
local store = {}
ModData = { getOrCreate = function() return store end }
package.path = "42/media/lua/shared/?.lua;" .. package.path

local hooks = {}
Events = {
    OnInitGlobalModData = { Add = function(f) hooks.init = f end },
    EveryOneMinute = { Add = function(f) hooks.minute = f end },
}
IsoFlagType = { water = "water" }
function getDebug() return false end
local worldHours = 100
function getGameTime() return { getWorldAgeHours = function() return worldHours end } end
function ZombRand(a) return a + 41 end
function getSprite(name) return name end

local function newSprite(name) return { getName = function() return name end } end

local function newList(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end, items = items }
end

local function newObject(spriteName)
    local modData = {}
    return {
        getSprite = function() return newSprite(spriteName) end,
        setSprite = function(_, name) spriteName = name end,
        getModData = function() return modData end,
    }
end

local squares, blocked = {}, function() return false end

local function getSquare(x, y)
    local key = x .. "," .. y
    if not squares[key] then
        local square = { objects = newList({ newObject("blends_natural_01_1") }) }
        local floor = square.objects.items[1]
        function square:getX() return x end
        function square:getY() return y end
        function square:getBuilding() end
        function square:getRoom() end
        function square:isOutside() return true end
        function square:getProperties() return { has = function() return false end } end
        function square:HasTree() return blocked(x, y) end
        function square:getVehicleContainer() end
        function square:isFree() return true end
        function square:getFloor() return floor end
        function square:getObjects() return self.objects end
        function square:AddTileObject(object) table.insert(self.objects.items, object) end
        squares[key] = square
    end
    return squares[key]
end

local cell = { getGridSquare = function(_, x, y) return getSquare(x, y) end }
function getCell() return cell end
IsoObject = { new = function(_, _, sprite) return newObject(sprite) end }

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/server/TraditionalPreservationSaltWorld.lua")
local N = TraditionalPreservationSalt

local check = H.check

local function markers(x, y)
    local count = 0
    for _, object in ipairs(getSquare(x, y).objects.items) do
        if object:getModData()[N.OBJECT_KEY] then count = count + 1 end
    end
    return count
end

local function markerSprite(tile)
    for _, object in ipairs(getSquare(tile.x, tile.y).objects.items) do
        if object:getModData()[N.OBJECT_KEY] then return object:getSprite():getName() end
    end
end

hooks.init()
hooks.minute()
for _, site in ipairs(store.sites) do
    check("site " .. site.region .. " is placed at its planned size", site.placed and #site.tiles == N.patchSize(store.seed, site.region))
    local touching = true
    for _, tile in ipairs(site.tiles) do
        check("a tile starts full, with one marker", tile.units == N.MAX_UNITS and markers(tile.x, tile.y) == 1)
        check("a tile is found by its square", N.getTileAt(tile.x, tile.y) == tile)
        local near = #site.tiles == 1
        for _, other in ipairs(site.tiles) do
            near = near or math.abs(tile.x - other.x) + math.abs(tile.y - other.y) == 1
        end
        touching = touching and near
    end
    check("every tile shares a full edge with another", touching)
    for _, tile in ipairs(site.tiles) do
        check("a tile's sprite shows its neighbours", markerSprite(tile) == N.spriteFor(site, tile))
    end
end

hooks.minute()
local first = store.sites[1].tiles[1]
check("another minute adds no markers", markers(first.x, first.y) == 1)

local function shapeOf(tile, sprites)
    for index, number in ipairs(sprites) do
        if markerSprite(tile) == N.SPRITE_PREFIX .. number then return index end
    end
end

local fresh = shapeOf(first, N.PATCH_SPRITES)
check("a full tile shows a fresh sprite", fresh ~= nil)

first.units = 1
hooks.minute()
check("a partly dug tile still looks fresh", shapeOf(first, N.PATCH_SPRITES) == fresh)

first.units, first.lastRegen = 0, worldHours
hooks.minute()
check("a worked out tile keeps its shape in the worked colour", shapeOf(first, N.WORKED_SPRITES) == fresh)

worldHours = worldHours + N.REGEN_HOURS
hooks.minute()
check("regrowth brings the fresh sprite back", first.units == 1 and shapeOf(first, N.PATCH_SPRITES) == fresh)

local cross = { tiles = { { x = 5, y = 5 }, { x = 5, y = 4 }, { x = 6, y = 5 }, { x = 5, y = 6 }, { x = 4, y = 5 }, { x = 6, y = 6 } } }
check("a tile with all four neighbours has mask 15", N.edgeMask(cross, cross.tiles[1]) == 15)
check("a tile with only a north neighbour has mask 4 from below", N.edgeMask(cross, cross.tiles[2]) == 4)
check("a corner touch does not count", N.edgeMask({ tiles = { { x = 0, y = 0 }, { x = 1, y = 1 } } }, { x = 0, y = 0 }) == 0)
check("each mask has a sprite", #N.PATCH_SPRITES == 16 and #N.WORKED_SPRITES == 16)

-- A marker from before tiles had shapes changes to its proper sprite.
local second = store.sites[1].tiles[2]
for _, object in ipairs(getSquare(second.x, second.y).objects.items) do
    if object:getModData()[N.OBJECT_KEY] then object:setSprite(N.SPRITE_PREFIX .. "1") end
end
hooks.minute()
check("an old marker picks up its shape", markerSprite(second) == N.spriteFor(store.sites[1], second))

-- Nowhere to spread: only the target square is clear, on every attempt.
store.sites = nil
squares = {}
blocked = function(x, y) return (x + y) % 2 == 0 or x % 2 == 0 end
hooks.init()
for _ = 1, 12 do hooks.minute() end
for _, site in ipairs(store.sites) do
    check("a cramped site still ends up placed", site.placed and #site.tiles >= 1)
end
-- A save from when there were fewer regions gains the new ones and keeps its own.
store.sites = nil
squares = {}
hooks.init()
hooks.minute()
local kept = store.sites[8]
local keptX, keptY = kept.x, kept.y
for index = #store.sites, 9, -1 do store.sites[index] = nil end
hooks.init()
check("new regions reach an existing save", #store.sites == #N.REGIONS)
check("old sites keep their place", store.sites[8] == kept and kept.x == keptX and kept.y == keptY)

-- Nothing usable on any attempt: it must keep trying past the limit, then place when it can.
store.sites = nil
squares = {}
blocked = function() return true end
hooks.init()
for _ = 1, 12 do hooks.minute() end
local stuck = store.sites[1]
check("a site with nowhere to go stays unplaced", not stuck.placed)
check("it keeps trying past the last attempt", stuck.attempt > 8)
blocked = function() return false end
hooks.minute()
check("it is placed once there is room", stuck.placed and #stuck.tiles >= 1)

-- A site that had run out of attempts in an older version.
store.sites = nil
squares = {}
hooks.init()
store.sites[1].attempt = 8
hooks.minute()
check("a site saved at the last attempt gets placed", store.sites[1].placed)
H.done()
