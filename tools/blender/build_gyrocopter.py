"""Builds the Gyrocopter Unit's model in Blender and exports it as a .glb file (wasteland_kit.py
says how the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_gyrocopter.py -- \
        --out assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.glb --previews <dir>

The GYROKOPTERA panel of the concept sheet (assets/art/vehicles/vehicle-design.png) in the game's
rules: one Team colour (the Accent, in two tones) and neutral metal and rubber. An open gyrocopter:
a two-blade Team rotor with darker tips on a tripod mast (the largest Team-coloured shape from the
camera above), a Team nose pod with a darker cap and a windscreen, an open seat over a Team tank, a
boxer engine under a Team cowl driving a three-blade pusher propeller, a keel running back to a
Team fin wearing the skull over a Team stabiliser with darker end plates, and tricycle gear with
small knobby wheels on Team rims and darker Team legs. The rest of the tube frame is dark metal,
as on the sheet. The rotor stands still, yawed and tilted as the kit model's was.

Sized to the Gyrocopter's collider (src/gameplay/units/data/gyrocopter_stats.tres: 1.6 m wide,
2.4 m long, 1.0 m tall): about 2.4 m from the nose to the fin, 1.4 m across the main wheels, 4.6 m
across the rotor, the rotor head at 1.5 m. The wheels touch the ground here; the game lifts the
model by its scene's hover_height while the collider stays on the floor, and the hull its rise
reads stops below the rotor (the scene's hull_top). Front toward +Y, metres, origin on the ground
at the middle of the collider.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# The frame's tube radius and the keel's ends.
TUBE_R = 0.03
KEEL_FRONT = (0.0, 0.92, 0.28)
KEEL_BACK = (0.0, -1.16, 0.36)
# The rotor: its hub, radius, chord, the blades' coning, the yaw of the blades about the mast and
# the disc's tilt back, degrees (the kit model's 25 and 6).
ROTOR_HUB = (0.0, -0.1, 1.58)
ROTOR_R = 2.3
ROTOR_CHORD = 0.17
ROTOR_CONING = 2.5
ROTOR_YAW = 25.0
ROTOR_TILT = 6.0
# The engine and the pusher propeller behind it: centre, radius, the blades' angles from up.
ENGINE = (0.0, -0.42, 0.9)
PROP_Y = -0.63
PROP_R = 0.5
PROP_ANGLES = (20.0, 140.0, 260.0)
# The gear: main wheels' radius, width, x and y; the nose wheel's radius, width and y. Each
# wheel's axle stands so its tread touches the ground (wasteland_kit.wheel stops 5 mm inside the
# radius).
MAIN_R = 0.17
MAIN_W = 0.1
MAIN_X = 0.6
MAIN_Y = -0.2
NOSE_R = 0.13
NOSE_W = 0.08
NOSE_Y = 0.86
# The occlusion bake's reach, and no ground plane: the model is drawn in the air.
AO_DISTANCE = 0.3
GROUND_SIZE = 0.0
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((4.2, 5.2, 3.0), (0.0, 0.0, 0.8), None),
    "rear_three_quarter": ((-4.4, -4.8, 3.2), (0.0, -0.2, 0.8), None),
    "side": ((7.5, 0.0, 1.2), (0.0, 0.0, 0.8), None),
    "top": ((0.0, -0.001, 12.0), (0.0, 0.0, 0.0), 5.4),
}


def build_frame():
    kit.tube("keel", KEEL_FRONT, KEEL_BACK, TUBE_R + 0.005, "gunmetal")
    for side in (-1.0, 1.0):
        kit.tube("floor_rail", (side * 0.2, 0.7, 0.3), (side * 0.2, -0.3, 0.3), TUBE_R, "gunmetal")
        kit.tube("floor_rail_front", (side * 0.2, 0.7, 0.3), (0.0, 0.88, 0.285), TUBE_R,
                "gunmetal")
        kit.tube("floor_rail_back", (side * 0.2, -0.3, 0.3), (0.0, -0.46, 0.31), TUBE_R,
                "gunmetal")
        # The tripod mast: two legs forward from the floor rails to under the rotor head.
        kit.tube("mast_leg", (side * 0.2, 0.3, 0.3), (0.0, -0.08, 1.38), 0.024, "gunmetal")
    kit.tube("mast", (0.0, -0.12, 0.31), (0.0, -0.1, 1.46), 0.04, "gunmetal")
    kit.tube("mast_brace", (0.0, -0.66, 0.33), (0.0, -0.12, 1.16), 0.024, "gunmetal")
    kit.box("pylon", (0.1, 0.14, 0.5), (0.0, -0.42, 0.6), "gunmetal", bevel=0.02)


def _pod_section(y, half, bottom, top):
    mid = bottom + 0.45 * (top - bottom)
    return [(-0.6 * half, y, bottom), (0.6 * half, y, bottom), (half, y, mid),
            (0.7 * half, y, top), (-0.7 * half, y, top), (-half, y, mid)]


def build_pod():
    # The nose pod: a darker cap on the nose, the Team body back to the seat.
    cap = [(1.16, 0.05, 0.33, 0.4), (0.95, 0.18, 0.25, 0.55)]
    body = [(0.95, 0.18, 0.25, 0.55), (0.6, 0.24, 0.22, 0.66), (0.24, 0.24, 0.24, 0.6)]
    kit.loft("pod_cap", [_pod_section(*s) for s in cap], "accent_dark", bevel=0.015)
    kit.loft("pod", [_pod_section(*s) for s in body], "accent", bevel=0.02)
    # The windscreen leaning back from the pod's top, a slab of glass.
    base = [(-0.16, 0.8, 0.595), (0.16, 0.8, 0.595)]
    top = [(0.12, 0.56, 0.86), (-0.12, 0.56, 0.86)]
    corners = base + top
    normal = (0.0, 0.74, 0.67)
    back = [tuple(c[i] + normal[i] * 0.004 for i in range(3)) for c in corners]
    front = [tuple(c[i] + normal[i] * 0.016 for i in range(3)) for c in corners]
    kit.loft("windscreen", [back, front], "glass")
    kit.box("windscreen_frame", (0.27, 0.025, 0.025), (0.0, 0.565, 0.86), "gunmetal")
    kit.box("panel", (0.28, 0.06, 0.12), (0.0, 0.48, 0.7), "gunmetal", bevel=0.015,
            rotation=(-20.0, 0.0, 0.0))
    kit.tube("stick", (0.0, 0.3, 0.34), (0.0, 0.34, 0.6), 0.012, "gunmetal", segments=6)
    # The seat between Team side panels, the tank under it.
    kit.box("seat", (0.34, 0.32, 0.1), (0.0, 0.05, 0.42), "leather", bevel=0.03)
    kit.box("seat_back", (0.34, 0.08, 0.42), (0.0, -0.14, 0.64), "leather", bevel=0.03,
            rotation=(-12.0, 0.0, 0.0))
    for side in (-1.0, 1.0):
        kit.box("cockpit_side", (0.03, 0.44, 0.22), (side * 0.205, 0.04, 0.45), "accent",
                bevel=0.01)
    kit.box("tank", (0.3, 0.26, 0.14), (0.0, 0.02, 0.3), "accent", bevel=0.02)


def build_engine():
    x, y, z = ENGINE
    kit.box("engine", (0.3, 0.28, 0.26), ENGINE, "gunmetal", bevel=0.03)
    kit.box("engine_cowl", (0.26, 0.24, 0.05), (x, y + 0.02, z + 0.15), "accent",
            bevel=0.015)
    for side in (-1.0, 1.0):
        kit.cylinder("engine_cylinder", 0.065, 0.16, (side * 0.22, y, z), "X", "steel_dark",
                segments=10)
        for k in range(3):
            kit.cylinder("engine_fin", 0.085, 0.012, (side * (0.17 + k * 0.045), y, z), "X",
                    "gunmetal", segments=10)
    kit.tube("exhaust", (0.12, y - 0.08, z - 0.1), (0.2, y - 0.16, z - 0.3), 0.025, "gunmetal",
            segments=8)
    kit.cylinder("exhaust_hole", 0.018, 0.01, (0.202, y - 0.162, z - 0.305), "Z", "hole",
            segments=8)
    kit.cylinder("prop_hub", 0.07, 0.12, (0.0, PROP_Y + 0.05, z), "Y", "gunmetal", segments=10)
    kit.cone("spinner", 0.07, 0.1, (0.0, PROP_Y - 0.01, z), (0.0, -1.0, 0.0), "steel_dark",
            segments=10)
    for angle in PROP_ANGLES:
        blade = [kit.box("prop_blade", (0.09, 0.022, PROP_R - 0.14), (0.0, PROP_Y, z + 0.05
                + (PROP_R - 0.14) / 2.0), "steel_dark", bevel=0.006),
                kit.box("prop_tip", (0.09, 0.024, 0.09), (0.0, PROP_Y, z + PROP_R - 0.045),
                "accent", bevel=0.006)]
        kit.rotate_parts(blade, (0.0, PROP_Y, z), (0.0, angle, 0.0))


def build_tail():
    kit.prism_x("fin", [(-0.92, 0.38), (-1.2, 0.38), (-1.26, 1.06), (-1.06, 1.06)], -0.016, 0.016,
            "accent", bevel=0.006)
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * 0.016, side * 0.022))
        kit.prism_x("fin_diamond", [(-1.11, 0.52), (-1.23, 0.72), (-1.11, 0.92), (-0.99, 0.72)],
                x0, x1, "accent_dark")
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.0085, (side * 0.022, -1.11, 0.72), side, 0.006,
                "bone_white")
    kit.box("stabiliser", (0.86, 0.22, 0.025), (0.0, -1.1, 0.4), "accent", bevel=0.008)
    for side in (-1.0, 1.0):
        kit.box("end_plate", (0.025, 0.2, 0.14), (side * 0.43, -1.1, 0.44), "accent_dark",
                bevel=0.006)


def build_gear():
    hub_z = MAIN_R - 0.005
    for side in (-1.0, 1.0):
        hub = (side * (MAIN_X - 0.06), MAIN_Y, hub_z)
        kit.tube("strut_front", (side * 0.15, 0.0, 0.3), hub, 0.026, "accent_dark", segments=6)
        kit.tube("strut_back", (side * 0.15, -0.42, 0.3), hub, 0.026, "accent_dark", segments=6)
        kit.tube("axle", hub, (side * MAIN_X, MAIN_Y, hub_z), 0.02, "gunmetal", segments=6)
        kit.wheel("main_wheel", (side * MAIN_X, MAIN_Y, hub_z), MAIN_R, MAIN_W, side, lugs=10,
                lug_length=0.07, lug_height=0.04)
    nose_z = NOSE_R - 0.005
    for side in (-1.0, 1.0):
        kit.tube("nose_fork", (side * 0.06, NOSE_Y + 0.03, 0.27), (side * 0.06, NOSE_Y, nose_z),
                0.016, "gunmetal", segments=6)
    kit.wheel("nose_wheel", (0.0, NOSE_Y, nose_z), NOSE_R, NOSE_W, 1.0, lugs=8, lug_length=0.06,
            lug_height=0.035)


def build_rotor():
    """The rotor, built across X about its hub, then yawed about the mast and tilted back."""
    hx, hy, hz = ROTOR_HUB
    kit.cylinder("rotor_head", 0.07, 0.12, (hx, hy, hz - 0.08), "Z", "gunmetal", segments=10)
    rotor = [kit.box("rotor_hub", (0.4, 0.1, 0.06), ROTOR_HUB, "steel_dark", bevel=0.012)]
    tip = 0.44
    for side in (-1.0, 1.0):
        inner = ROTOR_R - tip - 0.18
        blade = [kit.box("blade", (inner, ROTOR_CHORD, 0.026), (hx + side * (0.18 + inner / 2.0),
                hy, hz), "accent", bevel=0.006),
                kit.box("blade_tip", (tip, ROTOR_CHORD, 0.027), (hx + side * (ROTOR_R - tip / 2.0),
                hy, hz), "accent_dark", bevel=0.006)]
        kit.rotate_parts(blade, ROTOR_HUB, (0.0, -side * ROTOR_CONING, 0.0))
        rotor += blade
    kit.rotate_parts(rotor, ROTOR_HUB, (0.0, 0.0, ROTOR_YAW))
    kit.rotate_parts(rotor, ROTOR_HUB, (ROTOR_TILT, 0.0, 0.0))


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_frame()
    build_pod()
    build_engine()
    build_tail()
    build_gear()
    build_rotor()
    kit.finish(args["out"], args["previews"], VIEWS, ground_size=GROUND_SIZE,
            ao_distance=AO_DISTANCE)


main()
