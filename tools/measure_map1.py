from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)
h, w, _ = arr.shape

def get_surface_y_in_band(x, y_min, y_max, min_lum=30):
    # Find the top-most surface pixel in [y_min, y_max] at column x
    col = arr[y_min:y_max, x]
    # calculate luminance
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    # A stone surface or bridge plank has a distinct top edge
    # Let's inspect
    return [(y_min + i, lum[i], col[i, :3]) for i in range(len(lum)) if lum[i] > min_lum]

# Let's examine upper tier around y=400-470
print("--- Upper Tier Survey (x from 60 to 1460) ---")
# Let's check left stone ledge: x = 100, 200, 300, 400, 500, 600, 700, 800, 850
for x in range(100, 900, 100):
    pts = get_surface_y_in_band(x, 420, 470, 35)
    if pts:
        print(f"x={x}: first lit y={pts[0][0]} (lum={pts[0][1]:.1f})")

# Let's check where the upper bridge begins and ends:
print("\nUpper bridge survey (x from 800 to 1250):")
for x in range(800, 1260, 20):
    pts = get_surface_y_in_band(x, 410, 480, 35)
    # Filter for bridge planks
    # Let's see the first few points
    y_str = ", ".join([f"y={p[0]}(lum={p[1]:.0f})" for p in pts[:3]])
    print(f"x={x}: {y_str}")
