-- Checks brine as a fluid outside the game: strength, the vat's passes, the notes on each item, and the salt scraped.
-- Run from the mod folder: luajit tests/test_brine.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
function getDebug() return false end

Fluid = { Get = function(name) return { name = name, getFluidTypeString = function() return name end } end }

-- A fluid container holding litres by fluid name.
local function newTank(parts)
    parts = parts or {}
    local tank = {}
    local function total()
        local sum = 0
        for _, litres in pairs(parts) do sum = sum + litres end
        return sum
    end
    function tank:isEmpty() return total() <= 0 end
    function tank:getAmount() return total() end
    function tank:getSpecificFluidAmount(fluid) return parts[fluid.name] or 0 end
    function tank:isTainted() return (parts.TaintedWater or 0) > 0 end
    function tank:addFluid(name, litres) parts[name] = (parts[name] or 0) + litres end
    function tank:Empty() parts = {} end
    tank.parts = function() return parts end
    return tank
end

ItemTag = { METAL_BUCKET = "base:metalbucket" }
function getText(key, ...)
    local args = { ... }
    if #args == 0 then return key end
    return key .. "(" .. table.concat(args, ",") .. ")"
end

local function newItem(fullType, tank)
    local modData = {}
    local item = { container = nil }
    function item:getFullType() return fullType end
    function item:hasTag(tag) return tag == ItemTag.METAL_BUCKET and fullType:find("Bucket") ~= nil end
    function item:getWorldItem() return nil end
    function item:getModData() return modData end
    function item:getFluidContainer() return tank end
    function item:getContainer() return self.container end
    return item
end

-- A Java-ish inventory: AddItem, DoRemoveItem, getItemsFromFullType.
local function newInventory()
    local inventory = { items = {} }
    function inventory:AddItem(item)
        table.insert(self.items, item)
        item.container = self
        return item
    end
    function inventory:DoRemoveItem(item)
        for i, each in ipairs(self.items) do
            if each == item then table.remove(self.items, i) break end
        end
        item.container = nil
    end
    function inventory:getItemsFromFullType(fullType)
        local found = {}
        for _, item in ipairs(self.items) do
            if item:getFullType() == fullType then table.insert(found, item) end
        end
        return H.list(found)
    end
    function inventory:count(fullType) return self:getItemsFromFullType(fullType):size() end
    function inventory:getType() return self.type or "none" end
    return inventory
end

function instanceItem(fullType)
    local isBucket = fullType == "Base.BucketEmpty" or fullType == "Base.BucketForged"
    return newItem(fullType, isBucket and newTank() or nil)
end

local given = newInventory()
Actions = { addOrDropItem = function(_, item) given:AddItem(item) end }

-- A recorded fluid sample, as the engine keeps for a flagged fluid line.
local function newSample(parts)
    local names, total = {}, 0
    for name, litres in pairs(parts) do
        table.insert(names, name)
        total = total + litres
    end
    return {
        size = function() return #names end,
        getFluid = function(_, i) return Fluid.Get(names[i + 1]) end,
        getPercentage = function(_, i) return parts[names[i + 1]] / total end,
        getAmount = function() return total end,
    }
end

local function newRecipeData(consumed, created, sample)
    return {
        getAllConsumedItems = function() return H.list(consumed) end,
        getAllCreatedItems = function() return H.list(created) end,
        getFirstInputFluidWithFlag = function(_, flag) return flag == "RecordInput" and sample or nil end,
    }
end

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltBrine.lua")
local S = TraditionalPreservationSalt

-- Strength and salt
check("a spring's litre of Brine boils to one salt", S.saltFor(1) == 1)
check("salt rounds down", S.saltFor(5.9) == 5 and S.saltFor(0.9) == 0)
check("a float a hair under a litre still counts as one", S.saltFor(0.9999999) == 1)
check("strength words by whole litres",
    S.strength(0.5) == nil and S.strength(1) == "Weak" and S.strength(4.9) == "Weak" and S.strength(5) == "Brine"
    and S.strength(7) == "Brine" and S.strength(8) == "Strong" and S.strength(9.9) == "Strong" and S.strength(10) == "Saturated")

-- Passes through the vat
check("water: 0, 5, 8, 10", S.afterLeach(0) == 5 and S.afterLeach(5) == 8 and S.afterLeach(8) == 10)
check("spring: 1, 6, 9, 10", S.afterLeach(1) == 6 and S.afterLeach(6) == 9 and S.afterLeach(9) == 10)
check("never past saturation", S.afterLeach(9.5) == 10)
check("saturated brine can't be leached, anything weaker can", not S.canLeach(10) and S.canLeach(9.9) and S.canLeach(0))

-- Reading containers and samples
local brine, rest = S.containerBrine(newTank({ Brine = 1, TaintedWater = 9 }))
check("a spring bucket reads 1 L of Brine, the rest tainted", H.near(brine, 1) and rest == "TaintedWater")
brine, rest = S.containerBrine(newTank({ Water = 10 }))
check("a bucket of water has no Brine", brine == 0 and rest == "Water")
brine, rest = S.sampleBrine(newSample({ Brine = 6, Water = 4 }))
check("a sample gives the Brine share in litres", H.near(brine, 6) and rest == "Water")
check("no sample, nothing read", S.sampleBrine(nil) == nil)

-- OnTest
check("the charge takes a bucket of water", S.onTestChargeLiquid(newItem("Base.BucketEmpty", newTank({ Water = 10 }))))
check("and of spring brine", S.onTestChargeLiquid(newItem("Base.BucketEmpty", newTank({ Brine = 1, TaintedWater = 9 }))))
check("but not of saturated brine", not S.onTestChargeLiquid(newItem("Base.BucketEmpty", newTank({ Brine = 10 }))))
check("the sack is never refused", S.onTestChargeLiquid(newItem("TraditionalPreservationSalt.SalineSoilSack")))

-- The chain: a forged bucket of spring brine, charged, leached, taken out, put on the heat, cooked, scraped.
local forged = newItem("Base.BucketForged", newTank({ Brine = 1, TaintedWater = 9 }))
local charge = newItem(S.CHARGE_ITEM)
S.onChargePrepared(newRecipeData({ forged }, { charge }, newSample({ Brine = 1, TaintedWater = 9 })))
brine, rest = S.notedBrine(charge)
check("the charge notes the liquid that went in", H.near(brine, 1) and rest == "TaintedWater")
check("and the bucket's kind", charge:getModData()["condition:tpContainer"] == "Base.BucketForged")

local vatBucket = newItem(S.BRINE_ITEM)
S.onBrineLeached(newRecipeData({ charge }, { vatBucket }))
brine, rest = S.notedBrine(vatBucket)
check("the vat adds the soil's salt: spring 1 -> 6", H.near(brine, 6) and rest == "TaintedWater")
check("the bucket kind carries on", vatBucket:getModData()["condition:tpContainer"] == "Base.BucketForged")
check("and it is marked as the vat's", vatBucket:getModData()[S.VAT_KEY] == true)

local oldCharge = newItem(S.CHARGE_ITEM)
local oldBucket = newItem(S.BRINE_ITEM)
S.onBrineLeached(newRecipeData({ oldCharge }, { oldBucket }))
check("a charge from before the notes leaches as water: 5", S.notedBrine(oldBucket) == 5)

local hands = newInventory()
hands:AddItem(vatBucket)
local fluidBucket = S.toFluid(vatBucket)
check("taken out, it is a fluid bucket of the kind that went in",
    fluidBucket:getFullType() == "Base.BucketForged" and hands:count(S.BRINE_ITEM) == 0 and hands:count("Base.BucketForged") == 1)
local parts = fluidBucket:getFluidContainer().parts()
check("holding 6 L of Brine and 4 of tainted water", H.near(parts.Brine, 6) and H.near(parts.TaintedWater, 4))

local campfire = newInventory()
campfire.type = "campfire"
hands:DoRemoveItem(fluidBucket)
campfire:AddItem(fluidBucket)
local boiling = S.onMoved(fluidBucket, hands, campfire)
brine = S.notedBrine(boiling)
check("on the fire it notes the Brine and the bucket", H.near(brine, 6)
    and boiling:getModData()["condition:tpContainer"] == "Base.BucketForged")

-- The cooking swap keeps only condition: keys, so the crust gets those.
local crust = newItem("TraditionalPreservationSalt.BucketSaltCrust")
for key, value in pairs(boiling:getModData()) do
    if key:sub(1, 10) == "condition:" then crust:getModData()[key] = value end
end
local placeholder = newItem("Base.BucketEmpty")
local salt = newItem(S.SALT_ITEM)
given:AddItem(placeholder)
given:AddItem(salt)
S.onCrustScraped(newRecipeData({ crust }, { salt, placeholder }), {})
check("scraping 6 L of Brine gives 6 salt", given:count(S.SALT_ITEM) == 6)
check("and the forged bucket back", given:count("Base.BucketForged") == 1 and given:count("Base.BucketEmpty") == 0)

given = newInventory()
local oldCrust = newItem("TraditionalPreservationSalt.BucketSaltCrust")
salt = newItem(S.SALT_ITEM)
given:AddItem(salt)
S.onCrustScraped(newRecipeData({ oldCrust }, { salt }), {})
check("a crust from before the notes gives today's 5", given:count(S.SALT_ITEM) == 5)

-- fillBucket
local full = S.fillBucket("Base.BucketEmpty", 10, "Water"):getFluidContainer().parts()
check("a saturated bucket is all Brine", full.Brine == 10 and full.Water == nil)
local plain = S.fillBucket("Base.BucketEmpty", 0, "Water"):getFluidContainer().parts()
check("and one with none is all water", plain.Water == 10 and plain.Brine == nil)

-- Part-filled buckets on and off the heat (step 2)
check("a full bucket fills to 10 L, a part-filled one to its litres",
    H.near(S.fillBucket("Base.BucketEmpty", 1, "Water", 7.5):getFluidContainer():getAmount(), 7.5))
brine, rest, total = S.boilableBrine(newTank({ Brine = 1, TaintedWater = 8.9 }))
check("a sipped spring bucket still boils: 1 L Brine of 9.9", H.near(brine, 1) and rest == "TaintedWater" and H.near(total, 9.9))
check("too little Brine for a salt doesn't boil", S.boilableBrine(newTank({ Brine = 0.5, Water = 9 })) == nil)
check("nor water, nor an empty bucket", S.boilableBrine(newTank({ Water = 10 })) == nil and S.boilableBrine(newTank()) == nil)
check("nor brine mixed with anything else", S.boilableBrine(newTank({ Brine = 5, Vinegar = 1, Water = 4 })) == nil)

local stove = newInventory()
stove.type = "stove"
local bag = newInventory()
bag.type = "none"
local sipped = newItem("Base.BucketForged", newTank({ Brine = 6, Water = 3.4 }))
stove:AddItem(sipped)
local onHeat = S.onMoved(sipped, bag, stove)
check("into the stove, a bucket of brine turns into the boiling item",
    onHeat and onHeat:getFullType() == S.BRINE_ITEM and stove:count(S.BRINE_ITEM) == 1 and stove:count("Base.BucketForged") == 0)
brine, rest = S.notedBrine(onHeat)
check("noting its Brine, rest, litres and kind", H.near(brine, 6) and rest == "Water" and H.near(S.notedLitres(onHeat), 9.4)
    and onHeat:getModData()["condition:tpContainer"] == "Base.BucketForged")
check("the tooltip line names its strength", S.strengthText(brine) == "Tooltip_TraditionalPreservationSalt_BoilsTo(Tooltip_TraditionalPreservationSalt_StrengthBrine,6)")

stove:DoRemoveItem(onHeat)
bag:AddItem(onHeat)
local offHeat = S.onMoved(onHeat, stove, bag)
parts = offHeat and offHeat:getFluidContainer().parts()
check("taken off unboiled, it is the same bucket of brine again", offHeat and offHeat:getFullType() == "Base.BucketForged"
    and bag:count(S.BRINE_ITEM) == 0 and H.near(parts.Brine, 6) and H.near(parts.Water, 3.4))

local full = newItem("Base.BucketEmpty", newTank({ Brine = 8, Water = 2 }))
stove:AddItem(full)
local fullOnHeat = S.onMoved(full, bag, stove)
check("a full bucket notes no litres", fullOnHeat:getModData()[S.LITRES_KEY] == nil and S.notedLitres(fullOnHeat) == 10)

local fire = newInventory()
fire.type = "campfire"
stove:DoRemoveItem(fullOnHeat)
fire:AddItem(fullOnHeat)
check("from one heat to another nothing changes", S.onMoved(fullOnHeat, stove, fire) == nil and fire:count(S.BRINE_ITEM) == 1)

local water = newItem("Base.BucketEmpty", newTank({ Water = 10 }))
stove:AddItem(water)
check("a bucket of water on the stove stays water", S.onMoved(water, bag, stove) == nil and stove:count("Base.BucketEmpty") == 1)
local pot = newItem("Base.Pot", newTank({ Brine = 5, Water = 5 }))
stove:AddItem(pot)
check("brine in a pot isn't swapped: buckets only", S.onMoved(pot, bag, stove) == nil)
local microwave = newInventory()
microwave.type = "microwave"
local inMicrowave = newItem("Base.BucketEmpty", newTank({ Brine = 5, Water = 5 }))
microwave:AddItem(inMicrowave)
check("a microwave isn't a heat for brine", S.onMoved(inMicrowave, bag, microwave) == nil)
local refused = newItem("Base.BucketEmpty", newTank({ Brine = 5, Water = 5 }))
bag:AddItem(refused)
check("a bucket vanilla didn't move is left alone", S.onMoved(refused, bag, stove) == nil and bag:count("Base.BucketEmpty") == 1)
H.done()
