-- Traditional Preservation (Salt): a vanilla salt shaker leaves an empty one behind, for Evaporated Salt to refill.
-- ReplaceOnUse covers seasoning, but the engine skips it while crafting, so hand crafts are checked here.
require "TraditionalPreservationSalt"
require "Entity/TimedActions/ISHandcraftAction"

local SHAKER = "Base.Salt"
local EMPTY_SHAKER = "Base.ShakerEmpty"
local EMPTY_SHAKER_MODEL = "TraditionalPreservationSalt.EmptyShaker"
local EVAPORATED_SALT = "TraditionalPreservationSalt.LooseSalt"

-- Only tests the salt, as a part-used portion can't fill a shaker.
function TraditionalPreservationSalt.onTestFullSalt(item)
    return item:getFullType() ~= EVAPORATED_SALT or RecipeCodeOnTest.genericPacking(item, nil)
end

-- LTP's curing gives its own empty shaker, and notes which shakers it has replaced.
local function isReplacedByLTP(item)
    local replaced = RecipeCodeOnCreate and RecipeCodeOnCreate.curedFoodSaltContainers
    return replaced ~= nil and replaced[item] == true
end

function TraditionalPreservationSalt.needsEmptyShaker(item)
    if item:getFullType() ~= SHAKER or item:getCurrentUses() > 0 then return false end
    return not item:getModData().emptyShakerGiven and not isReplacedByLTP(item)
end

function TraditionalPreservationSalt.returnEmptyShakers(character, usedItems)
    for i = 0, usedItems:size() - 1 do
        local item = usedItems:get(i)
        if TraditionalPreservationSalt.needsEmptyShaker(item) then
            item:getModData().emptyShakerGiven = true
            Actions.addOrDropItem(character, instanceItem(EMPTY_SHAKER))
        end
    end
end

local performRecipe = ISHandcraftAction.performRecipe
function ISHandcraftAction:performRecipe()
    performRecipe(self)
    local recipeData = self.logic and self.logic:getRecipeData()
    if recipeData then TraditionalPreservationSalt.returnEmptyShakers(self.character, recipeData:getAllConsumedItems()) end
end

-- LTP defines the same empty shaker, so its look is set here to hold whichever mod loads last.
function TraditionalPreservationSalt.applyShakerReplacement()
    local salt = ScriptManager.instance:getItem(SHAKER)
    if salt then salt:DoParam("ReplaceOnUse = " .. EMPTY_SHAKER) end
    local empty = ScriptManager.instance:getItem(EMPTY_SHAKER)
    if not empty then return end
    empty:DoParam("Icon = ShakerEmpty")
    empty:DoParam("StaticModel = " .. EMPTY_SHAKER_MODEL)
    empty:DoParam("WorldStaticModel = " .. EMPTY_SHAKER_MODEL)
end

Events.OnInitGlobalModData.Add(TraditionalPreservationSalt.applyShakerReplacement)
