import re
from pathlib import Path

levels_dir = Path("descent/assets/scenes/levels")
maps_dir = Path("descent/assets/maps")

for scene_path in sorted(levels_dir.glob("*.tscn")):
    text = scene_path.read_text(encoding="utf-8")
    
    # Check if vertical
    is_vertical = 'kind = 1' in text or 'kind=1' in text
    
    # Check platforms
    platforms = re.findall(r'\[node name="(Platform\w*)" type="StaticBody2D" parent="Platforms"', text)
    
    # Check if any platforms have rotation
    has_rotation = bool(re.search(r'\[node name="Platform[^"]*".*?rotation\s*=', text, re.DOTALL))
    
    # Check if any platforms have scale
    has_scale = bool(re.search(r'\[node name="Platform[^"]*".*?scale\s*=', text, re.DOTALL))
    
    # Check if reviewed
    reviewed = "reviewed = true" in text
    
    print(f"{scene_path.stem:40s} | vert={str(is_vertical):5s} | plats={len(platforms):2d} | rot={str(has_rotation):5s} | rev={str(reviewed):5s}")
