"""Writes the stone-block wall textures of the art overhaul (2026-11-26): a seamless 1024 px tile of 8 blocks by 12
rows (rows offset by half a block), each block its own stone tone with a pixel grain, mortar seams and bevelled edges,
plus its normal map. Run: python3 tools/art/build_stone_texture.py (numpy, Pillow). Seeded."""
import numpy as np
from PIL import Image

SIZE, COLS, ROWS, MORTAR, BEVEL, GRAIN = 1024, 8, 12, 5, 9, 8
TONES = np.array([(0.52, 0.47, 0.46), (0.58, 0.52, 0.48), (0.47, 0.43, 0.43), (0.62, 0.56, 0.50), (0.55, 0.48, 0.44)])
MORTAR_TONE = np.array((0.28, 0.24, 0.23))
rng = np.random.default_rng(20261126)
bw, bh = SIZE / COLS, SIZE / ROWS
y, x = np.mgrid[0:SIZE, 0:SIZE].astype(float)
row = np.floor(y / bh)
shift = (row % 2) * bw * 0.5
col = np.floor(((x + shift) % SIZE) / bw)
lx = ((x + shift) % SIZE) - col * bw
ly = y - row * bh
block_id = (row * COLS + col).astype(int)
tone_of = rng.integers(0, len(TONES), ROWS * COLS)
lift_of = rng.uniform(0.9, 1.1, ROWS * COLS)
albedo = TONES[tone_of[block_id]] * lift_of[block_id][..., None]
# A pixel grain inside each block, GRAIN px squares.
gy, gx = (y // GRAIN).astype(int), (x // GRAIN).astype(int)
grain = rng.uniform(0.92, 1.08, (SIZE // GRAIN + 1, SIZE // GRAIN + 1))[gy, gx]
albedo *= grain[..., None]
d = np.minimum.reduce([lx, bw - lx, ly, bh - ly])
mortar = d < MORTAR
# Bevel: lighter toward the top-left edges, darker toward the bottom-right, inside BEVEL px of the seam.
edge = np.clip((BEVEL - (d - MORTAR)) / BEVEL, 0, 1) * (~mortar)
light = np.where((ly - MORTAR < BEVEL) | (lx - MORTAR < BEVEL), 1.12, 0.86)
albedo *= np.where(edge > 0, 1 + (light - 1) * edge, 1)[..., None]
albedo[mortar] = MORTAR_TONE
Image.fromarray((np.clip(albedo, 0, 1) ** (1 / 1.0) * 255).astype(np.uint8)).save("src/gameplay/maps/map_01/textures/stone_blocks.png")
# Normal map: the bevel tilts each edge outward; the mortar is level and sunk (flat).
nx = np.zeros_like(x); ny = np.zeros_like(y)
nx += np.where(lx < MORTAR + BEVEL, -1, 0) * edge + np.where(bw - lx < MORTAR + BEVEL, 1, 0) * edge
ny += np.where(ly < MORTAR + BEVEL, 1, 0) * edge + np.where(bh - ly < MORTAR + BEVEL, -1, 0) * edge
nx *= 0.6; ny *= 0.6
nz = np.ones_like(x)
n = np.stack([nx, ny, nz], -1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save("src/gameplay/maps/map_01/textures/stone_blocks_normal.png")
print("stone textures written")
