-- Traditional Preservation (Salt): the hand jobs at a Leaching Vat (TraditionalPreservationSaltVat.lua). "soil" tips a
-- carried Sack of Saline Soil on the bed (the empty sack back), "pour" pours a container of water or brine onto it, as
-- much as there is room for, and "draw" draws the tub's brine off into a container, as much as it takes. Each brings
-- the vat up to now first, so a pour or a draw meets the bed and the tub as they are.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationSaltVat"

TPLeachingVat = ISBaseTimedAction:derive("TPLeachingVat")

local S = TraditionalPreservationSalt
local Action = require "TraditionalPreservationCore/Action"
local SOIL_TICKS = 60
-- Past this many litres a pour or a draw takes no longer.
local MOST_LITRES = 10
local EMPTY_SACK = "Base.EmptySandbag"

local function carried(self)
    return self.item ~= nil and self.character:getInventory():containsRecursive(self.item)
end

-- The vat as saved, not brought up to now (isValid and getDuration run often).
local function savedVat(self)
    return S.vatOf(self.station)
end

-- Litres this job moves, as things stand.
local function litresOf(self)
    local container = self.item and self.item:getFluidContainer()
    if not container then return 0 end
    local record = savedVat(self)
    if self.mode == "pour" then return math.min(container:getAmount(), S.bedRoom(record)) end
    return math.min(container:getFreeCapacity(), record.tub.litres)
end

function TPLeachingVat:isValid()
    if not self.station:getSquare() or not carried(self) then return false end
    local record = savedVat(self)
    if self.mode == "soil" then return self.item:getFullType() == S.SACK_ITEM and S.soilRefusal(record) == nil end
    if self.mode == "pour" then return S.leachLiquid(self.item:getFluidContainer()) ~= nil and S.pourRefusal(record) == nil end
    return S.canTakeSpringBrine(self.item) and record.tub.litres > 0
end

function TPLeachingVat:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPLeachingVat:start()
    self:setActionAnim("Loot")
end

function TPLeachingVat:complete()
    local record = S.vatNow(S.vatOf(self.station), getGameTime():getWorldAgeHours())
    if self.mode == "soil" then
        if carried(self) and S.addSoil(record) then
            Action.removeItem(self.item)
            Actions.addOrDropItem(self.character, instanceItem(EMPTY_SACK))
        end
    elseif self.mode == "pour" then
        local container = self.item:getFluidContainer()
        local brine, rest, litres = S.leachLiquid(container)
        if brine then
            local taken = S.pourOnBed(record, litres, brine, rest)
            if taken > 0 then container:removeFluid(taken) end
        end
    else
        local container = self.item:getFluidContainer()
        if container and S.canTakeSpringBrine(self.item) then
            local litres, brine, rest = S.drawOff(record, container:getFreeCapacity())
            if litres > 0 then S.fillWith(container, litres, brine, rest) end
        end
    end
    if TraditionalPreservationSaltWorld then TraditionalPreservationSaltWorld.refresh(self.station) end
    return true
end

function TPLeachingVat:perform()
    ISBaseTimedAction.perform(self)
end

function TPLeachingVat:getDuration()
    if self.mode == "soil" then return Action.duration(self.character, SOIL_TICKS) end
    return Action.pourDuration(self.character, litresOf(self), MOST_LITRES)
end

-- mode "soil" (item: the Sack of Saline Soil), "pour" (item: the container poured) or "draw" (item: the container filled).
function TPLeachingVat:new(character, station, mode, item)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
