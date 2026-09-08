import math
from PIL import Image, ImageDraw

def segment_params(x0, y0, x1, y1, depth=18.0):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy)
    rot = math.atan2(dy, dx)
    half_depth = depth * 0.5
    cx = (x0 + x1) * 0.5
    cy = (y0 + y1) * 0.5 + half_depth
    return {
        "pos": (cx, cy),
        "rot": rot,
        "size": (length, depth)
    }

# Define all segments for map 1:
map1_platforms = [
    # --- UPPER TIER ---
    {"name": "Upper_Left_Stone", "pts": (67, 438, 740, 438), "one_way": False, "group": ""},
    # Upper bridge (6 segments, sag to 465)
    {"name": "Upper_Bridge_1", "pts": (740, 438, 800, 448), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_2", "pts": (800, 448, 865, 458), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_3", "pts": (865, 458, 925, 465), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_4", "pts": (925, 465, 985, 458), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_5", "pts": (985, 458, 1050, 448), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Bridge_6", "pts": (1050, 448, 1110, 438), "one_way": True, "group": "upper_bridge"},
    # Upper stairs to right elevated stone
    {"name": "Upper_Stairs_1", "pts": (1110, 438, 1160, 415), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Stairs_2", "pts": (1160, 415, 1210, 392), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Right_Stone", "pts": (1210, 392, 1466, 392), "one_way": False, "group": ""},

    # --- MID TIER FLOATING STONES ---
    {"name": "Mid_Float_1", "pts": (865, 664, 955, 664), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (905, 587, 995, 587), "one_way": True, "group": ""},
    {"name": "Mid_Float_3", "pts": (970, 522, 1060, 522), "one_way": True, "group": ""},

    # --- LOWER TIER ---
    {"name": "Lower_Left_Stone_A", "pts": (67, 781, 565, 781), "one_way": False, "group": ""},
    {"name": "Lower_Step_1", "pts": (565, 879, 630, 879), "one_way": True, "group": ""},
    {"name": "Lower_Step_2", "pts": (643, 822, 710, 822), "one_way": True, "group": ""},
    {"name": "Lower_Left_Stone_B", "pts": (710, 790, 840, 790), "one_way": False, "group": ""},
    # Lower suspension bridge (6 segments, sag to 822)
    {"name": "Lower_Bridge_1", "pts": (840, 790, 895, 804), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_2", "pts": (895, 804, 950, 816), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_3", "pts": (950, 816, 1000, 822), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_4", "pts": (1000, 822, 1050, 816), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_5", "pts": (1050, 816, 1100, 804), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Bridge_6", "pts": (1100, 804, 1145, 790), "one_way": True, "group": "lower_bridge"},
    {"name": "Lower_Right_Stone", "pts": (1145, 790, 1466, 790), "one_way": False, "group": ""},
]

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")
draw = ImageDraw.Draw(img)

for p in map1_platforms:
    x0, y0, x1, y1 = p["pts"]
    color = (255, 220, 0, 255) if p["one_way"] else (0, 255, 120, 255)
    draw.line([(x0, y0), (x1, y1)], fill=color, width=3)
    draw.ellipse([x0-2, y0-2, x0+2, y0+2], fill=(255, 0, 0, 255))
    draw.ellipse([x1-2, y1-2, x1+2, y1+2], fill=(0, 0, 255, 255))

img.crop((700, 360, 1250, 480)).save("tools/_test_map1_upper_new.png")
img.crop((800, 740, 1200, 850)).save("tools/_test_map1_lower_new.png")
img.save("tools/_test_map1_full_new.png")
print("Saved test images.")
