"""Throwaway probe: find the checkerboard period and tones from a known-empty row."""

import sys

import numpy as np
from PIL import Image

for path in sys.argv[1:]:
    gray = np.asarray(Image.open(path).convert("L"), dtype=int)
    print(f"\n=== {path}  {gray.shape}")

    histogram = np.bincount(gray.ravel(), minlength=256)
    peaks = np.argsort(histogram)[::-1][:12]
    print(f"  top gray values: {sorted(int(p) for p in peaks)}")

    row = gray[8]
    print(f"  row 8 first 80: {row[:80].tolist()}")

    # Transition positions along a row that should be pure background.
    binary = row > 110
    edges = np.nonzero(np.diff(binary.astype(int)))[0] + 1
    print(f"  row 8 transitions: {edges[:20].tolist()} ... count={edges.size}")
    if edges.size > 1:
        print(f"  transition spacing: {np.diff(edges)[:20].tolist()}")

    column = gray[:, 8]
    binary_col = column > 110
    edges_col = np.nonzero(np.diff(binary_col.astype(int)))[0] + 1
    print(f"  col 8 transitions: {edges_col[:20].tolist()} ... count={edges_col.size}")
