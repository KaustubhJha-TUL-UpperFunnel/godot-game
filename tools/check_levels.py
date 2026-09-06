"""Structural check on the generated level scenes.

There is no Godot binary on this machine, so this stands in for opening all
fifty scenes in the editor: it parses the .tscn files, resolves every resource
path and node parent, and asserts the contract level.gd relies on.

    python tools/check_levels.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from map_analysis import PROJECT_ROOT

LEVELS_DIR = PROJECT_ROOT / "descent" / "assets" / "scenes" / "levels"

REQUIRED_NODES = (
    "Background",
    "Walls",
    "Platforms",
    "Hazards",
    "DeathZones",
    "WalkableRegion",
    "PlayerStart",
    "SpawnPoints",
    "DoorAnchors",
)

HEADER_RE = re.compile(r"^\[(?P<kind>gd_scene|ext_resource|sub_resource|node)(?P<attrs>.*)\]$")
ATTR_RE = re.compile(r'(\w+)="([^"]*)"|(\w+)=(\d+)')
SUBRES_USE_RE = re.compile(r'SubResource\("([^"]+)"\)')
EXTRES_USE_RE = re.compile(r'ExtResource\("([^"]+)"\)')


def parse(path: Path) -> tuple[list[dict], list[str]]:
    """Returns (sections, errors). Each section is a dict of header attrs plus
    a 'properties' dict of the key = value lines under it."""
    sections: list[dict] = []
    errors: list[str] = []
    current: dict | None = None

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        header = HEADER_RE.match(line)
        if header:
            attrs: dict[str, str] = {}
            for key_q, value_q, key_n, value_n in ATTR_RE.findall(header.group("attrs")):
                if key_q:
                    attrs[key_q] = value_q
                else:
                    attrs[key_n] = value_n
            groups = re.search(r'groups=\[([^\]]*)\]', header.group("attrs"))
            if groups:
                attrs["groups"] = groups.group(1)
            current = {"kind": header.group("kind"), "line": number, "properties": {}, **attrs}
            sections.append(current)
            continue
        if current is None:
            errors.append(f"{path.name}:{number}: property outside any section: {line}")
            continue
        if "=" not in line:
            errors.append(f"{path.name}:{number}: unparsed line: {line}")
            continue
        key, value = line.split("=", 1)
        current["properties"][key.strip()] = value.strip()

    return sections, errors


def check(path: Path) -> list[str]:
    sections, problems = parse(path)
    if not sections or sections[0]["kind"] != "gd_scene":
        problems.append(f"{path.name}: missing gd_scene header")
        return problems

    ext_ids = {s["id"] for s in sections if s["kind"] == "ext_resource"}
    sub_ids = {s["id"] for s in sections if s["kind"] == "sub_resource"}
    nodes = [s for s in sections if s["kind"] == "node"]

    # Resource files must exist on disk.
    for section in sections:
        if section["kind"] != "ext_resource":
            continue
        res = section.get("path", "")
        if not res.startswith("res://"):
            problems.append(f"{path.name}: non-res path {res}")
            continue
        target = PROJECT_ROOT / res[len("res://") :]
        if not target.exists():
            problems.append(f"{path.name}: missing resource {res}")

    # Every referenced id must be declared.
    text = path.read_text(encoding="utf-8")
    for used in set(SUBRES_USE_RE.findall(text)):
        if used not in sub_ids:
            problems.append(f"{path.name}: undeclared SubResource {used}")
    for used in set(EXTRES_USE_RE.findall(text)):
        if used not in ext_ids:
            problems.append(f"{path.name}: undeclared ExtResource {used}")

    # load_steps is a hint, but a wrong one is a sign the emitter drifted.
    expected_steps = len(ext_ids) + len(sub_ids) + 1
    declared = int(sections[0].get("load_steps", expected_steps))
    if declared != expected_steps:
        problems.append(
            f"{path.name}: load_steps={declared}, expected {expected_steps}"
        )

    # Node paths must resolve: a node's declared parent has to have been seen.
    if not nodes or "parent" in nodes[0]:
        problems.append(f"{path.name}: first node is not the scene root")
        return problems

    known = {".": nodes[0]["name"]}
    for node in nodes[1:]:
        parent = node.get("parent")
        if parent is None:
            problems.append(f"{path.name}:{node['line']}: non-root node without parent")
            continue
        if parent not in known:
            problems.append(
                f"{path.name}:{node['line']}: node {node['name']} has unknown parent {parent}"
            )
            continue
        full = node["name"] if parent == "." else f"{parent}/{node['name']}"
        if full in known:
            problems.append(f"{path.name}: duplicate node path {full}")
        known[full] = node["name"]

    for required in REQUIRED_NODES:
        if required not in known:
            problems.append(f"{path.name}: missing required node {required}")

    root = nodes[0]
    kind = root["properties"].get("kind", "0")
    vertical = kind == "1"

    # Anything with a resizing @tool script needs the child it drives.
    for node in nodes[1:]:
        script = node["properties"].get("script", "")
        if "3_platform" in script or "4_hazard" in script or "5_death" in script:
            parent = node.get("parent", ".")
            expected = f"{parent}/{node['name']}/CollisionShape2D"
            if expected not in known:
                problems.append(f"{path.name}: {expected} missing")
            if "size" not in node["properties"]:
                problems.append(f"{path.name}: {node['name']} has no size")

    platforms = [n for n in nodes if n.get("parent") == "Platforms"]
    pits = [n for n in nodes if n.get("parent") == "DeathZones"]
    spawns = [n for n in nodes if n.get("parent") == "SpawnPoints"]
    anchors = [n for n in nodes if n.get("parent") == "DoorAnchors"]

    if vertical:
        if not platforms:
            problems.append(f"{path.name}: vertical level has no platforms")
        if not pits:
            problems.append(f"{path.name}: vertical level has no death zone")
    else:
        if platforms:
            problems.append(f"{path.name}: flat level should not have platforms")
        if "WalkableRegion/Shape" not in known:
            problems.append(f"{path.name}: flat level has no WalkableRegion/Shape")

    if not spawns:
        problems.append(f"{path.name}: no spawn points")
    if len(anchors) != 3:
        problems.append(f"{path.name}: expected 3 door anchors, found {len(anchors)}")
    if root["properties"].get("reviewed") != "false":
        problems.append(f"{path.name}: root should start with reviewed = false")

    return problems


def main() -> int:
    paths = sorted(LEVELS_DIR.glob("*.tscn"))
    if not paths:
        print(f"no level scenes in {LEVELS_DIR}")
        return 1

    all_problems: list[str] = []
    thin: list[str] = []
    for path in paths:
        problems = check(path)
        all_problems.extend(problems)
        text = path.read_text(encoding="utf-8")
        # Anchored, or "hazard_kind = 1" would match every flat level too.
        if re.search(r"^kind = 1$", text, re.MULTILINE):
            count = text.count('parent="Platforms"')
            if count <= 3:
                thin.append(f"{path.stem}: only {count} platform(s)")

    print(f"checked {len(paths)} level scenes")
    if thin:
        print("\nvertical levels that need the most hand-fixing:")
        for entry in thin:
            print(f"  {entry}")
    if all_problems:
        print(f"\n{len(all_problems)} problem(s):")
        for entry in all_problems:
            print(f"  {entry}")
        return 1
    print("\nno structural problems found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
