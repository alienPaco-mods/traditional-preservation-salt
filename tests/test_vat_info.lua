-- Checks the Leaching Vat's info block (TP Core's StationInfo) with stand-ins for the engine. Run from the mod folder:
-- luajit tests/test_vat_info.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, list = H.check, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The mod's own modules and TP Core's load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") then return realRequire(name) end
end

-- Engine stand-ins
ComponentType = { Resources = "Resources", CraftLogic = "CraftLogic" }
ResourceIO = { Input = "Input", Output = "Output" }
ResourceType = { Item = "Item" }
ArrayList = { new = function() return list({}) end }
function getPlayer() return {} end
function instanceof(_, class) return class == "IsoObject" end
CraftLogicUILogic = {
    new = function(_, _, logic)
        return { getCraftLogic = function() return logic end, getItemsInProgress = function() return logic.inProgress end }
    end,
}
-- What TP Core's StationInfo and InfoWindow derive from; the vat's provider is kept here instead of hooked.
ISPanel = H.class("ISPanel")
ISCollapsableWindow = H.class("ISCollapsableWindow")
local vatInfo
require("TraditionalPreservationCore/StationInfo").add = function(provider) vatInfo = provider end

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltBrine.lua")
dofile("42/media/lua/client/TraditionalPreservationSaltVatInfo.lua")
local S = TraditionalPreservationSalt

local function item(fullType, brine)
    local modData = { [S.BRINE_KEY] = brine }
    return { getFullType = function() return fullType end, getModData = function() return modData end }
end

-- A vat in the open with a running charge a quarter through, one charge of 6 L of brine waiting and a bucket of
-- 8 L done.
local function vat(sprite, inProgress, waiting, finished)
    local logic = { inProgress = inProgress }
    function logic:getInputsGroupName() return "in" end
    function logic:getOutputsGroupName() return "out" end
    function logic:getProgress(data) return data.progress end
    local resources = {}
    function resources:getResourcesFromGroup(group)
        local items = group == "in" and waiting or finished
        return list({ { getStoredItems = function() return list(items) end } })
    end
    local square = { getZ = function() return 0 end, isOutside = function() return true end }
    local object = {}
    function object:getComponent(kind) return kind == "Resources" and resources or logic end
    function object:getSprite() return { getName = function() return sprite end } end
    function object:getSquare() return square end
    return object
end

local running = { progress = 0.25 }
function running:getRecipe() return { getTime = function() return 7200 end } end
local block = vatInfo(vat("traditionalpreservationsalt_01_9", { [running] = { charge = 1 } },
    { item(S.CHARGE_ITEM, 6) }, { item(S.BRINE_ITEM, 8) }))
check("the vat's place, and no temperature", #block.rows == 1 and block.rows[1][2] == "Open air")
check("the running charge's bar by the clock", #block.bars == 1 and block.bars[1].text == "Leaching"
    and block.bars[1].value == "25%, 0 d 2 h left")
check("what waits and what is done, then the clock note", table.concat(block.notes, " | ") ==
    "Loaded and not started: 1 (press Craft) | Finished and waiting to be taken: 1 | "
    .. "The charge waiting comes out at 9 L of Brine in the bucket: Strong brine: boils to 9 salt. | "
    .. "The bucket holds 8 L of Brine: Strong brine: boils to 8 salt. | "
    .. "Leaching goes by the clock, rain or shine.", table.concat(block.notes, " | "))
check("anything else gets no block", vatInfo(vat("traditionalpreservationsalt_01_1", {}, {}, {})) == nil)
H.done()
