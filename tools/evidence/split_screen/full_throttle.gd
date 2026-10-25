extends RefCounted
## Scenario full_throttle of the split screen evidence harness (split_screen_harness.gd): on a pad the
## Unit drives as fast however far up the stick is held, it still turns on the spot with the stick
## leaned sideways, and no Unit type outranges a Turret (Story 049). Pad 0 is connected through the
## launch scene's PadAssignment (connect_pad()) and driven with InputEventJoypadMotion events. CHECK
## lines:
##  T1 full throttle: from standing, the stick straight up, half up, just past full_throttle_from and
##     leaned up and left (45 degrees) each give the Unit the same speed after the same ticks, and
##     the same as the keyboard's W; a stick just short of full_throttle_from gives none.
##  T2 still a spot turn: the stick fully left with a little up (below full_throttle_from) turns the
##     standing Unit at its spot_turn_rate and it does not roll.
##  T3 the data: every type's spot_turn_rate is three quarters of its turn_rate (it was half), and the
##     Turret's reach to a target's centre (weapon_range + muzzle_forward) is beyond every type's reach
##     to the Turret's centre (weapon_range + muzzle_forward + the drum's radius).
## Implements: production/epics/wasteland-fire/story-049-full-throttle-spin-turret-reach.md AC-1 to
## AC-3. Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=full_throttle

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

const STICK_DRIVE: bool = true
const FULL_THROTTLE: bool = true
const FIRE_HEIGHTS: bool = true
const MINES: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const MAP_CHOICE: bool = true
const STATS: Array[String] = [
	"res://src/gameplay/units/data/motorbike_stats.tres",
	"res://src/gameplay/units/data/buggy_stats.tres",
	"res://src/gameplay/units/data/truck_stats.tres",
	"res://src/gameplay/units/data/gyrocopter_stats.tres",
]
const TURRET_STATS: String = "res://src/gameplay/defences/data/turret_stats.tres"
const TURRET_SCENE: String = "res://src/gameplay/defences/turret.tscn"
const PAD_1: int = 0
## Ticks the stick is held from standing: short, so the Unit is still gaining speed and a lower
## throttle would show, and stays on the open ground.
const DRIVE_TICKS: int = 20
## Ticks the Unit stands after it is put back, before the next run.
const SETTLE_TICKS: int = 10
const TURN_TICKS: int = 30
## How far past, or short of, full_throttle_from the stick is pushed.
const EDGE: float = 0.05
## A sideways stick's little lean up, as a share of full_throttle_from.
const LEAK_SHARE: float = 0.75
const SPOT_SHARE: float = 0.75
const SPEED_TOLERANCE: float = 0.001
const RATE_TOLERANCE: float = 0.01
const STILL_METRES: float = 0.01

var _h: Harness
var _kit: Kit
var _pads: PadAssignment
var _unit: Unit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_pads = _h.split.get_node("PadAssignment") as PadAssignment
	_unit = _h.split.player_1_unit
	_check_data()
	_pads.connect_pad(PAD_1)
	await _kit.advance(2)
	await _check_full_throttle()
	await _check_spot_turn()
	_pads.disconnect_pad(PAD_1)
	_h.finish("pads=1")


func _check_full_throttle() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var from: float = _pads.layout.full_throttle_from
	var diagonal: float = sqrt(0.5)
	var leans: Array[Array] = [
		["straight up", 0.0, -1.0],
		["half up", 0.0, -0.5],
		["just past %.2f" % from, 0.0, -(from + EDGE)],
		["up and left", -diagonal, -diagonal],
	]
	var speeds: PackedStringArray = PackedStringArray()
	await _kit.advance(SETTLE_TICKS)
	var reference: float = await _speed_after(0.0, -1.0)
	for lean: Array in leans:
		var speed: float = await _speed_after(lean[1], lean[2])
		_kit.need(problems, absf(speed - reference) < SPEED_TOLERANCE and speed > 0.0, "%s: %.3f m/s, straight up %.3f m/s" % [lean[0], speed, reference])
		speeds.append("%s %.3f" % [lean[0], speed])
	var short: float = await _speed_after(0.0, -(from - EDGE))
	_kit.need(problems, is_zero_approx(short), "just short of %.2f: %.3f m/s" % [from, short])
	var key: float = await _key_speed()
	_kit.need(problems, absf(key - reference) < SPEED_TOLERANCE, "W: %.3f m/s, the stick %.3f m/s" % [key, reference])
	_kit.verdict("T1_full_throttle", problems, "speed after %d ticks from standing, m/s: %s; just short of %.2f %.3f; W %.3f; top %.1f, acceleration %.1f" % [
		DRIVE_TICKS, ", ".join(speeds), from, short, key, _unit.stats.max_speed, _unit.stats.acceleration])


func _check_spot_turn() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var leak: float = _pads.layout.full_throttle_from * LEAK_SHARE
	var start: Vector3 = _unit.global_position
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_axis(JOY_AXIS_LEFT_Y, -leak)
	await _kit.advance(2)
	var heading: float = _unit.global_rotation.y
	await _kit.advance(TURN_TICKS)
	var turned: float = angle_difference(heading, _unit.global_rotation.y)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _kit.advance(2)
	var rate: float = turned * Engine.physics_ticks_per_second / TURN_TICKS
	var moved: float = _unit.global_position.distance_to(start)
	_kit.need(problems, absf(rate - _unit.stats.spot_turn_rate) < RATE_TOLERANCE, "turned at %.3f rad/s, spot_turn_rate %.3f" % [rate, _unit.stats.spot_turn_rate])
	_kit.need(problems, moved < STILL_METRES, "rolled %.3f m" % moved)
	_kit.verdict("T2_spot_turn", problems, "stick left with %.2f up, %d ticks: %.3f rad/s left (spot_turn_rate %.3f), rolled %.3f m" % [
		leak, TURN_TICKS, rate, _unit.stats.spot_turn_rate, moved])


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turret: TurretStats = load(TURRET_STATS) as TurretStats
	var drum: float = _drum_radius()
	var turret_reach: float = turret.weapon_range + turret.muzzle_forward
	var lines: PackedStringArray = PackedStringArray()
	for path: String in STATS:
		var stats: UnitStats = load(path) as UnitStats
		var share: float = stats.spot_turn_rate / stats.turn_rate
		var reach: float = stats.weapon_range + stats.muzzle_forward + drum
		_kit.need(problems, absf(share - SPOT_SHARE) < RATE_TOLERANCE, "%s: spot %.3f is %.3f of turn %.3f" % [path.get_file(), stats.spot_turn_rate, share, stats.turn_rate])
		_kit.need(problems, reach < turret_reach, "%s reaches %.1f m to a Turret's centre, the Turret %.1f m" % [path.get_file(), reach, turret_reach])
		lines.append("%s spot %.2f / turn %.2f, reach %.1f" % [path.get_file().get_basename(), stats.spot_turn_rate, stats.turn_rate, reach])
	_kit.verdict("T3_data", problems, "%s; the Turret reaches %.1f m (range %.0f + muzzle %.1f), drum radius %.1f" % [
		"; ".join(lines), turret_reach, turret.weapon_range, turret.muzzle_forward, drum])


## The Unit's speed after DRIVE_TICKS with the stick held here from standing; then the Unit is put
## back where it started, standing.
func _speed_after(x: float, y: float) -> float:
	var start: Transform3D = _unit.global_transform
	_axis(JOY_AXIS_LEFT_X, x)
	_axis(JOY_AXIS_LEFT_Y, y)
	await _kit.advance(DRIVE_TICKS)
	var speed: float = _unit.current_speed
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _put_back(start)
	return speed


## The same with Player 1's throttle key.
func _key_speed() -> float:
	var start: Transform3D = _unit.global_transform
	var key: Key = _key_of(&"p1_throttle")
	_h.set_key(key, true)
	await _kit.advance(DRIVE_TICKS)
	var speed: float = _unit.current_speed
	_h.set_key(key, false)
	await _put_back(start)
	return speed


func _put_back(start: Transform3D) -> void:
	await _kit.advance(2)
	_unit.global_transform = start
	_unit.reset_motion()
	await _kit.advance(SETTLE_TICKS)


func _key_of(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode
	return KEY_NONE


func _drum_radius() -> float:
	var scene: Node = (load(TURRET_SCENE) as PackedScene).instantiate()
	var radius: float = 0.0
	for node: Node in scene.find_children("*", "CollisionShape3D", true, false):
		var cylinder: CylinderShape3D = (node as CollisionShape3D).shape as CylinderShape3D
		if cylinder != null:
			radius = maxf(radius, cylinder.radius)
	scene.free()
	return radius


func _axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = PAD_1
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
