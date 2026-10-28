#!/usr/bin/env python3
"""Read the authored dragon rig from its OpenRaster master."""

from __future__ import annotations

from dataclasses import dataclass
import io
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image


EXPECTED_PARTS = {
    "head", "jaw", "body", "wing_big", "wing_small", "tail",
    "arm_front", "arm_back", "leg_front", "leg_back",
}


@dataclass(frozen=True)
class OraPart:
    rgba: np.ndarray
    x: int
    y: int
    pivot: tuple[int, int]
    z: int


@dataclass(frozen=True)
class OraMaster:
    width: int
    height: int
    parts: dict[str, OraPart]


def _visible(element: ET.Element) -> bool:
    return element.get("visibility", "visible") == "visible"


def read_master(path: Path) -> OraMaster:
    """Read visible top-level part groups and validate the authored contract."""
    try:
        archive = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as error:
        raise RuntimeError(f"could not open ORA master {path}: {error}") from error
    with archive:
        try:
            root = ET.fromstring(archive.read("stack.xml"))
        except (KeyError, ET.ParseError) as error:
            raise RuntimeError(f"invalid ORA stack.xml in {path}: {error}") from error
        stack = root.find("stack")
        if stack is None:
            raise RuntimeError("ORA master has no top-level stack")
        groups = [child for child in stack if child.tag == "stack"]
        by_name: dict[str, ET.Element] = {}
        for group in groups:
            name = group.get("name", "")
            if not name:
                raise RuntimeError("ORA master has an unnamed top-level group")
            if name in by_name:
                raise RuntimeError(f"ORA master has duplicate group: {name}")
            by_name[name] = group
        missing = sorted(EXPECTED_PARTS - set(by_name))
        hidden = sorted(name for name in EXPECTED_PARTS if name in by_name and not _visible(by_name[name]))
        visible_names = {name for name, group in by_name.items() if _visible(group)}
        unexpected = sorted(visible_names - EXPECTED_PARTS)
        problems = []
        if missing:
            problems.append(f"missing required groups: {', '.join(missing)}")
        if hidden:
            problems.append(f"required groups are hidden: {', '.join(hidden)}")
        if unexpected:
            problems.append(f"unexpected visible groups: {', '.join(unexpected)}")
        if problems:
            raise RuntimeError("ORA group contract failed; " + "; ".join(problems))

        visible_groups = [group for group in groups if _visible(group)]
        parts: dict[str, OraPart] = {}
        for top_index, group in enumerate(visible_groups):
            name = group.get("name", "")
            layers = [child for child in group if child.tag == "layer"]
            markers = [layer for layer in layers if layer.get("name", "").startswith("pivot_")]
            pixels = [layer for layer in layers if not layer.get("name", "").startswith("pivot_")]
            if len(markers) != 1 or markers[0].get("name") != f"pivot_{name}":
                raise RuntimeError(f"visible group {name!r} must have exactly one pivot_{name} marker layer")
            if len(pixels) != 1:
                raise RuntimeError(f"visible group {name!r} must have exactly one part layer")
            marker = markers[0]
            layer = pixels[0]
            try:
                marker_rgba = Image.open(io.BytesIO(archive.read(marker.get("src", "")))).convert("RGBA")
                rgba = np.array(Image.open(io.BytesIO(archive.read(layer.get("src", "")))).convert("RGBA"))
                marker_x = int(marker.get("x", "0"))
                marker_y = int(marker.get("y", "0"))
                x = int(layer.get("x", "0"))
                y = int(layer.get("y", "0"))
            except (KeyError, OSError, ValueError) as error:
                raise RuntimeError(f"could not read layers for visible group {name!r}: {error}") from error
            if marker_rgba.size != (29, 29):
                raise RuntimeError(f"pivot marker for {name!r} is {marker_rgba.size}, expected 29x29")
            parts[name] = OraPart(
                rgba=rgba,
                x=x,
                y=y,
                pivot=(marker_x + 14, marker_y + 14),
                z=len(visible_groups) - top_index - 1,
            )
        return OraMaster(width=int(root.get("w", "0")), height=int(root.get("h", "0")), parts=parts)


def composite(master: OraMaster) -> np.ndarray:
    """Composite visible part pixels on the ORA canvas, excluding pivot markers."""
    canvas = Image.new("RGBA", (master.width, master.height))
    for part in sorted(master.parts.values(), key=lambda item: item.z):
        canvas.alpha_composite(Image.fromarray(part.rgba, "RGBA"), (part.x, part.y))
    return np.array(canvas)
