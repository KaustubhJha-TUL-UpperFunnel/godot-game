from PIL import Image
import numpy as np

# Load map_01_fire_vertical.png
img = Image.open("descent/assets/maps/map_01_fire_vertical.png")
print("Map size:", img.size)

# The bridge in map 1 is between Platform4 (ends ~866) and Platform5 (starts ~1163) at y around 780-840.
# Let's crop that region and inspect pixel colors or save a crop.
crop = img.crop((850, 750, 1180, 860))
crop.save("tools/_debug_bridge_crop.png")
print("Saved bridge crop: tools/_debug_bridge_crop.png")
