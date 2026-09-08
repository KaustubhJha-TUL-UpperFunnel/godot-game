import sys
from pathlib import Path
from PIL import Image
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms
from map_analysis import analyse

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

for s in scenes:
    platforms = parse_platforms(s)
    map_png = MAPS_DIR / f"{s.stem}.png"
    img = Image.open(map_png).convert("L")
    arr = np.array(img)
    
    # Analyze image for horizontal ridges & bridges
    # Upper band: y in [350, 520]
    # Lower band: y in [700, 880]
    
    # Find long platforms in current tscn
    long_p = [p for p in platforms if (p["x_range"][1] - p["x_range"][0]) > 250]
    has_bridge = any("bridge" in p["name"].lower() or p["rot"] != 0 for p in platforms)
    
    print(f"\n[{s.stem}]")
    print(f"  Existing plats: {len(platforms)} | Long plats (>250): {len(long_p)}")
    for p in platforms:
        x0, x1 = p["x_range"]
        (ax, ay), (bx, by) = p["seg"]
        print(f"    {p['name']:24s} x:[{x0:6.1f}, {x1:6.1f}] y:[{ay:5.1f}->{by:5.1f}] rot={p['rot']:6.3f} one_way={p['one_way']}")
