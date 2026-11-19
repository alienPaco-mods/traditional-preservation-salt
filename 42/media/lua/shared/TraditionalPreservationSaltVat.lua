-- Traditional Preservation (Salt): the Leaching Vat's record, the one charge it holds and its clock (TP Core's station
-- rule: pieces put on a station; ROADMAP section 12). Kept in the vat's movableData (VAT_KEY); the World shows it, the
-- menu and Vat Info put the charge in and take it out. Leaching goes by the plain game clock, rain or shine, at any Day
-- Length: LEACH_HOURS after it went in, the charge's bucket comes out holding the brine (S.afterLeach). Taken out
-- before then, the charge comes back as it went in.
require "TraditionalPreservationSaltBrine"
local Container = require "TraditionalPreservationCore/Container"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationSalt/Tiles"
local S = TraditionalPreservationSalt

-- Save key in the vat's movableData: never rename it once the mod is out. { charge }; a charge is { brine (litres of
-- Brine in its liquid), rest (the rest's fluid), bucket (the bucket's full type, nil for a plain one), startHour }.
S.VAT_KEY = "tpsVat"
S.LEACH_HOURS = 2

local VATS = {}
for _, name in ipairs(Tiles.STATIONS) do VATS[name] = true end

function S.isVat(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and VATS[sprite:getName()] == true
end

function S.vatOf(station)
    local movableData = Station.movableData(station)
    local record = movableData[S.VAT_KEY]
    if not record then
        record = {}
        movableData[S.VAT_KEY] = record
    end
    return record
end

function S.chargeProgress(charge, now)
    return math.max(math.min((now - charge.startHour) / S.LEACH_HOURS, 1), 0)
end

function S.chargeDone(charge, now)
    return S.chargeProgress(charge, now) >= 1
end

-- Hours until the charge is done (0 once it is).
function S.chargeHoursLeft(charge, now)
    return (1 - S.chargeProgress(charge, now)) * S.LEACH_HOURS
end

-- Litres of Brine the charge's bucket comes out with.
function S.chargeBrineOut(charge)
    return S.afterLeach(charge.brine)
end

-- Puts a carried Leaching Charge in the vat, its clock starting now. Returns the charge, or nil when the vat is full.
function S.putCharge(record, item, now)
    if record.charge or item:getFullType() ~= S.CHARGE_ITEM then return nil end
    local brine, rest = S.notedBrine(item)
    record.charge = { brine = brine, rest = rest, bucket = item:getModData()[Container.KEY], startHour = now }
    return record.charge
end

-- Takes the charge out of the record. Returns it, or nil.
function S.takeCharge(record)
    local charge = record.charge
    record.charge = nil
    return charge
end

-- What a charge comes out as, a new item: done, its bucket of brine; before then, the Leaching Charge as it went in.
function S.chargeOutput(charge, now)
    if S.chargeDone(charge, now) then
        return S.fillBucket(charge.bucket or S.EMPTY_BUCKET, S.chargeBrineOut(charge), charge.rest)
    end
    local item = instanceItem(S.CHARGE_ITEM)
    local modData = item:getModData()
    modData[S.BRINE_KEY] = charge.brine
    modData[S.REST_KEY] = charge.rest
    modData[Container.KEY] = charge.bucket
    return item
end

-- The vat's look: "leaching", "done", or nil when it is empty.
function S.vatLook(record, now)
    if not record.charge then return nil end
    return S.chargeDone(record.charge, now) and "done" or "leaching"
end
