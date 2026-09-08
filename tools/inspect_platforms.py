import re
import math
from pathlib import Path

def parse_platforms(tscn_path):
    text = Path(tscn_path).read_text(encoding="utf-8")
    
    # Extract sub_resources (RectangleShape2D sizes)
    shapes = {}
    for match in re.finditer(r'\[sub_resource type="RectangleShape2D" id="([^"]+)"\]\s*size = Vector2\(([^,]+),\s*([^)]+)\)', text):
        shapes[match.group(1)] = (float(match.group(2)), float(match.group(3)))
        
    # Find all platform nodes
    # Platform node starts with [node name="..." type="StaticBody2D" parent="Platforms"
    # followed by properties, and has child CollisionShape2D
    platform_blocks = re.findall(r'\[node name="([^"]+)" type="StaticBody2D" parent="Platforms"[^\]]*\](.*?)(?=\n\[node|\n\[connection|\Z)', text, re.DOTALL)
    
    platforms = []
    for name, block in platform_blocks:
        pos_m = re.search(r'position = Vector2\(([^,]+),\s*([^)]+)\)', block)
        pos = (float(pos_m.group(1)), float(pos_m.group(2))) if pos_m else (0.0, 0.0)
        
        rot_m = re.search(r'rotation = ([-0-9.e]+)', block)
        rot = float(rot_m.group(1)) if rot_m else 0.0
        
        scale_m = re.search(r'scale = Vector2\(([^,]+),\s*([^)]+)\)', block)
        scale = (float(scale_m.group(1)), float(scale_m.group(2))) if scale_m else (1.0, 1.0)
        
        one_way = "one_way = true" in block
        
        size_m = re.search(r'size = Vector2\(([^,]+),\s*([^)]+)\)', block)
        if size_m:
            size = (float(size_m.group(1)), float(size_m.group(2)))
        else:
            shape_ref = re.search(r'SubResource\("([^"]+)"\)', block)
            size = shapes.get(shape_ref.group(1), (100.0, 18.0)) if shape_ref else (100.0, 18.0)
            
        # compute navigation segment endpoints
        # From LevelPlatform.gd:
        # half = size * 0.5
        # a = transform * Vector2(-half.x, 0)
        # b = transform * Vector2(half.x, 0)
        # thickness = abs(size.y * scale.y) * 0.5
        # a.y -= thickness
        # b.y -= thickness
        # transform: position + rotate(rot) * scale
        hx = size[0] * 0.5 * scale[0]
        # in local rotated coords:
        cos_r = math.cos(rot)
        sin_r = math.sin(rot)
        
        # local a = (-size.x*0.5*scale.x, 0), local b = (size.x*0.5*scale.x, 0)
        # rotated:
        ax = pos[0] - hx * cos_r
        ay = pos[1] - hx * sin_r
        bx = pos[0] + hx * cos_r
        by = pos[1] + hx * sin_r
        
        thickness = abs(size[1] * scale[1]) * 0.5
        ay -= thickness
        by -= thickness
        
        platforms.append({
            "name": name,
            "pos": pos,
            "rot": rot,
            "scale": scale,
            "size": size,
            "one_way": one_way,
            "seg": ((ax, ay), (bx, by)),
            "x_range": (min(ax, bx), max(ax, bx)),
            "y_range": (min(ay, by), max(ay, by))
        })
        
    return platforms

if __name__ == "__main__":
    for p in parse_platforms("descent/assets/scenes/levels/map_01_fire_vertical.tscn"):
        print(f"{p['name']:12s} | one_way={str(p['one_way']):5s} | x:[{p['x_range'][0]:6.1f}, {p['x_range'][1]:6.1f}] | y:[{p['seg'][0][1]:6.1f} -> {p['seg'][1][1]:6.1f}] | rot={p['rot']:.3f}")
