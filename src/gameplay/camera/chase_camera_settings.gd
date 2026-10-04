class_name ChaseCameraSettings
extends Resource
## Feel values for a ChaseCamera: where it sits and how tightly it follows.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md AC-5 (a smooth chase
## camera) under the coding standard that tuned values are data, never script defaults, so the
## numbers a designer settles on are recorded (AC-8) and survive an editor re-save. Since Story 010
## (production/epics/wasteland-fire/story-010-camera-from-above.md AC-1 and AC-5) a settings
## resource can also describe a view from above, by a pitch, a distance and a look-ahead instead of
## an offset; each view is one .tres, and a Player's key steps a camera through a list of them.
##
## Data only, apart from the two readers local_offset() and local_focus(). A ChaseCamera reads these
## numbers and never writes them. Every number below defaults to zero on purpose, for the reason
## UnitStats gives: the engine leaves a property out of a saved .tres when it equals the script
## default. Write every tuned number into the .tres. A ChaseCamera refuses to follow while
## follow_sharpness is zero or less. The one default that is not zero, follow_rotation, is true
## because a .tres written before Story 010 has no such property and has always turned with its
## Unit.
##
## Two ways to say where the camera sits. A resource with a distance of zero uses offset, the
## chase view of Stories 001 to 009 (behind and above the Unit). A resource with a distance above
## zero ignores offset and puts the camera that far from its look point, at pitch_degrees below the
## horizon and behind that point, with the look point look_ahead metres ahead of the Unit: 90
## degrees is straight down, and a pitch a little under it is a view from above with a slight
## forward tilt, which sees more ground ahead of the Unit than behind it.

## Where the camera sits, in the target's local space, in metres: x right, y up, z back. A Unit
## faces -Z, so a positive z puts the camera behind it.
@export var offset: Vector3 = Vector3.ZERO

## How tightly the camera follows, as an exponential smoothing rate per second. Higher is
## stiffer. The follow feels the same at any frame rate.
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:1/s") var follow_sharpness: float = 0.0

## Height above the target's origin that the camera looks at, in metres.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:m") var look_height: float = 0.0

## How far ahead of the target, along its heading, the camera looks, in metres. Zero looks at the
## point look_height above the target itself; a positive value moves that point forward, so the
## Unit sits below the middle of the view and more of the ground ahead of it shows.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m") var look_ahead: float = 0.0

## How far the camera stands from its look point, in metres. Zero keeps the camera at offset (the
## chase view); above zero it is placed by this and pitch_degrees instead and offset is ignored.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m") var distance: float = 0.0

## The angle of the view below the horizon when distance is above zero, in degrees: 90 looks
## straight down, 0 looks along the ground. Ignored while distance is zero.
@export_range(0.0, 90.0, 0.1, "suffix:°") var pitch_degrees: float = 0.0

## The visual layers (VisualInstance3D.layers) that a camera on these settings does not draw, as a
## bitmask: layer 1 is bit 1, layer 2 is bit 2, layer 3 is bit 4. Zero hides nothing. The view from
## above hides the water towers' tanks (layer 2, "tower_top" in project.godot) that would otherwise
## cover the Flag on its seat and the Unit that drives in to take it
## (production/epics/wasteland-fire/story-010-camera-from-above.md AC-3). Shadows are not affected:
## a hidden piece still casts its shadow, because that follows the light's own mask.
@export_flags_3d_render var hidden_layers: int = 0

## Whether the camera turns with its target (true: the view keeps the Unit's heading, as in
## Stories 001 to 009) or keeps a fixed heading, the world's -Z up the screen (false), the other
## half of the source's camera test (design/rules.md, "Camera and controls"). The offset, the
## look-ahead and the pitch are in the target's frame when this is true and in the world's when it
## is false.
@export var follow_rotation: bool = true


## Where the look point is, relative to the target's origin, in the frame the camera follows in: x
## right, y up, z back (a Unit faces -Z, so the look-ahead is a negative z).
func local_focus() -> Vector3:
	return Vector3(0.0, look_height, -look_ahead)


## Where the camera sits, relative to the target's origin, in the frame the camera follows in. With
## a distance of zero it is offset as it stands; above zero it is the look point plus distance
## metres in the direction pitch_degrees below the horizon, behind the look point.
func local_offset() -> Vector3:
	if distance <= 0.0:
		return offset
	var pitch: float = deg_to_rad(pitch_degrees)
	return local_focus() + Vector3(0.0, sin(pitch), cos(pitch)) * distance
