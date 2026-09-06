"""Draws what will actually be written into each level scene on top of the map
art, so fifty generated levels can be reviewed without opening fifty scenes.

Reads the same plan gen_levels.py emits, so the overlay and the scene never
disagree.

    python tools/map_debug.py                        # all fifty
    python tools/map_debug.py map_01_fire_vertical.png ...
    python tools/map_debug.py --masks map_01_fire_vertical.png

Green   standable platform (dashed = one-way, jump up through it)
Red     hazard zone
Magenta death zone
Cyan    the room interior
Yellow  player start; small dots are enemy spawns, squares are door anchors
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw

from gen_levels import plan
from map_analysis import MAPS_DIR, PROJECT_ROOT, _load, analyse, find_interior, hazard_mask

OUT = PROJECT_ROOT / "tools" / "_debug"

CYAN = (90, 200, 255)
GREEN = (80, 255, 130)
AMBER = (255, 210, 70)
RED = (255, 70, 60)
MAGENTA = (255, 30, 190)
YELLOW = (255, 240, 90)


def _box(canvas: ImageDraw.ImageDraw, rect, colour, alpha: int, width: int = 2) -> None:
    # Pillow rejects inverted rectangles, and a clamped pit can end up inverted.
    x0, x1 = sorted((rect.x, rect.right))
    y0, y1 = sorted((rect.y, rect.bottom))
    canvas.rectangle([x0, y0, x1, y1], fill=(*colour, alpha), outline=(*colour, 255), width=width)


def draw(name: str, dump_masks: bool = False) -> None:
    path = MAPS_DIR / name
    info = analyse(path)
    level = plan(info)

    image = Image.open(path).convert("RGB")
    canvas = ImageDraw.Draw(image, "RGBA")

    _box(canvas, info.interior, CYAN, 0, 3)

    if level.walkable is not None:
        _box(canvas, level.walkable, CYAN, 40, 2)

    if level.death_zone is not None:
        _box(canvas, level.death_zone, MAGENTA, 60, 3)

    for hazard in level.hazards:
        _box(canvas, hazard, RED, 70, 2)

    for platform in level.platforms:
        one_way = platform.w <= 220
        _box(canvas, platform, AMBER if one_way else GREEN, 90, 2)

    for x, y in level.spawns:
        canvas.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(*YELLOW, 190))

    for x, y in level.door_anchors:
        canvas.rectangle([x - 11, y - 11, x + 11, y + 11], outline=(*YELLOW, 255), width=3)

    sx, sy = level.player_start
    canvas.ellipse([sx - 14, sy - 14, sx + 14, sy + 14], outline=(255, 255, 255, 255), width=4)

    canvas.text(
        (12, 12),
        f"{info.name}   {info.orientation}   platforms={len(level.platforms)}   "
        f"hazards={len(level.hazards)}   death={'yes' if level.death_zone else 'no'}",
        fill=(255, 255, 0, 255),
    )

    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / f"{info.name}_debug.png")
    print(
        f"{info.name:50s} {info.orientation:8s} platforms={len(level.platforms):2d} "
        f"hazards={len(level.hazards):2d} death={'yes' if level.death_zone else 'no ':3s}"
    )

    if not dump_masks:
        return
    _, lum, sat = _load(path)
    interior = find_interior(lum)
    mask = hazard_mask(lum, sat, interior)
    Image.fromarray((mask * 255).astype("uint8")).save(OUT / f"{info.name}_mask_hazard.png")


def main() -> None:
    dump_masks = "--masks" in sys.argv
    names = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    if not names:
        names = sorted(p.name for p in MAPS_DIR.glob("*.png"))
    OUT.mkdir(parents=True, exist_ok=True)
    for entry in names:
        draw(entry, dump_masks)
    print(f"\noverlays written to {OUT.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
