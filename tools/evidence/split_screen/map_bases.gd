extends RefCounted
## Scenario map_bases of the split screen evidence harness (split_screen_harness.gd): Map 01's Base
## compounds driven on the main composition, every Player key a real event. Two CHECK lines with
## the measured numbers: base_exits (AC-6: each Unit type straight out of the gate from each
## SpawnPoint marker of both Bases, two runs at a time, throttle only, touching no wall, tower or
## leg; each run's time and least gap) and base_flag_run (AC-6 and the win: Player 1's Motorbike
## drives in through Base2's gate, the Round hands it the Flag under the tank, it reverses out,
## turns, is refuelled and drives home clear of the cover by map_kit.gd's pursuit to the delivery
## and the win). Base-local -Z leads out of a gate. Implements:
## production/epics/wasteland-fire/story-007-the-map.md AC-6 (the exit end and the raid start sit
## clear of the cover as built); design/rules.md "Units", "Resources". Tooling.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=map_bases

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks and the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 004 helpers (canister_kit.gd): the Round's Flag and win record, drive_until().
const Flags: GDScript = preload("res://tools/evidence/split_screen/canister_kit.gd")
## The Story 007 helpers (map_kit.gd): the staging, the wall contact, the pursuit, the tick log.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: both Players confirm the Motorbike with their keys.
const OWN_CHOICE: bool = true
## The Motorbike's index into the data: the raider (it carries, and turns tightest).
const MOTORBIKE: int = 0
## Base-local z an exit ends at, its centre 15 m beyond the gate's outer face: the wrecks at
## (+-80, 5) stand in the spare markers' lanes from about -34 on (the cover as built).
const EXIT_END_Z: float = -30.0
## Ticks an exit may take before it fails.
const EXIT_LIMIT_TICKS: int = 360
## Base-local z of a gate's outer face: a centre past it is out of the compound.
const GATE_Z: float = -15.0
## Base-local z the raid starts at, on Base2's gate axis facing in: clear of the long container at
## (58, 0) (the cover as built).
const RAID_START_Z: float = -50.0
## Base-local z the Motorbike reverses to after the pick-up, before its U-turn.
const REVERSE_TO_Z: float = -28.0
## The U-turn ends once the heading is within this of the way home, degrees.
const HOME_HEADING_DEG: float = 20.0
## The U-turn's steer key: 1 is left, north for a Unit facing +X, toward the lane home.
const TURN_STEER: int = 1
## Where Player 2's Unit waits during the raid, off every lane, world metres.
const PARK_SPOT: Vector3 = Vector3(0.0, 0.0, 14.0)
## The route home after the U-turn, world (x, z) metres: the lane along z -15.5 between the north
## wrecks (their tips at z -12.4) and the canyon rock's south face (z -20), through both fords,
## then onto Base1's gate axis west of the wreck at (-80, 5) and in through the gate.
const HOME_ROUTE: Array[Vector2] = [Vector2(80.0, -15.5), Vector2(-70.0, -15.5), Vector2(-88.0, 0.0),
	Vector2(-150.0, 0.0)]
## Ticks the U-turn and the run home may each take before they give up.
const RAID_LIMIT_TICKS: int = 900

var _harness: Harness
var _kit: Kit
var _flags: Flags
var _map: Map
var _bases: Array[Base] = []
var _cover_shapes: Array[Node] = []
var _tps: float = 0.0
var _most_drift: float = 0.0
var _raid: Dictionary[StringName, float] = {}


## Makes both Players' first choice with their fire keys, runs both checks, then the RESULT line.
## The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_flags = Flags.new(harness, _kit)
	_map = Map.new(harness, _kit)
	_tps = float(_harness.ticks_in(1.0))
	_bases.assign([_map.map.player_1_base, _map.map.player_2_base])
	var cover: Node = _map.find("Cover")
	if cover != null:
		_cover_shapes = cover.find_children("*", "CollisionShape3D", true, false)
	await _harness.confirm_choices()
	var exits: String = await _exits()
	var raid: String = await _flag_run()
	_harness.finish(exits + " " + raid)


## base_exits (AC-6): each type from each marker of both Bases (_exit_pair()); the times per type
## and the least gap of its runs in the detail.
func _exits() -> String:
	var problems: PackedStringArray = []
	var parts: PackedStringArray = []
	var types: Array[UnitStats] = _flags.controller.unit_types()
	var contacts: int = 0
	var runs: int = 0
	for type_index: int in types.size():
		var times: PackedStringArray = []
		var least: float = INF
		for marker_index: int in 1 + _bases[Harness.PLAYER_1].spare_spawn_points.size():
			var pair: Array[Vector3] = await _exit_pair(type_index, marker_index, problems)
			times.append("%.2f/%.2f" % [pair[0].x, pair[1].x])
			least = minf(least, minf(pair[0].z, pair[1].z))
			contacts += int(pair[0].y + pair[1].y)
			runs += pair.size()
		parts.append("%s %s s, least gap %.3f m" % [types[type_index].type_id, " ".join(times), least])
	_kit.verdict("base_exits", problems, "%d runs, two at a time, straight from standstill to Base-local z %.0f, no steer key; seconds from SpawnPoint, SpareSpawnLeft, SpareSpawnRight as Base1/Base2: %s; wall-contact ticks %d, most drift %.4f m" % [
		runs, EXIT_END_Z, "; ".join(parts), contacts, _most_drift])
	return "exit_runs=%d exit_contacts=%d" % [runs, contacts]


## One exit for each Player at once, both of one type from the marker of one index in their own
## Base: staged at rest there with a full tank (map_kit.gd), the throttle held until the centre is
## at EXIT_END_Z. A problem for a run that did not get there or touched a wall. Returns (seconds,
## wall-contact ticks, least gap) per Player.
func _exit_pair(type_index: int, marker_index: int, problems: PackedStringArray) -> Array[Vector3]:
	var markers: Array[Marker3D] = [_marker(_bases[0], marker_index), _marker(_bases[1], marker_index)]
	var types: Array[int] = [type_index, type_index]
	var spots: Array[Vector3] = [markers[0].global_position, markers[1].global_position]
	var facings: Array[Vector3] = [-markers[0].global_transform.basis.z, -markers[1].global_transform.basis.z]
	await _map.stage(types, spots, facings, true)
	var done: Array[int] = [-1, -1]
	var touched: Array[int] = [0, 0]
	_exit_tick(markers, 0, done, touched)
	for count: int in range(1, EXIT_LIMIT_TICKS + 1):
		await _kit.tick()
		_exit_tick(markers, count, done, touched)
		if done[0] > 0 and done[1] > 0:
			break
	_harness.release_all()
	var results: Array[Vector3] = []
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _map.units[player]
		var gap: float = _clearance(_bases[player], markers[player], unit.stats.collision_size)
		var label: String = "%s P%d %s/%s" % [unit.type_id, player + 1, _bases[player].name, markers[player].name]
		_kit.need(problems, done[player] > 0, label + " did not reach local z %.0f" % EXIT_END_Z)
		_kit.need(problems, touched[player] == 0 and gap > 0.0, label + " touched on %d ticks, gap %.3f m" % [touched[player], gap])
		results.append(Vector3(done[player] / _tps, touched[player], gap))
		fields.append("p%d_s=%.3f p%d_contacts=%d p%d_gap=%.3f" % [player + 1, done[player] / _tps, player + 1, touched[player], player + 1, gap])
	_split("exit type=%s marker=%s %s" % [_map.units[0].type_id, markers[0].name, " ".join(fields)])
	return results


## Both Players' exit tick: after a tick (count above 0) a Player whose run goes on counts a wall
## contact, keeps the most drift off its marker's line and is done once its centre is at
## EXIT_END_Z; then its keys: the throttle while it runs, the reverse key once done until it stops.
func _exit_tick(markers: Array[Marker3D], count: int, done: Array[int], touched: Array[int]) -> void:
	for player: int in Kit.PLAYERS:
		var unit: Unit = _map.units[player]
		var local: Vector3 = _bases[player].to_local(unit.global_position)
		if count > 0 and done[player] < 0:
			_most_drift = maxf(_most_drift, absf(local.x - _bases[player].to_local(markers[player].global_position).x))
			touched[player] += 1 if _map.wall_contact(unit) else 0
			done[player] = count if local.z <= EXIT_END_Z else -1
		var braking: bool = done[player] > 0 and unit.current_speed > 0.0
		_harness.drive(player, -1 if braking else (1 if done[player] < 0 else 0), 0)


## A Base's marker by index: its SpawnPoint marker (0), then its spares in order.
func _marker(base: Base, index: int) -> Marker3D:
	return base.spawn_point if index == 0 else base.spare_spawn_points[index - 1]


## The least lateral gap, metres, between a straight run's swept box (the Unit's box from its
## marker to EXIT_END_Z) and each box of a static body of the Base (walls, towers, Garage walls,
## tower legs) whose span along the run meets it; below zero the two boxes overlap.
func _clearance(base: Base, marker: Marker3D, size: Vector3) -> float:
	var start: Vector3 = base.to_local(marker.global_position)
	var least: float = INF
	for node: Node in base.find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		var box: BoxShape3D = shape.shape as BoxShape3D
		if box == null or not (shape.get_parent() is StaticBody3D):
			continue
		var bounds: AABB = base.global_transform.affine_inverse() * shape.global_transform * AABB(-box.size / 2.0, box.size)
		if bounds.end.z > EXIT_END_Z - size.z / 2.0 and bounds.position.z < start.z + size.z / 2.0:
			least = minf(least, maxf(bounds.position.x - (start.x + size.x / 2.0), (start.x - size.x / 2.0) - bounds.end.x))
	return least


## base_flag_run (AC-6 and the win): Player 2's Unit parked off every lane, Player 1's Motorbike at
## rest on Base2's gate axis facing in; in until the Round's pick-up, then reverse to REVERSE_TO_Z
## (canister_kit.gd's drive_until(), no steering), then _return_home(), each leg while the last
## succeeded, every tick logged (_log_raid()); the cover distance is kept apart for the gate axis.
func _flag_run() -> String:
	var raid: Base = _bases[Harness.PLAYER_2]
	var unit: Unit = _map.units[Harness.PLAYER_1]
	var types: Array[int] = [MOTORBIKE, MOTORBIKE]
	var spots: Array[Vector3] = [raid.to_global(Vector3(0.0, 0.0, RAID_START_Z)), PARK_SPOT]
	var facings: Array[Vector3] = [raid.global_transform.basis.z, Vector3.FORWARD]
	await _map.stage(types, spots, facings, true)
	_map.clear_log()
	_raid = {&"deepest_z": -INF, &"reversed_m": 0.0, &"northmost_z": INF, &"cover_m": INF, &"off_home_deg": NAN,
		&"refuel": NAN, &"home_ticks": -1.0, &"win_z": NAN}
	_kit.on_tick = _log_raid.bind(raid)
	var start: int = _harness.ticks
	var took: int = await _flags.drive_until(Harness.PLAYER_1, 1, INF, func() -> bool: return not _flags.pick_ups.is_empty())
	_raid[&"pick_z"] = raid.to_local(unit.global_position).z if took > 0 else NAN
	var out: int = -1
	if took > 0:
		out = await _flags.drive_until(Harness.PLAYER_1, -1, INF, func() -> bool: return raid.to_local(unit.global_position).z <= REVERSE_TO_Z)
	_raid[&"out_z"] = raid.to_local(unit.global_position).z if out > 0 else NAN
	_raid[&"back_m"] = _raid[&"reversed_m"]
	_split("raid legs=in,out pick_z=%.2f deepest_z=%.2f reversed_m=%.2f out_z=%.2f" % [_raid[&"pick_z"], _raid[&"deepest_z"], _raid[&"reversed_m"], _raid[&"out_z"]])
	_raid[&"axis_cover_m"] = _raid[&"cover_m"]
	_raid[&"cover_m"] = INF
	if out > 0:
		await _return_home(_bases[Harness.PLAYER_1], (_bases[Harness.PLAYER_1].global_position - raid.global_position).normalized())
	_kit.on_tick = Callable()
	_raid[&"seconds"] = (_harness.ticks - start) / _tps
	_flag_verdict(raid)
	return "raid_s=%.2f reverse_m=%.2f" % [_raid[&"seconds"], _raid[&"back_m"]]


## The raid's tick hook: map_kit.gd's log (the wall contacts), then the deepest Base2-local z, the
## metres driven in reverse, the northmost z and the least centre distance to a cover box.
func _log_raid(raid: Base) -> void:
	_map.log_tick()
	var trail: PackedVector3Array = _map.places[Harness.PLAYER_1]
	var at: Vector3 = trail[trail.size() - 1]
	var step: float = at.distance_to(trail[trail.size() - 2]) if trail.size() > 1 else 0.0
	_raid[&"deepest_z"] = maxf(_raid[&"deepest_z"], raid.to_local(at).z)
	_raid[&"reversed_m"] += step if _map.units[Harness.PLAYER_1].current_speed < 0.0 else 0.0
	_raid[&"northmost_z"] = minf(_raid[&"northmost_z"], at.z)
	for node: Node in _cover_shapes:
		var shape: CollisionShape3D = node as CollisionShape3D
		var half: Vector3 = (shape.shape as BoxShape3D).size / 2.0
		var local: Vector3 = shape.global_transform.affine_inverse() * at
		_raid[&"cover_m"] = minf(_raid[&"cover_m"], Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.z, 0.0)).length())


## Refuels Player 1's Motorbike to full for the run home (a tool may), holds its throttle at full
## lock (TURN_STEER) until it heads within HOME_HEADING_DEG of home, then drives HOME_ROUTE from
## where it stands by map_kit.gd's pursuit, the throttle held, until the Round ends.
func _return_home(home: Base, home_way: Vector3) -> void:
	var unit: Unit = _map.units[Harness.PLAYER_1]
	_raid[&"refuel"] = unit.refuel(unit.fuel_capacity)
	for _count: int in RAID_LIMIT_TICKS:
		_harness.drive(Harness.PLAYER_1, 1, TURN_STEER)
		await _kit.tick()
		_raid[&"off_home_deg"] = rad_to_deg((-unit.global_transform.basis.z).angle_to(home_way))
		if _raid[&"off_home_deg"] <= HOME_HEADING_DEG:
			break
	_split("raid leg=turn x=%.2f z=%.2f off_home_deg=%.2f" % [unit.global_position.x, unit.global_position.z, _raid[&"off_home_deg"]])
	var path: PackedVector2Array = [Vector2(unit.global_position.x, unit.global_position.z)]
	path.append_array(PackedVector2Array(HOME_ROUTE))
	_map.set_path(Harness.PLAYER_1, path)
	for count: int in range(1, RAID_LIMIT_TICKS + 1 if _raid[&"off_home_deg"] <= HOME_HEADING_DEG else 1):
		_map.steer(Harness.PLAYER_1, 1)
		await _kit.tick()
		if not _flags.round_overs.is_empty():
			_raid[&"home_ticks"] = count
			break
	_raid[&"win_z"] = home.to_local(unit.global_position).z
	_split("raid leg=home ticks=%d northmost_z=%.2f cover_m=%.2f win_z=%.2f" % [_raid[&"home_ticks"], _raid[&"northmost_z"], _raid[&"cover_m"], _raid[&"win_z"]])


## True when a Base's Flag seat lies inside its zone's box in the ground plane and under its tank,
## within the tank's radius (the beacon's box) of its vertical axis.
func _seat_inside(base: Base) -> bool:
	var shape: CollisionShape3D = base.zone.get_child(0) as CollisionShape3D
	var box: BoxShape3D = (shape.shape as BoxShape3D) if shape != null else null
	if box == null:
		return false
	var seat: Vector3 = base.canister_seat.global_position
	var local: Vector3 = shape.global_transform.affine_inverse() * seat
	var off_axis: Vector3 = seat - base.beacon.global_position
	return absf(local.x) <= box.size.x / 2.0 and absf(local.z) <= box.size.z / 2.0 \
		and Vector2(off_axis.x, off_axis.z).length() <= base.beacon.get_aabb().size.x / 2.0


## The base_flag_run verdict from the raid's numbers and the Round's record (canister_kit.gd): one
## pick-up, of Player 2's Flag by Player 1 inside Base2's gate, from a seat inside the zone under
## the tank; out to REVERSE_TO_Z; round; the win carrying it; no wall touched. The scenario never
## calls carry_by(): the Round's own rules hand the Flag over.
func _flag_verdict(raid: Base) -> void:
	var problems: PackedStringArray = []
	var took: bool = _flags.pick_ups.size() == 1 and _flags.pick_ups[0].x == Harness.PLAYER_1 and _flags.pick_ups[0].y == Harness.PLAYER_2
	var won: bool = _flags.round_overs.size() == 1 and _flags.round_overs[0].x == Harness.PLAYER_1
	var carried: bool = _flags.canisters[Harness.PLAYER_2].state == WaterCanister.State.CARRIED
	var seat_z: float = raid.to_local(raid.canister_seat.global_position).z
	var contacts: int = _map.contacts[Harness.PLAYER_1]
	_kit.need(problems, took and _raid[&"pick_z"] > GATE_Z, "no pick-up of Player 2's Flag inside Base2's gate (%d pick-ups)" % _flags.pick_ups.size())
	_kit.need(problems, _seat_inside(raid), "Base2's Flag seat (local z %.2f) is not inside its zone under its tank" % seat_z)
	_kit.need(problems, _raid[&"out_z"] <= REVERSE_TO_Z and _raid[&"off_home_deg"] <= HOME_HEADING_DEG, "the Motorbike did not get out and round")
	_kit.need(problems, won and carried, "no win by the delivery")
	_kit.need(problems, contacts == 0, "the Motorbike touched a wall on %d ticks" % contacts)
	_kit.verdict("base_flag_run", problems, ("Motorbike from Base2-local z %.0f on its gate axis: the Round's pick-up of Player 2's Flag at local z %.2f (seat z %.2f, in the zone "
		+ "under the tank %s); braked to z %.2f, then a reverse was needed (no forward-only route at the %.2f m turn radius): %.2f m in reverse, "
		+ "no steer key, out to z %.2f (%.2f m in all, with the U-turn's stop), the gate axis %.2f m (centre) from the nearest cover box; full lock north to %.2f deg off home; refuel() "
		+ "added %.2f; home along z -15.5 by the pursuit: northmost z %.2f, centre at least %.2f m from every cover box; delivered at Base1-local "
		+ "z %.2f, won %s after %.2f s, Flag carried %s; wall-contact ticks %d; the scenario never called carry_by()") % [RAID_START_Z, _raid[&"pick_z"],
		seat_z, _seat_inside(raid), _raid[&"deepest_z"], _map.units[0].stats.max_speed / _map.units[0].stats.turn_rate, _raid[&"back_m"],
		_raid[&"out_z"], _raid[&"reversed_m"], _raid[&"axis_cover_m"], _raid[&"off_home_deg"], _raid[&"refuel"], _raid[&"northmost_z"], _raid[&"cover_m"], _raid[&"win_z"],
		won, _raid[&"seconds"], carried, contacts])


## Prints one SPLIT progress line with the runner's time.
func _split(fields: String) -> void:
	print("SPLIT %s t=%.3f %s" % [_harness.scenario, _harness.time(), fields])
