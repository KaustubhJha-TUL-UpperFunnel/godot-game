from PIL import Image
import numpy as np
from pathlib import Path

MAPS_DIR = Path("descent/assets/maps")
map_files = sorted(MAPS_DIR.glob("*_vertical.png"))

# Preload grayscale downscaled thumbnails (153x102)
thumbs = {}
for mf in map_files:
    img = Image.open(mf).convert("L").resize((153, 102))
    thumbs[mf.stem] = np.array(img, dtype=np.float32)

names = list(thumbs.keys())
n = len(names)

# Compute pairwise differences
diff_matrix = np.zeros((n, n))
for i in range(n):
    for j in range(i + 1, n):
        d = np.mean(np.abs(thumbs[names[i]] - thumbs[names[j]]))
        diff_matrix[i, j] = d
        diff_matrix[j, i] = d

# Find clusters with threshold < 15.0 (very similar structure)
visited = set()
clusters = []
for i in range(n):
    if names[i] in visited:
        continue
    cluster = [names[i]]
    visited.add(names[i])
    for j in range(i + 1, n):
        if names[j] not in visited and diff_matrix[i, j] < 15.0:
            cluster.append(names[j])
            visited.add(names[j])
    clusters.append(cluster)

print(f"Total vertical maps: {n}")
print(f"Found {len(clusters)} clusters:")
for idx, cl in enumerate(clusters, 1):
    print(f"\n--- Cluster {idx} ({len(cl)} maps) ---")
    for name in cl:
        print(f"  {name}")
