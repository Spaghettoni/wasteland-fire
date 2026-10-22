extends RefCounted
## Scenario secondary of the split screen evidence harness (split_screen_harness.gd): the secondary weapons on the secondary key
## (Story 042). On an arena of its own 400 m south of Map 01, with the shipped data. CHECK lines:
##  X1 the Truck: E lays a Mine and a pad's LT lays one, its count going 5 -> 4 -> 3; LT fires no Shot; the HUD's
##     secondary line is hidden (the Mines have their own line).
##  X2 the Buggy's nitro: at top speed, E lifts it to about nitro_speed_share times that within the nitro's 2 s, and it falls
##     back after; the HUD's line reads "Nitro ready", "Nitro!", "Nitro in N s"; a press while it cools does nothing; it is ready again after the cooldown; E on a Motorbike changes nothing.
##  X3 the Gyrocopter's smoke: the HUD's line reads "Smoke 2 / 2"; E drops a cloud where it is (2 -> 1 left); a Turret 20 m off fires nothing at it while the cloud
##     hangs, and fires again after the cloud is gone; the second press drops the last, a third drops nothing; a restart frees
##     every cloud.
##  X5 the data: the pad's LT is the secondary key and fires nothing, X is free; the Buggy's nitro 2 s x 1.6, 8 s cooldown; the
##     Gyrocopter's 2 smoke screens; smoke_settings.tres 12 m, 6 s; the Turret's sight holds the smoke layer (416, 256).
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-1 to AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=secondary

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
const WATCHDOG_SECONDS: float = 900.0

const ARENA: Vector3 = Vector3(0.0, 0.0, 400.0)
const ARENA_SIZE: float = 400.0
const PAD_1: int = 0
const KEY_SECONDARY_1: Key = KEY_E
const RUN_UP_TICKS: int = 150
const NITRO_SAMPLE_TICKS: int = 90
const COOLDOWN_TICKS: int = 480
const TURRET_GAP: float = 20.0
const WATCH_TICKS: int = 240
const CLOUD_TICKS: int = 360
const SPEED_SHARE_LOW: float = 1.4
const TURRET_SCENE: PackedScene = preload("res://src/gameplay/defences/turret.tscn")
const TEXTS: Array[String] = ["Nitro ready", "Nitro!", "Nitro in %d s", "Smoke 2 / 2"]
## Where each check runs, apart, so a Mine of X1 lies under nobody else.
const NITRO_SPOT: Vector3 = ARENA + Vector3(60.0, 0.0, 0.0)
const SMOKE_SPOT: Vector3 = ARENA + Vector3(-60.0, 0.0, 0.0)
## The Gyrocopter of X3 takes the Turret's Shots all through the test (the cloud's fade lets them through again).
const STURDY_HIT_POINTS: float = 10000.0

var _m: M2
var _status: SecondaryStatus


func run(harness: Node) -> void:
	_m = M2.new(harness)
	_status = _m.split.get_node("Views/Player1View/SubViewport/Player1SecondaryStatus") as SecondaryStatus
	_make_floor()
	await _m.park(1)
	await _check_truck()
	await _check_nitro()
	await _check_smoke()
	_check_data()
	_m.h.finish("arena=1")


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	body.add_child(shape)
	_m.split.get_node("World").add_child(body)
	body.global_position = ARENA + Vector3.DOWN * 0.5


func _press(key: Key) -> void:
	_m.h.set_key(key, true)
	await _m.kit.advance(2)
	_m.h.set_key(key, false)
	await _m.kit.advance(2)


func _status_text() -> String:
	await _m.h.get_tree().process_frame
	return _status.text if _status.visible else ""


func _check_truck() -> void:
	var problems: PackedStringArray = PackedStringArray()
	# MineLayer refills on a Unit coming into play, so the parked Motorbike leaves play first.
	_m.units[0].leave_play()
	await _m.kit.advance(2)
	await _m.put(0, M2.TRUCK, ARENA, Vector3.FORWARD)
	var layer: MineLayer = _m.split.player_1_mine_layer
	var counts: Array[int] = [layer.mines_left]
	await _press(KEY_SECONDARY_1)
	counts.append(layer.mines_left)
	await _m.drive_for(0, 1, 0, 30)
	var pads: PadAssignment = _m.split.get_node("PadAssignment") as PadAssignment
	pads.connect_pad(PAD_1)
	var shots_before: int = _m.split.player_1_weapon.shots_left
	for value: float in [1.0, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.device = PAD_1
		motion.axis = JOY_AXIS_TRIGGER_LEFT
		motion.axis_value = value
		Input.parse_input_event(motion)
		await _m.kit.advance(3)
	counts.append(layer.mines_left)
	var lt_shots: int = shots_before - _m.split.player_1_weapon.shots_left
	pads.disconnect_pad(PAD_1)
	var truck_line: String = await _status_text()
	_m.kit.need(problems, counts == [5, 4, 3], "Mines %s" % [counts])
	_m.kit.need(problems, lt_shots == 0, "LT fired %d Shots" % lt_shots)
	_m.kit.need(problems, truck_line.is_empty(), "the status line reads '%s' for a Truck" % truck_line)
	_m.kit.verdict("X1_truck", problems, "Mines %s (E, then LT); LT fired %d Shots; status line '%s'" % [counts, lt_shots, truck_line])


func _speed() -> float:
	var unit: Unit = _m.units[0]
	return Vector2(unit.velocity.x, unit.velocity.z).length()


func _check_nitro() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var texts: PackedStringArray = PackedStringArray()
	await _m.put(0, M2.BUGGY, NITRO_SPOT, Vector3.FORWARD)
	texts.append(await _status_text())
	_m.h.drive(0, 1, 0)
	await _m.kit.advance(RUN_UP_TICKS)
	var top: float = _speed()
	_m.h.set_key(KEY_SECONDARY_1, true)
	await _m.kit.advance(2)
	_m.h.set_key(KEY_SECONDARY_1, false)
	texts.append(await _status_text())
	var fastest: float = 0.0
	for _tick: int in NITRO_SAMPLE_TICKS:
		await _m.kit.tick()
		fastest = maxf(fastest, _speed())
	await _m.kit.advance(RUN_UP_TICKS)
	var after: float = _speed()
	var booster: NitroBooster = _m.split.get_node("World/Player1NitroBooster") as NitroBooster
	var cooling_line: String = await _status_text()
	var cooling_left: float = booster.seconds_left()
	texts.append(cooling_line)
	await _press(KEY_SECONDARY_1)
	var cooling_press: float = 0.0
	for _tick: int in NITRO_SAMPLE_TICKS:
		await _m.kit.tick()
		cooling_press = maxf(cooling_press, _speed())
	await _m.kit.advance(COOLDOWN_TICKS)
	var ready_again: bool = booster.state() == NitroBooster.State.READY
	_m.h.drive(0, 0, 0)
	# A Motorbike: the key changes nothing.
	await _m.put(0, M2.MOTORBIKE, NITRO_SPOT + Vector3(-20.0, 0.0, 0.0), Vector3.FORWARD)
	_m.h.drive(0, 1, 0)
	await _m.kit.advance(RUN_UP_TICKS)
	var bike_top: float = _speed()
	await _press(KEY_SECONDARY_1)
	var bike_fastest: float = 0.0
	for _tick: int in NITRO_SAMPLE_TICKS / 2:
		await _m.kit.tick()
		bike_fastest = maxf(bike_fastest, _speed())
	_m.h.drive(0, 0, 0)
	var bike_line: String = await _status_text()
	var share: float = _m.stats(M2.BUGGY).nitro_speed_share
	_m.kit.need(problems, fastest > top * SPEED_SHARE_LOW and fastest <= top * share + 0.01, "nitro: top %.2f m/s, fastest %.2f m/s (share %.2f)" % [top, fastest, share])
	_m.kit.need(problems, absf(after - top) < 0.05, "after the nitro %.2f m/s, before %.2f" % [after, top])
	_m.kit.need(problems, cooling_press <= top + 0.05, "a press while cooling reached %.2f m/s" % cooling_press)
	_m.kit.need(problems, ready_again, "the nitro is not ready after the cooldown")
	_m.kit.need(problems, bike_fastest <= bike_top + 0.05 and bike_line.is_empty(), "Motorbike %.2f -> %.2f m/s, line '%s'" % [bike_top, bike_fastest, bike_line])
	_m.kit.need(problems, texts == PackedStringArray([TEXTS[0], TEXTS[1], TEXTS[2] % ceili(cooling_left)]) and cooling_left > 0.0 and cooling_left < _m.stats(M2.BUGGY).nitro_cooldown_seconds, "status lines %s" % [texts])
	_m.kit.verdict("X2_nitro", problems, "Buggy top %.2f m/s, with nitro %.2f, after %.2f, a press while cooling %.2f, ready again %s; Motorbike %.2f -> %.2f; lines %s" % [
		top, fastest, after, cooling_press, ready_again, bike_top, bike_fastest, texts])


func _check_smoke() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	_m.split.get_node("World").add_child(turret)
	turret.global_position = SMOKE_SPOT + Vector3.FORWARD * TURRET_GAP
	turret.player_index = 1
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	var sturdy: UnitStats = _m.stats(M2.GYROCOPTER).duplicate() as UnitStats
	sturdy.max_hit_points = STURDY_HIT_POINTS
	await _m.put(0, M2.GYROCOPTER, SMOKE_SPOT, Vector3.FORWARD, sturdy)
	var line: String = await _status_text()
	turret.arm(_m.units[0], _m.units[0].get_parent(), _m.controller.rules)
	await _m.kit.advance(WATCH_TICKS)
	var open_shots: int = fired[0]
	var launcher: SmokeLauncher = _m.split.get_node("World/Player1SmokeLauncher") as SmokeLauncher
	var lefts: Array[int] = [launcher.smoke_left()]
	await _press(KEY_SECONDARY_1)
	lefts.append(launcher.smoke_left())
	var clouds: int = _m.h.get_tree().get_nodes_in_group(&"smokes").size()
	await _m.kit.advance(30)
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var smoked_shots: int = fired[0]
	await _m.kit.advance(CLOUD_TICKS)
	var gone: int = _m.h.get_tree().get_nodes_in_group(&"smokes").size()
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var after_shots: int = fired[0]
	turret.queue_free()
	await _press(KEY_SECONDARY_1)
	lefts.append(launcher.smoke_left())
	await _press(KEY_SECONDARY_1)
	lefts.append(launcher.smoke_left())
	var hanging: int = _m.h.get_tree().get_nodes_in_group(&"smokes").size()
	_m.controller.round_started.emit()
	await _m.kit.advance(2)
	var after_restart: int = _m.h.get_tree().get_nodes_in_group(&"smokes").size()
	await _m.park(0)
	_m.kit.need(problems, line == TEXTS[3], "the status line reads '%s'" % line)
	_m.kit.need(problems, open_shots > 0, "the Turret fired %d Shots at the Gyrocopter in the open" % open_shots)
	_m.kit.need(problems, clouds == 1 and smoked_shots == 0, "%d clouds, %d Shots while it hung" % [clouds, smoked_shots])
	_m.kit.need(problems, gone == 0 and after_shots > 0, "%d clouds after its time, %d Shots then" % [gone, after_shots])
	_m.kit.need(problems, lefts == [2, 1, 0, 0] and hanging == 1, "smoke left %s, %d hanging after the last presses" % [lefts, hanging])
	_m.kit.need(problems, after_restart == 0, "%d clouds after the restart" % after_restart)
	_m.kit.verdict("X3_smoke", problems, "line '%s'; Turret 20 m off: %d Shots in the open, %d while the cloud hung, %d after it was gone (%d left); smoke left %s; %d hanging, %d after the restart" % [
		line, open_shots, smoked_shots, after_shots, gone, lefts, hanging, after_restart])


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var layout: PadLayout = load("res://src/gameplay/input/data/pad_layout.tres") as PadLayout
	var lt: Array[String] = []
	var x_bound: bool = false
	for binding: PadBinding in layout.bindings:
		if binding.kind == PadBinding.Kind.AXIS and binding.axis == JOY_AXIS_TRIGGER_LEFT:
			lt.append(String(binding.action_suffix))
		if binding.kind == PadBinding.Kind.BUTTON and binding.button == JOY_BUTTON_X:
			x_bound = true
	var buggy: UnitStats = _m.stats(M2.BUGGY)
	var gyro: UnitStats = _m.stats(M2.GYROCOPTER)
	var smoke: SmokeSettings = load("res://src/gameplay/secondary/data/smoke_settings.tres") as SmokeSettings
	var turret: TurretStats = load("res://src/gameplay/defences/data/turret_stats.tres") as TurretStats
	_m.kit.need(problems, lt == ["lay_mine"] and not x_bound, "LT is bound to %s, X bound %s" % [lt, x_bound])
	_m.kit.need(problems, is_equal_approx(buggy.nitro_seconds, 2.0) and is_equal_approx(buggy.nitro_speed_share, 1.6) and is_equal_approx(buggy.nitro_cooldown_seconds, 8.0), "Buggy nitro %.1f s x %.2f, %.1f s" % [buggy.nitro_seconds, buggy.nitro_speed_share, buggy.nitro_cooldown_seconds])
	_m.kit.need(problems, gyro.smoke_capacity == 2 and is_equal_approx(smoke.radius, 12.0) and is_equal_approx(smoke.seconds, 6.0), "Gyrocopter smoke %d, %.1f m, %.1f s" % [gyro.smoke_capacity, smoke.radius, smoke.seconds])
	_m.kit.need(problems, turret.sight_extra_mask == 416 and turret.flying_sight_extra_mask == 256, "Turret sight %d / %d" % [turret.sight_extra_mask, turret.flying_sight_extra_mask])
	_m.kit.verdict("X5_data", problems, "LT %s, X bound %s; nitro %.1f s x %.2f, cooldown %.1f s; smoke %d x %.0f m, %.0f s; Turret sight %d / %d" % [
		lt, x_bound, buggy.nitro_seconds, buggy.nitro_speed_share, buggy.nitro_cooldown_seconds, gyro.smoke_capacity, smoke.radius, smoke.seconds, turret.sight_extra_mask, turret.flying_sight_extra_mask])
