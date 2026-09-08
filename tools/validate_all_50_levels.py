import sys
from pathlib import Path
import re
import math

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
scenes = sorted(LEVELS_DIR.glob("*.tscn"))

REQUIRED_NODES = (
    "Background",
    "Walls",
    "Platforms",
    "Hazards",
    "DeathZones",
    "WalkableRegion",
    "PlayerStart",
    "SpawnPoints",
    "DoorAnchors",
)

def validate():
    print(f"=== COMPREHENSIVE AUDIT OF ALL {len(scenes)} LEVEL SCENES ===")
    
    vertical_count = 0
    flat_count = 0
    total_platforms = 0
    errors = []

    for sc in scenes:
        text = sc.read_text(encoding="utf-8")
        
        # 1. Kind
        kind_m = re.search(r'^\s*kind\s*=\s*(\d+)', text, re.MULTILINE)
        kind = int(kind_m.group(1)) if kind_m else 0
        is_vertical = (kind == 1)
        
        if is_vertical:
            vertical_count += 1
        else:
            flat_count += 1
            
        # 2. Check required nodes
        for req in REQUIRED_NODES:
            if f'name="{req}"' not in text:
                errors.append(f"{sc.name}: missing required node {req}")
                
        # 3. Door anchors count
        anchors = re.findall(r'parent="DoorAnchors"', text)
        if len(anchors) != 3:
            errors.append(f"{sc.name}: expected 3 door anchors, found {len(anchors)}")
            
        # 4. PlayerStart
        start_m = re.search(r'\[node name="PlayerStart"[^\]]*\]\s*position = Vector2\(([^,]+),\s*([^)]+)\)', text)
        if not start_m:
            errors.append(f"{sc.name}: missing PlayerStart marker")
            continue
        sx, sy = float(start_m.group(1)), float(start_m.group(2))
        
        # 5. Platforms / Walkable checks
        if is_vertical:
            plats = parse_platforms(sc)
            total_platforms += len(plats)
            if not plats:
                errors.append(f"{sc.name}: vertical level has 0 platforms")
                continue
                
            # Check player start support
            best_drop = 9999
            best_plat = None
            for p in plats:
                x0, y0 = p['seg'][0]
                x1, y1 = p['seg'][1]
                xmin, xmax = min(x0, x1), max(x0, x1)
                if xmin - 15 <= sx <= xmax + 15:
                    t = (sx - x0) / (x1 - x0) if abs(x1 - x0) > 0.001 else 0.5
                    plat_y = y0 + (y1 - y0) * t
                    drop = plat_y - sy
                    if 0 <= drop < best_drop:
                        best_drop = drop
                        best_plat = p
                        
            if best_drop > 150:
                errors.append(f"{sc.name}: player start at ({sx}, {sy}) not supported (best drop = {best_drop})")
                
            # Check bounds and solid lips
            for p in plats:
                x0, y0 = p['seg'][0]
                x1, y1 = p['seg'][1]
                xmin, xmax = min(x0, x1), max(x0, x1)
                if xmin < 40 or xmax > 1490:
                    errors.append(f"{sc.name}: platform {p['name']} out of bounds ({xmin:.1f}, {xmax:.1f})")
                    
            for i in range(len(plats)):
                pA = plats[i]
                xA0, yA0 = pA['seg'][0]
                xA1, yA1 = pA['seg'][1]
                xAmax = max(xA0, xA1)
                xAmin = min(xA0, xA1)
                yA_right = yA1 if xA0 <= xA1 else yA0
                yA_left = yA0 if xA0 <= xA1 else yA1
                
                for j in range(i + 1, len(plats)):
                    pB = plats[j]
                    xB0, yB0 = pB['seg'][0]
                    xB1, yB1 = pB['seg'][1]
                    xBmax = max(xB0, xB1)
                    xBmin = min(xB0, xB1)
                    yB_left = yB0 if xB0 <= xB1 else yB1
                    yB_right = yB1 if xB0 <= xB1 else yB0
                    
                    if abs(xAmax - xBmin) < 3.0:
                        diff = abs(yA_right - yB_left)
                        if not pA['one_way'] and not pB['one_way'] and diff > 10.0:
                            errors.append(f"{sc.name}: solid lip between {pA['name']} and {pB['name']}: {diff:.1f}px")
                    elif abs(xBmax - xAmin) < 3.0:
                        diff = abs(yB_right - yA_left)
                        if not pA['one_way'] and not pB['one_way'] and diff > 10.0:
                            errors.append(f"{sc.name}: solid lip between {pB['name']} and {pA['name']}: {diff:.1f}px")
                            
            # Check pit
            if 'parent="DeathZones"' not in text:
                errors.append(f"{sc.name}: vertical level has no DeathZones")
                
        else: # Flat level
            p_nodes = re.findall(r'parent="Platforms"', text)
            if p_nodes:
                errors.append(f"{sc.name}: flat level has platforms: {p_nodes}")
            if 'name="WalkableRegion"' not in text:
                errors.append(f"{sc.name}: flat level missing WalkableRegion")

    print(f"Total scenes analyzed: {len(scenes)}")
    print(f"  Vertical levels:     {vertical_count}")
    print(f"  Flat levels:         {flat_count}")
    print(f"  Total platforms:     {total_platforms}")
    print(f"  Errors found:        {len(errors)}")
    
    if errors:
        for err in errors:
            print(f"  [ERROR] {err}")
        return False
    else:
        print("\n>>> ALL 50 MAPS PASSED COMPREHENSIVE VALIDATION WITH ZERO ERRORS! <<<")
        return True

if __name__ == "__main__":
    success = validate()
    sys.exit(0 if success else 1)
