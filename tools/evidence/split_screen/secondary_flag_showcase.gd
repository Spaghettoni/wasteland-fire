extends RefCounted
## Scenario secondary_flag_showcase of the split screen evidence harness (split_screen_harness.gd): the frames of Stories 042
## and 043, windowed, saved as PNGs in the folder named by the environment variable SHOTS: 01 Player 1's Buggy on its nitro
## ("Nitro!" on its HUD), 02 Player 1's Gyrocopter in the middle of its smoke screen seen from Player 2's Truck, 03 Player 2's
## Flag on its seat on its foot, waving, 04 Player 1's Motorbike carrying it as a banner, 05 the Flag planted where the
## Motorbike was destroyed, 06 a close-up of the Flag planted on
## the open flat (drop_at()), 07 one of the Flag back on its seat under the water tower. On Map 01. Implements: story-042-secondary-weapons.md AC-7 and story-043-a-real-flag.md AC-5
## (the look). Tooling only.
## Run: SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=secondary_flag_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")

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
## A clear spot of Map 01's salt flat, Player 1's side.
const SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const WATCHER_GAP: float = 22.0
const RUN_UP_TICKS: int = 90
const NITRO_TICKS: int = 40
const SMOKE_TICKS: int = 90
const SETTLE_TICKS: int = 30
const CARRY_TICKS: int = 50
const FRAMES: int = 7
## The close-up camera's place from the Flag: back, up and to the side.
const CLOSE_UP: Vector3 = Vector3(5.0, 3.2, 6.0)
## The camera's place from the seated Flag, which stands under Map 01's water tower.
const SEAT_VIEW: Vector3 = Vector3(9.0, 2.5, 0.0)

var _m: M2
var _f: Flags
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_m = M2.new(harness)
	_f = Flags.new(harness, _m.kit)
	# 01 the nitro.
	await _m.put(1, M2.TRUCK, SPOT + Vector3(8.0, 0.0, -30.0), Vector3.FORWARD)
	await _m.put(0, M2.BUGGY, SPOT, Vector3.FORWARD)
	_m.h.drive(0, 1, 0)
	await _m.kit.advance(RUN_UP_TICKS)
	await _tap(KEY_E)
	await _m.kit.advance(NITRO_TICKS)
	await _save("01-buggy-on-its-nitro")
	_m.h.drive(0, 0, 0)
	# 02 the smoke screen, seen from the other Player's Truck.
	await _m.put(0, M2.GYROCOPTER, SPOT, Vector3.FORWARD)
	await _m.put(1, M2.TRUCK, SPOT + Vector3.BACK * WATCHER_GAP, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _tap(KEY_E)
	await _m.kit.advance(SMOKE_TICKS)
	await _save("02-gyrocopter-in-its-smoke-screen")
	_m.controller.round_started.emit()
	# 03 the Flag on its seat.
	var flag: Flag = _f.flags[1]
	var from: Vector3 = Vector3(flag.global_position.x - _f.bases[1].global_position.x, 0.0, flag.global_position.z - _f.bases[1].global_position.z)
	await _m.put(1, M2.TRUCK, SPOT, Vector3.FORWARD)
	await _m.put(0, M2.MOTORBIKE, SPOT + Vector3(0.0, 0.0, 20.0), Vector3.FORWARD)
	_f.approach(0, flag.global_position, -from if from.length() > 0.1 else Vector3.BACK)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("03-flag-on-its-seat")
	# 04 carried.
	await _f.drive_until(0, 1, 6.0, func() -> bool: return flag.state == Flag.State.CARRIED)
	_m.h.drive(0, 1, 1)
	await _m.kit.advance(CARRY_TICKS)
	_m.h.drive(0, 0, 0)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("04-motorbike-carrying-the-flag")
	# 05 dropped.
	_m.units[0].destroy()
	await _m.kit.advance(SETTLE_TICKS)
	await _save("05-flag-planted-where-the-carrier-fell")
	# 06, 07 close-ups from a low camera in Player 1's view: the planted Flag, then the Flag back on its seat.
	var camera := Camera3D.new()
	_m.split.get_node("Views/Player1View/SubViewport").add_child(camera)
	flag.drop_at(SPOT + Vector3(0.0, 0.0, 30.0))
	_look_at(camera, flag.global_position)
	camera.make_current()
	await _m.kit.advance(SETTLE_TICKS)
	await _save("06-close-up-planted")
	flag.seat_at(_f.bases[1].flag_seat.global_transform)
	camera.global_position = flag.global_position + SEAT_VIEW
	camera.look_at(flag.global_position + Vector3.UP * 2.0)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("07-close-up-on-its-seat")
	camera.queue_free()
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == FRAMES else PackedStringArray(["%d frames" % _saved.size()])
	_m.kit.verdict("S1_frames", problems, ", ".join(_saved))
	_m.h.finish("frames=%d" % _saved.size())


func _look_at(camera: Camera3D, at: Vector3) -> void:
	camera.global_position = at + CLOSE_UP
	camera.look_at(at + Vector3.UP * 1.8)


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
