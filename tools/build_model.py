"""Builds the Salt Pan's ground model (42/media/Models_X/SaltPan.glb) and its texture (mock approved 2026-11-22,
WIP/TPCore/art/saltpan_model_mock.py).

A shallow pan of forged sheet iron, as the hearth tiles draw it (tools/salt_pan_tiles.py): about 70 cm across, a hand
deep (30 L), the side flaring a little to a rolled rim, sooted black underneath and up the lower side, bare greased iron
above, the inside dark iron; no handles. Units are metres, Y up, base on the ground; its in-game size is the `scale` of
the SaltPanGround model in 42/media/scripts/TraditionalPreservationSalt_SaltPan.txt, the Forged Cauldron's, so the two
sit together at their true sizes. The mesh, texture greys, glb writer and preview are TP Core's
(TraditionalPreservationCore/tools/build_model.py).

Usage: python3 tools/build_model.py [preview.png]
Needs Pillow and numpy. Rerun after editing the tables below.
"""
import math
import os
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import build_model as M  # noqa: E402  TP Core's
import pzart  # noqa: E402

PAN_R = 0.35        # the rim's radius, m (the tiles' 0.35 of a tile, the README's 70 cm across)
PAN_FOOT_R = 0.31   # the bottom's: the side flares
PAN_H = 0.13        # bottom to rim, m: a little more than a hand, as the camera squashes height
WALL = 0.005
LIP_TUBE = 0.014    # the rolled rim: thinner than the cauldron's
RINGS = 8
SOOT_LINE = 0.55    # how far up the side the soot reaches, as the tiles (0.55 with a wavy edge)


def side_radius(t):
    """The side from bottom (t 0) to rim (t 1): a short round into the flare."""
    return PAN_FOOT_R + (PAN_R - PAN_FOOT_R) * t + 0.012 * math.sin(math.pi * min(1.0, t * 2)) * (1 - t)


def build_mesh():
    mesh = M.Mesh()
    outer = [(PAN_H * k / RINGS, side_radius(k / RINGS), k / RINGS) for k in range(RINGS + 1)]
    M.lathe(mesh, outer, M.OUT_U)
    inner = [(0.008 + (PAN_H - 0.008) * k / RINGS, side_radius(k / RINGS) - WALL, k / RINGS) for k in range(RINGS + 1)]
    M.lathe(mesh, inner, M.IN_U, inward=True)
    M.disc(mesh, 0.001, PAN_FOOT_R, False, (M.OUT_U[0] + 0.01, 0.99))
    M.disc(mesh, inner[0][0], inner[0][1], True, ((M.IN_U[0] + M.IN_U[1]) / 2, 0.9))
    ring = [(PAN_R * math.cos(a), PAN_H, PAN_R * math.sin(a)) for a in np.linspace(0, 2 * math.pi, M.SIDES + 1)]
    for i, (p0, p1) in enumerate(zip(ring, ring[1:])):
        M.tube(mesh, [p0, p1], LIP_TUBE, (M.LIP_U[0] + (M.LIP_U[1] - M.LIP_U[0]) * (i + 0.5) / M.SIDES, 0.5))
    return mesh


def paint_texture():
    """The cauldron's greys: the outside sooted black to SOOT_LINE with a wavy edge, bare iron above; the lip light
    iron with soot blotches; the inside dark iron."""
    size = M.TEXTURE_SIZE
    rng = random.Random("saltpan")
    cloud = Image.blend(pzart.soft_noise(rng, (size, size), 10, 10), pzart.soft_noise(rng, (size, size), 4, 4), 0.4).load()
    image = Image.new("RGBA", (size, size))
    pixels = image.load()

    def grey(value, x, y):
        v = int(value * (0.8 + 0.4 * cloud[x, y] / 255))
        return (v, v, v, 255)

    x0, x1 = int(M.OUT_U[0] * size), int(M.OUT_U[1] * size)
    lx0, lx1 = int(M.LIP_U[0] * size), int(M.LIP_U[1] * size)
    for x in range(size):
        a = 2 * math.pi * (x - x0) / max(1, x1 - x0)
        la = 2 * math.pi * (x - lx0) / max(1, lx1 - lx0)
        for y in range(size):
            if x < x1:
                t = 1 - y / (size - 1)
                line = SOOT_LINE + 0.1 * math.sin(a * 7) + 0.04 * math.sin(a * 17 + 1.3)
                sooted = max(0.0, min(1.0, (line - t) / 0.12 + 0.5))
                pixels[x, y] = grey(M.LIGHT_IRON * (1 - sooted) + M.SOOT * sooted, x, y)
            elif lx0 <= x < lx1:
                sooted = max(0.0, min(1.0, 0.2 + 0.4 * math.sin(la * 3 + 0.7) * math.sin(la * 7 + 0.2)))
                pixels[x, y] = grey(M.LIGHT_IRON * 1.05 * (1 - sooted) + M.SOOT * sooted, x, y)
            else:
                pixels[x, y] = grey(M.DARK_IRON, x, y)
    return image.resize((M.SAVED_TEXTURE_SIZE, M.SAVED_TEXTURE_SIZE), Image.BOX)


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    (media / "Models_X").mkdir(parents=True, exist_ok=True)
    mesh = build_mesh()
    texture = paint_texture()
    M.write_glb(media / "Models_X" / "SaltPan.glb", mesh)
    texture.save(media / "textures" / "SaltPanModel.png")
    if len(sys.argv) > 1:
        M.preview(mesh, texture, sys.argv[1])
    print(f"wrote the salt pan's model ({len(mesh.indices) // 3} triangles, {len(mesh.positions)} vertices) and texture to {media}")


if __name__ == "__main__":
    main()
