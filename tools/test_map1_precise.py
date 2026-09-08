from PIL import Image, ImageDraw

# Updated precise coordinates for map 1:
map1_precise_platforms = [
    # --- UPPER TIER ---
    {"name": "Upper_Left_Stone", "pts": (67, 436, 740, 436), "one_way": False, "group": ""},
    # Upper bridge (following planks: 436 -> 442 -> 448 -> 452 -> 448 -> 442 -> 436)
    {"name": "Upper_Bridge_1", "pts": (740, 436, 800, 442), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_2", "pts": (800, 442, 860, 448), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_3", "pts": (860, 448, 920, 452), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_4", "pts": (920, 452, 980, 452), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_5", "pts": (980, 452, 1040, 448), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_6", "pts": (1040, 448, 1100, 442), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_7", "pts": (1100, 442, 1140, 436), "one_way": True, "group": "upper_bridge"},
    # Stairs to upper right stone
    {"name": "Upper_Stairs_1", "pts": (1140, 436, 1180, 412), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Stairs_2", "pts": (1180, 412, 1220, 392), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Right_Stone", "pts": (1220, 392, 1466, 392), "one_way": False, "group": ""},

    # --- MID TIER FLOATING STONES ---
    {"name": "Mid_Float_1", "pts": (865, 664, 955, 664), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (905, 587, 995, 587), "one_way": True, "group": ""},
    {"name": "Mid_Float_3", "pts": (970, 522, 1060, 522), "one_way": True, "group": ""},

    # --- LOWER TIER ---
    {"name": "Lower_Left_Stone_A", "pts": (67, 781, 565, 781), "one_way": False, "group": ""},
    {"name": "Lower_Step_1", "pts": (565, 879, 630, 879), "one_way": True, "group": ""},
    {"name": "Lower_Step_2", "pts": (643, 822, 710, 822), "one_way": True, "group": ""},
    {"name": "Lower_Left_Stone_B", "pts": (710, 785, 840, 785), "one_way": False, "group": ""},
    # Lower suspension bridge (following planks: 785 -> 790 -> 796 -> 800 -> 796 -> 790 -> 785)
    {"name": "Lower_Bridge_1", "pts": (840, 785, 890, 790), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_2", "pts": (890, 790, 945, 796), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_3", "pts": (945, 796, 1000, 800), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_4", "pts": (1000, 800, 1055, 796), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_5", "pts": (1055, 796, 1110, 790), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_6", "pts": (1110, 790, 1150, 785), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Right_Stone", "pts": (1150, 785, 1466, 785), "one_way": False, "group": ""},
]

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
draw = ImageDraw.Draw(img)

for p in map1_precise_platforms:
    x0, y0, x1, y1 = p["pts"]
    color = (255, 220, 0, 255) if p["one_way"] else (0, 255, 120, 255)
    draw.line([(x0, y0), (x1, y1)], fill=color, width=3)
    draw.ellipse([x0-2, y0-2, x0+2, y0+2], fill=(255, 0, 0, 255))
    draw.ellipse([x1-2, y1-2, x1+2, y1+2], fill=(0, 0, 255, 255))

img.crop((700, 360, 1250, 480)).save("tools/_test_map1_upper_precise.png")
img.crop((800, 740, 1200, 850)).save("tools/_test_map1_lower_precise.png")
print("Saved precise test images.")
