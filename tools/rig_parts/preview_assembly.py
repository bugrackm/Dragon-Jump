#!/usr/bin/env python3
"""Render the atlas assembly and compare it with the ORA master."""

from __future__ import annotations

import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ora_master


ROOT = Path(__file__).resolve().parents[2]
PACK_DIR = ROOT / "assets/dragon_rig/classic"
MASTER_PATH = ROOT / "assets/sprites/_masters/dragon_rig/rig_master.ora"
OUTPUT_DIR = ROOT / "docs/codex-briefs/ref"
BACKGROUND = (232, 234, 237, 255)


def load_pack() -> tuple[dict, Image.Image]:
    data = json.loads((PACK_DIR / "parts.json").read_text(encoding="utf-8"))
    atlas = Image.open(PACK_DIR / data["atlas"]).convert("RGBA")
    return data, atlas


def global_pivots(data: dict) -> dict[str, tuple[int, int]]:
    result: dict[str, tuple[int, int]] = {}

    def resolve(name: str) -> tuple[int, int]:
        if name in result:
            return result[name]
        part = data["parts"][name]
        parent = part["parent"]
        if not parent:
            result[name] = (0, 0)
        else:
            parent_position = resolve(parent)
            result[name] = (parent_position[0] + part["offset"][0], parent_position[1] + part["offset"][1])
        return result[name]

    for part_name in data["parts"]:
        resolve(part_name)
    return result


def assemble(data: dict, atlas: Image.Image) -> tuple[Image.Image, dict[str, tuple[int, int]], tuple[int, int]]:
    pivots = global_pivots(data)
    placements = {
        name: (pivots[name][0] - part["pivot"][0], pivots[name][1] - part["pivot"][1])
        for name, part in data["parts"].items()
    }
    min_x = min(position[0] for position in placements.values())
    min_y = min(position[1] for position in placements.values())
    max_x = max(placements[name][0] + data["parts"][name]["region"][2] for name in placements)
    max_y = max(placements[name][1] + data["parts"][name]["region"][3] for name in placements)
    canvas = Image.new("RGBA", (max_x - min_x, max_y - min_y))
    for name, part in sorted(data["parts"].items(), key=lambda item: item[1]["z"]):
        x, y, width, height = part["region"]
        image = atlas.crop((x, y, x + width, y + height))
        place_x, place_y = placements[name]
        canvas.alpha_composite(image, (place_x - min_x, place_y - min_y))
    alpha = np.array(canvas)[..., 3]
    ys, xs = np.nonzero(alpha)
    crop = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    origin = (min_x + crop[0], min_y + crop[1])
    shifted_pivots = {name: (point[0] - origin[0], point[1] - origin[1]) for name, point in pivots.items()}
    return canvas.crop(crop), shifted_pivots, origin


def ora_at_size(size: tuple[int, int]) -> Image.Image:
    master = ora_master.read_master(MASTER_PATH)
    image = ora_master.composite(master)
    ys, xs = np.nonzero(image[..., 3])
    crop = image[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1]
    return Image.fromarray(crop, "RGBA").resize(size, Image.Resampling.LANCZOS)


def _panel(image: Image.Image, title: str, margin: int = 24, label_height: int = 28) -> Image.Image:
    panel = Image.new("RGBA", (image.width + margin * 2, image.height + margin * 2 + label_height), BACKGROUND)
    panel.alpha_composite(image, (margin, margin + label_height))
    ImageDraw.Draw(panel).text((margin, 13), title, fill=(45, 50, 58, 255), font=ImageFont.load_default())
    return panel


def render_assembly(assembly: Image.Image, pivots: dict[str, tuple[int, int]]) -> None:
    marked = assembly.copy()
    draw = ImageDraw.Draw(marked)
    for x, y in pivots.values():
        draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(225, 35, 42, 255))
    _panel(marked, "RIG ASSEMBLY - RED DOTS ARE AUTHORED PIVOTS").convert("RGB").save(
        OUTPUT_DIR / "rig_018a_assembly.png", compress_level=9
    )


def render_comparison(ora_image: Image.Image, assembly: Image.Image) -> None:
    left = _panel(ora_image, "ORA VISIBLE-GROUP COMPOSITE")
    right = _panel(assembly, "ATLAS + PARTS.JSON ASSEMBLY")
    gap = 24
    canvas = Image.new("RGBA", (left.width + right.width + gap, max(left.height, right.height)), BACKGROUND)
    canvas.alpha_composite(left, (0, 0))
    canvas.alpha_composite(right, (left.width + gap, 0))
    canvas.convert("RGB").save(OUTPUT_DIR / "rig_018a_ora_vs_rig.png", compress_level=9)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    data, atlas = load_pack()
    assembly, pivots, _ = assemble(data, atlas)
    ora_image = ora_at_size(assembly.size)
    render_assembly(assembly, pivots)
    render_comparison(ora_image, assembly)
    print(f"preview={assembly.width}x{assembly.height} outputs=2 pivots={len(pivots)}")


if __name__ == "__main__":
    main()
