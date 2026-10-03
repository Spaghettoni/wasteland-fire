extends RefCounted
## Scenario map_legibility of the split screen evidence harness (split_screen_harness.gd): the
## staged frames of Story 007 AC-13's legibility check on Map 01, both views at once, every Player
## key a real event. Both Players confirm the Motorbike (their fire keys); then each moment is
## staged by map_kit.gd's stage() with the two Units facing each other, so each camera, 13 m behind
## and 7 m above its Unit, sees the other Unit about 40 m away, and held still. The Gyrocopter over
## salt water, a moment per Team colour (CHANNEL_SPOTS): one Gyrocopter in the west channel, the
## other in the west ford, whose camera looks south down the channel at it with salt water behind
## it. Then each surface of AC-13 (SURFACES): two Motorbikes, and in each view beside the other
## Team's Unit a salt-flat Fuel Can (CAN_PATHS) on one side and the viewer's own Flag on the other,
## standing on the ground: a Flag, a Fuel Can and a Unit as three objects, no Flag carried. The Cans
## and the Flags are moved there as a staging step (as place() is for a Unit) and stand back home
## at the end. A SPLIT line comes at every moment, after its hold: both Units' type and place, both
## Flags' states, each camera's distance to the other Unit, its Can and its Flag, and frame=, in a
## --write-movie run the number of the PNG that shows the moment. It ends with RESULT ok, or one
## failing CHECK named premise when the run did not reach its steps. OWN_CHOICE; the shipped data;
## tooling only. Implements: production/epics/wasteland-fire/story-007-the-map.md AC-13 and Test
## Evidence.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/legible.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=map_legibility

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the controller, the Units, Bases and cameras.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 007 helpers (map_kit.gd): the staging, the Map's nodes.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The Motorbike's index into the data (unit_kit.gd TYPE_IDS): the Units on the surfaces.
const MOTORBIKE: int = 0
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## The Gyrocopter over salt water, a moment per Team colour: name to the spots (Player 1's x, z,
## then Player 2's), metres. The named Player's Gyrocopter stands in the west channel (x -46 to
## -34, z 20 to 48; its water runs on into the sea), the other's in the west ford 26.4 m north,
## facing each other: the ford's camera looks south down the channel, so the ground behind the
## channel's Gyrocopter in its view is salt water. One moment cannot show both: the camera that
## looked north up the channel would stand out at sea, past the Map's edge.
const CHANNEL_SPOTS: Dictionary[StringName, Vector4] = {
	&"channel_p1_gyrocopter": Vector4(-40, 36, -40, 9.6),
	&"channel_p2_gyrocopter": Vector4(-40, 9.6, -40, 36),
}
## The surfaces of AC-13, a moment each: name to [the Motorbikes' spots (Player 1's x, z, then
## Player 2's), the Fuel Cans' spots (in CAN_PATHS order: the first beside Player 2, for Player 1's
## view)], metres. A Can stands 4 m to its Unit's side (3 m on the road and in the ford, to stay on
## them), clear of its 1.6 m pick-up sphere, and the viewer's own Flag as far to the Unit's other
## side, clear of its 1 m one (_surface()). sand: south of Base A, Player 1 looking west toward the
## shore, Player 2 east toward the ridge's foot; salt_flat: its west half, the Flag Player 2 sees
## 1.8 m clear of its line of sight past the wreck at (-80, 5); canyon_road: its middle straight;
## ford: the west ford, along its length.
const SURFACES: Dictionary[StringName, Array] = {
	&"sand": [Vector4(-106, 28, -133, 28), Vector4(-133, 24, -106, 24)],
	&"salt_flat": [Vector4(-84, 13, -57, 13), Vector4(-57, 17, -84, 17)],
	&"canyon_road": [Vector4(-14, -28, 13, -28), Vector4(13, -25, -14, -25)],
	&"ford": [Vector4(-40, -14, -40, 13), Vector4(-37, 13, -43, -14)],
}
## The two Fuel Cans the surfaces move, by path from the Map: the salt flat's.
const CAN_PATHS: Array[String] = ["FuelCanFlatWest", "FuelCanFlatEast"]
## The distance at which AC-13 tells a Flag, a Fuel Can and a Unit apart, metres.
const VIEW_DISTANCE: float = 40.0
## How far a staged distance may miss VIEW_DISTANCE, metres.
const DISTANCE_TOLERANCE: float = 2.5
## Seconds each moment is held still before its line (and its frame) is taken.
const HOLD_SECONDS: float = 1.0
## Main-loop iterations from a moment's line back to the PNG that shows it: the next staging moves
## the Units in the line's own iteration, before that frame is drawn (measured, --write-movie).
const MOMENT_FRAME_LAG: int = 1

var _harness: Harness
var _kit: Kit
var _units: Units
var _map: Map
## The two staged Fuel Cans (CAN_PATHS order) and the two Flags (by Player), and where each stood.
var _cans: Array[Node3D] = []
var _flags: Array[Flag] = []
var _homes: Dictionary[Node3D, Vector3] = {}
## The moments reached, in order, and the problems they found.
var _reached: PackedStringArray = []
var _problems: PackedStringArray = []
## The largest miss of a staged distance from VIEW_DISTANCE, metres.
var _worst_miss: float = 0.0


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_map = Map.new(harness, _kit)
	for player: int in Kit.PLAYERS:
		_cans.append(_map.find(CAN_PATHS[player]) as Node3D)
		_flags.append(_units.bases[player].flag)
		for node: Node3D in [_cans[player], _flags[player]]:
			if node != null:
				_homes[node] = node.global_position
	await _harness.confirm_choices()
	for moment: StringName in CHANNEL_SPOTS:
		await _face_off(GYROCOPTER, CHANNEL_SPOTS[moment])
		await _moment(moment, 1)
		_kit.need(_problems, _units.units[0].type_id == &"gyrocopter" and _units.units[1].type_id == &"gyrocopter", "no Gyrocopters at %s" % moment)
	for surface: StringName in SURFACES:
		await _surface(surface)
	for node: Node3D in _homes:
		_put(node, _homes[node])
	_finish()


## Both Units as a type at a pair of spots (Player 1's x, z, then Player 2's), facing each other:
## map_kit.gd stage() (place(), a typed spawn, keys up, full tanks). Returns the spots on the
## ground. A coroutine: await it.
func _face_off(type: int, spots: Vector4) -> Array[Vector3]:
	var at: Array[Vector3] = _pair(spots)
	var kinds: Array[int] = [type, type]
	var facings: Array[Vector3] = [at[1] - at[0], at[0] - at[1]]
	await _map.stage(kinds, at, facings, true)
	return at


## A surface of SURFACES: two Motorbikes facing each other; in each view, beside the other Unit,
## its Can on one side and the viewer's own Flag as far on the other (the Can's spot mirrored
## through that Unit); then the moment, after which both Flags must still stand where they were put.
func _surface(surface: StringName) -> void:
	var row: Array = SURFACES[surface]
	var spots: Array[Vector3] = await _face_off(MOTORBIKE, row[0])
	var cans: Array[Vector3] = _pair(row[1])
	for player: int in Kit.PLAYERS:
		_put(_cans[player], cans[player])
		_put(_flags[player], spots[1 - player] * 2.0 - cans[player])
	await _moment(surface, 3)
	for player: int in Kit.PLAYERS:
		_kit.need(_problems, _flags[player].state == Flag.State.AT_HOME, "p%d's Flag picked up at %s" % [player + 1, surface])


## Moves a staged Can or Flag to a spot on the ground, at its own height (a staging step).
func _put(node: Node3D, at: Vector3) -> void:
	if node != null and at != Vector3.INF:
		node.global_position = Vector3(at.x, node.global_position.y, at.z)
		node.reset_physics_interpolation()


## Holds every key up for HOLD_SECONDS under the moment's name, files it and prints its line with
## the distances it measures: measured 1 (each camera to the other Unit) or 3 (and to its Can and
## its Flag).
func _moment(moment: StringName, measured: int) -> void:
	_harness.phase = moment
	_harness.release_all()
	await _kit.advance(_harness.ticks_in(HOLD_SECONDS))
	_reached.append(moment)
	_line("moment=%s %s" % [moment, _spans(measured)])


## Each camera's distance to the other Unit, its staged Can and its Flag, as line fields, the first
## measured of them per camera filed in _worst_miss (their miss from VIEW_DISTANCE).
func _spans(measured: int) -> String:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var eye: Vector3 = _units.cameras[player].global_position
		var spans: Array[float] = [eye.distance_to(_units.units[1 - player].global_position), INF, eye.distance_to(_flags[player].global_position)]
		if _cans[player] != null:
			spans[1] = eye.distance_to(_cans[player].global_position)
		for index: int in mini(measured, spans.size()):
			_worst_miss = maxf(_worst_miss, absf(spans[index] - VIEW_DISTANCE))
		fields.append("cam%d_to_p%d=%.1f cam%d_to_can=%.1f cam%d_to_flag=%.1f" % [player + 1, 2 - player, spans[0], player + 1,
			spans[1], player + 1, spans[2]])
	return " ".join(fields)


## The two (x, z) pairs of a Vector4 (Player 1's, then Player 2's) as points on the ground.
func _pair(values: Vector4) -> Array[Vector3]:
	var pair: Array[Vector3] = [Vector3(values.x, 0.0, values.y), Vector3(values.z, 0.0, values.w)]
	return pair


## Prints one SPLIT line: time, frame= (the PNG that shows the moment, MOMENT_FRAME_LAG back),
## phase, the label, both Units' type and place, both Flags' states and the Round state.
func _line(label: String) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units.units[player]
		var flag: String = Flag.State.keys()[_flags[player].state]
		fields.append("p%d_type=%s p%d_x=%.2f p%d_z=%.2f flag%d=%s" % [player + 1, unit.type_id, player + 1,
			unit.global_position.x, player + 1, unit.global_position.z, player + 1, flag])
	print("SPLIT %s t=%.3f frame=%d phase=%s %s %s round=%s" % [_harness.scenario, _harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, _harness.phase, label, " ".join(fields),
		"OVER" if _units.controller.is_round_over() else "RUNNING"])


## Prints the failing premise check when the run did not reach its steps (a moment missed, no
## Gyrocopters over the channel, a Flag picked up, a staged distance off VIEW_DISTANCE by more than
## DISTANCE_TOLERANCE, a destruction or the Round over), then RESULT.
func _finish() -> void:
	var expected: int = CHANNEL_SPOTS.size() + SURFACES.size()
	_kit.need(_problems, _reached.size() == expected, "moments reached %d of %d" % [_reached.size(), expected])
	_kit.need(_problems, _worst_miss <= DISTANCE_TOLERANCE, "a staged distance misses %.0f m by %.2f m" % [VIEW_DISTANCE, _worst_miss])
	_kit.need(_problems, _units.destroyed.is_empty() and not _units.controller.is_round_over(), "a destruction or the Round over")
	var detail: String = "moments=%d worst_miss_m=%.2f destroyed=%d" % [_reached.size(), _worst_miss, _units.destroyed.size()]
	if not _problems.is_empty():
		_kit.verdict("premise", _problems, "the run did not reach its steps: " + detail)
	_harness.finish(detail)
