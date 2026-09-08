from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

# Let's inspect the Upper Bridge: x in [710, 1200]
print("=== UPPER BRIDGE PROFILE ===")
# For each x, let's inspect the vertical slice y in [380, 470]
# The bridge floor has lit wooden planks. Above it is darker cavern background.
for x in range(710, 1190, 20):
    # Find the pixel where luminance jumps from background (<35) to bridge plank (>40)
    col = arr[380:470, x]
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    # Let's find candidate surface y
    # Let's print the top 3 highest y with lum > 45 in the plank region (y > 400)
    hits = [380 + i for i in range(len(lum)) if lum[i] > 42 and (380 + i) >= 400]
    first_hit = hits[0] if hits else None
    print(f"x={x:4d}: surface_y={first_hit}")

print("\n=== LOWER BRIDGE PROFILE ===")
# For each x, let's inspect the vertical slice y in [760, 860]
for x in range(830, 1190, 20):
    col = arr[760:860, x]
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    hits = [760 + i for i in range(len(lum)) if lum[i] > 42 and (760 + i) >= 770]
    first_hit = hits[0] if hits else None
    print(f"x={x:4d}: surface_y={first_hit}")
