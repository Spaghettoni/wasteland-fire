extends RefCounted
## What goes over a Flag Wall, for the flag_walls scenario (Story 012 AC-1 and AC-2): a Gyrocopter
## flies over the Gate-side Flag Wall of the other Player's box at full speed, across the box and
## out over the Garage-side one, its model rising over each as over the cover and settling back; one
## brakes to a stop inside the box; one is still stopped by a leg (gyro_over); and the seated Flag
## shows over the near Flag Wall in the view from above, from each of the four sides of the box at
## both Bases, within 20 m of the seat, while in the chase view the near Flag Wall hides it
## (flag_visible). Run by flag_walls_moves.gd. Implements:
## production/epics/wasteland-fire/story-012-flag-walls.md AC-1 and AC-2. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs.

## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, the model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The runner, for the chase view's settings.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

## Metres out of a face where a run starts (the centre is that and the half-length further).
const RUN: float = 14.0
## Ticks a run may take.
const RUN_LIMIT_TICKS: int = 420
## Base-local z where a crossing Gyrocopter brakes, and the least share of its top speed it keeps
## over a Flag Wall, and how far under the rise clearance its model may come, metres.
const BRAKE_Z: float = -3.0
const SPEED_SHARE: float = 0.9
const RISE_SLACK: float = 0.02
## The feathered speed of the slow entry, m/s, and the Base-local z where it brakes (0.7 m inside).
const SLOW: float = 4.0
const BRAKE_INSIDE_Z: float = Walls.SEAT.z - 0.6
## The box's inner half extent, metres: a Unit's centre inside it is inside the box.
const INNER: float = 1.3
## Metres from the seat where a Unit faces the box to see the Flag, the farthest that must show the
## Flag's top, and the Flag's middle and top above its seat (flag.gd: 0.94 m tall).
const DISTANCES: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
const SIGHT_LIMIT: float = 20.0
const FLAG_MIDDLE: float = 0.47
const FLAG_TOP: float = 0.94

var _w: Walls
## Per Player: the ticks its model was over a Flag Wall, the least height of its lowest point over
## the Flag Wall's top then, and its slowest real speed then (logged by _cross_tick()).
var _over: Array[int] = [0, 0]
var _clear: Array[float] = [INF, INF]
var _slowest: Array[float] = [INF, INF]


func _init(kit: Walls) -> void:
	_w = kit


## gyro_over, then flag_visible. A coroutine: await it.
func run() -> void:
	await _gyro_over()
	await _flag_visible()


## gyro_over (AC-2): both Players' Gyrocopters cross the other Player's box on its Gate axis at full
## speed; then one brakes to rest inside the box; then one is flown at a leg and stopped by it.
func _gyro_over() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var stats: UnitStats = q.units.stats(Quick.GYROCOPTER)
	var half: float = stats.collision_size.z / 2.0
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		var at: Array[Vector3] = _w.pose(1 - player, Walls.GATE, Walls.FACE + RUN + half)
		spots.append(at[0])
		facings.append(at[1])
	await q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], spots, facings, true)
	q.map.clear_log()
	q.kit.on_tick = _cross_tick
	var throttles: Array[int] = [1, 1]
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			var unit: Unit = q.units.units[player]
			if throttles[player] == 1 and _w.bases[1 - player].to_local(unit.global_position).z > BRAKE_Z:
				throttles[player] = -1
			elif throttles[player] == -1 and unit.current_speed <= 0.0:
				throttles[player] = 0
			q.harness.drive(player, throttles[player], 0)
		await q.kit.tick()
	q.kit.on_tick = Callable()
	q.harness.release_all()
	var clearance: float = (q.units.units[0].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel).rise_clearance
	var notes: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var past: float = _w.bases[1 - player].to_local(q.units.units[player].global_position).z - (Walls.SEAT.z + Walls.FACE)
		q.kit.need(problems, q.map.contacts[player] == 0, "p%d touched a wall %d times" % [player + 1, q.map.contacts[player]])
		q.kit.need(problems, _over[player] > 0 and _clear[player] >= clearance - RISE_SLACK, "p%d: its model came to %.3f m over a Flag Wall's top in %d ticks over one (rise clearance %.3f)" % [player + 1, _clear[player], _over[player], clearance])
		q.kit.need(problems, _slowest[player] >= SPEED_SHARE * stats.max_speed, "p%d slowed to %.2f m/s over a Flag Wall" % [player + 1, _slowest[player]])
		q.kit.need(problems, past > 0.0, "p%d ended %.2f m short of clearing the box" % [player + 1, -past])
		notes.append("p%d: model >= %.3f m over the 2 m top for %d ticks, never under %.1f m/s, out over the Garage side" % [player + 1, _clear[player], _over[player], _slowest[player]])
	notes.append(await _brake_inside(problems))
	notes.append(await _leg(problems))
	q.kit.verdict("gyro_over", problems, " | ".join(notes))


## Logs both Gyrocopters after a tick (the map kit's log), and for each the ticks its model's
## footprint covers a Flag Wall of the box it crosses, the least height of its lowest point over
## that Flag Wall's top, and its slowest real speed then.
func _cross_tick() -> void:
	var q: Quick = _w.s.q
	q.map.log_tick()
	for player: int in Kit.PLAYERS:
		var box: AABB = Quick.model_box(q.units.units[player])
		var top: float = -INF
		for side: int in Walls.SIDE_NAMES.size():
			var mesh: MeshInstance3D = _w.wall(1 - player, side).get_node("Mesh") as MeshInstance3D
			var wall_box: AABB = mesh.global_transform * mesh.get_aabb()
			if box.position.x < wall_box.end.x and box.end.x > wall_box.position.x and box.position.z < wall_box.end.z and box.end.z > wall_box.position.z:
				top = wall_box.end.y
		if top > -INF:
			_over[player] += 1
			_clear[player] = minf(_clear[player], box.position.y - top)
			_slowest[player] = minf(_slowest[player], q.map.real_speed(player, -1))


## Player 1's Gyrocopter enters the box on the Gate axis at SLOW m/s and brakes; the note says where
## it stopped. A problem when its centre is not inside the box or it touched a wall.
func _brake_inside(problems: PackedStringArray) -> String:
	var q: Quick = _w.s.q
	await _w.face(0, Quick.GYROCOPTER, 1, Walls.GATE, Walls.FACE + RUN)
	q.map.clear_log()
	q.kit.on_tick = q.map.log_tick
	var unit: Unit = q.units.units[0]
	for _tick: int in RUN_LIMIT_TICKS:
		var braking: bool = _w.bases[1].to_local(unit.global_position).z > BRAKE_INSIDE_Z
		q.harness.drive(0, (-1 if unit.current_speed > 0.0 else 0) if braking else (1 if unit.current_speed < SLOW else 0), 0)
		await q.kit.tick()
		if braking and unit.current_speed <= 0.0:
			break
	q.kit.on_tick = Callable()
	q.harness.release_all()
	await q.kit.advance(Walls.SETTLE)
	var at: Vector3 = _w.bases[1].to_local(unit.global_position) - Walls.SEAT
	q.kit.need(problems, absf(at.x) <= INNER and absf(at.z) <= INNER and q.map.contacts[0] == 0, "braking inside the box, the Gyrocopter stopped %.2f m from the seat across and %.2f along, with %d wall contacts" % [at.x, at.z, q.map.contacts[0]])
	return "braking from %.0f m/s inside the box it stopped %.2f m across and %.2f m along from the seat" % [SLOW, at.x, at.z]


## Player 1's Gyrocopter is flown at full throttle at the Gate-side leg beside the Flag Wall (the
## legs are on the map layer, which the Gyrocopter's mask has): the leg stops it, with a wall
## contact, and it does not get past the leg's outer face.
func _leg(problems: PackedStringArray) -> String:
	var q: Quick = _w.s.q
	var half: float = q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	var leg_face: float = Walls.SEAT.z - Walls.FACE
	var start: Vector3 = _w.point(1, Vector3(-2.0, 0.0, leg_face - RUN - half))
	await q.map.stage([Quick.GYROCOPTER, -1], [start, Vector3.ZERO], [_w.way(1, Vector3.BACK), Vector3.ZERO], true)
	q.map.clear_log()
	q.kit.on_tick = q.map.log_tick
	for _tick: int in RUN_LIMIT_TICKS / 2:
		q.harness.drive(0, 1, 0)
		await q.kit.tick()
	q.kit.on_tick = Callable()
	q.harness.release_all()
	var z: float = _w.bases[1].to_local(q.units.units[0].global_position).z
	q.kit.need(problems, q.map.contacts[0] > 0 and z <= leg_face - half + 0.15, "flown at the leg, the Gyrocopter had %d wall contacts and ended at local z %.2f (the leg's face is at %.2f)" % [q.map.contacts[0], z, leg_face])
	return "flown at the Gate-side leg it touched it on %d ticks and stopped at local z %.2f, short of its face at %.2f" % [q.map.contacts[0], z, leg_face]


## flag_visible (AC-1): Player 1's Unit is put at each distance on each of the four sides of each
## box, facing the seat, with its camera snapped and no tick between (camera_views.gd's T8 pattern),
## and the sight line from the camera to the Flag's middle and to its top is tested against the
## drawn box of every standing Flag Wall of that Base. In the view from above the top must show
## through SIGHT_LIMIT; the note gives the farthest distance each shows from. In the chase view the
## near Flag Wall must hide the top at every distance, so the check can fail.
func _flag_visible() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	await _w.restore_all()
	var camera: ChaseCamera = q.units.cameras[0]
	var unit: Unit = q.units.units[0]
	var home: Transform3D = unit.global_transform
	var above: ChaseCameraSettings = camera.settings
	var farthest: Array[Vector2] = []
	var chase_hidden: int = 0
	var chase_probes: int = 0
	for base_index: int in Kit.PLAYERS:
		var seat: Vector3 = _w.point(base_index, Walls.SEAT)
		for side: int in Walls.SIDE_NAMES.size():
			var far: Vector2 = Vector2.ZERO
			var middle_open: bool = true
			var top_open: bool = true
			for distance: float in DISTANCES:
				var at: Array[Vector3] = _w.pose(base_index, side, distance)
				var where: Transform3D = Transform3D(Basis(Vector3.UP, atan2(-at[1].x, -at[1].z)), Vector3(at[0].x, 0.0, at[0].z))
				camera.settings = above
				q.harness.place(unit, where, camera)
				middle_open = middle_open and not _hidden(camera, seat + Vector3.UP * FLAG_MIDDLE, base_index)
				var top_hidden: bool = _hidden(camera, seat + Vector3.UP * FLAG_TOP, base_index)
				top_open = top_open and not top_hidden
				far = Vector2(distance if middle_open else far.x, distance if top_open else far.y)
				q.kit.need(problems, distance > SIGHT_LIMIT or not top_hidden, "%s side %s at %.0f m: a Flag Wall hides the Flag's top from the view from above" % [_w.bases[base_index].name, Walls.SIDE_NAMES[side], distance])
				camera.settings = Harness.CHASE_CAMERA_SETTINGS
				q.harness.place(unit, where, camera)
				chase_probes += 1
				chase_hidden += 1 if _hidden(camera, seat + Vector3.UP * FLAG_TOP, base_index) else 0
			farthest.append(far)
	camera.settings = above
	q.harness.place(unit, home, camera)
	await q.kit.advance(Walls.SETTLE)
	q.kit.need(problems, chase_hidden == chase_probes, "in the chase view the Flag Wall hides the top in only %d of %d views, so the check cannot tell" % [chase_hidden, chase_probes])
	var least: Vector2 = Vector2(INF, INF)
	for far: Vector2 in farthest:
		least = Vector2(minf(least.x, far.x), minf(least.y, far.y))
	q.kit.verdict("flag_visible", problems, "%d views (2 Bases x 4 sides x %d distances) in the view from above: the Flag's top shows from every side through %.0f m (farthest shown: top %.0f m, middle %.0f m at the worst side); in the chase view the near Flag Wall hides the top in %d of %d" % [
		farthest.size() * DISTANCES.size(), DISTANCES.size(), SIGHT_LIMIT, least.y, least.x, chase_hidden, chase_probes])


## True when the drawn box of a standing Flag Wall of the Base crosses the line from the camera to
## the point.
func _hidden(camera: Camera3D, target: Vector3, base_index: int) -> bool:
	for side: int in Walls.SIDE_NAMES.size():
		var wall: Structure = _w.wall(base_index, side)
		var mesh: MeshInstance3D = wall.get_node("Mesh") as MeshInstance3D
		if wall.is_standing and (mesh.global_transform * mesh.get_aabb()).intersects_segment(camera.global_position, target) != null:
			return true
	return false
