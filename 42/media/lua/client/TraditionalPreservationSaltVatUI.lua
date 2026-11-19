-- Traditional Preservation (Salt) B42: the Leaching Vat's right-click menu (what it holds, Info, Put In the Charge,
-- Take Out the Brine, Take Out the Charge; TPLeachingVat does the hand jobs) and Vat Info, its info window (TP Core's
-- InfoWindow: the place, a bar for the charge, what the brine comes out at, the buttons and the drop square). A vat
-- holding a charge stays where it is.
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
local CHARGE_ICON = "media/textures/Item_LeachingCharge.png"
local BRINE_ICON = "media/textures/Item_BucketBrine.png"
local COLOURS = { leaching = { 0.35, 0.55, 0.75 }, done = { 0.35, 0.7, 0.35 } }

local function say(key, ...) return UI.say(KEY .. key, ...) end

local function now() return getGameTime():getWorldAgeHours() end

local function vatNow(station)
    if TraditionalPreservationSaltWorld then
        TraditionalPreservationSaltWorld.track(station)
        TraditionalPreservationSaltWorld.refresh(station)
    end
    return S.vatOf(station)
end

-- "8 L of Brine: Strong brine: boils to 8 salt."
local function brineText(litres)
    return say("VatBrineOut", string.format("%.0f", litres), S.strengthText(litres) or "")
end

-- Everything the menu and Vat Info show: { place, look, progress, barText, brineText, holds }.
function VatUI.view(record, place, hours)
    hours = hours or now()
    local charge = record.charge
    local view = { place = place, look = S.vatLook(record, hours) }
    if not charge then
        view.holds = say("VatEmpty")
        return view
    end
    view.progress = S.chargeProgress(charge, hours)
    view.brineText = brineText(S.chargeBrineOut(charge))
    if view.look == "done" then
        view.holds = say("VatHoldsBrine")
        view.barText = say("VatDone")
    else
        view.holds = say("VatHoldsCharge")
        view.barText = say("VatLeft", UI.percent(view.progress), UI.durationText(S.chargeHoursLeft(charge, hours)))
    end
    return view
end

local function viewOf(station)
    return VatUI.view(vatNow(station), Weather.placeOf(station))
end

-- The jobs, queued: the charge into the inventory first, then the walk, then the hand job (vanilla's order).
function VatUI.put(playerObj, station, item)
    if not item then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    if not UI.walkTo(playerObj, station) then return end
    ISTimedActionQueue.add(TPLeachingVat:new(playerObj, station, "put", item))
end

function VatUI.take(playerObj, station)
    if not UI.walkTo(playerObj, station) then return end
    ISTimedActionQueue.add(TPLeachingVat:new(playerObj, station, "take"))
end

local function carriedCharge(playerObj)
    return UI.findItems(playerObj, function(item) return item:getFullType() == S.CHARGE_ITEM end)[1]
end

-- What Vat Info's drop square makes of a dragged selection: the one charge it would take.
function VatUI.dropJudge(record, items)
    if record.charge then return { take = {}, lines = { say("VatFull") }, refused = say("VatFull") } end
    for _, item in ipairs(items) do
        if item:getFullType() == S.CHARGE_ITEM then
            local refused = #items > 1 and say("VatOneCharge") or nil
            return { take = { item }, lines = { say("DropCharge") }, refused = refused }
        end
    end
    return { take = {}, lines = { say("NeedsCharge") }, refused = say("NeedsCharge") }
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
    y = self:row(y, KEY .. "VatHolds", view.holds)
    if view.progress then
        y = self:bar(y, KEY .. "InfoLeaching", view.progress, COLOURS[view.look], view.barText)
        y = self:row(y, KEY .. "VatBrine", view.brineText)
    end
    local done, leaching = view.look == "done", view.look == "leaching"
    y = self:buttonRow(y, {
        { title = getText(MENU .. "TakeBrine"), enabled = done,
          tooltip = not done and (view.barText or say("VatEmpty")) or nil,
          onClick = function() VatUI.take(playerObj, station) end },
        { title = getText(MENU .. "TakeCharge"), enabled = leaching, tooltip = leaching and say("TakeChargeHelp") or nil,
          onClick = function() VatUI.take(playerObj, station) end },
    })
    y = self:dropZone(y, say("DropIdle"), function(items) return VatUI.dropJudge(S.vatOf(station), items) end,
        function(take) VatUI.put(playerObj, station, take[1]) end)
    local notes = { getText(KEY .. "InfoClock") }
    if not view.look then table.insert(notes, 1, say("NoteVatEmpty")) end
    self:drawNotes(y, notes)
end

function VatUI.open(playerObj, station)
    InfoWindow.open(VatWindow, playerObj, station)
end

-- The menu

function VatUI.addMenu(context, playerObj, station)
    local record = vatNow(station)
    local view = VatUI.view(record, Weather.placeOf(station))
    local vatIcon = getTexture(VAT_ICON)
    local option = context:addOption(getText("IGUI_CraftingWindow_LeachingVat"))
    option.iconTexture = vatIcon
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(view.barText and (view.holds .. ": " .. view.barText) or view.holds)
    status.isDisabled = true
    status.iconTexture = vatIcon
    local lines = { UI.placeName(view.place) }
    if view.brineText then table.insert(lines, view.brineText) end
    table.insert(lines, getText(KEY .. "InfoClock"))
    UI.tooltip(status, table.concat(lines, " <LINE> "))
    local info = menu:addOption(say("VatInfo"), playerObj, VatUI.open, station)
    info.iconTexture = vatIcon
    UI.topInfo(context, say("VatInfo"), vatIcon, playerObj, VatUI.open, station)

    local charge = carriedCharge(playerObj)
    if charge then
        local put = menu:addOption(getText(MENU .. "PutCharge"), playerObj, VatUI.put, station, charge)
        put.iconTexture = getTexture(CHARGE_ICON)
        if record.charge then
            UI.disable(put, say("VatFull"))
        else
            UI.tooltip(put, brineText(S.afterLeach((S.notedBrine(charge)))))
        end
    end

    -- Take Out the Brine is always there: greyed until the charge is done, saying how long is left.
    local take = menu:addOption(getText(MENU .. "TakeBrine"), playerObj, VatUI.take, station)
    take.iconTexture = getTexture(BRINE_ICON)
    if view.look ~= "done" then UI.disable(take, view.barText or say("VatEmpty")) end
    if view.look == "leaching" then
        local back = menu:addOption(getText(MENU .. "TakeCharge"), playerObj, VatUI.take, station)
        back.iconTexture = getTexture(CHARGE_ICON)
        UI.tooltip(back, say("TakeChargeHelp"))
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

-- A vat holding a charge stays where it is (no station moves mid-process).
UI.keepInPlace(function(isoObject)
    if not S.isVat(isoObject) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local record = movableData and movableData[S.VAT_KEY]
    return (record ~= nil and record.charge ~= nil) or nil
end)
