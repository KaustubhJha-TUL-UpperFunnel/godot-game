import glob
from pathlib import Path

maps = sorted(Path("descent/assets/maps").glob("*.png"))
print(f"Total maps in descent/assets/maps: {len(maps)}")

vertical_maps = [m.name for m in maps if "vertical" in m.name]
flat_maps = [m.name for m in maps if "flat" in m.name]
other_maps = [m.name for m in maps if "vertical" not in m.name and "flat" not in m.name]

print(f"Vertical maps ({len(vertical_maps)}):")
for m in vertical_maps:
    print(" ", m)

print(f"\nFlat maps ({len(flat_maps)}):")
for m in flat_maps:
    print(" ", m)

if other_maps:
    print(f"\nOther maps ({len(other_maps)}):")
    for m in other_maps:
        print(" ", m)
