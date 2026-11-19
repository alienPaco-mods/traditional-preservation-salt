-- Traditional Preservation (Salt): the hand jobs at a Leaching Vat (TraditionalPreservationSaltVat.lua). "put" sets one
-- carried Leaching Charge in (if the vat is still empty when the hands are done), "take" lifts the charge out: its
-- bucket of brine when done, else the charge as it went in (S.chargeOutput).
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationSaltVat"

TPLeachingVat = ISBaseTimedAction:derive("TPLeachingVat")

local S = TraditionalPreservationSalt
local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { put = 60, take = 40 }

local function carried(self)
    return self.item ~= nil and self.character:getInventory():containsRecursive(self.item)
end

function TPLeachingVat:isValid()
    if not self.station:getSquare() then return false end
    local record = S.vatOf(self.station)
    if self.mode == "put" then return carried(self) and record.charge == nil end
    return record.charge ~= nil
end

function TPLeachingVat:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPLeachingVat:start()
    self:setActionAnim("Loot")
end

function TPLeachingVat:complete()
    local now = getGameTime():getWorldAgeHours()
    local record = S.vatOf(self.station)
    if self.mode == "put" then
        if carried(self) and S.putCharge(record, self.item, now) then Action.removeItem(self.item) end
    else
        local charge = S.takeCharge(record)
        local output = charge and S.chargeOutput(charge, now)
        if output then Actions.addOrDropItem(self.character, output) end
    end
    if TraditionalPreservationSaltWorld then TraditionalPreservationSaltWorld.refresh(self.station) end
    return true
end

function TPLeachingVat:perform()
    ISBaseTimedAction.perform(self)
end

function TPLeachingVat:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- "put": item is the carried Leaching Charge; "take": nothing more.
function TPLeachingVat:new(character, station, mode, item)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
