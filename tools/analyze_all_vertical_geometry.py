import sys
from pathlib import Path
from PIL import Image
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

vertical_scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

for scene_path in vertical_scenes:
    platforms = parse_platforms(scene_path)
    map_img = MAPS_DIR / f"{scene_path.stem}.png"
    
    # Check for platforms wider than 200px
    wide_plats = [p for p in platforms if (p["x_range"][1] - p["x_range"][0]) > 200]
    
    # Check for gaps between adjacent platforms where a bridge might be missing
    # or where platforms overlap
    print(f"\n=======================================================")
    print(f"MAP: {scene_path.stem} ({len(platforms)} platforms, {len(wide_plats)} wide)")
    print(f"=======================================================")
    for p in platforms:
        x0, x1 = p["x_range"]
        (ax, ay), (bx, by) = p["seg"]
        print(f"  {p['name']:14s} | x:[{x0:6.1f}, {x1:6.1f}] w={x1-x0:5.1f} | y:[{ay:5.1f} -> {by:5.1f}] | rot={p['rot']:6.3f} | one_way={str(p['one_way']):5s}")
