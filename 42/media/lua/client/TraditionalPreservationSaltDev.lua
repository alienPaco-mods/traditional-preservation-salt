-- Traditional Preservation (Salt): commands for the debug Lua console, loaded only in debug mode.
-- Type TPS.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local S = TraditionalPreservationSalt
local Container = require "TraditionalPreservationCore/Container"
local Fire = require "TraditionalPreservationCore/Fire"
local Station = require "TraditionalPreservationCore/Station"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local SaltPanAttachment = require "TraditionalPreservationSalt/SaltPanAttachment"
TPS = {}

-- Towns near the regions that were placed for one, by position in S.REGIONS.
local NEAR = { [9] = "Brandenburg", [10] = "Riverside", [11] = "Valley Station", [12] = "Muldraugh / March Ridge",
    [13] = "Ekron", [14] = "Rosewood", [15] = "Irvington" }

local function say(text) print("[TPS] " .. text) end

local function now() return getGameTime():getWorldAgeHours() end

local function sites()
    local saltModData = S.saltModData()
    return saltModData.sites or {}
end

-- Diggings left and soil tiles, litres in the springs and spring tiles.
local function stock(site)
    local units, soil, litres, springs = 0, 0, 0, 0
    local hours = now()
    for _, tile in ipairs(site.tiles or {}) do
        if S.isSpring(tile) then
            litres, springs = litres + S.catchUp(tile, hours), springs + 1
        else
            units, soil = units + S.catchUp(tile, hours), soil + 1
        end
    end
    return units, soil, litres, springs
end

-- "2/5 diggings" or "18/30 L" for one tile.
local function tileStock(tile)
    if S.isSpring(tile) then return string.format("spring, %.1f/%d L", tile.litres, S.SPRING_LITRES) end
    return string.format("soil, %d/%d diggings", tile.units, S.MAX_UNITS)
end

local function playerSquare()
    local player = getPlayer()
    return math.floor(player:getX()), math.floor(player:getY())
end

-- The lick nearest the player, by its number, and how far it is; placedOnly leaves out those not placed yet.
local function nearestSite(placedOnly)
    local x, y = playerSquare()
    local best, bestDistance
    for index, site in ipairs(sites()) do
        if site.placed or not placedOnly then
            local sx, sy = S.position(site)
            local distance = math.sqrt((sx - x) ^ 2 + (sy - y) ^ 2)
            if not bestDistance or distance < bestDistance then best, bestDistance = index, distance end
        end
    end
    return best, bestDistance
end

local function pickSite(n)
    if n then return sites()[n] end
    local site = S.siteAt(playerSquare())
    if not site then say("Stand on a lick tile, or give a lick number.") end
    return site
end

function TPS.help()
    say("TPS.licks()         list every lick: placed or not, soil diggings and spring litres left, with no locations")
    say("TPS.licks(true)     the same, with coordinates, distance, region and nearby town")
    say("TPS.tp(n)           teleport to lick n (its first tile, or its target if it isn't placed yet)")
    say("TPS.nearest()       the nearest lick to you, with distance and direction")
    say("TPS.tile()          the lick tile you're standing on: diggings or litres left and the refill")
    say("TPS.tiles(n)        each tile of lick n (or the nearest): its ground object, sprite and what else is on the square")
    say("TPS.refill(n)       fill every tile of lick n, or the one you're on, to " .. S.MAX_UNITS .. " diggings, springs to " .. S.SPRING_LITRES .. " L")
    say("TPS.empty(n)        dig every soil tile of lick n, or the one you're on, out to 0 and draw its springs dry")
    say("TPS.regrow(hours)   wind every lick's regrowth clock forward by this many hours")
    say("TPS.seed()          this save's lick seed and regrowth setting")
    say("TPS.brine(litres, clean, total, forged) a bucket with litres of Brine (default 1, a spring's), the rest tainted water (clean: water); total litres for a part-used one (default 10); forged: a Forged Bucket")
    say("TPS.give(name, n)   spawn n of: sack (Sack of Saline Soil), salt (Evaporated Salt), bag (Bag of Salt), map (Salt Lick Map), bucket, forgedBucket (both empty), pan (Salt Pan). TPS.give() lists them")
    say("TPS.kit(kind)       what the salt pan takes: \"fit\" (the default: the Salt Pan, 2 clay and a mason's trowel, for Fit Salt Pan on a Stone Hearth; TPC.kit(\"stone\") builds one) or \"forge\" (Forge Salt Pan at a forge, Blacksmith 3, and the magazine that teaches it)")
    say("TPS.panInfo()       the nearest Stone Hearth with the salt pan: fire, litres, salt, heat, when it is dry")
    say("TPS.pan(l, brine, c) set its pan: l litres (0 empties it, salt too) of which brine litres are Brine, at c degrees (default 30 L, 3 L Brine: three spring buckets, 20 C); TPS.pan(0, 5) leaves a dry crust of 5 salt")
    say("TPS.buckets()       the Brine in every bucket, boiling bucket and crust in your main inventory")
    say("TPS.vat(hours)      the nearest Leaching Vat: each layer's salt, the liquid soaking, the tub; hours: let it drain that long now")
    say("Changes show on the ground within an in-game minute.")
end

-- Without showCoords it only says whether each lick is placed and how it's doing, so it can be shown
-- without giving away where the licks are.
function TPS.licks(showCoords)
    local x, y = playerSquare()
    local placed = 0
    for index, site in ipairs(sites()) do
        local line
        if site.placed then
            placed = placed + 1
            local units, soil, litres, springs = stock(site)
            line = string.format("#%-2d PLACED, %d soil tiles %d/%d diggings left, %d springs %.0f/%d L", index, soil,
                units, soil * S.MAX_UNITS, springs, litres, springs * S.SPRING_LITRES)
            if showCoords then
                line = line .. string.format(", at %d,%d (%d squares away)", site.x, site.y,
                    math.floor(math.sqrt((site.x - x) ^ 2 + (site.y - y) ^ 2)))
            end
        else
            line = string.format("#%-2d not placed yet, attempt %d. Places when its ground loads.", index, site.attempt)
            if showCoords then line = line .. string.format(" Target %d,%d.", site.targetX, site.targetY) end
        end
        if showCoords then
            local region = S.REGIONS[index]
            line = line .. string.format("  region %d,%d-%d,%d", region.x1, region.y1, region.x2, region.y2)
                .. (NEAR[index] and ("  near " .. NEAR[index]) or "")
        end
        say(line)
    end
    say(string.format("%d of %d licks placed.%s", placed, #sites(), showCoords and "" or " TPS.licks(true) adds where they are."))
end

function TPS.tp(n)
    local site = sites()[n]
    if not site then return say("No lick " .. tostring(n) .. ". There are " .. #sites() .. ".") end
    local x, y = S.position(site)
    getPlayer():teleportTo(x + 0.5, y + 0.5, 0)
    say(string.format("Teleported to lick #%d at %d,%d%s", n, x, y, site.placed and "" or " (its target: wait for it to place)"))
end

local DIRECTIONS = { "east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east" }

function TPS.nearest()
    local x, y = playerSquare()
    local best, bestDistance = nearestSite(false)
    if not best then return say("No licks recorded yet.") end
    local site = sites()[best]
    local sx, sy = S.position(site)
    -- Screen y grows southward, so this angle runs clockwise from east.
    local angle = math.atan2(sy - y, sx - x)
    local direction = DIRECTIONS[math.floor((angle / (2 * math.pi) * 8) + 0.5) % 8 + 1]
    say(string.format("Lick #%d, %d squares %s, at %d,%d%s. TPS.tp(%d) to go there.", best, math.floor(bestDistance),
        direction, sx, sy, site.placed and "" or " (not placed yet)", best))
end

function TPS.tile()
    local x, y = playerSquare()
    local site, tile = S.siteAt(x, y)
    if not tile then return say("You're not on a lick tile. TPS.nearest() finds one.") end
    S.catchUp(tile, now())
    if S.isSpring(tile) then
        return say(string.format("Lick #%d tile %d,%d: %s, refills %.1f L an hour", site.region, x, y, tileStock(tile),
            S.springRate()))
    end
    local nextIn = tile.units < S.MAX_UNITS and (tile.lastRegen + S.REGEN_HOURS - now()) or nil
    say(string.format("Lick #%d tile %d,%d: %d/%d diggings%s", site.region, x, y, tile.units, S.MAX_UNITS,
        nextIn and string.format(", next regrows in %.1f hours", nextIn) or ", full"))
end

-- full true fills every soil tile and spring, false empties them.
local function setAll(site, full)
    for _, tile in ipairs(site.tiles or {}) do
        if S.isSpring(tile) then
            tile.litres = full and S.SPRING_LITRES or 0
        else
            tile.units = full and S.MAX_UNITS or 0
        end
        tile.lastRegen = now()
    end
end

-- For each tile of lick n (or the nearest placed one): whether its ground object is there, its sprite,
-- and everything else on the square, in drawing order, to see what might cover it.
function TPS.tiles(n)
    local site = n and sites()[n] or sites()[nearestSite(true) or 0]
    if not site or not site.placed then return say("No placed lick to check.") end
    local cell = getCell()
    for index, tile in ipairs(site.tiles) do
        local square = cell:getGridSquare(tile.x, tile.y, 0)
        if not square then
            say(string.format("tile %d at %d,%d: not loaded", index, tile.x, tile.y))
        else
            local names, marker = {}, nil
            local objects = square:getObjects()
            for i = 0, objects:size() - 1 do
                local isoObject = objects:get(i)
                local name = isoObject:getSprite() and isoObject:getSprite():getName() or "?"
                if isoObject:getModData()[S.LICK_TILE_KEY] then
                    marker = name
                    name = "*LICK*"
                end
                table.insert(names, name)
            end
            say(string.format("tile %d at %d,%d: %s, %s. Objects in order: %s", index, tile.x, tile.y,
                marker and ("lick sprite " .. marker) or "NO LICK OBJECT", tileStock(tile), table.concat(names, ", ")))
        end
    end
end

function TPS.refill(n)
    local site = pickSite(n)
    if not site then return end
    if not site.placed then return say("Lick #" .. site.region .. " isn't placed yet.") end
    setAll(site, true)
    say("Lick #" .. site.region .. " refilled.")
end

function TPS.empty(n)
    local site = pickSite(n)
    if not site then return end
    if not site.placed then return say("Lick #" .. site.region .. " isn't placed yet.") end
    setAll(site, false)
    say("Lick #" .. site.region .. " dug out and drawn dry. TPS.regrow(" .. S.REGEN_HOURS .. ") brings back one digging per soil tile and "
        .. math.floor(S.springRate() * S.REGEN_HOURS) .. " L per spring.")
end

function TPS.regrow(hours)
    hours = hours or S.REGEN_HOURS
    for _, site in ipairs(sites()) do
        for _, tile in ipairs(site.tiles or {}) do tile.lastRegen = tile.lastRegen - hours end
    end
    say(string.format("Regrowth clocks wound forward %.0f hours (one digging per soil tile every %.0f, %.1f L an hour per spring).",
        hours, S.REGEN_HOURS, S.springRate()))
end

function TPS.seed()
    say(string.format("Seed %s. Regrowth every %.0f hours (%.1f days).", tostring(S.saltModData().seed), S.REGEN_HOURS, S.REGEN_HOURS / 24))
end

-- Brine

-- A bucket with litres of Brine (default 1, a spring's), the rest tainted water, or clean water if clean; full, or
-- holding total litres in all for a part-used one. forged: a Forged Bucket, to see it come back forged.
function TPS.brine(litres, clean, total, forged)
    total = math.max(0, math.min(S.BUCKET_LITRES, total or S.BUCKET_LITRES))
    litres = math.max(0, math.min(total, litres or 1))
    local bucket = S.fillBucket(forged and "Base.BucketForged" or S.EMPTY_BUCKET, litres, clean and S.WATER or S.TAINTED, total)
    getPlayer():getInventory():AddItem(bucket)
    say(string.format("Gave a %s of %g L Brine, %g L %s: %s, boils to %d salt.", forged and "Forged Bucket" or "bucket", litres,
        total - litres, clean and "water" or "tainted water", S.strength(litres) or "too weak", S.saltFor(litres)))
end

-- The other things a test wants, by name.
local GIVES = { sack = S.SACK_ITEM, salt = S.SALT_ITEM, bag = S.BAG_ITEM, map = S.MAP_ITEM, bucket = S.EMPTY_BUCKET,
    forgedBucket = "Base.BucketForged", pan = SaltPanAttachment.ITEM }

function TPS.give(name, count)
    if not GIVES[name] then return say("Things: sack, salt, bag, map, bucket, forgedBucket, pan") end
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem(GIVES[name]) end
    say(string.format("Gave %d %s.", count or 1, name))
end

-- What every bucket, boiling bucket and crust in your main inventory holds.
function TPS.buckets()
    local items = getPlayer():getInventory():getItems()
    local found = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local brine, rest
        if item:getFluidContainer() and item:hasTag(ItemTag.METAL_BUCKET) then
            brine, rest = S.containerBrine(item:getFluidContainer())
            brine = string.format("%g L Brine of %g L", brine, item:getFluidContainer():getAmount())
        elseif item:getModData()[S.BRINE_KEY] then
            brine, rest = S.notedBrine(item)
            brine = string.format("%g L Brine of %g L noted", brine, S.notedLitres(item))
        end
        if brine then
            found = found + 1
            say(string.format("%s: %s, rest %s, bucket kind %s", item:getDisplayName(), brine, rest,
                tostring(item:getModData()[Container.KEY])))
        end
    end
    if found == 0 then say("No buckets of brine in your main inventory.") end
end

-- The nearest Leaching Vat: each layer's salt (top first), the liquid soaking through and the tub. hours: it drains
-- that many hours at once.
function TPS.vat(hours)
    local vat = Station.near(getPlayer():getSquare(), 10, S.isVat)[1]
    if not vat then return say("No Leaching Vat within 10 tiles.") end
    local record = S.stationNow(vat, now())
    if hours then
        record.hour = now() - hours
        S.vatNow(record, now())
    end
    if TraditionalPreservationSaltWorld then TraditionalPreservationSaltWorld.refresh(vat) end
    local layers = {}
    for _, salt in ipairs(record.layers) do table.insert(layers, string.format("%.2f", salt)) end
    local bed, tub = record.bed, record.tub
    say(string.format("Vat at %d,%d: soil [%s] (salt %.2f); soaking %.2f L, %.2f L Brine%s; tub %.2f L, %.2f L Brine%s",
        vat:getX(), vat:getY(), table.concat(layers, ", "), S.saltLeft(record), bed.litres, bed.brine,
        bed.tainted and " (tainted)" or "", tub.litres, tub.brine, tub.tainted and " (tainted)" or ""))
    if record.frost then
        say(string.format("Frozen %.1f h in all (freezes at %g C)%s", record.frost.age, S.VAT_FREEZE_C,
            S.vatFrozen(record) and ": frozen now, the bed and the drip wait" or ""))
    end
end

-- What the salt pan takes, by kind.
local KITS = {
    fit = { about = "the Salt Pan, 2 clay and a mason's trowel, for Fit Salt Pan on a Stone Hearth",
        [SaltPanAttachment.ITEM] = 1, [SaltPanAttachment.CLAY] = 2, ["Base.MasonsTrowel_Wood"] = 1 },
    forge = { about = "2 sheet metal, 2 charcoal, a ball-peen hammer and tongs to forge the salt pan (Blacksmith 3, at a "
        .. "forge), and the magazine that teaches it (Smithing Magazine Vol. 2)",
        ["Base.SheetMetal"] = 2, ["Base.Charcoal"] = 2, ["Base.BallPeenHammer"] = 1, ["Base.Tongs"] = 1, ["Base.SmithingMag2"] = 1 },
}

function TPS.kit(kind)
    local kit = KITS[kind or "fit"]
    if not kit then return say("Kits: fit, forge") end
    local inventory = getPlayer():getInventory()
    for fullType, count in pairs(kit) do
        if fullType ~= "about" then
            for _ = 1, count do inventory:AddItem(fullType) end
        end
    end
    say("Gave " .. kit.about .. ".")
end

local function nearestPan()
    local fire = Fire.fittedNear(getPlayer():getSquare(), SaltPan.ID)[1]
    if not fire then say(string.format("No Stone Hearth with the salt pan within %d tiles.", Fire.FIRE_RADIUS)) end
    return fire
end

function TPS.panInfo()
    local fire = nearestPan()
    if not fire then return end
    local pan = SaltPanAttachment.of(fire)
    local fireState = Fire.isBanked(fire) and "banked" or fire:isLit() and "lit" or "out"
    local dry = SaltPan.hoursToDry(pan)
    say(string.format("Fire %s, fuel %.1f h. Pan: %s, %.1f / %g L, %.2f L Brine (%d salt), %s C, dry in %s h on a lit fire.",
        fireState, Fire.fuelHours(fire) or 0, SaltPan.look(pan), (pan.ml or 0) / 1000, SaltPan.CAPACITY_ML / 1000, pan.salt or 0,
        S.saltFor(pan.salt or 0), pan.tempC and string.format("%.0f", pan.tempC) or "-", dry and string.format("%.1f", dry) or "-"))
end

function TPS.pan(litres, brine, celsius)
    local fire = nearestPan()
    if not fire then return end
    local pan = SaltPanAttachment.of(fire)
    pan.ml, pan.salt, pan.tempC, pan.lastHour = nil, nil, nil, nil
    litres, brine = litres or 30, brine or 3
    local now = getGameTime():getWorldAgeHours()
    if litres > 0 then
        SaltPan.pourInto(pan, litres, math.min(brine, litres), celsius or 20, now)
    elseif brine > 0 then
        pan.salt, pan.tempC, pan.lastHour = brine, celsius or 20, now
    end
    Fire.redraw(fire)
    TPS.panInfo()
end

say("Debug commands loaded. Type TPS.help() in the Lua console.")
