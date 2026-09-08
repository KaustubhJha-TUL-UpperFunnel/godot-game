import sys
from pathlib import Path
import re
import math
import random

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_analysis import analyse, MAPS_DIR
from gen_levels import plan
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")

def compute_platform_dict(x0, y0, x1, y1, one_way=False, group="", depth=16.0):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy)
    rot = math.atan2(dy, dx)
    
    mx = (x0 + x1) * 0.5
    my = (y0 + y1) * 0.5
    
    half_d = depth * 0.5
    pos_x = mx - half_d * math.sin(rot)
    pos_y = my + half_d * math.cos(rot)
    
    return {
        "pos": (round(pos_x, 3), round(pos_y, 3)),
        "rot": round(rot, 6),
        "size": (round(length, 2), round(depth, 1)),
        "one_way": one_way,
        "group": group
    }

def update_scene_platforms(tscn_path: Path, platform_specs: list[dict]):
    content = tscn_path.read_text(encoding="utf-8")
    
    # 1. Split into header/resources and nodes
    node_start = re.search(r'\n\[node name="', content).start()
    headers_and_subres = content[:node_start]
    nodes_section = content[node_start:]
    
    # Identify the platform nodes section:
    plat_match = re.search(r'(\[node name="Platforms" type="Node2D" parent="\."[^\]]*\]\n)', nodes_section)
    hazards_match = re.search(r'(\[node name="Hazards" type="Node2D" parent="\."[^\]]*\])', nodes_section)
    
    before_plats = nodes_section[:plat_match.end()]
    after_plats = nodes_section[hazards_match.start():]
    
    # Find all subresources used OUTSIDE Platforms in nodes_section
    non_platform_nodes_text = before_plats + after_plats
    used_subres_ids = set(re.findall(r'SubResource\("([^"]+)"\)', non_platform_nodes_text))
    
    # Parse existing resources in headers_and_subres
    has_platform_script = 'path="res://descent/scripts/world/level_platform.gd"' in headers_and_subres
    
    ext_resources = []
    kept_subresources = []
    
    # headers_and_subres starts with [gd_scene ...]\n
    gd_scene_header = re.match(r'(\[gd_scene[^\]]*\]\n*)', headers_and_subres).group(1)
    rest_headers = headers_and_subres[len(gd_scene_header):]
    
    # Split by [ext_resource or [sub_resource
    res_blocks = re.split(r'(?=\[(?:ext_resource|sub_resource))', rest_headers)
    for block in res_blocks:
        block = block.strip()
        if not block:
            continue
        if block.startswith('[ext_resource'):
            ext_resources.append(block)
        elif block.startswith('[sub_resource'):
            m = re.search(r'id="([^"]+)"', block)
            if m and m.group(1) in used_subres_ids:
                kept_subresources.append(block)
                
    if not has_platform_script:
        ext_resources.append('[ext_resource type="Script" uid="uid://c53knd5g2a6g3" path="res://descent/scripts/world/level_platform.gd" id="3_platform"]')
        
    # Generate new platform subresources and node blocks
    subres_lines = []
    node_lines = []
    rng = random.Random(abs(hash(tscn_path.name)) % 1000000007)
    
    for i, spec in enumerate(platform_specs):
        x0, y0, x1, y1 = spec["pts"]
        one_way = spec.get("one_way", False)
        group = spec.get("group", "")
        depth = spec.get("depth", 16.0)
        p = compute_platform_dict(x0, y0, x1, y1, one_way, group, depth)
        
        subres_id = f"SubResource_plat_{i}"
        plat_node_id = rng.randint(100000000, 2147483647)
        shape_node_id = rng.randint(100000000, 2147483647)
        
        subres_lines.append(f'[sub_resource type="RectangleShape2D" id="{subres_id}"]\nsize = Vector2({p["size"][0]}, {p["size"][1]})')
        
        rot_str = f'\nrotation = {p["rot"]}' if abs(p["rot"]) > 0.0001 else ""
        one_way_str = '\none_way = true' if one_way else ""
        group_str = f'\ntraversal_group = &"{group}"' if group else ""
        
        node_block = f'''[node name="{spec["name"]}" type="StaticBody2D" parent="Platforms" unique_id={plat_node_id}]
position = Vector2({p["pos"][0]}, {p["pos"][1]}){rot_str}
collision_layer = 4
collision_mask = 0
script = ExtResource("3_platform"){one_way_str}{group_str}
size = Vector2({p["size"][0]}, {p["size"][1]})

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platforms/{spec["name"]}" unique_id={shape_node_id}]
shape = SubResource("{subres_id}"){f"\none_way_collision = true" if one_way else ""}'''
        node_lines.append(node_block)
        
    all_subresources = kept_subresources + subres_lines
    load_steps = len(ext_resources) + len(all_subresources) + 1
    
    new_gd_scene = re.sub(r'load_steps=\d+', f'load_steps={load_steps}', gd_scene_header)
    
    new_file_text = (
        new_gd_scene.rstrip() + "\n\n" +
        "\n\n".join(ext_resources) + "\n\n" +
        "\n\n".join(all_subresources) + "\n\n" +
        before_plats + "\n" +
        "\n\n".join(node_lines) + "\n\n" +
        after_plats
    )
    tscn_path.write_text(new_file_text, encoding="utf-8")
    print(f"Updated {tscn_path.name}: {len(platform_specs)} platforms, load_steps={load_steps}")

print("Platform updater ready.")
