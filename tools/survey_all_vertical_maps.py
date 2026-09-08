import re
import sys
from pathlib import Path
from PIL import Image
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

vertical_scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

print("Auditing all 31 vertical maps...")
for scene in vertical_scenes:
    platforms = parse_platforms(scene)
    
    # check if map image exists
    map_path = MAPS_DIR / f"{scene.stem}.png"
    if not map_path.exists():
        print(f"Missing map image for {scene.name}")
        continue
        
    img = Image.open(map_path)
    
    # Analyze existing platforms:
    # Are there any platforms with length > 250?
    long_plats = [p for p in platforms if (p["x_range"][1] - p["x_range"][0]) > 250]
    
    # Check for gaps and steps
    # Sort by min x
    sorted_p = sorted(platforms, key=lambda p: p["x_range"][0])
    
    print(f"\n=== {scene.stem} (platforms: {len(platforms)}) ===")
    for p in platforms:
        x0, x1 = p["x_range"]
        y0 = p["seg"][0][1]
        y1 = p["seg"][1][1]
        rot = p["rot"]
        print(f"  {p['name']:12s}: x=[{x0:6.1f}, {x1:6.1f}], y=[{y0:6.1f}->{y1:6.1f}], one_way={p['one_way']}, rot={rot:.3f}")
