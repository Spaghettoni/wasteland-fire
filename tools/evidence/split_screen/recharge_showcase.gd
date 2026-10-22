extends RefCounted
## Scenario recharge_showcase of the split screen evidence harness (split_screen_harness.gd): the frames of Story 044, windowed,
## saved as PNGs in the folder named by the environment variable SHOTS: 01 Player 1's Buggy on its boost (the bar draining),
## 02 Player 1's Gyrocopter dropping its smoke screen ahead of it (the bar empty), 03 Player 1's Truck just after a Mine (the
## bar "Mine" filling), 04 Player 1's Motorbike carrying Player 2's Flag ("Drop flag"; it then drops it), 05 Player 1's Motorbike hidden in a
## Bush, the
## Bush 1.4 times its old size, 06 (Story 045) an ammunition zone in the ammo bar's blue (Player 1) and a Fuel zone in the
## fuel bar's amber (Player 2). On Map 01. Implements: story-044-secondaries-recharge.md AC-7 (the look). Tooling only.
## Run: SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=recharge_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const MINES: bool = true
const TURRET_LOOKS: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const USE_MAP_STOCK: bool = true
const BUSHES: bool = true
const MAP_CHOICE: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const SHIPPED_CAMERA: bool = true
const WATCHDOG_SECONDS: float = 1800.0
const SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const RUN_UP_TICKS: int = 90
const SETTLE_TICKS: int = 30
const FRAMES: int = 6
const BUSH_SCENE: PackedScene = preload("res://src/gameplay/cover/bush.tscn")

var _m: M2
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _m.put(1, M2.TRUCK, SPOT + Vector3(8.0, 0.0, -30.0), Vector3.FORWARD)
	await _m.put(0, M2.BUGGY, SPOT, Vector3.FORWARD)
	_m.h.drive(0, 1, 0)
	await _m.kit.advance(RUN_UP_TICKS)
	await _tap(KEY_E)
	await _m.kit.advance(50)
	await _save("01-buggy-boost-bar-draining")
	_m.h.drive(0, 0, 0)
	await _m.put(0, M2.GYROCOPTER, SPOT, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _tap(KEY_E)
	await _m.kit.advance(40)
	await _save("02-gyrocopter-smoke-ahead")
	_m.controller.round_started.emit()
	_m.units[0].leave_play()
	await _m.kit.advance(2)
	await _m.put(0, M2.TRUCK, SPOT, Vector3.FORWARD)
	await _tap(KEY_E)
	await _m.drive_for(0, 1, 0, 60)
	await _m.kit.advance(5 * 60)
	await _save("03-truck-mine-bar-filling")
	var flag: Flag = _m.field.player_2_base.flag
	await _m.put(1, M2.TRUCK, SPOT, Vector3.FORWARD)
	await _m.put(0, M2.MOTORBIKE, flag.global_position, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("04-motorbike-drop-flag-bar")
	await _tap(KEY_E)
	await _m.kit.advance(5)
	var bush: Bush = BUSH_SCENE.instantiate() as Bush
	_m.split.get_node("World").add_child(bush)
	bush.global_position = SPOT + Vector3(0.0, 0.0, 20.0)
	await _m.put(0, M2.MOTORBIKE, bush.global_position, Vector3.FORWARD)
	await _m.put(1, M2.BUGGY, bush.global_position + Vector3(8.0, 0.0, -6.0), Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("05-motorbike-hidden-in-a-bush")
	var ammo: SupplyZone = _m.split.field.get_node("AmmoBuildingWest/AmmoZone") as SupplyZone
	await _m.put(0, M2.TRUCK, ammo.global_position + Vector3(0.0, 0.0, 9.0), Vector3.FORWARD)
	await _m.put(1, M2.TRUCK, Vector3(-12.0, 0.0, 9.0), Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("06-ammo-zone-blue-fuel-zone-amber")
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == FRAMES else PackedStringArray(["%d frames" % _saved.size()])
	_m.kit.verdict("S1_frames", problems, ", ".join(_saved))
	_m.h.finish("frames=%d" % _saved.size())


func _tap(key: Key) -> void:
	_m.h.set_key(key, true)
	await _m.kit.advance(2)
	_m.h.set_key(key, false)


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SHOTS")
	if folder.is_empty():
		return
	var image: Image = _m.h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
