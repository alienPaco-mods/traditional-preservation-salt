-- Checks the vat timer outside the game. Run from the mod folder: luajit tests/test_leach.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
H.useModPaths()
ModData = { getOrCreate = function() return {} end }
local hours = 100
function getGameTime()
    return { getWorldAgeHours = function() return hours end }
end
dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
local N = TraditionalPreservationSalt
local RECIPE_TIME = 7200

local check = H.check

local function newRecipeData()
    local craftRecipeData = { modData = {}, elapsed = 0 }
    function craftRecipeData:getModData() return self.modData end
    function craftRecipeData:getElapsedTime() return self.elapsed end
    function craftRecipeData:setElapsedTime(elapsedTime) self.elapsed = elapsedTime end
    function craftRecipeData:getRecipe() return { getTime = function() return RECIPE_TIME end } end
    return craftRecipeData
end

local craftRecipeData = newRecipeData()
N.onLeachStart(craftRecipeData)
hours = 101
N.onLeachUpdate(craftRecipeData)
check("one game hour is half the recipe", craftRecipeData.elapsed == RECIPE_TIME / 2)

hours = 150
N.onLeachUpdate(craftRecipeData)
check("time away finishes the run, and no further", craftRecipeData.elapsed == RECIPE_TIME)

-- The engine resets elapsed but not ModData when it reuses a pooled object.
craftRecipeData.elapsed = 0
N.onLeachStart(craftRecipeData)
hours = 150.5
N.onLeachUpdate(craftRecipeData)
check("a reused object starts from its new run", craftRecipeData.elapsed == RECIPE_TIME / 4)

craftRecipeData = newRecipeData()
craftRecipeData.elapsed = 12
N.onLeachUpdate(craftRecipeData)
check("a run with no start hour is left alone", craftRecipeData.elapsed == 12)
H.done()
