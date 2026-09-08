import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_analysis import analyse, MAPS_DIR
from gen_levels import plan

for num in ["10", "12", "18", "30", "40", "41"]:
    matches = list(MAPS_DIR.glob(f"map_{num}_*vertical.png"))
    if not matches:
        continue
    p = matches[0]
    info = analyse(p)
    lvl = plan(info)
    print(f"{p.name:45s} | ledges: {len(info.ledges):2d} | platforms: {len(lvl.platforms):2d} | pit: {info.pit_top}")
