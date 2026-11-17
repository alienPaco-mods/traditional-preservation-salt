-- Traditional Preservation (Salt): where a Bag of Salt is found. A bag is 50 uses of salt, five shakers, so finding one
-- is meant to be an event like vanilla's Sledgehammer (0.01 to 0.1 in its lists) or Generator Magazine (0.1 to 2): a
-- restaurant kitchen's sauce and baking shelves hold one very rarely, a house's kitchen dry food rarer still. Against
-- vanilla's Salt shaker (10 uses) at 4 on the sauce shelf and 20 in dry food, a bag at 0.05 is 1 in 80 of the shaker's
-- chance and 1 in 2000 at 0.01. Each list is one a room rolls (Distributions.lua): restaurant, diner and chain
-- kitchens share StoreKitchenSauce and StoreKitchenBaking.
require "TraditionalPreservationSalt"
local Loot = require "TraditionalPreservationCore/Loot"

Loot.add(TraditionalPreservationSalt.BAG_ITEM, {
    StoreKitchenSauce = 0.05,
    StoreKitchenBaking = 0.05,
    KitchenDryFood = 0.01,
})

-- A Salt Lick Map is as rare as vanilla's Generator Magazine (0.1 to 2 in most of its lists): 1 where people who
-- know the woods keep papers (a ranger station's desk and magazines, a camping store's books), 0.5 in a library,
-- and 0.1 in an office desk, which there are many of.
Loot.add(TraditionalPreservationSalt.MAP_ITEM, {
    RangerDesk = 1,
    RangerMagazines = 1,
    CampingStoreBooks = 1,
    LibraryBooks = 0.5,
    LibraryMagazines = 0.5,
    OfficeDesk = 0.1,
})

-- A found map rings the lick nearest where it was found, not where it is first read, so carrying it home unread
-- doesn't turn it into a map of the home lick.
local function onFillContainer(_, _, container)
    if not instanceof(container, "ItemContainer") then return end
    local square = container:getSourceGrid()
    if not square then return end
    local S = TraditionalPreservationSalt
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == S.MAP_ITEM then
            S.pickMapLick(item:getModData(), square:getX(), square:getY())
        end
    end
end

Events.OnFillContainer.Add(onFillContainer)
