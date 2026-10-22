extends RefCounted
## Scenario shadow_showcase of the split screen evidence harness (split_screen_harness.gd): the canyon walls' shadows round a
## Unit driving beside them (Story 047; Martin, 2026-10-22: "ked idem pri zraze, tiene sa stracaju za vozidlom"). Windowed,
## on Map 02, the shipped camera: Player 1's Motorbike drives north along the east wall and then the west wall of the canyon,
## in the view from above and then the chase view, and a PNG is saved every STEP_TICKS in the folder named by the environment variable SHOTS. Run it with the Forward+ renderer (Vulkan) to see
## what the shipped game draws. Tooling only.
## Run: SHOTS=<folder> godot --rendering-driver vulkan --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=shadow_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
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
## Along each long wall of the canyon, northward, and the camera views (from above, then the chase view).
const STARTS: Array[Vector3] = [Vector3(51.0, 0.0, 60.0), Vector3(-46.0, 0.0, 60.0), Vector3(-47.0, 0.0, -30.0)]
const STEP_TICKS: int = 60
const STEPS: int = 3
const FRAMES: int = 18

var _m: M2
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _m.park(1)
	var index: int = 0
	for view: String in ["above", "chase"]:
		for start: Vector3 in STARTS:
			if OS.get_environment("SHADOW_ONLY_SOUTH") == "1" and start.z > 0.0:
				continue
			# The third run drives south past the Fuel building, the wall on the Motorbike's right (Martin's picture).
			var facing: Vector3 = Vector3.BACK if start.z < 0.0 else Vector3.FORWARD
			await _m.put(0, M2.MOTORBIKE, start, facing)
			await _m.kit.advance(20)
			for _step: int in STEPS:
				for _tick: int in STEP_TICKS:
					_m.h.drive(0, 1 if _speed() < 10.0 else 0, 0)
					await _m.kit.tick()
				index += 1
				await _save("%02d-%s-%s-wall-z%d" % [index, view, ("east" if start.x > 0.0 else ("west" if start.z > 0.0 else "west-south")), roundi(_m.units[0].global_position.z)])
			_m.h.drive(0, 0, 0)
		# The camera key (Q, Player 1) switches to the chase view.
		_m.h.set_key(KEY_Q, true)
		await _m.kit.advance(2)
		_m.h.set_key(KEY_Q, false)
		await _m.kit.advance(60)
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == FRAMES else PackedStringArray(["%d frames" % _saved.size()])
	_m.kit.verdict("S1_frames", problems, ", ".join(_saved))
	_m.h.finish("frames=%d" % _saved.size())


func _speed() -> float:
	var unit: Unit = _m.units[0]
	return Vector2(unit.velocity.x, unit.velocity.z).length()


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SHOTS")
	if folder.is_empty():
		return
	var image: Image = _m.h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
