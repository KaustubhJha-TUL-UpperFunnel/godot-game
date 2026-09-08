import sys
from pathlib import Path
from PIL import Image
import numpy as np

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")

vertical_maps = sorted(list(MAPS_DIR.glob("*_vertical.png")))

# Let's inspect each map image to see where bridges, stairs, or curved platforms exist.
# A bridge in these maps typically:
# 1. Connects two stone platforms over a chasm/pit
# 2. Has vertical fence posts / ropes
# 3. Has a sagging or curved walking surface
# 4. Spans between x=300..1200

print("Scanning vertical maps for bridges and non-flat platforms:")
for p in vertical_maps:
    print(f"\nChecking {p.stem}...")
    img = Image.open(p).convert("RGB")
    arr = np.array(img)
    # Check dimensions
    # All are 1536x1024
