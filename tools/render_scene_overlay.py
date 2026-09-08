import sys
from pathlib import Path
import math
import re
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_platforms import parse_platforms

MAPS_DIR = Path("descent/assets/maps")
SCENES_DIR = Path("descent/assets/scenes/levels")
OUT_DIR = Path("tools/_scene_debug")
OUT_DIR.mkdir(parents=True, exist_ok=True)

GREEN = (80, 255, 130, 200)
CYAN = (90, 200, 255, 200)
YELLOW = (255, 240, 90, 255)

def render_scene(map_name: str):
    scene_path = SCENES_DIR / f"{map_name}.tscn"
    img_path = MAPS_DIR / f"{map_name}.png"
    if not scene_path.exists() or not img_path.exists():
        print(f"Skipping {map_name}: file missing")
        return

    img = Image.open(img_path).convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Read platforms
    platforms = parse_platforms(scene_path)
    for p in platforms:
        # p has 'pos', 'rot', 'size', 'one_way', 'seg'
        p0 = p['seg'][0]
        p1 = p['seg'][1]
        color = CYAN if p['one_way'] else GREEN
        draw.line([p0, p1], fill=color, width=3)
        # Draw platform thickness (box)
        cx, cy = p['pos']
        w, h = p['size']
        rot = p['rot']
        # 4 corners in local space: (-w/2, -h/2), (w/2, -h/2), (w/2, h/2), (-w/2, h/2)
        # Note top surface is at -h/2
        cos_r = math.cos(rot)
        sin_r = math.sin(rot)
        local_pts = [
            (-w * 0.5, -h * 0.5),
            (w * 0.5, -h * 0.5),
            (w * 0.5, h * 0.5),
            (-w * 0.5, h * 0.5),
        ]
        world_pts = []
        for lx, ly in local_pts:
            wx = cx + lx * cos_r - ly * sin_r
            wy = cy + lx * sin_r + ly * cos_r
            world_pts.append((wx, wy))
        fill_color = (*color[:3], 60)
        draw.polygon(world_pts, fill=fill_color, outline=color)

    # Read PlayerStart
    text = scene_path.read_text(encoding="utf-8")
    sm = re.search(r'\[node name="PlayerStart"[^\]]*\]\s*position = Vector2\(([^,]+),\s*([^)]+)\)', text)
    if sm:
        sx, sy = float(sm.group(1)), float(sm.group(2))
        draw.ellipse([sx - 6, sy - 6, sx + 6, sy + 6], fill=YELLOW, outline=(0, 0, 0, 255), width=2)

    # Composite
    out_img = Image.alpha_composite(img, overlay)
    out_path = OUT_DIR / f"{map_name}_debug.png"
    out_img.save(out_path)
    print(f"Saved debug overlay to {out_path}")

if __name__ == "__main__":
    maps_to_test = [
        "map_01_fire_vertical",
        "map_03_fire_magma_chasm_vertical",
        "map_07_ice_cavern_vertical",
        "map_13_poison_toxic_sewer_vertical",
        "map_21_water_aqueduct_chasm_vertical",
        "map_25_crystal_amethyst_geode_vertical",
        "map_33_nature_ancient_hollow_vertical",
    ]
    for m in maps_to_test:
        render_scene(m)
