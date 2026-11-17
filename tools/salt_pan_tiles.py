"""The salt pan's art, for build_tileset.py: the Stone Hearth with Salt's salt pan fitted (ROADMAP section 6; mock
approved 2026-11-17, WIP/TPCore/art/salt_pan_mock.py). TP Core's Stone Hearth body, door, slab and glow are drawn by
Core's own tools/build_tileset.py, imported here, so the stone matches the cauldron's.

A shallow pan of forged sheet iron, about 70 cm across and a hand deep (30 L), set on the slab over the hole and bedded
in a bead of fired clay (the Fit's 2 Clay), sooted on its outside. Whole-hearth tiles, each a fireplace, by what shows
in the pan and the fire (out, lit, banked: the glow baked in at the door's vents, as the cauldron's). What the pan holds
is the overlay, a pale surface the game tints with the brine's colour, still or boiling; the dry crust is drawn in the
tile. Everything inside is cut to the rim's opening, so the bottom never covers the pan's front wall.
"""
import math
import random
from pathlib import Path
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import build_tileset as B  # noqa: E402  TP Core's
import pzart  # noqa: E402
from pzart import shrink, tint as shade  # noqa: E402

SS = B.SS
Z = B.TOP + B.CAP          # the slab's top, px
PAN_R = 0.35               # the rim's radius, in tiles (the slab reaches 0.50)
PAN_FOOT_R = 0.33          # its bottom's: the side flares a little
PAN_H = 9                  # px from bottom to rim
INNER = PAN_R - 0.015      # the rim's inner edge
CLAY = (118, 70, 50)       # the clay bead, fired dark by the hearth, as vanilla's fired clay
IRON = B.METAL
RUST = (92, 60, 42)
SALT = (236, 236, 230)
TIDE = (150, 120, 90)
SURFACE = (222, 222, 222)  # the overlay, greys the game tints
SURFACE_LIGHT = (244, 244, 244)
SURFACE_SHADE = (176, 176, 176)
LEVEL = Z + PAN_H - 1.6    # where the brine stands, px

# Whole-hearth looks: what shows in the pan (Empty: nothing, or brine under the overlay; Steam: brine steaming; Crust)
# and the fire. The Lua reads the tile numbers from Tiles.lua.
CONTENTS = ("Empty", "Steam", "Crust")
FIRES = ("", "Lit", "Banked")
SURFACES = ("Still", "Boiling")


def ring(draw, r, z, fill):
    cx, cy = pzart.project(0, 0, z)
    rx, ry = B.ellipse_r(r)
    draw.ellipse(B.box(cx, cy, rx, ry), fill=fill)


def opening_mask(size):
    """The rim's inner edge from above: all that shows of the inside."""
    mask = Image.new("L", size, 0)
    cx, cy = pzart.project(0, 0, Z + PAN_H)
    rx, ry = B.ellipse_r(INNER)
    ImageDraw.Draw(mask).ellipse(B.box(cx, cy, rx, ry), fill=255)
    return mask


def inside(look, rng):
    """The far inside wall, lit, down to the bottom: bare iron flecked with rust, or the dry crust of salt cracked into
    plates with a brown tide line high on the wall."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    tcx, tcy = pzart.project(0, 0, Z + PAN_H)
    irx, iry = B.ellipse_r(INNER)
    draw.chord(B.box(tcx, tcy, irx, iry), 180, 360, fill=shade(IRON, 0.55))
    bcx, bcy = pzart.project(0, 0, Z + 1.5)
    brx, bry = B.ellipse_r(PAN_FOOT_R - 0.015)
    draw.ellipse(B.box(bcx, bcy, brx, bry), fill=shade(IRON, 0.4))
    if look != "Crust":
        for _ in range(24):
            a, r = rng.uniform(0, 2 * math.pi), math.sqrt(rng.uniform(0.02, 0.8))
            draw.ellipse(B.box(bcx + brx * r * math.cos(a), bcy + bry * r * math.sin(a), rng.uniform(0.6, 1.5), rng.uniform(0.4, 0.8)),
                         fill=shade(RUST, rng.uniform(0.6, 0.9)))
        return layer
    draw.arc(B.box(tcx, tcy + 1.2, irx - 0.5, iry - 0.3), 180, 360, fill=shade(TIDE, 0.9), width=SS)
    draw.ellipse(B.box(bcx, bcy - 0.4, brx, bry), fill=shade(SALT, 0.88))
    draw.ellipse(B.box(bcx - 3, bcy - 1.0, brx - 6, bry - 3), fill=shade(SALT, 0.97))
    for _ in range(140):
        a, r = rng.uniform(0, 2 * math.pi), math.sqrt(rng.uniform(0, 0.95))
        draw.ellipse(B.box(bcx + brx * r * math.cos(a), bcy - 0.4 + bry * r * math.sin(a), 0.5, 0.35),
                     fill=shade(SALT, rng.choice([0.8, 1.05, 1.1])))
    for _ in range(9):
        a0, r0 = rng.uniform(0, 2 * math.pi), rng.uniform(0.1, 0.5)
        x, y = bcx + brx * r0 * math.cos(a0), bcy - 0.4 + bry * r0 * math.sin(a0)
        points = [(x * SS, y * SS)]
        for _ in range(3):
            x, y = x + rng.uniform(-5, 5), y + rng.uniform(-2, 2)
            points.append((x * SS, y * SS))
        draw.line(points, fill=shade(SALT, 0.62), width=SS)
    return layer


def paint_pan(look, rng):
    """The pan from its clay bead up: its sooted side as stacked rings lit from the left, the rolled rim, the inside."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    cx, cy = pzart.project(0, 0, Z)
    rx, ry = B.ellipse_r(PAN_FOOT_R + 0.02)
    for i in range(48):
        a = 2 * math.pi * i / 48
        lit = 0.8 + 0.3 * max(0.0, math.cos(a - 2.3))
        draw.ellipse(B.box(cx + rx * math.cos(a), cy + 0.6 + ry * math.sin(a), rng.uniform(2.0, 2.8), rng.uniform(1.1, 1.5)),
                     fill=shade(CLAY, lit * rng.uniform(0.9, 1.05)))
    steps = PAN_H * 4
    for k in range(steps + 1):
        t = k / steps
        r = PAN_FOOT_R + (PAN_R - PAN_FOOT_R) * t
        pcx, pcy = pzart.project(0, 0, Z + 0.5 + PAN_H * t)
        rx, ry = B.ellipse_r(r)
        for i in range(90):
            a = math.pi * (0.02 + 0.96 * i / 89)   # the front half only shows
            lit = 0.55 + 0.6 * max(0.0, math.cos(a - 2.3)) ** 2
            colour = B.KETTLE_SOOT if t < 0.55 + 0.1 * math.sin(a * 7) else IRON
            draw.ellipse(B.box(pcx + rx * math.cos(a), pcy + ry * math.sin(a), 0.9, 0.9), fill=shade(colour, lit))
    top = Z + PAN_H
    ring(draw, PAN_R + 0.008, top, shade(IRON, 0.5))
    tcx, tcy = pzart.project(0, 0, top)
    rx, ry = B.ellipse_r(PAN_R)
    for i in range(140):
        a = 2 * math.pi * i / 140
        lit = 0.7 + 0.8 * max(0.0, math.cos(a - 2.3)) ** 2
        draw.ellipse(B.box(tcx + rx * math.cos(a), tcy + ry * math.sin(a), 1.1, 0.8), fill=shade(IRON, lit))
    for i in range(30):
        a = 2.0 + 0.9 * i / 29
        draw.ellipse(B.box(tcx + rx * math.cos(a), tcy + ry * math.sin(a) - 0.3, 0.6, 0.3), fill=B.SPECULAR + (255,))
    ring(draw, INNER, top, shade(IRON, 0.32))
    seen = inside(look, rng)
    seen.putalpha(ImageChops.multiply(seen.getchannel("A"), opening_mask(seen.size)))
    layer.alpha_composite(seen)
    return layer


def steam():
    """Wisps off the whole surface, low and wide: a shallow pan at the boil."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    cx, cy = pzart.project(0, 0, Z + PAN_H)
    for dx, height, phase in ((-16, 26, 0.0), (-5, 36, 1.7), (6, 30, 3.1), (17, 22, 4.4)):
        for i in range(26):
            t = i / 25
            x = cx + dx + 4 * math.sin(phase + t * 5) * t
            draw.ellipse(B.box(x, cy - height * t, 2.4 + 3.5 * t, 1.8 + 2.4 * t), fill=B.STEAM + (int(110 * (1 - t) ** 1.2),))
    return layer.filter(ImageFilter.GaussianBlur(1.2 * SS))


def paint_tile(contents, fire, face):
    """A whole-hearth tile: the stone with its hole, the pan, its fire's glow at the door, steam over it."""
    layer = B.body(face, True)
    layer.alpha_composite(paint_pan("Crust" if contents == "Crust" else "Empty", random.Random(400 + face)))
    tile = pzart.hard_edges(pzart.weather(shrink(layer), random.Random(190 + face), B.WEATHER).convert("RGBA"))
    if fire:
        tile.alpha_composite(B.paint_bare_glow(fire + "Flue", face))
    if contents == "Steam":
        tile.alpha_composite(shrink(steam()))
    return tile


def paint_surface(kind, face):
    """The overlay: the brine standing in the pan, a pale surface with a lighter middle and a shadowed far edge, the game
    tints it; boiling, rings of bubbles over it. Cut to the opening."""
    rng = random.Random(420 + face)
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    scx, scy = pzart.project(0, 0, LEVEL)
    srx, sry = B.ellipse_r(INNER - 0.005)
    draw.ellipse(B.box(scx, scy, srx, sry), fill=SURFACE + (255,))
    draw.ellipse(B.box(scx - 3, scy - 0.8, srx - 8, sry - 4), fill=SURFACE_LIGHT + (255,))
    draw.arc(B.box(scx, scy, srx, sry), 190, 350, fill=SURFACE_SHADE + (255,), width=SS)
    if kind == "Boiling":
        for _ in range(22):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.0, 0.85)
            x, y = scx + srx * r * math.cos(a), scy + sry * r * math.sin(a)
            s = rng.uniform(0.7, 1.4)
            draw.ellipse(B.box(x, y, s * 1.2, s * 0.6), outline=(255, 255, 255, 255), width=SS)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), opening_mask(layer.size)))
    return pzart.hard_edges(shrink(layer).convert("RGBA"))


def paint_icon(contents, size=32):
    """The pan on its own, for the item and the menu's status row: a dark iron dish, empty, with brine or with a crust."""
    scale = 4
    image = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    c, w = size * scale / 2, size * scale * 0.46
    top, depth, squash = size * scale * 0.42, size * scale * 0.16, 0.42
    draw.ellipse([c - w, top + depth - w * squash, c + w, top + depth + w * squash], fill=B.KETTLE_SOOT + (255,))
    draw.rectangle([c - w, top, c + w, top + depth], fill=B.KETTLE_SOOT + (255,))
    draw.ellipse([c - w, top - w * squash, c + w, top + w * squash], fill=shade(IRON, 1.25))
    iw = w * 0.9
    fill = {"Empty": shade(IRON, 0.45), "Brine": (214, 206, 150, 255), "Crust": SALT + (255,)}[contents]
    draw.ellipse([c - iw, top - iw * squash, c + iw, top + iw * squash], fill=fill)
    if contents == "Crust":
        draw.line([(c - iw * 0.4, top), (c + iw * 0.1, top + iw * 0.1), (c + iw * 0.5, top - iw * 0.08)], fill=shade(SALT, 0.6), width=scale)
    outline = Image.new("RGBA", image.size, (0, 0, 0, 0))
    alpha = image.getchannel("A").filter(ImageFilter.MaxFilter(2 * scale + 1))
    outline.putalpha(alpha)
    outline = Image.composite(Image.new("RGBA", image.size, (24, 20, 22, 255)), outline, alpha)
    outline.alpha_composite(image)
    return outline.resize((size, size), Image.LANCZOS)
