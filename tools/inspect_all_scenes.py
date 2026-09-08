import re
from pathlib import Path

levels_dir = Path("descent/assets/scenes/levels")
scenes = sorted(levels_dir.glob("*.tscn"))

for scene in scenes:
    text = scene.read_text(encoding="utf-8")
    # find kind
    kind_match = re.search(r'kind\s*=\s*(\d+)', text)
    kind = kind_match.group(1) if kind_match else "0"
    
    # count platforms
    platforms = re.findall(r'\[node name="Platform[^"]*" type="StaticBody2D" parent="Platforms"', text)
    
    # check if has WalkableRegion with CollisionShape2D
    walkable_shapes = re.findall(r'parent="WalkableRegion"', text)
    
    print(f"{scene.name:45s} | kind={kind} | platforms={len(platforms):2d} | walkable={len(walkable_shapes)}")
