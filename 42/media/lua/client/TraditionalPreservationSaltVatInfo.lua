-- Traditional Preservation (Salt): the Leaching Vat's info block in its crafting window (TP Core's StationInfo): its
-- place, a bar for the running charge with the time left, and what the brine comes out at. Leaching goes by the
-- plain clock, so there is no temperature or rate.
require "TraditionalPreservationSaltBrine"
local UI = require "TraditionalPreservationCore/UI"
local StationInfo = require "TraditionalPreservationCore/StationInfo"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationSalt/Tiles"
local S = TraditionalPreservationSalt

local KEY = "IGUI_TraditionalPreservationSalt_"
local VATS = {}
for _, name in ipairs(Tiles.STATIONS) do VATS[name] = true end

-- The block for a vat; nil for anything else.
local function vatInfo(entity)
    local sprite = instanceof(entity, "IsoObject") and entity:getSprite()
    if not (sprite and VATS[sprite:getName()]) then return nil end
    local contents = StationInfo.contents(entity)
    if not contents then return nil end
    local batches = {}
    for _, batch in ipairs(contents.batches) do
        local hours = batch.data:getRecipe():getTime() / 3600
        table.insert(batches, { name = getText(KEY .. "InfoLeaching"), progress = batch.progress,
            hoursLeft = (1 - batch.progress) * hours })
    end
    local notes = {}
    for _, item in ipairs(contents.waiting) do
        if item:getFullType() == S.CHARGE_ITEM then
            local after = S.afterLeach((S.notedBrine(item, 0)))
            table.insert(notes, UI.say(KEY .. "InfoChargeOut", string.format("%.0f", after), S.strengthText(after) or ""))
        end
    end
    for _, item in ipairs(contents.finished) do
        if item:getFullType() == S.BRINE_ITEM then
            local brine = S.notedBrine(item, S.OLD_BRINE_LITRES)
            table.insert(notes, UI.say(KEY .. "InfoBucket", string.format("%.0f", brine), S.strengthText(brine) or ""))
        end
    end
    table.insert(notes, getText(KEY .. "InfoClock"))
    return StationInfo.block({ place = Weather.placeOf(entity), batches = batches,
        waiting = #contents.waiting, finished = #contents.finished, notes = notes })
end

StationInfo.add(vatInfo)
