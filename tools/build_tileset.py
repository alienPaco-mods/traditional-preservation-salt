#!/usr/bin/env python3
"""Builds the Traditional Preservation (Salt) tileset (42/media/traditionalpreservationsalt.tiles and texturepacks/traditionalpreservationsalt.pack).

Tile 0 is the empty Leaching Vat. Tiles 2 and 3 are the vat while leaching and when finished. They are overlays,
so each repaints the whole vat to keep the frame in front. PATCH_TILES are the mineral soil that marks a salt lick, one
for each combination of sides with a neighbour, and WORKED_TILES the same once worked out. Tiles 9, 10 and 11 are the vat a quarter turn
round: empty, leaching and finished. The narrow end is the front, so tile 0 faces east and tile 9 south.
Workstations need their own sprite: the game refuses to load a world if two entities share one.

It also writes the item icons and bucket model textures to 42/media/textures. The buckets are vanilla art with the
fluid recoloured, so they read the game's files. The Evaporated Salt icon and pile texture are painted here. The Bag of Salt is vanilla's
Sugar bag retinted and relabelled.

Usage: python3 tools/build_tileset.py [path/to/ProjectZomboid/projectzomboid]
Needs Pillow. Rerun after editing the colours or sizes below.
"""
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import pzart  # noqa: E402
from pzart import TILE_W, TILE_H, shrink, tint  # noqa: E402

NAME = "traditionalpreservationsalt"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 5
PAGE_SIZE = 1024
SUPERSAMPLE = 4

# The vat, after the plank leaching vats at Mammoth Cave: a V-shaped trough in a log frame.
# x and y are in tiles from the middle of the floor (+x runs down-right, +y down-left), z in pixels.
TROUGH_X = (-0.33, 0.27)
TROUGH_FLARE = 0.07  # how far the rim overhangs the keel at each end
RIM_HALF_WIDTH, KEEL_HALF_WIDTH = 0.31, 0.05
RIM_Z, KEEL_Z = 66, 12
SIDE_BOARDS, END_BOARDS = 6, 4
RIM_THICKNESS = 0.05  # tiles: how thick the boards look from above
RIM_LIP = 4.0  # pixels: the rim's outer face
RIM_TOP = (150, 108, 72)
BATTEN_RADIUS = 1.7
POST_X, POST_Y = 0.43, 0.41
POST_HEIGHT, RAIL_Z = 92, 80
POST_RADIUS, RAIL_RADIUS, SILL_RADIUS = 3.0, 2.6, 3.4
SIDE_WOOD = (112, 74, 46)
END_WOOD = (66, 45, 30)
# A quarter turn round, the long side is away from the light and the end faces it.
TURNED_SIDE_WOOD = (72, 49, 33)
TURNED_END_WOOD = (116, 77, 48)
INSIDE_WOOD = (100, 68, 44)
LOG = (94, 64, 42)
CHARRED_LOG = (44, 36, 31)
CUT_END = (186, 146, 116)
BOARD_SEAM = (30, 20, 14)
BOARD_GRAIN = (0.74, 0.86, 0.94, 1.06, 1.16)
BEAM_DARK_FACE = 0.56
VAT_WEATHER = 0.3
DUST = (150, 138, 122)
VAT_SEED = 1810
SOIL_DROP = 9  # pixels below the rim
WET_SOIL = (62, 50, 42)
SPENT_SOIL = (128, 112, 94)
BUCKET_POSITION = (0.33, 0.03)
# The bucket follows the vanilla Item_MetalBucket icon: tapered galvanised steel, a rolled rim,
# a ridge around the middle and a wire handle. The greys are the dark steel it shows in the world.
BUCKET_TOP_RADIUS, BUCKET_BASE_RADIUS, BUCKET_HEIGHT = 8.5, 6.2, 13.0
BUCKET_SQUASH = 0.5
BUCKET_RIDGE = 0.55  # as a fraction of the height
GALVANISED = (84, 86, 88)
BUCKET_RIM = (108, 110, 112)
BUCKET_INSIDE = (50, 50, 50)
BUCKET_WIRE = (39, 41, 47)
BRINE = (138, 126, 90)
DRIP = (150, 170, 176)
VAT_LEACHING = dict(soil=WET_SOIL, brine=False)
VAT_FINISHED = dict(soil=SPENT_SOIL, brine=True)
SHADOW = (0, 0, 0, 90)

# The empty shaker is vanilla's. The cap's lower edge runs from this point on the icon at this slope.
SHAKER_CAP_EDGE = (7, 14)
SHAKER_CAP_SLOPE = 0.46
SHAKER_OUTLINE = 70
SHAKER_HIGHLIGHT = 225
SHAKER_GLASS = (206, 226, 232, 90)
# On SaltPepper.png: bare glass to copy, and the salt it covers.
SHAKER_GLASS_SAMPLE = (7, 14, 22, 22)
SHAKER_SALT_AREA = (5, 24, 26, 61)
CRUST = (214, 208, 190)
CRUST_BRIGHT = (236, 233, 222)
# Dark mineral soil scattered with salt grains. Worked out, it is paler and most of the grains are gone.
MINERAL_SOIL = (20, 16, 15)
MINERAL_SOIL_LIGHT = (40, 32, 28)
WORKED_SOIL = (60, 49, 40)
WORKED_SOIL_LIGHT = (82, 68, 55)
SALT_GRAIN = (236, 234, 226)
WORKED_GRAIN = (176, 170, 158)
SALT_GRAINS, WORKED_GRAINS = 120, 20
PATCH_SEED = 42
# Measured from vanilla's floor tiles, which step 64 by 32 on the grid. The soil must fit this exactly, or grass shows
# between tiles. pzart's FOOT and DIAMOND_HALF are a little smaller, which suits the vat standing inside its tile.
FLOOR_MIDDLE = (62.5, 223.5)
FLOOR_HALF_W, FLOOR_HALF_H = 64, 32
# In tiles. An open side sits PATCH_INSET in from the tile edge and wanders by PATCH_RAGGED either way.
PATCH_INSET, PATCH_RAGGED = 0.1, 0.16
PATCH_SEAM = 0.025  # joined sides overlap by a pixel or two, so no line of grass shows between tiles
PATCH_ROUNDING = 22
SIDE_N, SIDE_E, SIDE_S, SIDE_W = 1, 2, 4, 8  # must match TraditionalPreservationSalt.edgeMask
# The vat facing east, then south: empty, leaching, finished. The Lua reads these from the generated Tiles.lua.
VAT_TILES = {"E": (0, 2, 3), "S": (9, 10, 11)}
# Indexed by side mask.
PATCH_TILES = (1, 4, 5, *range(12, 25))
WORKED_TILES = (6, 7, 8, *range(25, 38))

ICON_SIZE = 32
SALT = (226, 224, 218)
SALT_SHADOW = (176, 174, 170)
SALT_OUTLINE = (24, 20, 22)
SALT_PILE_SEED = 7
SALT_TEXTURE_SIZE = 64  # the same as vanilla's Poultice texture, which is plain grain all over
CHARGE_SOIL = (98, 76, 58)
# Name stem: (colour, whether it is solid). Solids get a rough, matt finish instead of the fluid's shading.
BUCKET_CONTENTS = {"BucketBrine": (BRINE, False), "BucketSaltCrust": (CRUST_BRIGHT, True), "LeachingCharge": (CHARGE_SOIL, True)}
SOLID_SPECKS = (0.72, 1.08)
# The Sugar bag's blue band and pink ring become kraft paper and brown print.
BAG_BAND = (196, 168, 124)
BAG_PRINT = (112, 82, 58)
BAG_PAPER = (240, 238, 232)
BAG_LABEL = (5, 39, 26, 76)  # the oval around SUGAR on the model texture
BAG_SMALL_LABEL = (32, 52, 45, 63)
LETTERS = {"S": ("111", "100", "111", "001", "111"), "A": ("111", "101", "111", "101", "101"),
           "L": ("100", "100", "100", "100", "111"), "T": ("111", "010", "010", "010", "010")}

TILE_PROPS = {
    # The engine only links the facings of tiles with a GroupName, and that link lets a moved vat rotate.
    **{index: [("BlocksPlacement", ""), ("CustomName", "Vat"), ("Facing", facing), ("GroupName", "Leaching"), ("IsMoveAble", ""), ("PickUpWeight", "200"), ("solidtrans", "")]
       for facing, (index, _, _) in VAT_TILES.items()},
    **{index: [("CustomName", "Salt Lick")] for index in PATCH_TILES + WORKED_TILES},
}


def new_layer():
    return pzart.new_layer(SUPERSAMPLE)


turned = False  # swaps x and y, which turns the vat a quarter while keeping the back-to-front order


def project(x, y, z=0.0):
    """pzart.project on the supersampled layer, turned a quarter when turned is set."""
    if turned:
        x, y = y, x
    x, y = pzart.project(x, y, z)
    return x * SUPERSAMPLE, y * SUPERSAMPLE


def lerp(a, b, amount):
    return tuple(a[i] + (b[i] - a[i]) * amount for i in range(len(a)))


def paint_boards(draw, rng, first, second, boards, colour, light, ragged=0.0):
    """Fills the face between two edges with boards that run from the first edge to the second. They follow
    vanilla's rain barrels: even tone, fine grain and a thin dark seam."""
    s = SUPERSAMPLE
    for i in range(boards):
        t0, t1 = i / boards, (i + 1) / boards
        lift = (0, 0, rng.uniform(0, ragged))
        start = [tuple(map(sum, zip(lerp(*first, t), lift))) for t in (t0, t1)]
        end = [lerp(*second, t) for t in (t1, t0)]
        shade = light * rng.uniform(0.93, 1.07)
        draw.polygon([project(*point) for point in start + end], fill=tint(colour, shade))
        for _ in range(26):
            t = rng.uniform(t0, t1)
            along, run = rng.random(), rng.uniform(0.08, 0.3)
            grain = [project(*lerp(lerp(first[0], first[1], t), lerp(second[0], second[1], t), u)) for u in (along, min(1, along + run))]
            draw.line(grain, fill=tint(colour, shade * rng.choice(BOARD_GRAIN)), width=max(1, s // 2))
        seam = [project(*lerp(*edge, t1)) for edge in (first, second)]
        draw.line(seam, fill=BOARD_SEAM + (255,), width=max(2, s * 3 // 4))


def paint_log(draw, rng, start, end, radius, colour, cap=True):
    """A sawn beam after vanilla's butcher hook: one lit face, one dark, grain along it, and pale end grain."""
    s = SUPERSAMPLE
    a, b = project(*start), project(*end)
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    nx, ny = -uy, ux
    if (abs(uy) > abs(ux) and nx < 0) or (abs(uy) <= abs(ux) and ny < 0):
        nx, ny = -nx, -ny  # points to the dark side
    w = radius * s

    def strip(near, far):
        return [(a[0] + nx * near, a[1] + ny * near), (b[0] + nx * near, b[1] + ny * near),
                (b[0] + nx * far, b[1] + ny * far), (a[0] + nx * far, a[1] + ny * far)]

    for near, far, shade in ((-w, 0, 1.0), (0, w, BEAM_DARK_FACE)):
        draw.polygon(strip(near, far), fill=tint(colour, shade))
        for _ in range(int(length / s * radius * 0.7)):
            t = rng.random()
            run = min(rng.uniform(3, 12) * s / length, 1 - t)
            across = rng.uniform(near, far)
            first = (a[0] + (b[0] - a[0]) * t + nx * across, a[1] + (b[1] - a[1]) * t + ny * across)
            second = (first[0] + (b[0] - a[0]) * run, first[1] + (b[1] - a[1]) * run)
            draw.line([first, second], fill=tint(colour, shade * rng.choice(BOARD_GRAIN)), width=max(1, s // 2))
    draw.line(strip(0, 0)[:2], fill=BOARD_SEAM + (255,), width=max(1, s // 2))
    draw.line(strip(w, w)[:2], fill=BOARD_SEAM + (255,), width=max(1, s // 2))
    if cap:
        lift = (ux * w * 0.8, uy * w * 0.8)
        corners = strip(-w, w)[1:3]
        draw.polygon(corners + [(corners[1][0] + lift[0], corners[1][1] + lift[1]), (corners[0][0] + lift[0], corners[0][1] + lift[1])], fill=tint(CUT_END, 1.0))


def weather(tile, seed, depth):
    """Mottles a finished tile with dirt, grain and water stains running down it, because vanilla art is
    hand painted and never flat."""
    return pzart.weather(tile, random.Random(seed), depth, streaks=True)


def paint_soil(draw, soil):
    """The charge heaped in the trough, a little below the rim."""
    rng = random.Random(VAT_SEED + 1)
    z = RIM_Z - SOIL_DROP
    depth = SOIL_DROP / (RIM_Z - KEEL_Z)
    back = lerp((TROUGH_X[0] - TROUGH_FLARE,), (TROUGH_X[0],), depth)[0]
    front = lerp((TROUGH_X[1] + TROUGH_FLARE,), (TROUGH_X[1],), depth)[0]
    half = lerp((RIM_HALF_WIDTH,), (KEEL_HALF_WIDTH,), depth)[0]
    draw.polygon([project(back, -half, z), project(front, -half, z), project(front, half, z), project(back, half, z)], fill=tint(soil, 0.9))
    for _ in range(170):
        x, y = project(rng.uniform(back, front), rng.uniform(-half, half), z + rng.uniform(0, 2))
        r = rng.uniform(0.6, 2.0) * SUPERSAMPLE
        draw.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=tint(soil, rng.uniform(0.72, 1.2)))


def paint_bucket(draw, brine):
    """The bucket under the end of the keel, lit from the left like everything else."""
    s = SUPERSAMPLE
    rng = random.Random(VAT_SEED + 2)
    cx, fy = project(*BUCKET_POSITION)
    top_r, base_r, height = BUCKET_TOP_RADIUS * s, BUCKET_BASE_RADIUS * s, BUCKET_HEIGHT * s
    top = fy - height

    def around(u, level):
        """The point on the front of the bucket, u from -1 to 1, level from base to rim."""
        r = base_r + (top_r - base_r) * level
        return cx + u * r, fy - height * level + r * BUCKET_SQUASH * math.sqrt(max(0.0, 1 - u * u))

    columns = int(top_r * 2)
    for i in range(columns + 1):
        u = i / columns * 2 - 1
        light = 1.08 - 0.46 * (u + 1) / 2
        for step in range(6):
            mottle = rng.uniform(0.9, 1.08)
            draw.line([around(u, step / 6), around(u, (step + 1) / 6)], fill=tint(GALVANISED, light * mottle), width=2)

    ridge = [around(i / 12 - 1, BUCKET_RIDGE) for i in range(25)]
    draw.line(ridge, fill=tint(GALVANISED, 0.56), width=s)
    draw.line([(x, y - s) for x, y in ridge], fill=tint(BUCKET_RIM, 0.92), width=max(1, s // 2))

    ry = top_r * BUCKET_SQUASH
    draw.ellipse([cx - top_r, top - ry, cx + top_r, top + ry], fill=tint(BUCKET_RIM, 1.0))
    inner = 0.86
    draw.ellipse([cx - top_r * inner, top - ry * inner, cx + top_r * inner, top + ry * inner], fill=tint(BUCKET_INSIDE, 1.0))
    if brine:
        level, drop = 0.74, 1.2 * s
        draw.ellipse([cx - top_r * level, top - ry * level + drop, cx + top_r * level, top + ry * level + drop], fill=tint(BRINE, 1.0))
    else:
        keel = project(TROUGH_X[1], 0, KEEL_Z)
        draw.line([keel, (cx, top)], fill=tint(DRIP, 1.0), width=max(1, s // 2))

    wire = [(cx + top_r * math.cos(math.pi * i / 16), top - 7 * s * math.sin(math.pi * i / 16)) for i in range(17)]
    draw.line(wire, fill=tint(BUCKET_WIRE, 1.0), width=max(1, s // 2 + 1), joint="curve")
    for side in (-1, 1):
        x = cx + side * top_r
        draw.rectangle([x - s * 0.7, top - s * 0.7, x + s * 0.7, top + s * 0.7], fill=tint(BUCKET_WIRE, 1.0))


def paint_vat(contents=None, quarter_turn=False):
    global turned
    turned = quarter_turn
    side_wood, end_wood = (TURNED_SIDE_WOOD, TURNED_END_WOOD) if quarter_turn else (SIDE_WOOD, END_WOOD)
    inside_side, inside_end = (0.62, 0.8) if quarter_turn else (0.8, 0.62)
    rng = random.Random(VAT_SEED)
    layer = new_layer()

    draw = ImageDraw.Draw(layer)

    back, front = TROUGH_X
    width, keel = RIM_HALF_WIDTH, KEEL_HALF_WIDTH
    rim_back, rim_front = back - TROUGH_FLARE, front + TROUGH_FLARE

    def rim(x, y):
        return (x, y, RIM_Z)

    def bottom(x, y):
        return (x, y, KEEL_Z)

    far_post, left_post = (-POST_X, -POST_Y), (-POST_X, POST_Y)
    right_post, near_post = (POST_X, -POST_Y), (POST_X, POST_Y)

    # Back to front: what stands behind the trough first.
    paint_log(draw, rng, (*left_post, 3), (*far_post, 3), SILL_RADIUS, LOG)
    paint_log(draw, rng, (*far_post, 0), (*far_post, POST_HEIGHT), POST_RADIUS, LOG)
    paint_log(draw, rng, (-POST_X - 0.04, -POST_Y, RAIL_Z), (POST_X + 0.05, -POST_Y, RAIL_Z), RAIL_RADIUS, LOG)
    paint_log(draw, rng, (back, 0, 5), (front, 0, 5), SILL_RADIUS, CHARRED_LOG)

    paint_boards(draw, rng, (rim(rim_back, -width), rim(rim_front, -width)),
                 (bottom(back, -keel), bottom(front, -keel)), SIDE_BOARDS, INSIDE_WOOD, inside_side)
    paint_boards(draw, rng, (rim(rim_back, width), rim(rim_back, -width)),
                 (bottom(back, keel), bottom(back, -keel)), 4, INSIDE_WOOD, inside_end)
    if contents:
        paint_soil(draw, contents["soil"])
    paint_boards(draw, rng, (rim(rim_back, width), rim(rim_front, width)),
                 (bottom(back, keel), bottom(front, keel)), SIDE_BOARDS, side_wood, 1.0)
    paint_boards(draw, rng, (rim(rim_front, width), bottom(front, keel)),
                 (rim(rim_front, -width), bottom(front, -keel)), END_BOARDS, end_wood, 1.0)
    for _ in range(26):
        z = rng.uniform(KEEL_Z + 8, RIM_Z - 3)
        up = (z - KEEL_Z) / (RIM_Z - KEEL_Z)
        half = (keel + (width - keel) * up) * 0.7
        x, y = project(front + TROUGH_FLARE * up, rng.uniform(-half, half), z)
        draw.line([(x, y), (x + rng.uniform(1, 4) * SUPERSAMPLE, y - rng.uniform(0, 1) * SUPERSAMPLE)], fill=tint(DUST, 0.8), width=max(1, SUPERSAMPLE // 2))

    # Battens down the near corners, then the rim, so the trough reads as solid boards.
    for side in (width, -width):
        keel_side = keel if side > 0 else -keel
        paint_log(draw, rng, (rim_front, side, RIM_Z), (front, keel_side, KEEL_Z), BATTEN_RADIUS, LOG, cap=False)
    paint_log(draw, rng, (rim_back, width, RIM_Z), (back, keel, KEEL_Z), BATTEN_RADIUS, LOG, cap=False)
    paint_rim(draw, rng, rim_back, rim_front, width, side_wood, end_wood)

    if contents:
        paint_bucket(draw, contents["brine"])

    # The charred prop along the near side, then the frame in front of the trough.
    paint_log(draw, rng, (back - 0.02, 0.34, 20), (front + 0.1, 0.27, 3), SILL_RADIUS, CHARRED_LOG)
    paint_log(draw, rng, (*left_post, 0), (*left_post, POST_HEIGHT - 12), POST_RADIUS, LOG)
    paint_log(draw, rng, (*right_post, 3), (*near_post, 3), SILL_RADIUS, LOG)
    paint_log(draw, rng, (*right_post, 0), (*right_post, POST_HEIGHT), POST_RADIUS, LOG)
    paint_log(draw, rng, (POST_X - 0.02, POST_Y - 0.04, 4), (POST_X - 0.14, POST_Y - 0.04, 34), RAIL_RADIUS, LOG)
    paint_log(draw, rng, (*near_post, 0), (*near_post, POST_HEIGHT + 6), POST_RADIUS, LOG)
    paint_log(draw, rng, (-POST_X - 0.05, POST_Y, RAIL_Z), (POST_X + 0.05, POST_Y, RAIL_Z + 3), RAIL_RADIUS, LOG)
    turned = False
    return weather(shrink(layer), VAT_SEED, VAT_WEATHER)


def paint_rim(draw, rng, back, front, half_width, side_wood, end_wood):
    """The thickness of the boards along the top of the trough, so they don't read as thin sheets."""
    t = RIM_THICKNESS
    bands = [(back, -half_width, front, -half_width + t), (back, -half_width, back + t, half_width),
             (back, half_width - t, front, half_width), (front - t, -half_width, front, half_width)]
    for x0, y0, x1, y1 in bands:
        corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        draw.polygon([project(x, y, RIM_Z) for x, y in corners], fill=tint(RIM_TOP, rng.uniform(0.94, 1.06)))
        for _ in range(16):
            u, v = rng.random(), rng.random()
            x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * v
            dx, dy = ((x1 - x0) * 0.2, 0) if x1 - x0 > y1 - y0 else (0, (y1 - y0) * 0.2)
            draw.line([project(x, y, RIM_Z), project(min(x + dx, x1), min(y + dy, y1), RIM_Z)], fill=tint(RIM_TOP, rng.choice(BOARD_GRAIN)), width=max(1, SUPERSAMPLE // 2))
    for first, second, wood in (((back, half_width), (front, half_width), side_wood), ((front, half_width), (front, -half_width), end_wood)):
        draw.polygon([project(*first, RIM_Z), project(*second, RIM_Z), project(*second, RIM_Z - RIM_LIP), project(*first, RIM_Z - RIM_LIP)], fill=tint(wood, 0.82))
        draw.line([project(*first, RIM_Z - RIM_LIP), project(*second, RIM_Z - RIM_LIP)], fill=BOARD_SEAM + (255,), width=max(1, SUPERSAMPLE // 2))
    for first, second in (((back, -half_width), (front, -half_width)), ((back, half_width - t), (front, half_width - t)), ((front - t, -half_width), (front - t, half_width))):
        draw.line([project(*first, RIM_Z), project(*second, RIM_Z)], fill=BOARD_SEAM + (255,), width=max(1, SUPERSAMPLE // 2))


def floor_noise(rng, cells):
    """Smooth noise over the tile, 0 to 1, with blobs twice as wide as tall to lie flat on the floor."""
    small = Image.new("L", (cells, cells * TILE_H // TILE_W * 2))
    small.putdata([rng.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((TILE_W, TILE_H), Image.BICUBIC)


def paint_patch(mask, worked=False):
    """One tile of a deposit. Sides in mask have a neighbour, so the soil runs right to that edge and on into it.

    The other sides are ragged, but the raggedness fades out towards each end of a side, so the outline
    meets the next tile's at the same inset. Worked or not gives the same outline, so only the colour changes.
    """
    rng = random.Random(PATCH_SEED + mask)
    outline, detail, mottle = floor_noise(rng, 6), floor_noise(rng, 26), floor_noise(rng, 11)
    dark, light, salt = (WORKED_SOIL, WORKED_SOIL_LIGHT, WORKED_GRAIN) if worked else (MINERAL_SOIL, MINERAL_SOIL_LIGHT, SALT_GRAIN)
    grains = set()
    for _ in range(WORKED_GRAINS if worked else SALT_GRAINS):
        x = int(FLOOR_MIDDLE[0] + rng.uniform(-FLOOR_HALF_W, FLOOR_HALF_W))
        y = int(FLOOR_MIDDLE[1] + rng.uniform(-FLOOR_HALF_H, FLOOR_HALF_H))
        grains.update({(x, y), (x + 1, y)} if rng.random() < 0.4 else {(x, y)})

    tile = Image.new("RGBA", (TILE_W, TILE_H), (0, 0, 0, 0))
    pixels = tile.load()
    for y in range(TILE_H):
        for x in range(TILE_W):
            speck = rng.uniform(0.94, 1.04)
            grain = detail.getpixel((x, y)) / 255
            shade = mottle.getpixel((x, y)) / 255 * 0.65 + grain * 0.35
            across, down = (x - FLOOR_MIDDLE[0]) / FLOOR_HALF_W, (y - FLOOR_MIDDLE[1]) / FLOOR_HALF_H
            tile_x, tile_y = (across + down) / 2, (down - across) / 2  # -0.5 to 0.5 across the floor diamond

            open_sides, joined = [], True
            for side, outward, along in ((SIDE_N, -tile_y, tile_x), (SIDE_E, tile_x, tile_y), (SIDE_S, tile_y, tile_x), (SIDE_W, -tile_x, tile_y)):
                if mask & side:
                    joined = joined and outward <= 0.5 + PATCH_SEAM
                else:
                    wander = (outline.getpixel((x, y)) / 255 - 0.5) * 2 * PATCH_RAGGED * math.cos(math.pi * min(0.5, abs(along)))
                    open_sides.append(0.5 - PATCH_INSET + wander - outward)
            if not joined:
                continue
            # A soft minimum, which rounds the corners where two open sides meet.
            edge = -math.log(sum(math.exp(-PATCH_ROUNDING * side) for side in open_sides)) / PATCH_ROUNDING if open_sides else 1.0
            if edge <= 0:
                continue
            colour = lerp(dark, light, min(1.0, max(0.0, (shade - 0.3) / 0.4)))
            alpha = min(1.0, edge * 28)  # solid, or the overlap on joined sides shows as a darker line
            if (x, y) in grains and edge > 0.03:  # inside the soil, so no grain floats on the grass
                colour, alpha, speck = salt, 1.0, 1.0
            pixels[x, y] = tuple(min(255, int(c * speck)) for c in colour) + (int(alpha * 255),)
    return tile


def retint_bag(image):
    """Turns the Sugar bag's blues and pinks to BAG_BAND and BAG_PRINT, keeping their light and dark."""
    result = image.copy()
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = pixels[x, y]
            light = max(r, g, b) / 225
            if b - r > 12 and (b - r) / b > 0.16:  # the paper is pale blue too, but far less saturated
                pixels[x, y] = tint(BAG_BAND, light)[:3] + (a,)
            elif r - g > 28:
                pixels[x, y] = tint(BAG_PRINT, light)[:3] + (a,)
    return result


def print_word(image, word, box):
    """Prints word in the pixel letters, scaled to the box as the model's UVs stretch it."""
    left, top, right, bottom = box
    letters = Image.new("RGBA", (len(word) * 4 - 1, 5), (0, 0, 0, 0))
    for index, letter in enumerate(word):
        for row, line in enumerate(LETTERS[letter]):
            for column, cell in enumerate(line):
                if cell == "1":
                    letters.putpixel((index * 4 + column, row), BAG_PRINT + (255,))
    image.alpha_composite(letters.resize((right - left + 1, bottom - top + 1), Image.BILINEAR), (left, top))


def paint_salt_bag_texture(texture):
    """Retints the Sugar texture and swaps both SUGAR labels for SALT."""
    bag = retint_bag(texture)
    draw = ImageDraw.Draw(bag)
    draw.ellipse(BAG_LABEL, fill=BAG_PAPER + (255,))
    draw.rectangle(BAG_SMALL_LABEL, fill=bag.getpixel((BAG_SMALL_LABEL[0] - 2, BAG_SMALL_LABEL[1] - 2)))
    left, top, right, bottom = BAG_LABEL
    print_word(bag, "SALT", (left + 3, (top + bottom) // 2 - 6, right - 3, (top + bottom) // 2 + 6))
    print_word(bag, "SALT", (BAG_SMALL_LABEL[0] + 1, BAG_SMALL_LABEL[1] + 2, BAG_SMALL_LABEL[2] - 1, BAG_SMALL_LABEL[3] - 2))
    return bag


def recolour(image, is_fluid, colour, solid):
    """Repaints the fluid pixels in colour, keeping their light and dark unless the contents are solid."""
    return pzart.recolour(image, is_fluid, colour, solid, random.Random(VAT_SEED), SOLID_SPECKS)


def paint_salt_icon():
    """A low, lumpy heap of salt with a dark outline."""
    rng = random.Random(SALT_PILE_SEED)
    size, centre, half = ICON_SIZE, 15.5, 14.5
    lumps = [(9, 3.0, 2.5), (15, 3.5, 4.5), (21, 3.0, 2.0), (26, 2.5, 1.0), (5, 2.0, 0.8)]
    patches = {(x, y): rng.random() ** 2.5 for x in range(size) for y in range(size)}

    def top(x):
        across = abs(x - centre) / half
        return 22 - 8 * (1 - across ** 1.7) - sum(h * math.exp(-((x - c) / w) ** 2) for c, w, h in lumps)

    def bottom(x):
        return 25 - 3 * ((x - centre) / half) ** 2 + rng.choice((0, 0, 1))

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = icon.load()
    for x in range(1, size - 1):
        high, low = int(top(x)), int(bottom(x))
        for y in range(high, low + 1):
            light = 1.0 - 0.08 * max(0.0, (x - centre) / half) - 0.1 * (y - high) / max(1, low - high)
            pixels[x, y] = tint(lerp(SALT, SALT_SHADOW, patches[x // 2, y // 2]), light)

    outlined = icon.copy()
    edges = outlined.load()
    for y in range(size):
        for x in range(size):
            neighbours = ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
            if pixels[x, y][3] and any(not 0 <= a < size or not 0 <= b < size or pixels[a, b][3] == 0 for a, b in neighbours):
                edges[x, y] = SALT_OUTLINE + (255,)
    return outlined


def paint_salt_texture():
    """Coarse white grains with a few greyer ones, for vanilla's Poultice mesh."""
    rng = random.Random(SALT_PILE_SEED)
    size = SALT_TEXTURE_SIZE
    texture = Image.new("RGBA", (size, size))
    pixels = texture.load()
    for y in range(size):
        for x in range(size):
            pixels[x, y] = tint(lerp(SALT, SALT_SHADOW, rng.random() ** 2.5), rng.uniform(0.92, 1.08))
    return texture


def paint_empty_shaker_icon(icon):
    """Vanilla's shaker with the salt gone: the cap, outline and highlights stay, and the glass shows through."""
    art = icon.convert("RGBA")
    empty = art.copy()
    for y in range(art.height):
        for x in range(art.width):
            r, g, b, a = art.getpixel((x, y))
            in_cap = y < SHAKER_CAP_EDGE[0] + (x - SHAKER_CAP_EDGE[1]) * SHAKER_CAP_SLOPE
            if a == 0 or in_cap or max(r, g, b) < SHAKER_OUTLINE or min(r, g, b) >= SHAKER_HIGHLIGHT or b > r + 10:
                continue
            empty.putpixel((x, y), SHAKER_GLASS)
    return empty


def paint_empty_shaker_texture(texture):
    """Fills the salt in vanilla's shaker texture with the bare glass above it."""
    art = texture.convert("RGBA")
    left, top, right, bottom = SHAKER_GLASS_SAMPLE
    glass = art.crop(SHAKER_GLASS_SAMPLE).resize((1, 1), Image.BOX).getpixel((0, 0))
    painted = art.copy()
    painted.paste(glass, SHAKER_SALT_AREA)
    return painted


def write_textures(folder, game):
    folder.mkdir(parents=True, exist_ok=True)
    icons = pzart.extract_sprites(game / "media/texturepacks/UI2.pack", {"Item_MetalBucket", "Item_MetalBucket_Water"})
    empty, water = icons["Item_MetalBucket"], icons["Item_MetalBucket_Water"]
    models = game / "media/textures/WorldItems"
    texture = Image.open(models / "BucketFullWater_New.png").convert("RGBA")
    mask = Image.open(models / "BucketFullWater_NewFLUIDTINT.png").convert("RGBA")
    for name, (colour, solid) in BUCKET_CONTENTS.items():
        recolour(water, lambda x, y: empty.getpixel((x, y)) != water.getpixel((x, y)), colour, solid).save(folder / f"Item_{name}.png")
        recolour(texture, lambda x, y: mask.getpixel((x, y))[3] > 0, colour, solid).save(folder / f"{name}Model.png")

    paint_salt_icon().save(folder / "Item_LooseSalt.png")
    paint_salt_texture().save(folder / "EvaporatedSaltModel.png")
    retint_bag(pzart.extract_old_sprite(game / "media/texturepacks/UI.pack", "Item_Sugar")).save(folder / "Item_BagOfSalt.png")
    paint_salt_bag_texture(Image.open(models / "Sugar.png").convert("RGBA")).save(folder / "SaltBagModel.png")
    shaker = pzart.extract_sprites(game / "media/texturepacks/UI2.pack", {"Item_Salt"})["Item_Salt"]
    paint_empty_shaker_icon(shaker).save(folder / "Item_ShakerEmpty.png")
    paint_empty_shaker_texture(Image.open(models / "SaltPepper.png")).save(folder / "ShakerEmptyModel.png")


def lua_tiles():
    prefix = TILESET + "_"
    vats = [prefix + str(tiles[0]) for tiles in VAT_TILES.values()]
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "STATIONS": vats,
        "OUTDOOR": {name: True for name in vats},
        "PATCH": list(PATCH_TILES),
        "WORKED": list(WORKED_TILES),
    }


def main():
    default_game = Path.home() / ".local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else default_game
    media = Path(__file__).resolve().parent.parent / "42/media"
    pzart.write_lua_tiles(media, "TraditionalPreservationSalt", lua_tiles(), "tools/build_tileset.py")
    write_textures(media / "textures", game)
    east, south = VAT_TILES["E"], VAT_TILES["S"]
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", {
        east[0]: paint_vat(),
        east[1]: paint_vat(VAT_LEACHING),
        east[2]: paint_vat(VAT_FINISHED),
        south[0]: paint_vat(quarter_turn=True),
        south[1]: paint_vat(VAT_LEACHING, quarter_turn=True),
        south[2]: paint_vat(VAT_FINISHED, quarter_turn=True),
        **{index: paint_patch(mask) for mask, index in enumerate(PATCH_TILES)},
        **{index: paint_patch(mask, worked=True) for mask, index in enumerate(WORKED_TILES)},
    }, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    pzart.write_build_icon(paint_vat(quarter_turn=True), media / "textures" / "Item_LeachingVat.png")
    # The mod list shows a finished vat: spent soil and a full bucket of brine. The LTP Bridge's adds a Bag of Salt.
    finished = paint_vat(VAT_FINISHED, quarter_turn=True)
    pzart.write_mod_icon(finished, media.parent / "icon.png")
    pzart.write_mod_icon(finished, media.parent.parent.parent / "TraditionalPreservationSaltLTP" / "42" / "icon.png",
                   Image.open(media / "textures" / "Item_BagOfSalt.png").convert("RGBA"))


if __name__ == "__main__":
    main()
