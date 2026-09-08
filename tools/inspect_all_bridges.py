from PIL import Image
import numpy as np
from pathlib import Path

MAPS_DIR = Path("descent/assets/maps")
vertical_maps = sorted(MAPS_DIR.glob("*_vertical.png"))

print(f"Analyzing all {len(vertical_maps)} vertical maps for bridge features...")

# In each map, let's examine the horizontal band around y=350..500 (upper tier)
# and around y=700..850 (lower tier).
# In a bridge, there is a gap below it (darker background/lava/water/chasm) 
# and the bridge itself sags.
for map_path in vertical_maps:
    img = Image.open(map_path).convert("L")
    arr = np.array(img)
    h, w = arr.shape
    
    # Check upper tier center region (x=700..1150, y=360..480)
    # Check lower tier center region (x=800..1180, y=720..840)
    upper_crop = arr[360:480, 700:1150]
    lower_crop = arr[720:840, 800:1180]
    
    # Calculate row-wise profile to see if there is a distinct bridge feature
    print(f"{map_path.stem:40s}: upper_mean={upper_crop.mean():.1f}, lower_mean={lower_crop.mean():.1f}")
