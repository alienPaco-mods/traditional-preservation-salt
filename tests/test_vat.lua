-- Checks the Leaching Vat with stand-ins for the engine: the charge's clock on the plain game clock, the World's
-- overlay, the right-click menu (status, Info, Put In the Charge, Take Out the Brine, Take Out the Charge) and its hand
-- jobs (TPLeachingVat), what Vat Info shows, its drop square, and that a vat holding a charge stays put. Run from the
-- mod folder: luajit tests/test_vat.lua
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
Fluid = { Get = function(name) return { name = name, getFluidTypeString = function() return name end } end }
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

-- A fluid container holding litres by fluid name.
local function newTank()
    local parts = {}
    local tank = { parts = function() return parts end }
    function tank:Empty() parts = {} end
    function tank:addFluid(name, litres) parts[name] = (parts[name] or 0) + litres end
    return tank
end

local function newItem(fullType)
    local item = { fullType = fullType, modData = {} }
    if fullType:find("^Base.Bucket") then item.tank = newTank() end
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:getContainer() return inventory end
    function item:getWorldItem() return nil end
    function item:getOutermostContainer() return nil end
    function item:isFavorite() return false end
    function item:getTex() return self.fullType .. ".png" end
    function item:getFluidContainer() return self.tank end
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

-- A charge of spring brine (1 L of Brine, the rest tainted), made in a forged bucket.
local function newCharge(brine)
    local charge = newItem(S.CHARGE_ITEM)
    charge.modData[S.BRINE_KEY] = brine or 1
    charge.modData[S.REST_KEY] = S.TAINTED
    charge.modData["condition:tpContainer"] = "Base.BucketForged"
    return charge
end

-- The record: one charge, two hours by the clock.
local record = {}
local charge = S.putCharge(record, newCharge(), H.hours)
check("a charge goes in", charge ~= nil and S.vatLook(record, H.hours) == "leaching")
check("one at a time", S.putCharge(record, newCharge(), H.hours) == nil)
check("only a Leaching Charge", S.putCharge({}, newItem(S.BRINE_ITEM), H.hours) == nil)
check("an hour in it is half done", near(S.chargeProgress(charge, H.hours + 1), 0.5)
    and near(S.chargeHoursLeft(charge, H.hours + 1), 1))
check("two hours in it is done", S.vatLook(record, H.hours + S.LEACH_HOURS) == "done")

-- The World: the leaching sprite, then the done one, for each facing; none when empty.
local south = vatAt(9, 1)
loaders[PREFIX .. "9"](south)
tick()
check("an empty vat shows nothing over it", #south.sprites == 0)
S.putCharge(S.vatOf(south), newCharge(), H.hours)
tick()
check("leaching shows the wet charge", table.concat(south.sprites, " ") == PREFIX .. "10")
H.setHours(H.hours + S.LEACH_HOURS)
tick()
check("done shows the bucket of brine", table.concat(south.sprites, " ") == PREFIX .. "11")
local east = vatAt(0, 3)
S.putCharge(S.vatOf(east), newCharge(), H.hours)
loaders[PREFIX .. "0"](east)
tick()
check("the east face has its own", table.concat(east.sprites, " ") == PREFIX .. "2")

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

-- The menu: an empty vat, a charge carried.
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

local carried = newCharge(4)
ui.carried = { carried }
local context, menu = menuFor(empty)
check("the vat's own entry, with its icon", context.options[1].name == "Leaching Vat"
    and context.options[1].iconTexture == "media/textures/Item_LeachingVat.png")
check("the status row first, greyed: what it holds", menu.options[1].name == "Empty" and menu.options[1].isDisabled)
check("then Vat Info, and Info at the bottom of the main menu", menu.options[2].name == "Vat Info"
    and context.options[2].name == "Vat Info")
local put = named(menu, "Put In the Charge")
check("Put In the Charge says what the brine comes out at", put and not put.isDisabled
    and put.toolTip.description:find("9 L of Brine", 1, true) ~= nil)
local takeBrine = named(menu, "Take Out the Brine")
check("Take Out the Brine is there, greyed", takeBrine and takeBrine.isDisabled)
check("no Take Out the Charge on an empty vat", named(menu, "Take Out the Charge") == nil)
check("every row has an icon", (function()
    for _, option in ipairs(menu.options) do if not option.iconTexture then return false end end
    return true
end)())

choose(put)
check("the charge is moved into the inventory before the walk", #ui.queued == 1 and ui.moved[#ui.moved] == carried)
runQueued()
check("it is in the vat, gone from the hands", S.vatOf(empty).charge ~= nil and #ui.carried == 0)
local function canPickUp() return ISMoveableSpriteProps.canPickUpMoveable({}, playerObj, empty:getSquare(), empty) end
check("a vat holding a charge can't be picked up (no station moves mid-process)", canPickUp() == false)

-- Leaching: the status, Vat Info's view, the drop square.
H.setHours(H.hours + 0.5)
context, menu = menuFor(empty)
check("the status says how far and how long", menu.options[1].name:find("A Leaching Charge: 25%", 1, true) ~= nil)
local back = named(menu, "Take Out the Charge")
check("Take Out the Charge while it leaches", back and not back.isDisabled)
local view = VatUI.view(S.vatOf(empty), "Open")
check("Vat Info: a bar a quarter full and the brine it comes out at", near(view.progress, 0.25)
    and view.brineText:find("9 L of Brine", 1, true) ~= nil)
local judged = VatUI.dropJudge(S.vatOf(empty), { newCharge() })
check("the drop square refuses while it holds one", #judged.take == 0)
judged = VatUI.dropJudge({}, { newItem(S.BRINE_ITEM), newCharge(), newCharge() })
check("on an empty vat it takes one charge, saying the rest stay", #judged.take == 1
    and judged.take[1]:getFullType() == S.CHARGE_ITEM and judged.refused ~= nil)

-- Taking out: early gives the charge back, done the bucket.
given = {}
choose(back)
runQueued()
check("taken out early, the charge comes back as it went in", #given == 1 and given[1]:getFullType() == S.CHARGE_ITEM
    and given[1].modData[S.BRINE_KEY] == 4 and S.vatOf(empty).charge == nil)
check("an empty vat can be picked up", canPickUp() ~= false)
ui.carried = { given[1] }
VatUI.put(playerObj, empty, given[1])
runQueued()
H.setHours(H.hours + S.LEACH_HOURS)
given = {}
context, menu = menuFor(empty)
takeBrine = named(menu, "Take Out the Brine")
check("done, Take Out the Brine is open", not takeBrine.isDisabled and named(menu, "Take Out the Charge") == nil)
choose(takeBrine)
runQueued()
local bucket = given[1]
check("it gives the forged bucket back, holding the brine", #given == 1 and bucket:getFullType() == "Base.BucketForged"
    and near(bucket.tank.parts().Brine, 9) and near(bucket.tank.parts().TaintedWater, 1))
check("and no translator warnings", #H.textWarnings == 0)

H.done()
