from PIL import Image
import numpy as np

img = Image.open("descent/assets/maps/map_07_ice_cavern_vertical.png").convert("RGB")
arr = np.array(img)

# In Map 07:
# 1. Upper bridge: between x=740 and x=1140 around y=420..460
print("--- Map 07 Upper Bridge Samples ---")
for x in range(740, 1150, 40):
    # Find first bright plank pixel (ice cavern has blue/cyan planks, high B or G)
    ys = [y for y in range(410, 470) if (arr[y,x,2] > 60 or arr[y,x,0] > 60)]
    print(f"x={x}: first lit y={ys[0] if ys else None}, sample RGB={arr[ys[0], x].tolist() if ys else None}")

# 2. Lower bridge: between x=860 and x=1170 around y=760..820
print("\n--- Map 07 Lower Bridge Samples ---")
for x in range(860, 1180, 40):
    ys = [y for y in range(760, 830) if (arr[y,x,2] > 60 or arr[y,x,0] > 60)]
    print(f"x={x}: first lit y={ys[0] if ys else None}, sample RGB={arr[ys[0], x].tolist() if ys else None}")
