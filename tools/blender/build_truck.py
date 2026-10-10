"""Builds the Truck Unit's model in Blender and exports it as a .glb file (wasteland_kit.py says how
the game draws it). Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_truck.py -- \
        --out assets/art/vehicles/wasteland_truck/wasteland_truck.glb --previews <dir>

The TRUCK panel of the concept sheet (assets/art/vehicles/vehicle-design.png) in the game's rules:
one Team colour (the Accent, in two tones) and neutral metal, rubber and cargo. A lifted pickup on
knobby tyres: a sloped bonnet with a scoop over a barred grille and a spiked bumper, a cab with a
skull on each door and a four-lamp light bar, the rocket pod on a turret ring on the roof (the
Truck beats the Gyrocopter), exhaust stacks and a headache rack behind the cab, and a bed with
crates, a spare tyre, a drum and jerrycans.

Sized to the Truck's collider (src/gameplay/units/data/truck_stats.tres: 2.4 m wide, 4.4 m long,
1.6 m tall): about 4.4 m from the bumper spikes to the rear bumper, 2.1 m across the tyres, the
roof at 1.65 m and the pod's top at 2.2 m. Front toward +Y, metres, origin on the ground at the
middle of the collider.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# Wheels: radius, width, the axles' y and the wheel centres' x.
WHEEL_R = 0.44
WHEEL_W = 0.36
FRONT_Y = 1.28
REAR_Y = -1.30
TRACK_X = 0.86
# The pod's pitch above the horizon, degrees, and the point it pitches about.
POD_PITCH = 12.0
POD_PIVOT = (0.0, -0.02, 1.95)
# Preview cameras: name -> (location, look-at point, orthographic scale or None).
VIEWS = {
    "front_three_quarter": ((4.3, 5.6, 2.7), (0.0, 0.25, 0.85), None),
    "rear_three_quarter": ((-4.6, -5.2, 3.0), (0.0, -0.3, 0.85), None),
    "side": ((8.0, 0.0, 1.3), (0.0, 0.0, 0.85), None),
    "top": ((0.0, -0.001, 14.0), (0.0, 0.0, 0.0), 7.2),
}


def build_chassis():
    for side in (-1.0, 1.0):
        kit.box("rail", (0.14, 3.9, 0.16), (side * 0.45, 0.0, 0.56), "gunmetal", bevel=0.02)
    for y in (FRONT_Y, REAR_Y):
        kit.tube("axle", (-TRACK_X, y, WHEEL_R), (TRACK_X, y, WHEEL_R), 0.06, "gunmetal")
        kit.box("diff", (0.3, 0.26, 0.24), (0.0, y, WHEEL_R), "gunmetal", bevel=0.04)
    for side in (-1.0, 1.0):
        kit.box("step", (0.2, 0.8, 0.04), (side * 0.93, 0.2, 0.6), "steel_dark", bevel=0.01)


def build_front():
    # The bonnet tapers toward the grille and slopes down to it; a scoop and a riveted patch on top.
    sections = []
    for y, half, top, shoulder in ((0.7, 0.78, 1.1, 0.62), (1.9, 0.74, 1.02, 0.58)):
        sections.append([(-half, y, 0.66), (half, y, 0.66), (half, y, top - 0.12),
                (shoulder, y, top), (-shoulder, y, top), (-half, y, top - 0.12)])
    kit.loft("bonnet", sections, "accent", bevel=0.03)
    kit.box("scoop", (0.46, 0.5, 0.1), (0.0, 1.12, 1.1), "accent_dark", bevel=0.03)
    kit.box("scoop_mouth", (0.34, 0.02, 0.05), (0.0, 1.375, 1.11), "hole")
    kit.box("patch", (0.3, 0.26, 0.014), (0.38, 1.6, 1.04), "rust_dark", bevel=0.004)
    # A darker stripe down the bonnet from the scoop to the grille, on the sloped top.
    stripe = []
    for y in (1.4, 1.88):
        z = 1.1 - 0.08 * (y - 0.7) / 1.2
        stripe.append([(-0.11, y, z - 0.002), (0.11, y, z - 0.002), (0.11, y, z + 0.008),
                (-0.11, y, z + 0.008)])
    kit.loft("bonnet_stripe", stripe, "accent_dark")
    for side in (-1.0, 1.0):
        kit.arch("fender", (FRONT_Y, WHEEL_R), WHEEL_R + 0.08, min(side * 0.7, side * 1.08),
                max(side * 0.7, side * 1.08), "accent", start_deg=12.0, end_deg=168.0)
    # Barred grille between the headlamps, a bull bar, the spiked bumper and the skid plate.
    kit.box("grille", (0.86, 0.06, 0.34), (0.0, 1.93, 0.82), "gunmetal", bevel=0.015)
    for i in range(7):
        kit.box("grille_bar", (0.05, 0.05, 0.38), (-0.36 + i * 0.12, 1.97, 0.82), "steel_dark",
                bevel=0.01)
    for z in (0.65, 0.99):
        kit.box("grille_rail", (0.92, 0.05, 0.05), (0.0, 1.97, z), "steel_dark", bevel=0.01)
    for side in (-1.0, 1.0):
        kit.cylinder("headlamp_bezel", 0.1, 0.06, (side * 0.6, 1.94, 0.86), "Y", "accent",
                segments=10, bevel=0.01)
        kit.cylinder("headlamp", 0.075, 0.03, (side * 0.6, 1.975, 0.86), "Y", "lamp", segments=10)
        kit.tube("bull_bar", (side * 0.3, 2.02, 0.72), (side * 0.26, 1.98, 1.04), 0.035, "gunmetal")
    kit.tube("bull_bar_top", (-0.3, 1.98, 1.04), (0.3, 1.98, 1.04), 0.035, "gunmetal")
    kit.box("bumper", (2.0, 0.2, 0.24), (0.0, 1.98, 0.6), "rust_dark", bevel=0.035)
    for x in (-0.84, -0.42, 0.0, 0.42, 0.84):
        kit.cone("spike", 0.055, 0.17, (x, 2.07, 0.6), (0.0, 1.0, 0.0), "steel")
    kit.box("skid_plate", (1.2, 0.5, 0.04), (0.0, 1.78, 0.44), "rust_dark", bevel=0.01,
            rotation=(15.0, 0.0, 0.0))


def _windscreen_point(t, x_frac):
    """A point on the cab's sloped windscreen: t from 0 (its foot, z 1.14) to 1 (the roof, z 1.62),
    x_frac from -1 to 1 across its width."""
    return (x_frac * (0.84 - 0.08 * t), 0.66 - 0.26 * t, 1.14 + 0.48 * t)


def _glass_slab(name, corners, normal, offset=0.006, depth=0.012):
    """A thin glass panel on the four corners, raised off the surface along normal."""
    back = [tuple(c[i] + normal[i] * offset for i in range(3)) for c in corners]
    front = [tuple(c[i] + normal[i] * (offset + depth) for i in range(3)) for c in corners]
    kit.loft(name, [back, front], "glass")


def build_cab():
    kit.box("cab_sill", (1.64, 1.04, 0.1), (0.0, 0.2, 0.69), "accent_dark", bevel=0.02)
    kit.box("cab_lower", (1.72, 1.0, 0.44), (0.0, 0.2, 0.92), "accent", bevel=0.035)
    kit.loft("cab_upper", [
        [(-0.84, -0.3, 1.14), (0.84, -0.3, 1.14), (0.84, 0.66, 1.14), (-0.84, 0.66, 1.14)],
        [(-0.76, -0.26, 1.62), (0.76, -0.26, 1.62), (0.76, 0.4, 1.62), (-0.76, 0.4, 1.62)],
    ], "accent", bevel=0.03)
    kit.box("roof", (1.5, 0.62, 0.05), (0.0, 0.07, 1.645), "accent_dark", bevel=0.015)
    # Glass: the windscreen, two panes a side split by the B-pillar, the rear window.
    wn = (0.0, 0.879, 0.476)
    _glass_slab("windscreen", [_windscreen_point(0.12, -0.86), _windscreen_point(0.12, 0.86),
            _windscreen_point(0.86, 0.86), _windscreen_point(0.86, -0.86)], wn)
    for side in (-1.0, 1.0):
        sn = (side * 0.986, 0.0, 0.164)

        def at(t, y, s=side):
            return (s * (0.84 - 0.08 * t), y, 1.14 + 0.48 * t)
        _glass_slab("rear_pane", [at(0.15, -0.2), at(0.15, 0.06), at(0.85, 0.06),
                at(0.85, -0.18)], sn)
        _glass_slab("door_pane", [at(0.15, 0.16), at(0.15, 0.54), at(0.85, 0.34),
                at(0.85, 0.16)], sn)
        kit.pixel_plate("skull", kit.SKULL_ROWS, 0.022, (side * 0.86, 0.24, 0.92), side, 0.012,
                "bone_white")
        kit.box("handle", (0.02, 0.1, 0.03), (side * 0.865, -0.04, 1.06), "steel_dark")
        for y in (0.12, 0.64):
            kit.box("door_seam", (0.012, 0.012, 0.4), (side * 0.866, y, 0.92), "gunmetal")
        kit.tube("mirror_arm", (side * 0.8, 0.58, 1.3), (side * 1.0, 0.62, 1.36), 0.015, "gunmetal")
        kit.box("mirror", (0.05, 0.1, 0.16), (side * 1.02, 0.62, 1.38), "gunmetal", bevel=0.01)
    _glass_slab("rear_window", [(0.55, -0.296, 1.22), (-0.55, -0.296, 1.22),
            (-0.5, -0.27, 1.54), (0.5, -0.27, 1.54)], (0.0, -1.0, 0.0))


def build_roof():
    for x in (-0.55, 0.55):
        kit.box("bar_post", (0.05, 0.05, 0.06), (x, 0.3, 1.68), "gunmetal")
    kit.box("light_bar", (1.36, 0.12, 0.1), (0.0, 0.3, 1.73), "gunmetal", bevel=0.015)
    for x in (-0.48, -0.16, 0.16, 0.48):
        kit.cylinder("bar_bezel", 0.075, 0.05, (x, 0.37, 1.73), "Y", "accent", segments=10,
                bevel=0.008)
        kit.cylinder("bar_lamp", 0.055, 0.02, (x, 0.4, 1.73), "Y", "lamp", segments=10)
    kit.cylinder("turret_ring", 0.3, 0.07, (0.0, -0.02, 1.7), "Z", "gunmetal", segments=16,
            bevel=0.01)
    kit.box("yoke", (0.7, 0.3, 0.06), (0.0, -0.02, 1.76), "gunmetal", bevel=0.01)
    for x in (-0.34, 0.34):
        kit.box("yoke_plate", (0.06, 0.3, 0.34), (x, -0.02, 1.93), "gunmetal", bevel=0.01)
    # The pod is built level about its pivot, then pitched up as one.
    px, py, pz = POD_PIVOT
    pod = [kit.box("pod", (0.56, 0.86, 0.32), (px, py, pz), "gunmetal", bevel=0.03)]
    for dy in (-0.26, 0.26):
        pod.append(kit.box("pod_band", (0.58, 0.1, 0.34), (px, py + dy, pz), "accent", bevel=0.012))
    for dx in (-0.13, 0.13):
        for dz in (-0.075, 0.075):
            pod.append(kit.cylinder("pod_tube", 0.07, 0.96, (px + dx, py, pz + dz), "Y", "gunmetal",
                    segments=10))
            pod.append(kit.cylinder("pod_mouth", 0.08, 0.03, (px + dx, py + 0.48, pz + dz), "Y",
                    "steel_dark", segments=10))
            pod.append(kit.cylinder("pod_hole", 0.055, 0.02, (px + dx, py + 0.497, pz + dz), "Y",
                    "hole", segments=10))
    kit.rotate_parts(pod, POD_PIVOT, (POD_PITCH, 0.0, 0.0))
    kit.tube("antenna", (-0.7, -0.24, 1.6), (-0.76, -0.4, 2.7), 0.012, "steel_dark", segments=4)


def build_bed():
    kit.box("bed_floor", (1.62, 1.74, 0.08), (0.0, -1.22, 0.86), "accent_dark", bevel=0.01)
    for side in (-1.0, 1.0):
        kit.box("bed_side", (0.07, 1.74, 0.42), (side * 0.825, -1.22, 1.03), "accent", bevel=0.02)
        kit.box("bed_rail", (0.12, 1.78, 0.04), (side * 0.825, -1.22, 1.26), "accent_dark",
                bevel=0.01)
        kit.arch("rear_fender", (REAR_Y, WHEEL_R), WHEEL_R + 0.08, min(side * 0.7, side * 1.08),
                max(side * 0.7, side * 1.08), "accent", start_deg=12.0, end_deg=168.0)
        kit.box("mud_flap", (0.3, 0.02, 0.28), (side * TRACK_X, -1.86, 0.42), "rubber")
        kit.box("bed_stripe", (0.012, 1.5, 0.07), (side * 0.866, -1.22, 1.13), "accent_dark")
        # Exhaust stack with a heat shield, behind the cab corner.
        kit.tube("stack", (side * 0.93, -0.36, 0.8), (side * 0.93, -0.36, 1.95), 0.055, "gunmetal")
        kit.cylinder("heat_shield", 0.07, 0.4, (side * 0.93, -0.36, 1.5), "Z", "steel", segments=8)
        kit.cylinder("stack_mouth", 0.04, 0.02, (side * 0.93, -0.36, 1.955), "Z", "hole",
                segments=8)
        kit.tube("rack_post", (side * 0.72, -0.44, 1.24), (side * 0.72, -0.44, 1.86), 0.04,
                "gunmetal")
        kit.tube("rack_brace", (side * 0.72, -0.44, 1.8), (side * 0.78, -0.95, 1.26), 0.03,
                "gunmetal")
    kit.box("bed_front", (1.72, 0.06, 0.4), (0.0, -0.38, 1.04), "accent", bevel=0.02)
    # Rust patches riveted over the paint: the right bed side and the left door's foot.
    kit.box("bed_patch", (0.012, 0.3, 0.16), (0.866, -1.66, 0.97), "rust_dark")
    kit.box("door_patch", (0.012, 0.18, 0.12), (-0.866, -0.05, 0.8), "rust_dark")
    kit.tube("rack_top", (-0.72, -0.44, 1.86), (0.72, -0.44, 1.86), 0.04, "gunmetal")
    kit.tube("rack_mid", (-0.72, -0.44, 1.58), (0.72, -0.44, 1.58), 0.03, "gunmetal")
    kit.box("tailgate", (1.72, 0.07, 0.4), (0.0, -2.1, 1.03), "accent", bevel=0.02)
    # A raised plate in the full Team tone: its chamfers catch the light without darkening the
    # rear, which the chase camera sees most.
    kit.box("tailgate_panel", (1.2, 0.03, 0.22), (0.0, -2.145, 1.03), "accent", bevel=0.012)
    kit.box("rear_bumper", (1.8, 0.16, 0.18), (0.0, -2.16, 0.66), "rust_dark", bevel=0.025)
    kit.box("hitch", (0.12, 0.14, 0.1), (0.0, -2.26, 0.62), "gunmetal", bevel=0.01)


def build_cargo():
    kit.box("crate", (0.55, 0.55, 0.4), (-0.4, -0.8, 1.1), "olive", bevel=0.02)
    for dy in (-0.15, 0.15):
        kit.box("strap", (0.57, 0.04, 0.42), (-0.4, -0.8 + dy, 1.1), "rust_dark")
    kit.box("crate_small", (0.45, 0.45, 0.32), (0.35, -0.75, 1.06), "olive", bevel=0.02,
            rotation=(0.0, 0.0, 12.0))
    kit.cylinder("spare_tyre", 0.36, 0.2, (0.27, -1.55, 1.0), "Z", "rubber", segments=12,
            bevel=0.03)
    kit.cylinder("spare_rim", 0.2, 0.21, (0.27, -1.55, 1.0), "Z", "rim", segments=10, bevel=0.01)
    kit.cylinder("spare_hub", 0.08, 0.23, (0.27, -1.55, 1.0), "Z", "gunmetal", segments=8)
    kit.cylinder("drum", 0.2, 0.5, (-0.45, -1.3, 1.15), "Z", "steel_dark", segments=12, bevel=0.02)
    for dz in (-0.12, 0.12):
        kit.cylinder("drum_hoop", 0.21, 0.03, (-0.45, -1.3, 1.15 + dz), "Z", "gunmetal",
                segments=12)
    for x in (-0.6, -0.42):
        kit.box("jerrycan", (0.14, 0.3, 0.42), (x, -1.76, 1.11), "steel_dark", bevel=0.02)
        kit.box("jerrycan_cap", (0.05, 0.05, 0.05), (x, -1.66, 1.34), "gunmetal")


def build_wheels():
    for y in (FRONT_Y, REAR_Y):
        for side in (-1.0, 1.0):
            kit.wheel("wheel", (side * TRACK_X, y, WHEEL_R), WHEEL_R, WHEEL_W, side)


def main():
    args = kit.parse_args()
    kit.reset_scene()
    build_chassis()
    build_front()
    build_cab()
    build_roof()
    build_bed()
    build_cargo()
    build_wheels()
    kit.finish(args["out"], args["previews"], VIEWS)


main()
