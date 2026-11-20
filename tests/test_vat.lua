-- Checks the Leaching Vat with stand-ins for the engine: the soil bed's leaching (each layer, salt left in the soil, the
-- tub filling and stopping it, the plain clock), the World's look a facing and an old vat losing its crafting window,
-- the right-click menu (status, Info, Add Saline Soil, Pour onto the Soil, Draw Off Brine) and its hand jobs
-- (TPLeachingVat), Vat Info's view and drop square, and that a vat holding anything stays put. Run from the mod
-- folder: luajit tests/test_vat.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near, list = H.check, H.near, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules, TP Core's and the mod's action load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local ui = H.installMenus()
function isClient() return false end
function isServer() return false end
function getNumActivePlayers() return 0 end
function getClimateManager()
    return { isUpdated = function() return true end, getTemperature = function() return 16 end, getHumidity = function() return 50 end }
end
local loaders = {}
MapObjects = { OnLoadWithSprite = function(name, handler) loaders[name] = handler end }
local cellSquares = {}
function getCell()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
ISPanel = H.class("ISPanel")
ItemTag = { METAL_BUCKET = "base:metalbucket", TAKE_DIRT = "base:takedirt" }
local function colour() return { getRedFloat = function() return 0.5 end, getGreenFloat = function() return 0.6 end,
    getBlueFloat = function() return 0.7 end } end
Fluid = { Get = function(name) return { name = name, getFluidTypeString = function() return name end, getColor = colour } end }
local given = {}
Actions = { addOrDropItem = function(_, item) table.insert(given, item) end }

local function square(x)
    local s = {}
    function s:getX() return x end
    function s:getY() return 0 end
    function s:getZ() return 0 end
    function s:getObjects() return list({}) end
    function s:isOutside() return true end
    function s:isInARoom() return false end
    function s:getRoom() return nil end
    function s:getBuilding() return nil end
    cellSquares[x .. ",0,0"] = s
    return s
end

-- A Leaching Vat facing south (tile 9) or east (tile 0) at x.
local PREFIX = "traditionalpreservationsalt_01_"
local function vatAt(tile, x)
    local self = { square = square(x), sprites = {}, modData = {} }
    function self:getSprite() return { getName = function() return PREFIX .. tile end } end
    function self:getSquare() return self.square end
    function self:getModData() return self.modData end
    function self:hasModData() return true end
    function self:getObjectIndex() return 0 end
    function self:isOutside() return true end
    function self:getComponent() return nil end
    function self:clearAttachedAnimSprite() self.sprites = {} end
    function self:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return self
end

local inventory = { Remove = function(_, item)
    for i, carried in ipairs(ui.carried) do
        if carried == item then return table.remove(ui.carried, i) end
    end
end }
function inventory:containsRecursive(item)
    for _, carried in ipairs(ui.carried) do if carried == item then return true end end
    return false
end
function inventory:getAllEvalRecurse(test)
    local found = {}
    for _, carried in ipairs(ui.carried) do if test(carried) then table.insert(found, carried) end end
    return list(found)
end
local playerObj = { getInventory = function() return inventory end, isTimedActionInstant = function() return false end }
function getSpecificPlayer() return playerObj end

-- A fluid container holding litres by fluid name, capacity litres at most.
local function newTank(parts, capacity)
    parts = parts or {}
    local tank = { capacity = capacity or 10 }
    local function total()
        local sum = 0
        for _, litres in pairs(parts) do sum = sum + litres end
        return sum
    end
    function tank:parts() return parts end
    function tank:isEmpty() return total() <= 0.0001 end
    function tank:getAmount() return total() end
    function tank:getFreeCapacity() return self.capacity - total() end
    function tank:getSpecificFluidAmount(fluid) return parts[fluid.name] or 0 end
    function tank:isTainted() return (parts.TaintedWater or 0) > 0 end
    function tank:canAddFluid() return true end
    function tank:Empty() parts = {} end
    function tank:addFluid(name, litres) parts[name] = (parts[name] or 0) + litres end
    function tank:removeFluid(litres)
        local all = total()
        for name, amount in pairs(parts) do parts[name] = amount - amount / all * litres end
    end
    return tank
end

local function newItem(fullType, parts)
    local item = { fullType = fullType, modData = {} }
    if fullType:find("^Base.Bucket") or parts then item.tank = newTank(parts) end
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:getContainer() return inventory end
    function item:getWorldItem() return nil end
    function item:getOutermostContainer() return nil end
    function item:isFavorite() return false end
    function item:getTex() return self.fullType .. ".png" end
    function item:getFluidContainer() return self.tank end
    function item:getDisplayName() return self.fullType end
    function item:getName() return self.fullType end
    return item
end
function instanceItem(fullType) return newItem(fullType) end

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltBrine.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltVat.lua")
dofile("42/media/lua/server/TraditionalPreservationSaltWorld.lua")
dofile("42/media/lua/client/TraditionalPreservationSaltVatUI.lua")
local S, World, VatUI = TraditionalPreservationSalt, TraditionalPreservationSaltWorld, TraditionalPreservationSaltVatUI

local function tick(times)
    for _ = 1, times or 30 do H.fire("OnTick") end
end

local function newRecord() return { layers = {}, bed = { litres = 0, brine = 0 }, tub = { litres = 0, brine = 0 } } end
local function bed(sacks)
    local record = newRecord()
    for _ = 1, sacks do S.addSoil(record) end
    return record
end
-- Pours litres (brine of them Brine) and lets it all drain; returns litres and Brine drawn off.
local function leach(record, litres, brine)
    S.pourOnBed(record, litres, brine or 0, S.WATER)
    S.vatNow(record, 0)
    S.vatNow(record, 100)
    local drawn, drawnBrine = S.drawOff(record)
    return drawn, drawnBrine
end

-- The leaching (the numbers put to the user in session 60).
local litres, brine = leach(bed(1), 10)
check("1 sack, 10 L of water: 5 L of Brine in 10 L, as the old charge", near(litres, 10) and near(brine, 5))
local chain = {}
local share = 0
for _ = 1, 3 do
    local _, out = leach(bed(1), 10, share * 10)
    share = out / 10
    table.insert(chain, out)
end
check("re-run over a fresh sack: 5, 8, 10", near(chain[1], 5) and near(chain[2], 8) and near(chain[3], 10))
local deep = bed(3)
_, brine = leach(deep, 10)
check("3 sacks, 10 L of water: saturated, 5 salt left in the soil", near(brine, 10) and near(S.saltLeft(deep), 5))
check("the top layer gave its all, the bottom least", near(deep.layers[1], 0) and deep.layers[3] > deep.layers[2])
_, brine = leach(deep, 10)
check("the next 10 L takes the salt left: 5", near(brine, 5) and near(S.saltLeft(deep), 0))
_, brine = leach(bed(2), 10)
check("2 sacks, 10 L: 8", near(brine, 8))
_, brine = leach(bed(3), 30)
check("3 sacks, 30 L at once: 15 L of Brine in 30", near(brine, 15))
_, brine = leach(bed(3), 10, 1)
check("3 sacks, 10 L of spring brine: saturated", near(brine, 10))
local partial = bed(1)
_, brine = leach(partial, 4)
check("a partial pour takes salt for its litres (4 L: 2), the rest stays in the soil", near(brine, 2)
    and near(S.saltLeft(partial), 3))

local old028 = vatAt(9, 21)
old028.modData.movableData = { [S.VAT_KEY] = { charge = { brine = 0, rest = "Water", startHour = 1 } } }
check("a 0.1.28 vat's charge record starts afresh", #S.vatOf(old028).layers == 0 and S.vatOf(old028).bed.litres == 0)

-- The clock: 5 L an hour; the tub full stops the bed.
local timed = bed(3)
S.pourOnBed(timed, 10, 0, S.WATER)
S.vatNow(timed, 200)
S.vatNow(timed, 201)
check("5 L an hour", near(timed.tub.litres, 5) and near(timed.bed.litres, 5) and near(S.drainHoursLeft(timed), 1))
S.pourOnBed(timed, 30, 0, S.WATER)
check("the bed holds 30 L", near(timed.bed.litres, 30) and S.pourRefusal(timed) == "full")
S.vatNow(timed, 230)
check("the full tub stops it: 30 L in the tub, the rest waits", near(timed.tub.litres, 30) and near(timed.bed.litres, 5)
    and S.drainHoursLeft(timed) == math.huge)
check("no soil while liquid soaks", S.soilRefusal(timed) == "soaking")
check("no pour without soil", S.pourRefusal(newRecord()) == "noSoil")
local full = bed(3)
check("three sacks with salt fill the bed", S.soilRefusal(full) == "full")
leach(full, 30)
check("spent soil is thrown out when new goes on", S.addSoil(full) and #full.layers == 1 and near(S.saltLeft(full), 5))

-- The World: a look a facing; a bare vat shows none.
local PREFIX = "traditionalpreservationsalt_01_"
local Tiles = require "TraditionalPreservationSalt/Tiles"
local south = vatAt(9, 1)
loaders[PREFIX .. "9"](south)
tick()
check("a bare vat shows nothing over it", #south.sprites == 0)
S.addSoil(S.vatOf(south))
tick()
check("dry soil shows, facing south", south.sprites[1] == PREFIX .. (Tiles.VAT_LOOKS["dry:empty"] + 1))
S.pourOnBed(S.vatOf(south), 10, 0, S.WATER)
S.vatOf(south).hour = H.hours
H.setHours(H.hours + 1)
tick()
check("wet soil and some brine in the tub", south.sprites[1] == PREFIX .. (Tiles.VAT_LOOKS["wet:low"] + 1))
local east = vatAt(0, 3)
S.addSoil(S.vatOf(east))
loaders[PREFIX .. "0"](east)
tick()
check("the east face has its own", east.sprites[1] == PREFIX .. Tiles.VAT_LOOKS["dry:empty"])

-- A vat built before 0.1.28: its saved crafting window goes, its old overlay style is cleared, once.
ComponentType = { UiConfig = "UiConfig", CraftLogic = "CraftLogic", Resources = "Resources",
    SpriteOverlayConfig = "SpriteOverlayConfig" }
local removed = {}
GameEntityFactory = { RemoveComponentType = function(entity, componentType)
    entity.components[componentType] = nil
    table.insert(removed, componentType)
end }
local old = vatAt(9, 11)
old.components = { UiConfig = { isUiEnabled = function() return true end }, CraftLogic = {}, Resources = {},
    SpriteOverlayConfig = { clearStyle = function(self) self.cleared = (self.cleared or 0) + 1 end } }
function old:getComponent(componentType) return self.components[componentType] end
function old:getX() return 11 end
function old:getY() return 0 end
function old:getZ() return 0 end
local overlay = old.components.SpriteOverlayConfig
loaders[PREFIX .. "9"](old)
tick()
tick()
check("an old vat loses its crafting window", old.components.UiConfig == nil and old.components.CraftLogic == nil
    and old.components.Resources == nil and #removed == 3)
check("its old overlay is cleared once", overlay.cleared == 1)
local fresh = vatAt(9, 13)
fresh.components = { UiConfig = { isUiEnabled = function() return false end } }
function fresh:getComponent(componentType) return self.components[componentType] end
loaders[PREFIX .. "9"](fresh)
tick()
check("a new vat keeps its UiConfig (window off)", fresh.components.UiConfig ~= nil and #removed == 3)
ComponentType, GameEntityFactory = nil, nil

-- The menu: an empty vat, two sacks and a bucket of water carried.
local empty = vatAt(9, 5)
local function menuFor(station)
    local context = H.menu()
    VatUI.addMenu(context, playerObj, station)
    return context, context.options[1].subOption
end
local function named(menu, prefix)
    for _, option in ipairs(menu.options) do
        if option.name:sub(1, #prefix) == prefix then return option end
    end
end
local function choose(option) option.onSelect(option.target, unpack(option.args)) end
local function runQueued()
    local queued = ui.queued
    ui.queued = {}
    for _, action in ipairs(queued) do
        action.setActionAnim = function() end
        if action:isValid() then
            action:start()
            action:complete()
        end
    end
end

local water = newItem("Base.BucketEmpty", { Water = 10 })
local sacks = { newItem(S.SACK_ITEM), newItem(S.SACK_ITEM) }
ui.carried = { sacks[1], sacks[2], water }
local context, menu = menuFor(empty)
check("the vat's own entry, with its icon", context.options[1].name == "Leaching Vat"
    and context.options[1].iconTexture == "media/textures/Item_LeachingVat.png")
check("the status row first, greyed", menu.options[1].isDisabled and menu.options[1].name:find("No soil", 1, true) ~= nil)
check("then its Info row, the station's full name, and the same at the bottom of the main menu",
    menu.options[2].name == "Leaching Vat Info" and context.options[2].name == "Leaching Vat Info")
local pour = named(menu, "Pour onto the Soil")
check("Pour onto the Soil greyed: soil first", pour.isDisabled and pour.toolTip.description == "Put soil in the vat first.")
check("Draw Off Brine greyed: the tub is empty", named(menu, "Draw Off Brine").isDisabled)
check("every row has an icon", (function()
    for _, option in ipairs(menu.options) do if not option.iconTexture then return false end end
    return true
end)())

given = {}
choose(named(menu, "Add Saline Soil"))
check("the sack is moved into the inventory before the walk", #ui.queued == 1 and ui.moved[#ui.moved] == sacks[1])
runQueued()
check("soil on the bed, the empty sack back", #S.vatOf(empty).layers == 1 and #given == 1
    and given[1]:getFullType() == "Base.EmptySandbag")
local function canPickUp() return ISMoveableSpriteProps.canPickUpMoveable({}, playerObj, empty:getSquare(), empty) end
check("a vat holding soil can't be picked up (no station moves mid-process)", canPickUp() == false)

context, menu = menuFor(empty)
pour = named(menu, "Pour onto the Soil")
check("Pour onto the Soil lists the bucket of water", not pour.isDisabled and pour.subOption.options[1].name:find("10.0", 1, true))
choose(pour.subOption.options[1])
runQueued()
check("poured: 10 L on the bed, the bucket empty", near(S.vatOf(empty).bed.litres, 10) and water.tank:isEmpty())
context, menu = menuFor(empty)
check("no soil while it soaks", named(menu, "Add Saline Soil").isDisabled)

-- Vat Info's view and drop square.
H.setHours(H.hours + 1)
local record = S.vatNow(S.vatOf(empty), H.hours)
local view = VatUI.view(record, "Open")
check("Vat Info: soil, soaking and tub bars", near(view.soakShare, 5 / 30) and near(view.tubShare, 5 / 30)
    and view.soakText:find("5.0 L", 1, true) and view.tubText:find("2.5 L of Brine", 1, true))
local judged = VatUI.dropJudge(record, { newItem(S.SACK_ITEM), newItem("Base.BucketEmpty", { Water = 5 }), newItem("Base.Plank") })
check("the drop square: no soil while it soaks, but pours, and says why not the plank", #judged.take == 1
    and judged.take[1]:getFullType() == "Base.BucketEmpty" and judged.refused ~= nil)
judged = VatUI.dropJudge(newRecord(), { newItem(S.SACK_ITEM), newItem("Base.BucketEmpty", { Water = 5 }) })
check("on an empty vat, a sack and a pour together: soil first", #judged.take == 2
    and judged.take[1]:getFullType() == S.SACK_ITEM)
judged = VatUI.dropJudge(newRecord(), { newItem(S.SACK_ITEM), newItem("Base.BucketEmpty", { Water = 5 }) }, "soil")
check("the soil's cells take the sack, not the bucket, saying where it goes", #judged.take == 1 and judged.cells == 1
    and judged.refused == "Water and brine go on the soaking bed.")
local soiled = newRecord()
S.addSoil(soiled)
judged = VatUI.dropJudge(soiled, { newItem(S.SACK_ITEM), newItem("Base.BucketEmpty", { Water = 6 }) }, "pour")
check("the soaking bed takes the bucket, filling a fifth of it", #judged.take == 1 and judged.cells == 0
    and near(judged.adds, 6 / 30) and judged.refused == "The soil takes Sacks of Saline Soil.")

-- Vat Info's band and holdings.
local function bandOf(r)
    local word, text = VatUI.band(VatUI.view(r, "Open"))
    return word:match("VatBand(%a+)$"), text
end
check("an empty vat: empty", bandOf(newRecord()) == "Empty")
check("soil, nothing on it: ready", bandOf(soiled) == "Ready")
local word, text = bandOf(record)
check("soaking through: leaching, the rate and sacks", word == "Leaching" and text == "5 L/h through 1 sacks of soil")
local full = newRecord()
S.addSoil(full)
full.bed.litres, full.tub.litres, full.tub.brine = 5, S.TUB_LITRES, 10
check("the tub full stops it: tub full first", bandOf(full) == "TubFull")
full.bed.litres = 0
word, text = bandOf(full)
check("the bed drained, brine in the tub", word == "Brine" and text == "30.0 L in the tub: draw it off")
local spent = newRecord()
S.addSoil(spent)
spent.layers[1] = 0
check("spent soil: spent", bandOf(spent) == "Spent")
spent.layers = { S.SACK_SALT, 0 }
spent.bed.litres = 2
check("spent soil stays while liquid soaks", S.spentLayers(spent) == 1 and S.throwOutSpent(spent) == 0)
spent.bed.litres = 0
check("thrown out: only the spent soil goes", S.throwOutSpent(spent) == 1 and #spent.layers == 1 and spent.layers[1] == S.SACK_SALT)
local holdings = VatUI.holdings(VatUI.view(record, "Open"), record)
check("holdings as the liquid goes: the bed's tank, the soil's cells, the tub's tank", #holdings == 3
    and holdings[1].kind == "tank" and holdings[2].kind == "cells" and holdings[2].cells == 3 and holdings[2].filled == 1
    and holdings[3].kind == "tank")
check("both arrows carry the rate while it drains", holdings[1].arrow == "5 L/h" and holdings[2].arrow == "5 L/h"
    and holdings[1].under:find("through in", 1, true) ~= nil)
check("the tub says what all of it boils to", holdings[3].amount == "5.0 / 30 L" and holdings[3].under == "boils to "
    .. S.saltFor(record.tub.brine) .. " salt")
local drip = newRecord()
drip.tub.litres, drip.tub.brine = 0.02, 0.015
holdings = VatUI.holdings(VatUI.view(drip, "Open"), drip)
check("a drip that reads 0.0 L says nothing", holdings[3].amount == "0.0 / 30 L" and holdings[3].state == nil and holdings[3].under == nil)
check("and can't be drawn off", not S.canDrawOff(drip) and not VatUI.view(drip, "Open").canDraw and bandOf(drip) == "Empty")
drip.tub.litres, drip.tub.brine = 1, 0.75
holdings = VatUI.holdings(VatUI.view(drip, "Open"), drip)
check("a strong litre is too little to boil yet", holdings[3].under == "too little to boil yet")
holdings = VatUI.holdings(VatUI.view(record, "Open"), record)
holdings = VatUI.holdings(VatUI.view(soiled, "Open"), soiled)
check("nothing draining: plain arrows", holdings[1].arrow == "" and holdings[2].arrow == "")

-- Drawing off what has dripped so far.
local catch = newItem("Base.BucketEmpty")
ui.carried = { catch }
context, menu = menuFor(empty)
local draw = named(menu, "Draw Off Brine")
check("Draw Off Brine lists the empty bucket", not draw.isDisabled and draw.subOption.options[1] ~= nil)
choose(draw.subOption.options[1])
runQueued()
check("it draws off what has dripped: 5 L, 2.5 of Brine", near(catch.tank:getAmount(), 5)
    and near(catch.tank:parts().Brine, 2.5) and near(S.vatOf(empty).tub.litres, 0))
H.setHours(H.hours + 2)
S.vatNow(S.vatOf(empty), H.hours)
check("the bed spent and drained, the tub holding the rest: still can't be picked up", canPickUp() == false)
S.drawOff(S.vatOf(empty))
check("spent soil alone doesn't hold it", canPickUp() ~= false)
check("and no translator warnings", #H.textWarnings == 0)

-- Frost (user, session 76): at -2 C and below where the vat stands, the bed and the drip wait; a basement never freezes.
local Frost = require "TraditionalPreservationCore/Frost"
local frostHour = math.max(Frost.ledger().lastHour, 300)
local function frostWeather(hours, celsius)
    for _ = 1, hours * 6 do
        frostHour = frostHour + 1 / 6
        Frost.recordWeather(frostHour, celsius)
    end
end
frostWeather(1, 5)
local outside, cellar = bed(3), bed(3)
for _, vat in ipairs({ outside, cellar }) do
    S.pourOnBed(vat, 20, 0, S.WATER)
    S.vatNow(vat, frostHour, "Open")
end
S.vatNow(cellar, frostHour, "Basement")
check("the first look with a place starts its frost record", outside.frost ~= nil and outside.frost.age == 0)
frostWeather(2, -5)
S.vatNow(outside, frostHour, "Open")
S.vatNow(cellar, frostHour, "Basement")
check("two hours at -5 C in the open: nothing drips", near(outside.tub.litres, 0) and near(outside.bed.litres, 20)
    and S.vatFrozen(outside))
check("in a basement it drips on: 10 L", near(cellar.tub.litres, 10, 0.01) and not S.vatFrozen(cellar))
frostWeather(1, -1)
S.vatNow(outside, frostHour, "Open")
check("-1 C doesn't freeze it: an hour, 5 L", near(outside.tub.litres, 5, 0.01) and not S.vatFrozen(outside))
check("its freezing point is -2 C", S.VAT_FREEZE_C == -2)

check("Vat Info: frozen with liquid on the bed reads Frozen first", (function()
    local VatUIx = TraditionalPreservationSaltVatUI
    local word = VatUIx.band(VatUIx.view(outside, "Open"))
    frostWeather(1, -5)
    S.vatNow(outside, frostHour, "Open")
    local frozenWord = VatUIx.band(VatUIx.view(outside, "Open"))
    return word:find("VatBandLeaching") ~= nil and frozenWord:find("VatBandFrozen") ~= nil
end)())

H.done()
