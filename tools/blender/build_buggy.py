"""Builds the Buggy Unit's model in Blender and exports it as a .glb file (wasteland_kit.py says how
the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_buggy.py -- \
        --out assets/art/vehicles/wasteland_buggy/wasteland_buggy.glb --previews <dir>

The BUGINA panel of the concept sheet (assets/art/vehicles/vehicle-design.png) in the game's rules:
one Team colour (the Accent, in two tones) and neutral metal and rubber. A low dune buggy on big
knobby tyres at its four corners: a sloped Team bonnet with three lamps in its nose behind a tube
bull bar over a skid plate, an open tub with two seats and a skull on each door, a darker Team
roll cage with a four-lamp light bar, exposed suspension arms with Team coil springs, a rear deck
with a cargo box and an exhaust, and the pennant on a whip at the rear in the Team colour (the kit
model's flag became the Team accent the same way).

Sized to the Buggy's collider (src/gameplay/units/data/buggy_stats.tres: 1.8 m wide, 3.0 m long,
1.1 m tall): about 3.0 m from the bull bar to the pennant's tail, 1.78 m across the tyres, the
cage at 1.32 m and the pennant's top at 2.0 m. Front toward +Y, metres, origin on the ground at the
middle of the collider.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# Wheels: radius, width, the axles' y and the wheel centres' x.
WHEEL_R = 0.37
WHEEL_W = 0.3
FRONT_Y = 0.92
REAR_Y = -0.92
TRACK_X = 0.74
# The roll cage's tube radius, the main hoop's y behind the seats, the front hoop's top y, and
# the height of the roof.
CAGE_R = 0.034
MAIN_Y = -0.32
FRONT_TOP_Y = 0.15
ROOF_Z = 1.32
# The occlusion bake's reach: about a wheel's radius.
AO_DISTANCE = 0.35
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((3.3, 4.3, 2.2), (0.0, 0.15, 0.6), None),
    "rear_three_quarter": ((-3.5, -4.0, 2.4), (0.0, -0.2, 0.6), None),
    "side": ((6.4, 0.0, 1.0), (0.0, 0.0, 0.65), None),
    "top": ((0.0, -0.001, 10.0), (0.0, 0.0, 0.0), 4.8),
}


def build_chassis():
    kit.box("floor", (1.0, 2.36, 0.08), (0.0, 0.02, 0.34), "gunmetal", bevel=0.02)
    for side in (-1.0, 1.0):
        kit.box("rail", (0.08, 2.5, 0.1), (side * 0.42, 0.02, 0.3), "gunmetal", bevel=0.02)


def build_body():
    # The open tub: Team sides with a darker inset and the skull, a dash at the front.
    for side in (-1.0, 1.0):
        kit.box("tub_side", (0.06, 0.96, 0.42), (side * 0.5, 0.12, 0.58), "accent", bevel=0.02)
        kit.box("door_inset", (0.012, 0.56, 0.28), (side * 0.534, 0.1, 0.58), "accent_dark")
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.0135, (side * 0.54, 0.1, 0.585), side, 0.01,
                "bone_white")
        kit.box("tub_rim", (0.1, 0.98, 0.04), (side * 0.5, 0.12, 0.8), "accent_dark", bevel=0.01)
    kit.box("dash", (0.94, 0.16, 0.14), (0.0, 0.52, 0.84), "gunmetal", bevel=0.02)
    kit.box("tub_back", (0.94, 0.06, 0.4), (0.0, -0.33, 0.58), "accent_dark", bevel=0.015)
    # The bonnet slopes down to the nose; a darker patch across one side of it.
    sections = []
    for y, half, top, shoulder in ((0.56, 0.53, 0.86, 0.43), (1.0, 0.51, 0.75, 0.42),
            (1.36, 0.45, 0.63, 0.36)):
        sections.append([(-half, y, 0.37), (half, y, 0.37), (half, y, top - 0.08),
                (shoulder, y, top), (-shoulder, y, top), (-half, y, top - 0.08)])
    kit.loft("bonnet", sections, "accent", bevel=0.025)
    patch = []
    for y, top in ((0.66, 0.835), (1.0, 0.75), (1.24, 0.67)):
        patch.append([(0.06, y, top - 0.002), (0.36, y, top - 0.002), (0.36, y, top + 0.01),
                (0.06, y, top + 0.01)])
    kit.loft("bonnet_patch", patch, "accent_dark")
    kit.box("bonnet_patch_rivets", (0.26, 0.012, 0.012), (0.21, 0.95, 0.765), "steel_dark",
            rotation=(-17.0, 0.0, 0.0))
    # The nose plate with three lamps in Team bezels, a skid plate under it.
    kit.box("nose", (0.86, 0.06, 0.22), (0.0, 1.39, 0.5), "accent_dark", bevel=0.015)
    for x in (-0.27, 0.0, 0.27):
        kit.cylinder("nose_bezel", 0.085, 0.04, (x, 1.43, 0.5), "Y", "accent", segments=12,
                bevel=0.008)
        kit.cylinder("nose_lamp", 0.066, 0.02, (x, 1.455, 0.5), "Y", "lamp", segments=12)
    kit.box("skid_plate", (0.8, 0.42, 0.035), (0.0, 1.3, 0.25), "rust_dark", bevel=0.01,
            rotation=(14.0, 0.0, 0.0))
    # The rear deck over the engine: Team, a darker patch, a cargo box strapped on, the exhaust.
    kit.box("rear_deck", (1.0, 0.8, 0.42), (0.0, -0.76, 0.58), "accent", bevel=0.03)
    kit.box("deck_patch", (0.42, 0.34, 0.012), (-0.22, -0.82, 0.795), "accent_dark",
            rotation=(0.0, 0.0, -14.0))
    kit.box("deck_grille", (0.36, 0.012, 0.16), (0.0, -1.165, 0.6), "gunmetal")
    for x in (-0.12, 0.0, 0.12):
        kit.box("deck_slot", (0.05, 0.014, 0.12), (x, -1.168, 0.6), "hole")
    kit.box("cargo_box", (0.4, 0.36, 0.3), (0.24, -0.8, 0.94), "accent_dark", bevel=0.02)
    for dy in (-0.09, 0.09):
        kit.box("cargo_strap", (0.42, 0.04, 0.32), (0.24, -0.8 + dy, 0.94), "rust_dark")
    kit.tube("exhaust", (0.3, -0.95, 0.42), (0.33, -1.27, 0.48), 0.04, "gunmetal", segments=10)
    kit.cylinder("exhaust_hole", 0.028, 0.012, (0.333, -1.276, 0.481), "Y", "hole", segments=10)


def build_cockpit():
    for x in (-0.24, 0.24):
        kit.box("seat", (0.36, 0.38, 0.14), (x, 0.04, 0.47), "leather", bevel=0.04)
        kit.box("seat_back", (0.36, 0.1, 0.46), (x, -0.2, 0.72), "leather", bevel=0.04,
                rotation=(-10.0, 0.0, 0.0))
    kit.torus("steering_wheel", 0.11, 0.016, (-0.24, 0.38, 0.9), "Y", "gunmetal", segments=14,
            section_segments=5)
    kit.tube("steering_column", (-0.24, 0.39, 0.9), (-0.24, 0.55, 0.8), 0.018, "gunmetal",
            segments=6)


def build_cage():
    """The roll cage, the light bar on its front hoop and the pennant on a whip at the rear."""
    def bar(a, b, radius=CAGE_R):
        kit.tube("cage", a, b, radius, "accent_dark", segments=8)
    for side in (-1.0, 1.0):
        bar((side * 0.5, MAIN_Y, 0.78), (side * 0.44, MAIN_Y, ROOF_Z))
        bar((side * 0.5, 0.56, 0.86), (side * 0.44, FRONT_TOP_Y, ROOF_Z))
        bar((side * 0.44, FRONT_TOP_Y, ROOF_Z), (side * 0.44, MAIN_Y, ROOF_Z))
        bar((side * 0.44, MAIN_Y, ROOF_Z), (side * 0.42, -1.06, 0.79))
        bar((side * 0.56, 0.5, 0.7), (side * 0.56, -0.3, 0.7), 0.028)
    bar((-0.44, MAIN_Y, ROOF_Z), (0.44, MAIN_Y, ROOF_Z))
    bar((-0.44, FRONT_TOP_Y, ROOF_Z), (0.44, FRONT_TOP_Y, ROOF_Z))
    bar((-0.44, MAIN_Y, ROOF_Z), (0.44, FRONT_TOP_Y, ROOF_Z), 0.026)
    kit.box("light_bar", (0.8, 0.08, 0.09), (0.0, FRONT_TOP_Y + 0.02, ROOF_Z + 0.07), "gunmetal",
            bevel=0.015)
    for x in (-0.3, -0.1, 0.1, 0.3):
        kit.cylinder("bar_bezel", 0.06, 0.05, (x, FRONT_TOP_Y + 0.07, ROOF_Z + 0.07), "Y",
                "accent", segments=10, bevel=0.008)
        kit.cylinder("bar_lamp", 0.045, 0.02, (x, FRONT_TOP_Y + 0.1, ROOF_Z + 0.07), "Y", "lamp",
                segments=10)
    kit.tube("whip", (0.42, -1.02, 0.8), (0.42, -1.02, 2.0), 0.011, "steel_dark", segments=4)
    kit.prism_x("pennant", [(-1.03, 1.99), (-1.03, 1.73), (-1.46, 1.76), (-1.34, 1.865),
            (-1.46, 1.97)], 0.413, 0.427, "accent")


def build_bars():
    # The bull bar in front of the nose and a bumper bar at the back.
    kit.tube("bull_bar", (-0.6, 1.47, 0.44), (0.6, 1.47, 0.44), 0.035, "accent_dark")
    for side in (-1.0, 1.0):
        kit.tube("bull_bar_arm", (side * 0.6, 1.47, 0.44), (side * 0.46, 1.3, 0.42), 0.035,
                "accent_dark")
        kit.tube("bull_bar_brace", (side * 0.36, 1.47, 0.44), (side * 0.3, 1.37, 0.66), 0.03,
                "accent_dark")
    kit.tube("bull_bar_low", (0.0, 1.44, 0.3), (0.0, 1.47, 0.44), 0.03, "accent_dark")
    kit.tube("rear_bar", (-0.56, -1.2, 0.44), (0.56, -1.2, 0.44), 0.035, "accent_dark")
    for side in (-1.0, 1.0):
        kit.tube("rear_bar_arm", (side * 0.56, -1.2, 0.44), (side * 0.46, -1.1, 0.42), 0.035,
                "accent_dark")


def build_wheels():
    for y in (FRONT_Y, REAR_Y):
        for side in (-1.0, 1.0):
            kit.wheel("wheel", (side * TRACK_X, y, WHEEL_R), WHEEL_R, WHEEL_W, side)
            # Exposed suspension: two arms and an upper link to the hub, a coil-over shock.
            knuckle = (side * 0.6, y, WHEEL_R)
            for dy in (-0.24, 0.24):
                kit.tube("arm", (side * 0.44, y + dy, 0.32), knuckle, 0.026, "gunmetal",
                        segments=6)
            kit.tube("link", (side * 0.46, y, 0.6), (side * 0.6, y, 0.52), 0.024, "gunmetal",
                    segments=6)
            kit.tube("stub", knuckle, (side * TRACK_X, y, WHEEL_R), 0.035, "gunmetal",
                    segments=8)
            low, high = (side * 0.62, y + 0.05, 0.45), (side * 0.46, y + 0.11, 0.66)
            kit.tube("shock", low, high, 0.018, "steel_dark", segments=6)
            mid_low = tuple(a + (b - a) * 0.22 for a, b in zip(low, high))
            mid_high = tuple(a + (b - a) * 0.72 for a, b in zip(low, high))
            kit.tube("spring", mid_low, mid_high, 0.045, "accent", segments=8)


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_chassis()
    build_body()
    build_cockpit()
    build_cage()
    build_bars()
    build_wheels()
    kit.finish(args["out"], args["previews"], VIEWS, ao_distance=AO_DISTANCE)


main()
