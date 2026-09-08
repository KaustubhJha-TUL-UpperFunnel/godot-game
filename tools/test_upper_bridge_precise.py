from PIL import Image, ImageDraw

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
draw = ImageDraw.Draw(img)

# Let's test the upper tier platforms:
upper_platforms = [
    # Left stone ledge: top surface is around y=403
    {"pts": (67, 403, 740, 403), "one_way": False},
    # Rope bridge planks:
    {"pts": (740, 403, 800, 407), "one_way": True},
    {"pts": (800, 407, 860, 414), "one_way": True},
    {"pts": (860, 414, 920, 419), "one_way": True},
    {"pts": (920, 419, 980, 419), "one_way": True},
    {"pts": (980, 419, 1040, 415), "one_way": True},
    {"pts": (1040, 415, 1100, 408), "one_way": True},
    {"pts": (1100, 408, 1140, 403), "one_way": True},
    # Stairs up to right stone
    {"pts": (1140, 403, 1180, 392), "one_way": True},
    {"pts": (1180, 392, 1220, 381), "one_way": True},
    # Right stone ledge:
    {"pts": (1220, 381, 1466, 381), "one_way": False},
]

for p in upper_platforms:
    x0, y0, x1, y1 = p["pts"]
    color = (255, 220, 0, 255) if p["one_way"] else (0, 255, 120, 255)
    draw.line([(x0, y0), (x1, y1)], fill=color, width=2)
    draw.ellipse([x0-2, y0-2, x0+2, y0+2], fill=(255, 0, 0, 255))
    draw.ellipse([x1-2, y1-2, x1+2, y1+2], fill=(0, 0, 255, 255))

img.crop((700, 350, 1260, 450)).save("tools/_test_upper_realigned.png")
print("Saved _test_upper_realigned.png")
