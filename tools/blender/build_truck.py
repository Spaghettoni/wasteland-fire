"""Builds the Truck Unit's model in Blender and exports it as a .glb file (wasteland_kit.py says how
the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_truck.py -- \
        --out assets/art/vehicles/wasteland_truck/wasteland_truck.glb --previews <dir>

Since Story 063 the Truck type is the Flame Tank (Martin, 2026-11-22, with a picture he made: "vymenme
terajsi truck za toto"); Story 068 brought it closer to that picture ("nevyzera moc ako na obrazku. chcel
by som aby sa viac podobal"). The type keeps its id, truck, its file names and its collider.

Chunky and riveted like the picture: two heavy tracks with big road wheels and thick cleats under a
tall iron body; a Team hood with a big skull over a barred grille and a row of big iron spikes; a
flamethrower each side of the hood, thick barrels with brass rings; behind the hood the driver
standing in a spiked iron cage behind a rocket pod (the high fire); a long Team fuel drum with a skull
on the back deck; a flag pole at the back with a tattered Team pennant and a skull; exhausts with
fire at their mouths; pyramid spikes on every corner; brass rivets on the plates.

Sized to the Truck's collider (src/gameplay/units/data/truck_stats.tres: 2.4 m wide, 4.4 m long,
1.6 m tall): the tracks 2.4 m across, the spikes' tips at 2.2 m ahead; the cage, the drum, the driver
and the pole stand above it. Front toward +Y, metres, origin on the ground at the middle of the collider.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# The tracks: the middle of each across, their width, where they turn at the back and front, the top.
TRACK_X = 0.9
TRACK_W = 0.6
TRACK_FRONT = 1.85
TRACK_BACK = -1.95
TRACK_TOP = 0.88
# Where each track's ground run is flat on the ground, its back and front ends (the Truck's tyre contacts in
# truck_stats.tres stand here, read by the tyre_tracks scenario).
GROUND_BACK = -1.6
GROUND_FRONT = 1.5
WHEEL_R = 0.33
# The body between and over the tracks.
BODY_HALF = 0.78
BODY_BACK = -1.9
BODY_FRONT = 1.2
# The deck, low enough that the drum, the cage, the pod and the driver stay under 2.25 m: the Gyrocopter flies at 2.5 m
# with 0.25 m to spare over every ground body (story 015); only the flag pole and its pennant reach higher, thin parts the
# heights scenario knows (heights_kit.gd's THIN).
DECK_Z = 1.15
# The flamethrower barrels: across, their tips' y and their height.
NOZZLE_X = 0.72
NOZZLE_TIP_Y = 2.15
NOZZLE_Z = 1.02
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((4.6, 5.8, 3.4), (0.0, 0.25, 1.0), None),
    "rear_three_quarter": ((-4.8, -5.4, 3.6), (0.0, -0.3, 1.0), None),
    "side": ((8.0, 0.0, 1.6), (0.0, 0.0, 1.0), None),
    "top": ((0.0, -0.001, 14.0), (0.0, 0.0, 0.0), 7.2),
}


def spike(base, direction, size=1.0, key="steel"):
    """A four-sided iron pyramid, the picture's spikes."""
    kit.cone("spike", 0.1 * size, 0.3 * size, base, direction, key, segments=4)


def rivets(x, y0, y1, z, side, count, key="brass"):
    """A row of brass rivets on a face looking along ±X."""
    for k in range(count):
        y = y0 + (y1 - y0) * k / max(count - 1, 1)
        kit.cylinder("rivet", 0.03, 0.03, (x + side * 0.012, y, z), "X", key, segments=6)


def build_tracks():
    for side in (-1.0, 1.0):
        x0, x1 = side * TRACK_X - TRACK_W / 2.0, side * TRACK_X + TRACK_W / 2.0
        face = side * (TRACK_X + TRACK_W / 2.0)
        profile = [(TRACK_BACK, 0.3), (GROUND_BACK, 0.0), (GROUND_FRONT, 0.0), (TRACK_FRONT, 0.32),
                (TRACK_FRONT, 0.6), (TRACK_FRONT - 0.3, TRACK_TOP), (TRACK_BACK + 0.3, TRACK_TOP),
                (TRACK_BACK, 0.62)]
        kit.prism_x("track_belt", profile, min(x0, x1), max(x0, x1), "tread", bevel=0.04)
        # Thick cleats on the top run and the ground run.
        y = TRACK_BACK + 0.3
        while y < TRACK_FRONT - 0.25:
            kit.box("track_cleat", (TRACK_W + 0.02, 0.16, 0.09), (side * TRACK_X, y, TRACK_TOP + 0.02),
                    "rubber", bevel=0.015)
            y += 0.3
        y = GROUND_BACK + 0.05
        while y < GROUND_FRONT:
            kit.box("track_shoe", (TRACK_W - 0.02, 0.16, 0.06), (side * TRACK_X, y, 0.03), "rubber",
                    bevel=0.01)
            y += 0.3
        # Four big road wheels and the sprockets at the ends, on the outer face.
        for k in range(4):
            wy = GROUND_BACK + 0.25 + k * (GROUND_FRONT - GROUND_BACK - 0.5) / 3.0
            kit.cylinder("road_wheel", WHEEL_R, 0.1, (face + side * 0.03, wy, WHEEL_R + 0.06), "X",
                    "gunmetal", segments=10, bevel=0.02)
            kit.cylinder("road_rim", WHEEL_R * 0.72, 0.04, (face + side * 0.085, wy, WHEEL_R + 0.06), "X",
                    "rust_dark", segments=10)
            kit.cylinder("road_hub", WHEEL_R * 0.3, 0.06, (face + side * 0.11, wy, WHEEL_R + 0.06), "X",
                    "brass", segments=6, bevel=0.01)
        for wy in (TRACK_FRONT - 0.2, TRACK_BACK + 0.2):
            kit.cylinder("sprocket", 0.3, 0.1, (face + side * 0.03, wy, 0.48), "X", "steel_dark",
                    segments=8, bevel=0.02)
            for k in range(8):
                a = 2.0 * math.pi * k / 8
                kit.box("sprocket_tooth", (0.11, 0.08, 0.08),
                        (face + side * 0.03, wy + math.cos(a) * 0.32, 0.48 + math.sin(a) * 0.32), "steel_dark")
            kit.cylinder("sprocket_hub", 0.1, 0.06, (face + side * 0.09, wy, 0.48), "X", "brass", segments=6)


def build_body():
    # The tall iron body over the tracks: a lower hull and the upper body, in riveted plates.
    kit.box("hull", (2 * BODY_HALF - 0.1, BODY_FRONT - BODY_BACK, 0.5),
            (0.0, (BODY_FRONT + BODY_BACK) / 2.0, 0.65), "gunmetal", bevel=0.04)
    kit.box("upper", (2 * BODY_HALF + 0.5, BODY_FRONT - BODY_BACK - 0.1, 0.3),
            (0.0, (BODY_FRONT + BODY_BACK) / 2.0 - 0.05, DECK_Z - 0.15), "rust_dark", bevel=0.04)
    for side in (-1.0, 1.0):
        x = side * (BODY_HALF + 0.25)
        for k, (y0, y1) in enumerate(((-1.85, -0.85), (-0.8, 0.2), (0.25, 1.1))):
            kit.box("side_plate", (0.05, y1 - y0, 0.26), (x + side * 0.02, (y0 + y1) / 2.0, DECK_Z - 0.15),
                    "accent_dark" if k == 1 else "scrap", bevel=0.015)
            rivets(x + side * 0.045, y0 + 0.08, y1 - 0.08, DECK_Z - 0.08, side, 4)
            rivets(x + side * 0.045, y0 + 0.08, y1 - 0.08, DECK_Z - 0.23, side, 4)
        # Big spikes along the top edge, pointing out and up.
        for y in (-1.75, -0.95, -0.15, 0.65):
            spike((x, y, DECK_Z), (side * 0.5, 0.0, 1.0), 1.1)
    kit.box("deck", (2 * BODY_HALF + 0.4, BODY_FRONT - BODY_BACK - 0.2, 0.06), (0.0, -0.4, DECK_Z), "steel_dark",
            bevel=0.02)


def build_front():
    # The Team hood sloping down to the grille, a big skull on it, and the spiked ram.
    # The hood stands clear of the flamer mounts and the lamps: the occlusion bake reads a part at its corners only, and
    # a corner tucked under a neighbour would darken the whole face.
    kit.prism_x("hood", [(0.95, DECK_Z + 0.08), (1.95, DECK_Z - 0.28), (1.95, 0.75), (0.95, 0.75)],
            -0.55, 0.55, "accent", bevel=0.04)
    skull = kit.pixel_plate("skull_front", kit.SKULL_ROWS, 0.028, (0.0, 0.0, 0.0), 1.0, 0.016, "bone_white")
    kit.rotate_parts([skull], (0.0, 0.0, 0.0), (0.0, -70.0, 90.0))
    skull.data.transform(kit.Matrix.Translation((0.0, 1.47, DECK_Z - 0.08)))
    kit.box("grille_frame", (1.2, 0.1, 0.5), (0.0, 1.99, 0.62), "gunmetal", bevel=0.03)
    for k in range(9):
        gx = -0.48 + k * 0.12
        kit.box("grille_bar", (0.05, 0.06, 0.42), (gx, 2.05, 0.62), "steel_dark")
    for gx in (-0.55, 0.55):
        kit.cylinder("grille_rivet", 0.035, 0.03, (gx, 2.05, 0.82), "Y", "brass", segments=6)
    kit.box("ram_bar", (2.3, 0.18, 0.2), (0.0, 2.0, 0.3), "steel_dark", bevel=0.03)
    for rx, s in ((-0.85, 1.3), (-0.3, 1.5), (0.3, 1.5), (0.85, 1.3)):
        spike((rx, 2.05, 0.3), (0.0, 1.0, 0.05), s)
    for side in (-1.0, 1.0):
        kit.cylinder("lamp_housing", 0.09, 0.08, (side * 0.32, 0.86, DECK_Z + 0.5), "Y", "gunmetal",
                segments=10, bevel=0.01)
        kit.cylinder("lamp", 0.065, 0.02, (side * 0.32, 0.91, DECK_Z + 0.5), "Y", "lamp", segments=10)


def build_flamers():
    for side in (-1.0, 1.0):
        x = side * NOZZLE_X
        kit.box("flamer_mount", (0.32, 0.6, 0.34), (x, 1.0, NOZZLE_Z), "steel_dark", bevel=0.04)
        rivets(x + side * 0.16, 0.8, 1.2, NOZZLE_Z + 0.08, side, 3)
        kit.tube("flamer_barrel", (x, 1.2, NOZZLE_Z), (x, NOZZLE_TIP_Y - 0.12, NOZZLE_Z), 0.12, "gunmetal",
                segments=10)
        for ry in (1.4, 1.75):
            kit.cylinder("flamer_ring", 0.145, 0.07, (x, ry, NOZZLE_Z), "Y", "brass", segments=10)
        kit.cylinder("flamer_muzzle", 0.17, 0.18, (x, NOZZLE_TIP_Y - 0.09, NOZZLE_Z), "Y", "steel",
                segments=10, bevel=0.02)
        kit.cylinder("flamer_mouth", 0.11, 0.02, (x, NOZZLE_TIP_Y + 0.01, NOZZLE_Z), "Y", "hole", segments=10)
        kit.box("pilot_light", (0.08, 0.08, 0.08), (x, NOZZLE_TIP_Y - 0.03, NOZZLE_Z - 0.19), "lamp")
        kit.tube("feed_hose", (x, 0.75, NOZZLE_Z + 0.05), (side * 0.3, -0.6, DECK_Z + 0.25), 0.05, "rubber",
                segments=6)


def build_back():
    # The long fuel drum in Team paint, in pieces between darker bands, a skull each side.
    y = -1.85
    for length, key in ((0.1, "accent_dark"), (0.45, "accent"), (0.1, "accent_dark"), (0.45, "accent"),
            (0.1, "accent_dark"), (0.25, "accent")):
        kit.cylinder("drum", 0.42 if key == "accent" else 0.44, length, (0.0, y + length / 2.0, DECK_Z + 0.44), "Y",
                key, segments=12, bevel=0.02)
        y += length
    for side in (-1.0, 1.0):
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.022, (side * 0.42, -1.05, DECK_Z + 0.44), side, 0.014,
                "bone_white")
        kit.box("drum_cradle", (0.12, 1.5, 0.2), (side * 0.34, -1.1, DECK_Z + 0.1), "steel_dark", bevel=0.02)
    kit.cylinder("drum_cap", 0.09, 0.08, (0.0, -1.5, DECK_Z + 0.88), "Z", "brass", segments=8)
    # Exhausts at the back corners with fire at their mouths; spikes on the back corners.
    for side in (-1.0, 1.0):
        # The fire's top stands at 2.204 m, the tallest ground body: story 015's flying-height rule (that top + 0.25 m,
        # rounded up to 0.05 m) still gives the Gyrocopter's 2.5 m.
        kit.tube("exhaust", (side * 0.85, -1.8, 1.0), (side * 0.85, -1.8, 2.06), 0.08, "gunmetal", segments=8)
        kit.cylinder("exhaust_ring", 0.1, 0.06, (side * 0.85, -1.8, 1.92), "Z", "brass", segments=8)
        kit.box("exhaust_fire", (0.12, 0.12, 0.14), (side * 0.85, -1.8, 2.134), "lamp")
        spike((side * 1.02, -1.9, DECK_Z), (side * 0.4, -0.4, 1.0), 1.0)
    # The flag pole at the back right, a spike on top, a tattered Team pennant with a skull.
    pole_x, pole_y = 0.62, -1.55
    kit.tube("flag_pole", (pole_x, pole_y, DECK_Z), (pole_x, pole_y, DECK_Z + 1.9), 0.035, "gunmetal", segments=6)
    spike((pole_x, pole_y, DECK_Z + 1.9), (0.0, 0.0, 1.0), 0.8)
    kit.prism_x("pennant", [(pole_y - 0.02, DECK_Z + 1.85), (pole_y - 0.75, DECK_Z + 1.78),
            (pole_y - 0.6, DECK_Z + 1.6), (pole_y - 0.78, DECK_Z + 1.44), (pole_y - 0.02, DECK_Z + 1.4)],
            pole_x - 0.012, pole_x + 0.012, "accent")
    kit.pixel_plate("pennant_skull", kit.SKULL_ROWS, 0.016, (pole_x + 0.014, pole_y - 0.36, DECK_Z + 1.62), 1.0,
            0.006, "bone_white")
    kit.pixel_plate("pennant_skull", kit.SKULL_ROWS, 0.016, (pole_x - 0.014, pole_y - 0.36, DECK_Z + 1.62), -1.0,
            0.006, "bone_white")


def build_cage():
    # The driver's spiked iron cage behind the hood, the pintle with the rocket pod, and the driver.
    cy, half_x, half_y, top = 0.35, 0.5, 0.45, DECK_Z + 0.75
    kit.box("cage_floor", (2 * half_x + 0.1, 2 * half_y + 0.1, 0.08), (0.0, cy, DECK_Z + 0.04), "steel_dark",
            bevel=0.02)
    kit.box("cage_front", (2 * half_x, 0.06, 0.4), (0.0, cy + half_y, DECK_Z + 0.24), "accent_dark", bevel=0.015)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            post = (sx * half_x, cy + sy * half_y)
            kit.tube("cage_post", (post[0], post[1], DECK_Z), (post[0], post[1], top), 0.04, "gunmetal", segments=6)
            spike((post[0], post[1], top), (sx * 0.2, sy * 0.2, 1.0), 0.9)
    for sx in (-1.0, 1.0):
        kit.tube("cage_rail", (sx * half_x, cy - half_y, top - 0.05), (sx * half_x, cy + half_y, top - 0.05), 0.03,
                "gunmetal", segments=6)
        kit.tube("cage_rail_low", (sx * half_x, cy - half_y, DECK_Z + 0.4), (sx * half_x, cy + half_y, DECK_Z + 0.4),
                0.03, "gunmetal", segments=6)
    for sy in (-1.0, 1.0):
        kit.tube("cage_rail", (-half_x, cy + sy * half_y, top - 0.05), (half_x, cy + sy * half_y, top - 0.05), 0.03,
                "gunmetal", segments=6)
    # The pod sits low on its pintle, so the driver's head and shoulders show over it from every side.
    pod_z = DECK_Z + 0.55
    kit.tube("pintle", (0.0, cy + 0.42, DECK_Z + 0.1), (0.0, cy + 0.42, pod_z - 0.12), 0.05, "gunmetal", segments=8)
    kit.box("pod", (0.4, 0.6, 0.24), (0.0, cy + 0.62, pod_z), "accent_dark", bevel=0.03)
    kit.box("pod_band", (0.42, 0.08, 0.26), (0.0, cy + 0.47, pod_z), "brass", bevel=0.01)
    for px in (-0.1, 0.1):
        for pz in (-0.055, 0.055):
            kit.cylinder("pod_tube", 0.05, 0.03, (px, cy + 0.93, pod_z + pz), "Y", "hole", segments=8)
    kit.driver((0.0, cy - 0.08, DECK_Z + 0.08), ((-0.17, cy + 0.36, pod_z + 0.08), (0.17, cy + 0.36, pod_z + 0.08)),
            lean=12.0, legs="none", scale=1.1)


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_tracks()
    build_body()
    build_front()
    build_flamers()
    build_back()
    build_cage()
    # A short occlusion reach: the drum, the cage and the driver stand close together on the deck.
    kit.finish(args["out"], args["previews"], VIEWS, ao_distance=0.22)


main()
