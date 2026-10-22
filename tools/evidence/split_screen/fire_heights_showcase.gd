extends RefCounted
## Scenario fire_heights_showcase of the split screen evidence harness (split_screen_harness.gd): the frames of Story 041, windowed,
## saved as PNGs in the folder named by the environment variable FIRE_SHOTS: 01 Player 1's Buggy firing high at Player 2's
## Gyrocopter over a Wall Panel (the tracers drawn at the Gyrocopter's height), 02 the same Buggy firing low into the panel.
## On Map 01's open salt flat. Implements: production/epics/wasteland-fire/story-041-fire-in-two-heights.md AC-6 (the look).
## Tooling only.
## Run: FIRE_SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=fire_heights_showcase

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
const SHIPPED_CAMERA: bool = true
const WATCHDOG_SECONDS: float = 1800.0
## A clear spot of Map 01's salt flat, Player 1's side, and the distances.
const SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const AHEAD: float = 14.0
const PANEL_AHEAD: float = 7.0
const FIRE_TICKS: int = 5
const SETTLE_TICKS: int = 20
const PANEL_SCENE: PackedScene = preload("res://src/gameplay/defences/wall_panel_scrap.tscn")

var _m: M2
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var panel: Node3D = PANEL_SCENE.instantiate() as Node3D
	_m.split.get_node("World").add_child(panel)
	panel.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), SPOT + Vector3.FORWARD * PANEL_AHEAD)
	await _m.put(1, M2.GYROCOPTER, SPOT + Vector3.FORWARD * AHEAD, Vector3.BACK)
	await _m.put(0, M2.BUGGY, SPOT, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	_shift(true)
	await _m.kit.advance(FIRE_TICKS)
	await _save("01-high-fire-over-the-panel-at-the-gyrocopter")
	_shift(false)
	await _m.kit.advance(SETTLE_TICKS)
	_m.h.set_key(_m.h.fire_key(0), true)
	await _m.kit.advance(FIRE_TICKS)
	await _save("02-low-fire-into-the-panel")
	_m.h.set_key(_m.h.fire_key(0), false)
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == 2 else PackedStringArray(["%d frames" % _saved.size()])
	_m.kit.verdict("S1_frames", problems, ", ".join(_saved))
	_m.h.finish("frames=%d" % _saved.size())


func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("FIRE_SHOTS")
	if folder.is_empty():
		return
	var image: Image = _m.h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
