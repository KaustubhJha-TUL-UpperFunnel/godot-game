"""Generates one Level scene per map PNG.

    python tools/gen_levels.py            # all 50
    python tools/gen_levels.py map_01_fire_vertical.png

Everything written here is a starting point meant to be corrected by hand in the
editor: the platforms, hazards and death zone come out of map_analysis.py, and
the spawns and player start are derived from them. Each level
starts with `reviewed = false` so the editor shows a warning until a human has
looked at it.

Scenes are regenerated wholesale, so re-running this discards hand edits. Levels
already marked reviewed are skipped unless --force is passed.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from map_analysis import MAPS_DIR, PROJECT_ROOT, Ledge, MapAnalysis, Rect, analyse

LEVELS_DIR = PROJECT_ROOT / "descent" / "assets" / "scenes" / "levels"

SCRIPT_UID_PATHS = {
    "level": "res://descent/scripts/world/level.gd",
    "platform": "res://descent/scripts/world/level_platform.gd",
    "hazard": "res://descent/scripts/world/hazard_zone.gd",
    "death": "res://descent/scripts/world/death_zone.gd",
}

WALLS_LAYER = 4
WALL_THICKNESS = 48

# Flat levels keep the top-down clamp rect the game has always used. The art
# frames the floor with props, so the clamp sits well inside the stone frame.
FLAT_INSET_X = 0.075
FLAT_INSET_Y = 0.13

# A platform's collider is only as deep as it needs to be to stand on; the rest
# of the painted stone below it is scenery.
PLATFORM_MAX_DEPTH = 40
PLATFORM_MIN_DEPTH = 18

# Hazards that are simply not survivable, per theme.
LETHAL_THEMES = {"fire", "gold"}

HAZARD_FLAVOUR = {
    "LAVA": ("LAVA", 22.0),
    "FROST": ("FREEZING WATER", 12.0),
    "POISON": ("TOXIC SLUDGE", 14.0),
    "DROWNING": ("DEEP WATER", 12.0),
    "ARCANE": ("ARCANE VENT", 16.0),
    "THORNS": ("THORNS", 12.0),
    "VOID": ("VOID", 18.0),
    "MOLTEN_GOLD": ("MOLTEN GOLD", 22.0),
    "MACHINERY": ("MACHINERY", 18.0),
    "SHOCK": ("LIVE CURRENT", 20.0),
}

DEATH_FLAVOUR = {
    "fire": "THE MAGMA BELOW",
    "ice": "THE GLACIAL ABYSS",
    "poison": "THE SLUDGE BELOW",
    "water": "THE DEPTHS",
    "crystal": "THE CHASM",
    "nature": "THE HOLLOW BELOW",
    "shadow": "THE VOID BELOW",
    "gold": "THE MOLTEN VAULT",
    "clockwork": "THE GEARWORKS BELOW",
    "electric": "THE PIT",
}


# --- Derived authoring data --------------------------------------------------


@dataclass
class LevelPlan:
    info: MapAnalysis
    platforms: list[Rect]
    hazards: list[Rect]
    death_zone: Rect | None
    walkable: Rect | None
    player_start: tuple[int, int]
    spawns: list[tuple[int, int]]


def plan(info: MapAnalysis) -> LevelPlan:
    interior = info.interior
    vertical = info.orientation == "vertical"

    platforms = [_platform_rect(ledge) for ledge in info.ledges] if vertical else []
    death_zone = None
    hazards = list(info.hazards)

    if vertical and info.pit_top is not None:
        death_zone = Rect(
            interior.x,
            info.pit_top,
            interior.w,
            max(info.size[1] - info.pit_top, 60),
        )
        # A pool already inside the pit is redundant; the fall kills first.
        hazards = [h for h in hazards if h.cy < info.pit_top]
        platforms = [p for p in platforms if p.y < info.pit_top]

    walkable = None
    if not vertical:
        walkable = Rect(
            int(interior.x + interior.w * FLAT_INSET_X),
            int(interior.y + interior.h * FLAT_INSET_Y),
            int(interior.w * (1.0 - FLAT_INSET_X * 2)),
            int(interior.h * (1.0 - FLAT_INSET_Y * 2)),
        )

    if vertical:
        start = _vertical_start(platforms, interior)
        spawns = _vertical_spawns(platforms)
    else:
        assert walkable is not None
        start = (int(walkable.cx), int(walkable.y + walkable.h * 0.72))
        spawns = _flat_spawns(walkable)

    return LevelPlan(
        info=info,
        platforms=platforms,
        hazards=hazards,
        death_zone=death_zone,
        walkable=walkable,
        player_start=start,
        spawns=spawns,
    )


def _platform_rect(ledge: Ledge) -> Rect:
    depth = int(min(max(ledge.thickness, PLATFORM_MIN_DEPTH), PLATFORM_MAX_DEPTH))
    return Rect(ledge.x0, ledge.y, ledge.width, depth)


def _wide_platforms(platforms: list[Rect], minimum: int = 150) -> list[Rect]:
    wide = [p for p in platforms if p.w >= minimum]
    return wide or platforms


def _vertical_start(platforms: list[Rect], interior: Rect) -> tuple[int, int]:
    """Stand the knight on the widest low platform, toward its left."""
    candidates = _wide_platforms(platforms, 220)
    if not candidates:
        return int(interior.cx), int(interior.y + interior.h * 0.5)
    lowest = max(candidates, key=lambda p: p.y)
    return int(lowest.x + min(lowest.w * 0.25, 160.0)), int(lowest.y - 40)


def _vertical_spawns(platforms: list[Rect]) -> list[tuple[int, int]]:
    """Spread spawn markers along the top of every platform worth standing on."""
    spawns: list[tuple[int, int]] = []
    for platform in _wide_platforms(platforms, 150):
        slots = max(1, min(int(platform.w // 260), 4))
        for index in range(slots):
            fraction = (index + 0.5) / slots
            spawns.append((int(platform.x + platform.w * fraction), int(platform.y - 40)))
    return spawns[:16]


def _flat_spawns(walkable: Rect) -> list[tuple[int, int]]:
    """The old arena's 14 markers, re-laid over the new floor."""
    spawns: list[tuple[int, int]] = []
    for row, count in ((0.16, 5), (0.5, 5), (0.84, 4)):
        for index in range(count):
            fraction = (index + 0.5) / count
            spawns.append(
                (int(walkable.x + walkable.w * fraction), int(walkable.y + walkable.h * row))
            )
    return spawns


# --- Scene emission ----------------------------------------------------------


def _title(info: MapAnalysis) -> str:
    words = info.descriptor.replace("_", " ").split()
    return " ".join(word.upper() for word in words) or info.theme.upper()


def _node_name(info: MapAnalysis) -> str:
    parts = re.split(r"[_\s]+", info.name)
    return "".join(part.capitalize() for part in parts if part)


def emit(plan_data: LevelPlan, texture_uid: str) -> str:
    info = plan_data.info
    width, height = info.size
    vertical = info.orientation == "vertical"

    externals: list[str] = [
        f'[ext_resource type="Script" path="{SCRIPT_UID_PATHS["level"]}" id="1_level"]',
        f'[ext_resource type="Texture2D" path="{texture_uid}" id="2_map"]',
    ]
    if plan_data.platforms:
        externals.append(
            f'[ext_resource type="Script" path="{SCRIPT_UID_PATHS["platform"]}" id="3_platform"]'
        )
    if plan_data.hazards:
        externals.append(
            f'[ext_resource type="Script" path="{SCRIPT_UID_PATHS["hazard"]}" id="4_hazard"]'
        )
    if plan_data.death_zone:
        externals.append(
            f'[ext_resource type="Script" path="{SCRIPT_UID_PATHS["death"]}" id="5_death"]'
        )

    subs: list[str] = [
        '[sub_resource type="RectangleShape2D" id="Shape_wall_v"]',
        f"size = Vector2({WALL_THICKNESS}, {height})",
        "",
        '[sub_resource type="RectangleShape2D" id="Shape_wall_h"]',
        f"size = Vector2({width}, {WALL_THICKNESS})",
        "",
    ]
    sub_count = 2
    if plan_data.walkable:
        walkable = plan_data.walkable
        subs.extend(
            [
                '[sub_resource type="RectangleShape2D" id="Shape_walkable"]',
                f"size = Vector2({walkable.w}, {walkable.h})",
                "",
            ]
        )
        sub_count += 1

    lines: list[str] = []
    lines.append(f"[gd_scene load_steps={len(externals) + sub_count + 1} format=3]")
    lines.append("")
    lines.extend(externals)
    lines.append("")
    lines.extend(subs)

    # --- root
    hazard_label, hazard_damage = HAZARD_FLAVOUR.get(info.hazard_kind, ("HAZARD", 14.0))
    lines.append(f'[node name="{_node_name(info)}" type="Node2D"]')
    lines.append('script = ExtResource("1_level")')
    lines.append(f"kind = {1 if vertical else 0}")
    lines.append(f"hazard_kind = {_hazard_enum_index(info.hazard_kind)}")
    lines.append(f'display_name = "{_title(info)}"')
    lines.append(f'theme = "{info.theme}"')
    lines.append("reviewed = false")
    lines.append(f"content_size = Vector2({width}, {height})")
    lines.append("")

    # --- background
    lines.append('[node name="Background" type="Sprite2D" parent="."]')
    lines.append("centered = false")
    lines.append('texture = ExtResource("2_map")')
    lines.append("")

    # --- walls
    interior = info.interior
    lines.append('[node name="Walls" type="StaticBody2D" parent="." groups=["walls"]]')
    lines.append(f"collision_layer = {WALLS_LAYER}")
    lines.append("collision_mask = 0")
    lines.append("")
    wall_specs = [
        ("Left", interior.x - WALL_THICKNESS // 2, height // 2, "Shape_wall_v"),
        ("Right", interior.right + WALL_THICKNESS // 2, height // 2, "Shape_wall_v"),
        ("Top", width // 2, interior.y - WALL_THICKNESS // 2, "Shape_wall_h"),
    ]
    if not vertical:
        # A vertical room is closed at the bottom by its death zone, not a floor.
        wall_specs.append(
            ("Bottom", width // 2, interior.bottom + WALL_THICKNESS // 2, "Shape_wall_h")
        )
    for name, x, y, shape in wall_specs:
        lines.append(f'[node name="{name}" type="CollisionShape2D" parent="Walls"]')
        lines.append(f"position = Vector2({int(x)}, {int(y)})")
        lines.append(f'shape = SubResource("{shape}")')
        lines.append("")

    # --- platforms
    lines.append('[node name="Platforms" type="Node2D" parent="."]')
    lines.append("")
    for index, rect in enumerate(plan_data.platforms):
        # Narrow ledges are the floating stones and bridge decks: let the player
        # jump up through them.
        one_way = rect.w <= 220
        lines.append(f'[node name="Platform{index}" type="StaticBody2D" parent="Platforms"]')
        lines.append(f"position = Vector2({int(rect.cx)}, {int(rect.cy)})")
        lines.append('script = ExtResource("3_platform")')
        lines.append(f"size = Vector2({rect.w}, {rect.h})")
        lines.append(f"one_way = {str(one_way).lower()}")
        lines.append("")
        lines.append(
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Platforms/Platform{index}"]'
        )
        lines.append("")

    # --- hazards
    lines.append('[node name="Hazards" type="Node2D" parent="."]')
    lines.append("")
    lethal = info.theme in LETHAL_THEMES
    for index, rect in enumerate(plan_data.hazards):
        lines.append(f'[node name="Hazard{index}" type="Area2D" parent="Hazards"]')
        lines.append(f"position = Vector2({int(rect.cx)}, {int(rect.cy)})")
        lines.append('script = ExtResource("4_hazard")')
        lines.append(f"size = Vector2({rect.w}, {rect.h})")
        lines.append(f"damage = {hazard_damage}")
        lines.append(f"instant_death = {str(lethal).lower()}")
        lines.append(f'hazard_name = "{hazard_label}"')
        lines.append("")
        lines.append(
            f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Hazards/Hazard{index}"]'
        )
        lines.append("")

    # --- death zones
    lines.append('[node name="DeathZones" type="Node2D" parent="."]')
    lines.append("")
    if plan_data.death_zone:
        rect = plan_data.death_zone
        lines.append('[node name="Pit" type="Area2D" parent="DeathZones"]')
        lines.append(f"position = Vector2({int(rect.cx)}, {int(rect.cy)})")
        lines.append('script = ExtResource("5_death")')
        lines.append(f"size = Vector2({rect.w}, {rect.h})")
        lines.append(f'hazard_name = "{DEATH_FLAVOUR.get(info.theme, "THE FALL")}"')
        lines.append("")
        lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="DeathZones/Pit"]')
        lines.append("")

    # --- walkable region
    if plan_data.walkable:
        walkable = plan_data.walkable
        lines.append('[node name="WalkableRegion" type="Area2D" parent="."]')
        lines.append(f"position = Vector2({int(walkable.cx)}, {int(walkable.cy)})")
        lines.append("collision_layer = 0")
        lines.append("collision_mask = 0")
        lines.append("monitoring = false")
        lines.append("monitorable = false")
        lines.append("")
        lines.append('[node name="Shape" type="CollisionShape2D" parent="WalkableRegion"]')
        lines.append('shape = SubResource("Shape_walkable")')
        lines.append("")
    else:
        lines.append('[node name="WalkableRegion" type="Area2D" parent="."]')
        lines.append("collision_layer = 0")
        lines.append("collision_mask = 0")
        lines.append("monitoring = false")
        lines.append("monitorable = false")
        lines.append("")

    # --- markers
    start_x, start_y = plan_data.player_start
    lines.append('[node name="PlayerStart" type="Marker2D" parent="."]')
    lines.append(f"position = Vector2({start_x}, {start_y})")
    lines.append("")

    lines.append('[node name="SpawnPoints" type="Node2D" parent="."]')
    lines.append("")
    for index, (x, y) in enumerate(plan_data.spawns):
        lines.append(f'[node name="Spawn{index}" type="Marker2D" parent="SpawnPoints"]')
        lines.append(f"position = Vector2({x}, {y})")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def _hazard_enum_index(name: str) -> int:
    order = [
        "LAVA",
        "FROST",
        "POISON",
        "DROWNING",
        "ARCANE",
        "THORNS",
        "VOID",
        "MOLTEN_GOLD",
        "MACHINERY",
        "SHOCK",
    ]
    return order.index(name) if name in order else 0


def texture_path(name: str) -> str:
    return f"res://descent/assets/maps/{name}"


def is_reviewed(path: Path) -> bool:
    if not path.exists():
        return False
    return "reviewed = true" in path.read_text(encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("maps", nargs="*", help="map file names; defaults to all")
    parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite levels that have been marked reviewed",
    )
    args = parser.parse_args()

    names = args.maps or sorted(p.name for p in MAPS_DIR.glob("*.png"))
    LEVELS_DIR.mkdir(parents=True, exist_ok=True)

    written = 0
    skipped = 0
    for name in names:
        info = analyse(MAPS_DIR / name)
        out_path = LEVELS_DIR / f"{info.name}.tscn"
        if is_reviewed(out_path) and not args.force:
            print(f"  skip (reviewed) {info.name}")
            skipped += 1
            continue
        plan_data = plan(info)
        out_path.write_text(emit(plan_data, texture_path(name)), encoding="utf-8")
        written += 1
        print(
            f"  {info.name:50s} {info.orientation:8s} "
            f"platforms={len(plan_data.platforms):2d} hazards={len(plan_data.hazards):2d} "
            f"death={'yes' if plan_data.death_zone else 'no ':3s} "
            f"spawns={len(plan_data.spawns):2d}"
        )

    print(f"\n{written} level scenes written to {LEVELS_DIR.relative_to(PROJECT_ROOT)}")
    if skipped:
        print(f"{skipped} skipped because they were already reviewed (use --force)")


if __name__ == "__main__":
    main()
