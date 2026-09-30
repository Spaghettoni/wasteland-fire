class_name UnitStats
extends Resource
## Feel values and controller settings for one Unit type: the numbers a designer tunes to change
## how it drives, and the CharacterBody3D settings the Unit copies into its body.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-4: every feel value is read
## from a data resource (one .tres per Unit type), never hardcoded in a script.
##
## Data only. A Unit reads these numbers and never writes them. One .tres is shared by every
## Unit that references it, so treat it as read-only at runtime (duplicate() it for a private
## copy).
##
## Every default below is 0.0 on purpose. The engine leaves a property out of a saved .tres
## when it equals the script default, so a tuned number that happened to match a default would
## live in this script and vanish from the data file. Write every tuned number into the .tres.
## A Unit refuses to drive while max_speed or ground_snap_length is zero or less.
##
## The Controller group is not feel: it holds engine controller settings (how the body handles
## the floor and walls). They are data for the same reasons, one set per Unit type, and the
## Unit copies them into the body once, in _ready().

## Top forward speed at full throttle, in metres per second. It is also the divisor that turns
## speed into the speed fraction scaling steering, so it must stay above zero.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s") var max_speed: float = 0.0

## How fast speed builds toward the throttle target, in metres per second squared.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var acceleration: float = 0.0

## How fast speed is shed while the throttle opposes the direction of travel (forward throttle
## while rolling backward, or reverse throttle while rolling forward), in metres per second
## squared.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var braking: float = 0.0

## How fast speed is shed toward zero while no throttle is held, in metres per second squared.
## This is the coast-to-a-stop feel of Story 001 AC-2.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var coast_deceleration: float = 0.0

## Top reverse speed at full reverse throttle, in metres per second, written as a positive
## number.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s") var reverse_max_speed: float = 0.0

## Yaw rate at max_speed with steering fully held, in radians per second. The Unit turns slower
## at lower speed (in proportion to speed / max_speed), so it cannot pivot on the spot.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:rad/s") var turn_rate: float = 0.0

@export_group("Controller")

## Floor snap distance in metres, copied into CharacterBody3D.floor_snap_length. It keeps the
## body glued to the floor over seams and while pushing against walls and corners; zero drops
## floor contact for a tick or two there, so a Unit refuses to drive while it is zero or less.
## The engine default is 0.1.
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:m") var ground_snap_length: float = 0.0

## Angle from head-on, in degrees, under which a wall stops the Unit dead instead of letting it
## slide along it; copied into CharacterBody3D.wall_min_slide_angle (radians). Measured
## 2026-09-30 on Godot 4.7.2 with Jolt (the Story 001 evidence doc keeps the run): it applies in
## the GROUNDED motion mode, although the class reference says it only affects FLOATING. At 15, a
## hit 10 degrees off head-on stopped dead and one 25 degrees off slid at max_speed * sin(25
## degrees); at 0 the 10 degree hit slid. The engine default is 15. Zero lets every hit slide.
@export_range(0.0, 90.0, 0.5, "suffix:deg") var wall_min_slide_angle_degrees: float = 0.0

## Real speed along the facing direction, in metres per second, under which a Unit touching a
## wall counts as blocked by it. A blocked Unit whose throttle is then pushed the other way drops
## its held drive speed at once instead of braking it off first (Unit, movement model step 4).
## Zero disables that, and leaving a wall then takes as long as braking from the drive speed.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var blocked_speed: float = 0.0
