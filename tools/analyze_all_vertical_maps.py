import re
import math
from pathlib import Path
from inspect_platforms import parse_platforms

levels_dir = Path("descent/assets/scenes/levels")
maps_dir = Path("descent/assets/maps")

vertical_scenes = sorted(levels_dir.glob("*_vertical.tscn"))

print(f"Total vertical scenes: {len(vertical_scenes)}")
print("=" * 80)

for scene in vertical_scenes:
    platforms = parse_platforms(scene)
    
    # Check for long platforms (w > 200) that might be cutting across bridges or uneven ground
    wide_platforms = [p for p in platforms if (p["x_range"][1] - p["x_range"][0]) > 250]
    
    # Check for adjacent platforms and edge differences
    # Sort by min x
    sorted_p = sorted(platforms, key=lambda p: p["x_range"][0])
    
    issues = []
    # Check pairwise transitions
    for i in range(len(sorted_p)):
        for j in range(i + 1, len(sorted_p)):
            p1 = sorted_p[i]
            p2 = sorted_p[j]
            # Check if they are horizontally close or overlapping
            x_dist = p2["x_range"][0] - p1["x_range"][1]
            if -30 <= x_dist <= 30: # near or overlapping
                # evaluate y difference at transition
                y1 = p1["seg"][1][1] if p1["seg"][0][0] < p1["seg"][1][0] else p1["seg"][0][1]
                y2 = p2["seg"][0][1] if p2["seg"][0][0] < p2["seg"][1][0] else p2["seg"][1][1]
                diff = abs(y1 - y2)
                if diff > 15 and diff < 60:
                    issues.append(f"step {p1['name']}->{p2['name']}: dx={x_dist:.1f}, dy={diff:.1f}")
                elif x_dist > 5 and x_dist < 40 and diff < 20:
                    issues.append(f"gap {p1['name']}->{p2['name']}: dx={x_dist:.1f}, dy={diff:.1f}")
                    
    print(f"{scene.stem:40s} | plats: {len(platforms):2d} | wide: {len(wide_platforms):2d} | issues: {len(issues)}")
    for iss in issues[:3]:
        print(f"    - {iss}")
