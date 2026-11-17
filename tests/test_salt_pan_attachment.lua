-- Checks the salt pan as TP Core's Stone Hearth attachment outside the game: its tiles are Stone Hearth tiles, the tile
-- and overlay for each look and fire, the brine's colour, Fit's kit, and the pour and scrape at the pan (TPSaltPanWork).
-- Run from the mod folder: luajit tests/test_salt_pan_attachment.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
function getDebug() return false end
function instanceof(object, name) return type(object) == "table" and object.class == name end
ISBaseTimedAction = H.class("ISBaseTimedAction")
function ISBaseTimedAction.perform() end

local function colour(r, g, b) return { getRedFloat = function() return r end, getGreenFloat = function() return g end, getBlueFloat = function() return b end } end
local COLOURS = { Brine = colour(0.94, 0.9, 0.55), Water = colour(0.2, 0.4, 0.8), TaintedWater = colour(0.3, 0.4, 0.3) }
Fluid = { Get = function(name)
    return { name = name, getFluidTypeString = function() return name end, getColor = function() return COLOURS[name] end }
end }

dofile("42/media/lua/shared/TraditionalPreservationSalt.lua")
dofile("42/media/lua/shared/TraditionalPreservationSaltBrine.lua")
local S = TraditionalPreservationSalt
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Doors = require "TraditionalPreservationCore/Doors"
local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local SaltPanAttachment = require "TraditionalPreservationSalt/SaltPanAttachment"
local Tiles = require "TraditionalPreservationSalt/Tiles"
H.checkTiles(Tiles)

local function near(a, b) return math.abs(a - b) < 0.001 end
local P = Tiles.PREFIX

-- Tiles
check("18 pan tiles, two facings of nine looks", #Tiles.PAN_SPRITES == 18 and Tiles.PAN_FACE_COUNT == 2)
local tracked = {}
for _, name in ipairs(Fire.sprites()) do tracked[name] = true end
local allKnown = true
for _, name in ipairs(Tiles.PAN_SPRITES) do
    allKnown = allKnown and tracked[name] and StoneHearth.fittedByTile(name) == SaltPan.ID and Doors.facingOf(name) ~= nil
end
check("every pan tile is a Stone Hearth tile: tracked, the pan fitted by tile, its door known", allKnown)
check("their facing: S then E", StoneHearth.face(P .. "72") == 0 and StoneHearth.face(P .. "73") == 1 and StoneHearth.face(P .. "89") == 1)
check("the overlays aren't hearth tiles", StoneHearth.face(P .. Tiles.PAN_SURFACES.Still) == nil)

-- Sprite by look and fire
local sprite = SaltPanAttachment.sprite
check("empty and brine show the empty pan (brine is the overlay)", sprite(SaltPan.EMPTY, 0) == P .. "72"
    and sprite(SaltPan.BRINE, 1) == P .. "73")
check("boiling steams, by fire", sprite(SaltPan.BOILING, 0, true) == P .. (Tiles.PAN_LOOKS.SteamLit)
    and sprite(SaltPan.BOILING, 1, true, true) == P .. (Tiles.PAN_LOOKS.SteamBanked + 1)
    and sprite(SaltPan.BOILING, 0) == P .. Tiles.PAN_LOOKS.Steam)
check("the crust, lit", sprite(SaltPan.CRUST, 0, true, false) == P .. Tiles.PAN_LOOKS.CrustLit)

-- Overlay and colour
check("no overlay with no brine", SaltPanAttachment.overlay({}, 0) == nil and SaltPanAttachment.overlay({ salt = 3 }, 0) == nil)
local still, tint = SaltPanAttachment.overlay({ ml = 30000, salt = 3, tempC = 60 }, 1)
check("brine below the boil: the still surface, tinted a tenth Brine", still == P .. (Tiles.PAN_SURFACES.Still + 1)
    and near(tint[1], 0.94 * 0.1 + 0.2 * 0.9) and near(tint[3], 0.55 * 0.1 + 0.8 * 0.9))
check("at the boil: the boiling surface", SaltPanAttachment.overlay({ ml = 30000, salt = 3, tempC = 100 }, 0) == P .. Tiles.PAN_SURFACES.Boiling)
local strong = SaltPanAttachment.colour({ ml = 10000, salt = 30 })
check("salt built up past the liquid reads all Brine", near(strong[1], 0.94) and near(strong[2], 0.9))

-- The attachment
local attachment = Fire.attachment(SaltPan.ID)
check("registered with Fire: Fit takes the pan, 2 clay and a mason's trowel, the clay lost",
    attachment == SaltPanAttachment.attachment and attachment.fit.tool == "MASONS_TROWEL"
    and #Fire.fitBack(attachment) == 1 and Fire.fitBack(attachment)[1][1] == SaltPanAttachment.ITEM)
local pan = {}
attachment.heats(pan, nil, 100, {}, 20)
check("heats keeps no clock for an empty, cold pan", pan.lastHour == nil)
SaltPan.pourInto(pan, 10, 1, 20, 100)
attachment.heats(pan, nil, 102, { fireUntil = 200 }, 20)
check("and boils a full one by the fire", pan.tempC == 100 and pan.ml < 10000)

-- The brine a pour takes
local function tank(parts)
    local container = {}
    local function total() local sum = 0 for _, l in pairs(parts) do sum = sum + l end return sum end
    function container:isEmpty() return total() <= 0 end
    function container:getAmount() return total() end
    function container:getSpecificFluidAmount(fluid) return parts[fluid.name] or 0 end
    function container:isTainted() return (parts.TaintedWater or 0) > 0 end
    function container:removeFluid(litres)
        local all = total()
        for name, l in pairs(parts) do parts[name] = l - l * litres / all end
    end
    container.parts = parts
    return container
end
local brine, litres = S.brineAndWater(tank({ Brine = 0.5, TaintedWater = 4.5 }))
check("half a spring bucket is brine to pour", near(brine, 0.5) and near(litres, 5))
check("water alone, or brine with anything else, isn't", S.brineAndWater(tank({ Water = 10 })) == nil
    and S.brineAndWater(tank({ Brine = 1, Vinegar = 1 })) == nil and S.brineAndWater(tank({})) == nil)

-- TPSaltPanWork
Actions = { addOrDropItem = function(character, item) table.insert(character.got, item) end }
function instanceItem(fullType) return fullType end
ItemTag = { SHARP_KNIFE = "base:sharpknife", DULL_KNIFE = "base:dullknife", MEAT_CLEAVER = "base:meatcleaver" }
package.preload["TimedActions/ISBaseTimedAction"] = function() return ISBaseTimedAction end
package.loaded["TraditionalPreservationSalt"], package.loaded["TraditionalPreservationSaltBrine"] = true, true
dofile("42/media/lua/shared/TimedActions/TPSaltPanWork.lua")

local fireModData = {}
local fire = { class = "IsoFireplace", sprite = P .. "72" }
function fire:getModData() return fireModData end
function fire:getSprite() local name = self.sprite return { getName = function() return name end } end
function fire:getSquare() return {} end
function fire:isLit() return false end
Fire.fit(fire, SaltPan.ID)
local tags = {}
local character = { got = {} }
function character:getInventory()
    return { containsRecursive = function() return true end, containsTagRecurse = function(_, tag) return tags[tag] end }
end
function character:isTimedActionInstant() return false end

local bucket = { getFluidContainer = function(self) return self.tank end, getItemHeat = function() return 1 end }
bucket.tank = tank({ Brine = 1, TaintedWater = 9 })
local pour = TPSaltPanWork:new(character, fire, bucket, "pourIn")
check("a pour is offered with a bucket of spring brine", pour:isValid())
pour:complete()
local saved = Fire.partModData(fireModData, SaltPan.ID)
check("the bucket goes in, its Brine noted as salt", near(saved.ml, 10000) and near(saved.salt, 1) and bucket.tank:isEmpty())
check("and an empty bucket pours no more", not pour:isValid())

local empty = TPSaltPanWork:new(character, fire, nil, "empty")
check("Empty is offered with brine in the pan", empty:isValid())
empty:complete()
check("emptied: no brine, no salt", (saved.ml or 0) == 0 and saved.salt == nil and not empty:isValid())

saved.ml, saved.salt, saved.tempC = 0, 3.4, 100
local scrape = TPSaltPanWork:new(character, fire, nil, "scrape")
check("no knife, no scraping", not scrape:isValid())
tags["base:dullknife"] = true
check("a dull knife does", scrape:isValid())
scrape:complete()
check("scraped: 3 Evaporated Salt, the pan empty", #character.got == 3 and character.got[1] == S.SALT_ITEM
    and SaltPan.look(saved) == SaltPan.EMPTY and not scrape:isValid())
H.done()
