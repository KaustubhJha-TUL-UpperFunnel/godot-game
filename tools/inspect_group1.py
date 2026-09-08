import sys
from pathlib import Path
from PIL import Image
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

for name in [
    "map_01_fire_vertical",
    "map_03_fire_magma_chasm_vertical",
    "map_05_fire_catacombs_vertical",
    "map_07_ice_cavern_vertical",
    "map_09_ice_glacial_abyss_vertical",
]:
    tscn = Path(f"descent/assets/scenes/levels/{name}.tscn")
    platforms = parse_platforms(tscn)
    print(f"\n================== {name} ({len(platforms)} platforms) ==================")
    for p in platforms:
        x0, x1 = p["x_range"]
        y0, y1 = p["seg"][0][1], p["seg"][1][1]
        print(f"{p['name']:12s} | one_way={str(p['one_way']):5s} | x=[{x0:6.1f}, {x1:6.1f}] | y=[{y0:6.1f}->{y1:6.1f}] | rot={p['rot']:+.3f}")
