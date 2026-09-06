"""Throwaway probe: upscale a sprite strip over a backdrop with cell guides."""

import sys

from PIL import Image, ImageDraw

ZOOM = 4


def preview(path: str, cell_width: int, anchor: tuple[float, float]) -> None:
    strip = Image.open(path).convert("RGBA")
    backdrop = Image.new("RGBA", strip.size, (255, 0, 255, 255))
    flat = Image.alpha_composite(backdrop, strip)
    big = flat.resize((flat.width * ZOOM, flat.height * ZOOM), Image.NEAREST)

    draw = ImageDraw.Draw(big)
    for index in range(strip.width // cell_width + 1):
        x = index * cell_width * ZOOM
        draw.line([(x, 0), (x, big.height)], fill=(0, 255, 0, 255), width=1)
        ax = x + anchor[0] * ZOOM
        ay = anchor[1] * ZOOM
        draw.line([(ax - 12, ay), (ax + 12, ay)], fill=(255, 255, 0, 255), width=1)
        draw.line([(ax, ay - 12), (ax, ay + 12)], fill=(255, 255, 0, 255), width=1)

    out = path.replace(".png", "_preview.png")
    big.save(out)
    print(f"wrote {out}  {big.width}x{big.height}")


for source in sys.argv[1:]:
    preview(source, 129, (57.91, 91.17))
