-- Traditional Preservation (Salt): brine on the heat, and its strength in the tooltip. A bucket of brine moved into
-- a fire, stove or oven that is on turns into the boiling item through TP Core's Transfer hook (every way onto the
-- heat goes through it: drag, the loot window, Put in); one put into a cold heat turns once the heat comes on (S.boilIn).
require "TraditionalPreservationSaltBrine"
local Transfer = require "TraditionalPreservationCore/Transfer"
local ItemTooltip = require "TraditionalPreservationCore/ItemTooltip"
local S = TraditionalPreservationSalt

Transfer.after(function(action, item)
    S.onMoved(item, action.srcContainer, action.destContainer)
end)

-- The strength line for an item: a metal bucket of brine, or the boiling item. Nil for anything else, and for what
-- isn't an inventory item (the pour window's tooltip holds something else).
local function strengthLine(item)
    if not instanceof(item, "InventoryItem") then return nil end
    if item:getFullType() == S.BRINE_ITEM then return S.strengthText((S.notedBrine(item))) end
    if not item:hasTag(ItemTag.METAL_BUCKET) then return nil end
    local brine = S.boilableBrine(item:getFluidContainer())
    return brine and S.strengthText(brine)
end

-- Before the item's own text, on its line (TP Core's ItemTooltip, the one wrap of the tooltip's draw).
ItemTooltip.add(strengthLine, { sameLine = true })
