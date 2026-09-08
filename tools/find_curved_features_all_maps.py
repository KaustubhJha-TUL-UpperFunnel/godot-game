import sys
from pathlib import Path
from PIL import Image
import numpy as np

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

# List all 31 vertical maps
vertical_maps = sorted([p for p in MAPS_DIR.glob("*_vertical.png")])
print(f"Analyzing {len(vertical_maps)} vertical maps...")

for map_path in vertical_maps:
    stem = map_path.stem
    scene_path = LEVELS_DIR / f"{stem}.tscn"
    platforms = parse_platforms(scene_path) if scene_path.exists() else []
    
    # Let's inspect the map image
    img = Image.open(map_path).convert("L")
    arr = np.array(img)
    
    # We want to know what features this map has:
    # Check if there are existing platforms, their widths, and count
    long_plats = [p for p in platforms if (p["x_range"][1] - p["x_range"][0]) > 200]
    
    print(f"\n[{stem}] (platforms: {len(platforms)}, long: {len(long_plats)})")
    for lp in long_plats:
        x0, x1 = lp["x_range"]
        y0, y1 = lp["seg"][0][1], lp["seg"][1][1]
        print(f"   - {lp['name']}: x=[{x0:.0f}, {x1:.0f}] w={x1-x0:.0f}, y=[{y0:.0f}, {y1:.0f}], rot={lp['rot']:.2f}")
