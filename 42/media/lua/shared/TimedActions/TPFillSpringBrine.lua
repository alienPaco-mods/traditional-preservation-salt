-- Traditional Preservation (Salt): filling a container at a brine spring.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationSaltBrine"

TPFillSpringBrine = ISBaseTimedAction:derive("TPFillSpringBrine")

local S = TraditionalPreservationSalt

local function springTile(square)
    local tile = S.getTileAt(square:getX(), square:getY())
    return tile and S.isSpring(tile) and tile or nil
end

function TPFillSpringBrine:isValid()
    if not self.character:getInventory():containsRecursive(self.item) then return false end
    local tile = springTile(self.square)
    return tile ~= nil and S.canTakeSpringBrine(self.item) and S.catchUp(tile, getGameTime():getWorldAgeHours()) > 0
end

function TPFillSpringBrine:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function TPFillSpringBrine:start()
    self.startHours = getGameTime():getWorldAgeHours()
    self.item:setBeingFilled(true)
    self.item:setJobType(getText("ContextMenu_TraditionalPreservationSalt_Fill"))
    self.item:setJobDelta(0)
    self.sound = self.character:playSound(self.item:getFillFromLakeSound() or "GetWaterFromLake")
    self:setAnimVariable("PourType", self.item:getPourType())
    self:setActionAnim("fill_container_tap")
    if self.character:isSecondaryHandItem(nil) then
        self:setOverrideHandModels(nil, self.item:getStaticModel())
    else
        self:setOverrideHandModels(self.item:getStaticModel(), nil)
    end
end

-- Runs on the game clock, so it takes the same in-game time at any Day Length.
function TPFillSpringBrine:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    local minutes = (getGameTime():getWorldAgeHours() - self.startHours) * 60
    local progress = minutes / S.FILL_MINUTES
    self.item:setJobDelta(math.min(progress, 1))
    if progress >= 1 or self.character:isTimedActionInstant() then
        self:forceComplete()
    end
end

function TPFillSpringBrine:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function TPFillSpringBrine:finish()
    self:stopSound()
    self.item:setBeingFilled(false)
    self.item:setJobDelta(0)
end

function TPFillSpringBrine:stop()
    self:finish()
    ISBaseTimedAction.stop(self)
end

function TPFillSpringBrine:perform()
    self:finish()
    if self.item:getContainer() then self.item:getContainer():setDrawDirty(true) end
    ISBaseTimedAction.perform(self)
end

-- Takes as much as the container holds, or what the spring has.
function TPFillSpringBrine:complete()
    local tile = springTile(self.square)
    local container = self.item:getFluidContainer()
    if not tile or not container then return true end
    local taken = S.takeBrine(tile, getGameTime():getWorldAgeHours(), container:getFreeCapacity())
    if taken > 0 then S.addSpringBrine(container, taken) end
    return true
end

function TPFillSpringBrine:getDuration()
    return -1
end

function TPFillSpringBrine:new(character, square, item)
    local o = ISBaseTimedAction.new(self, character)
    o.square = square
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
