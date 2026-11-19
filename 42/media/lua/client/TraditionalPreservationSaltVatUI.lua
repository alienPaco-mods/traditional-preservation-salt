-- Traditional Preservation (Salt) B42: the Leaching Vat's right-click menu (what it holds, Info, Add Saline Soil, Pour
-- onto the Soil, Draw Off Brine; TPLeachingVat does the hand jobs) and Vat Info, its info window (TP Core's InfoWindow:
-- the place, the Soil, Soaking and Tub bars, Draw Off and the drop square). A vat holding anything stays where it is.
require "TimedActions/TPLeachingVat"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"

TraditionalPreservationSaltVatUI = TraditionalPreservationSaltVatUI or {}
local VatUI = TraditionalPreservationSaltVatUI
local S = TraditionalPreservationSalt

local KEY = "IGUI_TraditionalPreservationSalt_"
local MENU = "ContextMenu_TraditionalPreservationSalt_"
local VAT_ICON = "media/textures/Item_LeachingVat.png"
local SOIL_ICON = "Item_Sandbag"
local BRINE_ICON = "media/textures/Item_BucketBrine.png"
local POUR_ICON = "Item_MetalBucket"
local COLOURS = { soil = { 0.55, 0.45, 0.35 }, soaking = { 0.35, 0.55, 0.75 }, tub = { 0.75, 0.68, 0.45 } }

local function say(key, ...) return UI.say(KEY .. key, ...) end

local function vatNow(station)
    if TraditionalPreservationSaltWorld then
        TraditionalPreservationSaltWorld.track(station)
        TraditionalPreservationSaltWorld.refresh(station)
    end
    return S.vatNow(S.vatOf(station), getGameTime():getWorldAgeHours())
end

local function one(value) return string.format("%.1f", value) end

-- "Strong brine: boils to 8 salt." for the tub, or a plain line when too weak to boil to a salt.
local function tubStrength(tub)
    local brine10 = S.poolShare(tub) * S.BUCKET_LITRES
    return S.strengthText(brine10) or say("VatTooWeak")
end

-- Everything the menu and Vat Info show.
function VatUI.view(record, place)
    local bed, tub = record.bed, record.tub
    local view = { place = place, sacks = #record.layers, salt = S.saltLeft(record) }
    view.soilShare = view.salt / (S.VAT_SACKS * S.SACK_SALT)
    view.soilText = view.sacks == 0 and say("VatNoSoil") or say("VatSoil", tostring(view.sacks), one(view.salt))
    view.soakShare = bed.litres / S.BED_LITRES
    local hours = S.drainHoursLeft(record)
    if not hours then
        view.soakText = say("VatDry")
    elseif hours == math.huge then
        view.soakText = say("VatSoakWaits", one(bed.litres))
    else
        view.soakText = say("VatSoaking", one(bed.litres), UI.durationText(hours))
    end
    view.tubShare = tub.litres / S.TUB_LITRES
    view.tubText = tub.litres > 0 and say("VatTub", one(tub.litres), one(tub.brine), tubStrength(tub)) or say("VatTubEmpty")
    view.empty = view.sacks == 0 and bed.litres <= 0 and tub.litres <= 0
    return view
end

local function viewOf(station)
    return VatUI.view(vatNow(station), Weather.placeOf(station))
end

-- The jobs, queued: the item into the inventory first, then the walk, then the hand jobs (vanilla's order).
function VatUI.queue(playerObj, station, mode, items)
    if #items == 0 then return end
    for _, item in ipairs(items) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not UI.walkTo(playerObj, station) then return end
    for _, item in ipairs(items) do ISTimedActionQueue.add(TPLeachingVat:new(playerObj, station, mode, item)) end
end

local function carriedSacks(playerObj)
    return UI.findItems(playerObj, function(item) return item:getFullType() == S.SACK_ITEM end)
end

local function pourable(item)
    return S.leachLiquid(item:getFluidContainer()) ~= nil
end

local function carriedLiquids(playerObj)
    return UI.findItems(playerObj, pourable)
end

-- Containers the tub's brine can go into: the fullest first, so a part-filled bucket is topped up before a new one.
local function carriedCatchers(playerObj)
    local items = UI.findItems(playerObj, S.canTakeSpringBrine)
    table.sort(items, function(a, b) return a:getFluidContainer():getAmount() > b:getFluidContainer():getAmount() end)
    return items
end

local SOIL_REFUSALS = { soaking = "VatSoakingNoSoil", full = "VatSoilFull" }
local POUR_REFUSALS = { noSoil = "VatSoilFirst", full = "VatBedFull" }

-- What Vat Info's drop square makes of a dragged selection: sacks go on as soil while there is room, then containers
-- of water or brine are poured while the bed has room.
function VatUI.dropJudge(record, items)
    local sacks, liquids, refused = {}, {}, nil
    local soilWhy, pourWhy = S.soilRefusal(record), S.pourRefusal(record)
    local room = S.soilRoom(record)
    for _, item in ipairs(items) do
        if item:getFullType() == S.SACK_ITEM then
            if soilWhy then
                refused = refused or say(SOIL_REFUSALS[soilWhy])
            elseif #sacks >= room then
                refused = refused or say("VatSoilFull")
            else
                table.insert(sacks, item)
            end
        elseif pourable(item) then
            -- Soil dropped with them goes on first, so a pour waits only on a full bed.
            local why = pourWhy
            if why == "noSoil" and #sacks > 0 then why = nil end
            if why then refused = refused or say(POUR_REFUSALS[why]) else table.insert(liquids, item) end
        else
            refused = refused or say("VatTakes")
        end
    end
    local lines = {}
    if #sacks > 0 then table.insert(lines, say("DropSoil", tostring(#sacks))) end
    if #liquids > 0 then table.insert(lines, say("DropPour", tostring(#liquids))) end
    if #lines == 0 then table.insert(lines, refused or say("VatTakes")) end
    local take = {}
    for _, item in ipairs(sacks) do table.insert(take, item) end
    for _, item in ipairs(liquids) do table.insert(take, item) end
    return { take = take, lines = lines, refused = (#take < #items) and refused or nil }
end

-- The drop square's take: sacks first, then containers.
local function dropped(playerObj, station, take)
    local sacks, liquids = {}, {}
    for _, item in ipairs(take) do table.insert(item:getFullType() == S.SACK_ITEM and sacks or liquids, item) end
    VatUI.queue(playerObj, station, "soil", sacks)
    VatUI.queue(playerObj, station, "pour", liquids)
end

-- Vat Info

local VatWindow = InfoWindow:derive("TraditionalPreservationSaltVatWindow")

function VatWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = say("VatInfo")
    return o
end

function VatWindow:refresh()
    self.vatView = viewOf(self.station)
end

function VatWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.vatView then return end
    local view = self.vatView
    local station, playerObj = self.station, self.playerObj
    local y = self:top()
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoPlace", UI.placeName(view.place))
    y = self:bar(y, KEY .. "VatSoilLabel", view.soilShare, COLOURS.soil, view.soilText)
    y = self:bar(y, KEY .. "VatSoakLabel", view.soakShare, COLOURS.soaking, view.soakText)
    y = self:bar(y, KEY .. "VatTubLabel", view.tubShare, COLOURS.tub, view.tubText)
    local catcher = carriedCatchers(playerObj)[1]
    local canDraw = view.tubShare > 0 and catcher ~= nil
    y = self:buttonRow(y, {
        { title = getText(MENU .. "DrawOffBrine"), enabled = canDraw,
          tooltip = not canDraw and (view.tubShare > 0 and say("VatNoCatcher") or say("VatTubEmpty")) or nil,
          onClick = function() VatUI.queue(playerObj, station, "draw", { catcher }) end },
    })
    y = self:dropZone(y, say("DropIdle"), function(items) return VatUI.dropJudge(S.vatOf(station), items) end,
        function(take) dropped(playerObj, station, take) end)
    local notes = { getText(KEY .. "NoteVat") }
    if view.empty then table.insert(notes, 1, say("NoteVatEmpty")) end
    self:drawNotes(y, notes)
end

function VatUI.open(playerObj, station)
    InfoWindow.open(VatWindow, playerObj, station)
end

-- The menu

-- A submenu row a container: "Bucket (10 L, 1.0 L of Brine)".
local function containerRows(menu, option, items, playerObj, station, mode)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local brine = S.containerBrine(container)
        local row = sub:addOption(UI.say(MENU .. "PanBrineItem", UI.itemName(item), one(container:getAmount()), one(brine)),
            playerObj, VatUI.queue, station, mode, { item })
        row.itemForTexture = item
    end
end

function VatUI.addMenu(context, playerObj, station)
    local record = vatNow(station)
    local view = VatUI.view(record, Weather.placeOf(station))
    local vatIcon = getTexture(VAT_ICON)
    local option = context:addOption(getText("IGUI_CraftingWindow_LeachingVat"))
    option.iconTexture = vatIcon
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(view.soilText .. ", " .. view.tubText)
    status.isDisabled = true
    status.iconTexture = vatIcon
    UI.tooltip(status, table.concat({ UI.placeName(view.place), view.soilText, view.soakText, view.tubText,
        getText(KEY .. "NoteVat") }, " <LINE> "))
    local info = menu:addOption(say("VatInfo"), playerObj, VatUI.open, station)
    info.iconTexture = vatIcon
    UI.topInfo(context, say("VatInfo"), vatIcon, playerObj, VatUI.open, station)

    -- Add Saline Soil: one sack a row, greyed with the reason.
    local sacks = carriedSacks(playerObj)
    local soil = menu:addOption(getText(MENU .. "AddSoil"), playerObj, VatUI.queue, station, "soil", { sacks[1] })
    soil.iconTexture = getTexture(SOIL_ICON)
    local soilWhy = S.soilRefusal(record)
    if soilWhy then
        UI.disable(soil, say(SOIL_REFUSALS[soilWhy]))
    elseif #sacks == 0 then
        UI.disable(soil, say("VatNoSack"))
    else
        UI.tooltip(soil, say("AddSoilHelp", tostring(S.SACK_SALT)))
    end

    -- Pour onto the Soil: a row a carried container of water or brine.
    local pour = menu:addOption(getText(MENU .. "PourOnSoil"))
    pour.iconTexture = getTexture(POUR_ICON)
    local pourWhy = S.pourRefusal(record)
    local liquids = carriedLiquids(playerObj)
    if pourWhy then
        UI.disable(pour, say(POUR_REFUSALS[pourWhy]))
    elseif #liquids == 0 then
        UI.disable(pour, say("VatNoLiquid"))
    else
        containerRows(menu, pour, liquids, playerObj, station, "pour")
        UI.tooltip(pour, say("PourOnSoilHelp", one(S.bedRoom(record))))
    end

    -- Draw Off Brine: a row a carried container that can take it.
    local draw = menu:addOption(getText(MENU .. "DrawOffBrine"))
    draw.iconTexture = getTexture(BRINE_ICON)
    local catchers = carriedCatchers(playerObj)
    if record.tub.litres <= 0 then
        UI.disable(draw, say("VatTubEmpty"))
    elseif #catchers == 0 then
        UI.disable(draw, say("VatNoCatcher"))
    else
        containerRows(menu, draw, catchers, playerObj, station, "draw")
        UI.tooltip(draw, view.tubText)
    end
end

local function onFillMenu(playerNum, context, worldobjects, test)
    for _, isoObject in ipairs(worldobjects) do
        if S.isVat(isoObject) then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            return VatUI.addMenu(context, getSpecificPlayer(playerNum), isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillMenu)

-- A vat holding soil with salt in it, liquid or brine stays where it is (no station moves mid-process). Spent soil
-- alone doesn't hold it.
UI.keepInPlace(function(isoObject)
    if not S.isVat(isoObject) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local record = movableData and movableData[S.VAT_KEY]
    if not record then return nil end
    return (S.saltLeft(record) > 0 or record.bed.litres > 0 or record.tub.litres > 0) or nil
end)
