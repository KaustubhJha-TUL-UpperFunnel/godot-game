import sys
from pathlib import Path
import math

sys.path.insert(0, str(Path(__file__).resolve().parent))
from platform_updater_core import update_scene_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")

def make_bridge_segments(x0, y0, x1, y1, steps, sag, name_prefix, group, one_way=True, depth=16.0):
    segments = []
    dx = (x1 - x0) / steps
    
    xs = [x0 + i * dx for i in range(steps + 1)]
    ys = []
    for i in range(steps + 1):
        t = i / steps
        y_linear = y0 + (y1 - y0) * t
        y_sag = 4.0 * sag * t * (1.0 - t)
        ys.append(y_linear + y_sag)
        
    for i in range(steps):
        p0_x = xs[i] - (0.5 if i > 0 else 0.0)
        p1_x = xs[i+1] + (0.5 if i < steps - 1 else 0.0)
        p0_y = ys[i]
        p1_y = ys[i+1]
        segments.append({
            "name": f"{name_prefix}_{i+1}",
            "pts": (round(p0_x, 1), round(p0_y, 1), round(p1_x, 1), round(p1_y, 1)),
            "one_way": one_way,
            "group": group,
            "depth": depth
        })
    return segments

BATCH2_FIXES = {}

# 1. Map 03: Fire Magma Chasm
m03_bridge = make_bridge_segments(465, 485, 1065, 485, steps=8, sag=6.0, name_prefix="Platform_MidBridge", group="mid_bridge", one_way=True)
BATCH2_FIXES["map_03_fire_magma_chasm_vertical"] = [
    {"name": "Platform_UpperLeftStone", "pts": (67, 284, 451, 284), "one_way": False},
    {"name": "Platform_UpperLeftStairs", "pts": (444, 284, 572, 357), "one_way": True, "group": "upper_stairs_left"},
    {"name": "Platform_UpperRightStone", "pts": (1150, 284, 1468, 284), "one_way": False},
    {"name": "Platform_UpperRightStairs", "pts": (1027, 357, 1155, 284), "one_way": True, "group": "upper_stairs_right"},
    {"name": "Platform_MidLeftStone", "pts": (67, 567, 390, 567), "one_way": False},
    {"name": "Platform_MidLeftStairs", "pts": (353, 567, 471, 485), "one_way": True, "group": "mid_stairs_left"},
    *m03_bridge,
    {"name": "Platform_MidRightStairs", "pts": (1060, 485, 1188, 567), "one_way": True, "group": "mid_stairs_right"},
    {"name": "Platform_MidRightStone", "pts": (1152, 567, 1468, 567), "one_way": False},
    {"name": "Platform_Step1", "pts": (554, 594, 652, 594), "one_way": True},
    {"name": "Platform_Step2", "pts": (638, 640, 734, 640), "one_way": True},
    {"name": "Platform_Step3", "pts": (708, 685, 806, 685), "one_way": True},
    {"name": "Platform_Step4", "pts": (786, 728, 884, 728), "one_way": True},
    {"name": "Platform_Step5", "pts": (896, 800, 992, 800), "one_way": True},
    {"name": "Platform_LowerLeftStone", "pts": (67, 894, 456, 894), "one_way": False},
    {"name": "Platform_LowerRightStone", "pts": (1054, 894, 1468, 894), "one_way": False},
    {"name": "Platform_PitFloor", "pts": (67, 997, 1468, 997), "one_way": False},
]

# 2. Map 05: Fire Catacombs
m05_ramp = make_bridge_segments(772, 535, 1190, 348, steps=5, sag=0.0, name_prefix="Platform_MidRamp", group="mid_ramp", one_way=True)
BATCH2_FIXES["map_05_fire_catacombs_vertical"] = [
    {"name": "Platform_UpperLeftFloor", "pts": (67, 371, 824, 371), "one_way": False},
    {"name": "Platform_UpperRightLedge", "pts": (1189, 348, 1468, 348), "one_way": False},
    {"name": "Platform_MidLedge", "pts": (639, 535, 901, 535), "one_way": True},
    *m05_ramp,
    {"name": "Platform_LowerLeftFloor", "pts": (67, 828, 1116, 828), "one_way": False},
    {"name": "Platform_LowerRightFloor", "pts": (1229, 816, 1468, 816), "one_way": False},
]

# 3. Map 09: Ice Glacial Abyss
BATCH2_FIXES["map_09_ice_glacial_abyss_vertical"] = [
    {"name": "Platform_TopStep", "pts": (642, 152, 718, 152), "one_way": True},
    {"name": "Platform_UpperLeftIce", "pts": (67, 314, 600, 314), "one_way": False},
    {"name": "Platform_UpperRightIce", "pts": (1168, 300, 1468, 300), "one_way": False},
    {"name": "Platform_MidStep1", "pts": (718, 446, 818, 446), "one_way": True},
    {"name": "Platform_MidStep2", "pts": (601, 508, 677, 508), "one_way": True},
    {"name": "Platform_MidStep3", "pts": (859, 507, 957, 507), "one_way": True},
    {"name": "Platform_MidLeftStone", "pts": (67, 587, 626, 587), "one_way": False},
    {"name": "Platform_MidRightStone", "pts": (1028, 608, 1468, 608), "one_way": False},
    {"name": "Platform_MidStep4", "pts": (803, 624, 901, 624), "one_way": True},
    {"name": "Platform_LeftSlope", "pts": (187, 587, 547, 940), "one_way": True, "group": "slope_left"},
    {"name": "Platform_RightSlope", "pts": (1198, 736, 1454, 545), "one_way": True, "group": "slope_right"},
    {"name": "Platform_Step5", "pts": (797, 888, 895, 888), "one_way": True},
    {"name": "Platform_LowerLeftIce", "pts": (67, 940, 743, 940), "one_way": False},
    {"name": "Platform_LowerMidIce", "pts": (962, 947, 1256, 947), "one_way": True},
    {"name": "Platform_LowerRightIce", "pts": (1234, 917, 1468, 917), "one_way": False},
]

# 4. Map 15: Poison Spore Caverns
m15_bridge = make_bridge_segments(337, 460, 715, 460, steps=4, sag=4.0, name_prefix="Platform_UpperBridge", group="upper_bridge", one_way=True)
BATCH2_FIXES["map_15_poison_spore_caverns_vertical"] = [
    {"name": "Platform_TopStep", "pts": (668, 244, 756, 244), "one_way": True},
    {"name": "Platform_UpperLeftStone", "pts": (67, 347, 389, 347), "one_way": False},
    *m15_bridge,
    {"name": "Platform_UpperRightStep1", "pts": (816, 427, 1012, 427), "one_way": True},
    {"name": "Platform_UpperRightStep2", "pts": (1059, 538, 1161, 538), "one_way": True},
    {"name": "Platform_UpperRightStep3", "pts": (1191, 559, 1345, 559), "one_way": True},
    {"name": "Platform_MidLeftSlope", "pts": (262, 555, 342, 477), "one_way": True},
    {"name": "Platform_MidLeftStone", "pts": (67, 564, 268, 564), "one_way": False},
    {"name": "Platform_MidCenterStone", "pts": (393, 630, 691, 630), "one_way": True},
    {"name": "Platform_MidSlope1", "pts": (502, 785, 860, 673), "one_way": True, "group": "mid_mush_slope"},
    {"name": "Platform_MidStep4", "pts": (722, 739, 832, 739), "one_way": True},
    {"name": "Platform_MidSlope2", "pts": (807, 734, 909, 692), "one_way": True, "group": "mid_mush_bridge"},
    {"name": "Platform_MidSlope3", "pts": (898, 729, 990, 790), "one_way": True, "group": "mid_mush_bridge"},
    {"name": "Platform_LowerRightFloor", "pts": (914, 795, 1468, 795), "one_way": False},
]

# 5. Map 17: Poison Alchemical Lab
BATCH2_FIXES["map_17_poison_alchemical_lab_vertical"] = [
    {"name": "Platform_TopLeftStep", "pts": (108, 223, 168, 223), "one_way": True},
    {"name": "Platform_UpperWalkway", "pts": (67, 393, 1450, 393), "one_way": False},
    {"name": "Platform_MidRightStep", "pts": (1068, 499, 1166, 499), "one_way": True},
    {"name": "Platform_GroundWalkway", "pts": (67, 871, 1468, 871), "one_way": False},
]

# 6. Map 19: Water Sunken Ruins
m19_arch = make_bridge_segments(600, 347, 1136, 351, steps=6, sag=-36.0, name_prefix="Platform_UpperArch", group="upper_arch", one_way=True)
BATCH2_FIXES["map_19_water_sunken_ruins_vertical"] = [
    {"name": "Platform_UpperLeftStone", "pts": (67, 347, 604, 347), "one_way": False},
    *m19_arch,
    {"name": "Platform_UpperRightStone", "pts": (1122, 351, 1468, 351), "one_way": False},
    {"name": "Platform_UpperLeftStairs", "pts": (110, 446, 370, 650), "one_way": True, "group": "left_stairs"},
    {"name": "Platform_MidLeftStone", "pts": (67, 780, 335, 780), "one_way": False},
    {"name": "Platform_LowerLeftStairs", "pts": (326, 786, 518, 938), "one_way": True, "group": "lower_left_stairs"},
    {"name": "Platform_Float1", "pts": (643, 498, 731, 498), "one_way": True},
    {"name": "Platform_Float2", "pts": (370, 653, 458, 653), "one_way": True},
    {"name": "Platform_Float3", "pts": (538, 684, 626, 684), "one_way": True},
    {"name": "Platform_Float4", "pts": (843, 760, 931, 760), "one_way": True},
    {"name": "Platform_LowerRightStairs", "pts": (993, 937, 1179, 781), "one_way": True, "group": "lower_right_stairs"},
    {"name": "Platform_MidRightStone", "pts": (1174, 781, 1468, 781), "one_way": False},
    {"name": "Platform_GroundFloor", "pts": (67, 946, 1468, 946), "one_way": False},
]

# 7. Map 22: Water Deep Grotto
BATCH2_FIXES["map_22_water_deep_grotto_vertical"] = [
    {"name": "Platform_UpperFloor", "pts": (67, 376, 1052, 376), "one_way": False},
    {"name": "Platform_UpperRightStep", "pts": (1033, 370, 1136, 370), "one_way": True},
    {"name": "Platform_LowerLeftLedge", "pts": (67, 791, 521, 791), "one_way": False},
    {"name": "Platform_LowerRightLedge", "pts": (963, 797, 1468, 797), "one_way": False},
]

# 8. Map 24: Water Tidal Gate
BATCH2_FIXES["map_24_water_tidal_gate_vertical"] = [
    {"name": "Platform_UpperLeftWalkway", "pts": (67, 365, 1148, 365), "one_way": False},
    {"name": "Platform_UpperRightWalkway", "pts": (1108, 357, 1445, 357), "one_way": False},
    {"name": "Platform_MidLeftFloor", "pts": (67, 720, 513, 720), "one_way": False},
    {"name": "Platform_MidCenterFloor", "pts": (624, 720, 854, 720), "one_way": False},
    {"name": "Platform_MidRightFloor", "pts": (1023, 717, 1445, 717), "one_way": False},
    {"name": "Platform_MidStep", "pts": (873, 811, 995, 811), "one_way": True},
    {"name": "Platform_LowerStep1", "pts": (284, 931, 408, 931), "one_way": True},
    {"name": "Platform_LowerStep2", "pts": (893, 929, 969, 929), "one_way": True},
    {"name": "Platform_LowerStep3", "pts": (1029, 927, 1255, 927), "one_way": True},
    {"name": "Platform_LowerStep4", "pts": (1288, 922, 1350, 922), "one_way": True},
    {"name": "Platform_LowerLongFloor", "pts": (672, 945, 1445, 945), "one_way": False},
]

# 9. Map 27: Crystal Spire Chasm
m27_ramp1 = make_bridge_segments(394, 911, 722, 811, steps=4, sag=0.0, name_prefix="Platform_LowerRampLeft", group="ramp_left", one_way=True)
m27_ramp2 = make_bridge_segments(886, 793, 1288, 919, steps=4, sag=0.0, name_prefix="Platform_LowerRampMid", group="ramp_mid", one_way=True)
BATCH2_FIXES["map_27_crystal_spire_chasm_vertical"] = [
    {"name": "Platform_UpperLeftStone", "pts": (67, 297, 621, 297), "one_way": False},
    {"name": "Platform_UpperRightStone", "pts": (798, 296, 1468, 296), "one_way": False},
    {"name": "Platform_UpperStep", "pts": (826, 355, 924, 355), "one_way": True},
    {"name": "Platform_MidLeftStone", "pts": (67, 599, 336, 599), "one_way": False},
    {"name": "Platform_MidLeftSlope", "pts": (296, 599, 370, 565), "one_way": True},
    {"name": "Platform_MidLeftCrystal", "pts": (351, 552, 643, 552), "one_way": False},
    {"name": "Platform_MidStep1", "pts": (829, 585, 951, 585), "one_way": True},
    {"name": "Platform_MidRightCrystal", "pts": (953, 579, 1468, 579), "one_way": False},
    {"name": "Platform_MidStep2", "pts": (665, 660, 769, 660), "one_way": True},
    {"name": "Platform_MidStep3", "pts": (552, 757, 656, 757), "one_way": True},
    {"name": "Platform_LowerLeftStone", "pts": (67, 876, 550, 876), "one_way": False},
    *m27_ramp1,
    *m27_ramp2,
    {"name": "Platform_LowerRightSlope", "pts": (985, 836, 1401, 908), "one_way": True, "group": "ramp_right"},
    {"name": "Platform_LowerRightStone", "pts": (1165, 895, 1468, 895), "one_way": False},
]

# 10. Map 28: Crystal Prismatic Mine
BATCH2_FIXES["map_28_crystal_prismatic_mine_vertical"] = [
    {"name": "Platform_UpperLeftRail", "pts": (67, 318, 1130, 318), "one_way": False},
    {"name": "Platform_UpperRightRail", "pts": (1131, 318, 1445, 318), "one_way": False},
    {"name": "Platform_MidRail", "pts": (67, 613, 1344, 613), "one_way": False},
    {"name": "Platform_MidRightLedge", "pts": (1304, 626, 1468, 626), "one_way": False},
    {"name": "Platform_LowerRail", "pts": (67, 891, 1468, 891), "one_way": False},
]

# 11. Map 31: Nature Overgrown Sanctuary
BATCH2_FIXES["map_31_nature_overgrown_sanctuary_vertical"] = [
    {"name": "Platform_UpperLeftBranch", "pts": (67, 448, 528, 448), "one_way": False},
    {"name": "Platform_UpperRightBranch", "pts": (1194, 420, 1468, 420), "one_way": False},
    {"name": "Platform_LowerLeftRoot", "pts": (67, 815, 820, 815), "one_way": False},
    {"name": "Platform_LowerRightRoot", "pts": (1122, 825, 1468, 825), "one_way": False},
]

# 12. Map 33: Nature Ancient Hollow
m33_bridge1 = make_bridge_segments(551, 253, 981, 253, steps=6, sag=6.0, name_prefix="Platform_UpperBridge", group="upper_bridge", one_way=True)
m33_bridge2 = make_bridge_segments(534, 870, 1038, 870, steps=6, sag=6.0, name_prefix="Platform_LowerBridge", group="lower_bridge", one_way=True)
BATCH2_FIXES["map_33_nature_ancient_hollow_vertical"] = [
    {"name": "Platform_UpperLeftBranch", "pts": (67, 275, 407, 275), "one_way": False},
    *m33_bridge1,
    {"name": "Platform_UpperRightBranch", "pts": (979, 260, 1468, 260), "one_way": False},
    {"name": "Platform_UpperSlope1", "pts": (339, 404, 565, 249), "one_way": True, "group": "upper_slope_1"},
    {"name": "Platform_UpperSlope2", "pts": (246, 425, 398, 535), "one_way": True, "group": "upper_slope_2"},
    {"name": "Platform_MidLeftBranch", "pts": (67, 589, 397, 589), "one_way": False},
    {"name": "Platform_MidSlope1", "pts": (381, 578, 561, 525), "one_way": True, "group": "mid_slope_1"},
    {"name": "Platform_MidCenterWalkway", "pts": (550, 548, 976, 548), "one_way": False},
    {"name": "Platform_MidRightWalkway", "pts": (996, 555, 1368, 555), "one_way": True},
    {"name": "Platform_MidRightStep", "pts": (1312, 546, 1386, 546), "one_way": True},
    {"name": "Platform_MidSlope2", "pts": (1124, 810, 1468, 571), "one_way": True, "group": "mid_slope_2"},
    {"name": "Platform_LowerSlopeLeft", "pts": (370, 951, 540, 872), "one_way": True, "group": "lower_slope_1"},
    {"name": "Platform_LowerSlopeRight", "pts": (1039, 857, 1203, 946), "one_way": True, "group": "lower_slope_2"},
    {"name": "Platform_LowerLeftFloor", "pts": (67, 915, 482, 915), "one_way": False},
    {"name": "Platform_LowerRightFloor", "pts": (1101, 914, 1468, 914), "one_way": False},
    *m33_bridge2,
]

# 13. Map 35: Nature Druidic Canopy
BATCH2_FIXES["map_35_nature_druidic_canopy_vertical"] = [
    {"name": "Platform_UpperLeftStone", "pts": (67, 402, 432, 402), "one_way": False},
    {"name": "Platform_UpperMidStep", "pts": (469, 380, 635, 380), "one_way": True},
    {"name": "Platform_UpperRightStep", "pts": (822, 472, 988, 472), "one_way": True},
    {"name": "Platform_UpperRightCanopy", "pts": (1061, 400, 1468, 400), "one_way": False},
    {"name": "Platform_GroundFloor", "pts": (67, 875, 1468, 875), "one_way": False},
]

# 14. Map 38: Shadow Necrotic Spire
BATCH2_FIXES["map_38_shadow_necrotic_spire_vertical"] = [
    {"name": "Platform_UpperLeftFloor", "pts": (67, 380, 548, 380), "one_way": False},
    {"name": "Platform_UpperRightFloor", "pts": (1055, 380, 1468, 380), "one_way": False},
    {"name": "Platform_MidLeftFloor", "pts": (67, 620, 445, 620), "one_way": False},
    {"name": "Platform_MidLeftRamp", "pts": (425, 610, 547, 564), "one_way": True, "group": "mid_ramp_left"},
    {"name": "Platform_MidCenterFloor", "pts": (502, 585, 988, 585), "one_way": False},
    {"name": "Platform_MidRightRamp", "pts": (962, 585, 1086, 625), "one_way": True, "group": "mid_ramp_right"},
    {"name": "Platform_MidRightFloor", "pts": (1043, 620, 1468, 620), "one_way": False},
    {"name": "Platform_LowerLeftFloor", "pts": (67, 890, 459, 890), "one_way": False},
    {"name": "Platform_LowerLeftRamp", "pts": (424, 857, 630, 925), "one_way": True, "group": "lower_ramp_left"},
    {"name": "Platform_LowerCenterFloor", "pts": (584, 950, 952, 950), "one_way": False},
    {"name": "Platform_LowerRightRamp", "pts": (912, 928, 1066, 866), "one_way": True, "group": "lower_ramp_right"},
    {"name": "Platform_LowerRightFloor", "pts": (1046, 890, 1468, 890), "one_way": False},
]

# 15. Map 48: Electric Tesla Lab (one-way gantry walkways to allow smooth running & vertical jumps)
BATCH2_FIXES["map_48_electric_tesla_lab_vertical"] = [
    {"name": "Platform_UpperLeftGantry", "pts": (67, 302, 591, 302), "one_way": True},
    {"name": "Platform_UpperRightGantry", "pts": (583, 309, 1468, 309), "one_way": True},
    {"name": "Platform_MidLeftGantry", "pts": (67, 586, 588, 586), "one_way": True},
    {"name": "Platform_MidCenterGantry", "pts": (581, 577, 949, 577), "one_way": True},
    {"name": "Platform_MidRightGantry", "pts": (935, 585, 1468, 585), "one_way": True},
    {"name": "Platform_LowerLeftGantry", "pts": (67, 932, 613, 932), "one_way": True},
    {"name": "Platform_LowerRightGantry", "pts": (605, 920, 1468, 920), "one_way": True},
]

# 16. Map 49: Clockwork Gearworks
BATCH2_FIXES["map_49_clockwork_gearworks_vertical"] = [
    {"name": "Platform_TopWalkway", "pts": (428, 264, 784, 264), "one_way": False},
    {"name": "Platform_TopGearShelf", "pts": (778, 264, 952, 264), "one_way": True},
    {"name": "Platform_GearStep1", "pts": (948, 345, 1062, 345), "one_way": True},
    {"name": "Platform_UpperRightShelf", "pts": (1200, 382, 1468, 382), "one_way": False},
    {"name": "Platform_MidLeftShelf", "pts": (67, 434, 644, 434), "one_way": False},
    {"name": "Platform_GearStep2", "pts": (830, 471, 944, 471), "one_way": True},
    {"name": "Platform_MidGearBridge", "pts": (658, 564, 822, 564), "one_way": True},
    {"name": "Platform_GearStep3", "pts": (522, 615, 638, 615), "one_way": True},
    {"name": "Platform_GearStep4", "pts": (910, 734, 1026, 734), "one_way": True},
    {"name": "Platform_LowerLeftFloor", "pts": (67, 882, 577, 882), "one_way": False},
    {"name": "Platform_LowerRightFloor", "pts": (564, 876, 1468, 876), "one_way": False},
]

def main():
    for name, specs in BATCH2_FIXES.items():
        tscn_path = LEVELS_DIR / f"{name}.tscn"
        if not tscn_path.exists():
            print(f"File not found: {tscn_path}")
            continue
        update_scene_platforms(tscn_path, specs)
    print(f"Applied fixes to {len(BATCH2_FIXES)} scenes in Batch 2.")

if __name__ == "__main__":
    main()
