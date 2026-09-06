"""Reads a map PNG and works out where the geometry is.

The art is consistent enough to mine: every room is a stone frame around a
lit interior, vertical rooms stack lit horizontal ledges over a bottomless
pit, and every hazard (lava, sludge, arcane) is far more saturated than the
stone around it.

Nothing here is exact. gen_levels.py turns the output into editable nodes and
the numbers get corrected by hand in the editor.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MAPS_DIR = PROJECT_ROOT / "descent" / "assets" / "maps"

# --- Tunables ----------------------------------------------------------------

# A ledge reads as a lit horizontal strip brighter than both the wall behind it
# and its own shadowed front face, so we look for horizontal brightness ridges.
LEDGE_RIDGE_SPAN = 20  # px compared above and below the candidate surface
LEDGE_RIDGE_PERCENTILE = 96.5  # adaptive cut, art is very dark overall
LEDGE_RIDGE_FLOOR = 0.022  # absolute minimum ridge contrast
LEDGE_MIN_LUM_PERCENTILE = 62.0  # a ledge is never one of the darkest pixels
LEDGE_MIN_RUN = 58  # px; shorter runs are railings, rubble, or props
LEDGE_ROW_MERGE = 22  # px; surfaces this close vertically are one ledge
LEDGE_MIN_COVERAGE = 0.020  # fraction of width that must qualify on a row
LEDGE_FLATNESS_BAND = 6  # px; a standable surface is flat, an arch crown is not
LEDGE_TOP_MARGIN = 0.12  # skip the ceiling; nothing is standable up there
LEDGE_MAX_COUNT = 22

# Hazard pools read as saturated colour, and are among the brightest things in
# the room. Both cuts are adaptive because a lava room and a crypt sit whole
# stops apart in exposure.
HAZARD_MIN_SAT = 0.50
HAZARD_LUM_PERCENTILE = 92.0
HAZARD_MIN_LUM = 0.18
HAZARD_CELL = 20  # px grid the pool shapes are quantised to
HAZARD_MIN_CELLS = 8  # drops torches, embers, and glowing runes
HAZARD_MIN_AREA = 3000

FRAME_SOLID_LUM = 0.11  # the outer stone border vs the black vignette


@dataclass
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def cx(self) -> float:
        return self.x + self.w * 0.5

    @property
    def cy(self) -> float:
        return self.y + self.h * 0.5

    @property
    def bottom(self) -> int:
        return self.y + self.h

    @property
    def right(self) -> int:
        return self.x + self.w


@dataclass
class Ledge:
    y: int
    x0: int
    x1: int
    thickness: int

    @property
    def width(self) -> int:
        return self.x1 - self.x0

    @property
    def cx(self) -> float:
        return (self.x0 + self.x1) * 0.5


@dataclass
class MapAnalysis:
    name: str
    size: tuple[int, int]
    orientation: str
    theme: str
    descriptor: str
    interior: Rect
    ledges: list[Ledge] = field(default_factory=list)
    hazards: list[Rect] = field(default_factory=list)
    pit_top: int | None = None
    hazard_kind: str = "LAVA"


# --- Theme table -------------------------------------------------------------

# Which hazard the pools in a themed room represent, and the name the level
# scene reports. Keyed by the theme token in the filename.
THEME_HAZARD = {
    "fire": "LAVA",
    "ice": "FROST",
    "poison": "POISON",
    "water": "DROWNING",
    "crystal": "ARCANE",
    "nature": "THORNS",
    "shadow": "VOID",
    "gold": "MOLTEN_GOLD",
    "clockwork": "MACHINERY",
    "electric": "SHOCK",
}

# map_01_fire_vertical has no descriptor; map_02_fire_forge_flat does.
NAME_RE = re.compile(r"^map_(\d+)_([a-z]+)(?:_(.+?))?_(vertical|flat)$")


def parse_name(stem: str) -> tuple[int, str, str, str]:
    match = NAME_RE.match(stem)
    if match is None:
        raise ValueError(f"unexpected map filename: {stem}")
    index, theme, descriptor, orientation = match.groups()
    return int(index), theme, descriptor or theme, orientation


# --- Pixel helpers -----------------------------------------------------------


def _load(path: Path) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return rgb, lum, sat


def _box_blur(arr: np.ndarray, radius: int) -> np.ndarray:
    """Separable box blur via cumulative sums, edges clamped."""
    if radius <= 0:
        return arr
    out = arr.astype(np.float32)
    for axis in (0, 1):
        padded = np.concatenate(
            [
                np.repeat(out.take([0], axis=axis), radius, axis=axis),
                out,
                np.repeat(out.take([-1], axis=axis), radius, axis=axis),
            ],
            axis=axis,
        )
        cumulative = np.cumsum(padded, axis=axis)
        zeros = np.zeros_like(cumulative.take([0], axis=axis))
        cumulative = np.concatenate([zeros, cumulative], axis=axis)
        width = radius * 2 + 1
        size = out.shape[axis]
        upper = cumulative.take(range(width, width + size), axis=axis)
        lower = cumulative.take(range(0, size), axis=axis)
        out = (upper - lower) / float(width)
    return out


def _runs(mask_row: np.ndarray, min_len: int, max_gap: int = 26) -> list[tuple[int, int]]:
    """Contiguous True spans, bridging small gaps (railing posts, cracks)."""
    idx = np.flatnonzero(mask_row)
    if idx.size == 0:
        return []
    spans: list[list[int]] = [[int(idx[0]), int(idx[0])]]
    for i in idx[1:]:
        if i - spans[-1][1] <= max_gap:
            spans[-1][1] = int(i)
        else:
            spans.append([int(i), int(i)])
    return [(a, b + 1) for a, b in spans if b + 1 - a >= min_len]


def _components(mask: np.ndarray) -> list[Rect]:
    """Bounding boxes of 4-connected True regions.

    Row runs are unioned against the runs they touch on the previous row, which
    keeps this to a few thousand Python steps instead of a million.
    """
    height = mask.shape[0]
    parent: list[int] = []

    def find(node: int) -> int:
        while parent[node] != node:
            parent[node] = parent[parent[node]]
            node = parent[node]
        return node

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    runs: list[tuple[int, int, int]] = []  # (y, x0, x1) half-open
    row_runs: list[list[int]] = []
    for y in range(height):
        current: list[int] = []
        for x0, x1 in _runs(mask[y], 1, max_gap=1):
            index = len(runs)
            runs.append((y, x0, x1))
            parent.append(index)
            current.append(index)
            for previous in row_runs[-1] if row_runs else []:
                _, px0, px1 = runs[previous]
                if px0 < x1 and x0 < px1:
                    union(index, previous)
        row_runs.append(current)

    grouped: dict[int, list[int]] = {}
    for index in range(len(runs)):
        grouped.setdefault(find(index), []).append(index)

    out: list[Rect] = []
    for members in grouped.values():
        xs0 = min(runs[i][1] for i in members)
        xs1 = max(runs[i][2] for i in members)
        ys0 = min(runs[i][0] for i in members)
        ys1 = max(runs[i][0] for i in members)
        rect = Rect(xs0, ys0, xs1 - xs0, ys1 - ys0 + 1)
        rect.area = sum(runs[i][2] - runs[i][1] for i in members)  # type: ignore[attr-defined]
        out.append(rect)
    return out


# --- Interior frame ----------------------------------------------------------


def find_interior(lum: np.ndarray) -> Rect:
    """The playable box inside the outer stone frame and black vignette."""
    h, w = lum.shape
    solid = lum > FRAME_SOLID_LUM
    col_cover = solid.mean(axis=0)
    row_cover = solid.mean(axis=1)

    def first_above(profile: np.ndarray, threshold: float) -> int:
        hits = np.flatnonzero(profile > threshold)
        return int(hits[0]) if hits.size else 0

    def last_above(profile: np.ndarray, threshold: float) -> int:
        hits = np.flatnonzero(profile > threshold)
        return int(hits[-1]) if hits.size else len(profile) - 1

    left = first_above(col_cover, 0.10)
    right = last_above(col_cover, 0.10)
    top = first_above(row_cover, 0.10)
    bottom = last_above(row_cover, 0.10)

    # Step inward past the frame masonry itself.
    inset_x = max(int(w * 0.045), 1)
    inset_y = max(int(h * 0.05), 1)
    x0 = min(left + inset_x, w // 3)
    x1 = max(right - inset_x, w * 2 // 3)
    y0 = min(top + inset_y, h // 3)
    y1 = max(bottom - inset_y, h * 2 // 3)
    return Rect(x0, y0, x1 - x0, y1 - y0)


# --- Ledges ------------------------------------------------------------------


def ledge_ridge(lum: np.ndarray, interior: Rect, hazard_mask: np.ndarray) -> np.ndarray:
    """Mask of pixels that look like the lit top face of a standable surface."""
    smooth = _box_blur(lum, 2)
    span = LEDGE_RIDGE_SPAN
    above = np.roll(smooth, span, axis=0)
    above[:span, :] = 1.0
    below = np.roll(smooth, -span, axis=0)
    below[-span:, :] = 1.0

    ridge = smooth - np.maximum(above, below)
    inside = ridge[interior.y : interior.bottom, interior.x : interior.right]
    cut = max(float(np.percentile(inside, LEDGE_RIDGE_PERCENTILE)), LEDGE_RIDGE_FLOOR)
    lit = float(np.percentile(smooth[interior.y : interior.bottom], LEDGE_MIN_LUM_PERCENTILE))

    mask = (ridge > cut) & (smooth > lit) & ~hazard_mask
    mask[: int(interior.y + interior.h * LEDGE_TOP_MARGIN), :] = False
    mask[interior.bottom :, :] = False
    mask[:, : interior.x] = False
    mask[:, interior.right :] = False
    return mask


def find_ledges(lum: np.ndarray, interior: Rect, hazard_mask: np.ndarray) -> list[Ledge]:
    surface = ledge_ridge(lum, interior, hazard_mask)
    smooth = _box_blur(lum, 2)

    coverage = surface.mean(axis=1)
    candidate_rows = np.flatnonzero(coverage > LEDGE_MIN_COVERAGE)
    if candidate_rows.size == 0:
        return []

    # Group nearby rows and keep the strongest row of each group.
    groups: list[list[int]] = [[int(candidate_rows[0])]]
    for row in candidate_rows[1:]:
        if row - groups[-1][-1] <= LEDGE_ROW_MERGE:
            groups[-1].append(int(row))
        else:
            groups.append([int(row)])

    ledges: list[Ledge] = []
    for group in groups:
        best = max(group, key=lambda r: coverage[r])
        # Union only a thin band around the peak row, so a run has to be level to
        # survive. Widening this lets curved arch crowns pass as floors.
        low = max(best - LEDGE_FLATNESS_BAND, 0)
        high = min(best + LEDGE_FLATNESS_BAND + 1, surface.shape[0])
        band = surface[low:high].any(axis=0)
        for x0, x1 in _runs(band, LEDGE_MIN_RUN):
            ledges.append(Ledge(best, x0, x1, _thickness(smooth, best, x0, x1)))

    ledges.sort(key=lambda item: -item.width)
    ledges = _dedupe_ledges(ledges)
    return sorted(ledges[:LEDGE_MAX_COUNT], key=lambda item: (item.y, item.x0))


def _dedupe_ledges(ledges: list[Ledge], y_tolerance: int = 90) -> list[Ledge]:
    """Drop surfaces that restate a wider one just above or below.

    The ridge filter often fires on both the lit top face and the cornice under
    the ledge's front lip; only the upper of the pair can be stood on. The
    tolerance is deliberately loose — two genuinely stackable floors are always
    further apart than this, or you could not fit between them.
    """
    kept: list[Ledge] = []
    for candidate in ledges:  # widest first, so survivors win
        redundant = False
        for existing in kept:
            overlap = min(candidate.x1, existing.x1) - max(candidate.x0, existing.x0)
            if overlap <= 0:
                continue
            shared = overlap / float(min(candidate.width, existing.width))
            if shared > 0.55 and abs(candidate.y - existing.y) <= y_tolerance:
                redundant = True
                break
        if not redundant:
            kept.append(candidate)
    return kept


def _thickness(smooth: np.ndarray, y: int, x0: int, x1: int) -> int:
    """How far the lit stone continues below the surface row."""
    height = smooth.shape[0]
    column = smooth[y : min(height, y + 160), x0:x1].mean(axis=1)
    if column.size == 0:
        return 18
    cut = float(column[:6].mean()) * 0.55
    depth = 0
    for value in column:
        if value < cut:
            break
        depth += 1
    return int(np.clip(depth, 16, 120))


# --- Hazards and the pit -----------------------------------------------------


def hazard_mask(lum: np.ndarray, sat: np.ndarray, interior: Rect) -> np.ndarray:
    """Pixels belonging to the molten/toxic/arcane core of a hazard pool.

    Opening the mask is what keeps a torch's glow from fusing into the lava it
    hangs above, which otherwise swallows the whole room in one rectangle.
    """
    inside = lum[interior.y : interior.bottom, interior.x : interior.right]
    cut = max(float(np.percentile(inside, HAZARD_LUM_PERCENTILE)), HAZARD_MIN_LUM)
    mask = (sat > HAZARD_MIN_SAT) & (lum > cut)
    mask[: interior.y, :] = False
    mask[interior.bottom :, :] = False
    mask[:, : interior.x] = False
    mask[:, interior.right :] = False
    return _open(mask, 3)


def find_hazards(mask: np.ndarray) -> list[Rect]:
    """Hazard pools as editable rectangles, biggest pools first.

    A lava channel is narrow and long, so only total area is screened here;
    rect_cover has already enforced a sensible minimum cell count.
    """
    rects = rect_cover(
        mask,
        cell=HAZARD_CELL,
        min_fill=0.32,
        min_cells=HAZARD_MIN_CELLS,
        limit=16,
    )
    keep = [rect for rect in rects if rect.w * rect.h >= HAZARD_MIN_AREA]
    return sorted(keep, key=lambda r: -(r.w * r.h))


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    out = mask.copy()
    for shift in range(1, radius + 1):
        out |= np.roll(mask, shift, axis=0)
        out |= np.roll(mask, -shift, axis=0)
        out |= np.roll(mask, shift, axis=1)
        out |= np.roll(mask, -shift, axis=1)
    return out


def _erode(mask: np.ndarray, radius: int) -> np.ndarray:
    out = mask.copy()
    for shift in range(1, radius + 1):
        for axis in (0, 1):
            for direction in (shift, -shift):
                shifted = np.roll(mask, direction, axis=axis)
                if axis == 0:
                    if direction > 0:
                        shifted[:direction, :] = False
                    else:
                        shifted[direction:, :] = False
                else:
                    if direction > 0:
                        shifted[:, :direction] = False
                    else:
                        shifted[:, direction:] = False
                out &= shifted
    return out


def _open(mask: np.ndarray, radius: int) -> np.ndarray:
    """Erode then dilate: drops glow fringes and thin bridges between pools."""
    return _dilate(_erode(mask, radius), radius)


def rect_cover(
    mask: np.ndarray,
    cell: int,
    min_fill: float,
    min_cells: int,
    limit: int,
) -> list[Rect]:
    """Approximate a mask with a handful of axis-aligned rectangles.

    A single bounding box turns an L-shaped lava channel into the whole floor,
    so instead the mask is reduced to a coarse grid and covered greedily by the
    largest solid rectangle remaining, which is also what is pleasant to edit
    as CollisionShape2D nodes later.
    """
    height, width = mask.shape
    rows = height // cell
    cols = width // cell
    if rows == 0 or cols == 0:
        return []

    trimmed = mask[: rows * cell, : cols * cell]
    grid = trimmed.reshape(rows, cell, cols, cell).mean(axis=(1, 3)) >= min_fill

    out: list[Rect] = []
    for _ in range(limit):
        found = _largest_rect(grid)
        if found is None:
            break
        gy, gx, gh, gw = found
        if gh * gw < min_cells:
            break
        grid[gy : gy + gh, gx : gx + gw] = False
        out.append(Rect(gx * cell, gy * cell, gw * cell, gh * cell))
    return out


def _largest_rect(grid: np.ndarray) -> tuple[int, int, int, int] | None:
    """Largest all-True axis-aligned rectangle as (y, x, height, width).

    Row-by-row histogram of consecutive True cells, each row solved with the
    usual monotonic stack.
    """
    rows, cols = grid.shape
    heights = [0] * cols
    best: tuple[int, int, int, int] | None = None
    best_area = 0

    for y in range(rows):
        row = grid[y]
        for x in range(cols):
            heights[x] = heights[x] + 1 if row[x] else 0

        stack: list[tuple[int, int]] = []  # (start column, bar height)
        for x in range(cols + 1):
            bar = heights[x] if x < cols else 0
            start = x
            while stack and stack[-1][1] >= bar:
                popped_start, popped_height = stack.pop()
                area = popped_height * (x - popped_start)
                if area > best_area:
                    best_area = area
                    best = (y - popped_height + 1, popped_start, popped_height, x - popped_start)
                start = popped_start
            stack.append((start, bar))

    return best if best_area > 0 else None


PIT_HIGHEST = 0.72  # fraction down the interior; the pit never starts above this


def find_pit_top(ledges: list[Ledge], interior: Rect, content_height: int) -> int:
    """Where the killing fall begins: just under the lowest standable surface.

    Staying below the lowest ledge is what keeps the pit from swallowing a floor
    the room actually has — several rooms are closed at the bottom by a deck
    rather than a chasm, and a death zone drawn over it would kill the player
    where they are meant to be standing.

    The floor of 72% only applies when nothing was detected low down, so a
    missed deck yields a pit that is too shallow rather than one that is lethal
    in the wrong place.
    """
    if ledges:
        lowest = max(ledges, key=lambda item: item.y)
        estimate = lowest.y + lowest.thickness + 12
    else:
        estimate = interior.y + interior.h * 0.82
    floor = interior.y + interior.h * PIT_HIGHEST
    return int(min(max(estimate, floor), content_height - 24))


# --- Entry point -------------------------------------------------------------


def analyse(path: Path) -> MapAnalysis:
    _, lum, sat = _load(path)
    h, w = lum.shape
    index, theme, descriptor, orientation = parse_name(path.stem)
    interior = find_interior(lum)

    mask = hazard_mask(lum, sat, interior)
    ledges = find_ledges(lum, interior, mask) if orientation == "vertical" else []
    hazards = find_hazards(mask)

    result = MapAnalysis(
        name=path.stem,
        size=(w, h),
        orientation=orientation,
        theme=theme,
        descriptor=descriptor.replace("_", " "),
        interior=interior,
        ledges=ledges,
        hazards=hazards,
        hazard_kind=THEME_HAZARD.get(theme, "LAVA"),
    )
    if orientation == "vertical":
        result.pit_top = find_pit_top(ledges, interior, h)
    return result
