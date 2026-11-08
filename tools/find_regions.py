#!/usr/bin/env python3
"""Finds salt-lick regions for towns out of reach of the existing ones, and prints them as Lua.

A candidate sits close to natural water, far from buildings and away from roads, and on
ground the forest map marks as woodland. Regions are spread apart so each one is a separate
find, and every town gets one within TOWN_FAR but no region sits closer to a town than
TOWN_NEAR. Add the output to the end of REGIONS in 42/media/lua/shared/TraditionalPreservationSalt.lua:
saves track sites by position in that list, so existing regions must keep their order.

Usage: python3 tools/find_regions.py [path/to/ProjectZomboid/projectzomboid]
Needs Pillow and numpy.
"""
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CELL = 300
PIXEL = 10  # tiles per raster pixel
WORLD_W, WORLD_H = 21000, 18000

WATER_NEAR = 80  # tiles: a candidate must be this close to water
WATER_CLEAR = 15  # tiles: and at least this far from it
BUILDING_CLEAR = 250
ROAD_CLEAR = 60
REGION_HALF = 40  # half the side of each region
REGION_SPACING = 1400
TOWN_NEAR, TOWN_FAR = 1000, 1500  # tiles: a bit of a search, but a realistic one


def town_labels(path):
    """Returns {town name: (x, y)} from the labels on the in-game map."""
    pattern = r'addUntranslatedText\("MapLabel_(\w+)", "text-town", (\d+), (\d+)\)'
    return {name: (int(x), int(y)) for name, x, y in re.findall(pattern, path.read_text(errors="replace"))}


def existing_centres():
    """Returns the middle of each region already in the mod."""
    lua = Path(__file__).resolve().parent.parent / "42/media/lua/shared/TraditionalPreservationSalt.lua"
    pattern = r"x1 = (\d+), y1 = (\d+), x2 = (\d+), y2 = (\d+)"
    return [((int(a) + int(c)) / 2, (int(b) + int(d)) / 2) for a, b, c, d in re.findall(pattern, lua.read_text())]


def features(path):
    """Yields (properties, geometry type, world-space points) for each map feature."""
    for _, cell in ET.iterparse(path, events=("end",)):
        if cell.tag != "cell":
            continue
        ox, oy = int(cell.get("x")) * CELL, int(cell.get("y")) * CELL
        for feature in cell.findall("feature"):
            props = {p.get("name"): p.get("value") for p in feature.iter("property")}
            geometry = feature.find("geometry")
            for coords in geometry.findall("coordinates"):
                points = [(ox + int(p.get("x")), oy + int(p.get("y"))) for p in coords.findall("point")]
                yield props, geometry.get("type"), points
        cell.clear()


def blank():
    return Image.new("1", (WORLD_W // PIXEL, WORLD_H // PIXEL))


def draw(canvas, kind, points):
    scaled = [(x / PIXEL, y / PIXEL) for x, y in points]
    if len(scaled) < 2:
        return
    if kind == "Polygon" and len(scaled) > 2:
        canvas.polygon(scaled, fill=1)
    else:
        canvas.line(scaled, fill=1, width=1)


def grow(mask, tiles):
    """Dilates a boolean mask by a radius in tiles, using a box for speed."""
    steps = max(1, tiles // PIXEL)
    padded = np.pad(mask.astype(np.int32), ((steps + 1, steps), (steps + 1, steps)))
    summed = padded.cumsum(0).cumsum(1)
    size = 2 * steps + 1
    window = summed[size:, size:] - summed[:-size, size:] - summed[size:, :-size] + summed[:-size, :-size]
    return window > 0


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else
                "~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid").expanduser()
    folder = root / "media/maps/Muldraugh, KY"

    water, built, roads, forest = blank(), blank(), blank(), blank()
    pens = {name: ImageDraw.Draw(image) for name, image in
            (("water", water), ("built", built), ("roads", roads), ("forest", forest))}
    kinds = {}
    for props, kind, points in features(folder / "worldmap.xml"):
        if "water" in props:
            kinds[props["water"]] = kinds.get(props["water"], 0) + 1
            draw(pens["water"], kind, points)
        elif "building" in props:
            draw(pens["built"], kind, points)
        elif "highway" in props and props["highway"] != "trail":
            draw(pens["roads"], kind, points)
    print("-- water feature kinds:", kinds, file=sys.stderr)
    for props, kind, points in features(folder / "worldmap-forest.xml"):
        draw(pens["forest"], kind, points)

    water_mask, built_mask = np.array(water), np.array(built)
    roads_mask, forest_mask = np.array(roads), np.array(forest)
    print(f"-- forest coverage {forest_mask.mean():.3f}", file=sys.stderr)

    # The map only records rivers, so some towns have no woodland by water: they fall back to dry woodland.
    dry = ~grow(water_mask, WATER_CLEAR) & ~grow(built_mask, BUILDING_CLEAR) & ~grow(roads_mask, ROAD_CLEAR) & forest_mask
    good = dry & grow(water_mask, WATER_NEAR)
    print(f"-- candidate pixels {int(good.sum())}", file=sys.stderr)

    def solid(mask):
        """Prefers the middle of a solid patch, so the region is not a sliver of qualifying ground."""
        steps = REGION_HALF // PIXEL
        padded = np.pad(mask.astype(np.int32), ((steps + 1, steps), (steps + 1, steps)))
        summed = padded.cumsum(0).cumsum(1)
        size = 2 * steps + 1
        window = summed[size:, size:] - summed[:-size, size:] - summed[size:, :-size] + summed[:-size, :-size]
        return np.where(mask, window, 0)

    score, dry_score = solid(good), solid(dry)

    towns = town_labels(folder / "worldmap-annotations.lua")
    centres = existing_centres()
    rows, columns = np.indices(score.shape)
    world_x, world_y = columns * PIXEL, rows * PIXEL

    def distance(point):
        return np.hypot(world_x - point[0], world_y - point[1])

    def block(point):
        score[distance(point) < REGION_SPACING] = 0
        dry_score[distance(point) < REGION_SPACING] = 0

    def uncovered():
        return {name: spot for name, spot in towns.items()
                if min(math.dist(spot, centre) for centre in centres) > TOWN_FAR}

    for centre in centres:
        block(centre)
    for spot in towns.values():
        score[distance(spot) < TOWN_NEAR] = 0
        dry_score[distance(spot) < TOWN_NEAR] = 0

    # Each pick serves as many towns still out of reach as it can, so the list stays short.
    while uncovered():
        waiting = uncovered()
        reach = sum((distance(spot) <= TOWN_FAR).astype(np.int32) for spot in waiting.values())
        served = np.where(score > 0, reach, 0)
        ground, note = score, ""
        if served.max() == 0:
            served = np.where(dry_score > 0, reach, 0)
            ground, note = dry_score, "away from water: "
        if served.max() == 0:
            print(f"-- no ground left for: {sorted(waiting)}", file=sys.stderr)
            break
        best = np.where(served == served.max(), ground, 0)
        py, px = np.unravel_index(best.argmax(), best.shape)
        x, y = int(px) * PIXEL, int(py) * PIXEL
        names = [f"{name} {math.dist(spot, (x, y)):.0f}" for name, spot in waiting.items() if math.dist(spot, (x, y)) <= TOWN_FAR]
        centres.append((x, y))
        block((x, y))
        print(f"    {{ x1 = {x - REGION_HALF}, y1 = {y - REGION_HALF}, "
              f"x2 = {x + REGION_HALF}, y2 = {y + REGION_HALF} }},  -- {note}{', '.join(names)}")

    for name, spot in sorted(towns.items()):
        print(f"-- {name}: nearest region {min(math.dist(spot, centre) for centre in centres):.0f}", file=sys.stderr)


if __name__ == "__main__":
    main()
