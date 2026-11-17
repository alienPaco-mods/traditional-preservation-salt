-- Traditional Preservation (Salt): the salt pan, a shallow forged pan about a metre across, set on TP Core's Stone
-- Hearth over its hole (an attachment, Fire.attach). Brine is poured in, any time, up to CAPACITY_ML of liquid; over the
-- fire it heats to the boil and boils away, the salt staying behind, until it is dry: a crust, scraped off with a
-- knife. Topped up while it boils, the salt builds up. Left dry on the fire it comes to no harm.
--
-- This file is the pan's rules on its state (the attachment's part: Fire.partModData under SaltPan.ID), with no game
-- objects in it, so a test runs them alone. Inside: ml (liquid), salt (litres of Brine poured in since the last
-- scrape: S.saltFor gives the portions), tempC, lastHour.
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Fire = require "TraditionalPreservationCore/Fire"

local SaltPan = {}

-- Its attachment id: the pan's state is under it in the fire's. Save value: never rename it once the mod is out.
SaltPan.ID = "saltPan"

SaltPan.CAPACITY_ML = 30000
SaltPan.BOIL_C = CauldronFluid.BOIL_C
SaltPan.HOT_C = CauldronFluid.HOT_C           -- steams from here
SaltPan.REMOVE_BELOW_C = 40                   -- cool enough to lift off
SaltPan.BOIL_ML_PER_HOUR = 6000               -- boiled off over a lit fire; a banked one a third (Fire.BANKED_BURN)
-- Heating: towards FIRE_C, so a full pan at 20 C boils in about half an hour (LIT_TAU); a smaller fill sooner, by the
-- cube root of its share, as the cauldron. Cooling to the air: OUT_TAU, a thin pan in the open top of the stone.
SaltPan.FIRE_C = 130
SaltPan.LIT_TAU = 0.5 / math.log((130 - 20) / (130 - 100))
SaltPan.OUT_TAU = 1.0
SaltPan.FLOOR_ML = 2000

-- Looks: what its tiles show.
SaltPan.EMPTY, SaltPan.BRINE, SaltPan.BOILING, SaltPan.CRUST = "Empty", "Brine", "Boiling", "Crust"

local function tau(pan, banked)
    local base = banked and SaltPan.LIT_TAU / Fire.BANKED_BURN or SaltPan.LIT_TAU
    return base * (math.max(pan.ml or 0, SaltPan.FLOOR_ML) / SaltPan.CAPACITY_ML) ^ (1 / 3)
end

local function hoursTo(fromC, toC, target, timeConstant)
    return timeConstant * math.log((target - fromC) / (target - toC))
end

-- Litres of liquid more it takes.
function SaltPan.roomL(pan)
    return math.max(SaltPan.CAPACITY_ML - (pan.ml or 0), 0) / CauldronFluid.ML_PER_L
end

-- Pours litres of liquid in, brine of them Brine, at fluidC; the heat mixes by volume (a dry pan's own heat counts
-- for nothing). Returns the litres taken, as many as there is room for, Brine in the same share.
function SaltPan.pourInto(pan, litres, brine, fluidC, now)
    local taken = math.min(litres, SaltPan.roomL(pan))
    if taken <= 0 then return 0 end
    local had, ml = pan.ml or 0, taken * CauldronFluid.ML_PER_L
    pan.tempC = had > 0 and ((pan.tempC or fluidC) * had + fluidC * ml) / (had + ml) or fluidC
    pan.ml = had + ml
    pan.salt = (pan.salt or 0) + brine * taken / litres
    pan.lastHour = pan.lastHour or now
    return taken
end

-- Hours of fire under the pan, lit or banked: it heats to the boil, then boils away until dry, held at the boil.
local function heat(pan, hours, banked)
    if (pan.ml or 0) <= 0 then
        pan.tempC = SaltPan.BOIL_C
        return
    end
    local timeConstant = tau(pan, banked)
    local toBoil = pan.tempC >= SaltPan.BOIL_C and 0 or hoursTo(pan.tempC, SaltPan.BOIL_C, SaltPan.FIRE_C, timeConstant)
    if hours <= toBoil then
        pan.tempC = CauldronFluid.cool(pan.tempC, SaltPan.FIRE_C, hours, timeConstant)
        return
    end
    pan.tempC = SaltPan.BOIL_C
    local rate = SaltPan.BOIL_ML_PER_HOUR * (banked and Fire.BANKED_BURN or 1)
    pan.ml = math.max(pan.ml - rate * (hours - toBoil), 0)
end

-- Brings the pan up to now by the fire's state (fireUntil, banked; nil for no fire): heating and boiling while the
-- fire burns, cooling to airC after. An empty pan keeps its clock only until it is cool.
function SaltPan.advance(pan, now, airC, fire)
    local hour = pan.lastHour or now
    pan.tempC = pan.tempC or airC
    local fireUntil = fire and fire.fireUntil
    if fireUntil and fireUntil > hour then
        local stop = math.min(fireUntil, now)
        heat(pan, stop - hour, fire.banked)
        hour = stop
    end
    if now > hour then pan.tempC = CauldronFluid.cool(pan.tempC, airC, now - hour, SaltPan.OUT_TAU) end
    pan.lastHour = now
    if SaltPan.look(pan) == SaltPan.EMPTY and pan.tempC < SaltPan.REMOVE_BELOW_C then pan.tempC, pan.lastHour = nil, nil end
end

-- Empty, Brine, Boiling (steaming, at HOT_C or more) or Crust (dry, salt in it).
function SaltPan.look(pan)
    if (pan.ml or 0) > 0 then return (pan.tempC or 0) >= SaltPan.HOT_C and SaltPan.BOILING or SaltPan.BRINE end
    if (pan.salt or 0) > 0 then return SaltPan.CRUST end
    return SaltPan.EMPTY
end

-- Dry with salt in it: Scrape Salt Pan is offered.
function SaltPan.canScrape(pan)
    return SaltPan.look(pan) == SaltPan.CRUST
end

-- Scrapes the crust off: the portions of Evaporated Salt it gives (whole ones, as the bucket's), the pan emptied.
function SaltPan.scrape(pan, saltFor)
    if not SaltPan.canScrape(pan) then return 0 end
    local portions = saltFor(pan.salt)
    pan.salt = nil
    return portions
end

-- Pours the brine away, the salt in it with it. Returns the litres poured. The pan keeps its heat, so a hot one still
-- has to cool before it comes off.
function SaltPan.empty(pan)
    local ml = pan.ml or 0
    if ml <= 0 then return 0 end
    pan.ml, pan.salt = nil, nil
    return ml / CauldronFluid.ML_PER_L
end

-- Off only empty and cool (the fire is out: Core asks that first).
function SaltPan.canRemove(pan)
    if (pan.ml or 0) > 0 then return false, "Full" end
    if (pan.salt or 0) > 0 then return false, "Crust" end
    if (pan.tempC or 0) >= SaltPan.REMOVE_BELOW_C then return false, "Hot" end
    return true
end

-- Hours until the pan is dry if a lit fire burns on, from now; nil for an empty or dry pan.
function SaltPan.hoursToDry(pan)
    if (pan.ml or 0) <= 0 then return nil end
    local toBoil = pan.tempC >= SaltPan.BOIL_C and 0 or hoursTo(pan.tempC, SaltPan.BOIL_C, SaltPan.FIRE_C, tau(pan, false))
    return toBoil + pan.ml / SaltPan.BOIL_ML_PER_HOUR
end

return SaltPan
