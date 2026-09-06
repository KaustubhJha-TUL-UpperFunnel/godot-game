"""Throwaway probe: locate knight bodies in a cut-out sheet.

Swords are thin and bridge neighbouring frames, so counting opaque pixels per
column and keeping only the tall columns separates the bodies cleanly.
"""

import sys

import numpy as np
from PIL import Image

BODY_COLUMN_MIN = 70


def runs(flags: np.ndarray, min_width: int = 8) -> list[tuple[int, int]]:
    found = []
    start = None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            if index - start >= min_width:
                found.append((start, index - 1))
            start = None
    if start is not None and flags.size - start >= min_width:
        found.append((start, flags.size - 1))
    return found


for path in sys.argv[1:]:
    alpha = np.asarray(Image.open(path).convert("RGBA"))[:, :, 3] > 0
    print(f"\n=== {path}")

    ys = np.nonzero(alpha.any(axis=1))[0]
    print(f"  content rows: {ys.min()}..{ys.max()}")

    per_column = alpha.sum(axis=0)
    print(f"  max column height: {per_column.max()}")

    bodies = runs(per_column >= BODY_COLUMN_MIN)
    print(f"  body runs (>= {BODY_COLUMN_MIN}px tall columns): {len(bodies)}")
    for left, right in bodies:
        band = alpha[:, left : right + 1]
        rows = np.nonzero(band.any(axis=1))[0]
        print(
            f"    x {left:4d}..{right:4d}  w={right - left + 1:3d}  "
            f"y {rows.min()}..{rows.max()}  centre_x={(left + right) // 2}"
        )

    everything = runs(per_column > 0, min_width=1)
    print(f"  opaque runs: {everything}")
