-- Traditional Preservation (Salt): digging one sack of saline soil from a deposit.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationSalt"

ISDigSalineSoil = ISBaseTimedAction:derive("ISDigSalineSoil")

function ISDigSalineSoil:isValid()
    local inventory = self.character:getInventory()
    if not inventory:containsRecursive(self.sack) or not inventory:containsRecursive(self.shovel) then return false end
    if self.shovel:isBroken() or not self.sack:getInventory():isEmpty() then return false end
    local tile = TraditionalPreservationSalt.getTileAt(self.square:getX(), self.square:getY())
    return tile ~= nil and TraditionalPreservationSalt.catchUp(tile, getGameTime():getWorldAgeHours()) > 0
end

function ISDigSalineSoil:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function ISDigSalineSoil:start()
    self.startHours = getGameTime():getWorldAgeHours()
    self:setActionAnim(BuildingHelper.getShovelAnim(self.character:getPrimaryHandItem()))
    self.sound = getSoundManager():PlayWorldSound("Shoveling", self.square, 0, 10, 1, true)
end

-- Runs on the game clock, so it takes the same in-game time at any Day Length.
function ISDigSalineSoil:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    local minutes = (getGameTime():getWorldAgeHours() - self.startHours) * 60
    local progress = minutes / TraditionalPreservationSalt.HARVEST_MINUTES
    self.shovel:setJobDelta(math.min(progress, 1))
    if progress >= 1 then
        self:forceComplete()
    end
end

function ISDigSalineSoil:stopSound()
    if self.sound and self.sound:isPlaying() then
        self.sound:stop()
    end
end

function ISDigSalineSoil:stop()
    self:stopSound()
    self.shovel:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end

function ISDigSalineSoil:perform()
    self:stopSound()
    self.shovel:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end

function ISDigSalineSoil:complete()
    local tile = TraditionalPreservationSalt.getTileAt(self.square:getX(), self.square:getY())
    if tile and TraditionalPreservationSalt.takeUnit(tile, getGameTime():getWorldAgeHours()) then
        self.sack:getContainer():Remove(self.sack)
        self.character:getInventory():AddItem("TraditionalPreservationSalt.SalineSoilSack")
    end
    return true
end

function ISDigSalineSoil:getDuration()
    return -1
end

function ISDigSalineSoil:new(character, square, shovel, sack)
    local o = ISBaseTimedAction.new(self, character)
    o.square = square
    o.shovel = shovel
    o.sack = sack
    o.maxTime = o:getDuration()
    o.caloriesModifier = 8
    return o
end
