-- Traditional Preservation (Salt): the hand jobs at a Stone Hearth's salt pan. "pourIn" pours a container of brine (Brine
-- and water, nothing else) into the pan, as much as there is room for, any time, the fire burning or not; "scrape"
-- scrapes the dry crust out with a knife, about ten minutes, as Evaporated Salt; "empty" pours the brine away, the salt
-- in it too, and takes no item.
require "TimedActions/ISBaseTimedAction"
require "TraditionalPreservationSalt"
require "TraditionalPreservationSaltBrine"
local Fire = require "TraditionalPreservationCore/Fire"
local Action = require "TraditionalPreservationCore/Action"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local SaltPanAttachment = require "TraditionalPreservationSalt/SaltPanAttachment"
local S = TraditionalPreservationSalt

TPSaltPanWork = ISBaseTimedAction:derive("TPSaltPanWork")

-- Past this many litres a pour takes no longer.
local MOST_LITRES = 10
TPSaltPanWork.SCRAPE_TICKS = 100
TPSaltPanWork.KNIVES = { "SHARP_KNIFE", "DULL_KNIFE", "MEAT_CLEAVER" }

-- The pan's state as saved, not brought up to now (isValid and getDuration run often).
local function savedPan(self)
    return Fire.partModData(self.fire:getModData(), SaltPan.ID)
end

-- Whether the character carries a knife to scrape with.
function TPSaltPanWork.hasKnife(character)
    for _, tag in ipairs(TPSaltPanWork.KNIVES) do
        if Action.hasTool(character, tag) then return true end
    end
    return false
end

function TPSaltPanWork:isValid()
    if not self.fire:getSquare() or not Fire.isFitted(self.fire, SaltPan.ID) then return false end
    if self.mode == "scrape" then
        return SaltPan.canScrape(savedPan(self)) and TPSaltPanWork.hasKnife(self.character)
    end
    if self.mode == "empty" then return (savedPan(self).ml or 0) > 0 end
    return self.character:getInventory():containsRecursive(self.item)
        and S.brineAndWater(self.item:getFluidContainer()) ~= nil and SaltPan.roomL(savedPan(self)) > 0
end

function TPSaltPanWork:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPSaltPanWork:start()
    self:setActionAnim("Loot")
end

function TPSaltPanWork:complete()
    -- Brought up to the minute first, so poured brine mixes with the pan as it is now.
    local pan = SaltPanAttachment.of(self.fire)
    local now = getGameTime():getWorldAgeHours()
    if self.mode == "scrape" then
        local portions = SaltPan.scrape(pan, S.saltFor)
        for _ = 1, portions do Actions.addOrDropItem(self.character, instanceItem(S.SALT_ITEM)) end
    elseif self.mode == "empty" then
        SaltPan.empty(pan)
    else
        local container = self.item:getFluidContainer()
        local brine, litres = S.brineAndWater(container)
        if brine then
            local taken = SaltPan.pourInto(pan, litres, brine, CauldronFluid.heatOf(self.item, now, self.character), now)
            if taken > 0 then container:removeFluid(taken) end
        end
    end
    Fire.redraw(self.fire)
    return true
end

function TPSaltPanWork:perform()
    ISBaseTimedAction.perform(self)
end

function TPSaltPanWork:getDuration()
    if self.mode == "scrape" then return Action.duration(self.character, TPSaltPanWork.SCRAPE_TICKS) end
    if self.mode == "empty" then return Action.pourDuration(self.character, (savedPan(self).ml or 0) / 1000, MOST_LITRES) end
    local container = self.item:getFluidContainer()
    local litres = container and math.min(container:getAmount(), SaltPan.roomL(savedPan(self))) or 0
    return Action.pourDuration(self.character, litres, MOST_LITRES)
end

-- mode "pourIn" with the container item, or "scrape" or "empty" with none.
function TPSaltPanWork:new(character, fire, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
