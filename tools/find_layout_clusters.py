from PIL import Image
import numpy as np
from pathlib import Path

maps = sorted(Path("descent/assets/maps").glob("*_vertical.png"))
thumbs = {}
for m in maps:
    thumbs[m.stem] = np.array(Image.open(m).convert("L").resize((64, 64)), dtype=float)

# Compare each map against map_01, map_03, map_05
for base_name in ["map_01_fire_vertical", "map_03_fire_magma_chasm_vertical", "map_05_fire_catacombs_vertical"]:
    print(f"\n--- Maps similar to {base_name} ---")
    base = thumbs[base_name]
    for name, thumb in thumbs.items():
        diff = np.mean(np.abs(base - thumb))
        if diff < 30.0:
            print(f"  {name:45s}: diff={diff:.2f}")
