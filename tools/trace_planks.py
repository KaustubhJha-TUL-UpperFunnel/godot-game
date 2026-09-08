from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
arr = np.array(img)

print("Upper bridge planks (y between 425 and 465):")
for x in range(720, 1130, 20):
    col = arr[425:465, x]
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    # find where planks are
    hits = [425 + i for i in range(len(lum)) if lum[i] > 36]
    first = hits[0] if hits else None
    print(f"x={x:4d}: plank_y={first}")

print("\nLower bridge planks (y between 780 and 845):")
for x in range(850, 1170, 20):
    col = arr[780:845, x]
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    hits = [780 + i for i in range(len(lum)) if lum[i] > 36]
    first = hits[0] if hits else None
    print(f"x={x:4d}: plank_y={first}")
