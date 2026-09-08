from pathlib import Path
import re

LEVELS_DIR = Path("descent/assets/scenes/levels")
flat_scenes = sorted(LEVELS_DIR.glob("*flat.tscn"))

print(f"Checking {len(flat_scenes)} flat scenes:")
all_ok = True
for sc in flat_scenes:
    text = sc.read_text(encoding="utf-8")
    
    # Subresources
    shapes = {}
    for sm in re.finditer(r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*size = Vector2\(([^,]+),\s*([^)]+)\)', text):
        shapes[sm.group(1)] = (float(sm.group(2)), float(sm.group(3)))
        
    parent_m = re.search(r'\[node name="WalkableRegion" type="Area2D" parent="\."[^\n]*\](?:\s*position = Vector2\(([^,]+),\s*([^)]+)\))?', text)
    if not parent_m:
        print(f"  {sc.stem}: NO WALKABLE REGION AREA2D!")
        all_ok = False
        continue
    
    px = float(parent_m.group(1)) if parent_m.group(1) else 0.0
    py = float(parent_m.group(2)) if parent_m.group(2) else 0.0
    
    child_m = re.search(r'\[node name="[^"]+" type="CollisionShape2D" parent="WalkableRegion"[^\n]*\](?:\s*position = Vector2\(([^,]+),\s*([^)]+)\))?\s*shape = SubResource\("([^"]+)"\)', text)
    if not child_m:
        print(f"  {sc.stem}: NO WALKABLE REGION SHAPE CHILD!")
        all_ok = False
        continue
    
    cx = float(child_m.group(1)) if child_m.group(1) else 0.0
    cy = float(child_m.group(2)) if child_m.group(2) else 0.0
    shape_id = child_m.group(3)
    w_w, w_h = shapes.get(shape_id, (0, 0))
    
    world_x = px + cx
    world_y = py + cy
    
    start_m = re.search(r'\[node name="PlayerStart"[^\]]*\]\s*position = Vector2\(([^,]+),\s*([^)]+)\)', text)
    if not start_m:
        print(f"  {sc.stem}: NO PLAYER START!")
        all_ok = False
        continue
    sx, sy = float(start_m.group(1)), float(start_m.group(2))
    
    inside_x = (world_x - w_w/2) <= sx <= (world_x + w_w/2)
    inside_y = (world_y - w_h/2) <= sy <= (world_y + w_h/2)
    
    if inside_x and inside_y:
        print(f"  {sc.stem:37s}: Walkable center=({world_x:.0f}, {world_y:.0f}) size=({w_w:.0f}, {w_h:.0f}) | Start=({sx:.0f}, {sy:.0f}) -> OK")
    else:
        print(f"  {sc.stem:37s}: START OUTSIDE WALKABLE! Start=({sx:.0f}, {sy:.0f}), Walkable center=({world_x:.0f}, {world_y:.0f}) size=({w_w:.0f}, {w_h:.0f})")
        all_ok = False

print(f"All flat scenes check: {all_ok}")
