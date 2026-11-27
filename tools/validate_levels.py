#!/usr/bin/env python3
"""Standalone validator for Echoes of the Void campaign level JSON files.

Checks:
1. Valid JSON syntax and required campaign metadata fields (`level_id`, `title`, `par_turns`, `layout`).
2. Non-empty rectangular `layout` containing only valid GridManager tile symbols.
3. Presence of player spawn/extraction (`E`) and vault objective (`G`).
4. All entity coordinates (`doors`, `switches`, `secondary_loot`, `items`, `lasers`,
   `cameras`, `turrets`, `guards` + `waypoints`) inside map bounds.
5. BFS reachability from `E` to `G` across passable tiles (floor, vent, closet, doors, etc.).
"""

from collections import deque
import glob
import json
import os
import sys

VALID_TILES = set(" .#=VCDEGSH")
PASSABLE_TILES = set(".VCDEGSH")


def find_tiles(layout, target):
    coords = []
    for y, row in enumerate(layout):
        for x, ch in enumerate(row):
            if ch == target:
                coords.append((x, y))
    return coords


def bfs_reachable(layout, start, goal):
    h = len(layout)
    w = len(layout[0])
    q = deque([start])
    seen = {start}
    while q:
        x, y = q.popleft()
        if (x, y) == goal:
            return True
        for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                if layout[ny][nx] in PASSABLE_TILES:
                    seen.add((nx, ny))
                    q.append((nx, ny))
    return False


def validate_level(path):
    errors = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        return [f"invalid JSON: {exc}"]

    if not isinstance(data, dict):
        return ["root JSON value must be an object"]

    for key in ("level_id", "title", "par_turns", "layout"):
        if key not in data:
            errors.append(f"missing required field '{key}'")

    if "par_turns" in data and (not isinstance(data["par_turns"], int) or data["par_turns"] <= 0):
        errors.append("'par_turns' must be a positive integer")

    layout = data.get("layout")
    if not isinstance(layout, list) or not layout:
        errors.append("'layout' must be a non-empty list of strings")
        return errors

    if not all(isinstance(r, str) and len(r) > 0 for r in layout):
        errors.append("all rows in 'layout' must be non-empty strings")
        return errors

    widths = {len(r) for r in layout}
    if len(widths) != 1:
        errors.append(f"non-rectangular layout widths: {sorted(widths)}")
        return errors

    w, h = len(layout[0]), len(layout)
    for y, row in enumerate(layout):
        for x, ch in enumerate(row):
            if ch not in VALID_TILES:
                errors.append(f"unknown tile '{ch}' at ({x}, {y})")

    starts = find_tiles(layout, "E")
    vaults = find_tiles(layout, "G")
    if not starts:
        errors.append("missing extraction/start tile 'E'")
    if not vaults:
        errors.append("missing vault objective tile 'G'")

    if starts and vaults and not bfs_reachable(layout, starts[0], vaults[0]):
        errors.append(f"vault {vaults[0]} is not reachable from start {starts[0]}")

    entity_sections = {
        "doors": "pos",
        "switches": "pos",
        "secondary_loot": "pos",
        "items": "pos",
        "lasers": "pos",
        "cameras": "pos",
        "turrets": "pos",
        "guards": "start",
    }

    for section, key in entity_sections.items():
        if section not in data:
            continue
        items = data[section]
        if not isinstance(items, list):
            errors.append(f"section '{section}' must be an array")
            continue
        for idx, item in enumerate(items):
            if not isinstance(item, dict):
                errors.append(f"{section}[{idx}] must be an object")
                continue
            pos = item.get(key)
            if (
                not isinstance(pos, list)
                or len(pos) != 2
                or not all(isinstance(v, int) for v in pos)
                or not (0 <= pos[0] < w and 0 <= pos[1] < h)
            ):
                errors.append(f"{section}[{idx}].{key}={pos} out of bounds ({w}x{h})")
            if section == "guards" and "waypoints" in item:
                for wi, wp in enumerate(item["waypoints"]):
                    if (
                        not isinstance(wp, list)
                        or len(wp) != 2
                        or not (0 <= wp[0] < w and 0 <= wp[1] < h)
                    ):
                        errors.append(f"guards[{idx}].waypoints[{wi}]={wp} out of bounds")

    return errors


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(repo_root, "levels", "campaign", "*.json")))
    if not files:
        print("ERROR: No campaign JSON files found.")
        sys.exit(1)

    total_errors = 0
    for path in files:
        rel = os.path.relpath(path, repo_root)
        errs = validate_level(path)
        if errs:
            total_errors += len(errs)
            print(f"[FAIL] {rel}:")
            for e in errs:
                print(f"  - {e}")
        else:
            with open(path, "r", encoding="utf-8") as f:
                d = json.load(f)
            print(f"[OK]   {rel} ({len(d['layout'][0])}x{len(d['layout'])}, par={d['par_turns']}): {d['title']}")

    print(f"\nValidated {len(files)} campaign level(s), {total_errors} error(s).")
    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
