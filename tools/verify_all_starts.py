import sys
from pathlib import Path
import re

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
scenes = sorted(LEVELS_DIR.glob("*vertical.tscn"))

all_supported = True
print(f"Checking start support for {len(scenes)} vertical maps:")
for sc in scenes:
    text = sc.read_text(encoding="utf-8")
    start_m = re.search(r'\[node name="PlayerStart"[^\]]*\]\s*position = Vector2\(([^,]+),\s*([^)]+)\)', text)
    if not start_m:
        print(f"  {sc.stem}: NO PLAYER START!")
        all_supported = False
        continue
    sx, sy = float(start_m.group(1)), float(start_m.group(2))
    plats = parse_platforms(sc)
    
    supported = False
    best_drop = 9999
    best_p = None
    for p in plats:
        x0, y0 = p['seg'][0]
        x1, y1 = p['seg'][1]
        x_min, x_max = min(x0, x1), max(x0, x1)
        if x_min - 15 <= sx <= x_max + 15:
            t = (sx - x0) / (x1 - x0) if abs(x1 - x0) > 0.001 else 0.5
            plat_y = y0 + (y1 - y0) * t
            drop = plat_y - sy
            if 0 <= drop < best_drop:
                best_drop = drop
                best_p = p
                supported = True
                
    if supported and best_drop < 150:
        print(f"  {sc.stem:42s}: Start=({sx:5.0f}, {sy:5.0f}) supported by {best_p['name']:24s} (drop={best_drop:4.1f}px) -> OK")
    else:
        print(f"  {sc.stem:42s}: Start=({sx:5.0f}, {sy:5.0f}) NOT SUPPORTED! best_drop={best_drop}")
        all_supported = False

print(f"All vertical maps start support: {all_supported}")
