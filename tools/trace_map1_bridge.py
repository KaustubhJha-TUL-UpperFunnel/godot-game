from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

# Let's save a zoomed image with coordinates marked
# Let's look at the region x: [840, 1180], y: [760, 850]
crop = arr[760:850, 840:1180].copy()

# In this region, where is the floor?
# Let's find the top-most pixel of the floor for each x from 840 to 1180.
# The bridge is wooden/stone planks. Let's see what pixels are above it (dark background) vs the planks.
# Let's print colors at a few key columns:
for test_x in [860, 900, 950, 1000, 1015, 1050, 1100, 1150]:
    col_idx = test_x - 840
    print(f"\n--- x={test_x} ---")
    for y in range(770, 835, 2):
        r, g, b, a = arr[y, test_x]
        # print luminance and color
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum > 35:
            print(f"y={y}: R={r:3d} G={g:3d} B={b:3d} (lum={lum:.1f})")
