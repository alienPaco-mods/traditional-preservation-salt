#!/usr/bin/env python3
"""Draws the Salt Lick Map's ring (42/media/textures/SaltLickMapRing.png): a soft red pencil circle, gone round twice
with a wobble like a hand-drawn mark, on a clear background. The ring's middle sits at RING_DRAWN of the picture's
half width; TraditionalPreservationSaltMap.lua stretches the picture so that is S.MAP_RING_RADIUS tiles.

Usage: python3 tools/draw_map_ring.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
RING_DRAWN = 0.9  # keep in step with TraditionalPreservationSaltMap.lua
COLOUR = (170, 40, 30)
OUT = Path(__file__).resolve().parent.parent / "42/media/textures/SaltLickMapRing.png"


def stroke(draw, rng, radius, width, alpha, turns):
    centre = SIZE / 2
    start = rng.uniform(0, 2 * math.pi)
    phase = [rng.uniform(0, 2 * math.pi) for _ in range(3)]
    steps = int(720 * turns)
    points = []
    for i in range(steps + 1):
        t = start + 2 * math.pi * turns * i / steps
        wobble = (0.012 * math.sin(3 * t + phase[0]) + 0.008 * math.sin(5 * t + phase[1])
                  + 0.004 * math.sin(11 * t + phase[2]))
        r = radius * (1 + wobble)
        points.append((centre + r * math.cos(t), centre + r * math.sin(t)))
    draw.line(points, fill=COLOUR + (alpha,), width=width, joint="curve")


def main():
    rng = random.Random(5171)
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = SIZE / 2 * RING_DRAWN
    stroke(draw, rng, radius, 7, 200, 1.08)
    stroke(draw, rng, radius * 0.99, 4, 140, 0.95)
    image = image.filter(ImageFilter.GaussianBlur(0.8))
    image.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
