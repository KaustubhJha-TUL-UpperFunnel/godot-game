"""Throwaway probe: column map of an un-baked sheet, to pick frame windows.

Prints, per 8px column bucket: how tall the solid content is, and whether gold
(slash arc) or steel-blue (knight) pixels are present. That is enough to see
where one pose ends and the next begins.
"""

import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "tools")
from build_knight_animation import SOURCE_DIRECTORY, unbake_checkerboard  # noqa: E402

BUCKET = 8

for file_name in sys.argv[1:]:
    path = f"{SOURCE_DIRECTORY}/{file_name}"
    print(f"\n=== {path}")
    rgba = unbake_checkerboard(path)
    alpha = rgba[:, :, 3]
    red, green, blue = rgba[:, :, 0], rgba[:, :, 1], rgba[:, :, 2]

    solid = alpha > 140
    any_pixel = alpha > 0
    gold = solid & (red > 140) & ((red - blue) > 55)
    steel = solid & ((blue - red) > 12) & (blue > 60)

    print("  bucket  solid_tall  any_tall  gold  steel")
    for start in range(0, rgba.shape[1], BUCKET):
        stop = start + BUCKET
        tall = int(solid[:, start:stop].sum(axis=0).max())
        loose = int(any_pixel[:, start:stop].sum(axis=0).max())
        if loose == 0:
            continue
        marks = ""
        if gold[:, start:stop].sum() > 20:
            marks += " GOLD"
        if steel[:, start:stop].sum() > 40:
            marks += " steel"
        print(f"  {start:4d}    {tall:4d}      {loose:4d}   {marks}")
