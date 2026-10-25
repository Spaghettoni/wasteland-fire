extends RefCounted
## Scenario map_03_showcase of the split screen evidence harness (split_screen_harness.gd): frames of Map 03 (Story 054),
## windowed, saved as PNGs in the folder named by the environment variable SHOTS: the two Garages at the start (the view from
## above), both Players out on the fords, and Player 1 at the Gate of Teal's fortress. Tooling only.
## Run: SHOTS=<folder> godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=map_03_showcase

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_03/map_03.tscn"
const OWN_CHOICE: bool = true
const TEAMS: bool = true
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
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const MORE_TOKENS: bool = true
const WATCHDOG_SECONDS: float = 600.0

const DRIVE_TICKS: int = 150
## Where Player 1 is put to look at Teal's fortress: in front of its Gate, facing it.
const GATE_AHEAD: float = 34.0

var _h: Harness
var _kit: Kit
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var split: SplitScreen = _h.split
	split.match_controller.choose(0, 1)
	split.match_controller.choose(1, 2)
	await _kit.advance(60)
	await _save("map03-01-garages")
	for key: Key in [KEY_W, KEY_UP]:
		_h.set_key(key, true)
	await _kit.advance(DRIVE_TICKS)
	for key: Key in [KEY_W, KEY_UP]:
		_h.set_key(key, false)
	await _kit.advance(30)
	await _save("map03-02-out-of-the-garages")
	var fortress: Node3D = split.field.player_2_base.flag_zone.get_parent() as Node3D
	var gate: Vector3 = -fortress.global_basis.z
	var at: Vector3 = fortress.global_position + gate * GATE_AHEAD
	var unit: Unit = split.all_units()[0]
	_h.place(unit, Transform3D(Basis(Vector3.UP, atan2(gate.x, gate.z)), Vector3(at.x, 0.0, at.z)), split.all_cameras()[0])
	await _kit.advance(60)
	await _save("map03-03-at-teal-fortress")
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == 3 else PackedStringArray(["%d frames" % _saved.size()])
	_kit.verdict("S1_frames", problems, ", ".join(_saved))
	_h.finish("frames=%d" % _saved.size())


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SHOTS")
	if folder.is_empty():
		return
	var image: Image = _h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
