extends RefCounted
## Scenario teams_showcase of the split screen evidence harness (split_screen_harness.gd): a frame of four Players in two
## Teams on Map 02 (Story 048), windowed, saved as a PNG in the folder named by the environment variable SHOTS: every Player
## chooses a Motorbike, Buggy, Truck or Gyrocopter and drives out of its Garage for two seconds. Tooling only.
## Run: SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=teams_showcase

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
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
const LINEUP_DEVICES: Array[int] = [-2, 0, -3, 1]
const LINEUP_TEAMS: Array[int] = [0, 0, 1, 1]
const WATCHDOG_SECONDS: float = 1800.0
const TYPES: Array[int] = [0, 1, 2, 3]
const DRIVE_TICKS: int = 120

var _h: Harness
var _kit: Kit
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var split: SplitScreen = _h.split
	for player: int in 4:
		split.match_controller.choose(player, TYPES[player])
	await _kit.advance(30)
	await _save("01-four-players-in-their-garages")
	for key: Key in [KEY_W, KEY_UP]:
		_h.set_key(key, true)
	await _kit.advance(DRIVE_TICKS)
	for key: Key in [KEY_W, KEY_UP]:
		_h.set_key(key, false)
	await _save("02-four-players-driving-out")
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == 2 else PackedStringArray(["%d frames" % _saved.size()])
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
