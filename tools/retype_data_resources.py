"""One-off migration: repoints the .tres data files from the removed C++ Resource
classes onto their GDScript replacements, preserving every authored value.

Run once from the repo root:  python tools/retype_data_resources.py
"""

from __future__ import annotations

import pathlib
import re
import sys

DATA_DIR = pathlib.Path("descent/data")
SCRIPT_DIR = "res://descent/scripts/data"

SCRIPTS = {
    "EnemyData": "enemy_data.gd",
    "UpgradeData": "upgrade_data.gd",
    "DoorDestinationData": "door_destination_data.gd",
    "ShopOfferData": "shop_offer_data.gd",
    "DifficultyData": "difficulty_data.gd",
}

# Properties renamed to avoid shadowing a GDScript built-in.
RENAMES = {"DifficultyData": {"floor": "floor_number"}}

HEADER = re.compile(r'^\[gd_resource type="(\w+)" format=3\]\s*', re.MULTILINE)


def migrate(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = HEADER.match(text)
    if not match:
        return "skipped (already migrated or unexpected header)"

    resource_type = match.group(1)
    script_file = SCRIPTS.get(resource_type)
    if script_file is None:
        return f"skipped (unknown type {resource_type})"

    body = text[match.end() :]
    body = body.split("[resource]", 1)[-1].strip("\n")

    for old, new in RENAMES.get(resource_type, {}).items():
        body = re.sub(rf"^{old}(\s*=)", rf"{new}\1", body, flags=re.MULTILINE)

    path.write_text(
        f'[gd_resource type="Resource" script_class="{resource_type}" load_steps=2 format=3]\n'
        "\n"
        f'[ext_resource type="Script" path="{SCRIPT_DIR}/{script_file}" id="1_script"]\n'
        "\n"
        "[resource]\n"
        'script = ExtResource("1_script")\n'
        f"{body}\n",
        encoding="utf-8",
    )
    return f"-> {resource_type} ({script_file})"


def main() -> int:
    if not DATA_DIR.exists():
        print(f"missing {DATA_DIR}", file=sys.stderr)
        return 1

    files = sorted(DATA_DIR.rglob("*.tres"))
    for path in files:
        print(f"{path.as_posix()} {migrate(path)}")
    print(f"\n{len(files)} resource files processed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
