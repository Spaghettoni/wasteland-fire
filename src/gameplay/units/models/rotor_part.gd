class_name RotorPart
extends Resource
## One part of a model that turns about a point of its own, with the look of the smear it trails:
## the Gyrocopter's main rotor and its pusher propeller are two of these in a RotorSettings.
##
## Implements: production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-1 and AC-3 (the
## rates), AC-2 (the smear), AC-5 (the hub and the axis are where the mesh file has the part) and
## AC-6 (every value is data); design/rules.md "Teams and visual style". Vocabulary: CONTEXT.md
## (Unit, Gyrocopter, Team colour).
##
## Data only. A RotorPivot reads these numbers and never writes them; one RotorSettings holds the
## parts of a model type, and every model of the type shares them. Every default below is zero or
## empty on purpose, for the reason UnitStats gives: the engine leaves a property that equals its
## script default out of a saved .tres, so a tuned number would vanish from the data file. Write
## every number into the .tres; RotorSettings.first_problem() says whether the values can turn a
## part at all.
##
## The frame. Every point and direction is in the frame of the model's mesh file (metres; Godot's,
## +Y up and -Z forward; tools/blender/build_<type>.py says how a Blender point maps into it), where
## the part's two meshes stand at rest. A part turns right-handed about its axis through its hub:
## seen from the tip of the axis looking back at the hub, it turns counter-clockwise. The smear is a
## flat disc in the plane through the hub that the axis stands square to, trailing each blade on the
## side the blade has just left.
##
## Rates are turns a second at the Unit's speed: idle_turns_per_second while it stands, rising in a
## straight line to full_turns_per_second at its top speed in the direction it moves (forward or in
## reverse). A part that keeps one rate, as the main rotor does, sets both the same.

## The name of the Team-coloured mesh of the part in the mesh file: it is painted with the Unit's
## Team material as the body's Accent is. Required.
@export var accent_mesh: StringName = &""

## The name of the neutral mesh of the part in the mesh file (the hub, the metal blades). Required.
@export var neutral_mesh: StringName = &""

## The point the part turns about, in the mesh file's frame, metres: the middle of its hub.
@export var hub: Vector3 = Vector3.ZERO

## The line the part turns about, through the hub, in the mesh file's frame. Any length but zero; it
## is normalised when used.
@export var axis: Vector3 = Vector3.ZERO

## The way one blade runs from the hub at rest, in the mesh file's frame. Any length but zero, and
## not along the axis; the part used is the share of it square to the axis.
@export var blade_direction: Vector3 = Vector3.ZERO

## How many blades the part has, evenly spaced about the axis starting at blade_direction. The gap
## between two is a whole turn divided by this.
@export_range(0, 12, 1) var blade_count: int = 0

## Turns a second while the Unit stands.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:turns/s") var idle_turns_per_second: float = 0.0

## Turns a second at the Unit's top speed, forward or in reverse.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:turns/s") var full_turns_per_second: float = 0.0

## How far the smear reaches from the hub, metres: the distance to the blades' tips.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:m") var smear_reach: float = 0.0

## The colour of the smear from the hub out to smear_tip_start, as an sRGB colour (its alpha is not
## used). Mixed with the Unit's Team colour by smear_body_team_share.
@export var smear_body_colour: Color = Color(0.0, 0.0, 0.0, 0.0)

## The share of the Team colour in the body of the smear: 1 is the Team colour (the main rotor's
## blades are painted with it), 0 is smear_body_colour alone (the propeller's blades are metal).
@export_range(0.0, 1.0, 0.01) var smear_body_team_share: float = 0.0

## The Team colour's tone in the tip of the smear, in the way the blades' tips are toned by their
## vertex colours (the main rotor's tips are 0.68 of its blades' colour and its smear's 0.8, a
## little darker than the smear's body; the propeller's Team-coloured tips are 1).
@export_range(0.0, 1.0, 0.01) var smear_tip_team_tone: float = 0.0

## The share of smear_reach, from the hub, where the tip of the smear begins (the blades' tips begin
## there too).
@export_range(0.0, 1.0, 0.01) var smear_tip_start: float = 0.0

## The share of smear_reach over which the smear fades in from the hub, so a hub is not tinted.
@export_range(0.0, 1.0, 0.01) var smear_inner_share: float = 0.0


## Turns a second for a speed share from 0 (the Unit stands) to 1 (its top speed): a straight line
## from the idle rate to the full one. A share outside 0 to 1 is held to it.
func turns_per_second(share: float) -> float:
	return lerpf(idle_turns_per_second, full_turns_per_second, clampf(share, 0.0, 1.0))


## The angle between two blades, radians: a whole turn over blade_count (zero blades: zero).
func blade_gap() -> float:
	return TAU / blade_count if blade_count > 0 else 0.0


## How far a blade moves in one physics tick at the given rate, as a share of the gap between two
## blades. The strobe limit is a ceiling on this; above half the blades seem to go backwards, and
## near one they seem to stand still.
func step_share(turns_per_second_now: float) -> float:
	return turns_per_second_now * blade_count / Engine.physics_ticks_per_second


## The axis as a unit vector, or a zero vector for an axis of length zero.
func axis_direction() -> Vector3:
	return axis.normalized()


## The way one blade runs at rest as a unit vector square to the axis (the share of blade_direction
## square to it), or a zero vector when blade_direction runs along the axis.
func blade_side() -> Vector3:
	var up: Vector3 = axis_direction()
	return (blade_direction - up * blade_direction.dot(up)).normalized()


## The frame of the smear in the pivot, in the mesh file's frame: +Y along the axis, +X along one
## blade at rest, +Z their cross product, and the smear's reach on X and Z, so that the default
## PlaneMesh (2 m across, facing +Y) fills the disc.
func smear_basis() -> Basis:
	var up: Vector3 = axis_direction()
	var side: Vector3 = blade_side()
	return Basis(side * smear_reach, up, side.cross(up) * smear_reach)
