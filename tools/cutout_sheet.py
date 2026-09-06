"""Throwaway probe: cut the baked-in checkerboard out of the knight sheets.

The sheets are opaque PNGs whose transparent background was flattened onto a
50x50 checkerboard, then saved lossily. That leaves two problems: the checker
tones themselves, and a one-pixel ringing lattice along every cell edge where
the compressor overshot. Both are removed here.
"""

import sys

import numpy as np
from PIL import Image

CELLS = 50
CHROMA_LIMIT = 22
TONE_TOLERANCE = 24
BOUNDARY_BAND = 2


def checker_parity(height: int, width: int) -> np.ndarray:
    cell = width / CELLS
    ys, xs = np.mgrid[0:height, 0:width]
    return (((xs / cell).astype(int) + (ys / cell).astype(int)) % 2) == 0


def boundary_band(height: int, width: int) -> np.ndarray:
    """Pixels within a couple of px of a checker cell edge, where ringing lives."""
    cell = width / CELLS
    xs = np.arange(width)
    ys = np.arange(height)
    near_x = np.min(
        np.abs(xs[:, None] - np.round(np.arange(CELLS + 1) * cell)[None, :]), axis=1
    )
    near_y = np.min(
        np.abs(ys[:, None] - np.round(np.arange(CELLS + 1) * cell)[None, :]), axis=1
    )
    return (near_x[None, :] <= BOUNDARY_BAND) | (near_y[:, None] <= BOUNDARY_BAND)


def background_candidates(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    gray = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    parity = checker_parity(height, width)

    # Border rows and columns are guaranteed background, so take the tones there.
    border = np.zeros((height, width), dtype=bool)
    border[:6, :] = border[-6:, :] = True
    border[:, :6] = border[:, -6:] = True
    tone_a = float(np.median(gray[border & parity]))
    tone_b = float(np.median(gray[border & ~parity]))
    print(f"  checker tones: {tone_a:.0f} / {tone_b:.0f}")

    model = np.where(parity, tone_a, tone_b)
    flat = (np.abs(gray - model) <= TONE_TOLERANCE) & (chroma <= CHROMA_LIMIT)

    low, high = min(tone_a, tone_b) - 20, max(tone_a, tone_b) + 20
    ringing = (
        boundary_band(height, width)
        & (chroma <= CHROMA_LIMIT)
        & (gray >= low)
        & (gray <= high)
    )
    return flat | ringing


def flood_from_border(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    flat_mask = mask.ravel()
    reached = np.zeros(flat_mask.size, dtype=bool)
    stack: list[int] = []

    def seed(index: int) -> None:
        if flat_mask[index] and not reached[index]:
            reached[index] = True
            stack.append(index)

    for y in range(height):
        seed(y * width)
        seed(y * width + width - 1)
    for x in range(width):
        seed(x)
        seed((height - 1) * width + x)

    while stack:
        index = stack.pop()
        y, x = divmod(index, width)
        if y > 0:
            seed(index - width)
        if y < height - 1:
            seed(index + width)
        if x > 0:
            seed(index - 1)
        if x < width - 1:
            seed(index + 1)
    return reached.reshape(height, width)


def label_components(mask: np.ndarray) -> tuple[np.ndarray, int]:
    height, width = mask.shape
    flat_mask = mask.ravel()
    labels = np.zeros(flat_mask.size, dtype=np.int32)
    current = 0

    for start in range(flat_mask.size):
        if not flat_mask[start] or labels[start]:
            continue
        current += 1
        labels[start] = current
        stack = [start]
        while stack:
            index = stack.pop()
            y, x = divmod(index, width)
            for neighbour, valid in (
                (index - width, y > 0),
                (index + width, y < height - 1),
                (index - 1, x > 0),
                (index + 1, x < width - 1),
            ):
                if valid and flat_mask[neighbour] and not labels[neighbour]:
                    labels[neighbour] = current
                    stack.append(neighbour)
    return labels.reshape(height, width), current


def cutout(path: str) -> Image.Image:
    print(f"\n=== {path}")
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    sprite = ~flood_from_border(background_candidates(rgb))

    labels, count = label_components(sprite)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    keep = np.nonzero(sizes >= 300)[0]
    print(f"  components: {count} total, {keep.size} above 300px")

    boxes = []
    for label in keep:
        ys, xs = np.nonzero(labels == label)
        boxes.append((int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()), int(sizes[label])))
    for box in sorted(boxes):
        print(f"    x {box[0]:4d}..{box[2]:4d}  y {box[1]:4d}..{box[3]:4d}  "
              f"w={box[2] - box[0] + 1:4d} h={box[3] - box[1] + 1:4d}  px={box[4]}")

    sprite = np.isin(labels, keep)
    rgba = np.dstack([rgb.astype(np.uint8), (sprite * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA")


for source in sys.argv[1:]:
    result = cutout(source)
    out = source.replace(".png", "_cut.png")
    result.save(out)
    print(f"  wrote {out}")
