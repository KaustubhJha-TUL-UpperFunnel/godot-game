"""One-off extractor: recovers the ASCII pixel-map sprites embedded in the old
C++ art module into real PNG files so they can be used by Sprite2D nodes.

Run once from the repo root:  python tools/extract_pixel_art.py
"""

from __future__ import annotations

import pathlib
import re
import sys

from PIL import Image

SOURCE = pathlib.Path("descent/src/descent_art.cpp")
OUT_DIR = pathlib.Path("descent/assets/game")

COLOR_DEF = re.compile(
    r"^const Color (C_[A-Z0-9_]+)\(\s*([0-9.f]+)\s*,\s*([0-9.f]+)\s*,\s*([0-9.f]+)\s*(?:,\s*([0-9.f]+)\s*)?\);",
    re.MULTILINE,
)
LITERAL_DEF = re.compile(r'const char \*(\w+)\s*=\s*((?:\s*"[^"]*")+)\s*;')
PALETTE_DEF = re.compile(
    r"std::vector<std::pair<char, Color>>\s*(\w+)\s*=\s*\{(.*?)\};", re.DOTALL
)
PALETTE_ENTRY = re.compile(r"\{\s*'(.)'\s*,\s*([^}]+?)\s*\}")
INLINE_COLOR = re.compile(
    r"Color\(\s*([0-9.f]+)\s*,\s*([0-9.f]+)\s*,\s*([0-9.f]+)\s*(?:,\s*([0-9.f]+)\s*)?\)"
)
CREATE_CALL = re.compile(
    r"(tex_\w+(?:\[\d+\])?)\s*=\s*create_texture_from_pixels\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\)"
)


def as_float(token: str) -> float:
    return float(token.rstrip("f"))


def to_rgba(r: float, g: float, b: float, a: float) -> tuple[int, int, int, int]:
    return tuple(max(0, min(255, round(channel * 255))) for channel in (r, g, b, a))


def parse_named_colors(text: str) -> dict[str, tuple[int, int, int, int]]:
    colors = {}
    for name, r, g, b, a in COLOR_DEF.findall(text):
        colors[name] = to_rgba(
            as_float(r), as_float(g), as_float(b), as_float(a) if a else 1.0
        )
    return colors


def parse_palette_body(
    body: str, named: dict[str, tuple[int, int, int, int]]
) -> dict[str, tuple[int, int, int, int]]:
    entries = {}
    for symbol, expression in PALETTE_ENTRY.findall(body):
        expression = expression.strip()
        if expression in named:
            entries[symbol] = named[expression]
            continue
        inline = INLINE_COLOR.match(expression)
        if inline:
            r, g, b, a = inline.groups()
            entries[symbol] = to_rgba(
                as_float(r), as_float(g), as_float(b), as_float(a) if a else 1.0
            )
            continue
        raise ValueError(f"unrecognised palette colour {expression!r}")
    return entries


def sprite_name(texture: str) -> str:
    base = texture.removeprefix("tex_")
    indexed = re.match(r"(\w+)\[(\d+)\]", base)
    return f"{indexed.group(1)}_{indexed.group(2)}" if indexed else base


def nearest_before(
    definitions: list[tuple[int, str, object]], name: str, offset: int
) -> object | None:
    """The C++ reuses local names such as `pix` in every block, so a definition
    has to be resolved against the call site rather than by name alone."""
    candidates = [
        payload
        for start, key, payload in definitions
        if key == name and start < offset
    ]
    return candidates[-1] if candidates else None


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}", file=sys.stderr)
        return 1

    text = SOURCE.read_text(encoding="utf-8")
    named = parse_named_colors(text)

    literals = [
        (match.start(), match.group(1), "".join(re.findall(r'"([^"]*)"', match.group(2))))
        for match in LITERAL_DEF.finditer(text)
    ]
    palettes = [
        (match.start(), match.group(1), parse_palette_body(match.group(2), named))
        for match in PALETTE_DEF.finditer(text)
    ]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped = 0

    for match in CREATE_CALL.finditer(text):
        texture, width, height, literal, palette = match.groups()
        width, height = int(width), int(height)
        pixels = nearest_before(literals, literal, match.start())
        entries = nearest_before(palettes, palette, match.start())
        if pixels is None or entries is None:
            print(f"skipping {texture}: unresolved {literal}/{palette}")
            continue

        target = OUT_DIR / f"{sprite_name(texture)}.png"
        if target.exists():
            print(f"keeping existing {target}")
            skipped += 1
            continue

        rows = [pixels[y * width : (y + 1) * width] for y in range(height)]
        rows = [row for row in rows if len(row) == width]
        if not rows:
            print(f"skipping {texture}: no complete rows")
            continue
        if len(rows) != height:
            print(f"note: {texture} declares {height} rows but only {len(rows)} are complete")

        image = Image.new("RGBA", (width, len(rows)), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, symbol in enumerate(row):
                image.putpixel((x, y), entries.get(symbol, (0, 0, 0, 0)))

        image.save(target)
        written += 1
        print(f"wrote {target} ({width}x{len(rows)})")

    print(f"\n{written} sprites written, {skipped} existing assets left untouched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
