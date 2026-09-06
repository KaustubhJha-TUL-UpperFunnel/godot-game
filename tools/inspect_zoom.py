"""Throwaway probe: export upscaled halves of a cut-out sheet band for eyeballing."""

import sys

from PIL import Image

BAND_TOP, BAND_BOTTOM = 366, 664

for path in sys.argv[1:]:
    sheet = Image.open(path).convert("RGBA")
    band = sheet.crop((0, BAND_TOP, sheet.width, BAND_BOTTOM))

    # Flatten onto flat magenta so transparency is unmistakable while inspecting.
    backdrop = Image.new("RGBA", band.size, (255, 0, 255, 255))
    flat = Image.alpha_composite(backdrop, band)

    half = band.width // 2
    for index, box in enumerate([(0, 0, half, band.height), (half, 0, band.width, band.height)]):
        piece = flat.crop(box)
        scaled = piece.resize((piece.width * 2, piece.height * 2), Image.NEAREST)
        out = path.replace(".png", f"_zoom{index}.png")
        scaled.save(out)
        print(f"wrote {out}  ({scaled.width}x{scaled.height}, x offset {box[0]})")
