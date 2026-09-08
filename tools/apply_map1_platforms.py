import re
import math
from pathlib import Path

def compute_platform(x0, y0, x1, y1, one_way=False, group="", depth=16.0):
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

# Precise platform specification for Map 1:
map1_spec = [
    # --- UPPER TIER ---
    # Left stone ledge:
    {"name": "Platform_UpperLeftStone", "pts": (67, 436, 740, 436), "one_way": False, "group": ""},
    # Upper rope bridge (smooth catenary sag from 436 to 455):
    {"name": "Platform_UpperBridge1", "pts": (740, 436, 800, 440), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge2", "pts": (800, 440, 860, 446), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge3", "pts": (860, 446, 920, 452), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge4", "pts": (920, 452, 980, 455), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge5", "pts": (980, 455, 1040, 451), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge6", "pts": (1040, 451, 1090, 444), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperBridge7", "pts": (1090, 444, 1140, 436), "one_way": True, "group": "upper_bridge"},
    # Upper stairs to right ledge:
    {"name": "Platform_UpperStairs1", "pts": (1140, 436, 1180, 412), "one_way": True, "group": "upper_bridge"},
    {"name": "Platform_UpperStairs2", "pts": (1180, 412, 1220, 392), "one_way": True, "group": "upper_bridge"},
    # Right stone ledge:
    {"name": "Platform_UpperRightStone", "pts": (1220, 392, 1468, 392), "one_way": False, "group": ""},

    # --- MID TIER FLOATING STONES ---
    {"name": "Platform_MidFloat1", "pts": (865, 664, 957, 664), "one_way": True, "group": ""},
    {"name": "Platform_MidFloat2", "pts": (905, 587, 997, 587), "one_way": True, "group": ""},
    {"name": "Platform_MidFloat3", "pts": (970, 522, 1058, 522), "one_way": True, "group": ""},

    # --- LOWER TIER ---
    {"name": "Platform_LowerLeftStoneA", "pts": (67, 781, 565, 781), "one_way": False, "group": ""},
    {"name": "Platform_LowerStep1", "pts": (565, 879, 630, 879), "one_way": True, "group": ""},
    {"name": "Platform_LowerStep2", "pts": (643, 822, 710, 822), "one_way": True, "group": ""},
    {"name": "Platform_LowerLeftStoneB", "pts": (710, 781, 865, 781), "one_way": False, "group": ""},
    # Lower suspension bridge (sag from 781 down to 806 and up to 776):
    {"name": "Platform_LowerBridge1", "pts": (865, 781, 920, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge2", "pts": (920, 792, 975, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge3", "pts": (975, 802, 1030, 806), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge4", "pts": (1030, 806, 1085, 802), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge5", "pts": (1085, 802, 1140, 792), "one_way": True, "group": "lower_bridge"},
    {"name": "Platform_LowerBridge6", "pts": (1140, 792, 1175, 776), "one_way": True, "group": "lower_bridge"},
    # Lower right stone:
    {"name": "Platform_LowerRightStone", "pts": (1175, 776, 1468, 776), "one_way": False, "group": ""},
]

def build_scene_platforms(tscn_path: Path, platform_specs: list[dict]):
    content = tscn_path.read_text(encoding="utf-8")
    
    # 1. Generate SubResources and Nodes for each platform
    subres_lines = []
    node_lines = []
    
    # Generate unique IDs for subresources and nodes
    import random
    rng = random.Random(42)  # deterministic
    
    for i, spec in enumerate(platform_specs):
        x0, y0, x1, y1 = spec["pts"]
        one_way = spec.get("one_way", False)
        group = spec.get("group", "")
        depth = spec.get("depth", 16.0)
        p = compute_platform(x0, y0, x1, y1, one_way, group, depth)
        
        subres_id = f"SubResource_plat_{i}"
        plat_node_id = rng.randint(100000000, 2147483647)
        shape_node_id = rng.randint(100000000, 2147483647)
        
        # SubResource
        subres_lines.append(f'[sub_resource type="RectangleShape2D" id="{subres_id}"]')
        subres_lines.append(f'size = Vector2({p["size"][0]}, {p["size"][1]})\n')
        
        # Platform node
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
shape = SubResource("{subres_id}"){f"\none_way_collision = true" if one_way else ""}
'''
        node_lines.append(node_block)

    # Replace existing platform subresources and platform nodes in tscn
    # First find all platform SubResources:
    # They are RectangleShape2D associated with Platforms/Platform...
    # Let's inspect where SubResources end and Nodes start
    node_start = re.search(r'\n\[node name="', content).start()
    headers_and_subres = content[:node_start]
    nodes_section = content[node_start:]
    
    # In headers_and_subres, remove old platform subresources
    # We can identify them or keep existing non-platform subresources
    # Let's see: non-platform subresources are Shape_wall_v, Shape_wall_h, RectangleShape2D_iobpx (pit), etc.
    # Actually, simpler: replace everything under [node name="Platforms"...] until the next top-level node [node name="Hazards"...]
    
    # First, let's keep only non-platform SubResources
    # In map_01, what non-platform subresources exist?
    # Shape_wall_v, Shape_wall_h, RectangleShape2D_iobpx (Pit)
    non_platform_subres = []
    current_sub = []
    for line in headers_and_subres.splitlines(keepends=True):
        if line.startswith('[sub_resource'):
            if current_sub:
                block = "".join(current_sub)
                if 'id="Shape_wall' in block or 'id="RectangleShape2D_iobpx' in block or 'id="Shape_walkable' in block:
                    non_platform_subres.append(block)
                current_sub = [line]
            else:
                current_sub = [line]
        elif current_sub:
            current_sub.append(line)
        else:
            non_platform_subres.append(line)
    if current_sub:
        block = "".join(current_sub)
        if 'id="Shape_wall' in block or 'id="RectangleShape2D_iobpx' in block or 'id="Shape_walkable' in block:
            non_platform_subres.append(block)
            
    new_header = "".join(non_platform_subres).rstrip() + "\n\n" + "\n".join(subres_lines) + "\n"
    
    # In nodes_section, replace the Platforms subtree
    # The Platforms subtree starts right after [node name="Platforms" type="Node2D" parent="." ...]
    # and ends right before [node name="Hazards" type="Node2D" parent="." ...]
    plat_match = re.search(r'(\[node name="Platforms" type="Node2D" parent="\."[^\]]*\]\n)', nodes_section)
    hazards_match = re.search(r'(\[node name="Hazards" type="Node2D" parent="\."[^\]]*\])', nodes_section)
    
    before_plats = nodes_section[:plat_match.end()]
    after_plats = nodes_section[hazards_match.start():]
    
    new_nodes = before_plats + "\n" + "\n".join(node_lines) + "\n" + after_plats
    
    # Count ext_resources and sub_resources for load_steps
    ext_count = len(re.findall(r'\[ext_resource', new_header))
    sub_count = len(re.findall(r'\[sub_resource', new_header))
    load_steps = ext_count + sub_count + 1
    
    new_header = re.sub(r'load_steps=\d+', f'load_steps={load_steps}', new_header)
    
    new_content = new_header + "\n" + new_nodes
    tscn_path.write_text(new_content, encoding="utf-8")
    print(f"Successfully rebuilt platforms for {tscn_path.name}: {len(platform_specs)} platforms, {load_steps} load_steps.")

build_scene_platforms(Path("descent/assets/scenes/levels/map_01_fire_vertical.tscn"), map1_spec)
