"""Builds the Motorbike Unit's model in Blender and exports it as a .glb file (wasteland_kit.py says
how the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_motorbike.py -- \
        --out assets/art/vehicles/wasteland_motorbike/wasteland_motorbike.glb --previews <dir>

The MOTORKA panel of the concept sheet (assets/art/vehicles/vehicle-design.png) in the game's
rules: one Team colour (the Accent, in two tones) and neutral metal and rubber. A dirt bike on fat
knobby tyres: a Team tank with a skull on each flank and the cream heading cue on top (a lamp part,
so the Motorbike's front reads from above, as the kit model's tank-top plate did), a darker Team
frame, Team fenders, a round headlamp in a Team bezel under a row of spikes, flat bars, a dark
V-twin with an exhaust low on the right and one swept up on the left, a dark saddle and a Team tail
cowl with two spikes over the rear wheel.

Sized to the Motorbike's collider (src/gameplay/units/data/motorbike_stats.tres: 1.4 m wide,
2.6 m long, 1.0 m tall): about 2.34 m from tyre to tyre, 0.76 m across the bars, the bars at
1.19 m. Front toward +Y, metres, origin on the ground at the middle of the collider.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# Wheels: the axles' y, the radius to the tread, the tyre's width and the height of its section.
FRONT_Y = 0.76
FRONT_R = 0.41
FRONT_W = 0.2
REAR_Y = -0.72
REAR_R = 0.43
REAR_W = 0.25
SECTION = 0.09
# The steering head: the top of the fork axis, which runs from here to the front axle.
HEAD = (0.0, 0.44, 1.02)
# The tank: (y, half-width, bottom, top) sections from the steering head back to the saddle.
TANK = ((0.45, 0.11, 0.88, 1.01), (0.34, 0.205, 0.80, 1.06), (0.04, 0.22, 0.79, 1.06),
        (-0.14, 0.155, 0.83, 0.99))
# The occlusion bake's reach: about the tyres' section, less than the larger models' wheels.
AO_DISTANCE = 0.3
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((2.3, 3.0, 1.45), (0.0, 0.05, 0.6), None),
    "rear_three_quarter": ((-2.4, -2.8, 1.65), (0.0, -0.1, 0.6), None),
    "side": ((4.6, 0.0, 0.75), (0.0, 0.0, 0.6), None),
    "top": ((0.0, -0.001, 8.0), (0.0, 0.0, 0.0), 4.0),
}


def fork_point(t, x=0.0):
    """A point on the fork axis: t 0 at the steering head, 1 at the front axle (beyond either end
    outside 0..1), x across."""
    return (x, HEAD[1] + t * (FRONT_Y - HEAD[1]), HEAD[2] + t * (FRONT_R - HEAD[2]))


# The fork's rake back from vertical, degrees: a plate across the fork is tilted by it about X.
RAKE = math.degrees(math.atan2(FRONT_Y - HEAD[1], HEAD[2] - FRONT_R))


def bike_wheel(prefix, y, radius, width, disc_side):
    """A spoked wheel on a fat knobby tyre, its axle along X at height radius (the tread touches
    the ground): the tyre a ring of rounded section with tread blocks staggered across it, a Team
    rim hoop, a hub, spokes and a disc on the disc_side face (1 or -1)."""
    centre = (0.0, y, radius)
    tread = radius - 0.02
    kit.torus(prefix + "_tyre", tread - SECTION, SECTION, centre, "X", "rubber", segments=20,
            section_width=width / 2.0)
    lugs = 22
    for k in range(lugs):
        a = 2.0 * math.pi * k / lugs
        shift = (0.18 if k % 2 == 0 else -0.18) * width
        at = (shift, y + math.cos(a) * (radius - 0.025), radius + math.sin(a) * (radius - 0.025))
        kit.box("%s_lug%d" % (prefix, k), (width * 0.64, 0.085, 0.05), at, "tread", bevel=0.012,
                rotation=(math.degrees(a) + 90.0, 0.0, 0.0))
    rim = tread - 2.0 * SECTION + 0.012
    kit.torus(prefix + "_rim", rim, 0.022, centre, "X", "rim", segments=20, section_segments=6)
    kit.cylinder(prefix + "_hub", 0.06, width * 0.8, centre, "X", "gunmetal", segments=10,
            bevel=0.01)
    kit.cylinder(prefix + "_axle_nut", 0.025, width * 0.8 + 0.06, centre, "X", "steel",
            segments=6)
    for k in range(10):
        a = 2.0 * math.pi * k / 10 + 0.15
        side = 1.0 if k % 2 == 0 else -1.0
        kit.tube(prefix + "_spoke", (side * width * 0.3, y + math.cos(a) * 0.05,
                radius + math.sin(a) * 0.05), (side * 0.01, y + math.cos(a + 0.3) * rim,
                radius + math.sin(a + 0.3) * rim), 0.006, "steel_dark", segments=4)
    kit.cylinder(prefix + "_disc", rim * 0.62, 0.012, (disc_side * width * 0.42, y, radius), "X",
            "steel", segments=16)


def build_wheels():
    bike_wheel("front", FRONT_Y, FRONT_R, FRONT_W, 1.0)
    bike_wheel("rear", REAR_Y, REAR_R, REAR_W, -1.0)
    # The rear sprocket on the left, opposite the disc.
    kit.cylinder("sprocket", 0.12, 0.014, (0.145, REAR_Y, REAR_R), "X", "steel_dark",
            segments=14)


def build_frame():
    tube_r = 0.042
    kit.tube("spine", (0.0, 0.42, 0.99), (0.0, -0.24, 0.88), tube_r, "accent_dark")
    kit.tube("down_tube", (0.0, 0.41, 0.94), (0.0, 0.25, 0.36), tube_r, "accent_dark")
    kit.cylinder("head_tube", 0.05, 0.2, HEAD, "Z", "accent_dark", segments=10)
    for side in (-1.0, 1.0):
        kit.tube("cradle_joint", (0.0, 0.25, 0.36), (side * 0.09, 0.22, 0.3), 0.028,
                "accent_dark")
        kit.tube("cradle", (side * 0.09, 0.22, 0.3), (side * 0.09, -0.24, 0.3), 0.028,
                "accent_dark")
        kit.tube("rear_upright", (side * 0.09, -0.24, 0.3), (side * 0.1, -0.24, 0.88), 0.03,
                "accent_dark")
        kit.tube("seat_rail", (side * 0.1, -0.24, 0.87), (side * 0.08, -0.86, 0.92), 0.022,
                "accent_dark")
        # The swingarm from its pivot back to the rear axle, and a shock with a Team spring.
        kit.tube("swingarm", (side * 0.11, -0.24, 0.42), (side * 0.15, REAR_Y, REAR_R), 0.03,
                "gunmetal")
        low, high = (side * 0.14, -0.56, 0.45), (side * 0.105, -0.4, 0.88)
        kit.tube("shock", low, high, 0.014, "steel_dark", segments=6)
        mid_low = tuple(a + (b - a) * 0.25 for a, b in zip(low, high))
        mid_high = tuple(a + (b - a) * 0.75 for a, b in zip(low, high))
        kit.tube("spring", mid_low, mid_high, 0.034, "accent", segments=8)
        kit.cylinder("peg", 0.018, 0.12, (side * 0.2, -0.1, 0.34), "X", "steel", segments=6)
    kit.cylinder("pivot", 0.03, 0.3, (0.0, -0.24, 0.42), "X", "gunmetal", segments=8)


def _cylinder_group(prefix, base, tilt):
    """One finned cylinder of the V-twin, standing on base and tilted by tilt degrees about X
    (positive leans it forward)."""
    x, y, z = base
    parts = [kit.cylinder(prefix + "_barrel", 0.07, 0.2, (x, y, z + 0.1), "Z", "steel_dark",
            segments=12)]
    for k in range(4):
        parts.append(kit.box(prefix + "_fin", (0.19, 0.19, 0.012), (x, y, z + 0.035 + k * 0.045),
                "gunmetal", bevel=0.004))
    parts.append(kit.box(prefix + "_head", (0.16, 0.16, 0.06), (x, y, z + 0.22), "gunmetal",
            bevel=0.015))
    kit.rotate_parts(parts, base, (-tilt, 0.0, 0.0))


def build_engine():
    kit.box("crankcase", (0.24, 0.34, 0.24), (0.0, 0.0, 0.43), "gunmetal", bevel=0.035)
    kit.box("gearbox", (0.2, 0.18, 0.18), (0.0, -0.17, 0.4), "gunmetal", bevel=0.03)
    for side in (-1.0, 1.0):
        kit.cylinder("case_cover", 0.1, 0.03, (side * 0.13, 0.02, 0.42), "X", "steel_dark",
                segments=14, bevel=0.008)
    _cylinder_group("front_cylinder", (0.0, 0.1, 0.52), 24.0)
    _cylinder_group("rear_cylinder", (0.0, -0.08, 0.52), -24.0)
    kit.box("air_box", (0.05, 0.16, 0.12), (0.13, -0.02, 0.62), "steel_dark", bevel=0.015)


def build_exhausts():
    # Right: a header off the front cylinder down under the engine and a low pipe back to a
    # muffler beside the rear wheel.
    path = [(0.07, 0.24, 0.64), (0.17, 0.2, 0.42), (0.2, 0.04, 0.3), (0.22, -0.52, 0.34)]
    for a, b in zip(path, path[1:]):
        kit.tube("pipe_right", a, b, 0.028, "gunmetal")
    kit.tube("muffler_right", (0.225, -0.5, 0.345), (0.235, -0.86, 0.38), 0.05, "steel_dark",
            segments=10)
    kit.cylinder("muffler_right_hole", 0.032, 0.012, (0.235, -0.866, 0.38), "Y", "hole",
            segments=10)
    # Left: a header off the rear cylinder swept up past the saddle.
    path = [(-0.07, -0.14, 0.66), (-0.19, -0.24, 0.6), (-0.23, -0.62, 0.74)]
    for a, b in zip(path, path[1:]):
        kit.tube("pipe_left", a, b, 0.028, "gunmetal")
    kit.tube("muffler_left", (-0.23, -0.6, 0.735), (-0.245, -0.98, 0.88), 0.05, "steel_dark",
            segments=10)
    kit.tube("muffler_left_shield", (-0.29, -0.66, 0.76), (-0.295, -0.88, 0.84), 0.012, "steel",
            segments=4)


def _tank_section(y, half, bottom, top):
    """One section of the tank: a flat top and a band of straight sides for the skulls."""
    return [(-0.72 * half, y, bottom), (0.72 * half, y, bottom), (half, y, bottom + 0.06),
            (half, y, top - 0.06), (0.8 * half, y, top), (-0.8 * half, y, top),
            (-half, y, top - 0.06), (-half, y, bottom + 0.06)]


def _tank_top(y):
    """The height of the tank's top at y, between its sections."""
    for (y0, _h0, _b0, t0), (y1, _h1, _b1, t1) in zip(TANK, TANK[1:]):
        if y1 <= y <= y0:
            return t0 + (t1 - t0) * (y0 - y) / (y0 - y1)
    raise ValueError("y %.2f is off the tank" % y)


def build_body():
    kit.loft("tank", [_tank_section(*section) for section in TANK], "accent", bevel=0.02)
    kit.cylinder("tank_cap", 0.035, 0.03, (0.06, 0.4, _tank_top(0.4) + 0.01), "Z", "steel",
            segments=10)
    # The cream heading cue on the tank top, the size of the kit model's tank-top plate. Its
    # glow is the lamp's, so the front of the Motorbike reads from the camera above.
    cue_y, cue_len = 0.18, 0.28
    rise = _tank_top(cue_y - cue_len / 2.0) - _tank_top(cue_y + cue_len / 2.0)
    kit.box("heading_cue", (0.28, cue_len, 0.014), (0.0, cue_y, _tank_top(cue_y) + 0.004), "lamp",
            bevel=0.004, rotation=(math.degrees(math.atan2(-rise, cue_len)), 0.0, 0.0))
    for side in (-1.0, 1.0):
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.0078, (side * 0.214, 0.15, 0.93), side,
                0.008, "bone_white")
        kit.box("side_panel", (0.02, 0.28, 0.2), (side * 0.13, -0.32, 0.68), "accent",
                bevel=0.008)
    kit.loft("saddle", [
        [(-0.12, -0.1, 0.88), (0.12, -0.1, 0.88), (0.13, -0.12, 0.95), (-0.13, -0.12, 0.95)],
        [(-0.12, -0.64, 0.88), (0.12, -0.64, 0.88), (0.12, -0.62, 0.955), (-0.12, -0.62, 0.955)],
    ], "leather", bevel=0.025)
    kit.loft("tail", [
        [(-0.12, -0.58, 0.86), (0.12, -0.58, 0.86), (0.13, -0.58, 0.97), (-0.13, -0.58, 0.97)],
        [(-0.06, -0.98, 0.92), (0.06, -0.98, 0.92), (0.07, -0.98, 1.01), (-0.07, -0.98, 1.01)],
    ], "accent", bevel=0.02)
    kit.arch("rear_fender", (REAR_Y, REAR_R), REAR_R + 0.03, -0.12, 0.12, "accent",
            start_deg=62.0, end_deg=158.0, steps=5, thickness=0.025)
    for side in (-1.0, 1.0):
        kit.cone("tail_spike", 0.022, 0.16, (side * 0.05, -0.95, 0.98), (0.0, -0.75, 0.66),
                "steel")


def build_front():
    # The fork: Team legs over dark sliders, two clamps across it, the axle.
    for side in (-1.0, 1.0):
        kit.tube("fork_leg", fork_point(-0.14, side * 0.105), fork_point(0.62, side * 0.105),
                0.03, "accent", segments=10)
        kit.tube("fork_slider", fork_point(0.55, side * 0.105), fork_point(1.0, side * 0.105),
                0.037, "gunmetal", segments=10)
    for t in (-0.1, 0.12):
        kit.box("fork_clamp", (0.28, 0.09, 0.04), fork_point(t), "gunmetal", bevel=0.012,
                rotation=(RAKE, 0.0, 0.0))
    kit.arch("front_fender", (FRONT_Y, FRONT_R), FRONT_R + 0.03, -0.08, 0.08, "accent",
            start_deg=34.0, end_deg=108.0, steps=4, thickness=0.025)
    # Bars on two risers, grips and short hand guards.
    top = fork_point(-0.14)
    for side in (-1.0, 1.0):
        kit.tube("riser", (side * 0.05, top[1], top[2]), (side * 0.05, top[1] - 0.02, 1.16),
                0.018, "gunmetal", segments=6)
        kit.tube("bar", (0.0, top[1] - 0.02, 1.16), (side * 0.36, top[1] - 0.07, 1.19), 0.016,
                "gunmetal", segments=6)
        kit.cylinder("grip", 0.025, 0.12, (side * 0.32, top[1] - 0.065, 1.187), "X", "rubber",
                segments=8)
        kit.box("hand_guard", (0.12, 0.05, 0.08), (side * 0.31, top[1] - 0.015, 1.19),
                "accent_dark", bevel=0.012)
    # The headlamp in its Team bezel, the spikes above it.
    lamp_y, lamp_z = 0.64, 0.99
    kit.cylinder("lamp_housing", 0.1, 0.12, (0.0, lamp_y - 0.06, lamp_z), "Y", "gunmetal",
            segments=12, bevel=0.01)
    kit.cylinder("lamp_bezel", 0.118, 0.05, (0.0, lamp_y, lamp_z), "Y", "accent", segments=14,
            bevel=0.01)
    kit.cylinder("headlamp", 0.09, 0.02, (0.0, lamp_y + 0.026, lamp_z), "Y", "lamp",
            segments=14)
    kit.box("spike_rail", (0.24, 0.05, 0.03), (0.0, lamp_y - 0.03, lamp_z + 0.13), "gunmetal",
            bevel=0.008)
    for x in (-0.08, 0.0, 0.08):
        kit.cone("spike", 0.022, 0.13, (x, lamp_y - 0.02, lamp_z + 0.14), (0.0, 0.55, 0.84),
                "steel_dark")


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_wheels()
    build_frame()
    build_engine()
    build_exhausts()
    build_body()
    build_front()
    kit.finish(args["out"], args["previews"], VIEWS, ao_distance=AO_DISTANCE)


main()
