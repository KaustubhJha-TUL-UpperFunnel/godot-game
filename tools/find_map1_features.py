from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

# Let's inspect the entire map 1 art
# Where are the ledges / walking surfaces in map 1?
# Let's find:
# 1. Upper tier:
#    - Left stone ledge: from x ~ 70 to where the rope bridge starts
#    - Upper rope bridge: sagging down between left stone and right stone
#    - Right lower stone landing
#    - Stairs going up to upper right stone ledge
#    - Upper right stone ledge
# 2. Mid tier platforms / stepping stones?
#    - What's in the middle? (Platform1, 2, 10, etc.)
# 3. Lower tier:
#    - Left stone floor: from x ~ 70 to where the lower bridge starts
#    - Lower rope bridge: sagging down between left stone and right stone
#    - Right stone floor
#    - Floating stones below? (Platform6, 7)

# Let's find exact x boundaries of each of these features!
print("Searching for feature boundaries in map 1...")
