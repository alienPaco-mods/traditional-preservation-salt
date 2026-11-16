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
