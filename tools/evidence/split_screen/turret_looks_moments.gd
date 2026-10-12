extends RefCounted
## The moments of the turret_looks_showcase that need the Units in a fight or a drive (Story 015):
## firing_chase and firing_above (the four whole Turrets firing at both Players' Trucks, a Shot in
## flight in each view, with the gap between a barrel's tip and where its Shot left measured through
## each view's camera: R17, the Shot is drawn at the one shooting height), unit_past (each Player's
## Motorbike past its own Turret in the chase view, Player 1's so close behind it that the Turret hides
## it and Player 2's beyond that; the chase camera's line to the Unit, computed against the Turret's
## drum, says where) and gyro_at_face (a Gyrocopter stopped at a grown Turret's face under its head).
## The showcase hands this module itself and its kit, and reads each moment through its _line(),
## _need(), _views(), _set_looks() and _switch_views(). Run by turret_looks_showcase.gd. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md, Test Evidence (retained frames).
## Tooling only.

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd): the looks, the views' files, the ticks a moment holds.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## The Trucks under fire: metres past the Turrets' line on the Gate's axis (turrets_fps.gd's), and the
## ages in ticks a Shot may have when it is read.
const TRUCK_OUT: float = 8.0
const SHOT_AGE_FROM: int = 2
const SHOT_AGE_TO: int = 6
## The barrel's front face in the head's frame (the box of the scene: 1.2 m long at z -1.1), the
## metres past its Turret's axis the Motorbikes of unit_past stand (Player 1's close, Player 2's far),
## the chase camera's distance behind and height over its Unit and the height of its aim point (data:
## chase_camera_settings.tres), the Gyrocopter's run-up.
const BARREL_FRONT: Vector3 = Vector3(0.0, 0.0, -0.6)
const PAST: Array[float] = [3.5, 6.5]
const CAMERA_BEHIND: float = 13.0
const CAMERA_UP: float = 7.0
const AIM_UP: float = 1.0
const RUN_UP: float = 14.0
## The speed under which a Unit counts as stopped.
const STOPPED: float = 0.5

var _k: Kit13
## The showcase that runs this module.
var _host: RefCounted


func _init(host: RefCounted, kit: Kit13) -> void:
	_host = host
	_k = kit


## The moments, in order: firing in the view the cameras are on and then in the other, unit_past
## and gyro_at_face. A coroutine.
func run() -> void:
	await _firing_in_both_views()
	await _unit_past()
	await _gyro_at_face()


## Both Players' Trucks in front of the other Player's Gate on its axis, TRUCK_OUT past the Turrets'
## line, with the four whole Turrets firing: read when each Player's view has a Shot of the other
## Base's Turrets in flight, with the gap between a barrel's tip and where its Shot left measured
## through that view's camera. In the view the cameras are on. A coroutine.
func _firing(name: String) -> void:
	var q: Quick = _k.w.s.q
	for player: int in Kit.PLAYERS:
		await _k.clear(player)
	await _host._set_looks(0)
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.w.point(1 - player, Vector3(0.0, 0.0, Kit13.PLACES[0].z - TRUCK_OUT)))
		facings.append(-_k.w.way(1 - player, Vector3.FORWARD))
	var mark: int = _k.firing.size()
	await q.map.stage([Quick.TRUCK, Quick.TRUCK], spots, facings, true)
	var read: bool = false
	for _tick: int in Looks.LIMIT_TICKS:
		await q.kit.tick()
		var reads: PackedStringArray = []
		for player: int in Kit.PLAYERS:
			var record: Dictionary = _shot_of(1 - player, mark)
			if record.is_empty():
				break
			var who: Turret = record["turret"] as Turret
			var camera: ChaseCamera = q.units.cameras[player]
			var tip: Vector3 = (who.get_node(Looks.WORN_NAMES[1]) as Node3D).global_transform * BARREL_FRONT
			var left: Vector3 = record["muzzle"]
			reads.append("p%d_gap_m=%.2f p%d_gap_px=%.0f" % [player + 1, tip.distance_to(left), player + 1, camera.unproject_position(tip).distance_to(camera.unproject_position(left))])
		if reads.size() == Kit.PLAYERS.size():
			_host._need(q.units.units[0].is_alive and q.units.units[1].is_alive, "%s: a Truck was destroyed" % name)
			_host._line(name, "views=%s %s" % [", ".join(_host._views()), " ".join(reads)])
			read = true
			break
	_host._need(read, "%s: no Shot of the other Base's Turrets was in flight in both views at once" % name)
	await q.kit.advance(Looks.HOLD_TICKS)


## A Shot of a Base's Turrets fired since `mark` that is in flight now, aged SHOT_AGE_FROM to
## SHOT_AGE_TO ticks, or an empty Dictionary.
func _shot_of(base_index: int, mark: int) -> Dictionary:
	for index: int in range(mark, _k.firing.size()):
		var record: Dictionary = _k.firing[index]
		var shot_value: Variant = record["shot"]
		var age: int = Engine.get_physics_frames() - int(record["frame"])
		if (record["turret"] as Turret).player_index == base_index and is_instance_valid(shot_value) and (shot_value as Shot).is_inside_tree() and age >= SHOT_AGE_FROM and age <= SHOT_AGE_TO:
			return record
	return {}


## The four whole Turrets firing at both Trucks, in the view from above and then in the chase view.
func _firing_in_both_views() -> void:
	await _firing("firing_" + ("above" if _host._views()[0] == Looks.ABOVE_FILE else "chase"))
	await _host._switch_views()
	await _firing("firing_" + ("above" if _host._views()[0] == Looks.ABOVE_FILE else "chase"))


## Each Player's Motorbike past its own Base's right-hand Turret, driving out, in the chase view (the
## cameras are on it): Player 1's close behind the Turret, Player 2's further. The chase camera rides
## CAMERA_UP over and CAMERA_BEHIND behind its Unit and aims AIM_UP over its floor, so the line to the
## Unit crosses the drum's axis at a height, and the Turret hides the Unit while that line passes
## under its top: the metres past the axis up to which it does are computed for the Turret as it is
## (the dome's top from its collider) and printed. A coroutine.
func _unit_past() -> void:
	var q: Quick = _k.w.s.q
	if _host._views()[0] == Looks.ABOVE_FILE:
		await _host._switch_views()
	_host._need(_host._views() == PackedStringArray([Looks.CHASE_FILE, Looks.CHASE_FILE]), "unit_past: the cameras are on %s, not the chase view" % [_host._views()])
	await _host._set_looks(0)
	for player: int in Kit.PLAYERS:
		var out: Vector3 = _k.w.way(player, Vector3.FORWARD)
		await _k.clear(player)
		q.units.retype(player, Quick.MOTORBIKE, _k.turret(player, Kit13.RIGHT).global_position + out * PAST[player], out)
	await q.kit.advance(Looks.VIEW_TICKS)
	var shape: CollisionShape3D = _k.turret(0, Kit13.RIGHT).get_node("CollisionShape3D") as CollisionShape3D
	var top: float = shape.position.y + (shape.shape as CylinderShape3D).height / 2.0
	var hidden_to: float = _hidden_until(top)
	var gaps: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		gaps.append("%.1f" % PAST[player])
		_host._need(q.units.units[player].is_alive, "unit_past: Player %d's Unit is not alive" % [player + 1])
	_host._need(PAST[0] < hidden_to and PAST[1] > hidden_to, "unit_past: the Turret hides a Unit up to %.2f m past its axis, the frames stand at %s" % [hidden_to, gaps])
	_host._line("unit_past", "views=%s metres_past_the_axis=%s hidden_up_to=%.2f turret_top=%.2f" % [", ".join(_host._views()), ", ".join(gaps), hidden_to, top])


## How far past a Turret's axis a Unit driving straight out along its line stops being hidden by it
## from the chase camera: the line from the camera (CAMERA_BEHIND behind the Unit and CAMERA_UP over
## the floor) to the Unit's aim point (AIM_UP over it) passes under the Turret's top, inside the
## drum's radius of its axis, while the Unit is closer than this. Both are in the vertical plane of
## the Unit's line through the axis; the drum is a rectangle there. Metres.
func _hidden_until(top: float) -> float:
	var behind: float = 0.0
	var step: float = 0.01
	var past: float = -Kit13.RADIUS
	while past < 20.0:
		var low: float = past - CAMERA_BEHIND
		var hit: bool = false
		for index: int in 1301:
			var x: float = low + CAMERA_BEHIND * float(index) / 1300.0
			var height: float = CAMERA_UP + (AIM_UP - CAMERA_UP) * (x - low) / CAMERA_BEHIND
			if absf(x) <= Kit13.RADIUS and height <= top:
				hit = true
				break
		if hit:
			behind = past
		past += step
	return behind


## Player 1's Gyrocopter driven at its own Base's right-hand Turret at full throttle from RUN_UP out:
## read when it has stopped at the drum's face under the head. A coroutine.
func _gyro_at_face() -> void:
	var q: Quick = _k.w.s.q
	var turret: Turret = _k.turret(0, Kit13.RIGHT)
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var half: float = q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	await _k.clear(0)
	q.units.retype(0, Quick.GYROCOPTER, turret.global_position + out * (Kit13.RADIUS + half + RUN_UP), -out)
	await q.kit.advance(Kit13.SETTLE)
	var stopped: bool = false
	for _tick: int in Looks.LIMIT_TICKS:
		q.harness.drive(0, 1, 0)
		await q.kit.tick()
		var gap: float = Vector2(q.units.units[0].global_position.x - turret.global_position.x, q.units.units[0].global_position.z - turret.global_position.z).length()
		if gap <= Kit13.RADIUS + half + 0.05 and q.units.units[0].get_real_velocity().length() < STOPPED:
			stopped = true
			break
	q.harness.drive(0, 0, 0)
	await q.kit.advance(Looks.HOLD_TICKS)
	_host._need(stopped and Looks.look_shown(turret) == 0, "gyro_at_face: the Gyrocopter stopped %s at the Turret" % stopped)
	_host._line("gyro_at_face", "stopped=%s hover=%s views=%s" % [stopped, "under the head", ", ".join(_host._views())])
