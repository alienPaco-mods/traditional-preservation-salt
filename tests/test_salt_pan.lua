-- Checks the salt pan's rules outside the game: pouring, heating to the boil, boiling dry, topping up, the crust,
-- scraping and Remove. Run from the mod folder: luajit tests/test_salt_pan.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installEvents()

local SaltPan = require "TraditionalPreservationSalt/SaltPan"
local Fire = require "TraditionalPreservationCore/Fire"

local function near(a, b, tolerance) return math.abs(a - b) <= (tolerance or 0.01) end
local function saltFor(brine) return math.floor(brine + 0.001) end
local LIT = function(untilHour) return { fireUntil = untilHour } end

-- Pouring
local pan = {}
check("an empty pan takes 30 L", SaltPan.look(pan) == SaltPan.EMPTY and SaltPan.roomL(pan) == 30)
check("a bucket of spring brine goes in: 10 L, 1 L of it Brine", SaltPan.pourInto(pan, 10, 1, 20, 0) == 10
    and pan.ml == 10000 and near(pan.salt, 1) and SaltPan.look(pan) == SaltPan.BRINE)
SaltPan.pourInto(pan, 10, 1, 20, 0)
check("only the room left is taken, the Brine in the same share", SaltPan.pourInto(pan, 15, 1.5, 20, 0) == 10
    and pan.ml == 30000 and near(pan.salt, 3) and SaltPan.pourInto(pan, 10, 1, 20, 0) == 0)

-- Heating and boiling, a lit fire
SaltPan.advance(pan, 0.4, 20, LIT(100))
check("a full pan isn't at the boil after 24 minutes", pan.tempC < 100 and pan.tempC > SaltPan.HOT_C and pan.ml == 30000
    and SaltPan.look(pan) == SaltPan.BOILING)
SaltPan.advance(pan, 1.5, 20, LIT(100))
check("boils from half an hour, 6 L an hour off after that", pan.tempC == 100 and near(pan.ml, 30000 - 6000, 1))
check("dry in four hours more (24 L at 6 L an hour)", near(SaltPan.hoursToDry(pan), 4))
SaltPan.advance(pan, 6, 20, LIT(100))
check("boiled dry: a crust, the salt kept", pan.ml == 0 and SaltPan.look(pan) == SaltPan.CRUST and near(pan.salt, 3))
SaltPan.advance(pan, 30, 20, LIT(100))
check("left dry on the fire it comes to no harm", near(pan.salt, 3) and SaltPan.canScrape(pan))

-- Topping up builds the salt up
local fed = {}
SaltPan.pourInto(fed, 30, 3, 20, 0)
SaltPan.advance(fed, 2.5, 20, LIT(100))
local half = fed.ml
SaltPan.pourInto(fed, 10, 1, 20, 2.5)
check("topped up while boiling: the heat mixes, the salt adds up", fed.ml == half + 10000 and fed.tempC < 100
    and near(fed.salt, 4))

-- Banked
local banked = { }
SaltPan.pourInto(banked, 30, 3, 100, 0)
SaltPan.advance(banked, 3, 20, { fireUntil = 100, banked = true })
check("over banked embers it boils a third as fast", near(banked.ml, 30000 - 6000, 1))

-- The fire going out
local out = {}
SaltPan.pourInto(out, 30, 3, 20, 0)
SaltPan.advance(out, 3, 20, LIT(1.5))
check("only the fire's hours boil it, then it cools", near(out.ml, 30000 - 6000, 1) and out.tempC < 100 and out.tempC > 20)
SaltPan.advance(out, 20, 20, nil)
check("cold, the brine waits", near(out.ml, 24000, 1) and out.tempC < 21 and SaltPan.look(out) == SaltPan.BRINE)

-- Scrape and Remove
check("not off with brine in it", select(2, SaltPan.canRemove(out)) == "Full")
check("not off with a crust in it", select(2, SaltPan.canRemove(pan)) == "Crust" and not SaltPan.canScrape(out))
check("scraped: whole portions, the pan empty", SaltPan.scrape(pan, saltFor) == 3 and SaltPan.look(pan) == SaltPan.EMPTY
    and SaltPan.scrape(pan, saltFor) == 0)
SaltPan.advance(pan, 30, 20, nil)
check("hot just after, so not off yet", select(2, SaltPan.canRemove(pan)) == "Hot")
SaltPan.advance(pan, 40, 20, nil)
check("cool, it comes off, and keeps no clock", SaltPan.canRemove(pan) and pan.tempC == nil and pan.lastHour == nil)
local weak = {}
SaltPan.pourInto(weak, 5, 0.5, 20, 0)
SaltPan.advance(weak, 10, 20, LIT(100))
check("half a litre of Brine scrapes to nothing, and the pan is empty", SaltPan.scrape(weak, saltFor) == 0
    and SaltPan.look(weak) == SaltPan.EMPTY)
local poured = {}
SaltPan.pourInto(poured, 20, 2, 20, 0)
SaltPan.advance(poured, 1, 20, LIT(100))
check("emptied: the brine and its salt go, the heat stays, so it still has to cool",
    near(SaltPan.empty(poured), 20 - 6 * (1 - 0.5 * (20000 / 30000) ^ (1 / 3)), 0.3) and SaltPan.look(poured) == SaltPan.EMPTY
    and poured.salt == nil and select(2, SaltPan.canRemove(poured)) == "Hot" and SaltPan.empty(poured) == 0)
check("Fire's banked share is the third", Fire.BANKED_BURN == 1 / 3)
H.done()
