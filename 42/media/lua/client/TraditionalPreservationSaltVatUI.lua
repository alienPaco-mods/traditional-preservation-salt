-- Traditional Preservation (Salt) B42: the Leaching Vat's right-click menu (what it holds, Info, Add Saline Soil, Pour
-- onto the Soil, Draw Off Brine; TPLeachingVat does the hand jobs) and Vat Info, its info window (TP Core's InfoWindow
-- on the settled look: band, Station block, the soil as cells and the soaking bed and tub as tanks, each taking its own
-- drag, Draw Off as a button). A vat holding anything stays where it is.
require "TimedActions/TPLeachingVat"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local StationReport = require "TraditionalPreservationCore/StationReport"
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
local STATION_ICON = "media/textures/TPStation_LeachingVat.png"   -- Vat Info's Station block (TP Core's tools/station_icons.py)
local SOIL_CELL = "media/textures/TPCell_Soil.png"                 -- the soil's cells (TP Core's tools/cell_patterns.py)
local SOIL_COLOUR, EMPTY_COLOUR = { 0.55, 0.45, 0.35 }, { 0.35, 0.55, 0.75 }

local function say(key, ...) return UI.say(KEY .. key, ...) end

local function vatNow(station)
    if TraditionalPreservationSaltWorld then
        TraditionalPreservationSaltWorld.track(station)
        TraditionalPreservationSaltWorld.refresh(station)
    end
    return S.stationNow(station)
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
    view.tubText = S.canDrawOff(record) and say("VatTub", one(tub.litres), one(tub.brine), tubStrength(tub)) or say("VatTubEmpty")
    view.empty = view.sacks == 0 and bed.litres <= 0 and tub.litres <= 0
    view.hours = hours
    view.frozen = hours ~= nil and S.vatFrozen(record)
    view.spent = S.spentLayers(record)
    view.canDraw = S.canDrawOff(record)
    view.bedLitres, view.tubLitres = bed.litres, tub.litres
    view.bedStrength, view.tubStrength = S.strength(S.poolShare(bed) * S.BUCKET_LITRES), S.strength(S.poolShare(tub) * S.BUCKET_LITRES)
    return view
end

-- The band (all_info_mock), the worst first: liquid on the bed frozen (session 76, no mock: the user's go); the tub full
-- and the bed waiting; leaching; brine waiting in the tub;
-- the soil spent; ready for a pour; empty. Returns the word's key, the finished text and the colours.
function VatUI.band(view)
    if view.frozen then return KEY .. "VatBandFrozen", say("VatBandFrozenText"), InfoWindow.BAND_WAITING end
    if view.hours == math.huge then return KEY .. "VatBandTubFull", say("VatBandTubFullText"), InfoWindow.BAND_WAITING end
    if view.hours then
        return KEY .. "VatBandLeaching", say("VatBandLeachingText", tostring(S.DRAIN_PER_HOUR), tostring(view.sacks)), InfoWindow.BAND_WORKING
    end
    if view.canDraw then return KEY .. "VatBandBrine", say("VatBandBrineText", one(view.tubLitres)), InfoWindow.BAND_WORKING end
    if view.sacks > 0 and view.salt <= 0.0001 then return KEY .. "VatBandSpent", say("VatBandSpentText"), InfoWindow.BAND_WAITING end
    if view.sacks > 0 then return KEY .. "VatBandReady", say("VatBandReadyText"), InfoWindow.BAND_IDLE end
    return KEY .. "VatBandEmpty", say("VatBandEmptyText"), InfoWindow.BAND_IDLE
end

-- A pool's colour: its Brine, water (or tainted water) for the rest, as the salt pan's.
local function poolColour(pool)
    if pool.litres <= 0 then return EMPTY_COLOUR end
    local brine = math.min(pool.brine, pool.litres)
    local rest = pool.tainted and S.TAINTED or S.WATER
    return CauldronFluid.liquidColour({ ml = pool.litres, fluid = "Brine", parts = { Brine = brine, [rest] = pool.litres - brine } })
        or EMPTY_COLOUR
end

-- Less than this reads 0.0 L: a tank that shows nothing says nothing about it.
local SHOWN_LITRES = S.DRAW_FROM_LITRES

-- What the whole tub boils down to: its Brine's salt, or too weak (its strength under a bucket's Brine) or too
-- little to boil to a salt.
local function tubBoils(tub)
    local salt = S.saltFor(tub.brine)
    if salt >= 1 then return say("VatBoilsTo", tostring(salt)) end
    return say(S.strength(S.poolShare(tub) * S.BUCKET_LITRES) and "VatTooLittle" or "VatTooWeakShort")
end

-- A pool's state line: its strength in a word, "Water" when too weak to count.
local function strengthWord(strength)
    return strength and getText("Tooltip_TraditionalPreservationSalt_Strength" .. strength) or say("VatWater")
end

-- The three holdings left to right as the liquid goes: what is poured on, soaking down through the soil (a cell a
-- sack) into the tub; the rate over both arrows while it drains.
function VatUI.holdings(view, record)
    local soakState = view.hours == nil and say("VatStateDry") or view.hours == math.huge and say("VatStateWaits")
        or say("VatStateThrough", UI.shortDuration(view.hours))
    local arrow = view.hours and view.hours ~= math.huge and say("VatRate", tostring(S.DRAIN_PER_HOUR)) or ""
    return {
        { kind = "tank", name = say("VatSoakLabel"), amount = say("VatLitres", one(view.bedLitres), tostring(S.BED_LITRES)),
          state = view.bedLitres >= SHOWN_LITRES and strengthWord(view.bedStrength) or nil, under = soakState,
          share = view.bedLitres / S.BED_LITRES, colour = poolColour(record.bed), arrow = arrow },
        { kind = "cells", name = say("VatSoilLabel"), amount = say("VatSacks", tostring(view.sacks), tostring(S.VAT_SACKS)),
          state = say("VatSaltLeft", one(view.salt)), cells = S.VAT_SACKS, filled = view.sacks,
          share = view.sacks / S.VAT_SACKS, colour = SOIL_COLOUR, pattern = SOIL_CELL, arrow = arrow },
        { kind = "tank", name = say("VatTubLabel"), amount = say("VatLitres", one(view.tubLitres), tostring(S.TUB_LITRES)),
          state = view.tubLitres >= SHOWN_LITRES and strengthWord(view.tubStrength) or nil,
          under = view.tubLitres >= SHOWN_LITRES and tubBoils(record.tub) or nil,
          share = view.tubLitres / S.TUB_LITRES, colour = poolColour(record.tub) },
    }
end

local function viewOf(station)
    return VatUI.view(vatNow(station), Weather.placeOf(station))
end

-- The jobs, queued: the item into the inventory first, then the walk, then the hand jobs (vanilla's order).
function VatUI.queue(playerObj, station, mode, items)
    if mode == "spent" then
        if UI.walkTo(playerObj, station) then ISTimedActionQueue.add(TPLeachingVat:new(playerObj, station, "spent")) end
        return
    end
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

-- What Vat Info makes of a dragged selection: sacks go on as soil while there is room, then containers of water or
-- brine are poured while the bed has room. only ("soil" or "pour") keeps to one holding's: the soil's cells take
-- sacks, the soaking bed's tank liquids.
function VatUI.dropJudge(record, items, only)
    local sacks, liquids, refused = {}, {}, nil
    local soilWhy, pourWhy = S.soilRefusal(record), S.pourRefusal(record)
    local room = S.soilRoom(record)
    for _, item in ipairs(items) do
        local isSack = item:getFullType() == S.SACK_ITEM
        if only and isSack ~= (only == "soil") and (isSack or pourable(item)) then
            refused = refused or say(only == "soil" and "VatBedTakesLiquid" or "VatSoilTakesSacks")
        elseif isSack then
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
    local litres = 0
    for _, item in ipairs(liquids) do
        table.insert(take, item)
        litres = litres + item:getFluidContainer():getAmount()
    end
    return { take = take, lines = lines, refused = (#take < #items) and refused or nil, cells = #sacks,
        pattern = SOIL_CELL, adds = math.min(litres, S.bedRoom(record)) / S.BED_LITRES }
end

-- A drag's take: sacks first, then containers.
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
    o.title = getText("IGUI_CraftingWindow_LeachingVat")
    return o
end

function VatWindow:refresh()
    local record = vatNow(self.station)
    self.vatView = VatUI.view(record, Weather.placeOf(self.station))
    self.vatView.holdings = VatUI.holdings(self.vatView, record)
    self.vatView.placeC = Weather.placeTemperature(Weather.weatherModData(), self.vatView.place)
    local station, playerObj = self.station, self.playerObj
    self.drops = self.drops or {
        soil = { judge = function(items) return VatUI.dropJudge(S.vatOf(station), items, "soil") end,
            drop = function(take) dropped(playerObj, station, take) end },
        pour = { judge = function(items) return VatUI.dropJudge(S.vatOf(station), items, "pour") end,
            drop = function(take) dropped(playerObj, station, take) end },
    }
end

-- Vat Info on the settled look (all_info_mock): the band, the Station block, the soaking bed, the soil and the tub
-- with the Lincolnshire lore beside them (sacks dragged onto the soil go on, water or brine onto the bed is poured),
-- Draw Off Brine, then notes.
function VatWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.vatView then return end
    local view = self.vatView
    local station, playerObj = self.station, self.playerObj
    local word, text, look = VatUI.band(view)
    local y = self:band(getText(word), text, look[1], look[2])
    y = self:stationBlock(y, STATION_ICON, view.place, view.placeC)
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    local holdings = view.holdings
    holdings[1].drop, holdings[2].drop = self.drops.pour, self.drops.soil
    -- A right click on the tub: Draw Off Brine into a container of your choice (the button takes the fullest).
    holdings[3].menu = function(context)
        local record = vatNow(station)
        VatUI.addDrawOff(context, playerObj, station, record, VatUI.view(record, Weather.placeOf(station)))
    end
    y = self:holds(y, holdings, say("VatLore"))
    local catcher = carriedCatchers(playerObj)[1]
    local canDraw = view.canDraw and catcher ~= nil
    local buttons = {
        { title = getText(MENU .. "DrawOffBrine"), icon = BRINE_ICON, enabled = canDraw,
          tooltip = not canDraw and (view.canDraw and say("VatNoCatcher") or say("VatTubEmpty")) or nil,
          onClick = function() VatUI.queue(playerObj, station, "draw", { catcher }) end },
    }
    if view.spent > 0 then
        table.insert(buttons, { title = UI.say(MENU .. "ThrowOutSpent", tostring(view.spent)), icon = SOIL_ICON,
            enabled = view.bedLitres <= 0, tooltip = view.bedLitres > 0 and say("VatSoakingNoSoil") or say("ThrowOutSpentHelp"),
            onClick = function() VatUI.queue(playerObj, station, "spent") end })
    end
    y = self:buttonRow(y, buttons)
    self:drawNotes(y, { getText(KEY .. "NoteVat"), say("NoteVatDrag") })
end

function VatUI.open(playerObj, station)
    InfoWindow.open(VatWindow, playerObj, station)
end
StationReport.add(VatWindow, function(isoObject) return S.isVat(isoObject) and isoObject or nil end)

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

-- Draw Off Brine: a row a carried container that can take it; greyed with the reason when the tub is empty or
-- nothing carried takes brine. The vat's menu has it, and a right click on Vat Info's tub (user, 2026-11-22).
function VatUI.addDrawOff(menu, playerObj, station, record, view)
    local draw = menu:addOption(getText(MENU .. "DrawOffBrine"))
    draw.iconTexture = getTexture(BRINE_ICON)
    local catchers = carriedCatchers(playerObj)
    if not S.canDrawOff(record) then
        UI.disable(draw, say("VatTubEmpty"))
    elseif #catchers == 0 then
        UI.disable(draw, say("VatNoCatcher"))
    else
        containerRows(menu, draw, catchers, playerObj, station, "draw")
        UI.tooltip(draw, view.tubText)
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

    -- Throw Out Spent Soil, while any is spent: greyed while liquid soaks through.
    if view.spent > 0 then
        local spent = menu:addOption(UI.say(MENU .. "ThrowOutSpent", tostring(view.spent)), playerObj, VatUI.queue, station, "spent", {})
        spent.iconTexture = getTexture(SOIL_ICON)
        if record.bed.litres > 0 then UI.disable(spent, say("VatSoakingNoSoil")) else UI.tooltip(spent, say("ThrowOutSpentHelp")) end
    end

    VatUI.addDrawOff(menu, playerObj, station, record, view)
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
