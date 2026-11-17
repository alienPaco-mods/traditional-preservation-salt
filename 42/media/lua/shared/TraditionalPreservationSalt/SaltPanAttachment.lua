-- Traditional Preservation (Salt): the salt pan as TP Core's Stone Hearth attachment (Fire.attach), the first from
-- outside Core. Its rules are SaltPan's; this file registers it: Fit Salt Pan beds the pan in 2 Clay on the stone with a
-- mason's trowel (the clay is lost on Remove), its whole-hearth tiles in Salt's tileset (StoneHearth.fittedTiles), its
-- look, sprite and overlay (the brine, tinted), and its heating by the fire. Its menu and Info rows are SaltPanUI's.
-- The forge recipe is taught by the same smithing magazine as the Forged Cauldron, or researched from the pan.
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Station = require "TraditionalPreservationCore/Station"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Recipes = require "TraditionalPreservationCore/Recipes"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local Tiles = require "TraditionalPreservationSalt/Tiles"

local SaltPanAttachment = {}

SaltPanAttachment.ITEM = "TraditionalPreservationSalt.SaltPan"
SaltPanAttachment.RECIPE = "TraditionalPreservationSalt.Forge_TPSaltPan"
SaltPanAttachment.CLAY = "Base.Clay"

local _, PAN_TILES = Station.kinds(Tiles.PREFIX, Tiles.PAN_FACE_COUNT, Tiles.PAN_LOOKS)
StoneHearth.fittedTiles(SaltPan.ID, Tiles.PAN_SPRITES, PAN_TILES.face)

-- What its tile shows in the pan: brine shows under the overlay, so the tile's pan is empty; steaming, it steams.
local CONTENTS = { [SaltPan.EMPTY] = "Empty", [SaltPan.BRINE] = "Empty", [SaltPan.BOILING] = "Steam", [SaltPan.CRUST] = "Crust" }

-- The tile for the pan's look and the fire, lit or banked; out if neither is given.
function SaltPanAttachment.sprite(look, face, burning, banked)
    local fire = burning and (banked and "Banked" or "Lit") or ""
    return Tiles.PREFIX .. (Tiles.PAN_LOOKS[(CONTENTS[look] or "Empty") .. fire] + face)
end

-- The brine's colour: Brine's own, mixed with water's by its share of the liquid (a spring's is mostly water).
function SaltPanAttachment.colour(pan)
    local ml = pan.ml or 0
    if ml <= 0 then return nil end
    local brine = math.min((pan.salt or 0) * CauldronFluid.ML_PER_L, ml)
    return CauldronFluid.liquidColour({ ml = ml, fluid = "Brine", parts = { Brine = brine, Water = ml - brine } })
end

-- The overlay: the brine standing in the pan, boiling once it is at the boil; nil when it holds none.
function SaltPanAttachment.overlay(pan, face)
    if (pan.ml or 0) <= 0 then return nil end
    local surface = (pan.tempC or 0) >= SaltPan.BOIL_C and "Boiling" or "Still"
    return Tiles.PREFIX .. (Tiles.PAN_SURFACES[surface] + face), SaltPanAttachment.colour(pan)
end

SaltPanAttachment.attachment = Fire.attach({
    id = SaltPan.ID,
    name = "IGUI_TraditionalPreservationSalt_InfoSaltPan",
    fitHelp = "IGUI_TraditionalPreservationSalt_FitSaltPanHelp",
    -- About half an hour: the pan set over the hole and bedded in clay, sealed round its foot.
    fit = {
        items = { { SaltPanAttachment.ITEM, 1 }, { SaltPanAttachment.CLAY, 2 } },
        tool = "MASONS_TROWEL",
        toolText = "IGUI_TraditionalPreservationSalt_ToolTrowel",
        ticks = 300,
        removeTicks = 150,
        lost = { [SaltPanAttachment.CLAY] = true },
    },
    canRemove = SaltPan.canRemove,
    look = SaltPan.look,
    sprite = SaltPanAttachment.sprite,
    overlay = SaltPanAttachment.overlay,
    -- Heated and boiled as the fire was until now, cooled to the air after.
    heats = function(pan, fire, now, fireModData, airC)
        SaltPan.advance(pan, now, airC, fireModData)
    end,
})

-- The pan's state, brought up to now where the World runs (Fire.fireModDataNow).
function SaltPanAttachment.of(fire)
    Fire.fireModDataNow(fire)
    return Fire.partModData(fire:getModData(), SaltPan.ID)
end

Events.OnInitGlobalModData.Add(function()
    Recipes.teach("Base.SmithingMag2", SaltPanAttachment.RECIPE, "TPS")
    Recipes.researchable(SaltPanAttachment.ITEM, SaltPanAttachment.RECIPE, "TPS")
end)

return SaltPanAttachment
