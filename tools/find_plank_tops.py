from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

# Let's inspect lower bridge:
# At x=840 (where stone ledge ends at y=790)
# What is the plank top at x=860, 880, 900, 920, 940, 960, 980, 1000, 1020, 1040, 1060, 1080, 1100, 1120, 1140?
# In _debug_lower_bridge_inspect.png, we can see the image rows:
# Let's crop vertical strips and print the RGB values around y=785 to 815!

print("Lower bridge pixels inspection:")
for x in [840, 860, 880, 900, 920, 940, 960, 980, 1000, 1020, 1040, 1060, 1080, 1100, 1120, 1140]:
    # Look for the top of the horizontal wooden plank
    # The plank has lighter pixels (R ~ 120-180, G ~ 60-90, B ~ 30-50)
    print(f"--- x={x} ---")
    for y in range(780, 825):
        r, g, b, a = arr[y, x]
        if r > 100 and g > 50:
            print(f"  y={y}: R={r}, G={g}, B={b}")
