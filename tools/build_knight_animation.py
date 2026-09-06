"""Turn the raw knight animation sheets into game-ready sprite strips.

The two source sheets arrived as opaque 1024x1024 PNGs: the intended
transparency had been flattened onto a 50x50 checkerboard and then saved
lossily, and the individual poses are unevenly spaced with swords that reach
into their neighbours. This script

  1. reconstructs and subtracts the checkerboard, recovering real alpha,
  2. lifts the usable poses out using hand-measured windows,
  3. re-anchors every pose on the knight's feet so it cannot jitter, and
  4. writes one uniform strip per animation, shared cell size across both.

Run from the project root:  python tools/build_knight_animation.py
"""

from __future__ import annotations

import numpy as np
from PIL import Image

SOURCE_DIRECTORY = "descent/assets/animations/knight"

# The checkerboard is 50 cells across, giving a fractional 20.48px period.
CHECKER_CELLS = 50
CHROMA_LIMIT = 22
TONE_TOLERANCE = 24
RINGING_BAND = 2

# Radius of the window used to measure how much checkerboard still shows
# through a pixel. It has to span a full checker period to see both tones.
UNMIX_RADIUS = 21

# Coverage recovered from the composite is honest but unhelpful: the generator
# left the knight's lower body partly transparent, which reads as ghostly in
# game. Anything covered at least this much becomes solid, and the rest -- the
# baked ground shadow, which the player scene already draws for itself -- goes.
SOLID_COVERAGE = 0.42

MINIMUM_BLOB = 250
FRAME_MARGIN = 3

# How tall the knight should end up on screen. The sprite it replaces rendered
# at roughly 87px, and the player's collision and melee reach are tuned to that.
TARGET_BODY_HEIGHT = 90.0

# Hand-measured from the cut-out sheets. `window` is the slice of the sheet that
# belongs to a pose; `body` is the knight's own torso columns within it, used
# both as the alignment anchor and to measure pose height.
SHEETS: dict[str, dict] = {
    "idle": {
        "file": "ideal_animation.png",
        "frames": [
            {"window": (0, 280), "body": (104, 210)},
            {"window": (280, 504), "body": (336, 450)},
            {"window": (504, 772), "body": (568, 670)},
            {"window": (772, 1024), "body": (824, 948)},
        ],
    },
    "slash": {
        "file": "slash_animation.png",
        "frames": [
            {"window": (0, 268), "body": (88, 216)},
            {"window": (268, 400), "body": (280, 362)},
            {"window": (396, 678), "body": (500, 562)},
        ],
    },
}


def box_sum(values: np.ndarray, radius: int) -> np.ndarray:
    """Sum over a (2*radius+1) square window, via summed-area table."""
    padded = np.pad(values, radius + 1, mode="constant")
    table = padded.cumsum(axis=0).cumsum(axis=1)
    size = 2 * radius + 1
    height, width = values.shape
    bottom = slice(size, size + height)
    top = slice(0, height)
    right = slice(size, size + width)
    left = slice(0, width)
    return (
        table[bottom, right] - table[top, right] - table[bottom, left] + table[top, left]
    )


def checker_parity(height: int, width: int) -> np.ndarray:
    cell = width / CHECKER_CELLS
    ys, xs = np.mgrid[0:height, 0:width]
    return (((xs / cell).astype(int) + (ys / cell).astype(int)) % 2) == 0


def ringing_band(height: int, width: int) -> np.ndarray:
    """Pixels hugging a checker cell edge, where the lossy save left overshoot."""
    cell = width / CHECKER_CELLS
    edges = np.round(np.arange(CHECKER_CELLS + 1) * cell)
    near_x = np.abs(np.arange(width)[:, None] - edges[None, :]).min(axis=1)
    near_y = np.abs(np.arange(height)[:, None] - edges[None, :]).min(axis=1)
    return (near_x[None, :] <= RINGING_BAND) | (near_y[:, None] <= RINGING_BAND)


def flood_from_border(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    flat = mask.ravel()
    reached = np.zeros(flat.size, dtype=bool)
    stack: list[int] = []

    def seed(index: int) -> None:
        if flat[index] and not reached[index]:
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


def drop_small_blobs(mask: np.ndarray, minimum: int) -> np.ndarray:
    height, width = mask.shape
    flat = mask.ravel()
    labels = np.zeros(flat.size, dtype=np.int32)
    sizes = [0]

    for start in range(flat.size):
        if not flat[start] or labels[start]:
            continue
        label = len(sizes)
        labels[start] = label
        stack = [start]
        count = 0
        while stack:
            index = stack.pop()
            count += 1
            y, x = divmod(index, width)
            for neighbour, valid in (
                (index - width, y > 0),
                (index + width, y < height - 1),
                (index - 1, x > 0),
                (index + 1, x < width - 1),
            ):
                if valid and flat[neighbour] and not labels[neighbour]:
                    labels[neighbour] = label
                    stack.append(neighbour)
        sizes.append(count)

    keep = np.array([size >= minimum for size in sizes])
    return keep[labels].reshape(height, width)


def unbake_checkerboard(path: str) -> np.ndarray:
    """Return the sheet as RGBA with the checkerboard removed."""
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height, width = rgb.shape[:2]
    gray = rgb.mean(axis=2)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)
    parity = checker_parity(height, width)

    border = np.zeros((height, width), dtype=bool)
    border[:6, :] = border[-6:, :] = True
    border[:, :6] = border[:, -6:] = True
    light = float(np.median(gray[border & parity]))
    dark = float(np.median(gray[border & ~parity]))
    if light < dark:
        light, dark = dark, light
        parity = ~parity
    swing = light - dark
    print(f"  checker tones {dark:.0f}/{light:.0f}")

    model = np.where(parity, light, dark)
    flat_background = (np.abs(gray - model) <= TONE_TOLERANCE) & (chroma <= CHROMA_LIMIT)
    ringing = (
        ringing_band(height, width)
        & (chroma <= CHROMA_LIMIT)
        & (gray >= dark - 20)
        & (gray <= light + 20)
    )
    outside = flood_from_border(flat_background | ringing)

    # Anything the sprite only partly covered -- translucent motion-blurred
    # blades, soft ground shadows, gaps the flood could not reach -- still
    # carries some of the checker's light/dark swing. How much of the swing
    # survives locally gives the coverage directly: none means fully opaque, all
    # of it means fully transparent. Measure with background pixels excluded so
    # the window cannot reach across the silhouette and eat the sprite's rim.
    kept = (~outside).astype(np.float32)
    measured = {}
    for name, side in (("light", parity), ("dark", ~parity)):
        valid = kept * side
        total = box_sum(gray * valid, UNMIX_RADIUS)
        count = box_sum(valid, UNMIX_RADIUS)
        measured[name] = np.divide(
            total, count, out=np.zeros_like(total), where=count > 8
        )
        measured[f"{name}_count"] = count

    reliable = (measured["light_count"] > 8) & (measured["dark_count"] > 8)
    coverage = np.ones((height, width), dtype=np.float32)
    showing_through = np.clip((measured["light"] - measured["dark"]) / swing, 0.0, 1.0)
    coverage[reliable] = 1.0 - showing_through[reliable]
    coverage[outside] = 0.0

    solid = drop_small_blobs(coverage >= SOLID_COVERAGE, MINIMUM_BLOB)
    print(f"  solid pixels {int(solid.sum())}")

    # Undo the composite: observed = coverage * sprite + (1 - coverage) * checker.
    # Recovering the colour still uses the measured coverage even where the
    # pixel is about to be forced solid, because that is the colour the
    # generator actually painted underneath the checkerboard.
    safe = np.maximum(coverage, SOLID_COVERAGE)[:, :, None]
    colour = (rgb - (1.0 - coverage)[:, :, None] * model[:, :, None]) / safe

    rgba = np.zeros((height, width, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(colour, 0.0, 255.0)
    rgba[:, :, 3] = solid * 255.0
    return rgba


def frame_geometry(alpha: np.ndarray, frame: dict) -> dict:
    """Locate a pose and its anchor within the sheet."""
    left, right = frame["window"]
    body_left, body_right = frame["body"]

    inside = np.zeros_like(alpha, dtype=bool)
    inside[:, left:right] = True
    pose = (alpha > 0) & inside
    if not pose.any():
        raise ValueError(f"no pixels in window {frame['window']}")

    ys, xs = np.nonzero(pose)

    # Anchor on the torso: tall columns inside the body range, so a sword or a
    # slash arc reaching sideways cannot drag the alignment with it. Only solid
    # pixels count, so the soft ground shadow does not pull the feet down.
    body = ((alpha > 140) & inside)[:, body_left:body_right]
    heights = body.sum(axis=0)
    tall = np.nonzero(heights >= max(30, heights.max() * 0.35))[0]
    centre_x = body_left + int((tall.min() + tall.max()) // 2)

    body_ys = np.nonzero(body.any(axis=1))[0]
    feet_y = int(body_ys.max())

    return {
        "pixels": pose,
        "centre_x": centre_x,
        "feet_y": feet_y,
        "body_height": int(body_ys.max() - body_ys.min() + 1),
        "extent": (
            int(xs.min()) - centre_x,
            int(ys.min()) - feet_y,
            int(xs.max()) - centre_x,
            int(ys.max()) - feet_y,
        ),
    }


def resize_premultiplied(cell: np.ndarray, size: tuple[int, int]) -> Image.Image:
    """Downscale RGBA without letting the background colour bleed into edges."""
    alpha = cell[:, :, 3:4] / 255.0
    premultiplied = np.dstack([cell[:, :, :3] * alpha, cell[:, :, 3]])
    small = np.asarray(
        Image.fromarray(premultiplied.astype(np.uint8), "RGBA").resize(
            size, Image.LANCZOS
        ),
        dtype=np.float32,
    )

    out_alpha = small[:, :, 3:4] / 255.0
    colour = np.divide(
        small[:, :, :3], out_alpha, out=np.zeros_like(small[:, :, :3]), where=out_alpha > 0.004
    )
    result = np.dstack([np.clip(colour, 0, 255), small[:, :, 3]])
    result[:, :, 3][result[:, :, 3] < 24] = 0
    return Image.fromarray(result.astype(np.uint8), "RGBA")


def main() -> None:
    sheets = {}
    for name, spec in SHEETS.items():
        path = f"{SOURCE_DIRECTORY}/{spec['file']}"
        print(f"\n=== {path}")
        rgba = unbake_checkerboard(path)
        frames = [frame_geometry(rgba[:, :, 3], frame) for frame in spec["frames"]]
        for index, frame in enumerate(frames):
            print(
                f"  frame {index}: anchor=({frame['centre_x']},{frame['feet_y']}) "
                f"body_height={frame['body_height']} extent={frame['extent']}"
            )
        sheets[name] = {"rgba": rgba, "frames": frames}

    # One cell size and one anchor for every frame of both animations, so the
    # knight stays put when the animation switches.
    extents = [frame["extent"] for sheet in sheets.values() for frame in sheet["frames"]]
    min_x = min(extent[0] for extent in extents) - FRAME_MARGIN
    min_y = min(extent[1] for extent in extents) - FRAME_MARGIN
    max_x = max(extent[2] for extent in extents) + FRAME_MARGIN
    max_y = max(extent[3] for extent in extents) + FRAME_MARGIN

    source_width = max_x - min_x + 1
    source_height = max_y - min_y + 1
    scale = TARGET_BODY_HEIGHT / sheets["idle"]["frames"][0]["body_height"]
    cell_width = int(round(source_width * scale))
    cell_height = int(round(source_height * scale))
    anchor = (round(-min_x * scale, 2), round(-min_y * scale, 2))

    print(
        f"\ncell {source_width}x{source_height} source -> {cell_width}x{cell_height} "
        f"at scale {scale:.4f}; feet anchor at {anchor} within the cell"
    )
    print(
        "AnimatedSprite2D offset to put the feet on the node origin: "
        f"({cell_width / 2 - anchor[0]:.1f}, {cell_height / 2 - anchor[1]:.1f})"
    )

    for name, sheet in sheets.items():
        strip = Image.new("RGBA", (cell_width * len(sheet["frames"]), cell_height))
        for index, frame in enumerate(sheet["frames"]):
            cell = np.zeros((source_height, source_width, 4), dtype=np.float32)
            ys, xs = np.nonzero(frame["pixels"])
            target_x = xs - frame["centre_x"] - min_x
            target_y = ys - frame["feet_y"] - min_y
            cell[target_y, target_x, :3] = sheet["rgba"][ys, xs, :3]
            cell[target_y, target_x, 3] = sheet["rgba"][ys, xs, 3]

            small = resize_premultiplied(cell, (cell_width, cell_height))
            strip.paste(small, (index * cell_width, 0))

        out = f"{SOURCE_DIRECTORY}/knight_{name}_strip.png"
        strip.save(out)
        print(f"wrote {out}  {strip.width}x{strip.height}  ({len(sheet['frames'])} frames)")


if __name__ == "__main__":
    main()
