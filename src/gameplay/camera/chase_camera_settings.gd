class_name ChaseCameraSettings
extends Resource
## Feel values for a ChaseCamera: where it sits and how tightly it follows.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md AC-5 (a smooth chase
## camera) under the coding standard that tuned values are data, never script defaults, so the
## numbers a designer settles on are recorded (AC-8) and survive an editor re-save.
##
## Data only. A ChaseCamera reads these numbers and never writes them. Every default below is
## zero on purpose, for the reason UnitStats gives: the engine leaves a property out of a saved
## .tres when it equals the script default. Write every tuned number into the .tres. A
## ChaseCamera refuses to follow while follow_sharpness is zero or less.

## Where the camera sits, in the target's local space, in metres: x right, y up, z back. A Unit
## faces -Z, so a positive z puts the camera behind it.
@export var offset: Vector3 = Vector3.ZERO

## How tightly the camera follows, as an exponential smoothing rate per second. Higher is
## stiffer. The follow feels the same at any frame rate.
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:1/s") var follow_sharpness: float = 0.0

## Height above the target's origin that the camera looks at, in metres.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:m") var look_height: float = 0.0
