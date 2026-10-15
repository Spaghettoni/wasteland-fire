extends RefCounted
## No Mines at the supply zones in the Story 024 scenario ammo_buildings, AC-4: a lay is refused where any part of the Mine would lie in a
## supply zone or within the margin of one, at all four zones (the two Fuel zones and the two ammunition zones), for both Players: the
## area test refuses a drop point 0.05 m inside each grown edge of every zone and not one 0.05 m outside (the height ignored, no zone
## handed: nothing refused); the real key lays nothing, keeps the count and shows "No Mines at a supply building" for about 1.5 s on that
## Player's notice line alone; a lay at the ammunition building's face reads the supply reason, not "No room for a Mine here", and one
## at its far face, outside the margin, reads "No room"; and everywhere else the rules of Story 014 hold: the canyon spots and the
## depot's five old Fuel Can spots are open ground, the two salt-flat spots are on a zone's edge and are refused. Real keys. Tooling
## only. Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-4.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/mines/data/mine_settings.tres"
## How far either side of a grown edge the checks stand, metres, and how far outside it a lay is made.
const STEP: float = 0.05
const LAY_OUTSIDE: float = 0.15
## The refusal's text and the ticks it stays on the notice line (1.5 s at 60 ticks a second).
const SUPPLY_TEXT: String = "No Mines at a supply building"
const ROOM_TEXT: String = "No room for a Mine here"
const NOTICE_TICKS: int = 90
## A drop point high above a zone, metres: the height is ignored.
const HIGH: float = 5.0
## The five old Fuel Can spots of the depot, the two canyon spots, and the two salt-flat spots (x, z).
const DEPOT_SPOTS: Array[Vector2] = [Vector2(-3, -3), Vector2(3, -3), Vector2(0, 0), Vector2(-3, 3), Vector2(3, 3)]
const CANYON_SPOTS: Array[Vector2] = [Vector2(-88, -26), Vector2(88, -26)]
const SALT_SPOTS: Array[Vector2] = [Vector2(-62, 14), Vector2(62, 14)]

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit24
var _q: Quick
var _settings: MineSettings


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as MineSettings


func run() -> void:
	_edges()
	_nothing_handed()
	await _refused_by_key()
	await _building_faces()
	await _edge_by_key()
	await _spots()


## The half extent of a zone's grown footprint, metres, along an axis of its own frame (x or z).
func _grown(zone: SupplyZone, along_x: bool) -> float:
	return (zone.size.x if along_x else zone.size.z) / 2.0 + _settings.supply_margin + _settings.trigger_radius


## A point of the zone's own frame (x, z) at a height, in the world.
func _world(zone: SupplyZone, local: Vector2, height: float = 0.0) -> Vector3:
	return zone.global_transform * Vector3(local.x, height, local.y)


## The area test at every grown edge of every zone, both Players' MineLayers: 0.05 m inside refuses, 0.05 m outside does not, at the
## middle of each side and at each corner (a corner is outside when either coordinate is), the height ignored.
func _edges() -> void:
	var problems: PackedStringArray = []
	var readings: int = 0
	for player: int in 2:
		var layer: MineLayer = _k.mines().layers[player]
		for index: int in Kit24.ZONE_PATHS.size():
			var zone: SupplyZone = _k.zone(index)
			var gx: float = _grown(zone, true)
			var gz: float = _grown(zone, false)
			var cases: Array = [
				[Vector2(gx - STEP, 0.0), true], [Vector2(gx + STEP, 0.0), false], [Vector2(-gx + STEP, 0.0), true], [Vector2(-gx - STEP, 0.0), false],
				[Vector2(0.0, gz - STEP), true], [Vector2(0.0, gz + STEP), false], [Vector2(0.0, -gz + STEP), true], [Vector2(0.0, -gz - STEP), false],
				[Vector2(gx - STEP, gz - STEP), true], [Vector2(gx + STEP, gz - STEP), false], [Vector2(-gx - STEP, -gz + STEP), false], [Vector2(-gx + STEP, -gz - STEP), false],
				[Vector2(0.0, 0.0), true]]
			for case: Array in cases:
				var refused: bool = layer.is_near_supply_zone(_world(zone, case[0]))
				readings += 1
				_q.kit.need(problems, refused == bool(case[1]), "Player %d's layer, zone %d, local %s: refuses %s, expected %s" % [player + 1, index, case[0], refused, case[1]])
			_q.kit.need(problems, layer.is_near_supply_zone(_world(zone, Vector2(0.0, 0.0), HIGH)) and layer.is_near_supply_zone(_world(zone, Vector2(gx - STEP, 0.0), -HIGH)), "Player %d's layer, zone %d: the height was not ignored" % [player + 1, index])
	var half: float = _grown(_k.zone(0), true)
	_q.kit.need(problems, is_equal_approx(half, _k.zone(0).size.x / 2.0 + 3.0 + 0.8), "the grown half extent is %.3f, not the zone's half plus 3.0 plus 0.8" % half)
	measured.append("supply_area_edges=%d_readings_grown_half_%.1f" % [readings, half])
	_q.kit.verdict("supply_area_edges", problems, "at all four zones, for both Players' MineLayers, a drop point 0.05 m inside each side of the zone's footprint grown by the margin (%.1f m) and the trigger radius (%.1f m) is refused and 0.05 m outside is not (corners outside when either coordinate is, a high or low point the same: %d readings), and the middle of every zone is refused" % [_settings.supply_margin, _settings.trigger_radius, readings])


## With no zone handed (a stand-in, the greybox field) the area test refuses nothing.
func _nothing_handed() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.mines().layers[0]
	var kept: Array[SupplyZone] = layer.supply_zones.duplicate()
	_q.kit.need(problems, kept.size() == Kit24.ZONE_PATHS.size(), "the layer was handed %d zones, not %d" % [kept.size(), Kit24.ZONE_PATHS.size()])
	layer.supply_zones = []
	for index: int in Kit24.ZONE_PATHS.size():
		_q.kit.need(problems, not layer.is_near_supply_zone(_k.centre(index)), "with no zone handed the middle of zone %d was refused" % index)
	layer.supply_zones = kept
	_q.kit.need(problems, layer.is_near_supply_zone(_k.centre(0)), "the zones were not given back")
	_q.kit.verdict("no_zone_handed_refuses_nothing", problems, "a MineLayer with no supply zone handed refused the middle of none of the four zones, and refused them again when the list was given back")


## Waits until both Players' notice lines are hidden (a refusal stays about 1.5 s), at most 200 ticks: the other Player's line must
## be quiet too, or a refusal of the one before reads as the other Player's notice.
func _wait_quiet(_player: int) -> void:
	for _tick: int in 200:
		if _k.mines().note(0) == "hidden" and _k.mines().note(1) == "hidden":
			return
		await _q.kit.tick()


## A Truck at a place facing a way presses the lay key: whether it laid, the reason, the note of its view and of the other, the count.
func _press_at(player: int, at: Vector3, facing: Vector3) -> Dictionary:
	await _wait_quiet(player)
	await _k.mines().revive(player)
	await _k.mines().put(player, Quick.TRUCK, at, facing)
	var laid: int = _k.mines().laid.size()
	var refused: int = _k.mines().refused[player].size()
	var record: Dictionary = await _k.mines().lay(player)
	var reason: int = int(_k.mines().refused[player][-1].x) if _k.mines().refused[player].size() > refused else -1
	return {"laid": _k.mines().laid.size() > laid, "reason": reason, "note": _k.mines().note(player), "other": _k.mines().note(1 - player), "left": _k.mines().layers[player].mines_left, "record": record}


## A press whose drop point is the point: the Truck stands the drop offset ahead of it, facing the way given.
func _drop_at(player: int, point: Vector3, facing: Vector3) -> Dictionary:
	var behind: float = _q.units.stats(Quick.TRUCK).mine_drop_offset.z
	return await _press_at(player, point + facing * behind, facing)


## The real key, both Players, all four zones: a drop point at the middle of the zone is refused with the supply reason, nothing laid,
## five Mines kept, the text on that Player's line alone, gone after about 1.5 s.
func _refused_by_key() -> void:
	var problems: PackedStringArray = []
	var count: int = 0
	for player: int in 2:
		for index: int in Kit24.ZONE_PATHS.size():
			var facing: Vector3 = Vector3.RIGHT if _k.centre(index).x < 0.0 else Vector3.LEFT
			var result: Dictionary = await _drop_at(player, _k.centre(index), facing)
			count += 1
			_q.kit.need(problems, not result["laid"] and result["reason"] == MineLayer.Refusal.NEAR_SUPPLY and result["left"] == _q.units.stats(Quick.TRUCK).mine_capacity, "Player %d at zone %d: %s" % [player + 1, index, result])
			_q.kit.need(problems, result["note"] == SUPPLY_TEXT and result["other"] == "hidden", "Player %d at zone %d: the notice lines read '%s' and '%s'" % [player + 1, index, result["note"], result["other"]])
			if index == 0:
				var shown: int = 0
				while _k.mines().note(player) != "hidden" and shown < 200:
					await _q.kit.tick()
					shown += 1
				_q.kit.need(problems, absi(shown - (NOTICE_TICKS - 2)) <= 2, "Player %d's refusal stayed %d more ticks (about %d)" % [player + 1, shown, NOTICE_TICKS - 2])
				measured.append("supply_notice_ticks_p%d=%d" % [player + 1, shown + 2])
	_q.kit.verdict("refused_at_every_zone_by_key", problems, "E pressed with the drop point at the middle of each of the four zones, by both Players (%d presses), laid nothing, kept all %d Mines, showed \"%s\" in that Player's view alone and let it go after about 1.5 s" % [count, _q.units.stats(Quick.TRUCK).mine_capacity, SUPPLY_TEXT])


## A drop point at the ammunition building's face toward the centre (inside the zone, where the open-ground probe also meets the
## building) reads the supply reason; one at its far face, 0.5 m outside the margin, reads "No room for a Mine here".
func _building_faces() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	for side: int in 2:
		var player: int = side
		var layer: MineLayer = _k.mines().layers[player]
		var face: Vector3 = _k.building(side).global_position + _k.inward(side) * (_k.zone(_k.ammo_index(side)).position.x - _k.zone(_k.ammo_index(side)).size.x / 2.0 - STEP)
		var near_point: Vector3 = Vector3(face.x, 0.0, face.z)
		_q.kit.need(problems, not layer.is_open_ground(near_point) and layer.is_near_supply_zone(near_point), "side %d: at %s the open-ground test reads open %s and the supply test refuses %s" % [side, near_point, layer.is_open_ground(near_point), layer.is_near_supply_zone(near_point)])
		var near: Dictionary = await _drop_at(player, near_point, _k.inward(side))
		_q.kit.need(problems, not near["laid"] and near["reason"] == MineLayer.Refusal.NEAR_SUPPLY and near["note"] == SUPPLY_TEXT, "side %d at the building's face: %s" % [side, near])
		var back_x: float = _k.building(side).global_position.x - _k.inward(side).x * (_k.building(side).get_node("CollisionShape3D").shape.size.x / 2.0 + STEP * 10.0)
		var far_point: Vector3 = Vector3(back_x, 0.0, _k.building(side).global_position.z)
		_q.kit.need(problems, not layer.is_open_ground(far_point) and not layer.is_near_supply_zone(far_point), "side %d: at %s the open-ground test reads open %s and the supply test refuses %s" % [side, far_point, layer.is_open_ground(far_point), layer.is_near_supply_zone(far_point)])
		var far: Dictionary = await _drop_at(player, far_point, -_k.inward(side))
		_q.kit.need(problems, not far["laid"] and far["reason"] == MineLayer.Refusal.NO_ROOM and far["note"] == ROOM_TEXT, "side %d at the building's far face: %s" % [side, far])
		summary.append("side %d: near %s, far %s" % [side, near["note"], far["note"]])
	_q.kit.verdict("building_face_reads_the_supply_reason", problems, "a lay with the drop point at the ammunition building's face toward the centre, where the open-ground test also refuses, read \"%s\" and one at its far face, outside the margin, read \"%s\" (%s)" % [SUPPLY_TEXT, ROOM_TEXT, "; ".join(summary)])


## Just outside the grown edge the same press lays (the Mine on the drop point, five less one kept), just inside it is refused.
func _edge_by_key() -> void:
	var problems: PackedStringArray = []
	var zone: SupplyZone = _k.ammo_zone(0)
	var gx: float = _grown(zone, true)
	var gz: float = _grown(zone, false)
	var capacity: int = _q.units.stats(Quick.TRUCK).mine_capacity
	for edge: Array in [["east", Vector2(gx, 0.0), Vector3.LEFT], ["south", Vector2(0.0, gz), Vector3.FORWARD]]:
		var out: Dictionary = await _drop_at(0, _world(zone, edge[1] + edge[1].normalized() * LAY_OUTSIDE), edge[2])
		_q.kit.need(problems, out["laid"] and out["left"] == capacity - 1 and out["note"] == "hidden", "%s edge, %.2f m outside: %s" % [edge[0], LAY_OUTSIDE, out])
		await _k.mines().clear_mines()
		var inside: Dictionary = await _drop_at(0, _world(zone, edge[1] - edge[1].normalized() * LAY_OUTSIDE), edge[2])
		_q.kit.need(problems, not inside["laid"] and inside["reason"] == MineLayer.Refusal.NEAR_SUPPLY and inside["left"] == capacity, "%s edge, %.2f m inside: %s" % [edge[0], LAY_OUTSIDE, inside])
	_q.kit.verdict("edge_by_key", problems, "with the drop point %.2f m outside the grown edge of the west ammunition zone (east and south) the key laid a Mine and %.2f m inside it refused" % [LAY_OUTSIDE, LAY_OUTSIDE])


## The places Story 014 allowed stay allowed (the two canyon spots and the five depot spots of the old Fuel Cans), and the two salt-flat
## spots, on an ammunition zone's edge, are refused.
func _spots() -> void:
	var problems: PackedStringArray = []
	var capacity: int = _q.units.stats(Quick.TRUCK).mine_capacity
	var open: Array[String] = []
	for spot: Vector2 in CANYON_SPOTS + DEPOT_SPOTS:
		var player: int = 0 if spot.x <= 0.0 else 1
		var facing: Vector3 = Vector3.RIGHT if spot.x <= 0.0 else Vector3.LEFT
		var result: Dictionary = await _drop_at(player, Vector3(spot.x, 0.0, spot.y), facing)
		_q.kit.need(problems, result["laid"] and result["left"] == capacity - 1 and result["note"] == "hidden", "the open spot %s: %s" % [spot, result])
		await _k.mines().clear_mines()
		open.append("%s" % [spot])
	var refused: Array[String] = []
	for spot: Vector2 in SALT_SPOTS:
		var player: int = 1 if spot.x > 0.0 else 0
		var facing: Vector3 = Vector3.RIGHT if spot.x < 0.0 else Vector3.LEFT
		var result: Dictionary = await _drop_at(player, Vector3(spot.x, 0.0, spot.y), facing)
		_q.kit.need(problems, not result["laid"] and result["reason"] == MineLayer.Refusal.NEAR_SUPPLY and result["note"] == SUPPLY_TEXT, "the salt-flat spot %s: %s" % [spot, result])
		refused.append("%s" % [spot])
	measured.append("open_spots=%d_refused_spots=%d" % [open.size(), refused.size()])
	_q.kit.verdict("old_spots_open_or_refused", problems, "a Mine laid on each of the two canyon spots and the five depot spots of the old Fuel Cans (%d places) was laid, and one on each of the two salt-flat spots, on an ammunition zone's edge, was refused with the supply reason" % open.size())
