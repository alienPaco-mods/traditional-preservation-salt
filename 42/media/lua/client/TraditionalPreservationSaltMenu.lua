-- Traditional Preservation (Salt): the right-click option on a deposit.
require "TraditionalPreservationSalt"
require "TimedActions/ISDigSalineSoil"
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
        ISTimedActionQueue.add(ISDigSalineSoil:new(playerObj, square, shovel, sack))
    end
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

local function addTooltip(option, text)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = text
    option.toolTip = tooltip
end

local function onFillMenu(playerNum, context, worldobjects, test)
    if test then return end

    local tile, square = findTile(worldobjects)
    if not tile then return end

    local playerObj = getSpecificPlayer(playerNum)
    local inventory = playerObj:getInventory()
    local shovel = inventory:getFirstEvalRecurse(isShovel)
    local sack = inventory:getFirstEvalRecurse(isEmptySack)
    local units = S.catchUp(tile, getGameTime():getWorldAgeHours())

    local option = context:addOption(getText("ContextMenu_TraditionalPreservationSalt_Dig"), playerObj, onDig, square, shovel, sack)
    local status = getText("IGUI_TraditionalPreservationSalt_Units", units, S.MAX_UNITS)
    if units <= 0 then
        status = getText("ContextMenu_TraditionalPreservationSalt_Depleted")
    elseif not shovel then
        status = status .. " <LINE> " .. getText("ContextMenu_TraditionalPreservationSalt_NeedShovel")
    elseif not sack then
        status = status .. " <LINE> " .. getText("ContextMenu_TraditionalPreservationSalt_NeedSack")
    end
    option.notAvailable = units <= 0 or not shovel or not sack
    addTooltip(option, status)
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

-- The Leaching Vat stands in the open. Its build recipe refuses an indoor square, and this stops one being picked
-- up and carried in, as placing a moveable doesn't run that check.
UI.outdoorOnly(require("TraditionalPreservationSalt/Tiles").OUTDOOR)
