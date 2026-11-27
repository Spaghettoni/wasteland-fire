"""Writes the layered-rock texture of the art overhaul (2026-11-26/27): a seamless 1024 px tile (12 m at the rock
material's scale) of smooth horizontal strata in red, peach and rust, the band edges gently wavy and each band faintly
mottled; no blocks (Martin, 2026-11-27: "nech to nie je ako minecraft"). Run: python3 tools/art/build_strata_texture.py"""
import numpy as np
from PIL import Image

SIZE = 1024
BANDS = np.array([(0.72, 0.36, 0.26), (0.86, 0.54, 0.38), (0.78, 0.44, 0.30), (0.92, 0.66, 0.46), (0.64, 0.31, 0.24), (0.84, 0.48, 0.34)])
rng = np.random.default_rng(7)
# Band boundaries down the tile; the tile repeats, so the last band runs into the first.
edges = np.sort(rng.uniform(0, SIZE, 9))
tones = rng.integers(0, len(BANDS), len(edges))
y, x = np.mgrid[0:SIZE, 0:SIZE].astype(float)
wave = 10 * np.sin(x / SIZE * 2 * np.pi * 2 + 1.3) + 5 * np.sin(x / SIZE * 2 * np.pi * 5 + 0.4)
yy = (y + wave) % SIZE
index = np.searchsorted(edges, yy) % len(edges)
img = BANDS[tones[index]]
# A soft mottle: low-frequency sines, seamless.
mottle = 1 + 0.05 * np.sin(x / SIZE * 2 * np.pi * 3 + y / SIZE * 2 * np.pi * 2) + 0.04 * np.sin(x / SIZE * 2 * np.pi * 7 - y / SIZE * 2 * np.pi * 4 + 2)
img = img * mottle[..., None]
# Darker just under each boundary: each band reads as a ledge.
d = np.min(np.abs(yy[..., None] - edges[None, None, :]), axis=-1)
img *= (1 - 0.18 * np.clip(1 - d / 6, 0, 1))[..., None]
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save("src/gameplay/maps/map_01/textures/rock_strata.png")
print("strata written")
