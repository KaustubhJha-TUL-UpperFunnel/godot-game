from PIL import Image
import numpy as np
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

vertical_scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

for s in vertical_scenes:
    platforms = parse_platforms(s)
    # Check if any platform has rot != 0 (indicates slopes or hand-placed stairs)
    sloped = [p for p in platforms if abs(p["rot"]) > 0.01]
    # Check if any platform spans x=700..1150 in the upper tier (y in [350, 480])
    upper_spans = [p for p in platforms if p["x_range"][0] < 800 and p["x_range"][1] > 1050 and 320 < p["seg"][0][1] < 480]
    # Check if any platform spans x=800..1180 in the lower tier (y in [700, 850])
    lower_spans = [p for p in platforms if p["x_range"][0] < 900 and p["x_range"][1] > 1100 and 700 < p["seg"][0][1] < 850]
    
    print(f"{s.stem:40s} | plats: {len(platforms):2d} | upper_span: {len(upper_spans)} | lower_span: {len(lower_spans)} | sloped: {len(sloped)}")
