from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

print("Upper bridge pixels inspection:")
for x in [740, 780, 820, 860, 900, 940, 980, 1020, 1060, 1100, 1140, 1180]:
    print(f"--- x={x} ---")
    for y in range(410, 460):
        r, g, b, a = arr[y, x]
        if r > 90 and g > 50:
            print(f"  y={y}: R={r}, G={g}, B={b}")
