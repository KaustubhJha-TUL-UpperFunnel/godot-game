from PIL import Image, ImageDraw
import numpy as np
import sys
from pathlib import Path

# Load map 1
img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
w, h = img.size

# Let's write a script that parses the existing platforms in map_01_fire_vertical.tscn
# and draws them over the map image with clear outlines, endpoints, and labels.
from inspect_platforms import parse_platforms

platforms = parse_platforms("descent/assets/scenes/levels/map_01_fire_vertical.tscn")

draw_img = img.copy()
draw = ImageDraw.Draw(draw_img)

for p in platforms:
    (ax, ay), (bx, by) = p["seg"]
    # Draw top line
    draw.line([(ax, ay), (bx, by)], fill=(0, 255, 100, 255), width=3)
    # Draw a small box or endpoint dots
    draw.ellipse([ax-3, ay-3, ax+3, ay+3], fill=(255, 255, 0, 255))
    draw.ellipse([bx-3, by-3, bx+3, by+3], fill=(255, 0, 255, 255))
    # Label
    draw.text(((ax+bx)/2, min(ay, by) - 15), p["name"], fill=(255, 255, 255, 255))

draw_img.save("tools/_debug_map1_current_platforms.png")
print("Saved tools/_debug_map1_current_platforms.png")
