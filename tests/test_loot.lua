-- Checks where a Bag of Salt is found (TraditionalPreservationSaltLoot.lua): added to the restaurant kitchen shelves
-- very rarely (a Sledgehammer's weights) and to a house's dry food rarer still, once each, and the lists are ones the game has. Run from the mod
-- folder: luajit tests/test_loot.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
local check = H.check

ProceduralDistributions = { list = {
    StoreKitchenSauce = { items = { "Salt", 4 } },
    StoreKitchenBaking = { items = { "Flour", 10 } },
    KitchenDryFood = { items = { "Salt", 20 } },
    SomethingElse = { items = { "Salt", 1 } },
} }
package.preload["Items/ProceduralDistributions"] = function() end
dofile("42/media/lua/server/TraditionalPreservationSaltLoot.lua")

local BAG = "TraditionalPreservationSalt.BagOfSalt"
local function weightOf(listName)
    local items, found = ProceduralDistributions.list[listName].items, nil
    for i = 1, #items, 2 do
        if items[i] == BAG then check(listName .. " has the bag once", found == nil); found = items[i + 1] end
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

-- The three lists are ones the game defines (skipped without the game's files).
local game = os.getenv("TP_GAME") or (os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/ProjectZomboid")
local file = io.open(game .. "/projectzomboid/media/lua/server/Items/ProceduralDistributions.lua")
if file then
    local text = file:read("*a"); file:close()
    for _, name in ipairs({ "StoreKitchenSauce", "StoreKitchenBaking", "KitchenDryFood" }) do
        check(name .. " is a vanilla list", text:find("\n\t" .. name .. " = {", 1, true) ~= nil)
    end
end
H.done()
