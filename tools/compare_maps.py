from PIL import Image
import numpy as np
from pathlib import Path

# Compare map_01 with map_07, map_13, etc.
img1 = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("L").resize((128, 128))
img7 = Image.open("descent/assets/maps/map_07_ice_cavern_vertical.png").convert("L").resize((128, 128))
img13 = Image.open("descent/assets/maps/map_13_poison_toxic_sewer_vertical.png").convert("L").resize((128, 128))

diff1_7 = np.mean(np.abs(np.array(img1, dtype=float) - np.array(img7, dtype=float)))
print("Diff map 1 and map 7:", diff1_7)
