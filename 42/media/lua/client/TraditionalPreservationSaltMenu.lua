-- Traditional Preservation (Salt): the right-click option on a lick: dig a soil tile, fill a container at a spring.
require "TraditionalPreservationSalt"
require "TimedActions/TPDigSalineSoil"
require "TimedActions/TPFillSpringBrine"
require "Moveables/ISMoveableSpriteProps"
local UI = require "TraditionalPreservationCore/UI"
local S = TraditionalPreservationSalt

local function isShovel(item)
    return not item:isBroken() and item:hasTag(ItemTag.TAKE_DIRT)
end

local function isEmptySack(item)
    return item:getFullType() == "Base.EmptySandbag" and item:getInventory():isEmpty()
end

local function onDig(playerObj, square, shovel, sack)
    if luautils.walkAdj(playerObj, square) then
        ISWorldObjectContextMenu.transferIfNeeded(playerObj, shovel)
        ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), shovel, true, true)
        ISTimedActionQueue.add(TPDigSalineSoil:new(playerObj, square, shovel, sack))
    end
end

local function onFill(playerObj, square, item)
    if luautils.walkAdj(playerObj, square) then
        ISWorldObjectContextMenu.transferIfNeeded(playerObj, item)
        ISTimedActionQueue.add(TPFillSpringBrine:new(playerObj, square, item))
    end
end

-- The container to fill: the one in hand if it can take brine, else a metal bucket, else any that can.
local function findVessel(playerObj)
    local inHand = playerObj:getPrimaryHandItem()
    if inHand and S.canTakeSpringBrine(inHand) then return inHand end
    local inventory = playerObj:getInventory()
    return inventory:getFirstEvalRecurse(function(item)
        return item:hasTag(ItemTag.METAL_BUCKET) and S.canTakeSpringBrine(item)
    end) or inventory:getFirstEvalRecurse(S.canTakeSpringBrine)
end

local function springMenu(playerObj, context, tile, square)
    local vessel = findVessel(playerObj)
    local litres = S.catchUp(tile, getGameTime():getWorldAgeHours())
    local option = context:addOption(getText("ContextMenu_TraditionalPreservationSalt_Fill"), playerObj, onFill, square, vessel)
    option.iconTexture = getTexture("Item_MetalBucket")
    local status = getText("IGUI_TraditionalPreservationSalt_SpringLitres", math.floor(litres), S.SPRING_LITRES)
    if litres < 1 then
        status = getText("ContextMenu_TraditionalPreservationSalt_SpringDry")
    elseif not vessel then
        status = status .. " <LINE> " .. getText("ContextMenu_TraditionalPreservationSalt_NeedVessel")
    end
    option.notAvailable = litres < 1 or not vessel
    UI.tooltip(option, status)
end

local function findTile(worldobjects)
    for _, object in ipairs(worldobjects) do
        local square = object:getSquare()
        if square and square:getZ() == 0 then
            local tile = S.getTileAt(square:getX(), square:getY())
            if tile then return tile, square end
        end
    end
    return nil
end

local function onFillMenu(playerNum, context, worldobjects, test)
    local tile, square = findTile(worldobjects)
    if not tile then return end
    -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
    if test then return ISWorldObjectContextMenu.setTest() end

    local playerObj = getSpecificPlayer(playerNum)
    if S.isSpring(tile) then return springMenu(playerObj, context, tile, square) end
    local inventory = playerObj:getInventory()
    local shovel = inventory:getFirstEvalRecurse(isShovel)
    local sack = inventory:getFirstEvalRecurse(isEmptySack)
    local units = S.catchUp(tile, getGameTime():getWorldAgeHours())

    local option = context:addOption(getText("ContextMenu_TraditionalPreservationSalt_Dig"), playerObj, onDig, square, shovel, sack)
    -- What the dig gives: a sack of saline soil.
    option.iconTexture = getTexture("Item_Sandbag")
    local status = getText("IGUI_TraditionalPreservationSalt_Units", units, S.MAX_UNITS)
    if units <= 0 then
        status = getText("ContextMenu_TraditionalPreservationSalt_Depleted")
    elseif not shovel then
        status = status .. " <LINE> " .. getText("ContextMenu_TraditionalPreservationSalt_NeedShovel")
    elseif not sack then
        status = status .. " <LINE> " .. getText("ContextMenu_TraditionalPreservationSalt_NeedSack")
    end
    option.notAvailable = units <= 0 or not shovel or not sack
    UI.tooltip(option, status)
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

-- The Leaching Vat stands in the open. Its build recipe refuses an indoor square, and this stops one being picked
-- up and carried in, as placing a moveable doesn't run that check.
UI.outdoorOnly(require("TraditionalPreservationSalt/Tiles").OUTDOOR)
-- And not in front of a door (TP Core's Doors).
UI.keepDoorsFree(require("TraditionalPreservationSalt/Tiles").STATIONS)
