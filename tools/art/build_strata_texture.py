"""Writes the layered-rock texture of the art overhaul (2026-11-26): a seamless 1024 px tile (12 m at the rock material's
scale) of 0.6 m voxel blocks in horizontal bands of red, peach and rust, each block its own tone, with a pixel grain and
darker block edges, like the voxel mesas (assets/art/voxel/mesa_*.res). Run: python3 tools/art/build_strata_texture.py"""
import numpy as np
from PIL import Image

SIZE, BLOCKS = 1024, 20
BANDS = np.array([(0.72, 0.36, 0.26), (0.86, 0.54, 0.38), (0.78, 0.44, 0.30), (0.92, 0.66, 0.46), (0.64, 0.31, 0.24), (0.84, 0.48, 0.34)])
rng = np.random.default_rng(7)
px = SIZE // BLOCKS  # 51 px a block; the tile holds 20 blocks a side
rows = []
while len(rows) < BLOCKS:
    band = rng.integers(0, len(BANDS))
    rows += [band] * int(rng.integers(1, 4))
rows = np.array(rows[:BLOCKS])
img = np.zeros((SIZE, SIZE, 3))
for r in range(BLOCKS):
    for c in range(BLOCKS):
        tone = BANDS[rows[r]] * rng.uniform(0.9, 1.1)
        y0, x0 = r * px, c * px
        y1, x1 = (SIZE if r == BLOCKS - 1 else y0 + px), (SIZE if c == BLOCKS - 1 else x0 + px)
        block = np.ones((y1 - y0, x1 - x0, 1)) * tone
        g = rng.uniform(0.94, 1.06, ((y1 - y0) // 8 + 1, (x1 - x0) // 8 + 1))
        gy, gx = np.mgrid[0:y1 - y0, 0:x1 - x0] // 8
        block *= g[gy, gx][..., None]
        # Darker bottom and right edge, lighter top: each block reads as a cube.
        block[-3:, :] *= 0.72
        block[:, -3:] *= 0.8
        block[:3, :] *= 1.12
        img[y0:y1, x0:x1] = block
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save("src/gameplay/maps/map_01/textures/rock_strata.png")
print("strata written")
