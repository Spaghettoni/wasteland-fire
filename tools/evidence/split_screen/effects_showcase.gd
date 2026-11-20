extends RefCounted
## Scenario effects_showcase of the split screen evidence harness (split_screen_harness.gd): frames of
## the effects of the "feel" batch on Map 02's open middle, in the chase view, with the shipped data.
## Player 1's Buggy and Player 2's Truck face each other 16 m apart and fire low at each other (muzzle
## flashes, sparks on the hits); then the Truck stops firing and the Buggy drives off in a left turn,
## firing, then brakes and fires high (dust behind the tyres, the body leaning in the turn and
## pitching on the brake, impacts and scorches on the cover, a rocket's smoke trail). Moments print a
## SPLIT line with frame=, the number of the PNG that shows it in a --write-movie recording.
## Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     --write-movie shots/effects.png res://tools/evidence/split_screen_harness.tscn -- --scenario=effects_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const HEIGHTS: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const ROTORS: bool = true
const BUSHES: bool = true
const FIRE_HEIGHTS: bool = true
const SHIPPED_CAMERA: bool = true
const CHASE_FIRST: bool = true
const FULL_THROTTLE: bool = true
const WATCHDOG_SECONDS: float = 200.0
const AHEAD: float = 16.0

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var start: Vector3 = M2.at(M2.CENTRE.x, M2.CENTRE.y + AHEAD / 2.0)
	await _m.put(1, M2.TRUCK, start + Vector3.FORWARD * AHEAD, Vector3.BACK)
	await _m.put(0, M2.BUGGY, start, Vector3.FORWARD)
	await _m.kit.advance(20)
	_m.h.set_key(_m.h.fire_key(0), true)
	_m.h.set_key(_m.h.fire_key(1), true)
	await _moment("duel", 40)
	_m.h.set_key(_m.h.fire_key(1), false)
	_m.h.drive(0, 1, 1)
	await _moment("turn_firing", 70)
	_m.h.drive(0, 1, 0)
	await _moment("straight", 40)
	_m.h.set_key(_m.h.fire_key(0), false)
	_m.h.drive(0, -1, 0)
	await _moment("brake", 25)
	_m.h.drive(0, 0, 0)
	_shift(true)
	await _moment("rocket", 50)
	_shift(false)
	await _moment("after", 60)
	_m.h.release_all()
	_m.h.finish("map=map_02")


func _moment(label: String, ticks: int) -> void:
	await _m.kit.advance(ticks)
	print("SPLIT %s t=%.3f frame=%d moment=%s" % [_m.h.scenario, _m.h.time(),
			Engine.get_process_frames() - 1, label])


func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
