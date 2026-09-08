from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png")
# Let's inspect the region x from 800 to 1250, y from 750 to 860
# Let's print out what colors or features are there
arr = np.array(img)

# For x from 850 to 1180, let's look at the brightness and find the top of the walkway
print("Sample columns across bridge:")
for x in range(860, 1170, 20):
    # look at y in 770..850
    # The bridge floor is lit stone. Let's find the top stone pixels.
    col = arr[770:850, x]
    # find highest y where stone / bridge floor is
    print(f"x={x}:")
