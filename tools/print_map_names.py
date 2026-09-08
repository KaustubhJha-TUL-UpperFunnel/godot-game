from pathlib import Path

maps = sorted(Path("descent/assets/maps").glob("*.png"))
for m in maps:
    print(m.name)
