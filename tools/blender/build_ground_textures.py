"""Writes the ground's noise textures for Map 01 as PNG files: seamless (the noise is periodic, so a
tile repeats with no seam and no blended band), generated from fixed seeds, so a run always writes
the same files. Blender's own Python runs it for numpy; nothing of Blender is used:

    blender --background --factory-startup --python tools/blender/build_ground_textures.py -- \
        --out src/gameplay/maps/map_01/textures

The shader src/gameplay/maps/spatial_env_ground.gdshader samples them in world space at several
sizes (each tile size is a material's uniform); the rocks' spatial_env_rock.gdshader reads
ground_soft.png and ground_cells.png too. Every file is data, not colour: the shaders read the
numbers, so the game imports them as linear, lossless, with mipmaps.

    ground_soft.png          R, G: two smooth fractal noises (tones, swells, streaks); B: a fine one
                             (grain).
    ground_soft_normal.png   the relief of R: gentle swells.
    ground_cells.png         a periodic cell pattern, 24 cells a side: R the distance to the nearest
                             cell point (stones), G the gap to the second nearest (cracks along the
                             cell borders), B a random tone per cell (plates).
    ground_stones_normal.png the relief of round stones around each cell point.
    ground_cracks_normal.png the relief of the cracks: a groove along each border with a raised rim.

The relief maps hold a normal in world orientation for a level surface, not in tangent space: R is
its x, G its z (the texture's v runs along world z) and B its height, each mapped from -1..1.
"""

import struct
import sys
import zlib
from pathlib import Path

import numpy as np

# Pixels a side of every texture.
SIZE = 1024
# Cells a side of the cell pattern.
CELLS = 24
# Lattice cells a side of the coarsest octave of the fractal noises, and their octaves.
BASE_CELLS = 4
OCTAVES = 6
# Radius of a stone's dome in cell units, and the relief strengths (slope per unit of height).
STONE_RADIUS = 0.42
SWELL_STRENGTH = 10.0
STONE_STRENGTH = 7.0
CRACK_STRENGTH = 9.0


def parse_out():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return Path(argv[argv.index("--out") + 1]) if "--out" in argv else Path(".")


def gradient_noise(size, cells, rng):
    """Periodic gradient (Perlin-style) noise, cells lattice cells a side, about -0.7..0.7."""
    angles = rng.random((cells, cells)) * 2.0 * np.pi
    grads = np.stack([np.cos(angles), np.sin(angles)], axis=-1)
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    i1 = (i0 + 1) % cells
    fade = f * f * f * (f * (f * 6.0 - 15.0) + 10.0)
    fy, fx = np.meshgrid(f, f, indexing="ij")
    uy, ux = np.meshgrid(fade, fade, indexing="ij")

    def corner(iy, ix, oy, ox):
        g = grads[np.ix_(iy, ix)]
        return g[..., 0] * (fx - ox) + g[..., 1] * (fy - oy)

    n00, n01 = corner(i0, i0, 0.0, 0.0), corner(i0, i1, 0.0, 1.0)
    n10, n11 = corner(i1, i0, 1.0, 0.0), corner(i1, i1, 1.0, 1.0)
    top = n00 + (n01 - n00) * ux
    bottom = n10 + (n11 - n10) * ux
    return top + (bottom - top) * uy


def fractal(size, base_cells, octaves, rng, gain=0.5):
    """A periodic fractal sum of gradient noise, normalised to 0..1."""
    total = np.zeros((size, size))
    amplitude = 1.0
    for octave in range(octaves):
        total += gradient_noise(size, base_cells * 2 ** octave, rng) * amplitude
        amplitude *= gain
    low, high = np.percentile(total, 0.5), np.percentile(total, 99.5)
    return np.clip((total - low) / (high - low), 0.0, 1.0)


def cells(size, count, rng):
    """A periodic cell (Worley) pattern: the distance to the nearest and second-nearest cell point
    and a random value of the nearest point's cell, in cell units, for each pixel."""
    points = rng.random((count, count, 2))
    values = rng.random((count, count))
    coords = (np.arange(size) + 0.5) * count / size
    cy, cx = np.meshgrid(coords, coords, indexing="ij")
    iy, ix = np.floor(cy).astype(int), np.floor(cx).astype(int)
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    value = np.zeros((size, size))
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            ny, nx = iy + dy, ix + dx
            wy, wx = ny % count, nx % count
            distance = np.hypot(cy - (ny + points[wy, wx, 0]), cx - (nx + points[wy, wx, 1]))
            closer = distance < f1
            f2 = np.where(closer, f1, np.minimum(f2, distance))
            value = np.where(closer, values[wy, wx], value)
            f1 = np.where(closer, distance, f1)
    return f1, f2, value


def relief(height, strength):
    """A normal map in world orientation (R x, G z, B up) from a periodic height field 0..1 per
    pixel, its slopes scaled by strength."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dz = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
    normal = np.stack([-dx, -dz, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def to_bytes(channels):
    return (np.clip(channels, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def write_png(path, rgb):
    """Writes an 8-bit RGB PNG with the standard library: no colour management touches the
    numbers."""
    height, width, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[row].tobytes() for row in range(height))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    print("TEXTURE %s" % path)


def main():
    out = parse_out()
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261010)
    tone = fractal(SIZE, BASE_CELLS, OCTAVES, rng)
    second = fractal(SIZE, BASE_CELLS, OCTAVES, rng)
    grain = fractal(SIZE, BASE_CELLS * 8, 4, rng, gain=0.6)
    write_png(out / "ground_soft.png", to_bytes(np.stack([tone, second, grain], axis=-1)))
    write_png(out / "ground_soft_normal.png", to_bytes(relief(tone, SWELL_STRENGTH)))
    f1, f2, value = cells(SIZE, CELLS, rng)
    gap = f2 - f1
    write_png(out / "ground_cells.png", to_bytes(np.stack([f1 / 0.9, gap / 0.9, value], axis=-1)))
    dome = np.clip(1.0 - f1 / STONE_RADIUS, 0.0, 1.0)
    dome = np.sqrt(dome * (2.0 - dome))
    write_png(out / "ground_stones_normal.png", to_bytes(relief(dome, STONE_STRENGTH)))
    groove = np.clip(gap / 0.12, 0.0, 1.0)
    rim = np.exp(-((gap - 0.14) / 0.06) ** 2) * 0.35
    write_png(out / "ground_cracks_normal.png",
            to_bytes(relief(groove * 0.8 + rim, CRACK_STRENGTH)))


if __name__ == "__main__":
    main()
