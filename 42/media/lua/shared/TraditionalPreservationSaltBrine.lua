-- Traditional Preservation (Salt): brine as a fluid. A bucket's strength is its share of Brine, in litres; the rest is
-- water, clean or tainted. Salt comes from the Brine alone, SALT_PER_LITRE portions a litre, rounded down, as
-- part-used salt can't be bagged. Any full bucket can be a charge's liquid, so brine run through the vat again comes
-- out stronger, to a cap of a full bucket of Brine (saturated).
--
-- The bucket goes through several items: the charge in the vat, the boiling bucket (food, as only food cooks), the
-- crust. Each carries the Brine litres and the rest's fluid in condition: keys, the only modData the cooking swap
-- keeps (see the core's Container). The vat's bucket is turned back into a fluid bucket as the player takes it out.
-- A metal bucket of brine put into a fire, stove or oven turns into the boiling item, any amount that boils to a salt
-- or more; taken off the heat unboiled it is the fluid bucket again, and the boil starts over (client's BrineUI).
require "TraditionalPreservationSalt"
local Container = require "TraditionalPreservationCore/Container"
local S = TraditionalPreservationSalt

S.BRINE = "Brine"
S.WATER = "Water"
S.TAINTED = "TaintedWater"
S.BUCKET_LITRES = 10
S.SALT_PER_LITRE = 1
S.BRINE_ITEM = "TraditionalPreservationSalt.BucketBrine"
S.CHARGE_ITEM = "TraditionalPreservationSalt.LeachingCharge"
S.SALT_ITEM = "TraditionalPreservationSalt.LooseSalt"
-- What a bucket held before the brine was a fluid: one pass of water, 5 salt.
S.OLD_BRINE_LITRES = 5

-- Save keys: never rename them once the mod is out.
S.BRINE_KEY = "condition:tpBrine"     -- litres of Brine
S.REST_KEY = "condition:tpBrineRest"  -- the fluid making up the rest of the bucket
S.LITRES_KEY = "condition:tpBrineLitres" -- litres in the bucket in all, when it went on the heat part-filled
S.VAT_KEY = "tpFromVat"               -- on the vat's bucket until it is taken out

-- Containers that cook what is put in them (ENGINE_NOTES, Fires and stoves). A microwave is left out.
S.HEAT_CONTAINERS = { stove = true, fireplace = true, woodstove = true, campfire = true, brazier = true, barbecue = true }

-- The flag on the recipes' fluid lines that keeps a sample of what was used (CraftRecipeData:getFirstInputFluidWithFlag).
local SAMPLE_FLAG = "RecordInput"
local EPSILON = 0.001

-- Portions of Evaporated Salt that litres of Brine boil down to.
function S.saltFor(brine)
    return math.floor(brine * S.SALT_PER_LITRE + EPSILON)
end

local function wholeLitres(brine)
    return math.floor(brine + EPSILON)
end

-- A liquid may go through the vat until it is saturated: a pass then would waste the sack.
function S.canLeach(brine)
    return wholeLitres(brine) < S.BUCKET_LITRES
end

-- The Brine a charge's liquid comes out of the vat with. Stronger brine takes up less salt from fresh soil, as it
-- nears saturation: by the whole litres going in, under 5 gains 5, 5-7 gains 3, 8-9 gains 2, to the cap.
function S.afterLeach(brine)
    local whole = wholeLitres(brine)
    local gain = whole < 5 and 5 or whole < 8 and 3 or 2
    return math.min(S.BUCKET_LITRES, brine + gain)
end

-- Weak, Brine, Strong or Saturated, by whole litres of Brine; nil for less than a litre.
function S.strength(brine)
    local whole = wholeLitres(brine)
    if whole < 1 then return nil end
    if whole < 5 then return "Weak" end
    if whole < 8 then return "Brine" end
    if whole < S.BUCKET_LITRES then return "Strong" end
    return "Saturated"
end

-- Litres of Brine and the fluid making up the rest in a fluid sample or container: tainted if any of it is.
-- size(), getFluid(i) and a share by index, or by fluid, are all the two have in common.
local function read(count, fluidAt, shareAt, total)
    local brine, rest = 0, S.WATER
    for i = 0, count - 1 do
        local name = fluidAt(i):getFluidTypeString()
        if name == S.BRINE then
            brine = brine + shareAt(i) * total
        elseif name == S.TAINTED then
            rest = S.TAINTED
        end
    end
    return brine, rest
end

-- What a recipe's flagged fluid line used: litres of Brine and the rest's fluid. Nil when the engine kept no sample.
function S.sampleBrine(sample)
    if not sample then return nil end
    return read(sample:size(), function(i) return sample:getFluid(i) end,
        function(i) return sample:getPercentage(i) end, sample:getAmount())
end

-- Litres of Brine in a fluid container, and the rest's fluid.
function S.containerBrine(container)
    if not container or container:isEmpty() then return 0, S.WATER end
    local brine = 0
    local fluid = Fluid.Get(S.BRINE)
    if fluid then brine = container:getSpecificFluidAmount(fluid) end
    return brine, container:isTainted() and S.TAINTED or S.WATER
end

-- Litres of Brine and the rest's fluid noted on an item; an item from before the notes counts as old brine.
function S.notedBrine(item, default)
    local modData = item:getModData()
    return modData[S.BRINE_KEY] or default or 0, modData[S.REST_KEY] or S.WATER
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
    if S.saltFor(brine) < 1 then return nil end
    local total = container:getAmount()
    local other = total - brine
    for _, name in ipairs({ S.WATER, S.TAINTED }) do
        local fluid = Fluid.Get(name)
        if fluid then other = other - container:getSpecificFluidAmount(fluid) end
    end
    if other > EPSILON then return nil end
    return brine, rest, total
end

-- "Strong brine: boils to 8 salt." for litres of Brine, or nil for too little.
function S.strengthText(brine)
    local strength = S.strength(brine)
    if not strength or S.saltFor(brine) < 1 then return nil end
    return getText("Tooltip_TraditionalPreservationSalt_BoilsTo",
        getText("Tooltip_TraditionalPreservationSalt_Strength" .. strength), S.saltFor(brine))
end

-- Every item of fullType the recipe made.
local function eachCreated(craftRecipeData, fullType, fn)
    local created = craftRecipeData:getAllCreatedItems()
    for i = 0, created:size() - 1 do
        local item = created:get(i)
        if item:getFullType() == fullType then fn(item) end
    end
end

-- The first item of fullType the recipe used up.
local function firstConsumed(craftRecipeData, fullType)
    local used = craftRecipeData:getAllConsumedItems()
    for i = 0, used:size() - 1 do
        if used:get(i):getFullType() == fullType then return used:get(i) end
    end
    return nil
end

local function recordedBrine(craftRecipeData)
    local brine, rest = S.sampleBrine(craftRecipeData:getFirstInputFluidWithFlag(SAMPLE_FLAG))
    if not brine and getDebug() then print("[TraditionalPreservationSalt] the recipe kept no fluid sample") end
    return brine or 0, rest or S.WATER
end

-- OnTest of the charge's bucket: refuses saturated brine. Other inputs pass.
function S.onTestChargeLiquid(item)
    if not item:getFluidContainer() then return true end
    return S.canLeach((S.containerBrine(item:getFluidContainer())))
end

-- The bucket becomes the charge, the brine and the crust in turn. Its kind (plain or forged) is noted on each, so
-- scraping gives back the bucket that went in, and so is the liquid that went in.
function S.onChargePrepared(craftRecipeData)
    Container.note(craftRecipeData, S.CHARGE_ITEM)
    local brine, rest = recordedBrine(craftRecipeData)
    eachCreated(craftRecipeData, S.CHARGE_ITEM, function(item) writeBrine(item, brine, rest) end)
end

-- The vat adds the soil's salt to what the charge's liquid held.
function S.onBrineLeached(craftRecipeData)
    Container.pass(craftRecipeData)
    local charge = firstConsumed(craftRecipeData, S.CHARGE_ITEM)
    local brine, rest = 0, S.WATER
    if charge then brine, rest = S.notedBrine(charge, 0) end
    eachCreated(craftRecipeData, S.BRINE_ITEM, function(item)
        writeBrine(item, S.afterLeach(brine), rest)
        item:getModData()[S.VAT_KEY] = true
    end)
end

-- The script gives one portion; the rest of what the crust's Brine boiled down to is added here.
function S.onCrustScraped(craftRecipeData, character)
    local crust = firstConsumed(craftRecipeData, "TraditionalPreservationSalt.BucketSaltCrust")
    local salt = crust and S.saltFor((S.notedBrine(crust, S.OLD_BRINE_LITRES))) or S.OLD_BRINE_LITRES
    Container.giveBack(craftRecipeData, character, "Base.BucketEmpty")
    if not character then return end
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

-- Puts new where old is, in an item container or on the ground. Returns new, or nil when old is nowhere.
local function replace(old, new)
    local inventory = old:getContainer()
    local worldItem = old:getWorldItem()
    if worldItem then
        local square = worldItem:getSquare()
        local x, y, z = worldItem:getWorldPosX() - square:getX(), worldItem:getWorldPosY() - square:getY(),
            worldItem:getWorldPosZ() - square:getZ()
        if inventory then inventory:DoRemoveItem(old) end
        square:transmitRemoveItemFromSquare(worldItem)
        worldItem:removeFromWorld()
        worldItem:removeFromSquare()
        square:AddWorldInventoryItem(new, x, y, z)
        return new
    end
    if not inventory then return nil end
    inventory:DoRemoveItem(old)
    inventory:AddItem(new)
    return new
end

-- Swaps a boiling bucket for the fluid bucket it stands for, where it lies. Returns the new bucket, or nil.
function S.toFluid(item)
    local brine, rest = S.notedBrine(item, S.OLD_BRINE_LITRES)
    local bucket = S.fillBucket(item:getModData()[Container.KEY] or "Base.BucketEmpty", brine, rest, S.notedLitres(item))
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

-- An item moved from one container to another (Transfer.after): a bucket of brine into the heat turns into the
-- boiling item, and the boiling item taken off the heat into the fluid bucket. Moving between two heats changes
-- nothing, so a bucket keeps its boiling time from one fire to the next.
function S.onMoved(item, from, to)
    local arrived = item:getContainer() == to or (to:getType() == "floor" and item:getWorldItem() ~= nil)
    if not arrived or isHeat(from) == isHeat(to) then return nil end
    if isHeat(to) then
        if item:getFluidContainer() then return S.toBoiling(item) end
    elseif item:getFullType() == S.BRINE_ITEM then
        return S.toFluid(item)
    end
    return nil
end

-- The vat's bucket is a bucket of fluid in the player's hands. Wraps ISItemSlotRemoveAction.complete: compare
-- with vanilla after a game update.
local function fromVatIn(inventory)
    local items = inventory:getItemsFromFullType(S.BRINE_ITEM)
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item:getModData()[S.VAT_KEY] then S.toFluid(item) end
    end
end

-- Outside the game (tests) there is no timed action.
if not ISItemSlotRemoveAction then pcall(require, "Entity/TimedActions/ISItemSlotRemoveAction") end
if ISItemSlotRemoveAction then
    local vanillaComplete = ISItemSlotRemoveAction.complete
    function ISItemSlotRemoveAction:complete()
        local result = vanillaComplete(self)
        fromVatIn(self.character:getInventory())
        return result
    end
end
