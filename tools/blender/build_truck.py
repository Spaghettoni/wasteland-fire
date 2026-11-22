"""Builds the Truck Unit's model in Blender and exports it as a .glb file (wasteland_kit.py says how
the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_truck.py -- \
        --out assets/art/vehicles/wasteland_truck/wasteland_truck.glb --previews <dir>

Since Story 063 the Truck type is the Flame Tank (Martin, 2026-11-22, with a picture he made: "vymenme
terajsi truck za toto", tracked, a flamethrower, "paci sa mi aj to ze tam je ten panak hore"); the
type keeps its id, truck, its file names and its collider. A low riveted hull on two tracks with road
wheels and spiked guards; a sloped Team glacis with a skull over a barred grille and a ram of spikes;
a flamethrower nozzle each side of the grille with a pilot light; a Team fuel drum with skulls on the
back deck; exhaust stacks; and on top the driver (wasteland_kit.driver) behind a rocket pod on a
pintle, for the high fire.

Sized to the Truck's collider (src/gameplay/units/data/truck_stats.tres: 2.4 m wide, 4.4 m long,
1.6 m tall): the tracks 2.4 m across, the ram's tips at 2.2 m ahead, the deck at 1.15 m, the drum's
top at 1.9 m and the driver's helmet near 2.2 m. Front toward +Y, metres, origin on the ground at the
middle of the collider.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# The tracks: the middle of each across, their width, the length of the ground run and the height.
TRACK_X = 0.95
TRACK_W = 0.5
TRACK_FRONT = 1.75
TRACK_BACK = -1.85
TRACK_TOP = 0.78
# Where each track's ground run is flat on the ground, its back and front ends (the Truck's tyre contacts in
# truck_stats.tres stand here, read by the tyre_tracks scenario).
GROUND_BACK = -1.6
GROUND_FRONT = 1.5
WHEEL_R = 0.26
# The hull between the tracks.
HULL_HALF = 0.7
DECK_Z = 1.15
# The flamethrower nozzles: across, their tips' y and their height.
NOZZLE_X = 0.62
NOZZLE_TIP_Y = 2.12
NOZZLE_Z = 0.82
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((4.6, 5.8, 3.2), (0.0, 0.25, 0.9), None),
    "rear_three_quarter": ((-4.8, -5.4, 3.4), (0.0, -0.3, 0.9), None),
    "side": ((8.0, 0.0, 1.4), (0.0, 0.0, 0.9), None),
    "top": ((0.0, -0.001, 14.0), (0.0, 0.0, 0.0), 7.2),
}


def build_tracks():
    for side in (-1.0, 1.0):
        x0, x1 = side * TRACK_X - TRACK_W / 2.0, side * TRACK_X + TRACK_W / 2.0
        # The belt seen from the side: a long loop, raised at the front and the back.
        profile = [(TRACK_BACK, 0.1), (GROUND_BACK, 0.0), (GROUND_FRONT, 0.0),
                (TRACK_FRONT + 0.12, 0.2), (TRACK_FRONT + 0.12, 0.5), (TRACK_FRONT - 0.15, TRACK_TOP - 0.06),
                (TRACK_BACK + 0.1, TRACK_TOP - 0.06), (TRACK_BACK - 0.12, 0.45)]
        kit.prism_x("track_belt", profile, min(x0, x1), max(x0, x1), "tread", bevel=0.03)
        # Tread blocks on the top run and across the ground run's ends.
        y = TRACK_BACK + 0.15
        while y < TRACK_FRONT - 0.1:
            kit.box("track_cleat", (TRACK_W + 0.04, 0.12, 0.05), (side * TRACK_X, y, TRACK_TOP - 0.04),
                    "rubber", bevel=0.01)
            kit.box("track_shoe", (TRACK_W - 0.02, 0.12, 0.05), (side * TRACK_X, y, 0.02), "rubber",
                    bevel=0.01)
            y += 0.26
        # Road wheels, sprocket and idler on the outer face.
        face = side * (TRACK_X + TRACK_W / 2.0)
        for k in range(5):
            wy = TRACK_BACK + 0.45 + k * (TRACK_FRONT - TRACK_BACK - 0.8) / 4.0
            kit.cylinder("road_wheel", WHEEL_R, 0.08, (face + side * 0.02, wy, WHEEL_R + 0.04), "X",
                    "gunmetal", segments=10, bevel=0.015)
            kit.cylinder("road_hub", WHEEL_R * 0.35, 0.06, (face + side * 0.06, wy, WHEEL_R + 0.04), "X",
                    "steel", segments=8, bevel=0.008)
        for wy, wz, r in ((TRACK_FRONT - 0.05, 0.38, 0.28), (TRACK_BACK + 0.02, 0.36, 0.27)):
            kit.cylinder("sprocket", r, 0.09, (face + side * 0.02, wy, wz), "X", "steel_dark",
                    segments=8, bevel=0.015)
            for k in range(8):
                a = 2.0 * math.pi * k / 8
                kit.box("sprocket_tooth", (0.08, 0.07, 0.07),
                        (face + side * 0.02, wy + math.cos(a) * (r + 0.02), wz + math.sin(a) * (r + 0.02)),
                        "steel_dark")
        # The guard over the track, with rivets and a row of spikes.
        kit.box("track_guard", (TRACK_W + 0.12, TRACK_FRONT - TRACK_BACK + 0.2, 0.08),
                (side * TRACK_X, (TRACK_FRONT + TRACK_BACK) / 2.0, TRACK_TOP + 0.06), "rust_dark",
                bevel=0.02)
        kit.box("guard_skirt", (0.06, TRACK_FRONT - TRACK_BACK + 0.1, 0.26),
                (face + side * 0.03, (TRACK_FRONT + TRACK_BACK) / 2.0, TRACK_TOP - 0.06), "accent_dark",
                bevel=0.015)
        for k in range(7):
            ry = TRACK_BACK + 0.2 + k * 0.55
            kit.cylinder("rivet", 0.025, 0.02, (face + side * 0.065, ry, TRACK_TOP - 0.06), "X", "steel",
                    segments=6)
        for ry in (TRACK_BACK + 0.2, -0.3, TRACK_FRONT - 0.2):
            kit.cone("guard_spike", 0.06, 0.24, (side * (TRACK_X + 0.12), ry, TRACK_TOP + 0.1),
                    (side * 0.3, 0.0, 1.0), "steel")


def build_hull():
    # The hull between the tracks, and the deck plate.
    kit.box("hull", (2 * HULL_HALF, 3.3, DECK_Z - 0.3), (0.0, -0.2, 0.3 + (DECK_Z - 0.3) / 2.0),
            "scrap", bevel=0.04)
    kit.box("deck", (2 * HULL_HALF + 0.2, 2.2, 0.06), (0.0, -0.75, DECK_Z), "gunmetal", bevel=0.02)
    # Welded plates and rivets on the hull's sides.
    for side in (-1.0, 1.0):
        for k, py in enumerate((-1.4, -0.6, 0.2, 1.0)):
            kit.box("hull_plate", (0.04, 0.7, 0.32), (side * (HULL_HALF + 0.02), py, 0.92),
                    "rust_dark" if k % 2 else "accent", bevel=0.01)
    # The sloped glacis in Team paint, a skull on it, and the barred grille under it.
    kit.prism_x("glacis", [(1.45, DECK_Z), (2.0, 0.78), (2.0, 0.62), (1.45, 0.62)], -HULL_HALF,
            HULL_HALF, "accent", bevel=0.03)
    kit.box("glacis_band", (2 * HULL_HALF + 0.02, 0.1, 0.06), (0.0, 1.5, DECK_Z - 0.01), "accent_dark",
            bevel=0.015)
    skull = kit.pixel_plate("skull_front", kit.SKULL_ROWS, 0.018, (0.0, 0.0, 0.0), 1.0, 0.012,
            "bone_white")
    kit.rotate_parts([skull], (0.0, 0.0, 0.0), (0.0, -56.0, 90.0))
    skull.data.transform(kit.Matrix.Translation((0.0, 1.74, 0.97)))
    kit.box("grille_frame", (0.9, 0.08, 0.42), (0.0, 2.02, 0.5), "gunmetal", bevel=0.02)
    for k in range(7):
        gx = -0.36 + k * 0.12
        kit.tube("grille_bar", (gx, 2.06, 0.32), (gx, 2.06, 0.7), 0.025, "steel_dark", segments=6)
    # The ram: a bar across the front with big spikes.
    kit.box("ram_bar", (2.2, 0.16, 0.16), (0.0, 2.04, 0.3), "steel_dark", bevel=0.03)
    for rx in (-0.95, -0.5, 0.0, 0.5, 0.95):
        kit.cone("ram_spike", 0.1, 0.34, (rx, 2.08, 0.3), (0.0, 1.0, 0.05), "steel", segments=6)
    # Two lamps over the glacis.
    for side in (-1.0, 1.0):
        kit.cylinder("lamp_housing", 0.08, 0.08, (side * 0.5, 1.42, DECK_Z + 0.12), "Y", "gunmetal",
                segments=10, bevel=0.01)
        kit.cylinder("lamp", 0.06, 0.02, (side * 0.5, 1.47, DECK_Z + 0.12), "Y", "lamp", segments=10)


def build_flamers():
    for side in (-1.0, 1.0):
        x = side * NOZZLE_X
        kit.box("flamer_mount", (0.26, 0.5, 0.26), (x, 1.62, NOZZLE_Z), "steel_dark", bevel=0.03)
        kit.tube("flamer_barrel", (x, 1.5, NOZZLE_Z), (x, NOZZLE_TIP_Y - 0.08, NOZZLE_Z), 0.09,
                "gunmetal", segments=10)
        kit.cylinder("flamer_muzzle", 0.13, 0.14, (x, NOZZLE_TIP_Y - 0.06, NOZZLE_Z), "Y", "steel",
                segments=10, bevel=0.015)
        kit.cylinder("flamer_mouth", 0.085, 0.02, (x, NOZZLE_TIP_Y + 0.01, NOZZLE_Z), "Y", "hole",
                segments=10)
        # The pilot light under the mouth and the feed hose back to the drum.
        kit.box("pilot_light", (0.07, 0.07, 0.07), (x, NOZZLE_TIP_Y - 0.02, NOZZLE_Z - 0.15), "lamp")
        kit.tube("feed_hose", (x, 1.4, NOZZLE_Z + 0.05), (side * 0.42, -0.1, DECK_Z + 0.2), 0.045,
                "rubber", segments=6)


def build_drum():
    # The fuel drum on the back deck in Team paint, bands, skulls on its ends' sides.
    # In pieces, Team paint between darker bands, end to end: a band laid over the drum would darken it (the occlusion
    # bake reads each piece at its two ends only).
    y = -1.7
    for length, key in ((0.1, "accent_dark"), (0.5, "accent"), (0.1, "accent_dark"), (0.5, "accent"),
            (0.1, "accent_dark"), (0.2, "accent")):
        kit.cylinder("drum", 0.44 if key == "accent" else 0.455, length, (0.0, y + length / 2.0, DECK_Z + 0.46), "Y",
                key, segments=12, bevel=0.02)
        y += length
    for side in (-1.0, 1.0):
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.02, (side * 0.44, -0.65, DECK_Z + 0.46), side, 0.012,
                "bone_white")
        kit.box("drum_cradle", (0.12, 1.6, 0.18), (side * 0.36, -0.95, DECK_Z + 0.08), "steel_dark",
                bevel=0.02)
    kit.cylinder("drum_cap", 0.09, 0.08, (0.0, -1.2, DECK_Z + 0.92), "Z", "steel", segments=8)
    # Exhaust stacks at the back corners, spikes on the deck's corners.
    for side in (-1.0, 1.0):
        kit.tube("exhaust", (side * 0.62, -1.75, 0.9), (side * 0.62, -1.75, 1.95), 0.07, "gunmetal",
                segments=8)
        kit.cylinder("exhaust_hole", 0.05, 0.02, (side * 0.62, -1.75, 1.96), "Z", "hole", segments=8)
        kit.cone("deck_spike", 0.06, 0.22, (side * 1.05, -1.75, DECK_Z + 0.04), (0.0, 0.0, 1.0), "steel")


def build_turret():
    # The driver's ring on top, the pintle with the rocket pod (the high fire) and the driver.
    kit.cylinder("ring", 0.5, 0.12, (0.0, 0.45, DECK_Z + 0.06), "Z", "steel_dark", segments=12,
            bevel=0.02)
    kit.box("ring_shield", (0.9, 0.08, 0.3), (0.0, 0.92, DECK_Z + 0.25), "accent_dark", bevel=0.02)
    for side in (-1.0, 1.0):
        kit.cone("shield_spike", 0.05, 0.2, (side * 0.38, 0.92, DECK_Z + 0.4), (0.0, 0.2, 1.0), "steel")
    kit.tube("pintle", (0.0, 0.85, DECK_Z + 0.1), (0.0, 0.85, DECK_Z + 0.62), 0.05, "gunmetal",
            segments=8)
    kit.box("pod", (0.42, 0.62, 0.3), (0.0, 1.02, DECK_Z + 0.74), "accent_dark", bevel=0.03)
    for px in (-0.1, 0.1):
        for pz in (-0.07, 0.07):
            kit.cylinder("pod_tube", 0.06, 0.03, (px, 1.34, DECK_Z + 0.74 + pz), "Y", "hole", segments=8)
    kit.driver((0.0, 0.35, DECK_Z + 0.16), ((-0.2, 0.78, DECK_Z + 0.68), (0.2, 0.78, DECK_Z + 0.68)),
            lean=10.0, legs="none", scale=1.15)


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_tracks()
    build_hull()
    build_flamers()
    build_drum()
    build_turret()
    # A short occlusion reach: the drum, the ring and the driver stand close together on the deck.
    kit.finish(args["out"], args["previews"], VIEWS, ao_distance=0.22)


main()
