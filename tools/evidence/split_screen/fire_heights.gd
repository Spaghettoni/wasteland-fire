extends RefCounted
## Scenario fire_heights of the split screen evidence harness (split_screen_harness.gd): Shots in two Heights (Story 041). On an
## arena of its own, a flat floor 400 m south of Map 01, with the shipped data. CHECK lines:
##  H1 low and high at a Gyrocopter: Player 1's Buggy firing low at Player 2's Gyrocopter 15 m ahead does nothing to it; firing
##     high hits it.
##  H2 low and high at a ground Unit: at Player 2's Buggy the high fire does nothing, the low fire hits.
##  H3 over a wall: with a Wall Panel 7 m ahead, the high fire passes over it and hits the Gyrocopter behind, the panel whole; the
##     low fire at a Buggy behind it stops at the panel and damages it, the Buggy whole.
##  H4 a Tall piece: with a block on the map layer 7 m ahead, the high fire stops at it and the Gyrocopter behind is whole.
##  H5 a Turret through both Heights: Player 1's low and high fire both damage Player 2's Turret; that Turret fires high over a
##     Wall Panel at Player 1's Gyrocopter and hits it, and does not fire at Player 1's Buggy behind the same panel.
##  H6 the inputs: Right Shift fires Player 2's Weapon high, Left Shift Player 1's, a pad's RB Player 1's; a high shot's tracer
##     is drawn high_shot_lift above its flight line, a low one's on it.
##  H7 the data: match_rules.tres masks 67 (low) and 17 (high), lift 2.9; the two high fire actions on the two Shift keys.
## Implements: production/epics/wasteland-fire/story-041-fire-in-two-heights.md AC-1 to AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=fire_heights

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
const WATCHDOG_SECONDS: float = 900.0

const ARENA: Vector3 = Vector3(0.0, 0.0, 400.0)
const ARENA_SIZE: float = 300.0
const AHEAD: float = 15.0
const OBSTACLE_AHEAD: float = 7.0
const TURRET_GAP: float = 20.0
const FIRE_TICKS: int = 40
const SETTLE_SHOTS: int = 30
const WATCH_TICKS: int = 240
const PANEL_SCENE: PackedScene = preload("res://src/gameplay/defences/wall_panel_scrap.tscn")
const TURRET_SCENE: PackedScene = preload("res://src/gameplay/defences/turret.tscn")
const BLOCK_SIZE: Vector3 = Vector3(3.0, 6.0, 3.0)
const LOW_MASK: int = 67
const HIGH_MASK: int = 17
const LIFT: float = 2.9
const PAD_1: int = 0

var _m: M2
var _floor: StaticBody3D
var _lifts: Array[float] = []
var _new_shots: Array[Shot] = []


func run(harness: Node) -> void:
	_m = M2.new(harness)
	_make_floor()
	_m.h.get_tree().node_added.connect(_on_node_added)
	await _check_at_gyro()
	await _check_at_ground()
	await _check_over_wall()
	await _check_tall_piece()
	await _check_turret()
	await _check_inputs()
	_check_data()
	_m.h.finish("arena=1")


func _make_floor() -> void:
	_floor = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	_floor.add_child(shape)
	_m.split.get_node("World").add_child(_floor)
	_floor.global_position = ARENA + Vector3.DOWN * 0.5


func _on_node_added(node: Node) -> void:
	var shot: Shot = node as Shot
	if shot != null:
		_new_shots.append(shot)


## Records the tracer height of every Shot added since the last call (it is set in the tick it is launched).
func _note_lifts() -> void:
	for shot: Shot in _new_shots:
		if is_instance_valid(shot) and shot.tracer != null:
			_lifts.append(shot.tracer.position.y)
	_new_shots.clear()


## Puts Player 1 at the arena's middle facing north and Player 2's Unit of a type `ahead` metres in front of it, facing it.
func _stage(p1_type: int, p2_type: int, ahead: float = AHEAD) -> void:
	await _m.put(1, p2_type, ARENA + Vector3.FORWARD * ahead, Vector3.BACK)
	await _m.put(0, p1_type, ARENA, Vector3.FORWARD)


func _fire(player: int, high: bool) -> void:
	if high:
		_shift(player, true)
	else:
		_m.h.set_key(_m.h.fire_key(player), true)
	for _tick: int in FIRE_TICKS:
		await _m.kit.tick()
		_note_lifts()
	if high:
		_shift(player, false)
	else:
		_m.h.set_key(_m.h.fire_key(player), false)
	await _m.kit.advance(SETTLE_SHOTS)


## A real Shift key event: the left one for Player 1, the right one for Player 2 (the high fire's keys).
func _shift(player: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = KEY_LOCATION_LEFT if player == 0 else KEY_LOCATION_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)


func _check_at_gyro() -> void:
	var problems: PackedStringArray = PackedStringArray()
	await _stage(M2.BUGGY, M2.GYROCOPTER)
	var start: float = _m.units[1].hit_points
	await _fire(0, false)
	var after_low: float = _m.units[1].hit_points
	await _fire(0, true)
	var after_high: float = _m.units[1].hit_points
	_m.kit.need(problems, is_equal_approx(after_low, start), "low fire took the Gyrocopter from %.1f to %.1f" % [start, after_low])
	_m.kit.need(problems, after_high < after_low, "high fire left the Gyrocopter at %.1f" % after_high)
	_m.kit.verdict("H1_at_gyro", problems, "Gyrocopter %.1f -> %.1f (low) -> %.1f (high)" % [start, after_low, after_high])


func _check_at_ground() -> void:
	var problems: PackedStringArray = PackedStringArray()
	await _stage(M2.BUGGY, M2.TRUCK)
	var start: float = _m.units[1].hit_points
	await _fire(0, true)
	var after_high: float = _m.units[1].hit_points
	await _fire(0, false)
	var after_low: float = _m.units[1].hit_points
	_m.kit.need(problems, is_equal_approx(after_high, start), "high fire took the Truck from %.1f to %.1f" % [start, after_high])
	_m.kit.need(problems, after_low < after_high, "low fire left the Truck at %.1f" % after_low)
	_m.kit.verdict("H2_at_ground", problems, "Truck %.1f -> %.1f (high) -> %.1f (low)" % [start, after_high, after_low])


func _check_over_wall() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var panel: Structure = PANEL_SCENE.instantiate() as Structure
	_m.split.get_node("World").add_child(panel)
	panel.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), ARENA + Vector3.FORWARD * OBSTACLE_AHEAD)
	await _stage(M2.BUGGY, M2.GYROCOPTER)
	var gyro_start: float = _m.units[1].hit_points
	await _fire(0, true)
	var gyro_after: float = _m.units[1].hit_points
	var panel_after_high: float = panel.hit_points
	await _stage(M2.BUGGY, M2.TRUCK)
	var truck_start: float = _m.units[1].hit_points
	await _fire(0, false)
	var truck_after: float = _m.units[1].hit_points
	var panel_after_low: float = panel.hit_points
	panel.queue_free()
	_m.kit.need(problems, gyro_after < gyro_start and is_equal_approx(panel_after_high, panel.stats.max_hit_points), "high over the panel: Gyrocopter %.1f -> %.1f, panel %.1f" % [gyro_start, gyro_after, panel_after_high])
	_m.kit.need(problems, is_equal_approx(truck_after, truck_start) and panel_after_low < panel_after_high, "low at the panel: Truck %.1f -> %.1f, panel %.1f" % [truck_start, truck_after, panel_after_low])
	_m.kit.verdict("H3_over_wall", problems, "high: Gyrocopter %.1f -> %.1f, panel %.1f; low: Truck %.1f -> %.1f, panel %.1f" % [gyro_start, gyro_after, panel_after_high, truck_start, truck_after, panel_after_low])


func _check_tall_piece() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BLOCK_SIZE
	shape.shape = box
	shape.position = Vector3.UP * BLOCK_SIZE.y / 2.0
	block.add_child(shape)
	_m.split.get_node("World").add_child(block)
	block.global_position = ARENA + Vector3.FORWARD * OBSTACLE_AHEAD
	await _stage(M2.BUGGY, M2.GYROCOPTER)
	var start: float = _m.units[1].hit_points
	await _fire(0, true)
	var after: float = _m.units[1].hit_points
	block.queue_free()
	_m.kit.need(problems, is_equal_approx(after, start), "high behind a Tall piece: Gyrocopter %.1f -> %.1f" % [start, after])
	_m.kit.verdict("H4_tall_piece", problems, "Gyrocopter behind the map-layer block %.1f -> %.1f" % [start, after])


func _check_turret() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	_m.split.get_node("World").add_child(turret)
	turret.global_position = ARENA + Vector3.FORWARD * AHEAD
	turret.player_index = 1
	await _m.park(1)
	await _m.put(0, M2.BUGGY, ARENA, Vector3.FORWARD)
	var start: float = turret.hit_points
	await _fire(0, false)
	var after_low: float = turret.hit_points
	await _fire(0, true)
	var after_high: float = turret.hit_points
	turret.restore()
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	turret.arm(_m.units[0], _m.units[0].get_parent(), _m.controller.rules)
	var panel: Structure = PANEL_SCENE.instantiate() as Structure
	_m.split.get_node("World").add_child(panel)
	panel.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), turret.global_position + Vector3.BACK * (TURRET_GAP / 2.0))
	await _m.put(0, M2.GYROCOPTER, turret.global_position + Vector3.BACK * TURRET_GAP, Vector3.FORWARD)
	var gyro_start: float = _m.units[0].hit_points
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var at_gyro: int = fired[0]
	var gyro_after: float = _m.units[0].hit_points
	await _m.put(0, M2.BUGGY, turret.global_position + Vector3.BACK * TURRET_GAP, Vector3.FORWARD)
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var at_buggy: int = fired[0]
	turret.queue_free()
	panel.queue_free()
	await _m.park(0)
	_m.kit.need(problems, after_low < start and after_high < after_low, "Turret %.1f -> %.1f (low) -> %.1f (high)" % [start, after_low, after_high])
	_m.kit.need(problems, at_gyro > 0 and gyro_after < gyro_start, "over the panel at the Gyrocopter: %d Shots, %.1f -> %.1f" % [at_gyro, gyro_start, gyro_after])
	_m.kit.need(problems, at_buggy == 0, "at the Buggy behind the panel: %d Shots" % at_buggy)
	_m.kit.verdict("H5_turret", problems, "Turret %.1f -> %.1f (low) -> %.1f (high); over a panel: %d Shots at the Gyrocopter (%.1f -> %.1f), %d at the Buggy" % [
		start, after_low, after_high, at_gyro, gyro_start, gyro_after, at_buggy])


func _check_inputs() -> void:
	var problems: PackedStringArray = PackedStringArray()
	# Right Shift: Player 2 fires high at Player 1's Gyrocopter.
	await _m.put(0, M2.GYROCOPTER, ARENA + Vector3.FORWARD * AHEAD, Vector3.BACK)
	await _m.put(1, M2.BUGGY, ARENA, Vector3.FORWARD)
	var start: float = _m.units[0].hit_points
	_lifts.clear()
	await _fire(1, true)
	var right_shift: float = start - _m.units[0].hit_points
	var high_lifts: Array[float] = _lifts.duplicate()
	_lifts.clear()
	await _fire(1, false)
	var low_lifts: Array[float] = _lifts.duplicate()
	# A pad's RB: Player 1 fires high at Player 2's Gyrocopter.
	await _stage(M2.BUGGY, M2.GYROCOPTER)
	var pads: PadAssignment = _m.split.get_node("PadAssignment") as PadAssignment
	pads.connect_pad(PAD_1)
	var pad_start: float = _m.units[1].hit_points
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = PAD_1
		event.button_index = JOY_BUTTON_RIGHT_SHOULDER
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(event)
		await _m.kit.advance(FIRE_TICKS if pressed else SETTLE_SHOTS)
	var rb: float = pad_start - _m.units[1].hit_points
	pads.disconnect_pad(PAD_1)
	_m.kit.need(problems, right_shift > 0.0, "Right Shift took %.1f off the Gyrocopter" % right_shift)
	_m.kit.need(problems, rb > 0.0, "RB took %.1f off the Gyrocopter" % rb)
	_m.kit.need(problems, not high_lifts.is_empty() and high_lifts.all(func(y: float) -> bool: return is_equal_approx(y, LIFT)), "high tracers drawn at %s" % [high_lifts])
	_m.kit.need(problems, not low_lifts.is_empty() and low_lifts.all(func(y: float) -> bool: return is_zero_approx(y)), "low tracers drawn at %s" % [low_lifts])
	_m.kit.verdict("H6_inputs", problems, "Right Shift -%.1f, RB -%.1f (Left Shift: H1); tracers high %s, low %s" % [right_shift, rb, high_lifts.slice(0, 1), low_lifts.slice(0, 1)])


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var rules: MatchRules = _m.controller.rules
	_m.kit.need(problems, rules.shot_collision_mask == LOW_MASK and rules.high_shot_collision_mask == HIGH_MASK and is_equal_approx(rules.high_shot_lift, LIFT), "masks %d / %d, lift %.2f" % [rules.shot_collision_mask, rules.high_shot_collision_mask, rules.high_shot_lift])
	var keys: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var action: StringName = StringName("p%d_fire_high" % (player + 1))
		var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		var key: InputEventKey = events[0] as InputEventKey if events.size() == 1 else null
		var want: KeyLocation = KEY_LOCATION_LEFT if player == 0 else KEY_LOCATION_RIGHT
		_m.kit.need(problems, key != null and key.physical_keycode == KEY_SHIFT and key.location == want, "%s is bound to %s" % [action, events])
		keys.append("%s Shift (location %d)" % [action, key.location if key != null else -1])
	_m.kit.verdict("H7_data", problems, "low mask %d, high mask %d, lift %.2f; %s" % [rules.shot_collision_mask, rules.high_shot_collision_mask, rules.high_shot_lift, ", ".join(keys)])
