-- Traditional Preservation (Salt): the Salt Lick Map. It opens like vanilla's town maps (LootMaps.Init by the item's
-- Map id, ISMapDefinitions.lua) and shows the woods around one lick with a pencil ring over its area. The ring is on
-- the found map only. Vanilla reveals all a map shows on the world map; this one reveals only S.MAP_REVEAL_RADIUS
-- round the ring's centre, so the world map gains a small patch of woods, not the whole view.
require "ISUI/Maps/ISMapDefinitions"
require "TraditionalPreservationSalt"
local Wrap = require "TraditionalPreservationCore/Wrap"
local S = TraditionalPreservationSalt

local RING_TEXTURE = "media/textures/SaltLickMapRing.png"
-- The ring is drawn this far out of the picture's half width (tools/draw_map_ring.py).
local RING_DRAWN = 0.9

LootMaps.Init[S.MAP_ID] = function(mapUI)
    local mapItem = mapUI.mapItem or mapUI.mapObj
    local reader = mapUI.character or getPlayer()
    local x, y = math.floor(reader:getX()), math.floor(reader:getY())
    local cx, cy = S.mapRing(mapItem:getModData(), x, y)
    local hasRing = cx ~= nil
    -- Before the licks exist (a map read in the first minute of a new game) it shows the reader's own area.
    if not hasRing then cx, cy = x, y end
    -- revealKnownArea runs next (ISMap:initMapData) and reveals round this instead of the view.
    mapUI.saltLickRevealAt = { x = cx, y = cy }

    local mapAPI = mapUI.javaObject:getAPIv1()
    MapUtils.initDirectoryMapData(mapUI, LootMaps.DEFAULT_MAP_DIRECTORY)
    MapUtils.initDefaultStyleV3(mapUI)
    local view = S.MAP_VIEW_RADIUS
    mapAPI:setBoundsInSquares(cx - view, cy - view, cx + view, cy + view)

    if hasRing then
        local half = S.MAP_RING_RADIUS / RING_DRAWN
        local layer = mapAPI:getStyleAPI():newTextureLayer("saltLickRing")
        layer:setMinZoom(0)
        layer:addFill(0, 255, 255, 255, 255)
        layer:addTexture(0, RING_TEXTURE)
        layer:setBoundsInSquares(cx - half, cy - half, cx + half, cy + half)
    end
    MapUtils.overlayPaper(mapUI)
end

-- Single player for now: a multiplayer client also sends the whole view to the server (ISMap:initMapData).
Wrap.method("MapUtils", "revealKnownArea", function(vanilla, mapUI)
    local at = mapUI.saltLickRevealAt
    if not at then return vanilla(mapUI) end
    local r = S.MAP_REVEAL_RADIUS
    WorldMapVisited.getInstance():setKnownInSquares(at.x - r, at.y - r, at.x + r - 1, at.y + r - 1)
end)
