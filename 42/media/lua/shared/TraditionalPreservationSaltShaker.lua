-- Traditional Preservation (Salt): a vanilla salt shaker leaves an empty one behind, for Evaporated Salt to refill,
-- and a Bag of Salt its paper bag. ReplaceOnUse covers seasoning, but the engine skips it while crafting, so hand
-- crafts are checked here.
require "TraditionalPreservationSalt"
require "Entity/TimedActions/ISHandcraftAction"
local S = TraditionalPreservationSalt

local SHAKER = "Base.Salt"
local EMPTY_SHAKER = "Base.ShakerEmpty"
local EMPTY_SHAKER_MODEL = "TraditionalPreservationSalt.EmptyShaker"
local EVAPORATED_SALT = "TraditionalPreservationSalt.LooseSalt"
local BAG = "TraditionalPreservationSalt.BagOfSalt"

-- What each salt item leaves when it is used up. A Jays or Spiffo's bag comes back plain.
S.EMPTIES = { [SHAKER] = EMPTY_SHAKER, [BAG] = "Base.PaperBag" }

-- Only tests the salt, as a part-used portion can't fill a shaker.
function S.onTestFullSalt(item)
    return item:getFullType() ~= EVAPORATED_SALT or RecipeCodeOnTest.genericPacking(item, nil)
end

-- LTP's curing gives its own empty shaker, and notes which shakers it has replaced.
local function isReplacedByLTP(item)
    local replaced = RecipeCodeOnCreate and RecipeCodeOnCreate.curedFoodSaltContainers
    return replaced ~= nil and replaced[item] == true
end

-- The empty a shaker or bag the craft used up should leave, if nobody has given it back yet.
function S.emptyFor(item)
    local empty = S.EMPTIES[item:getFullType()]
    if not empty or item:getCurrentUses() > 0 then return nil end
    if item:getModData().emptyShakerGiven or isReplacedByLTP(item) then return nil end
    return empty
end

-- Gives an empty shaker or paper bag for each one the craft used up, once.
function S.returnEmpties(character, usedItems)
    for i = 0, usedItems:size() - 1 do
        local item = usedItems:get(i)
        local empty = S.emptyFor(item)
        if empty then
            item:getModData().emptyShakerGiven = true
            Actions.addOrDropItem(character, instanceItem(empty))
        end
    end
end

-- Vanilla deletes a used-up shaker or bag. Wraps ISHandcraftAction.performRecipe: compare with vanilla after a
-- game update. Vinegar wraps it too (for bottles); each passes through to the other.
local performRecipe = ISHandcraftAction.performRecipe
function ISHandcraftAction:performRecipe()
    performRecipe(self)
    local recipeData = self.logic and self.logic:getRecipeData()
    if recipeData then S.returnEmpties(self.character, recipeData:getAllConsumedItems()) end
end

-- LTP defines the same empty shaker, so its look is set here to hold whichever mod loads last.
function S.applyShakerReplacement()
    local salt = ScriptManager.instance:getItem(SHAKER)
    if salt then salt:DoParam("ReplaceOnUse = " .. EMPTY_SHAKER) end
    local empty = ScriptManager.instance:getItem(EMPTY_SHAKER)
    if not empty then return end
    empty:DoParam("Icon = ShakerEmpty")
    empty:DoParam("StaticModel = " .. EMPTY_SHAKER_MODEL)
    empty:DoParam("WorldStaticModel = " .. EMPTY_SHAKER_MODEL)
end

Events.OnInitGlobalModData.Add(S.applyShakerReplacement)
