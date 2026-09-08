import re
from pathlib import Path
from PIL import Image
import numpy as np
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

vertical_scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

# For each vertical scene, let's detect:
# 1. Platform count
# 2. Are there long platforms (>250px) at y between 300 and 900?
# 3. In the art under those long platforms, is the surface curved or sagging?
# 4. Are there horizontal gaps between platforms that are spanned by bridges in the art?

for scene_path in vertical_scenes:
    platforms = parse_platforms(scene_path)
    map_img_path = MAPS_DIR / f"{scene_path.stem}.png"
    img = Image.open(map_img_path).convert("L")
    arr = np.array(img)
    
    # Check for long platforms
    curved_candidates = []
    for p in platforms:
        x0, x1 = p["x_range"]
        width = x1 - x0
        if width > 180:
            # Check the variance of brightness or contrast across the platform width
            # In particular, check if the surface Y in the art sags or varies
            curved_candidates.append((p["name"], int(x0), int(x1), int(p["seg"][0][1]), int(width)))
            
    print(f"{scene_path.stem:40s} | total plats: {len(platforms):2d} | wide platforms: {len(curved_candidates)}")
    for name, x0, x1, y, w in curved_candidates:
        print(f"    {name:12s}: x=[{x0:4d}, {x1:4d}], w={w:4d}, y={y:4d}")
