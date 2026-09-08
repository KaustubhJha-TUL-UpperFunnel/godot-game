from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png")
# Let's inspect the upper tier: y from 380 to 480 across x from 50 to 1450
crop = img.crop((50, 380, 1450, 480))
crop.save("tools/_debug_map1_upper_tier.png")
print("Saved tools/_debug_map1_upper_tier.png")
