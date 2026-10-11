"""Writes the Bases' wall texture for Map 01 as two PNG files: welded steel plates, seamless (the
pattern is periodic), from fixed seeds, so a run always writes the same files. Blender's own Python
runs it for numpy; nothing of Blender is used:

    blender --background --factory-startup --python tools/blender/build_wall_textures.py -- \
        --out src/gameplay/maps/map_01/textures

The Bases' wall material (src/gameplay/maps/map_01/materials/wall.tres) maps it in world space, one
tile every 16 m (uv1_scale 0.0625), and multiplies it by its grey, so the walls stay dark as the
illustrated drawing has them; the Flag Walls' damaged looks take the same texture under their darker
greys and crack layers (src/gameplay/defences/materials/flag_wall_damaged_*.tres).

    wall_plates.png         colour: plates two metres wide and 1.6 m tall (8 by 10 a tile), each
                            its own tone, dark seams, rows of bolts and rust running down from them.
    wall_plates_normal.png  their relief as a tangent-space normal map (green up): the seams sunk,
                            the bolts raised, each plate gently warped.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_ground_textures as ground  # noqa: E402  (its noise, cell and PNG helpers)

SIZE = 1024
COLUMNS = 8
ROWS = 10
# Pixels of a seam's half-width and of a bolt's radius, and bolts per plate edge.
SEAM = 3.0
BOLT = 2.6
BOLTS = 6
# The plates' tones (sRGB, before the material's grey): a weathered steel range.
PLATE_LOW = np.array([0.52, 0.47, 0.42])
PLATE_HIGH = np.array([0.74, 0.69, 0.62])
SEAM_TONE = np.array([0.22, 0.2, 0.19])
BOLT_TONE = np.array([0.64, 0.62, 0.58])
RUST_TONE = np.array([0.5, 0.3, 0.2])
# How strong the relief is: seams, bolts and the warp.
SEAM_DEPTH = 0.6
BOLT_HEIGHT = 0.5
WARP = 0.08
NORMAL_STRENGTH = 3.0


def tangent_normals(height, strength):
    """A tangent-space normal map (OpenGL convention: green points up the image) from a periodic
    height field."""
    du = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dv = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    normal = np.stack([-du, dv, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def main():
    out = ground.parse_out()
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261011)
    ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    plate_w, plate_h = SIZE / COLUMNS, SIZE / ROWS
    # Each row's plates shift by half a plate on alternate rows, as plates are hung.
    row = np.floor(ys / plate_h).astype(int)
    shift = (row % 2) * plate_w / 2.0
    col = np.floor(((xs + shift) % SIZE) / plate_w).astype(int)
    u = ((xs + shift) % SIZE) - col * plate_w
    v = ys - row * plate_h
    tones = rng.random((ROWS, COLUMNS))
    tone = tones[row % ROWS, col % COLUMNS][..., None]
    colour = PLATE_LOW + (PLATE_HIGH - PLATE_LOW) * tone
    mottle = ground.fractal(SIZE, 8, 5, rng)[..., None]
    colour *= 0.85 + mottle * 0.3
    edge = np.minimum(np.minimum(u, plate_w - u), np.minimum(v, plate_h - v))
    seam = np.clip(1.0 - (edge - SEAM) / 1.5, 0.0, 1.0)
    # Bolts along the top and bottom edges of each plate, inside the seam.
    spacing = plate_w / BOLTS
    bu = (u % spacing) - spacing / 2.0
    bolt_top = np.hypot(bu, v - SEAM * 3.0)
    bolt_bottom = np.hypot(bu, (plate_h - v) - SEAM * 3.0)
    bolt = np.clip(1.0 - (np.minimum(bolt_top, bolt_bottom) - BOLT) / 1.2, 0.0, 1.0)
    # Rust running down from the top bolts: a streak under some of them, fading with distance.
    streak_pick = rng.random((ROWS, COLUMNS * BOLTS)) < 0.35
    bolt_index = np.floor(u / spacing).astype(int) + col * BOLTS
    picked = streak_pick[row % ROWS, bolt_index % (COLUMNS * BOLTS)]
    run = (np.clip(1.0 - np.abs(bu) / 4.0, 0.0, 1.0)
            * np.clip(1.0 - (v - SEAM * 3.0) / (plate_h * 0.7), 0.0, 1.0))
    rust = (picked * run * (v > SEAM * 3.0))[..., None] * 0.55
    colour = colour * (1.0 - rust) + RUST_TONE * rust
    colour = colour * (1.0 - seam[..., None]) + SEAM_TONE * seam[..., None]
    colour = colour * (1.0 - bolt[..., None]) + BOLT_TONE * bolt[..., None]
    ground.write_png(out / "wall_plates.png", ground.to_bytes(colour))
    warp = ground.fractal(SIZE, 8, 3, rng) * WARP
    height = warp - seam * SEAM_DEPTH + bolt * BOLT_HEIGHT
    ground.write_png(out / "wall_plates_normal.png", ground.to_bytes(tangent_normals(height,
            NORMAL_STRENGTH)))


main()
