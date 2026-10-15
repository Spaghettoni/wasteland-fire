extends RefCounted
## What still stops a Unit, and how tall it stands in the Gyrocopter's band, for the heights scenario (Story 020 AC-5 and AC-7):
## air_stops (Player 1's Gyrocopter at full throttle into a corner tower, a water tower leg, a depot tank and a Turret is
## stopped flush against it and goes no further), ground_stops (a Buggy driven into a Flag Wall, a Base wall panel, a field
## wall, a container, a wreck, a cliff, a water channel and the same four Tall pieces is stopped as it always was) and band
## (each Tall kind's drawn top and how far it stands above the Gyrocopter's lowest drawn point, the water tower's tank
## above the band, and the Turret's head, barrel and dome against the band, beside story 015's figures). Run by heights.gd.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The Tall pieces a Gyrocopter is driven at: [label, collider path from the Map, the world direction it drives, the lateral
## place (INF: the piece's centre)].
const AIR: Array = [
	["a corner tower", "Base1/Walls/TowerGateLeft", Vector3.LEFT, INF],
	["a water tower leg", "Base1/WaterTower/LegGateLeft", Vector3.LEFT, INF],
	["a depot tank", "Depot/FuelTanks/FuelTankSouth/Collider", Vector3.BACK, INF],
	["a Turret", "Base1/Turrets/TurretLeft", Vector3.LEFT, INF]]
## The pieces a ground Unit is driven at, with whether the piece is turned (a wreck: the Unit then drives along the piece's own axis).
const GROUND: Array = [
	["a Flag Wall", "Base1/Defences/FlagWallGate", Vector3.LEFT, INF, false],
	["a Base wall panel", "Base1/Walls/WallLeft/Panel4", Vector3.BACK, INF, false],
	["a field panel", "FieldWalls/FieldWallWest/Panel3", Vector3.RIGHT, INF, false],
	["a container", "Cover/Containers/ContainerWest", Vector3.BACK, INF, false],
	["a wreck", "Cover/Wrecks/WreckWestOuterSouth", Vector3.BACK, INF, true],
	["a cliff", "Cliffs/RockCanyonSouth", Vector3.FORWARD, -15.0, false],
	["a water channel", "Water/ChannelWest", Vector3.BACK, INF, false],
	["a corner tower", "Base1/Walls/TowerGateLeft", Vector3.LEFT, INF, false],
	["a water tower leg", "Base1/WaterTower/LegGateLeft", Vector3.LEFT, INF, false],
	["a depot tank", "Depot/FuelTanks/FuelTankSouth/Collider", Vector3.BACK, INF, false],
	["a Turret", "Base1/Turrets/TurretLeft", Vector3.LEFT, INF, false]]
## Story 015's figures for the Turret against the band it measured (2.454 to 4.256 m): the barrel's drawn extent and the dome's top.
const RECORD_015_BAND: Vector2 = Vector2(2.454, 4.256)
const RECORD_015_BARREL: Vector2 = Vector2(2.53, 2.77)
const RECORD_015_DOME: float = 3.0
## The ticks of full throttle held against a piece after the first touch, the travel they may add (m) and how far from flush
## against its face the Unit may stand (m).
const STOP_TICKS: int = 12
const STOP_MOVE: float = 0.05
const FLUSH_SLACK: float = 0.15

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick
var _rows: Array[Dictionary] = []


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.k.restore_all(true)
	_rows = _k.solid_rows(_k.map())
	await _air_stops()
	await _ground_stops()
	_band()


## The collision box of a piece by its path from the Map.
func _box(path: String) -> AABB:
	for row: Dictionary in _rows:
		if row["path"] == path:
			return row["shape_box"]
	return AABB()


## One drive of Player 1's Unit as a type at a piece, along dir (in the piece's own frame when it is turned): the start 14 m
## (and the Unit's half length) before the piece's near face, the lateral place the piece's centre or `lateral`, full
## throttle until the first touch and STOP_TICKS more. Judged: the floor under the start, the lane free to the piece, a touch,
## no further travel, the Unit short of the piece's centre and flush against the face. Returns a note.
func _stop(label: String, type_index: int, path: String, dir_local: Vector3, lateral: float, turned: bool, problems: PackedStringArray) -> String:
	var box: AABB = _box(path)
	var stats: UnitStats = _q.units.stats(type_index)
	var half: float = stats.collision_size.z / 2.0
	var dir: Vector3 = dir_local
	var reach: float = (absf(dir.x) * box.size.x + absf(dir.z) * box.size.z) / 2.0
	var centre: Vector3 = Vector3(box.get_center().x, 0.0, box.get_center().z)
	if turned:
		var shape_node: CollisionShape3D = _k.map().get_node(path).get_node("CollisionShape3D") as CollisionShape3D
		var size: Vector3 = (shape_node.shape as BoxShape3D).size * shape_node.global_basis.get_scale()
		dir = shape_node.global_basis.orthonormalized() * dir_local
		reach = (absf(dir_local.x) * size.x + absf(dir_local.z) * size.z) / 2.0
		centre = Vector3(shape_node.global_position.x, 0.0, shape_node.global_position.z)
	var start: Vector3 = centre - dir * (reach + Kit20.RUN_UP + half)
	if lateral != INF:
		if absf(dir.x) > 0.5:
			start.z = lateral
		else:
			start.x = lateral
	var face: float = dir.dot(centre) - reach
	var short_of: Vector3 = start + dir * (face - dir.dot(start) - 0.5)
	_q.kit.need(problems, _k.footprint_on_floor(start, dir, stats.collision_size) and _k.lane_free(start, short_of, stats.collision_size.x / 2.0, stats.collision_mask), "%s: the floor is missing under the Unit's footprint at the start %s or the lane to the piece is not free of other bodies" % [label, start])
	var rec: Dictionary = await _k.fly(0, type_index, start, dir, Kit20.RUN_LIMIT_TICKS, func(u: Unit) -> bool: return _q.map.wall_contact(u))
	var touch_at: int = (rec["touches"] as Array).find(true)
	var hit_speed: float = rec["speeds"][-1] if not (rec["speeds"] as PackedFloat64Array).is_empty() else 0.0
	var unit: Unit = _q.units.units[0]
	var contact_along: float = dir.dot(unit.global_position)
	for _tick: int in STOP_TICKS:
		_q.harness.drive(0, 1, 0)
		await _q.kit.tick()
	_q.harness.release_all()
	var moved: float = absf(dir.dot(unit.global_position) - contact_along)
	var flush: float = absf(dir.dot(unit.global_position) + half - face)
	_q.kit.need(problems, touch_at >= 0 and moved <= STOP_MOVE, "%s: touch at %d, %.3f m of travel in %d more ticks of throttle" % [label, touch_at, moved, STOP_TICKS])
	_q.kit.need(problems, dir.dot(unit.global_position) < dir.dot(centre), "%s: the %s went past the piece's centre" % [label, stats.type_id])
	_q.kit.need(problems, flush <= FLUSH_SLACK, "%s: %.3f m from flush against its face" % [label, flush])
	return "%s: %s stopped flush within %.3f m at %.1f m/s" % [label, stats.type_id, flush, hit_speed]


## air_stops (AC-5): the Gyrocopter is stopped by the four kinds of Tall piece that stop it.
func _air_stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for entry: Array in AIR:
		notes.append(await _stop(entry[0], Kit20.GYRO, entry[1], entry[2], entry[3], false, problems))
	measured.append("air_stops=%d" % AIR.size())
	_q.kit.verdict("air_stops", problems, "Player 1's Gyrocopter driven at full throttle at each Tall piece from 14 m is stopped by it (a wall contact) flush against its face and goes no further with the throttle held 12 more ticks, as it did before this story (the sea edge is the canyon flight's, in cross_low): %s" % "; ".join(notes))


## ground_stops (AC-5): a ground Unit stops at every low and every Tall piece as before.
func _ground_stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for entry: Array in GROUND:
		notes.append(await _stop(entry[0], Quick.BUGGY, entry[1], entry[2], entry[3], entry[4], problems))
	measured.append("ground_stops=%d" % GROUND.size())
	_q.kit.verdict("ground_stops", problems, "Player 1's Buggy driven at full throttle at %d kinds, seven low and four Tall, is stopped by each flush against its face (the turned wreck along its own axis) and goes no further: %s" % [GROUND.size(), "; ".join(notes)])


## band (AC-7): every Tall kind reaches into the Gyrocopter's drawn band, its lowest point to its top; the Turret's head overlaps
## it at the height set here as story 015 sized it; the water tower's tank stands above it.
func _band() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var band: Vector2 = _k.band()
	var kinds: Array = [["a corner tower", "Base1/Walls/TowerGateLeft"], ["a water tower leg", "Base1/WaterTower/LegGateLeft"], ["a depot tank", "Depot/FuelTanks/FuelTankSouth"], ["a Turret", "Base1/Turrets/TurretLeft"]]
	for entry: Array in kinds:
		var node: Node = _k.map().get_node(entry[1])
		var top: float = Kit20.drawn_top(node)
		var collider: float = _box(entry[1] if entry[1] != "Depot/FuelTanks/FuelTankSouth" else "Depot/FuelTanks/FuelTankSouth/Collider").end.y
		_q.kit.need(problems, collider > band.x and top > band.x, "%s: its collider (%.3f m) or drawn top (%.3f m) does not reach the band's lowest point (%.3f m)" % [entry[0], collider, top, band.x])
		notes.append("%s: collider %.3f m, drawn %.3f m, %.3f m above the lowest point" % [entry[0], collider, top, top - band.x])
	var tank: MeshInstance3D = _k.map().get_node("Base1/WaterTower/Tank") as MeshInstance3D
	var tank_box: AABB = tank.global_transform * tank.get_aabb()
	_q.kit.need(problems, tank_box.position.y > band.y, "the water tower's tank (bottom %.3f m) is not above the band's top (%.3f m)" % [tank_box.position.y, band.y])
	var head: AABB = Kit20.drawn_box(_k.map().get_node("Base1/Turrets/TurretLeft/Look/Head")) as AABB
	var barrel: AABB = Kit20.drawn_box(_k.map().get_node("Base1/Turrets/TurretLeft/Look/Head/Barrel")) as AABB
	var dome: AABB = Kit20.drawn_box(_k.map().get_node("Base1/Turrets/TurretLeft/Look/Head/Dome")) as AABB
	_q.kit.need(problems, head.end.y > band.x and head.position.y < band.y, "the Turret's head (%.3f to %.3f m) does not overlap the band (%.3f to %.3f m)" % [head.position.y, head.end.y, band.x, band.y])
	_q.kit.need(problems, barrel.position.y >= band.x and barrel.end.y <= band.y, "the Turret's barrel (%.3f to %.3f m) is not inside the band" % [barrel.position.y, barrel.end.y])
	measured.append("band=%.4f..%.4f turret_head=%.3f..%.3f" % [band.x, band.y, head.position.y, head.end.y])
	_q.kit.verdict("band", problems, "the Gyrocopter's drawn band at the flying height is %.4f to %.4f m (story 015 measured %.3f to %.3f): %s; the water tower's tank (bottom %.3f m) stands %.3f m above the band, so only its legs meet a Gyrocopter; the Turret's head is drawn %.3f to %.3f m and overlaps the band by %.3f m (barrel %.3f to %.3f m wholly inside it, story 015: %.2f to %.2f; the dome's top %.3f m stands %.3f m over the band's lowest point, story 015: %.2f m, %.3f m over its %.3f)" % [
		band.x, band.y, RECORD_015_BAND.x, RECORD_015_BAND.y, "; ".join(notes), tank_box.position.y, tank_box.position.y - band.y, head.position.y, head.end.y, minf(head.end.y, band.y) - maxf(head.position.y, band.x), barrel.position.y, barrel.end.y, RECORD_015_BARREL.x, RECORD_015_BARREL.y, dome.end.y, dome.end.y - band.x, RECORD_015_DOME, RECORD_015_DOME - RECORD_015_BAND.x, RECORD_015_BAND.x])
