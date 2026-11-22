-- Traditional Preservation (Salt): the salt pan's menu rows and its fire's Info rows, given to TP Core's Fire.attach as
-- the cauldron's are (CauldronUI). The status row says what is in the pan; Pour Brine into Salt Pan takes a container of
-- brine (Brine and water only), any time there is room; Scrape Salt Pan, with a knife, once it has boiled dry; Empty
-- Salt Pan pours the brine away, the salt in it too, while it holds any. The
-- Info holds it as a tank with its heat bar (the salt in it and when it will be dry under).
require "TimedActions/TPSaltPanWork"
require "TraditionalPreservationSaltBrine"
local UI = require "TraditionalPreservationCore/UI"
local Fire = require "TraditionalPreservationCore/Fire"
local FireUI = require "TraditionalPreservationCore/FireUI"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local SaltPanAttachment = require "TraditionalPreservationSalt/SaltPanAttachment"
local S = TraditionalPreservationSalt

local KEY = "IGUI_TraditionalPreservationSalt_"
local MENU = "ContextMenu_TraditionalPreservationSalt_"
local PAN_ICON = "media/textures/Item_TPSaltPan.png"
local BRINE_ICON = "media/textures/Item_TPSaltPanBrine.png"
local CRUST_ICON = "media/textures/Item_TPSaltPanCrust.png"
local IRON_COLOUR = { 0.42, 0.42, 0.44 }
local CRUST_COLOUR = { 0.92, 0.91, 0.87 }   -- the salt settled in the pan

local say, litresText, degrees, hoursText = UI.say, UI.litres, UI.degrees, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

local function mlOf(pan)
    return pan.ml or 0
end

local function capacityText()
    return litresText(SaltPan.CAPACITY_ML)
end

-- Whole portions the salt in the pan scrapes to.
local function portionsOf(pan)
    return S.saltFor(pan.salt or 0)
end

local function onPanAction(playerObj, fire, item, mode)
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPSaltPanWork:new(playerObj, fire, item, mode))
end

local function panStatus(pan)
    local look = SaltPan.look(pan)
    if look == SaltPan.EMPTY then return getText(KEY .. "PanEmpty"), PAN_ICON end
    if look == SaltPan.CRUST then return say(KEY .. "PanCrust", portionsOf(pan)), CRUST_ICON end
    return say(KEY .. "PanStatus", litresText(pan.ml), capacityText(), degrees(pan.tempC)), BRINE_ICON
end

-- Every container holding brine, each with its litres and strength; none, or a full pan, says why in its hover.
local function addPourInMenu(menu, playerObj, fire, pan)
    local option = menu:addOption(getText(MENU .. "PourIntoPan"))
    option.iconTexture = getTexture(BRINE_ICON)
    if SaltPan.roomL(pan) <= 0 then return disableWith(option, getText(KEY .. "PanFull")) end
    local items = findItems(playerObj, function(item) return S.brineAndWater(item:getFluidContainer()) ~= nil end)
    if #items == 0 then return disableWith(option, getText(KEY .. "PanNoBrine")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local brine, litres = S.brineAndWater(item:getFluidContainer())
        local row = sub:addOption(say(MENU .. "PanBrineItem", UI.itemName(item), litresText(litres * 1000),
            string.format("%.1f", brine)), playerObj, onPanAction, fire, item, "pourIn")
        row.itemForTexture = item
    end
    tooltipFor(option, say(KEY .. "PourIntoPanHelp", litresText(SaltPan.roomL(pan) * 1000)))
end

local function addScrapeOption(menu, playerObj, fire, pan)
    local option = menu:addOption(getText(MENU .. "ScrapePan"), playerObj, onPanAction, fire, false, "scrape")
    option.iconTexture = getTexture(CRUST_ICON)
    if not TPSaltPanWork.hasKnife(playerObj) then return disableWith(option, getText(KEY .. "ScrapeNeedsKnife")) end
    tooltipFor(option, say(KEY .. "ScrapePanHelp", portionsOf(pan)))
end

-- Pours the brine away, salt and all: for a pan you want off the hearth before it has boiled down.
local function addEmptyOption(menu, playerObj, fire, pan)
    local option = menu:addOption(getText(MENU .. "EmptyPan"), playerObj, onPanAction, fire, false, "empty")
    option.iconTexture = getTexture(PAN_ICON)
    tooltipFor(option, say(KEY .. "EmptyPanHelp", litresText(pan.ml), portionsOf(pan)))
end

-- Under the heat: dry in how long while a lit fire burns on, slowly while banked, or not on this fire.
local function dryText(fireView)
    local pan = fireView.part
    if fireView.banked then return getText(KEY .. "PanDryBanked") end
    local dryIn = fireView.lit and SaltPan.hoursToDry(pan)
    if dryIn and dryIn <= fireView.burnHours then return say(KEY .. "PanDryIn", hoursText(dryIn)) end
    return getText(KEY .. "PanDryNo")
end

-- The pan as a tank (the brine's colour, the iron's when empty) with its heat bar, the salt in it and when it will
-- be dry under. The salt shows as a white layer at its foot under the brine (user): none while the brine can hold it
-- (saturated is a litre of Brine in a litre), then growing as the brine boils down past that, all of it once dry; a
-- full pan of Brine's salt (30) fills the tank.
-- Buckets dragged onto the pan: brine, watered or not (S.brineAndWater, as Pour Brine into Salt Pan takes), up to its
-- room.
-- Returns DropZone's judgement and adds, the share of the pan the pour would fill.
local function pourJudge(pan, items)
    local room, take, refused, litres, brine = SaltPan.roomL(pan), {}, nil, 0, 0
    for _, item in ipairs(items) do
        local container = item.getFluidContainer and item:getFluidContainer()
        local itemBrine, itemLitres = S.brineAndWater(container)
        if not itemBrine then
            refused = refused or getText(KEY .. "PanDropTakes")
        elseif litres >= room then
            refused = refused or getText(KEY .. "PanFull")
        else
            local taken = math.min(itemLitres, room - litres)
            litres, brine = litres + taken, brine + itemBrine * taken / itemLitres
            table.insert(take, item)
        end
    end
    local lines = { #take > 0 and say(KEY .. "PanDropPour", litresText(litres * CauldronFluid.ML_PER_L), string.format("%.1f", brine))
        or refused or getText(KEY .. "PanDropTakes") }
    return { take = take, lines = lines, refused = #take < #items and refused or nil,
        adds = litres / (SaltPan.CAPACITY_ML / CauldronFluid.ML_PER_L) }
end

-- One pour a bucket, a walk to the fire first.
local function pourDropped(playerObj, fire, take)
    for _, item in ipairs(take) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    for _, item in ipairs(take) do ISTimedActionQueue.add(TPSaltPanWork:new(playerObj, fire, item, "pourIn")) end
end

local function settledShare(pan)
    local held = (pan.ml or 0) / CauldronFluid.ML_PER_L
    return math.max(0, (pan.salt or 0) - held) / (SaltPan.CAPACITY_ML / CauldronFluid.ML_PER_L)
end

local function panHolds(fireView, holdings)
    local pan, ml = fireView.part, mlOf(fireView.part)
    table.insert(holdings, { kind = "tank", name = getText(KEY .. "InfoSaltPan"),
        amount = say(KEY .. "InfoLitres", litresText(ml), capacityText()),
        state = say(KEY .. "InfoSaltPortions", portionsOf(pan)),
        share = ml / SaltPan.CAPACITY_ML, colour = SaltPanAttachment.colour(pan) or IRON_COLOUR,
        under = ml > 0 and dryText(fireView) or nil, heat = FireUI.heatOf(pan.tempC, false),
        settled = { share = settledShare(pan), colour = CRUST_COLOUR },
        drop = { judge = function(items) return pourJudge(pan, items) end,
            drop = function(take) pourDropped(fireView.playerObj, fireView.fire, take) end },
        -- A right click: Scrape the Salt Pan once it has boiled dry (user, 2026-11-22).
        menu = function(context)
            if SaltPan.canScrape(pan) then addScrapeOption(context, fireView.playerObj, fireView.fire, pan) end
        end })
end

local function panNotes(fireView, notes)
    local look = SaltPan.look(fireView.part)
    if look == SaltPan.EMPTY then
        table.insert(notes, getText(KEY .. "PanHelpEmpty"))
    elseif look == SaltPan.CRUST then
        table.insert(notes, getText(KEY .. "PanHelpCrust"))
    elseif not fireView.lit and not fireView.banked then
        table.insert(notes, getText(KEY .. "PanHelpOut"))
    end
    if fireView.banked and mlOf(fireView.part) > 0 then table.insert(notes, getText(KEY .. "PanHelpBanked")) end
    if SaltPan.roomL(fireView.part) > 0 then table.insert(notes, getText(KEY .. "PanDragHint")) end
end

Fire.attach({
    id = SaltPan.ID,
    fitIcon = PAN_ICON,
    display = { icon = "media/textures/Item_TPStoneHearthSaltPan.png", title = "IGUI_CraftingWindow_TPStoneHearthSaltPan",
        infoText = MENU .. "StoneHearthSaltPanInfo",
        fire = { bank = "media/textures/Item_TPStoneHearthSaltPanBanked.png", stoke = "media/textures/Item_TPStoneHearthSaltPanLit.png" } },
    -- Remove's hover for the pan's own reasons (SaltPan.canRemove); Full reads Core's "Empty it first".
    removeText = { Crust = KEY .. "RemoveCrust", Hot = KEY .. "RemoveHot" },
    status = panStatus,
    menu = function(menu, playerObj, fire, pan)
        addPourInMenu(menu, playerObj, fire, pan)
        if SaltPan.canScrape(pan) then addScrapeOption(menu, playerObj, fire, pan) end
        if mlOf(pan) > 0 then addEmptyOption(menu, playerObj, fire, pan) end
    end,
    holds = panHolds,
    notes = panNotes,
})
