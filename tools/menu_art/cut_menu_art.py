#!/usr/bin/env python3
"""Regenerate the runtime menu art (logo, dragon, floating islands) from the
splash key art. Outputs: menu_logo.png, menu_dragon.png, menu_island_N.png.

Requires: numpy, pillow, scipy, opencv-python-headless
  python3 -m venv /tmp/menuart-venv
  /tmp/menuart-venv/bin/pip install numpy pillow scipy opencv-python-headless
  /tmp/menuart-venv/bin/python tools/menu_art/cut_menu_art.py [SOURCE_PNG] [OUT_DIR]
Defaults: assets/splash/splash_source.png -> assets/ui/menu (relative to repo root).
"""
import sys, os
import numpy as np, cv2
from scipy import ndimage as ndi
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/splash/splash_source.png")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "assets/ui/menu")
os.makedirs(OUT, exist_ok=True)
im = np.array(Image.open(SRC).convert("RGB"))
PAD = 4
LETTER_MIN = 1500  # logo components smaller than this (sparkle ticks, specks) are dropped


def hsv(c):
    return cv2.cvtColor(c, cv2.COLOR_RGB2HSV).astype(int)


def border_labels(lab):
    b = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return b[b > 0]


def outline_cut(box, keep_mode):
    """Dark-green-outline based cut (logo, dragon). Returns bool keep mask + crop."""
    x0, y0, x1, y1 = box
    c = im[y0:y1, x0:x1]
    h = hsv(c)
    r, g, b = [c[..., i].astype(int) for i in range(3)]
    outline = ndi.binary_dilation((h[..., 2] < 110) & (g >= b - 10), iterations=1)
    yel = (r > 190) & (g > 150) & (b < 130) & (r - b > 90)
    lab, _ = ndi.label(~(outline | yel))
    bg = np.isin(lab, border_labels(lab))
    sky = ((b - r) > 60) & (h[..., 1] > 90) & ~bg  # enclosed sky pockets (letter counters)
    sl, sn = ndi.label(sky)
    for i in range(1, sn + 1):
        m = sl == i
        if m.sum() >= 15:
            bg |= m
    fg = ~bg
    fl, fn = ndi.label(fg)
    sz = ndi.sum(fg, fl, range(1, fn + 1))
    if keep_mode == "largest":
        keep = fl == 1 + int(np.argmax(sz))
    else:  # letters only: drop small comps (sparkle ticks are yellow-excluded + tiny)
        keep = np.isin(fl, [i + 1 for i, s in enumerate(sz) if s >= LETTER_MIN])
    return keep, c


def decontaminate(rgb, alpha_bin, a):
    """Pull RGB of semi-transparent edge pixels toward nearest fully-opaque interior colour."""
    interior = ndi.binary_erosion(alpha_bin, iterations=2)
    if not interior.any():
        return rgb
    idx = ndi.distance_transform_edt(~interior, return_distances=False, return_indices=True)
    nearest = rgb[idx[0], idx[1]]
    edge = (a < 0.98)[..., None]
    return np.where(edge, nearest, rgb)


def finish(keep, c, name, erode=1, feather=0.8, decon=False, min_alpha=8, ramp=None):
    k = ndi.binary_erosion(keep, iterations=erode) if erode else keep
    a = cv2.GaussianBlur(k.astype(np.float32), (0, 0), feather)
    if ramp is not None:
        a = a * ramp
    rgb = decontaminate(c, k, a) if decon else c
    rgba = np.dstack([rgb, (a * 255).astype(np.uint8)])
    ys, xs = np.where(rgba[..., 3] > min_alpha)
    rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    rgba = np.pad(rgba, ((PAD, PAD), (PAD, PAD), (0, 0)))
    rgba[..., :3][rgba[..., 3] == 0] = 0
    Image.fromarray(rgba).save(os.path.join(OUT, name))
    print(name, rgba.shape[1], "x", rgba.shape[0])


def island(box, name):
    x0, y0, x1, y1 = box
    c = im[y0:y1, x0:x1]
    h = hsv(c)
    H, S, V = h[..., 0], h[..., 1], h[..., 2]
    r, g, b = [c[..., i].astype(int) for i in range(3)]
    grass = (g > b + 15) & (g > r)
    rock = (V < 215) & (b >= r - 10) & (H > 95)  # grey-blue rock; fogged underside fades via ramp below
    cand = grass | rock
    cand = ndi.binary_opening(cand, iterations=1)
    lab, n = ndi.label(cand)
    sz = ndi.sum(cand, lab, range(1, n + 1))
    keep = lab == 1 + int(np.argmax(sz))
    keep = ndi.binary_closing(keep, iterations=3)
    keep = ndi.binary_fill_holes(keep)
    fl, fn = ndi.label(keep)
    sz = ndi.sum(keep, fl, range(1, fn + 1))
    keep = fl == 1 + int(np.argmax(sz))
    ramp = np.where(grass, 1.0, np.clip((222 - V) / 35.0, 0, 1))  # fade fogged rock into sky
    ramp = cv2.GaussianBlur(ramp.astype(np.float32), (0, 0), 1.5)
    finish(keep, c, name, erode=1, feather=1.0, decon=True, ramp=ramp)


if __name__ == "__main__":
    k, c = outline_cut((100, 90, 930, 485), "letters")
    finish(k, c, "menu_logo.png")
    k, c = outline_cut((120, 520, 900, 1060), "largest")
    finish(k, c, "menu_dragon.png", decon=True)
    island((690, 440, 945, 635), "menu_island_1.png")
    island((80, 525, 305, 705), "menu_island_2.png")
