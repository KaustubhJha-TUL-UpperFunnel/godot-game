import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

LEVELS_DIR = Path("descent/assets/scenes/levels")
MAPS_DIR = Path("descent/assets/maps")
OUT_DIR = Path("tools/_debug_actual")
OUT_DIR.mkdir(parents=True, exist_ok=True)

vertical_scenes = sorted(LEVELS_DIR.glob("*_vertical.tscn"))

for scene_path in vertical_scenes:
    map_name = scene_path.stem + ".png"
    map_img_path = MAPS_DIR / map_name
    if not map_img_path.exists():
        continue
        
    img = Image.open(map_img_path).convert("RGBA")
    draw = ImageDraw.Draw(img)
    
    platforms = parse_platforms(scene_path)
    for p in platforms:
        (ax, ay), (bx, by) = p["seg"]
        color = (255, 200, 50, 255) if p["one_way"] else (50, 255, 100, 255)
        draw.line([(ax, ay), (bx, by)], fill=color, width=3)
        draw.ellipse([ax-3, ay-3, ax+3, ay+3], fill=(255, 255, 0, 255))
        draw.ellipse([bx-3, by-3, bx+3, by+3], fill=(255, 0, 255, 255))
        # Draw text label
        draw.text(((ax+bx)*0.5, min(ay, by) - 12), p["name"], fill=(255, 255, 255, 255))
        
    out_file = OUT_DIR / f"{scene_path.stem}_actual.png"
    img.save(out_file)

print(f"Generated debug overlay for {len(vertical_scenes)} vertical maps in tools/_debug_actual/")
