-- Traditional Preservation (Salt): brine on the heat, and its strength in the tooltip. A bucket of brine moved into
-- a fire, stove or oven turns into the boiling item through TP Core's Transfer hook, the only way to boil brine
-- (every way onto the heat goes through it: drag, the loot window, Put in; INGAME_PASS 89).
require "TraditionalPreservationSaltBrine"
require "ISUI/ISToolTipInv"
local Transfer = require "TraditionalPreservationCore/Transfer"
local S = TraditionalPreservationSalt

Transfer.after(function(action, item)
    S.onMoved(item, action.srcContainer, action.destContainer)
end)

-- The strength line for an item: a metal bucket of brine, or the boiling item. Nil for anything else, and for what
-- isn't an inventory item (the pour window's tooltip holds something else).
local function strengthLine(item)
    if not instanceof(item, "InventoryItem") then return nil end
    if item:getFullType() == S.BRINE_ITEM then return S.strengthText((S.notedBrine(item, S.OLD_BRINE_LITRES))) end
    if not item:hasTag(ItemTag.METAL_BUCKET) then return nil end
    local brine = S.boilableBrine(item:getFluidContainer())
    return brine and S.strengthText(brine)
end

-- The engine draws an item's Tooltip text through Translator.getText, so the line goes in as that text for the one
-- draw and comes out again (setTooltip keeps it in modData, which would otherwise be saved). Wraps
-- ISToolTipInv.render: compare with vanilla after a game update.
local vanillaRender = ISToolTipInv.render
function ISToolTipInv:render()
    local item = self.item
    local line = item and strengthLine(item)
    if not line then return vanillaRender(self) end
    local own = item:getTooltip()
    item:setTooltip(own and (line .. " " .. getText(own)) or line)
    local ok, err = pcall(vanillaRender, self)
    item:setTooltip(own)
    item:getModData().Tooltip = nil
    if not ok then error(err) end
end
