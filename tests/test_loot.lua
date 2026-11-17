-- Checks where a Bag of Salt is found (TraditionalPreservationSaltLoot.lua): added to the restaurant kitchen shelves
-- very rarely (a Sledgehammer's weights) and to a house's dry food rarer still, once each, and the lists are ones the game has. Run from the mod
-- folder: luajit tests/test_loot.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
local check = H.check

local MAP_LISTS = { RangerDesk = 1, RangerMagazines = 1, CampingStoreBooks = 1, LibraryBooks = 0.5,
    LibraryMagazines = 0.5, OfficeDesk = 0.1 }
ProceduralDistributions = { list = {
    StoreKitchenSauce = { items = { "Salt", 4 } },
    StoreKitchenBaking = { items = { "Flour", 10 } },
    KitchenDryFood = { items = { "Salt", 20 } },
    SomethingElse = { items = { "Salt", 1 } },
} }
for name in pairs(MAP_LISTS) do ProceduralDistributions.list[name] = { items = { "Notepad", 10 } } end
-- The loot file names the bag and map by the mod's constants, and hands a found map to pickMapLick (test_map
-- checks the pick itself).
local picked = {}
TraditionalPreservationSalt = { BAG_ITEM = "TraditionalPreservationSalt.BagOfSalt",
    MAP_ITEM = "TraditionalPreservationSalt.SaltLickMap",
    pickMapLick = function(mapData, x, y) table.insert(picked, { mapData = mapData, x = x, y = y }) end }
package.preload["TraditionalPreservationSalt"] = function() return true end
H.installEvents()
dofile("42/media/lua/server/TraditionalPreservationSaltLoot.lua")

local BAG, MAP = TraditionalPreservationSalt.BAG_ITEM, TraditionalPreservationSalt.MAP_ITEM
local function weightOf(listName, item)
    item = item or BAG
    local items, found = ProceduralDistributions.list[listName].items, nil
    for i = 1, #items, 2 do
        if items[i] == item then check(listName .. " has " .. item .. " once", found == nil); found = items[i + 1] end
    end
    return found
end

local sauce, baking, house = weightOf("StoreKitchenSauce"), weightOf("StoreKitchenBaking"), weightOf("KitchenDryFood")
check("sauce shelf weight", sauce == 0.05)
check("baking shelf weight", baking == 0.05)
check("house dry food weight", house == 0.01)
check("house rarer than restaurant", house < sauce)
check("a bag is five shakers of salt, so under a tenth of the shaker's weight there", sauce * 5 < 4 / 10)
check("the same in a house", house * 5 < 20 / 10)
check("other lists untouched", weightOf("SomethingElse") == nil)
check("vanilla entries kept", ProceduralDistributions.list.StoreKitchenSauce.items[1] == "Salt")

-- The Salt Lick Map: the Generator Magazine's rarity (0.1 to 2), and never in a kitchen.
for name, weight in pairs(MAP_LISTS) do
    check("map weight in " .. name, weightOf(name, MAP) == weight)
    check("map no commoner than the Generator Magazine in " .. name, weight >= 0.1 and weight <= 2)
end
check("no map in kitchens", weightOf("StoreKitchenSauce", MAP) == nil and weightOf("KitchenDryFood", MAP) == nil)
check("no bag in the map's lists", weightOf("RangerDesk") == nil)

-- A filled container hands each map in it the container's square; other items and spotless containers are left.
function instanceof(object, name) return type(object) == "table" and object.class == name end
local function item(fullType)
    local modData = {}
    return { getFullType = function() return fullType end, getModData = function() return modData end }
end
local function container(square, list)
    return { class = "ItemContainer", getSourceGrid = function() return square end,
        getItems = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
end
local square = { getX = function() return 6890 end, getY = function() return 6019 end }
local map, notepad = item(MAP), item("Base.Notepad")
H.fire("OnFillContainer", "camping", "shelves", container(square, { notepad, map }))
check("a found map gets the spot it was found at", #picked == 1 and picked[1].mapData == map:getModData()
    and picked[1].x == 6890 and picked[1].y == 6019)
H.fire("OnFillContainer", "car", "glovebox", container(nil, { item(MAP) }))
H.fire("OnFillContainer", "camping", "shelves", { class = "ItemPickerContainer" })
check("no spot, no pick: the map picks when first read", #picked == 1)

-- The lists are ones the game defines (skipped without the game's files).
local game = os.getenv("TP_GAME") or (os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/ProjectZomboid")
local file = io.open(game .. "/projectzomboid/media/lua/server/Items/ProceduralDistributions.lua")
if file then
    local text = file:read("*a"); file:close()
    local names = { "StoreKitchenSauce", "StoreKitchenBaking", "KitchenDryFood" }
    for name in pairs(MAP_LISTS) do table.insert(names, name) end
    for _, name in ipairs(names) do
        -- Most lists are tab-indented, the ranger ones by spaces.
        check(name .. " is a vanilla list", text:find("\n[ \t]+" .. name .. " = {") ~= nil)
    end
end
H.done()
