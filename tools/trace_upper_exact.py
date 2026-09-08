from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGB")
arr = np.array(img)

# Let's inspect the upper bridge from x=740 to x=1220
# For each x step (e.g. 20px), find the first non-background pixel or the bridge plank top
print("x-coord | y range 380..460 slice:")
for x in range(740, 1220, 25):
    # Print the RGB values around y=380..460 where brightness peaks
    col = arr[380:460, x]
    # Plank wood has distinct warm brown/orange/red tone: R > G and R > B, and luminance
    # Let's find highest gradient or top edge of plank
    lum = 0.299 * col[:, 0] + 0.587 * col[:, 1] + 0.114 * col[:, 2]
    # Find pixel where luminance is higher than background (background is dark ~ 20-40)
    plank_ys = np.where(lum > 50)[0]
    if len(plank_ys) > 0:
        top_y = 380 + plank_ys[0]
        # Also print RGB of top pixel
        rgb = col[plank_ys[0]]
        print(f"x={x:4d}: top_y={top_y:3d}, lum={lum[plank_ys[0]]:.1f}, rgb={rgb}")
    else:
        print(f"x={x:4d}: none")
