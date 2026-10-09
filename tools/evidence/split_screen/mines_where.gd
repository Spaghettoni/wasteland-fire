extends RefCounted
## Where a Mine may be laid in the Story 014 scenario mines (AC-5): the no-mine areas (both Bases' yards and
## Garages, from Gate tower to Gate tower and about 10 m out in front of each Gate, at the other Player's
## Base as at the own), their edges from both sides; the open-ground test (a wall, a corner tower, the cover,
## a depot Fuel tank, a standing Turret or Flag Wall, a cliff, a Truck backed flush against the rock, water);
## the refused press (nothing laid, the count kept, the reason on that Player's notice line alone for about
## 1.5 s); and the places a Truck does lay (open ground, outside the side and back walls, a ford, a Fuel Can's
## spot). Real keys; the two tests are also called directly, as a tool may. Tooling only. Implements:
## production/epics/wasteland-fire/story-014-truck-mines.md AC-5.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## The area's edges in a Base's own frame, metres: the zone's half width 14.7 and its Gate-side face at z -13.9
## and back face at z 13.6, grown by the trigger's 0.8 m, and the approach's 11.0 m past the Gate-side face.
const EDGE_X: float = 15.5
const EDGE_GATE: float = -25.7
const EDGE_BACK: float = 14.4
## How far either side of an edge the checks stand, metres.
const STEP: float = 0.05
## The Gate wall's outer face in a Base's frame and the trigger's radius, for the 9.9 m.
const GATE_FACE: float = -15.0
const RADIUS: float = 0.8
## Ticks a refusal stays on the notice line (1.5 s at 60 ticks a second).
const NOTICE_TICKS: int = 90

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	await _areas()
	await _refused_by_key()
	await _open_ground()
	await _rock_and_probe()
	await _lays_everywhere_else()


## The edges of both Bases' areas from both sides, in the world, and the story's numbers for Map 01.
func _areas() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.layers[0]
	var edges: PackedStringArray = []
	for base_index: int in 2:
		for edge: Array in [["x+", Vector3(EDGE_X, 0.0, 0.0)], ["x-", Vector3(-EDGE_X, 0.0, 0.0)], ["gate", Vector3(0.0, 0.0, EDGE_GATE)], ["back", Vector3(0.0, 0.0, EDGE_BACK)]]:
			var at: Vector3 = edge[1]
			var outward: Vector3 = at.normalized() * (1.0 if edge[0] != "back" else 1.0)
			var inside: Vector3 = _k.w.point(base_index, at - outward * STEP)
			var outside: Vector3 = _k.w.point(base_index, at + outward * STEP)
			_q.kit.need(problems, layer.is_in_no_mine_area(inside), "Base %d %s: %.2f m inside the edge the area does not refuse" % [base_index, edge[0], STEP])
			_q.kit.need(problems, not layer.is_in_no_mine_area(outside), "Base %d %s: %.2f m outside the edge the area refuses" % [base_index, edge[0], STEP])
			edges.append("%d%s" % [base_index, edge[0]])
	for base_index: int in 2:
		var sign: float = -1.0 if base_index == 0 else 1.0
		var gate_edge: Vector3 = _k.w.point(base_index, Vector3(0.0, 0.0, EDGE_GATE))
		var back_edge: Vector3 = _k.w.point(base_index, Vector3(0.0, 0.0, EDGE_BACK))
		var side_edge: Vector3 = _k.w.point(base_index, Vector3(EDGE_X, 0.0, 0.0))
		_q.kit.need(problems, absf(gate_edge.x - sign * 94.3) < 0.01 and absf(back_edge.x - sign * 134.4) < 0.01 and absf(absf(side_edge.z) - 15.5) < 0.01, "Base %d's edges in the world: gate x %.2f, back x %.2f, side z %.2f" % [base_index, gate_edge.x, back_edge.x, side_edge.z])
	_q.kit.need(problems, absf((EDGE_GATE * -1.0 + GATE_FACE) - RADIUS - 9.9) < 0.001, "the nearest part of a Mine at the gate edge is not 9.9 m from the Gate wall's outer face")
	measured.append("area_edges=16")
	_q.kit.verdict("no_mine_areas_edges", problems, "at both Bases, 0.05 m inside each of the four edges (Base-local x +-15.5, z -25.7 and 14.4) the area test refuses a drop point and 0.05 m outside it does not (16 readings each way); in the world the Gate-side edges stand at x -94.3 and 94.3, the back edges at x -134.4 and 134.4, the sides at z +-15.5, and no part of a Mine at the Gate-side edge lies less than 9.9 m in front of the Gate wall's outer face")


## Waits until the Player's notice line is hidden (a refusal stays about 1.5 s), at most 200 ticks.
func _wait_quiet(player: int) -> void:
	for _tick: int in 200:
		if _k.note(player) == "hidden":
			return
		await _q.kit.tick()


## A Truck at a world place facing a way presses the lay key: the Player's note and whether it laid.
func _press_at(player: int, at: Vector3, facing: Vector3) -> Dictionary:
	await _wait_quiet(player)
	await _k.revive(player)
	await _k.put(player, Quick.TRUCK, at, facing)
	var laid: int = _k.laid.size()
	var refused: int = _k.refused[player].size()
	var record: Dictionary = await _k.lay(player)
	var reason: int = int(_k.refused[player][-1].x) if _k.refused[player].size() > refused else -1
	return {"laid": _k.laid.size() > laid, "reason": reason, "note": _k.note(player), "other": _k.note(1 - player), "left": _k.layers[player].mines_left, "record": record}


## The real key: refused in the yard, at the Gate, at the other Player's Gate and at its edge's two sides.
func _refused_by_key() -> void:
	var problems: PackedStringArray = []
	var yard: Dictionary = await _press_at(0, _k.w.point(0, Vector3(0.0, 0.0, 3.0)), -_k.w.way(0, Vector3.BACK))
	_q.kit.need(problems, not yard["laid"] and yard["reason"] == MineLayer.Refusal.NEAR_BASE and yard["left"] == 5, "in its own yard: %s" % [yard])
	_q.kit.need(problems, yard["note"] == "No Mines in or near a Base" and yard["other"] == "hidden", "the notice lines read '%s' and '%s'" % [yard["note"], yard["other"]])
	var shown: int = 0
	while _k.note(0) != "hidden" and shown < 200:
		await _q.kit.tick()
		shown += 1
	_q.kit.need(problems, absi(shown - (NOTICE_TICKS - 2)) <= 2, "the refusal stayed %d more ticks (about %d)" % [shown, NOTICE_TICKS - 2])
	measured.append("notice_ticks=%d" % (shown + 2))
	var gate_in: Dictionary = await _press_at(0, Vector3(-98.0, 0.0, 0.0), Vector3.LEFT)
	_q.kit.need(problems, not gate_in["laid"] and gate_in["reason"] == MineLayer.Refusal.NEAR_BASE, "drop at x -94.6: %s" % [gate_in])
	var gate_out: Dictionary = await _press_at(0, Vector3(-97.55, 0.0, 0.0), Vector3.LEFT)
	_q.kit.need(problems, gate_out["laid"] and gate_out["left"] == 4 and gate_out["note"] == "hidden", "drop at x -94.15: %s" % [gate_out])
	var theirs_in: Dictionary = await _press_at(0, Vector3(98.0, 0.0, 0.0), Vector3.RIGHT)
	_q.kit.need(problems, not theirs_in["laid"] and theirs_in["reason"] == MineLayer.Refusal.NEAR_BASE, "at the other Player's Gate, drop at x 94.6: %s" % [theirs_in])
	var theirs_out: Dictionary = await _press_at(0, Vector3(97.55, 0.0, 0.0), Vector3.RIGHT)
	_q.kit.need(problems, theirs_out["laid"] and theirs_out["left"] == 4, "at the other Player's Gate, drop at x 94.15: %s" % [theirs_out])
	var turret_at: Vector3 = _k.w.point(0, Vector3(-10.0, 0.0, -19.0))
	var on_turret: Dictionary = await _press_at(0, turret_at + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	_q.kit.need(problems, not on_turret["laid"] and on_turret["reason"] == MineLayer.Refusal.NEAR_BASE and not _k.layers[0].is_open_ground(turret_at), "with the drop point on a standing Turret both tests refuse and the Base's reason shows: %s" % [on_turret])
	var back: Dictionary = await _press_at(1, Vector3(-98.0, 0.0, 0.0), Vector3.RIGHT)
	_q.kit.need(problems, not back["laid"] and back["reason"] == MineLayer.Refusal.NEAR_BASE and back["note"] == "No Mines in or near a Base", "Player 2 in front of Base A: %s" % [back])
	_q.kit.verdict("refused_in_and_near_a_base", problems, "E pressed in its own yard, with the drop point 0.3 m inside the Gate-side edge of either Base (the other Player's included) laid nothing, kept 5 Mines and said \"No Mines in or near a Base\" in that Player's view alone for about 1.5 s; 0.15 m outside the edge the same press laid; with the drop point on a standing Turret, which open ground refuses as well, the Base's reason showed; Comma behaved the same for Player 2")


## The open-ground test called at a place of each kind (the Truck's drop point cannot always reach them).
func _open_ground() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.layers[0]
	var shut: Dictionary = {
		"container": Vector3(-58.0, 0.0, 0.0), "wreck": Vector3(-53.0, 0.0, -8.0), "scrap_wall": Vector3(-12.0, 0.0, 12.0),
		"depot_tank": Vector3(-6.8115, 0.0, -6.6222), "water": Vector3(-40.0, 0.0, 34.0), "cliff_face": Vector3(-55.0, 0.0, -19.6),
		"base_wall": _k.w.point(0, Vector3(0.0, 0.0, 14.35)), "corner_tower": _k.w.point(0, Vector3(16.0, 0.0, -15.0)),
		"standing_turret": _k.w.point(0, Vector3(-10.0, 0.0, -19.0)), "standing_flag_wall": _k.w.point(0, Vector3(0.0, 0.0, -8.8))}
	var names: PackedStringArray = []
	for name: String in shut:
		_q.kit.need(problems, not layer.is_open_ground(shut[name]), "%s at %s reads open ground" % [name, shut[name]])
		names.append(name)
	var open: Dictionary = {"flat": Vector3(-30.0, 0.0, -2.0), "ford": Vector3(-40.0, 0.0, 0.0), "fuel_can_spot": Vector3(-62.0, 0.0, 14.0)}
	for name: String in open:
		_q.kit.need(problems, layer.is_open_ground(open[name]), "%s at %s reads not open" % [name, open[name]])
	for base_index: int in 2:
		for piece: Structure in _k.w.bases[base_index].structures:
			_q.kit.need(problems, layer.is_in_no_mine_area(piece.global_position), "%s of Base %d does not stand in a no-mine area" % [piece.name, base_index])
	var pieces: Array[Structure] = []
	for base_index: int in 2:
		pieces.append_array(_k.w.bases[base_index].structures)
	for piece: Structure in pieces:
		_q.kit.need(problems, not layer.is_open_ground(piece.global_position), "%s of %s reads open ground while it stands" % [piece.name, piece.get_parent().get_parent().name])
	for piece: Structure in pieces:
		piece.destroy()
	await _q.kit.advance(Kit14.SETTLE)
	for piece: Structure in pieces:
		_q.kit.need(problems, layer.is_open_ground(piece.global_position), "the rubble of %s still reads as a body" % piece.name)
	for piece: Structure in pieces:
		piece.restore()
	await _q.kit.advance(Kit14.SETTLE)
	for piece: Structure in pieces:
		_q.kit.need(problems, not layer.is_open_ground(piece.global_position), "%s reads open ground after it was restored" % piece.name)
	_q.kit.verdict("open_ground_test", problems, "the open-ground test refuses %s, and reads open ground on the flat, in a ford and on a Fuel Can's spot (areas never count); each of the %d Turrets and Flag Walls of both Bases refuses while it stands and, once destroyed, its rubble stops answering the query (and refuses again when restored); every one of them stands in a no-mine area, so there the Base's reason shows first" % [", ".join(names), pieces.size()])


## A footprint wholly inside the rock, which a probe that stops at the cliffs' own top (2 m) would lay buried, is
## refused by the 20 m probe; a Truck reversed flush against the rock's face is refused by its key.
func _rock_and_probe() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.layers[0]
	var shallow: MineSettings = layer.settings.duplicate() as MineSettings
	shallow.probe_top = 2.0
	var original: MineSettings = layer.settings
	var inside: PackedStringArray = []
	for z: float in [-31.0, -29.0, -26.0, -22.0, -21.0, -20.4]:
		var at: Vector3 = Vector3(-55.0, 0.0, z)
		layer.settings = shallow
		var shallow_open: bool = layer.is_open_ground(at)
		layer.settings = original
		_q.kit.need(problems, shallow_open and not layer.is_open_ground(at), "z %.1f: the 2 m probe reads open %s and the 20 m probe open %s" % [z, shallow_open, layer.is_open_ground(at)])
		inside.append("%.1f" % z)
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, Vector3(-55.0, 0.0, -12.0), Vector3.BACK)
	_q.harness.drive(0, -1, 0)
	await _q.kit.advance(150)
	_q.harness.drive(0, 0, 0)
	var truck: Unit = _q.units.units[0]
	var drop: Vector3 = truck.global_transform * Vector3(0.0, 0.0, 3.4)
	var refused: int = _k.refused[0].size()
	var laid: int = _k.laid.size()
	await _k.lay(0)
	_q.kit.need(problems, drop.z < -20.0 and absf(truck.global_position.z - (-20.0 + 2.2)) < 0.15, "the Truck stands at z %.2f, its drop point at z %.2f (the rock's face is at z -20)" % [truck.global_position.z, drop.z])
	_q.kit.need(problems, _k.laid.size() == laid and _k.refused[0].size() == refused + 1 and _k.refused[0][-1].x == MineLayer.Refusal.NO_ROOM, "the press laid %d and was refused %s" % [_k.laid.size() - laid, _k.refused[0].slice(refused)])
	_q.kit.need(problems, _k.note(0) == "No room for a Mine here" and _k.layers[0].mines_left == 5, "the notice reads '%s', %d left" % [_k.note(0), _k.layers[0].mines_left])
	_q.kit.verdict("rock_is_refused_and_the_probe_must_reach_it", problems, "at z %s (x -55) a footprint wholly inside RockCanyonSouth reads open to a probe that stops at 2 m (the cliffs' own top: a Mine would lie buried) and not open to the 20 m probe; a Truck reversed flush against the rock (drop point %.2f m inside it) pressing E laid nothing and read \"No room for a Mine here\"" % [", ".join(inside), -20.0 - drop.z])


## The places a Truck does lay: outside the side wall and the back wall of a Base, in a ford, on a Fuel Can's spot.
func _lays_everywhere_else() -> void:
	var problems: PackedStringArray = []
	var cases: Dictionary = {
		"side_wall_outside": [Vector3(-120.0, 0.0, -24.0), Vector3.BACK],
		"back_wall_outside": [Vector3(-141.0, 0.0, 0.0), Vector3.LEFT],
		"ford": [Vector3(-40.0, 0.0, 0.0), Vector3.LEFT],
		"fuel_can_spot": [Vector3(-62.0, 0.0, 10.6), Vector3.FORWARD]}
	for name: String in cases:
		var result: Dictionary = await _press_at(0, cases[name][0], cases[name][1])
		_q.kit.need(problems, result["laid"] and result["left"] == 4 and result["note"] == "hidden", "%s: %s" % [name, result])
		if result["laid"]:
			var drop: Vector3 = _q.units.units[0].global_transform * Vector3(0.0, 0.0, 3.4)
			_q.kit.need(problems, _k.place_of(result["record"]).distance_to(drop) <= 0.01, "%s: the Mine lies %.3f m from the drop point" % [name, _k.place_of(result["record"]).distance_to(drop)])
	_q.kit.verdict("lays_on_the_rest_of_the_map", problems, "a Truck laid with E outside Base A's side wall and outside its back wall, in a ford and on a Fuel Can's spot, each at its drop point, 5 -> 4, with no notice")
