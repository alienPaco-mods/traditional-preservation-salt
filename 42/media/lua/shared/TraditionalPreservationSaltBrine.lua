-- Traditional Preservation (Salt): brine as a fluid. A bucket's strength is its share of Brine, in litres; the rest is
-- water, clean or tainted. Salt comes from the Brine alone, SALT_PER_LITRE portions a litre, rounded down, as
-- part-used salt can't be bagged. The Leaching Vat (TraditionalPreservationSaltVat) makes brine from saline soil; brine
-- poured through it again comes out stronger, to saturation (10 L of Brine in 10 L).
--
-- A bucket of brine goes through two items: the boiling bucket (food, as only food cooks) and the crust. Each carries
-- the Brine litres and the rest's fluid in condition: keys, the only modData the cooking swap keeps (see the core's
-- Container).
-- A metal bucket of brine in a fire, stove or oven turns into the boiling item once that heat is on (S.BOIL_HEAT), any
-- amount that boils to a salt or more: as it goes in (client's BrineUI), or within a game minute of the heat coming on
-- (S.boilIn, the server's minute look at the heat near players). Taken off the heat unboiled it is the fluid bucket
-- again, and the boil starts over; left in a heat that goes out, it waits as the boiling item.
local Action = require "TraditionalPreservationCore/Action"
require "TraditionalPreservationSalt"
local Container = require "TraditionalPreservationCore/Container"
local Recipes = require "TraditionalPreservationCore/Recipes"
local log = require "TraditionalPreservationCore/Log"
local S = TraditionalPreservationSalt
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"

-- The brine boils on the hob (Core's Stone Hearth sets its pot in the hole for it).
StoneHearth.cooksOn(StoneHearth.STOVE, "TraditionalPreservationSalt.BucketBrine")

S.BRINE = "Brine"
S.WATER = "Water"
S.TAINTED = "TaintedWater"
S.BUCKET_LITRES = 10
S.SALT_PER_LITRE = 1
S.BRINE_ITEM = "TraditionalPreservationSalt.BucketBrine"
S.CRUST_ITEM = "TraditionalPreservationSalt.BucketSaltCrust"
-- Strengths by whole litres of Brine in a bucket: Weak below BRINE_FROM, Brine, Strong from STRONG_FROM, Saturated
-- at a full bucket. The vat's gain steps down at the same marks.
S.BRINE_FROM = 5
S.STRONG_FROM = 8

-- Save keys: never rename them once the mod is out.
S.BRINE_KEY = "condition:tpBrine"     -- litres of Brine
S.REST_KEY = "condition:tpBrineRest"  -- the fluid making up the rest of the bucket
S.LITRES_KEY = "condition:tpBrineLitres" -- litres in the bucket in all, when it went on the heat part-filled

-- Containers that cook what is put in them (ENGINE_NOTES, Fires and stoves). A microwave is left out.
S.HEAT_CONTAINERS = { stove = true, fireplace = true, woodstove = true, campfire = true, brazier = true, barbecue = true }
-- How hot one must be for brine in it to boil: vanilla's container temperature, 1.0 cold, 1.5 the lowest a stove turns
-- on to, 1.8 a lit or banked fire (ENGINE_NOTES, How hot things get).
S.BOIL_HEAT = 1.5

local EPSILON = 0.001

-- Portions of Evaporated Salt that litres of Brine boil down to.
function S.saltFor(brine)
    return math.floor(brine * S.SALT_PER_LITRE + EPSILON)
end

local function wholeLitres(brine)
    return math.floor(brine + EPSILON)
end

-- Weak, Brine, Strong or Saturated, by whole litres of Brine; nil for less than a litre.
function S.strength(brine)
    local whole = wholeLitres(brine)
    if whole < 1 then return nil end
    if whole < S.BRINE_FROM then return "Weak" end
    if whole < S.STRONG_FROM then return "Brine" end
    if whole < S.BUCKET_LITRES then return "Strong" end
    return "Saturated"
end

-- Brine, water and tainted water as the engine's fluids, by name. Looked up the first time they are asked for, as
-- the engine's fluids may not be there when this file loads, and kept once all three are found.
local fluids
local function brineFluids()
    if fluids then return fluids end
    local found = { [S.BRINE] = Fluid.Get(S.BRINE), [S.WATER] = Fluid.Get(S.WATER), [S.TAINTED] = Fluid.Get(S.TAINTED) }
    if found[S.BRINE] and found[S.WATER] and found[S.TAINTED] then fluids = found end
    return found
end

-- Litres of a fluid by name in a fluid container, 0 if the engine has no such fluid.
local function amountOf(container, name)
    local fluid = brineFluids()[name]
    return fluid and container:getSpecificFluidAmount(fluid) or 0
end

-- Litres in a fluid container that are neither Brine nor water, clean or tainted.
local function otherLitres(container)
    return container:getAmount() - amountOf(container, S.BRINE) - amountOf(container, S.WATER)
        - amountOf(container, S.TAINTED)
end

-- Litres of Brine in a fluid container, and the rest's fluid.
function S.containerBrine(container)
    if not container or container:isEmpty() then return 0, S.WATER end
    return amountOf(container, S.BRINE), container:isTainted() and S.TAINTED or S.WATER
end

-- Litres of Brine and the rest's fluid noted on an item.
function S.notedBrine(item)
    local modData = item:getModData()
    return modData[S.BRINE_KEY] or 0, modData[S.REST_KEY] or S.WATER
end

local function writeBrine(item, brine, rest, litres)
    local modData = item:getModData()
    modData[S.BRINE_KEY] = brine
    modData[S.REST_KEY] = rest
    modData[S.LITRES_KEY] = litres
end

-- Litres in the bucket an item stands for: a full one unless noted.
function S.notedLitres(item)
    return item:getModData()[S.LITRES_KEY] or S.BUCKET_LITRES
end

-- Litres of Brine, the rest's fluid and the litres in all of a fluid container that holds brine boiling to a salt
-- or more and nothing but Brine and water; nil otherwise.
function S.boilableBrine(container)
    if not container or container:isEmpty() then return nil end
    local brine, rest = S.containerBrine(container)
    if S.saltFor(brine) < 1 or otherLitres(container) > EPSILON then return nil end
    return brine, rest, container:getAmount()
end

-- Litres of Brine, the rest's fluid and the litres in all of a fluid container holding nothing but Brine and water,
-- clean or tainted (what the Leaching Vat takes); nil when empty or holding anything else.
function S.leachLiquid(container)
    if not container or container:isEmpty() or otherLitres(container) > EPSILON then return nil end
    local brine, rest = S.containerBrine(container)
    return brine, rest, container:getAmount()
end

-- Pours litres into a fluid container, brine of them Brine, the rest of rest's fluid.
function S.fillWith(container, litres, brine, rest)
    if brine > EPSILON then container:addFluid(S.BRINE, brine) end
    if litres - brine > EPSILON then container:addFluid(rest, litres - brine) end
end

-- Litres of Brine and the litres in all of a fluid container holding some Brine and nothing but Brine and water (the
-- salt pan takes any of it, a top-up too); nil otherwise.
function S.brineAndWater(container)
    if not container or container:isEmpty() then return nil end
    local brine = S.containerBrine(container)
    if brine < EPSILON or otherLitres(container) > EPSILON then return nil end
    return brine, container:getAmount()
end

-- "Strong brine: boils to 8 salt." for litres of Brine, or nil for too little.
function S.strengthText(brine)
    local strength = S.strength(brine)
    if not strength or S.saltFor(brine) < 1 then return nil end
    return getText("Tooltip_TraditionalPreservationSalt_BoilsTo",
        getText("Tooltip_TraditionalPreservationSalt_Strength" .. strength), S.saltFor(brine))
end

-- The script gives one portion; the rest of what the crust's Brine boiled down to is added here.
function S.onCrustScraped(craftRecipeData, character)
    local crust = Recipes.consumed(craftRecipeData, S.CRUST_ITEM)[1]
    Container.giveBack(craftRecipeData, character, S.EMPTY_BUCKET)
    if not crust or not character then return end
    local salt = S.saltFor((S.notedBrine(crust)))
    for _ = 2, salt do Actions.addOrDropItem(character, instanceItem(S.SALT_ITEM)) end
end

-- A metal bucket of type fullType holding litres (a full bucket if nil), brine of them Brine, the rest of rest's fluid.
function S.fillBucket(fullType, brine, rest, litres)
    litres = litres or S.BUCKET_LITRES
    local bucket = instanceItem(fullType)
    local container = bucket and bucket:getFluidContainer()
    if not container then return nil end
    container:Empty()
    if brine > 0 then container:addFluid(S.BRINE, brine) end
    if brine < litres - EPSILON then container:addFluid(rest, litres - brine) end
    return bucket
end

-- Whether an item can take spring brine: a fluid container with room, that takes Brine and tainted water (a fuel
-- can doesn't) and holds nothing but Brine and water, so a part-filled bucket of spring brine can be topped up.
function S.canTakeSpringBrine(item)
    local container = item:getFluidContainer()
    if not container or container:getFreeCapacity() < EPSILON then return false end
    local found = brineFluids()
    local brine, tainted = found[S.BRINE], found[S.TAINTED]
    if not brine or not tainted or not container:canAddFluid(brine) or not container:canAddFluid(tainted) then
        return false
    end
    return container:isEmpty() or otherLitres(container) <= EPSILON
end

-- Pours litres of spring brine into a fluid container: a tenth Brine, the rest tainted water.
function S.addSpringBrine(container, litres)
    container:addFluid(S.BRINE, litres * S.SPRING_BRINE_SHARE)
    container:addFluid(S.TAINTED, litres * (1 - S.SPRING_BRINE_SHARE))
end

local replace = Action.replaceItem

-- Swaps a boiling bucket for the fluid bucket it stands for, where it lies. Returns the new bucket, or nil.
function S.toFluid(item)
    local brine, rest = S.notedBrine(item)
    local bucket = S.fillBucket(item:getModData()[Container.KEY] or S.EMPTY_BUCKET, brine, rest, S.notedLitres(item))
    return bucket and replace(item, bucket)
end

-- Swaps a metal bucket of brine for the boiling item, where it lies, noting the Brine, the rest, the litres and the
-- bucket's kind. Returns the boiling item, or nil when the bucket holds no brine to boil.
function S.toBoiling(bucket)
    if not bucket:hasTag(ItemTag.METAL_BUCKET) then return nil end
    local brine, rest, litres = S.boilableBrine(bucket:getFluidContainer())
    if not brine then return nil end
    local boiling = instanceItem(S.BRINE_ITEM)
    if not boiling then return nil end
    writeBrine(boiling, brine, rest, math.abs(litres - S.BUCKET_LITRES) > EPSILON and litres or nil)
    boiling:getModData()[Container.KEY] = bucket:getFullType()
    return replace(bucket, boiling)
end

local function isHeat(container)
    return container ~= nil and S.HEAT_CONTAINERS[container:getType()] == true
end

-- A heat that is on: brine in it boils.
local function isHot(container)
    return isHeat(container) and container:getTemperature() >= S.BOIL_HEAT
end

-- An item moved from one container to another (Transfer.after): a bucket of brine into a heat that is on turns into
-- the boiling item (into a cold one it waits for S.boilIn), and the boiling item taken off the heat into the fluid
-- bucket. Moving between two heats changes nothing, so a bucket keeps its boiling time from one fire to the next.
function S.onMoved(item, from, to)
    local arrived = item:getContainer() == to or (to:getType() == "floor" and item:getWorldItem() ~= nil)
    if not arrived or isHeat(from) == isHeat(to) then return nil end
    if isHeat(to) then
        if item:getFluidContainer() and isHot(to) then return S.toBoiling(item) end
    elseif item:getFullType() == S.BRINE_ITEM then
        return S.toFluid(item)
    end
    return nil
end

-- Buckets of brine waiting in a heat that has come on turn into the boiling item (TP Core's Station.onHeatNear calls
-- it each game minute for the hot containers near a player). Returns how many turned.
function S.boilIn(container)
    if not isHot(container) then return 0 end
    local items, buckets = container:getItems(), {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFluidContainer() and item:hasTag(ItemTag.METAL_BUCKET) then table.insert(buckets, item) end
    end
    local turned = 0
    for _, bucket in ipairs(buckets) do
        if S.toBoiling(bucket) then turned = turned + 1 end
    end
    return turned
end
