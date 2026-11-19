-- Traditional Preservation (Salt): the Leaching Vat's record, a bed of saline soil that liquid soaks through into a tub
-- below (TP Core's station rule: a record in the station's movableData; ROADMAP section 12). The World shows it, the
-- menu and Vat Info add soil, pour and draw off.
-- The bed holds VAT_SACKS sacks, each a layer of SACK_SALT salt, the newest on top. Liquid poured on (water, clean or
-- tainted, or brine) waits on the bed as one pool and drains at DRAIN_PER_HOUR. Each litre picks up salt at every layer
-- it runs through, by its strength as it reaches that layer (UPTAKE, a litre of Brine a portion of salt), never past
-- saturation; salt it doesn't take stays in the soil for the next pour. So one sack and 10 L of water give 5 L of Brine
-- in 10 L, as the old charge did, and a deeper bed gives stronger brine. The tub catches it, TUB_LITRES at most
-- (one salt pan), drawn off into any container as it drips; with the tub full the bed waits. Leaching goes by the plain
-- game clock, rain or shine, at any Day Length. Spent soil is thrown out when new soil goes on.
require "TraditionalPreservationSaltBrine"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationSalt/Tiles"
local S = TraditionalPreservationSalt

-- Save key in the vat's movableData: never rename it once the mod is out. { layers = { salt left, top first },
-- bed = { litres, brine, tainted }, tub = { litres, brine, tainted }, hour (when it was last brought up to) }.
S.VAT_KEY = "tpsVat"
S.VAT_SACKS = 3
S.SACK_SALT = 5
S.BED_LITRES = 30
S.TUB_LITRES = 30
S.DRAIN_PER_HOUR = 5
-- Litres of Brine a litre of liquid picks up at one layer, by its whole litres of Brine in 10 (S.BRINE_FROM,
-- S.STRONG_FROM): weak 0.5, brine 0.3, strong 0.2, saturated none. The old charge's 5 / 3 / 2 for a 10 L bucket.
S.UPTAKE = { weak = 0.5, brine = 0.3, strong = 0.2 }
-- Litres drained a step: small enough that a pour's strength rises smoothly through the bed.
local STEP = 0.05
local EPSILON = 0.0001

local VATS = {}
for _, name in ipairs(Tiles.STATIONS) do VATS[name] = true end

function S.isVat(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and VATS[sprite:getName()] == true
end

local function newPool() return { litres = 0, brine = 0 } end

function S.vatOf(station)
    local movableData = Station.movableData(station)
    local record = movableData[S.VAT_KEY]
    -- 0.1.28's record held one charge ({ charge }): started afresh (no migration, ROADMAP section 12).
    if not record or not record.bed then
        record = { layers = {}, bed = newPool(), tub = newPool() }
        movableData[S.VAT_KEY] = record
    end
    return record
end

-- A pool's share of Brine, 0 to 1.
function S.poolShare(pool)
    return pool.litres > EPSILON and math.min(pool.brine / pool.litres, 1) or 0
end

-- Litres of Brine a litre at this share picks up at one layer.
function S.uptake(share)
    local whole = math.floor(share * S.BUCKET_LITRES + EPSILON)
    if whole < S.BRINE_FROM then return S.UPTAKE.weak end
    if whole < S.STRONG_FROM then return S.UPTAKE.brine end
    if whole < S.BUCKET_LITRES then return S.UPTAKE.strong end
    return 0
end

function S.saltLeft(record)
    local salt = 0
    for _, layer in ipairs(record.layers) do salt = salt + layer end
    return salt
end

-- Sacks' worth of soil still holding salt.
local function liveLayers(record)
    local live = 0
    for _, layer in ipairs(record.layers) do
        if layer > EPSILON then live = live + 1 end
    end
    return live
end

function S.soilRoom(record)
    return S.VAT_SACKS - liveLayers(record)
end

function S.bedRoom(record)
    return math.max(S.BED_LITRES - record.bed.litres, 0)
end

-- Nil when soil can go on, else why not: "full" or "soaking" (liquid still on the bed).
function S.soilRefusal(record)
    if record.bed.litres > EPSILON then return "soaking" end
    if S.soilRoom(record) <= 0 then return "full" end
    return nil
end

-- Nil when liquid can be poured on, else why not: "noSoil" or "full".
function S.pourRefusal(record)
    if #record.layers == 0 then return "noSoil" end
    if S.bedRoom(record) <= EPSILON then return "full" end
    return nil
end

-- Tips a sack of soil on top, throwing out spent soil first. True if it went on.
function S.addSoil(record)
    if S.soilRefusal(record) then return false end
    local kept = {}
    for _, layer in ipairs(record.layers) do
        if layer > EPSILON then table.insert(kept, layer) end
    end
    table.insert(kept, 1, S.SACK_SALT)
    record.layers = kept
    return true
end

local function mixInto(pool, litres, brine, tainted)
    pool.litres = pool.litres + litres
    pool.brine = pool.brine + brine
    if tainted then pool.tainted = true end
end

-- Pours litres (brine of them Brine, rest the rest's fluid) onto the bed, as much as there is room for. Returns the
-- litres taken.
function S.pourOnBed(record, litres, brine, rest)
    if S.pourRefusal(record) then return 0 end
    local taken = math.min(litres, S.bedRoom(record))
    local share = litres > EPSILON and brine / litres or 0
    mixInto(record.bed, taken, taken * share, rest == S.TAINTED)
    return taken
end

local function settle(pool)
    if pool.litres <= EPSILON then
        pool.litres, pool.brine, pool.tainted = 0, 0, nil
    end
end

-- Drains litres (or what the bed and the tub's room allow) through the soil. Returns the litres drained.
local function drain(record, litres)
    local bed, tub = record.bed, record.tub
    litres = math.min(litres, bed.litres, S.TUB_LITRES - tub.litres)
    local drained = 0
    while litres - drained > EPSILON do
        local step = math.min(STEP, litres - drained)
        local inShare = S.poolShare(bed)
        local share = inShare
        for index, layer in ipairs(record.layers) do
            local take = math.min(S.uptake(share) * step, layer, (1 - share) * step)
            if take > 0 then
                record.layers[index] = layer - take
                share = share + take / step
            end
        end
        bed.litres, bed.brine = bed.litres - step, math.max(bed.brine - inShare * step, 0)
        mixInto(tub, step, share * step, bed.tainted)
        drained = drained + step
    end
    settle(bed)
    return drained
end

-- Brings the vat up to now: the bed drains for the hours since the last look.
function S.vatNow(record, now)
    local hour = record.hour or now
    if now > hour then drain(record, (now - hour) * S.DRAIN_PER_HOUR) end
    record.hour = now
    return record
end

-- Hours until the bed has drained, at the tub's room; nil with nothing on it, math.huge when the full tub stops it.
function S.drainHoursLeft(record)
    if record.bed.litres <= EPSILON then return nil end
    if S.TUB_LITRES - record.tub.litres <= EPSILON then return math.huge end
    return math.min(record.bed.litres, S.TUB_LITRES - record.tub.litres) / S.DRAIN_PER_HOUR
end

-- Draws litres (or all of it) off the tub. Returns litres, litres of Brine and the rest's fluid.
function S.drawOff(record, litres)
    local tub = record.tub
    litres = math.min(litres or tub.litres, tub.litres)
    if litres <= EPSILON then return 0, 0, S.WATER end
    local brine = litres * S.poolShare(tub)
    local rest = tub.tainted and S.TAINTED or S.WATER
    tub.litres, tub.brine = tub.litres - litres, math.max(tub.brine - brine, 0)
    settle(tub)
    return litres, brine, rest
end

-- The vat's look: the bed's ("none", "dry", "wet" or "spent") and the tub's ("empty", "low" or "full").
S.TUB_FULL_FROM = 2 / 3
function S.vatLook(record)
    local soil = "none"
    if #record.layers > 0 then
        soil = record.bed.litres > EPSILON and "wet" or (S.saltLeft(record) > EPSILON and "dry" or "spent")
    end
    local tub = "empty"
    if record.tub.litres > EPSILON then
        tub = record.tub.litres >= S.TUB_LITRES * S.TUB_FULL_FROM and "full" or "low"
    end
    return soil, tub
end
