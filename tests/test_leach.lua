-- Checks the vat timer outside the game. Run from the mod folder: luajit tests/test_leach.lua
local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
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
    local data = { modData = {}, elapsed = 0 }
    function data:getModData() return self.modData end
    function data:getElapsedTime() return self.elapsed end
    function data:setElapsedTime(value) self.elapsed = value end
    function data:getRecipe() return { getTime = function() return RECIPE_TIME end } end
    return data
end

local data = newRecipeData()
N.onLeachStart(data)
hours = 101
N.onLeachUpdate(data)
check("one game hour is half the recipe", data.elapsed == RECIPE_TIME / 2)

hours = 150
N.onLeachUpdate(data)
check("time away finishes the run, and no further", data.elapsed == RECIPE_TIME)

-- The engine resets elapsed but not ModData when it reuses a pooled object.
data.elapsed = 0
N.onLeachStart(data)
hours = 150.5
N.onLeachUpdate(data)
check("a reused object starts from its new run", data.elapsed == RECIPE_TIME / 4)

data = newRecipeData()
data.elapsed = 12
N.onLeachUpdate(data)
check("a run with no start hour is left alone", data.elapsed == 12)
H.done()
