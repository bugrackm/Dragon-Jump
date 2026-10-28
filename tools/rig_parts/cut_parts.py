#!/usr/bin/env python3
"""Build the classic dragon rig atlas and metadata from the ORA master."""

from __future__ import annotations

import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ora_master


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/sprites/_masters/dragon_rig/rig_master.ora"
OUTPUT_DIR = ROOT / "assets/dragon_rig/classic"
ATLAS_PATH = OUTPUT_DIR / "atlas.png"
JSON_PATH = OUTPUT_DIR / "parts.json"
PADDING = 4
TARGET_HEIGHT = 512
TEXTURE_SCALE = 117.0 / TARGET_HEIGHT
PARENTS = {
    "body": "", "head": "body", "jaw": "head", "wing_big": "body",
    "wing_small": "body", "arm_front": "body", "arm_back": "body",
    "leg_front": "body", "leg_back": "body", "tail": "body",
}


def alpha_bbox(alpha: np.ndarray, threshold: int = 1) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(alpha >= threshold)
    if not len(xs):
        raise ValueError("empty alpha mask")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def resize_rgba(array: np.ndarray, factor: float) -> np.ndarray:
    width = max(1, int(round(array.shape[1] * factor)))
    height = max(1, int(round(array.shape[0] * factor)))
    return np.array(Image.fromarray(array, "RGBA").resize((width, height), Image.Resampling.LANCZOS))


def build_scaled_parts(
    master: ora_master.OraMaster, global_scale: float
) -> tuple[dict[str, np.ndarray], dict[str, tuple[int, int]], dict[str, tuple[int, int]]]:
    images: dict[str, np.ndarray] = {}
    positions: dict[str, tuple[int, int]] = {}
    pivots: dict[str, tuple[int, int]] = {}
    for name, part in master.parts.items():
        image = resize_rgba(part.rgba, global_scale)
        x0, y0, x1, y1 = alpha_bbox(image[..., 3])
        images[name] = image[y0:y1, x0:x1]
        positions[name] = (int(round(part.x * global_scale)) + x0, int(round(part.y * global_scale)) + y0)
        pivots[name] = (int(round(part.pivot[0] * global_scale)), int(round(part.pivot[1] * global_scale)))
    return images, positions, pivots


def composite_parts(
    images: dict[str, np.ndarray], positions: dict[str, tuple[int, int]], z_values: dict[str, int]
) -> tuple[np.ndarray, tuple[int, int]]:
    min_x = min(positions[name][0] for name in images)
    min_y = min(positions[name][1] for name in images)
    max_x = max(positions[name][0] + image.shape[1] for name, image in images.items())
    max_y = max(positions[name][1] + image.shape[0] for name, image in images.items())
    canvas = Image.new("RGBA", (max_x - min_x, max_y - min_y))
    for name in sorted(images, key=lambda part_name: z_values[part_name]):
        x, y = positions[name]
        canvas.alpha_composite(Image.fromarray(images[name], "RGBA"), (x - min_x, y - min_y))
    array = np.array(canvas)
    x0, y0, x1, y1 = alpha_bbox(array[..., 3])
    return array[y0:y1, x0:x1], (min_x + x0, min_y + y0)


def choose_global_scale(
    master: ora_master.OraMaster,
) -> tuple[float, dict[str, np.ndarray], dict[str, tuple[int, int]], dict[str, tuple[int, int]], np.ndarray, tuple[int, int]]:
    source = ora_master.composite(master)
    _, y0, _, y1 = alpha_bbox(source[..., 3])
    ideal = TARGET_HEIGHT / (y1 - y0)
    low, high = ideal * 0.9, ideal * 1.1
    best = None
    z_values = {name: part.z for name, part in master.parts.items()}
    for _ in range(32):
        scale = (low + high) / 2.0
        images, positions, pivots = build_scaled_parts(master, scale)
        assembled, origin = composite_parts(images, positions, z_values)
        candidate = (
            abs(assembled.shape[0] - TARGET_HEIGHT), abs(scale - ideal), scale,
            images, positions, pivots, assembled, origin,
        )
        if best is None or candidate[:2] < best[:2]:
            best = candidate
        if assembled.shape[0] < TARGET_HEIGHT:
            low = scale
        elif assembled.shape[0] > TARGET_HEIGHT:
            high = scale
        else:
            high = scale
    if best is None or best[0] != 0:
        raise RuntimeError("could not find a global scale for a 512 px assembly")
    return best[2], best[3], best[4], best[5], best[6], best[7]


def next_power_of_two(value: int) -> int:
    return 1 << max(0, value - 1).bit_length()


def pack_parts(images: dict[str, np.ndarray]) -> tuple[np.ndarray, dict[str, tuple[int, int, int, int]]]:
    ordered = sorted(images, key=lambda name: (-images[name].shape[0], name))
    candidates = []
    for atlas_width in (512, 1024, 2048):
        x = y = PADDING
        row_height = 0
        regions: dict[str, tuple[int, int, int, int]] = {}
        possible = True
        for name in ordered:
            height, width = images[name].shape[:2]
            if width + PADDING * 2 > atlas_width:
                possible = False
                break
            if x + width + PADDING > atlas_width:
                x = PADDING
                y += row_height + PADDING
                row_height = 0
            regions[name] = (x, y, width, height)
            x += width + PADDING
            row_height = max(row_height, height)
        if not possible:
            continue
        atlas_height = next_power_of_two(y + row_height + PADDING)
        if atlas_height <= 2048:
            candidates.append((atlas_width * atlas_height, atlas_width, atlas_height, regions))
    if not candidates:
        raise RuntimeError("parts do not fit in a 2048 px power-of-two atlas")
    _, width, height, regions = min(candidates, key=lambda item: (item[0], item[1]))
    atlas = np.zeros((height, width, 4), dtype=np.uint8)
    for name, (x, y, part_width, part_height) in regions.items():
        atlas[y:y + part_height, x:x + part_width] = images[name]
    return atlas, regions


def build_pack() -> tuple[dict, np.ndarray, np.ndarray]:
    master = ora_master.read_master(SOURCE)
    _, images, positions, global_pivots, assembled, _ = choose_global_scale(master)
    atlas, regions = pack_parts(images)
    local_pivots = {
        name: (global_pivots[name][0] - positions[name][0], global_pivots[name][1] - positions[name][1])
        for name in images
    }
    json_parts = {}
    for name in sorted(master.parts, key=lambda part_name: master.parts[part_name].z):
        parent = PARENTS[name]
        offset = [0, 0]
        if parent:
            offset = [
                global_pivots[name][0] - global_pivots[parent][0],
                global_pivots[name][1] - global_pivots[parent][1],
            ]
        json_parts[name] = {
            "region": list(regions[name]), "pivot": list(local_pivots[name]),
            "parent": parent, "offset": offset, "z": master.parts[name].z,
        }
    jaw_alpha = images["jaw"][..., 3]
    jaw_ys, jaw_xs = np.nonzero(jaw_alpha >= 64)
    jaw_front = jaw_xs >= np.quantile(jaw_xs, 0.96)
    mouth_global = (
        positions["jaw"][0] + int(jaw_xs.max()),
        positions["jaw"][1] + int(round(jaw_ys[jaw_front].mean())),
    )
    foot_alpha = images["leg_front"][..., 3]
    foot_ys, foot_xs = np.nonzero(foot_alpha >= 64)
    foot_bottom = foot_ys >= np.quantile(foot_ys, 0.98)
    feet_global = (
        positions["leg_front"][0] + int(round(foot_xs[foot_bottom].mean())),
        positions["leg_front"][1] + int(foot_ys.max()),
    )
    root_global = global_pivots["body"]
    data = {
        "version": 1, "skin": "classic", "atlas": "atlas.png",
        "texture_scale": TEXTURE_SCALE, "root": "body", "parts": json_parts,
        "anchors": {
            "mouth": [mouth_global[0] - root_global[0], mouth_global[1] - root_global[1]],
            "feet": [feet_global[0] - root_global[0], feet_global[1] - root_global[1]],
        },
    }
    return data, atlas, assembled


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    data, atlas, assembled = build_pack()
    Image.fromarray(atlas, "RGBA").save(ATLAS_PATH, optimize=False, compress_level=9)
    JSON_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(
        f"rig_parts={len(data['parts'])} atlas={atlas.shape[1]}x{atlas.shape[0]} "
        f"assembly={assembled.shape[1]}x{assembled.shape[0]} texture_scale={TEXTURE_SCALE:.9f}"
    )


if __name__ == "__main__":
    main()
