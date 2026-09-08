import sys
from pathlib import Path
import re
import math
import random

sys.path.insert(0, str(Path(__file__).resolve().parent))
from platform_updater_core import update_scene_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")

# Helper to build catenary rope bridge segments
def make_bridge_segments(name_prefix, x_start, x_end, y_start, y_end, sag=18.0, n_segs=7, group=""):
    dx = x_end - x_start
    x_mid = (x_start + x_end) * 0.5
    half_span = dx * 0.5
    
    # Generate points
    xs = [x_start + (i / n_segs) * dx for i in range(n_segs + 1)]
    pts = []
    for x in xs:
        # Linear interp between y_start and y_end + parabolic sag
        t = (x - x_start) / dx
        y_linear = y_start + t * (y_end - y_start)
        sag_offset = sag * (1.0 - ((x - x_mid) / half_span) ** 2)
        pts.append((round(x, 1), round(y_linear + sag_offset, 1)))
        
    segments = []
    for i in range(n_segs):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        segments.append({
            "name": f"{name_prefix}_{i+1}",
            "pts": (x0, y0, x1, y1),
            "one_way": True,
            "group": group
        })
    return segments

ALL_FIXES = {}

# Map 01 Fire Vertical
ALL_FIXES["map_01_fire_vertical"] = [
    {"name": "Platform_UpperLeftStone", "pts": (67, 436, 740, 436), "one_way": False, "group": ""},
    {"name": "Platform_UpperBridge1", "pts": (740, 436, 800, 440), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge2", "pts": (800, 440, 860, 446), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge3", "pts": (860, 446, 920, 452), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge4", "pts": (920, 452, 980, 455), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge5", "pts": (980, 455, 1040, 451), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge6", "pts": (1040, 451, 1090, 444), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge7", "pts": (1090, 444, 1140, 436), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperStairs1", "pts": (1140, 436, 1180, 412), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperStairs2", "pts": (1180, 412, 1220, 392), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperRightStone", "pts": (1220, 392, 1468, 392), "one_way": False, "group": ""},
    {"name": "Platform_MidFloat1", "pts": (865, 664, 957, 664), "one_way": True, "group": ""},
    {"name": "Platform_MidFloat2", "pts": (905, 587, 997, 587), "one_way": True, "group": ""},
    {"name": "Platform_MidFloat3", "pts": (970, 522, 1058, 522), "one_way": True, "group": ""},
    {"name": "Platform_LowerLeftStoneA", "pts": (67, 781, 565, 781), "one_way": False, "group": ""},
    {"name": "Platform_LowerStep1", "pts": (565, 879, 630, 879), "one_way": True, "group": ""},
    {"name": "Platform_LowerStep2", "pts": (643, 822, 710, 822), "one_way": True, "group": ""},
    {"name": "Platform_LowerLeftStoneB", "pts": (710, 781, 865, 781), "one_way": False, "group": ""},
    {"name": "Platform_LowerBridge1", "pts": (865, 781, 920, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge2", "pts": (920, 792, 975, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge3", "pts": (975, 802, 1030, 806), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge4", "pts": (1030, 806, 1085, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge5", "pts": (1085, 802, 1140, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge6", "pts": (1140, 792, 1175, 776), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerRightStone", "pts": (1175, 776, 1468, 776), "one_way": False, "group": ""},
]

# Map 07 Ice Cavern
ALL_FIXES["map_07_ice_cavern_vertical"] = [
    {"name": "Upper_Left_Stone", "pts": (67, 437, 740, 437), "one_way": False, "group": ""},
    *make_bridge_segments("Upper_Bridge", 740, 1140, 437, 437, sag=18.0, n_segs=7, group="upper_bridge"),
    {"name": "Upper_Stairs_1", "pts": (1140, 437, 1180, 418), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Stairs_2", "pts": (1180, 418, 1206, 404), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Right_Stone", "pts": (1206, 404, 1456, 404), "one_way": False, "group": ""},
    {"name": "Left_Stair_Lower", "pts": (67, 805, 129, 645), "one_way": False, "group": "left_stairs"},
    {"name": "Left_Stair_Mid", "pts": (129, 645, 215, 632), "one_way": False, "group": "left_stairs"},
    {"name": "Left_Stair_Upper", "pts": (215, 632, 308, 444), "one_way": False, "group": "left_stairs"},
    {"name": "Mid_Float_1", "pts": (906, 624, 992, 624), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (1013, 561, 1085, 561), "one_way": True, "group": ""},
    {"name": "Lower_Left_Stone", "pts": (184, 791, 865, 791), "one_way": False, "group": ""},
    *make_bridge_segments("Lower_Bridge", 865, 1165, 791, 791, sag=22.0, n_segs=6, group="lower_bridge"),
    {"name": "Lower_Right_Stone", "pts": (1165, 791, 1468, 791), "one_way": False, "group": ""},
    {"name": "Step_1", "pts": (866, 862, 1026, 862), "one_way": True, "group": ""},
    {"name": "Step_2", "pts": (1053, 862, 1133, 862), "one_way": True, "group": ""},
    {"name": "Step_3", "pts": (252, 928, 395, 928), "one_way": True, "group": ""},
    {"name": "Step_4", "pts": (587, 928, 645, 928), "one_way": True, "group": ""},
    {"name": "Step_5", "pts": (807, 928, 898, 928), "one_way": True, "group": ""},
]

# Map 13 Poison Toxic Sewer
ALL_FIXES["map_13_poison_toxic_sewer_vertical"] = [
    {"name": "Upper_Left_Stone", "pts": (67, 363, 740, 363), "one_way": False, "group": ""},
    *make_bridge_segments("Upper_Bridge", 740, 1140, 363, 363, sag=22.0, n_segs=7, group="upper_bridge"),
    {"name": "Upper_Right_Stone", "pts": (1140, 363, 1465, 363), "one_way": False, "group": ""},
    {"name": "Mid_Ladder_Step", "pts": (1178, 580, 1238, 580), "one_way": True, "group": ""},
    {"name": "Mid_Left_Stone", "pts": (67, 700, 865, 700), "one_way": False, "group": ""},
    *make_bridge_segments("Mid_Bridge", 865, 1165, 700, 698, sag=22.0, n_segs=6, group="mid_bridge"),
    {"name": "Mid_Right_Stone", "pts": (1165, 698, 1465, 698), "one_way": False, "group": ""},
    {"name": "Bottom_Left_Footing", "pts": (110, 952, 194, 952), "one_way": True, "group": ""},
    {"name": "Bottom_Right_Footing", "pts": (1351, 951, 1425, 951), "one_way": True, "group": ""},
]

# Map 25 Crystal Amethyst Geode
ALL_FIXES["map_25_crystal_amethyst_geode_vertical"] = [
    {"name": "Upper_Left_Stone", "pts": (67, 433, 740, 433), "one_way": False, "group": ""},
    *make_bridge_segments("Upper_Bridge", 740, 1140, 433, 433, sag=19.0, n_segs=7, group="upper_bridge"),
    {"name": "Upper_Stairs_1", "pts": (1140, 433, 1180, 412), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Stairs_2", "pts": (1180, 412, 1220, 392), "one_way": True, "group": "upper_bridge"},
    {"name": "Upper_Right_Stone", "pts": (1220, 392, 1465, 392), "one_way": False, "group": ""},
    {"name": "Mid_Float_1", "pts": (865, 664, 957, 664), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (905, 587, 997, 587), "one_way": True, "group": ""},
    {"name": "Mid_Float_3", "pts": (970, 522, 1058, 522), "one_way": True, "group": ""},
    {"name": "Mid_Left_Stone", "pts": (67, 771, 865, 771), "one_way": False, "group": ""},
    *make_bridge_segments("Mid_Bridge", 865, 1165, 771, 771, sag=24.0, n_segs=6, group="mid_bridge"),
    {"name": "Mid_Right_Stone", "pts": (1165, 771, 1465, 771), "one_way": False, "group": ""},
    {"name": "Bottom_Floor", "pts": (67, 953, 1465, 953), "one_way": False, "group": ""},
]

# Map 21 Water Aqueduct Chasm
ALL_FIXES["map_21_water_aqueduct_chasm_vertical"] = [
    {"name": "Upper_Aqueduct_Left", "pts": (67, 292, 600, 292), "one_way": False, "group": ""},
    *make_bridge_segments("Upper_Aqueduct_Span", 600, 1080, 292, 292, sag=12.0, n_segs=6, group="upper_aqueduct"),
    {"name": "Upper_Aqueduct_Right", "pts": (1080, 292, 1465, 292), "one_way": False, "group": ""},
    {"name": "Mid_Left_Ledge", "pts": (67, 570, 984, 570), "one_way": False, "group": ""},
    {"name": "Mid_Right_Ramp", "pts": (984, 570, 1093, 580), "one_way": True, "group": "mid_right"},
    {"name": "Mid_Right_Ledge", "pts": (1093, 580, 1412, 593), "one_way": False, "group": "mid_right"},
    {"name": "Lower_Left_Ledge", "pts": (67, 823, 599, 823), "one_way": False, "group": ""},
    {"name": "Lower_Step_1", "pts": (556, 822, 777, 822), "one_way": True, "group": ""},
    {"name": "Lower_Step_2", "pts": (741, 872, 973, 872), "one_way": True, "group": ""},
    {"name": "Lower_Step_3", "pts": (959, 874, 1191, 874), "one_way": True, "group": ""},
    {"name": "Lower_Step_4", "pts": (1186, 873, 1418, 873), "one_way": True, "group": ""},
    {"name": "Lower_Right_Ledge", "pts": (1236, 838, 1471, 838), "one_way": False, "group": ""},
]

# Map 43 Gold Midas Chasm
ALL_FIXES["map_43_gold_midas_chasm_vertical"] = [
    {"name": "Top_Left", "pts": (67, 317, 750, 317), "one_way": False, "group": ""},
    *make_bridge_segments("Top_Bridge", 750, 1150, 317, 317, sag=16.0, n_segs=6, group="top_bridge"),
    {"name": "Top_Right", "pts": (1150, 317, 1465, 317), "one_way": False, "group": ""},
    {"name": "Mid_Left", "pts": (67, 590, 780, 590), "one_way": False, "group": ""},
    *make_bridge_segments("Mid_Bridge", 780, 1170, 590, 590, sag=18.0, n_segs=6, group="mid_bridge"),
    {"name": "Mid_Right", "pts": (1170, 590, 1465, 590), "one_way": False, "group": ""},
    {"name": "Lower_Left", "pts": (67, 861, 800, 861), "one_way": False, "group": ""},
    *make_bridge_segments("Lower_Bridge", 800, 1180, 861, 861, sag=16.0, n_segs=6, group="lower_bridge"),
    {"name": "Lower_Right", "pts": (1180, 861, 1465, 861), "one_way": False, "group": ""},
]

# Map 45 Gold Opulent Sanctum
ALL_FIXES["map_45_gold_opulent_sanctum_vertical"] = [
    {"name": "Upper_Left_Plat", "pts": (682, 213, 747, 213), "one_way": True, "group": ""},
    {"name": "Upper_Right_Plat", "pts": (792, 214, 857, 214), "one_way": True, "group": ""},
    {"name": "Mid_Left_Stone", "pts": (67, 410, 750, 410), "one_way": False, "group": ""},
    *make_bridge_segments("Mid_Bridge", 750, 1150, 410, 410, sag=16.0, n_segs=6, group="mid_bridge"),
    {"name": "Mid_Right_Stone", "pts": (1150, 410, 1465, 410), "one_way": False, "group": ""},
    {"name": "Bottom_Floor", "pts": (67, 889, 1465, 889), "one_way": False, "group": ""},
]

# 8 Thin maps:
# Map 10 Ice Rime Crypt
ALL_FIXES["map_10_ice_rime_crypt_vertical"] = [
    {"name": "Upper_Left_Floor", "pts": (113, 368, 650, 368), "one_way": False, "group": ""},
    *make_bridge_segments("Upper_Walkway", 650, 1050, 368, 368, sag=12.0, n_segs=6, group="upper_walkway"),
    {"name": "Upper_Right_Floor", "pts": (1050, 368, 1423, 368), "one_way": False, "group": ""},
    {"name": "Mid_Float_1", "pts": (130, 858, 274, 858), "one_way": True, "group": ""},
    {"name": "Mid_Float_2", "pts": (300, 858, 519, 858), "one_way": True, "group": ""},
    {"name": "Mid_Float_3", "pts": (696, 858, 795, 858), "one_way": True, "group": ""},
    {"name": "Mid_Float_4", "pts": (828, 858, 942, 858), "one_way": True, "group": ""},
    {"name": "Mid_Float_5", "pts": (981, 858, 1083, 858), "one_way": True, "group": ""},
    {"name": "Mid_Float_6", "pts": (1263, 858, 1423, 858), "one_way": True, "group": ""},
    {"name": "Bottom_Floor", "pts": (67, 876, 1468, 876), "one_way": False, "group": ""},
]

# Map 12 Ice Boreas Hollow
ALL_FIXES["map_12_ice_boreas_hollow_vertical"] = [
    {"name": "Top_Float_Left", "pts": (503, 221, 581, 221), "one_way": True, "group": ""},
    {"name": "Top_Float_Right", "pts": (956, 221, 1033, 221), "one_way": True, "group": ""},
    {"name": "Upper_Ledge_Left", "pts": (190, 356, 256, 356), "one_way": True, "group": ""},
    {"name": "Upper_Ledge_Center", "pts": (592, 356, 945, 356), "one_way": False, "group": ""},
    {"name": "Upper_Ledge_Right", "pts": (1107, 356, 1190, 356), "one_way": True, "group": ""},
    {"name": "Mid_Step_Left", "pts": (442, 613, 553, 613), "one_way": True, "group": ""},
    {"name": "Mid_Floor_PlayerStart", "pts": (590, 605, 945, 605), "one_way": False, "group": ""},
    {"name": "Mid_Step_Right", "pts": (1017, 613, 1079, 613), "one_way": True, "group": ""},
    {"name": "Lower_Step_Right", "pts": (1134, 831, 1251, 831), "one_way": True, "group": ""},
    {"name": "Lower_Step_Left", "pts": (188, 864, 252, 864), "one_way": True, "group": ""},
]

# Map 18 Poison Plague Sanctum
ALL_FIXES["map_18_poison_plague_sanctum_vertical"] = [
    {"name": "Top_Spire_1", "pts": (511, 229, 612, 229), "one_way": True, "group": ""},
    {"name": "Top_Spire_2", "pts": (924, 229, 1026, 229), "one_way": True, "group": ""},
    {"name": "Top_Spire_3", "pts": (1205, 229, 1313, 229), "one_way": True, "group": ""},
    {"name": "Top_Spire_4", "pts": (1364, 229, 1423, 229), "one_way": True, "group": ""},
    {"name": "Upper_Center_Floor", "pts": (566, 326, 967, 326), "one_way": False, "group": ""},
    {"name": "Mid_Float_Left", "pts": (296, 460, 368, 460), "one_way": True, "group": ""},
    {"name": "Mid_Float_Right", "pts": (1171, 460, 1238, 460), "one_way": True, "group": ""},
    {"name": "Mid_Floor_PlayerStart", "pts": (680, 580, 860, 580), "one_way": False, "group": ""},
    {"name": "Lower_Ledge_Left", "pts": (404, 770, 629, 770), "one_way": True, "group": ""},
    {"name": "Lower_Ledge_Mid", "pts": (686, 700, 850, 700), "one_way": True, "group": ""},
    {"name": "Lower_Ledge_Right", "pts": (898, 770, 1129, 770), "one_way": True, "group": ""},
    {"name": "Lower_Floor", "pts": (676, 829, 849, 829), "one_way": True, "group": ""},
]

# Map 30 Crystal Observatory
ALL_FIXES["map_30_crystal_observatory_vertical"] = [
    {"name": "Upper_Observatory_Floor", "pts": (112, 474, 1468, 474), "one_way": False, "group": ""},
    {"name": "Mid_Crystal_Plat_1", "pts": (319, 475, 379, 475), "one_way": True, "group": ""},
    {"name": "Mid_Crystal_Plat_2", "pts": (465, 475, 1211, 475), "one_way": True, "group": ""},
    {"name": "Lower_Crystal_Plat_1", "pts": (325, 888, 399, 888), "one_way": True, "group": ""},
    {"name": "Lower_Crystal_Plat_2", "pts": (753, 888, 885, 888), "one_way": True, "group": ""},
]

# Map 36 Shadow Ossuary Chasm
ALL_FIXES["map_36_shadow_ossuary_chasm_vertical"] = [
    {"name": "Top_Ledge", "pts": (344, 259, 411, 259), "one_way": True, "group": ""},
    {"name": "Upper_Floor", "pts": (109, 366, 1421, 366), "one_way": False, "group": ""},
    {"name": "Lower_Left_Walkway", "pts": (109, 732, 745, 732), "one_way": False, "group": ""},
    {"name": "Lower_Right_Ledge", "pts": (1061, 732, 1185, 732), "one_way": True, "group": ""},
    {"name": "Bottom_Floor", "pts": (67, 750, 1468, 750), "one_way": False, "group": ""},
]

# Map 40 Shadow Catacombs Fallen
ALL_FIXES["map_40_shadow_catacombs_fallen_vertical"] = [
    {"name": "Top_Step_1", "pts": (390, 267, 481, 267), "one_way": True, "group": ""},
    {"name": "Top_Step_2", "pts": (580, 267, 658, 267), "one_way": True, "group": ""},
    {"name": "Top_Step_3", "pts": (723, 267, 799, 267), "one_way": True, "group": ""},
    {"name": "Top_Step_4", "pts": (859, 267, 939, 267), "one_way": True, "group": ""},
    {"name": "Top_Step_5", "pts": (1052, 267, 1144, 267), "one_way": True, "group": ""},
    {"name": "Upper_Floor", "pts": (111, 426, 1425, 426), "one_way": False, "group": ""},
    {"name": "Mid_Ledge", "pts": (886, 688, 944, 688), "one_way": True, "group": ""},
    {"name": "Lower_Walkway_1", "pts": (111, 757, 265, 757), "one_way": False, "group": ""},
    {"name": "Lower_Walkway_2", "pts": (303, 757, 488, 757), "one_way": False, "group": ""},
    {"name": "Lower_Walkway_3", "pts": (1040, 757, 1110, 757), "one_way": True, "group": ""},
    {"name": "Lower_Walkway_4", "pts": (1136, 757, 1425, 757), "one_way": False, "group": ""},
    {"name": "Bottom_Floor", "pts": (107, 895, 1421, 895), "one_way": False, "group": ""},
]

# Map 41 Gold Kings Treasury
ALL_FIXES["map_41_gold_kings_treasury_vertical"] = [
    {"name": "Upper_Main_Vault_Floor", "pts": (77, 377, 1143, 377), "one_way": False, "group": ""},
    {"name": "Upper_Right_Vault_Floor", "pts": (1198, 377, 1433, 377), "one_way": False, "group": ""},
    {"name": "Mid_Vault_Ledge", "pts": (79, 705, 142, 705), "one_way": True, "group": ""},
    {"name": "Lower_Vault_Floor", "pts": (77, 836, 1098, 836), "one_way": False, "group": ""},
]

# Map 46 Clockwork Foundry
ALL_FIXES["map_46_clockwork_foundry_vertical"] = [
    {"name": "Top_Foundry_Plat", "pts": (1307, 256, 1430, 256), "one_way": True, "group": ""},
    {"name": "Upper_Foundry_Floor", "pts": (102, 431, 1433, 431), "one_way": False, "group": ""},
    {"name": "Mid_Walkway_1", "pts": (135, 529, 385, 529), "one_way": True, "group": ""},
    {"name": "Mid_Walkway_2", "pts": (411, 529, 823, 529), "one_way": True, "group": ""},
    {"name": "Mid_Walkway_3", "pts": (1067, 529, 1432, 529), "one_way": True, "group": ""},
    {"name": "Lower_Foundry_Floor", "pts": (67, 907, 1468, 907), "one_way": False, "group": ""},
]

for map_name, specs in ALL_FIXES.items():
    tscn_path = LEVELS_DIR / f"{map_name}.tscn"
    if tscn_path.exists():
        update_scene_platforms(tscn_path, specs)

print(f"Applied fixes to {len(ALL_FIXES)} scenes.")
