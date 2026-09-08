from PIL import Image, ImageDraw
import numpy as np

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")

# Let's inspect the lower bridge by cropping 20x20 patches or drawing candidate segments
# Candidate segments for lower bridge:
# Left platform: ends around x=845, y=790
# Bridge:
# From (845, 790) to (920, 808)
# From (920, 808) to (1000, 822)
# From (1000, 822) to (1080, 810)
# From (1080, 810) to (1160, 760)?
# Wait, let's check what y is at x=1160!

test_img = img.crop((800, 740, 1200, 860))
draw = ImageDraw.Draw(test_img)

# Let's draw horizontal lines at y=760, 780, 790, 800, 810, 820, 830
for y in range(750, 850, 10):
    rel_y = y - 740
    draw.line([(0, rel_y), (400, rel_y)], fill=(120, 120, 120, 150), width=1)
    draw.text((5, rel_y - 10), f"y={y}", fill=(255, 255, 0, 255))

for x in range(800, 1200, 50):
    rel_x = x - 800
    draw.line([(rel_x, 0), (rel_x, 120)], fill=(120, 120, 120, 150), width=1)
    draw.text((rel_x + 2, 105), f"x={x}", fill=(0, 255, 255, 255))

test_img.save("tools/_debug_lower_bridge_inspect.png")
print("Saved tools/_debug_lower_bridge_inspect.png")
