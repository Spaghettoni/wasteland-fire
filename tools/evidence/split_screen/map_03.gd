extends RefCounted
## Scenario map_03 of the split screen evidence harness (split_screen_harness.gd): Map 03, the archipelago (Stories 053 and
## 054), two Players with the shipped game's opt-ins. CHECK lines:
##  A1 the Map: it loads with no engine error, the Round begins, each Player starts in its own Garage (the Base), each Team's
##     Flag stands in its own fortress far from it (over 100 m), and Teal's pieces are the mirror images of Orange's.
##  A2 the sea: a Buggy driven north out of Orange's Garage island stops at the shore; a Gyrocopter driven the same way
##     flies on over the sea.
##  A3 a ford: a Buggy driven from the Garage island along the ford to the middle island reaches it.
##  A6 the Turrets (Martin, 2026-10-26): each Team's Base lists 6 Turrets (the fortress's 2 at the Gate and 1 outside each other
##     wall, and 1 at the Garage), every one armed at the other Team.
##  A5 the shores (Martin, 2026-10-26): at each end of each ford a Buggy standing on the island 2.5 m from where the water
##     begins, facing along the ford, is in no ford's slowing zone; 3 m out on the water it is in that ford's.
##  A4 the Garage: a Motorbike carrying Teal's Flag inside Orange's fortress wins nothing; inside Orange's Garage it wins the
##     Round for Orange (Story 057). The swap answers in the Garage and not in the fortress.
## Implements: production/epics/wasteland-fire/story-054-map-03-archipelago.md AC-1 to AC-5 and
## production/epics/wasteland-fire/story-053-garage-and-flag-fortress.md AC-1 to AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=map_03

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_03/map_03.tscn"
const OWN_CHOICE: bool = true
const TEAMS: bool = true
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
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const MORE_TOKENS: bool = true
const WATCHDOG_SECONDS: float = 600.0

const MOTORBIKE: int = 0
const BUGGY: int = 1
const GYROCOPTER: int = 3
const SETTLE: int = 30
## A2: where the run toward the sea starts (Orange's Garage island, facing north) and for how long.
const SHORE_START: Vector3 = Vector3(-80.0, 0.0, -96.0)
const SHORE_TICKS: int = 240
## The island's north shore lies a little north of z -110 and the Map's edge stops even a Gyrocopter at z -120; free, a
## Buggy would end far past the shore.
const SHORE_LIMIT: float = -116.0
## A3: the ford from the Garage island to the middle island, its start and direction.
const FORD_START: Vector3 = Vector3(-54.0, 0.0, -56.0)
const FORD_TICKS: int = 300
const MIDDLE_REACHED: Vector2 = Vector2(-34.0, -36.0)
## A5: per ford end, its name, a point on the island 2.5 m from the water and a point 3 m out on it, and the ford's yaw in
## degrees, along its centre line. Computed by tools/maps/build_map_03.py's outlines (west and the two shared fords).
const SHORES: Array = [
	[&"FordWest1", Vector3(-48.08, 0, -50.16), Vector3(-44.01, 0, -46.46), 47.73],
	[&"FordWest1", Vector3(-29.28, 0, -33.07), Vector3(-33.35, 0, -36.77), 47.73],
	[&"FordWest2", Vector3(-101.00, 0, -47.00), Vector3(-101.00, 0, -41.50), 0.00],
	[&"FordWest2", Vector3(-101.00, 0, 49.00), Vector3(-101.00, 0, 43.50), 0.00],
	[&"FordWest3", Vector3(-31.15, 0, 31.20), Vector3(-34.37, 0, 35.66), -35.84],
	[&"FordWest3", Vector3(-55.39, 0, 64.76), Vector3(-52.17, 0, 60.31), -35.84],
	[&"FordNorth", Vector3(-42.45, 0, -100.00), Vector3(-36.95, 0, -100.00), 90.00],
	[&"FordNorth", Vector3(42.45, 0, -100.00), Vector3(36.95, 0, -100.00), 90.00],
	[&"FordSouth", Vector3(-60.70, 0, 104.00), Vector3(-55.20, 0, 104.00), 90.00],
	[&"FordSouth", Vector3(60.70, 0, 104.00), Vector3(55.20, 0, 104.00), 90.00],
]
const FAR: float = 100.0
## A6: the Gate's 2, 3 more around the fortress and 1 at the Garage.
const TURRETS_PER_BASE: int = 6
const MIRROR_TOLERANCE: float = 0.05

var _h: Harness
var _kit: Kit
var _split: SplitScreen
var _controller: MatchController
var _units: Array[Unit] = []


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_split = _h.split
	_controller = _split.match_controller
	_units = _split.all_units()
	_controller.choose(0, BUGGY)
	_controller.choose(1, GYROCOPTER)
	await _kit.advance(SETTLE)
	_check_map()
	await _check_sea()
	await _check_ford()
	await _check_shores()
	_check_turrets()
	await _check_fortress()
	_h.finish("map=map_03")


func _check_map() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var bases: Array[Base] = [_split.field.player_1_base, _split.field.player_2_base]
	var lines: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var base: Base = bases[player]
		var in_garage: bool = base.zone.overlaps_body(_units[player])
		var apart: float = base.zone.global_position.distance_to(base.flag_seat.global_position)
		_kit.need(problems, in_garage, "Player %d did not start in its Garage" % (player + 1))
		_kit.need(problems, base.flag_zone != null, "Player %d's Base has no fortress zone" % (player + 1))
		_kit.need(problems, apart > FAR, "Player %d's Flag is %.0f m from its Garage" % [player + 1, apart])
		lines.append("P%d Garage %s, Flag %.0f m away in %s" % [player + 1, _flat(base.global_position), apart, base.flag.get_parent().name])
	var a: Vector3 = bases[0].flag_seat.global_position
	var b: Vector3 = bases[1].flag_seat.global_position
	var g1: Vector3 = bases[0].global_position
	var g2: Vector3 = bases[1].global_position
	var mirrored: bool = absf(a.x + b.x) < MIRROR_TOLERANCE and absf(a.z - b.z) < MIRROR_TOLERANCE and absf(g1.x + g2.x) < MIRROR_TOLERANCE and absf(g1.z - g2.z) < MIRROR_TOLERANCE
	_kit.need(problems, mirrored, "Teal's Garage and seat are not Orange's mirror images: %s %s, %s %s" % [g1, g2, a, b])
	_kit.need(problems, not _controller.is_round_over() and _controller.is_alive(0) and _controller.is_alive(1), "the Round did not begin")
	var opposite: bool = g1.z < 0.0 and b.z > 0.0 and signf(g1.x) != signf(b.x)
	_kit.need(problems, opposite, "Teal's Flag is not in the corner opposite Orange's Garage")
	_kit.verdict("A1_the_map", problems, "%s; mirrored %s; Orange's Garage %s, the Flag it goes for %s (opposite %s)" % ["; ".join(lines), mirrored, _flat(g1), _flat(b), opposite])


func _check_sea() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var ends: PackedStringArray = PackedStringArray()
	var north: Vector3 = Vector3.FORWARD
	var buggy_z: float = await _run(0, SHORE_START, north, SHORE_TICKS)
	_kit.need(problems, buggy_z > SHORE_LIMIT, "the Buggy ended at z %.1f, past the shore" % buggy_z)
	ends.append("Buggy stopped at z %.1f" % buggy_z)
	var gyro_z: float = await _run(1, SHORE_START + Vector3(6.0, 0.0, 0.0), north, SHORE_TICKS)
	_kit.need(problems, gyro_z < SHORE_LIMIT, "the Gyrocopter ended at z %.1f, short of the sea" % gyro_z)
	ends.append("Gyrocopter flew on to z %.1f" % gyro_z)
	_kit.verdict("A2_the_sea", problems, "from %s north for %d ticks: %s (the shore is about z -110)" % [_flat(SHORE_START), SHORE_TICKS, ", ".join(ends)])


func _check_ford() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var way: Vector3 = Vector3(1.0, 0.0, 1.0).normalized()
	_h.place(_units[0], _facing(FORD_START, way), _split.all_cameras()[0])
	await _kit.advance(2)
	_h.drive(0, 1, 0)
	await _kit.advance(FORD_TICKS)
	_h.drive(0, 0, 0)
	var at: Vector3 = _units[0].global_position
	_kit.need(problems, at.x > MIDDLE_REACHED.x and at.z > MIDDLE_REACHED.y, "the Buggy ended at %s, not on the middle island" % _flat(at))
	_kit.verdict("A3_a_ford", problems, "a Buggy from %s along the ford for %d ticks ended at %s (the middle island begins about %s)" % [_flat(FORD_START), FORD_TICKS, _flat(at), MIDDLE_REACHED])


func _check_turrets() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var counts: Array[int] = []
	var armed: Array[int] = []
	for base: Base in [_split.field.player_1_base, _split.field.player_2_base]:
		var turrets: Array[Turret] = []
		for structure: Structure in base.structures:
			if structure is Turret:
				turrets.append(structure as Turret)
		counts.append(turrets.size())
		armed.append(turrets.filter(func(turret: Turret) -> bool: return turret.get(&"_target") != null).size())
	_kit.need(problems, counts == [TURRETS_PER_BASE, TURRETS_PER_BASE], "Turrets per Base %s" % [counts])
	_kit.need(problems, armed == counts, "armed %s of %s" % [armed, counts])
	_kit.verdict("A6_the_turrets", problems, "Turrets per Base %s, armed %s" % [counts, armed])


func _check_shores() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var fords: Array[Ford] = []
	for node: Node in _split.field.find_children("*", "Ford", true, false):
		fords.append(node as Ford)
	var unit: Unit = _units[0]
	var land_dry: int = 0
	var water_wet: int = 0
	for shore: Array in SHORES:
		var ford: Ford = _split.field.get_node(NodePath(String(shore[0]))) as Ford
		var heading: Basis = Basis(Vector3.UP, deg_to_rad(float(shore[3])))
		for wet: bool in [false, true]:
			var at: Vector3 = shore[2] if wet else shore[1]
			_h.place(unit, Transform3D(heading, at), _split.all_cameras()[0])
			await _kit.advance(4)
			var inside: PackedStringArray = PackedStringArray()
			for each: Ford in fords:
				if each.overlaps_body(unit):
					inside.append(each.name)
			if wet:
				_kit.need(problems, ford.overlaps_body(unit), "%s: 3 m out on the water at %s the Buggy is not in its zone" % [shore[0], _flat(at)])
				water_wet += 1 if ford.overlaps_body(unit) else 0
			else:
				_kit.need(problems, inside.is_empty(), "%s: on the island at %s the Buggy is in %s" % [shore[0], _flat(at), ", ".join(inside)])
				land_dry += 1 if inside.is_empty() else 0
	_kit.verdict("A5_the_shores", problems, "%d ford ends: on the island 2.5 m from the water, in no ford %d of %d; 3 m out on the water, in the ford %d of %d" % [
		SHORES.size(), land_dry, SHORES.size(), water_wet, SHORES.size()])


func _check_fortress() -> void:
	var problems: PackedStringArray = PackedStringArray()
	_units[0].destroy()
	await _kit.advance(5)
	_controller.choose(0, MOTORBIKE)
	await _kit.advance(int(_controller.rules.respawn_delay_seconds * Engine.physics_ticks_per_second) + SETTLE)
	var bases: Array[Base] = [_split.field.player_1_base, _split.field.player_2_base]
	var swap_in_garage: bool = _controller.can_swap(0)
	var teal_seat: Vector3 = bases[1].flag_seat.global_position
	_h.place(_units[0], _facing(teal_seat, Vector3.FORWARD), _split.all_cameras()[0])
	await _kit.advance(SETTLE)
	var carrying: bool = _controller.is_carrying(0)
	var fortress: Vector3 = bases[0].flag_zone.global_position
	_h.place(_units[0], _facing(fortress, Vector3.FORWARD), _split.all_cameras()[0])
	await _kit.advance(SETTLE)
	var swap_in_fortress: bool = _controller.can_swap(0)
	var over_in_fortress: bool = _controller.is_round_over()
	_h.place(_units[0], _facing(bases[0].zone.global_position, Vector3.FORWARD), _split.all_cameras()[0])
	await _kit.advance(SETTLE)
	var over: bool = _controller.is_round_over()
	var winner: int = _controller.winner_index()
	_kit.need(problems, swap_in_garage and not swap_in_fortress, "swap in the Garage %s, in the fortress %s" % [swap_in_garage, swap_in_fortress])
	_kit.need(problems, carrying, "the Motorbike did not take Teal's Flag in Teal's fortress")
	_kit.need(problems, not over_in_fortress, "the Round ended in Orange's fortress")
	_kit.need(problems, over and winner == 0, "in Orange's Garage: over %s, winner %d" % [over, winner])
	_kit.verdict("A4_the_garage", problems, "swap in the Garage %s, in the fortress %s; Teal's Flag taken %s; carried into Orange's fortress: over %s; into Orange's Garage: over %s, winner %d" % [
		swap_in_garage, swap_in_fortress, carrying, over_in_fortress, over, winner])


## Puts the Player's Unit at a point facing a way, drives it straight for the ticks and returns where it ends, z.
func _run(player: int, from: Vector3, way: Vector3, ticks: int) -> float:
	_h.place(_units[player], _facing(from, way), _split.all_cameras()[player])
	await _kit.advance(2)
	_h.drive(player, 1, 0)
	await _kit.advance(ticks)
	_h.drive(player, 0, 0)
	await _kit.advance(2)
	return _units[player].global_position.z


func _facing(at: Vector3, way: Vector3) -> Transform3D:
	var heading: Basis = Basis(Vector3.UP, atan2(-way.x, -way.z))
	return Transform3D(heading, Vector3(at.x, 0.0, at.z))


func _flat(at: Vector3) -> String:
	return "(%.0f, %.0f)" % [at.x, at.z]
