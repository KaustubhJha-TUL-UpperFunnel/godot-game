import sys
from pathlib import Path
from PIL import Image
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

MAPS_DIR = Path("descent/assets/maps")

def analyze_bridge_curve(map_name, x_start, x_end, y_min, y_max):
    img = Image.open(MAPS_DIR / f"{map_name}.png").convert("RGB")
    arr = np.array(img)
    
    # For each sample column, find the top surface of the bridge
    samples = []
    for x in range(x_start, x_end + 1, 20):
        col = arr[y_min:y_max, x]
        # Calculate luminance and contrast
        lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
        # Find where the bridge starts
        # Look for the highest gradient or threshold
        peak = np.argmax(lum)
        if lum[peak] > 40:
            samples.append((x, y_min + peak))
        else:
            samples.append((x, y_min + (y_max - y_min)//2))
    return samples

print("Map 07 Upper Bridge curve samples:")
print(analyze_bridge_curve("map_07_ice_cavern_vertical", 740, 1140, 410, 470))

print("\nMap 13 Upper Bridge curve samples:")
print(analyze_bridge_curve("map_13_poison_toxic_sewer_vertical", 740, 1140, 340, 410))

print("\nMap 25 Upper Bridge curve samples:")
print(analyze_bridge_curve("map_25_crystal_amethyst_geode_vertical", 740, 1140, 410, 470))
