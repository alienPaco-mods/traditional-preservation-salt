-- Traditional Preservation (Salt): the salt pan's menu rows and its fire's Info rows, given to TP Core's Fire.attach as
-- the cauldron's are (CauldronUI). The status row says what is in the pan; Pour Brine into Salt Pan takes a container of
-- brine (Brine and water only), any time there is room; Scrape Salt Pan, with a knife, once it has boiled dry. The
-- Info shows its litres, the salt in it, its heat and when it will be dry.
require "TimedActions/TPSaltPanWork"
require "TraditionalPreservationSaltBrine"
local UI = require "TraditionalPreservationCore/UI"
local Fire = require "TraditionalPreservationCore/Fire"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local SaltPanAttachment = require "TraditionalPreservationSalt/SaltPanAttachment"
local S = TraditionalPreservationSalt

local KEY = "IGUI_TraditionalPreservationSalt_"
local MENU = "ContextMenu_TraditionalPreservationSalt_"
local PAN_ICON = "media/textures/Item_TPSaltPan.png"
local BRINE_ICON = "media/textures/Item_TPSaltPanBrine.png"
local CRUST_ICON = "media/textures/Item_TPSaltPanCrust.png"
local IRON_COLOUR = { 0.42, 0.42, 0.44 }

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
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
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

-- Dry already, or in how long while a lit fire burns on.
local function dryText(fireView)
    local pan = fireView.part
    if fireView.banked then return getText(KEY .. "InfoDryBanked") end
    local dryIn = fireView.lit and SaltPan.hoursToDry(pan)
    if dryIn and dryIn <= fireView.burnHours then return say(KEY .. "InfoDryIn", hoursText(dryIn)) end
    return getText(KEY .. "InfoDryNo")
end

local function panRows(window, y, fireView)
    local pan, ml = fireView.part, mlOf(fireView.part)
    y = window:bar(y, KEY .. "InfoSaltPan", ml / SaltPan.CAPACITY_ML, SaltPanAttachment.colour(pan) or IRON_COLOUR,
        say(KEY .. "InfoLitres", litresText(ml), capacityText()))
    y = window:row(y, KEY .. "InfoSalt", say(KEY .. "InfoSaltPortions", portionsOf(pan)))
    y = window:row(y, KEY .. "InfoTemp", pan.tempC and say(KEY .. "InfoDegrees", degrees(pan.tempC)) or "-")
    if ml > 0 then y = window:row(y, KEY .. "InfoDry", dryText(fireView)) end
    return y
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
    end,
    rows = panRows,
    notes = panNotes,
})
