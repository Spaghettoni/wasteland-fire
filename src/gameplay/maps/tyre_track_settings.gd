class_name TyreTrackSettings
extends Resource
## Everything a Map's TyreTracks is told by data: where its track map lies and how fine it is, how a
## mark looks, how long it lasts, and how far a tyre may move in one tick before it counts as a jump.
##
## Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-2 (the look), AC-3 (the hold
## and the fade), AC-4 (the jump), AC-5 (the track map's size) and AC-6 (every value is data: a Map
## sets them in its scene, and nothing in the tracks' scripts or the ground shader is a number but 0
## and 1). Vocabulary: CONTEXT.md (Tyre track, Map).
##
## Every default is zero on purpose, like the other settings resources here: a tuned number that
## happened to match a default would vanish from the data file. Write every tuned number into the
## .tres (data/tyre_track_settings.tres holds Map 01's). first_problem() is the one rule of what is
## usable; TyreTracks asks it in _ready() and draws nothing, with one error, when it names a fault.

## The corner of the Map's track area with the smallest X and Z, in metres: the world point that is the
## track map's top-left pixel. The area must cover every place a tyre can roll; a tyre outside it
## leaves no mark.
@export var area_origin: Vector2 = Vector2.ZERO

## The size of the Map's track area in metres (X, Z). Map 01's ground is the island, 294 x 92.2 m.
@export var area_size: Vector2 = Vector2.ZERO

## The track map's size in pixels. Its pixel is the area over this: Map 01's 4096 x 1284 is about
## 7 cm a pixel, so a tyre of 0.20 to 0.36 m is 3 to 5 pixels wide. It holds one half-float RGBA
## texel each (8 bytes), whatever has been driven.
@export var texture_size: Vector2i = Vector2i.ZERO

@export_group("Look")

## How much of the ground's brightness a mark at full strength takes away: 0 none, 1 all of it.
@export_range(0.0, 1.0, 0.01) var darkness: float = 0.0

## How deep the rut looks, metres: the slope of its sides under the sun is this over the width of the
## mark's edge. Zero is a flat dark stripe.
@export_range(0.0, 0.5, 0.005, "or_greater", "suffix:m") var rut_depth: float = 0.0

## How far from a point the rut's sides are read, in pixels of the track map: more is softer and
## wider-lit, less is crisper. Above zero.
@export_range(0.0, 8.0, 0.1, "or_greater", "suffix:px") var rut_reach: float = 0.0

## The roughness a mark takes off the ground at full strength (packed earth is smoother), 0 to 1.
@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.0

## The soft rim of a stroke, in pixels of the track map: the mark falls from full to nothing across a
## band this wide centred on the tyre's edge, so the width the mark has at half strength is the tyre's.
## It antialiases the stroke: a hard edge stair-steps along a slanted stroke and crawls by a pixel
## along one only a few pixels wide. Above zero.
@export_range(0.0, 4.0, 0.1, "or_greater", "suffix:px") var rim_pixels: float = 0.0

@export_group("Time")

## How long a mark keeps its full strength, in seconds of the Round's time (a pause stops it).
@export_range(0.0, 600.0, 0.5, "or_greater", "suffix:s") var hold_seconds: float = 0.0

## How long a mark then takes to fade to nothing, in seconds of the Round's time. Above zero.
@export_range(0.0, 600.0, 0.5, "or_greater", "suffix:s") var fade_seconds: float = 0.0

@export_group("Strokes")

## The longest step a tyre may make in one physics tick before it counts as a jump (a teleport) and
## draws nothing, in metres. A fast Unit moves well under a metre a tick.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m") var jump_step: float = 0.0

## The shortest step worth a stroke, in metres: a tyre that moved less keeps its last place, so a
## slow roll still draws once it has moved this far, and a Unit standing still draws nothing.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:m") var min_step: float = 0.0


## The track map's pixel in metres (X, Z).
func metres_per_pixel() -> Vector2:
	return Vector2(area_size.x / texture_size.x, area_size.y / texture_size.y)


## Where a world point (X, Z) lies in the track map, in pixels.
func world_to_pixel(world: Vector2) -> Vector2:
	return (world - area_origin) / metres_per_pixel()


## What is left of a mark's strength at the given age in seconds, 0 to 1: all of it up to hold_seconds,
## then a straight line down to nothing over fade_seconds, and nothing after. The ground shader
## computes the same line from the Round's time and the time stamped in the track map.
func strength_at(age: float) -> float:
	return 1.0 - clampf((age - hold_seconds) / fade_seconds, 0.0, 1.0)


## An empty String when these settings can be used, else the first fault: an empty area or
## texture, a look value outside its range, a negative hold or a fade that is not above zero, a jump
## step that is not above zero or a minimum step that is negative or not below it. Every test is
## written so that a NaN fails it.
func first_problem() -> String:
	if not (area_size.x > 0.0 and area_size.y > 0.0):
		return "area_size is not above zero in both X and Z"
	if not (texture_size.x > 0 and texture_size.y > 0):
		return "texture_size is not above zero in both X and Y"
	if not (darkness >= 0.0 and darkness <= 1.0):
		return "darkness is not from 0 to 1"
	if not (rut_depth >= 0.0):
		return "rut_depth is below zero"
	if not (rut_reach > 0.0):
		return "rut_reach is not above zero"
	if not (smoothing >= 0.0 and smoothing <= 1.0):
		return "smoothing is not from 0 to 1"
	if not (rim_pixels > 0.0):
		return "rim_pixels is not above zero"
	if not (hold_seconds >= 0.0):
		return "hold_seconds is below zero"
	if not (fade_seconds > 0.0):
		return "fade_seconds is not above zero"
	if not (jump_step > 0.0):
		return "jump_step is not above zero"
	if not (min_step >= 0.0 and min_step < jump_step):
		return "min_step is not from 0 to under jump_step"
	if is_nan(area_origin.x) or is_nan(area_origin.y):
		return "area_origin is not a number"
	return ""
