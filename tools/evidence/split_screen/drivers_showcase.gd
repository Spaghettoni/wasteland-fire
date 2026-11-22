extends RefCounted
## Scenario drivers_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 064
## on Map 02's open middle with the shipped data and the chase view: the four Unit types in pairs, each Player's own in its
## view, slowly driving, so each driver shows; in the second pair the Flame Tank flames. Moments pair_1 (Motorbike, Buggy) and pair_2 (Gyrocopter, Flame Tank), with
## frame= for a --write-movie recording. Tooling only.
## Implements: production/epics/wasteland-fire/story-064-drivers.md, Test Evidence.
## Run: godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     --write-movie shots/drivers.png res://tools/evidence/split_screen_harness.tscn -- --scenario=drivers_showcase

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
const CLOSE_CHASE: bool = true
const FLAME_TANK: bool = true
const WATCHDOG_SECONDS: float = 120.0
const MOMENT_FRAME_LAG: int = 1
const DRIVE_TICKS: int = 50
const PAIRS: Array = [[M2.MOTORBIKE, M2.BUGGY], [M2.GYROCOPTER, M2.TRUCK]]

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var spot: Vector3 = M2.at(M2.CENTRE.x, M2.CENTRE.y)
	for index: int in PAIRS.size():
		var pair: Array = PAIRS[index]
		await _m.put(0, pair[0], spot + Vector3(-6.0, 0.0, 10.0), Vector3.FORWARD)
		await _m.put(1, pair[1], spot + Vector3(6.0, 0.0, -10.0), Vector3.BACK)
		_m.h.drive(0, 1, 0)
		_m.h.drive(1, 1, 0)
		# In the second pair Player 2's Flame Tank flames as it drives (Story 063).
		if pair[1] == M2.TRUCK:
			_m.h.set_key(_m.h.fire_key(1), true)
		await _m.kit.advance(DRIVE_TICKS)
		_m.h.set_key(_m.h.fire_key(1), false)
		print("SPLIT %s t=%.3f frame=%d moment=pair_%d" % [_m.h.scenario, _m.h.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, index + 1])
		_m.h.drive(0, 0, 0)
		_m.h.drive(1, 0, 0)
		await _m.kit.advance(20)
	_m.h.finish("map=map_02")
