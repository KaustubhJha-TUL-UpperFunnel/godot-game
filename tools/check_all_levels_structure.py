import re
from pathlib import Path
import math

LEVELS_DIR = Path("descent/assets/scenes/levels")
scenes = sorted(LEVELS_DIR.glob("*.tscn"))

from inspect_platforms import parse_platforms

for scene in scenes:
    text = scene.read_text(encoding="utf-8")
    kind_m = re.search(r'^\s*kind\s*=\s*(\d+)', text, re.MULTILINE)
    kind = int(kind_m.group(1)) if kind_m else 0
    
    start_m = re.search(r'\[node name="PlayerStart"[^\]]*\]\s*position\s*=\s*Vector2\(([^,\)]+),\s*([^\)]+)\)', text)
    start_x, start_y = (float(start_m.group(1)), float(start_m.group(2))) if start_m else (0.0, 0.0)
    
    platforms = parse_platforms(scene)
    
    # Check if any platform supports player start
    has_support = False
    for p in platforms:
        x0, x1 = p["x_range"]
        if (x0 - 24.0) <= start_x <= (x1 + 24.0):
            # Calculate surface Y
            # p["seg"] has [(x0, y0), (x1, y1)]
            seg_x0, seg_y0 = p["seg"][0]
            seg_x1, seg_y1 = p["seg"][1]
            if abs(seg_x1 - seg_x0) > 0.001:
                t = (start_x - seg_x0) / (seg_x1 - seg_x0)
                surf_y = seg_y0 + t * (seg_y1 - seg_y0)
            else:
                surf_y = seg_y0
            if abs((surf_y - 22.0) - start_y) <= 120.0:
                has_support = True
                break
                
    has_walkable = 'parent="WalkableRegion"' in text
    has_pit = 'parent="DeathZones"' in text
    
    status = "OK"
    if kind == 1 and not has_support:
        status = "VERTICAL BUT NO START SUPPORT"
    elif kind == 0 and has_pit:
        status = "FLAT BUT HAS PIT"
        
    if status != "OK" or len(platforms) < 4:
        print(f"{scene.name:45s} | kind={kind} | plats={len(platforms):2d} | support={has_support} | walkable={has_walkable} | status={status}")
