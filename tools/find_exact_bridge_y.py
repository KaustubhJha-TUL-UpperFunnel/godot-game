from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGB")
arr = np.array(img)

print("Pixel scan at x=950 from y=400 to y=460:")
for y in range(400, 460):
    rgb = arr[y, 950]
    lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
    # Mark if it looks like rope rail, empty space, plank, or underside
    print(f"y={y:3d}: RGB={rgb.tolist()}, lum={lum:5.1f}")
