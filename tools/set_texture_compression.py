"""Rewrite texture .import files to use Godot's lossy (WebP) compression.

The 1536x1024 map backdrops and 1024x1024 knight frames dominate the Android
package at ~2 MB each as lossless textures. Lossy at these qualities is ~9x
smaller and leaves pixel dimensions alone, so scene layout and the hand-placed
collision shapes still line up.

Run with `python tools/set_texture_compression.py`, then re-import:
    Godot_v4.7.2-stable_win64.exe --headless --path . --import
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (glob relative to project root, lossy_quality)
TARGETS: list[tuple[str, float]] = [
    ("descent/assets/maps/*.png.import", 0.85),
    ("descent/assets/animations/knight/**/*.png.import", 0.9),
    ("descent/assets/game/dungeon_bg.png.import", 0.85),
]


def patch(path: Path, quality: float) -> bool:
    text = path.read_text(encoding="utf-8")
    patched = re.sub(r"^compress/mode=\d+$", "compress/mode=1", text, flags=re.M)
    patched = re.sub(
        r"^compress/lossy_quality=[\d.]+$",
        f"compress/lossy_quality={quality}",
        patched,
        flags=re.M,
    )
    if patched == text:
        return False
    path.write_text(patched, encoding="utf-8")
    return True


def main() -> int:
    total = 0
    for pattern, quality in TARGETS:
        matches = sorted(ROOT.glob(pattern))
        if not matches:
            print(f"warning: no .import files matched {pattern}")
            continue
        changed = sum(patch(p, quality) for p in matches)
        total += changed
        print(f"{pattern}: {changed}/{len(matches)} set to lossy q{quality}")
    print(f"\n{total} import files rewritten. Re-import to regenerate .ctex files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
