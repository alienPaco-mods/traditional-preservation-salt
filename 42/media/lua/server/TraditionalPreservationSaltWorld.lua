-- Traditional Preservation (Salt): places each patch of deposit tiles once, the first time its ground is loaded.
-- Global ModData is the record of a deposit. The world object is only what the player sees,
-- so a lost object is put back on the same square and the site never moves or doubles up.
require "TraditionalPreservationSalt"
local S = TraditionalPreservationSalt

local SEARCH_RADIUS = 12
local PATCH_REACH = 4  -- how far a patch can spread from its first tile
local PATCH_GROWTH_TRIES = 80
local MAX_ATTEMPTS = 8
local SEED_LIMIT = 2147483646

local NATURAL_SPRITE_PREFIXES = { "blends_", "e_newgrass", "d_", "vegetation_", "traditionalpreservationsalt_" }
local NEIGHBOURS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }  -- sides only, so tiles always share a full edge

local function isNaturalSprite(name)
    if not name then return false end
    for _, prefix in ipairs(NATURAL_SPRITE_PREFIXES) do
        if string.sub(name, 1, #prefix) == prefix then return true end
    end
    return false
end

local function isSuitable(square)
    if square:getBuilding() or square:getRoom() or not square:isOutside() then return false end
    if square:getProperties():has(IsoFlagType.water) then return false end
    if square:HasTree() or square:getVehicleContainer() or not square:isFree(false) then return false end

    local floor = square:getFloor()
    if not floor or not floor:getSprite() then return false end
    if string.sub(floor:getSprite():getName() or "", 1, 7) ~= "blends_" then return false end

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local sprite = objects:get(i):getSprite()
        if not sprite or not isNaturalSprite(sprite:getName()) then return false end
    end
    return true
end

-- Waits for the whole search area, so the result can't depend on the way the player arrived.
local function isAreaLoaded(cell, x, y)
    local r = SEARCH_RADIUS + PATCH_REACH
    return cell:getGridSquare(x - r, y - r, 0) and cell:getGridSquare(x + r, y - r, 0)
        and cell:getGridSquare(x - r, y + r, 0) and cell:getGridSquare(x + r, y + r, 0)
end

-- Walks outward in rings from the target and returns the nearest suitable square.
local function findSquare(cell, x, y)
    for r = 0, SEARCH_RADIUS do
        for dx = -r, r do
            for dy = -r, r do
                if math.max(math.abs(dx), math.abs(dy)) == r then
                    local square = cell:getGridSquare(x + dx, y + dy, 0)
                    if square and isSuitable(square) then return square end
                end
            end
        end
    end
    return nil
end

local function findMarker(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object:getModData()[S.OBJECT_KEY] then return object end
    end
    return nil
end

local function addMarker(square, site, tile)
    local object = IsoObject.new(getCell(), square, getSprite(S.spriteFor(site, tile)))
    object:getModData()[S.OBJECT_KEY] = site.region
    square:AddTileObject(object)
end

-- Puts back a lost marker and keeps the look in step with the diggings left.
local function refreshMarker(square, site, tile)
    local marker = findMarker(square)
    if not marker then
        addMarker(square, site, tile)
        return
    end
    local name = S.spriteFor(site, tile)
    if marker:getSprite():getName() ~= name then
        marker:setSprite(getSprite(name))
    end
end

-- Spreads out from the first square one random neighbour at a time, for an uneven blob.
local function growPatch(cell, seed, site, first)
    local size = S.patchSize(seed, site.region)
    local nextRandom = S.nextRandom
    local state = S.seedState(seed, site.region, site.attempt)
    local squares = { first }
    local taken = { [first:getX() .. "," .. first:getY()] = true }

    for _ = 1, PATCH_GROWTH_TRIES do
        if #squares >= size then break end
        state = nextRandom(state)
        local from = squares[state % #squares + 1]
        state = nextRandom(state)
        local offset = NEIGHBOURS[state % #NEIGHBOURS + 1]
        local x, y = from:getX() + offset[1], from:getY() + offset[2]
        local key = x .. "," .. y
        local inReach = math.max(math.abs(x - first:getX()), math.abs(y - first:getY())) <= PATCH_REACH
        local square = inReach and not taken[key] and cell:getGridSquare(x, y, 0)
        if square and isSuitable(square) then
            taken[key] = true
            table.insert(squares, square)
        end
    end
    return squares
end

local function placeSite(cell, data, site)
    if not isAreaLoaded(cell, site.targetX, site.targetY) then return end

    local first = findSquare(cell, site.targetX, site.targetY)
    local squares = first and growPatch(cell, data.seed, site, first)
    -- A cramped spot gets another try, but the last attempt takes whatever it finds.
    -- With nowhere usable at all it keeps moving, or the site would never be placed.
    if squares and (#squares >= S.MIN_PATCH_TILES or site.attempt >= MAX_ATTEMPTS) then
        local now = getGameTime():getWorldAgeHours()
        site.placed = true
        site.x = first:getX()
        site.y = first:getY()
        site.tiles = {}
        for _, square in ipairs(squares) do
            table.insert(site.tiles, S.newTile(square:getX(), square:getY(), now))
        end
        S.splitTiles(data.seed, site, now)
        -- Every tile first, because a marker's sprite depends on its neighbours.
        for index, square in ipairs(squares) do
            refreshMarker(square, site, site.tiles[index])
        end
        if getDebug() then
            print("[TraditionalPreservationSalt] placed site " .. site.region .. " at " .. site.x .. "," .. site.y .. " with " .. #squares .. " tiles")
        end
        return
    end

    if site.attempt < MAX_ATTEMPTS or not first then
        site.attempt = site.attempt + 1
        site.targetX, site.targetY = S.pickTarget(data.seed, site.region, site.attempt)
    end
end

local function checkSites()
    local data = S.getData()
    if not data.sites then return end

    local cell = getCell()
    local now = getGameTime():getWorldAgeHours()
    for _, site in ipairs(data.sites) do
        if site.placed then
            -- A lick placed before the springs keeps its tiles and gets its kinds here.
            if not S.isSplit(site) then S.splitTiles(data.seed, site, now) end
            for _, tile in ipairs(site.tiles) do
                local square = cell:getGridSquare(tile.x, tile.y, 0)
                if square then
                    S.catchUp(tile, now)
                    refreshMarker(square, site, tile)
                end
            end
        else
            placeSite(cell, data, site)
        end
    end
end

local function initSites()
    S.applySandbox()
    local data = S.getData()
    if not data.seed then
        data.seed = ZombRand(1, SEED_LIMIT)
    end
    if not data.sites then
        data.sites = {}
    end
    -- Adds any region not yet known, so new regions reach existing saves.
    for index = #data.sites + 1, #S.REGIONS do
        data.sites[index] = S.newSite(data.seed, index)
    end
    if getDebug() then
        for _, site in ipairs(data.sites) do
            print("[TraditionalPreservationSalt] site " .. site.region .. " target "
                .. site.targetX .. "," .. site.targetY .. " placed=" .. tostring(site.placed))
        end
    end
end

Events.OnInitGlobalModData.Add(initSites)
Events.EveryOneMinute.Add(checkSites)
