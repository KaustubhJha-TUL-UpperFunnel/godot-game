"""Throwaway probe: works out how the raw knight animation sheets are laid out.

The sheets arrived as opaque PNGs with the transparency checkerboard baked into
the pixels, so this reconstructs the checker grid, cuts it out, and reports the
sprite clusters it finds.
"""

import sys

import numpy as np
from PIL import Image


def detect_cell_size(gray: np.ndarray) -> int:
    """Checker period, found from the run lengths along the top row."""
    row = gray[0].astype(int)
    runs = []
    start = 0
    for x in range(1, row.size):
        if abs(row[x] - row[start]) > 25:
            runs.append(x - start)
            start = x
    runs.append(row.size - start)
    interior = [run for run in runs[1:-1] if run > 2]
    return int(np.median(interior)) if interior else 32


def background_model(gray: np.ndarray, cell: int) -> np.ndarray:
    """Rebuild the checkerboard from its two base tones."""
    height, width = gray.shape
    ys, xs = np.mgrid[0:height, 0:width]
    parity = ((xs // cell) + (ys // cell)) % 2 == 0

    tone_a = float(np.median(gray[parity]))
    tone_b = float(np.median(gray[~parity]))
    print(f"  checker cell={cell}px tones={tone_a:.0f}/{tone_b:.0f}")
    return np.where(parity, tone_a, tone_b)


def sprite_mask(rgb: np.ndarray, tolerance: int = 26) -> np.ndarray:
    gray = rgb.mean(axis=2)
    cell = detect_cell_size(gray)
    model = background_model(gray, cell)

    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    looks_like_background = (np.abs(gray - model) <= tolerance) & (chroma <= 18)
    return ~flood_from_border(looks_like_background)


def flood_from_border(mask: np.ndarray) -> np.ndarray:
    """Keeps only the parts of `mask` reachable from the image border.

    Achromatic greys inside the knight's armour match the checker tones by
    coincidence; requiring a path to the edge leaves those alone.
    """
    height, width = mask.shape
    reached = np.zeros_like(mask)
    stack: list[int] = []

    for y in range(height):
        for x in (0, width - 1):
            if mask[y, x] and not reached[y, x]:
                reached[y, x] = True
                stack.append(y * width + x)
    for x in range(width):
        for y in (0, height - 1):
            if mask[y, x] and not reached[y, x]:
                reached[y, x] = True
                stack.append(y * width + x)

    flat_mask = mask.ravel()
    flat_reached = reached.ravel()
    while stack:
        index = stack.pop()
        y, x = divmod(index, width)
        for neighbour, valid in (
            (index - width, y > 0),
            (index + width, y < height - 1),
            (index - 1, x > 0),
            (index + 1, x < width - 1),
        ):
            if valid and flat_mask[neighbour] and not flat_reached[neighbour]:
                flat_reached[neighbour] = True
                stack.append(neighbour)
    return reached


def components(mask: np.ndarray, min_pixels: int = 400) -> list[tuple]:
    height, width = mask.shape
    seen = np.zeros_like(mask)
    flat_mask = mask.ravel()
    flat_seen = seen.ravel()
    found = []

    for seed in range(flat_mask.size):
        if not flat_mask[seed] or flat_seen[seed]:
            continue
        flat_seen[seed] = True
        stack = [seed]
        pixels = []
        while stack:
            index = stack.pop()
            pixels.append(index)
            y, x = divmod(index, width)
            for neighbour, valid in (
                (index - width, y > 0),
                (index + width, y < height - 1),
                (index - 1, x > 0),
                (index + 1, x < width - 1),
            ):
                if valid and flat_mask[neighbour] and not flat_seen[neighbour]:
                    flat_seen[neighbour] = True
                    stack.append(neighbour)
        if len(pixels) < min_pixels:
            continue
        coords = np.array([divmod(index, width) for index in pixels])
        found.append(
            (
                int(coords[:, 1].min()),
                int(coords[:, 0].min()),
                int(coords[:, 1].max()),
                int(coords[:, 0].max()),
                len(pixels),
            )
        )
    return sorted(found, key=lambda box: box[0])


def column_runs(mask: np.ndarray) -> list[tuple[int, int]]:
    occupied = mask.any(axis=0)
    runs = []
    start = None
    for x, filled in enumerate(occupied):
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            runs.append((start, x - 1))
            start = None
    if start is not None:
        runs.append((start, mask.shape[1] - 1))
    return runs


for path in sys.argv[1:]:
    print(f"\n=== {path}")
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    mask = sprite_mask(rgb)
    print(f"  sprite pixels: {int(mask.sum())}")

    ys, xs = np.nonzero(mask)
    print(f"  content bbox: x {xs.min()}..{xs.max()}  y {ys.min()}..{ys.max()}")
    print(f"  column runs: {column_runs(mask)}")
    print("  components (x0,y0,x1,y1,pixels):")
    for box in components(mask):
        print(f"    {box}  w={box[2] - box[0] + 1} h={box[3] - box[1] + 1}")

    cutout = np.dstack([rgb.astype(np.uint8), (mask * 255).astype(np.uint8)])
    debug = path.replace(".png", "_debug.png")
    Image.fromarray(cutout, "RGBA").save(debug)
    print(f"  wrote {debug}")
