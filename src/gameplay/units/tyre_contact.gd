class_name TyreContact
extends Resource
## Where one tyre of a ground Unit type touches the ground, and how wide it is: the data a Map's
## TyreTracks reads to draw the track that tyre leaves.
##
## Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-1 (a track under each tyre,
## as wide as that tyre) and AC-6 (every value is data). Vocabulary: CONTEXT.md (Tyre track).
##
## The offset is in the Unit's own frame, which is the frame of its model (the three mesh model scenes
## set no offset and no scale): x is to the Unit's right, y is Godot's Z, so a tyre ahead of the
## Unit's origin has a negative y (the Unit faces -Z). The numbers come from the Blender scripts
## that build the models (tools/blender/build_motorbike.py, build_buggy.py and build_truck.py: a
## Blender point (x, y, z) is (x, z, -y) in Godot), and a rebuilt model changes them by hand; the
## tyre_tracks evidence scenario compares them with the scripts' constants.
##
## A UnitStats lists its tyres in `tyres`. A type that lists none (the Gyrocopter, which flies)
## leaves no tracks, and nothing in the tracks code asks which type it is.

## Where the tyre touches the ground in the Unit's frame, metres: x to the right, y along Godot's Z
## (negative ahead of the origin).
@export var offset: Vector2 = Vector2.ZERO

## How wide the tyre is, metres: the width of the track it leaves.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:m") var width: float = 0.0


## Where this tyre touches the ground in the world, as (x, z), for a Unit standing at `frame`.
func world_point(frame: Transform3D) -> Vector2:
	var at: Vector3 = frame * Vector3(offset.x, 0.0, offset.y)
	return Vector2(at.x, at.z)


## An empty string when this tyre is usable, else why not: a width that is not above zero (NaN
## included) or an offset that is not a number.
func first_problem() -> String:
	if not (width > 0.0):
		return "width is not above zero"
	if is_nan(offset.x) or is_nan(offset.y) or is_inf(offset.x) or is_inf(offset.y):
		return "offset is not a finite number"
	return ""
