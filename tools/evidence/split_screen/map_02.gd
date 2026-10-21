extends RefCounted
## Scenario map_02 of the split screen evidence harness (split_screen_harness.gd): Map 02 plays as its schematic says (Story 038).
## The launch scene plays Map 02 (MAP_SCENE) with every shipped piece of the game. CHECK lines:
##  M1 layout: the field is Map 02; both Bases where the schematic puts them, each Gate facing west (Martin, 2026-10-21) and so
##     each Garage east of its Flag; 59 pieces of no Player (42 field wall panels, 6 in the ridge's gap, 4 small buildings, 7
##     wrecks), 9 Bushes, 6 outposts per Player (2 at the wall's gap, 4 round the Base), the Fuel zone and two ammunition zones; every listed piece has its mirror image across z = 0.
##  M2 canyon: a Buggy and a Gyrocopter driven flat out at the canyon for 4 s from the west, east, north and south stay inside the
##     floor's outline, and the Gyrocopter is not destroyed (the canyon's foot is the map's edge, not a Tall piece).
##  M3 ridge: a Buggy driven east into the ridge stops at its foot; a Gyrocopter from the same place flies over it.
##  M4 water: a Buggy driven south through the passage's water moves at about half the speed it had on the sand.
##  M5 ridge wall: a Buggy driven east at the wall in the ridge's gap stops at it; with its 6 panels down it drives into the passage.
##  M6 outposts: the two Turrets at the gap of the top half's wall are Player 1's: they fire at Player 2's Unit 14 m in front of the
##     gap and hit it, never at Player 1's in the same place; Player 1's Shots leave them whole and Player 2's damage them.
##  M7 supplies: a Buggy with a fifth of a tank refuels in the Fuel zone, one that fired its gun rearms in its half's ammunition
##     zone, and both MineLayers keep every one of the three zones clear of Mines.
##  M8 the Flag: with Player 2's Base Turrets down and its outposts standing, Player 1's Motorbike takes Player 2's Flag (the
##     outposts do not lock it) and wins by bringing it home; the restart stands every piece again.
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-2 to AC-5, AC-9.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=map_02

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
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
const WATCHDOG_SECONDS: float = 900.0

## The Bases' places (schematic) and the counts the schematic gives.
const BASE_PLACES: Array[Vector2] = [Vector2(76.0, 42.0), Vector2(76.0, 248.0)]
const NEUTRAL_COUNT: int = 59
const BUSH_COUNT: int = 9
## Per Player: the two at the wall's gap, then four more round the Base (Martin, 2026-10-21).
const OUTPOST_COUNT: int = 6
const FIELD_OUTPOSTS: int = 2
const ZONE_KINDS: Array[int] = [0, 1, 1]
## How far apart a piece and its mirror image may be, metres.
const MIRROR_TOLERANCE: float = 0.01
## The canyon runs: start (schematic) and direction.
## Each run is driven by the Player whose half it is in (index 2), so no Base Turret fires at it.
const CANYON_RUNS: Array = [[Vector2(40.0, 100.0), Vector3.LEFT, 0], [Vector2(125.0, 120.0), Vector3.RIGHT, 0],
	[Vector2(110.0, 40.0), Vector3.FORWARD, 0], [Vector2(110.0, 250.0), Vector3.BACK, 1]]
const RUN_TICKS: int = 240
## How far outside the outline a Unit's origin may stand at the edge (half the edge boxes' slack), metres.
const EDGE_SLACK: float = 0.3
## The ridge run: start (schematic) facing east; the ridge's foot there and its far side.
const RIDGE_START: Vector2 = Vector2(90.0, 66.0)
const RIDGE_FOOT_X: float = 102.2
const RIDGE_FAR_X: float = 118.0
## The water run: start, the stretch of sand measured and the stretch of water measured (schematic z).
const WATER_START: Vector2 = Vector2(125.0, 40.0)
const SAND_Z: Vector2 = Vector2(62.0, 78.0)
const WATER_Z: Vector2 = Vector2(84.0, 96.0)
const WATER_RUN_TICKS: int = 420
const WATER_SHARE: Vector2 = Vector2(0.4, 0.6)
## The ridge wall run: start facing east; the wall's near face and the passage beyond it (schematic x).
const GAP_START: Vector2 = Vector2(92.0, 145.0)
const WALL_NEAR_X: float = 104.3
const PASSAGE_X: float = 108.0
const GAP_RUN_TICKS: int = 180
## The outposts' test spot (schematic): 14 m in front of the top half's wall gap.
const OUTPOST_SPOT: Vector2 = Vector2(50.0, 90.0)
const WATCH_TICKS: int = 240
## Where a Buggy stands to shoot the top half's west Turret (schematic), and for how long it fires.
const SHOOT_SPOT: Vector2 = Vector2(47.0, 90.0)
const FIRE_TICKS: int = 60
## The supply tests: a fifth of a tank; ticks in a zone.
const LOW_TANK: float = 0.2
const ZONE_TICKS: int = 180
const FLAG_TICKS: int = 10

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	_check_layout()
	await _check_canyon()
	await _check_ridge()
	await _check_water()
	await _check_ridge_wall()
	await _check_outposts()
	await _check_supplies()
	await _check_flag()
	_m.h.finish("map=%s" % _m.field.scene_file_path.get_file())


func _check_layout() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var f: MapField = _m.field
	_m.kit.need(problems, f.scene_file_path == MAP_SCENE, "the field is %s" % f.scene_file_path)
	var details: PackedStringArray = PackedStringArray()
	for index: int in 2:
		var base: Base = f.player_1_base if index == 0 else f.player_2_base
		var want: Vector3 = M2.at(BASE_PLACES[index].x, BASE_PLACES[index].y)
		var gate_way: Vector3 = -base.global_basis.z
		var garage: Node3D = base.get_node("Garage/GarageFloor") as Node3D
		var flag: Node3D = base.flag_seat
		_m.kit.need(problems, base.global_position.distance_to(want) < 0.01, "Base %d at %s, not %s" % [index + 1, base.global_position, want])
		_m.kit.need(problems, gate_way.dot(Vector3.LEFT) > 0.999, "Base %d's Gate faces %s" % [index + 1, gate_way])
		_m.kit.need(problems, garage.global_position.x > flag.global_position.x + 1.0, "Base %d's Garage at x %.1f, its Flag at %.1f" % [index + 1, garage.global_position.x, flag.global_position.x])
		details.append("base%d (%.0f,%.0f) garage x %.1f flag x %.1f" % [index + 1, base.global_position.x, base.global_position.z, garage.global_position.x, flag.global_position.x])
	_m.kit.need(problems, f.neutral_structures.size() == NEUTRAL_COUNT, "%d pieces of no Player" % f.neutral_structures.size())
	_m.kit.need(problems, f.bushes.size() == BUSH_COUNT, "%d Bushes" % f.bushes.size())
	_m.kit.need(problems, f.player_1_outposts.size() == OUTPOST_COUNT and f.player_2_outposts.size() == OUTPOST_COUNT, "outposts %d and %d" % [f.player_1_outposts.size(), f.player_2_outposts.size()])
	var kinds: Array[int] = []
	for zone: SupplyZone in f.supply_zones:
		kinds.append(int(zone.kind))
	_m.kit.need(problems, kinds == ZONE_KINDS, "zone kinds %s" % [kinds])
	var listed: Array[Node3D] = []
	for piece: Structure in f.neutral_structures:
		listed.append(piece)
	for bush: Bush in f.bushes:
		listed.append(bush)
	for piece: Structure in f.player_1_outposts + f.player_2_outposts:
		listed.append(piece)
	for zone: SupplyZone in f.supply_zones:
		listed.append(zone)
	var unmatched: int = 0
	for node: Node3D in listed:
		var image: Vector3 = Vector3(node.global_position.x, 0.0, -node.global_position.z)
		var found: bool = false
		for other: Node3D in listed:
			if other.scene_file_path == node.scene_file_path and Vector3(other.global_position.x, 0.0, other.global_position.z).distance_to(image) < MIRROR_TOLERANCE:
				found = true
				break
		if not found:
			unmatched += 1
			problems.append("%s at %s has no mirror image" % [node.get_path(), node.global_position])
	_m.kit.verdict("M1_layout", problems, "%s; %d pieces, %d Bushes, outposts %d+%d, zones %s, %d of %d listed nodes mirrored" % [
		"; ".join(details), f.neutral_structures.size(), f.bushes.size(), f.player_1_outposts.size(), f.player_2_outposts.size(), kinds, listed.size() - unmatched, listed.size()])


func _check_canyon() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for run: Array in CANYON_RUNS:
		var player: int = run[2]
		await _m.park(1 - player)
		for type_index: int in [M2.BUGGY, M2.GYROCOPTER]:
			var start: Vector2 = run[0]
			await _m.put(player, type_index, M2.at(start.x, start.y), run[1])
			await _m.drive_for(player, 1, 0, RUN_TICKS)
			var unit: Unit = _m.units[player]
			var inside: float = M2.inside_by(unit.global_position)
			_m.kit.need(problems, inside > -EDGE_SLACK, "%s from (%.0f,%.0f) ended %.2f m outside" % [unit.stats.type_id, start.x, start.y, -inside])
			_m.kit.need(problems, unit.is_alive, "%s from (%.0f,%.0f) was destroyed at the edge" % [unit.stats.type_id, start.x, start.y])
			lines.append("%s %s %.2f m in" % [unit.stats.type_id, run[1], inside])
		await _m.park(player)
	_m.kit.verdict("M2_canyon", problems, "; ".join(lines))


func _check_ridge() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var ends: PackedFloat32Array = PackedFloat32Array()
	for type_index: int in [M2.BUGGY, M2.GYROCOPTER]:
		await _m.put(0, type_index, M2.at(RIDGE_START.x, RIDGE_START.y), Vector3.RIGHT)
		await _m.drive_for(0, 1, 0, RUN_TICKS)
		ends.append(_m.units[0].global_position.x + M2.CENTRE.x)
	_m.kit.need(problems, ends[0] < RIDGE_FOOT_X, "the Buggy reached x %.2f, past the ridge's foot at %.1f" % [ends[0], RIDGE_FOOT_X])
	_m.kit.need(problems, ends[1] > RIDGE_FAR_X, "the Gyrocopter reached x %.2f, not past the ridge (%.1f)" % [ends[1], RIDGE_FAR_X])
	_m.kit.verdict("M3_ridge", problems, "Buggy stopped at x %.2f, Gyrocopter reached x %.2f (schematic)" % [ends[0], ends[1]])


func _check_water() -> void:
	var problems: PackedStringArray = PackedStringArray()
	await _m.put(0, M2.BUGGY, M2.at(WATER_START.x, WATER_START.y), Vector3.BACK)
	var sand: Array[float] = []
	var water: Array[float] = []
	_m.h.drive(0, 1, 0)
	for _tick: int in WATER_RUN_TICKS:
		await _m.kit.tick()
		var unit: Unit = _m.units[0]
		var z: float = unit.global_position.z + M2.CENTRE.y
		var speed: float = Vector2(unit.velocity.x, unit.velocity.z).length()
		if z >= SAND_Z.x and z <= SAND_Z.y:
			sand.append(speed)
		elif z >= WATER_Z.x and z <= WATER_Z.y:
			water.append(speed)
	_m.h.drive(0, 0, 0)
	var on_sand: float = _mean(sand)
	var in_water: float = _mean(water)
	var share: float = in_water / on_sand if on_sand > 0.0 else 0.0
	_m.kit.need(problems, not sand.is_empty() and not water.is_empty(), "%d ticks on the sand, %d in the water" % [sand.size(), water.size()])
	_m.kit.need(problems, share >= WATER_SHARE.x and share <= WATER_SHARE.y, "the water's speed is %.2f of the sand's" % share)
	_m.kit.verdict("M4_water", problems, "Buggy %.2f m/s on the sand, %.2f m/s in the water (%.2f)" % [on_sand, in_water, share])


func _check_ridge_wall() -> void:
	var problems: PackedStringArray = PackedStringArray()
	await _m.put(0, M2.BUGGY, M2.at(GAP_START.x, GAP_START.y), Vector3.RIGHT)
	await _m.drive_for(0, 1, 0, GAP_RUN_TICKS)
	var blocked: float = _m.units[0].global_position.x + M2.CENTRE.x
	var panels: Array[Node] = _m.piece("FieldWalls/RidgeWall").get_children()
	for panel: Node in panels:
		(panel as Structure).destroy()
	await _m.put(0, M2.BUGGY, M2.at(GAP_START.x, GAP_START.y), Vector3.RIGHT)
	await _m.drive_for(0, 1, 0, GAP_RUN_TICKS)
	var through: float = _m.units[0].global_position.x + M2.CENTRE.x
	_m.kit.need(problems, panels.size() == 6, "%d panels in the ridge's gap" % panels.size())
	_m.kit.need(problems, blocked < WALL_NEAR_X, "the Buggy reached x %.2f, past the wall's face at %.1f" % [blocked, WALL_NEAR_X])
	_m.kit.need(problems, through > PASSAGE_X, "with the wall down the Buggy reached only x %.2f" % through)
	_m.kit.verdict("M5_ridge_wall", problems, "%d panels; standing: stopped at x %.2f; down: reached x %.2f" % [panels.size(), blocked, through])


func _check_outposts() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turrets: Array[Structure] = _m.field.player_1_outposts.slice(0, FIELD_OUTPOSTS)
	var fired: Array[int] = [0]
	for turret: Structure in turrets:
		_m.kit.need(problems, turret.player_index == 0, "%s belongs to player index %d" % [turret.name, turret.player_index])
		(turret as Turret).fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	var spot: Vector3 = M2.at(OUTPOST_SPOT.x, OUTPOST_SPOT.y)
	# Player 2 in front of the gap: fired on and hit.
	await _m.park(0)
	await _m.put(1, M2.BUGGY, spot, Vector3.FORWARD)
	var hp_before: float = _m.units[1].hit_points
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var p2_fired: int = fired[0]
	var p2_hit: float = hp_before - _m.units[1].hit_points
	# Player 1 in the same place, Player 2 parked: not fired on.
	await _m.park(1)
	await _m.put(0, M2.BUGGY, spot, Vector3.FORWARD)
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var p1_fired: int = fired[0]
	_m.kit.need(problems, p2_fired > 0 and p2_hit > 0.0, "at Player 2's Buggy the outposts fired %d Shots for %.1f damage" % [p2_fired, p2_hit])
	_m.kit.need(problems, p1_fired == 0, "at Player 1's Buggy the outposts fired %d Shots" % p1_fired)
	# Shots at the west outpost: Player 1's leave it whole, Player 2's damage it.
	var west: Structure = turrets[0]
	var shoot: Vector3 = M2.at(SHOOT_SPOT.x, SHOOT_SPOT.y)
	await _m.put(0, M2.BUGGY, shoot, west.global_position - shoot)
	var before_own: float = west.hit_points
	await _fire(0, FIRE_TICKS)
	var after_own: float = west.hit_points
	await _m.park(0)
	await _m.put(1, M2.BUGGY, shoot, west.global_position - shoot)
	await _fire(1, FIRE_TICKS)
	var after_other: float = west.hit_points
	await _m.park(1)
	_m.kit.need(problems, is_equal_approx(after_own, before_own), "Player 1's Shots took the outpost from %.1f to %.1f" % [before_own, after_own])
	_m.kit.need(problems, after_other < after_own, "Player 2's Shots left the outpost at %.1f" % after_other)
	_m.kit.verdict("M6_outposts", problems, "at Player 2: %d Shots, %.1f damage; at Player 1: %d Shots; outpost %.1f -> %.1f (own) -> %.1f (other)" % [
		p2_fired, p2_hit, p1_fired, before_own, after_own, after_other])


func _check_supplies() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var fuel_zone: SupplyZone = _m.field.supply_zones[0]
	var ammo_zone: SupplyZone = _m.field.supply_zones[1]
	await _m.put(0, M2.BUGGY, fuel_zone.global_position, Vector3.FORWARD, _m.small_tank(M2.BUGGY, LOW_TANK))
	var fuel_before: float = _m.units[0].fuel
	await _m.kit.advance(ZONE_TICKS)
	var fuel_after: float = _m.units[0].fuel
	await _m.put(0, M2.BUGGY, M2.at(OUTPOST_SPOT.x + 30.0, OUTPOST_SPOT.y + 40.0), Vector3.BACK)
	await _fire(0, FIRE_TICKS)
	var weapon: Weapon = _m.split.player_1_weapon
	var ammo_before: int = weapon.shots_left
	_m.h.place(_m.units[0], Transform3D(_m.units[0].global_basis, ammo_zone.global_position), _m.split.player_1_camera)
	await _m.kit.advance(ZONE_TICKS)
	var ammo_after: int = weapon.shots_left
	var guarded: int = 0
	for layer: MineLayer in [_m.split.player_1_mine_layer, _m.split.player_2_mine_layer]:
		for zone: SupplyZone in _m.field.supply_zones:
			guarded += 1 if layer.is_near_supply_zone(zone.global_position) else 0
	await _m.park(0)
	_m.kit.need(problems, fuel_after > fuel_before, "Fuel %.1f -> %.1f in the Fuel zone" % [fuel_before, fuel_after])
	_m.kit.need(problems, ammo_after > ammo_before, "ammo %d -> %d in the ammunition zone" % [ammo_before, ammo_after])
	_m.kit.need(problems, guarded == 6, "%d of 6 zone checks refuse a Mine" % guarded)
	_m.kit.verdict("M7_supplies", problems, "Fuel %.1f -> %.1f; ammo %d -> %d; Mines refused at %d of 6" % [fuel_before, fuel_after, ammo_before, ammo_after, guarded])


func _check_flag() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var enemy: Base = _m.field.player_2_base
	var downed: int = 0
	for piece: Structure in enemy.structures:
		if piece is Turret:
			piece.destroy()
			downed += 1
	var outposts_standing: int = 0
	for piece: Structure in _m.field.player_2_outposts:
		outposts_standing += 1 if piece.is_standing else 0
	await _m.park(1)
	await _m.put(0, M2.MOTORBIKE, enemy.flag_seat.global_position, Vector3.RIGHT)
	await _m.kit.advance(FLAG_TICKS)
	var taken: bool = enemy.flag.state == Flag.State.CARRIED
	_m.h.place(_m.units[0], Transform3D(_m.units[0].global_basis, _m.field.player_1_base.zone.global_position), _m.split.player_1_camera)
	await _m.kit.advance(FLAG_TICKS)
	var won: bool = _m.controller.is_round_over() and _m.controller.winner_index() == 0
	_m.kit.need(problems, downed == 2 and outposts_standing == OUTPOST_COUNT, "%d Base Turrets down, %d outposts standing" % [downed, outposts_standing])
	_m.kit.need(problems, taken, "Player 1's Motorbike did not take Player 2's Flag (state %d)" % enemy.flag.state)
	_m.kit.need(problems, won, "the Round is not won by Player 1 (over %s, winner %d)" % [_m.controller.is_round_over(), _m.controller.winner_index()])
	_m.controller.restart()
	await _m.kit.advance(FLAG_TICKS)
	var down: int = 0
	var all_pieces: Array[Structure] = []
	all_pieces.append_array(_m.field.neutral_structures)
	all_pieces.append_array(_m.field.player_1_outposts)
	all_pieces.append_array(_m.field.player_2_outposts)
	all_pieces.append_array(enemy.structures)
	for piece: Structure in all_pieces:
		if not piece.is_standing or piece.hit_points < piece.stats.max_hit_points:
			down += 1
	_m.kit.need(problems, down == 0, "%d pieces not whole after the restart" % down)
	await _m.h.confirm_choices()
	_m.kit.verdict("M8_flag", problems, "Base Turrets down %d, outposts standing %d; Flag taken %s; won %s; after the restart %d of %d pieces not whole" % [
		downed, outposts_standing, taken, won, down, all_pieces.size()])


## Holds a Player's fire key for a number of ticks.
func _fire(player: int, ticks: int) -> void:
	var key: Key = _m.h.fire_key(player)
	_m.h.set_key(key, true)
	await _m.kit.advance(ticks)
	_m.h.set_key(key, false)
	await _m.kit.advance(M2.SETTLE_TICKS)


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()
