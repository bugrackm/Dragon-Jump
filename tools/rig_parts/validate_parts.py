#!/usr/bin/env python3
"""Validate the generated classic dragon rig against its ORA master."""

from __future__ import annotations

import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cut_parts
import ora_master
import preview_assembly


def _placements(data: dict) -> dict[str, tuple[int, int]]:
    pivots = preview_assembly.global_pivots(data)
    return {
        name: (pivots[name][0] - part["pivot"][0], pivots[name][1] - part["pivot"][1])
        for name, part in data["parts"].items()
    }


def _jaw_coverage(data: dict, atlas: np.ndarray) -> float:
    placements = _placements(data)
    masks = {}
    for name in ("jaw", "head"):
        x, y, width, height = data["parts"][name]["region"]
        masks[name] = atlas[y:y + height, x:x + width, 3] >= 64
    jaw_y, jaw_x = np.nonzero(masks["jaw"])
    jaw_place = placements["jaw"]
    head_place = placements["head"]
    head_x = jaw_x + jaw_place[0] - head_place[0]
    head_y = jaw_y + jaw_place[1] - head_place[1]
    inside = (
        (head_x >= 0) & (head_x < masks["head"].shape[1])
        & (head_y >= 0) & (head_y < masks["head"].shape[0])
    )
    covered = np.zeros(len(jaw_x), dtype=bool)
    covered[inside] = masks["head"][head_y[inside], head_x[inside]]
    return float(covered.mean())


def validate() -> tuple[list[str], int, dict[str, float]]:
    errors: list[str] = []
    checks = 0

    def expect(condition: bool, description: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            errors.append(description)

    master = ora_master.read_master(cut_parts.SOURCE)
    data = json.loads(cut_parts.JSON_PATH.read_text(encoding="utf-8"))
    atlas_image = Image.open(cut_parts.ATLAS_PATH).convert("RGBA")
    atlas = np.array(atlas_image)
    parts = data.get("parts", {})
    expect(set(parts) == ora_master.EXPECTED_PARTS, "part set")
    expect(data.get("version") == 1, "schema version")
    expect(data.get("skin") == "classic", "skin")
    expect(data.get("atlas") == "atlas.png", "atlas name")
    expect(data.get("root") == "body", "root")
    expect(data.get("texture_scale") == cut_parts.TEXTURE_SCALE, "texture scale")
    expect(set(data.get("anchors", {})) == {"mouth", "feet"}, "anchors")
    expected_z = {name: part.z for name, part in master.parts.items()}
    expect({name: part["z"] for name, part in parts.items()} == expected_z, "ORA z order")
    expect(parts["jaw"]["z"] < parts["head"]["z"], "jaw behind head")
    width, height = atlas_image.size
    expect(width <= 2048 and height <= 2048, "atlas size")
    expect(width & (width - 1) == 0 and height & (height - 1) == 0, "atlas power of two")

    rectangles = []
    for name, parent in cut_parts.PARENTS.items():
        part = parts[name]
        expect(part.get("parent") == parent, f"parent:{name}")
        region = part.get("region", [])
        expect(len(region) == 4, f"region schema:{name}")
        if len(region) != 4:
            continue
        x, y, part_width, part_height = region
        expect(
            min(x, y, part_width, part_height) >= 0
            and x + part_width <= width and y + part_height <= height,
            f"region bounds:{name}",
        )
        rectangles.append((name, x, y, x + part_width, y + part_height))
        pivot = part.get("pivot", [])
        expect(
            len(pivot) == 2
            and -4 <= pivot[0] <= part_width + 4
            and -4 <= pivot[1] <= part_height + 4,
            f"pivot near alpha bbox:{name}",
        )
        alpha = atlas[y:y + part_height, x:x + part_width, 3]
        expect(bool(np.any(alpha >= 64)), f"opaque pixels:{name}")
        expect(cut_parts.alpha_bbox(alpha) == (0, 0, part_width, part_height), f"trimmed alpha bbox:{name}")
    for index, first in enumerate(rectangles):
        for second in rectangles[index + 1:]:
            overlap_x = min(first[3], second[3]) - max(first[1], second[1])
            overlap_y = min(first[4], second[4]) - max(first[2], second[2])
            expect(not (overlap_x > 0 and overlap_y > 0), f"atlas overlap:{first[0]}:{second[0]}")

    assembled, _, _ = preview_assembly.assemble(data, atlas_image)
    assembled_array = np.array(assembled)
    expect(assembled.height == cut_parts.TARGET_HEIGHT, f"assembly height:{assembled.height}")
    source = ora_master.composite(master)
    x0, y0, x1, y1 = cut_parts.alpha_bbox(source[..., 3])
    expected = Image.fromarray(source[y0:y1, x0:x1], "RGBA").resize(assembled.size, Image.Resampling.LANCZOS)
    difference = np.abs(assembled_array.astype(np.int16) - np.array(expected).astype(np.int16))
    rgba_mean = float(difference.mean())
    alpha_mean = float(difference[..., 3].mean())
    expect(rgba_mean <= 2.0, f"ORA composite rgba mean diff:{rgba_mean:.3f}")
    expect(alpha_mean <= 1.0, f"ORA composite alpha mean diff:{alpha_mean:.3f}")
    coverage = _jaw_coverage(data, atlas)
    expect(coverage >= 0.98, f"jaw coverage:{coverage:.4f}")
    metrics = {"rgba_mean": rgba_mean, "alpha_mean": alpha_mean, "jaw_coverage": coverage}
    return errors, checks, metrics


def main() -> None:
    try:
        errors, checks, metrics = validate()
    except Exception as error:
        print(f"rig_parts_validation=FAIL errors=1 detail={type(error).__name__}:{error}")
        raise SystemExit(1)
    if errors:
        print(f"rig_parts_validation=FAIL checks={checks} errors={len(errors)} detail={';'.join(errors)}")
        raise SystemExit(1)
    print(
        f"rig_parts_validation=PASS checks={checks} parts=10 z=0..9 "
        f"rgba_mean_diff={metrics['rgba_mean']:.3f} alpha_mean_diff={metrics['alpha_mean']:.3f} "
        f"jaw_coverage={metrics['jaw_coverage']:.4f}"
    )


if __name__ == "__main__":
    main()
