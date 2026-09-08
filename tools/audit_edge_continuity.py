import sys
from pathlib import Path
import math

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
scenes = sorted(LEVELS_DIR.glob("*vertical.tscn"))

issues = []

for sc in scenes:
    plats = parse_platforms(sc)
    # Check out-of-bounds
    for p in plats:
        x0, y0 = p['seg'][0]
        x1, y1 = p['seg'][1]
        x_min = min(x0, x1)
        x_max = max(x0, x1)
        w = x_max - x_min
        if w < 10:
            issues.append(f"{sc.stem}: platform {p['name']} width is very small ({w:.1f}px)")
        if x_min < 50:
            issues.append(f"{sc.stem}: platform {p['name']} extends past left wall (x_min={x_min:.1f})")
        if x_max > 1480:
            issues.append(f"{sc.stem}: platform {p['name']} extends past right wall (x_max={x_max:.1f})")
            
    # Check adjacent platform lips
    for i in range(len(plats)):
        pA = plats[i]
        xA0, yA0 = pA['seg'][0]
        xA1, yA1 = pA['seg'][1]
        xAmin, xAmax = min(xA0, xA1), max(xA0, xA1)
        yA_left = yA0 if xA0 <= xA1 else yA1
        yA_right = yA1 if xA0 <= xA1 else yA0
        
        for j in range(i + 1, len(plats)):
            pB = plats[j]
            xB0, yB0 = pB['seg'][0]
            xB1, yB1 = pB['seg'][1]
            xBmin, xBmax = min(xB0, xB1), max(xB0, xB1)
            yB_left = yB0 if xB0 <= xB1 else yB1
            yB_right = yB1 if xB0 <= xB1 else yB0
            
            # Check if A's right end meets B's left end
            if abs(xAmax - xBmin) < 3.0:
                diff = abs(yA_right - yB_left)
                # If neither is one_way and diff > 8px, player walking horizontally will hit solid side wall
                if not pA['one_way'] and not pB['one_way'] and diff > 10.0:
                    issues.append(f"{sc.stem}: solid lip between {pA['name']} and {pB['name']} at x={xAmax:.1f}: dy={diff:.1f}px")
            # Check if B's right end meets A's left end
            elif abs(xBmax - xAmin) < 3.0:
                diff = abs(yB_right - yA_left)
                if not pA['one_way'] and not pB['one_way'] and diff > 10.0:
                    issues.append(f"{sc.stem}: solid lip between {pB['name']} and {pA['name']} at x={xBmax:.1f}: dy={diff:.1f}px")

print(f"Edge continuity audit for {len(scenes)} vertical scenes:")
if issues:
    print(f"Found {len(issues)} issues:")
    for iss in issues:
        print(f"  {iss}")
else:
    print("ALL VERTICAL MAP PLATFORMS HAVE CLEAN CONTINUITY, NO SOLID LIPS, NO OUT-OF-BOUNDS!")
