from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png")
w, h = img.size

# Let's crop:
# 1. Upper tier full: x from 60 to 1460, y from 350 to 500
img.crop((60, 350, 1460, 500)).save("tools/_map1_upper_full.png")

# 2. Mid tier: x from 500 to 1200, y from 500 to 720
img.crop((500, 500, 1200, 720)).save("tools/_map1_mid_tier.png")

# 3. Lower tier full: x from 60 to 1460, y from 750 to 920
img.crop((60, 750, 1460, 920)).save("tools/_map1_lower_full.png")

print("Cropped sections saved.")
