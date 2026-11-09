-- Checks who gets an empty shaker, outside the game. Run from the mod folder: luajit tests/test_shaker.lua
local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
H.useModPaths()
ModData = { getOrCreate = function() return {} end }
Events = { OnInitGlobalModData = { Add = function() end } }
ISHandcraftAction = { performRecipe = function() end }
package.preload["TraditionalPreservationSalt"] = function() end
package.preload["Entity/TimedActions/ISHandcraftAction"] = function() end
dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltShaker.lua")
local N = TraditionalPreservationSalt

local check = H.check

local function item(fullType, uses)
    local data = {}
    return {
        getFullType = function() return fullType end,
        getCurrentUses = function() return uses end,
        getModData = function() return data end,
    }
end

local list = H.list

local given = 0
Actions = { addOrDropItem = function() given = given + 1 end }
function instanceItem(fullType) return fullType end

local spent, partUsed, otherFood = item("Base.Salt", 0), item("Base.Salt", 3), item("Base.Flour2", 0)
N.returnEmptyShakers({}, list({ spent, partUsed, otherFood }))
check("a used up shaker gives one empty shaker", given == 1)
check("a part-used shaker and other food give none", not N.needsEmptyShaker(partUsed) and not N.needsEmptyShaker(otherFood))
N.returnEmptyShakers({}, list({ spent }))
check("a shaker only gives one, even if seen twice", given == 1)

local cured = item("Base.Salt", 0)
RecipeCodeOnCreate = { curedFoodSaltContainers = { [cured] = true } }
check("LTP's curing is left to give its own", not N.needsEmptyShaker(cured))

local performed, returned = 0, 0
local logic = { getRecipeData = function() return { getAllConsumedItems = function() return list({}) end } end }
local real = N.returnEmptyShakers
N.returnEmptyShakers = function() returned = returned + 1 end
ISHandcraftAction.performRecipe({ logic = logic, character = {} })
N.returnEmptyShakers = real
check("a finished hand craft is checked", returned == 1)

RecipeCodeOnTest = { genericPacking = function() return false end }
check("part-used Evaporated Salt can't fill a shaker", not N.onTestFullSalt(item("TraditionalPreservationSalt.LooseSalt", 3)))
check("the shaker itself isn't tested", N.onTestFullSalt(item("Base.ShakerEmpty", 1)))
H.done()
