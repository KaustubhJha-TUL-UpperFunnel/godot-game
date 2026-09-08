from PIL import Image, ImageDraw

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
draw = ImageDraw.Draw(img)

# Complete precise platform specification for Map 1:
map1_platforms = [
    # --- UPPER TIER ---
    {"name": "Upper_Left_Stone", "pts": (67, 436, 740, 436), "one_way": False, "group": ""},
    # Upper bridge sag:
    {"name": "Upper_Bridge_1", "pts": (740, 436, 800, 440), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_2", "pts": (800, 440, 860, 446), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_3", "pts": (860, 446, 920, 452), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_4", "pts": (920, 452, 980, 455), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_5", "pts": (980, 455, 1040, 451), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_6", "pts": (1040, 451, 1090, 444), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_7", "pts": (1090, 444, 1140, 436), "one_way": True, "group": "upper_bridge"},
    # Upper stairs:
    {"name": "Upper_Stairs_1", "pts": (1140, 436, 1180, 412), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Stairs_2", "pts": (1180, 412, 1220, 392), "one_way": True, "group": "upper_bridge"},
    # Upper right stone:
    {"name": "Upper_Right_Stone", "pts": (1220, 392, 1468, 392), "one_way": False, "group": ""},

    # --- MID TIER FLOATING STONES ---
    {"name": "Mid_Float_1", "pts": (865, 664, 957, 664), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (905, 587, 997, 587), "one_way": True, "group": ""},
    {"name": "Mid_Float_3", "pts": (970, 522, 1058, 522), "one_way": True, "group": ""},

    # --- LOWER TIER ---
    {"name": "Lower_Left_Stone_A", "pts": (67, 781, 565, 781), "one_way": False, "group": ""},
    {"name": "Lower_Step_1", "pts": (565, 879, 630, 879), "one_way": True, "group": ""},
    {"name": "Lower_Step_2", "pts": (643, 822, 710, 822), "one_way": True, "group": ""},
    {"name": "Lower_Left_Stone_B", "pts": (710, 781, 865, 781), "one_way": False, "group": ""},
    # Lower bridge sag:
    {"name": "Lower_Bridge_1", "pts": (865, 781, 920, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_2", "pts": (920, 792, 975, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_3", "pts": (975, 802, 1030, 806), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_4", "pts": (1030, 806, 1085, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_5", "pts": (1085, 802, 1140, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_6", "pts": (1140, 792, 1175, 776), "one_way": True, "group": "lower_bridge"},
    # Lower right stone:
    {"name": "Lower_Right_Stone", "pts": (1175, 776, 1468, 776), "one_way": False, "group": ""},
]

for p in map1_platforms:
    x0, y0, x1, y1 = p["pts"]
    color = (255, 230, 0, 255) if p["one_way"] else (0, 255, 120, 255)
    draw.line([(x0, y0), (x1, y1)], fill=color, width=2)
    draw.ellipse([x0-2, y0-2, x0+2, y0+2], fill=(255, 0, 0, 255))
    draw.ellipse([x1-2, y1-2, x1+2, y1+2], fill=(0, 0, 255, 255))

img.crop((700, 360, 1260, 480)).save("tools/_test_map1_upper_v2.png")
img.crop((800, 720, 1250, 840)).save("tools/_test_map1_lower_v2.png")
print("Saved v2 crop images.")
