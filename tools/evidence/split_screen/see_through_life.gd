extends RefCounted
## The life of a Unit's silhouette for the see_through scenario (Story 027 AC-4): benched_at_start (before either Player has chosen a type, a Unit has no model and so no copy and no
## fill quad), life (the silhouette of a Unit is drawn exactly while the Unit is in play: after a destruction in the open and after a Swap at the own Base none of it is drawn, no
## copy or fill quad is ever outside a Unit, the explosion and the smoke have none, and a new Unit has exactly two copies for each mesh it draws and one fill quad; the other Player's
## Unit is never disturbed), retype (each of the four types given to a Unit in turn has exactly the copies of its own meshes and one fill quad, and the old model's leave with it)
## and respawn_cost (a second spawn of the same type reuses the Unit's silhouette and its fill material, and the copies keep the settings' own materials: no spawn makes a new one;
## a Unit given the other Team's colour gets a silhouette of that colour), and undressed (a Unit no Player owns, and one with no Team colour, is given no copy and no fill quad).
## Run by see_through.gd. Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The types, in the order retype gives them to a Unit.
const TYPE_ORDER: Array[int] = [Quick.TRUCK, Quick.BUGGY, Quick.MOTORBIKE, Quick.GYROCOPTER]
## Where Player 1's Unit is staged: the open middle of the Map, 30 m west of its middle.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## Ticks a destroyed or benched Unit is watched for, and a new Unit is given to appear.
const GONE_TICKS: int = 30
const LIFE_TICKS: int = 30
## What a drawn colour may differ from the data's by.
const TOLERANCE: float = 0.0001

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit27
var _q: Quick
var _start: Dictionary


func _init(kit: Kit27, at_start: Dictionary) -> void:
	_k = kit
	_q = kit.q()
	_start = at_start


## The checks, in order. A coroutine: await it.
func run() -> void:
	_benched_at_start()
	await _k.walls().turrets_down()
	await _life()
	await _retype()
	await _respawn_cost()
	await _undressed()


## What a Unit draws of its silhouette when it is in play and has `meshes` drawn meshes: two copies of each and one fill quad.
func _nodes_of(meshes: int) -> int:
	return 2 * meshes + 1


## benched_at_start (AC-4): see the class doc. The state was read by see_through.gd before either Player chose.
func _benched_at_start() -> void:
	var problems: PackedStringArray = []
	for player: int in 2:
		var state: Dictionary = _start[player]
		_q.kit.need(problems, not bool(state["alive"]) and not bool(state["visible"]) and not bool(state["model"]) and int(state["copies"]) == 0, "before Player %d chose, its Unit read %s: alive, visible, with a model or with copies" % [player + 1, state])
	_q.kit.verdict("benched_at_start", problems, "before either Player chose a type both Units were out of play, hidden and held no model and no copy (%s and %s)" % [_start[0], _start[1]])


## The number of nodes of the silhouette (copies and fill quads) that are not under a Unit.
func _stray_nodes() -> int:
	var stray: int = 0
	for group: StringName in [UnitSilhouette.COPY_GROUP, UnitSilhouette.FILL_GROUP]:
		for node: Node in _q.harness.get_tree().get_nodes_in_group(group):
			var owner_unit: Node = node
			while owner_unit != null and not owner_unit is Unit:
				owner_unit = owner_unit.get_parent()
			stray += 1 if owner_unit == null else 0
	return stray


## The nodes of the silhouette in the tree, copies and fill quads.
func _silhouette_total() -> int:
	return _q.harness.get_tree().get_nodes_in_group(UnitSilhouette.COPY_GROUP).size() + _q.harness.get_tree().get_nodes_in_group(UnitSilhouette.FILL_GROUP).size()


## life (AC-4): see the class doc.
func _life() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _k.stage(0, Quick.GYROCOPTER, OPEN, Vector3.RIGHT)
	var unit: Unit = _k.unit(0)
	var meshes: int = _k.drawn_meshes(0).size()
	var other_drawn: int = _k.drawn_silhouette(1)
	_q.kit.need(problems, meshes > 0 and _k.drawn_silhouette(0) == _nodes_of(meshes) and other_drawn == _nodes_of(_k.drawn_meshes(1).size()), "a Unit in play draws %d silhouette nodes for its %d meshes (%d expected) and the other Player's %d for its %d" % [_k.drawn_silhouette(0), meshes, _nodes_of(meshes), other_drawn, _k.drawn_meshes(1).size()])
	for kind: String in ["destroyed", "swapped"]:
		if kind == "swapped":
			await _k.swap().enter(0)
			await _k.swap().wait_swappable(0)
		await _q.kit.advance(GONE_TICKS)
		await _q.tokens.destruct(0)
		await _q.kit.advance(GONE_TICKS)
		var held: int = _k.copies_of(0).size() + _k.fills_of(0)
		_q.kit.need(problems, not unit.is_alive and _k.drawn_silhouette(0) == 0 and held == _nodes_of(meshes), "%s: the Unit is %s and %d of its %d silhouette nodes are drawn" % [kind, "alive" if unit.is_alive else "out of play", _k.drawn_silhouette(0), held])
		_q.kit.need(problems, _stray_nodes() == 0 and _k.drawn_silhouette(1) == other_drawn, "%s: %d silhouette nodes are outside a Unit, and the other Player draws %d, not %d" % [kind, _stray_nodes(), _k.drawn_silhouette(1), other_drawn])
		var came: bool = await _q.tokens.spawn(0, Quick.GYROCOPTER)
		await _q.kit.advance(LIFE_TICKS)
		_q.kit.need(problems, came and unit.is_alive and _k.drawn_silhouette(0) == _nodes_of(meshes) and _k.copies_of(0).size() + _k.fills_of(0) == _nodes_of(meshes), "%s: the new Unit has %d silhouette nodes, %d of them drawn, for %d meshes (appeared: %s)" % [kind, _k.copies_of(0).size() + _k.fills_of(0), _k.drawn_silhouette(0), meshes, came])
		notes.append("%s: 0 of %d drawn out of play, %d of %d drawn in the new life" % [kind, held, _k.drawn_silhouette(0), _nodes_of(meshes)])
	var smoke: Node = _k.model_of(0).get_node_or_null("Smoke")
	_q.kit.need(problems, smoke == null or smoke.find_children("*", "Node", true, false).all(func(node: Node) -> bool: return not node.is_in_group(UnitSilhouette.COPY_GROUP) and not node.is_in_group(UnitSilhouette.FILL_GROUP)), "the smoke of the new Unit holds a silhouette node")
	for blast: Node in _k.blasts():
		_q.kit.need(problems, not blast.is_in_group(UnitSilhouette.COPY_GROUP) and not blast.is_in_group(UnitSilhouette.FILL_GROUP) and blast.find_children("*", "Node", true, false).all(func(node: Node) -> bool: return not node.is_in_group(UnitSilhouette.COPY_GROUP) and not node.is_in_group(UnitSilhouette.FILL_GROUP)), "an explosion holds a silhouette node")
	measured.append("silhouette_nodes_per_life=%d" % _nodes_of(meshes))
	_q.kit.verdict("life", problems, "a Gyrocopter in play draws %d silhouette nodes, two copies of each mesh and one fill quad; out of play (%s) none is drawn, none is outside a Unit and no explosion or smoke holds one; the new Unit has exactly its %d nodes drawn; the other Player's Unit draws its own %d throughout" % [_nodes_of(meshes), "; ".join(notes), _nodes_of(meshes), other_drawn])


## retype (AC-4): see the class doc.
func _retype() -> void:
	var problems: PackedStringArray = []
	var lines: PackedStringArray = []
	for type_index: int in TYPE_ORDER:
		await _k.stage(0, type_index, OPEN, Vector3.RIGHT)
		var stats: UnitStats = _q.units.stats(type_index)
		var expected: int = _k.expected_meshes(stats)
		var copies: Array[MeshInstance3D] = _k.copies_of(0)
		var models: int = _k.unit(0).find_children("Model*", "Node3D", false, false).size()
		_q.kit.need(problems, _k.unit(0).type_id == stats.type_id and copies.size() == 2 * expected and _k.drawn_meshes(0).size() == expected and _k.drawn_silhouette(0) == _nodes_of(expected), "%s: %d copies, %d drawn meshes and %d silhouette nodes drawn, expected %d meshes, %d nodes" % [stats.type_id, copies.size(), _k.drawn_meshes(0).size(), _k.drawn_silhouette(0), expected, _nodes_of(expected)])
		var others: int = _k.copies_of(1).size() + _k.fills_of(1)
		_q.kit.need(problems, models == 1 and _k.fills_of(0) == 1 and _stray_nodes() == 0 and _silhouette_total() == copies.size() + _k.fills_of(0) + others, "%s: %d models under the Unit and %d silhouette nodes in the tree, %d expected" % [stats.type_id, models, _silhouette_total(), copies.size() + _k.fills_of(0) + others])
		lines.append("%s %d" % [stats.type_id, copies.size() + _k.fills_of(0)])
	measured.append("retype_nodes=%s" % ",".join(lines))
	_q.kit.verdict("retype", problems, "given each type in turn (%s silhouette nodes) a Unit has exactly two copies for each mesh its model draws, read from the mesh file and the rotor settings, one fill quad, one model under it, and no node of an older model or of the other Player's Unit left in the tree" % ", ".join(lines))


## What a Unit's silhouette is made of now: the silhouette object, the fill material and the materials of the copies.
func _made_of(player: int) -> Dictionary:
	var copy_materials: Array[Material] = []
	for copy: MeshInstance3D in _k.copies_of(player):
		copy_materials.append(copy.material_override)
	var fill: MeshInstance3D = _k.fill_of(player)
	return {"silhouette": _k.unit(player).get("_silhouette"), "fill_material": fill.material_override if fill != null else null, "copy_materials": copy_materials}


## respawn_cost (AC-6): see the class doc.
func _respawn_cost() -> void:
	var problems: PackedStringArray = []
	var settings: SilhouetteSettings = _k.settings()
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	var first: Dictionary = _made_of(0)
	var first_model: Node = _k.model_of(0)
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	var second: Dictionary = _made_of(0)
	_q.kit.need(problems, _k.model_of(0) != first_model and first["silhouette"] != null, "the second spawn kept the first model or the Unit has no silhouette")
	_q.kit.need(problems, first["silhouette"] == second["silhouette"] and first["fill_material"] != null and first["fill_material"] == second["fill_material"], "the second spawn made a new silhouette or a new fill material")
	var copies_first: Array = first["copy_materials"]
	var copies_second: Array = second["copy_materials"]
	var shared: bool = not copies_first.is_empty() and copies_first.size() == copies_second.size()
	for index: int in copies_second.size():
		shared = shared and copies_second[index] == (settings.mask_material if index % 2 == 0 else settings.sight_material)
	_q.kit.need(problems, shared, "the copies of the second spawn are not drawn with the settings' own mask and sight materials (%d against %d copies)" % [copies_second.size(), copies_first.size()])
	measured.append("reused_copies=%d" % copies_first.size())
	var unit: Unit = _k.unit(0)
	var own_colour: Material = unit.team_material
	unit.team_material = _k.unit(1).team_material
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	var changed: Dictionary = _made_of(0)
	var other: Color = _k.team_colour(1)
	var fill_colour: Color = (changed["fill_material"] as StandardMaterial3D).albedo_color if changed["fill_material"] != null else Color.BLACK
	_q.kit.need(problems, changed["silhouette"] != second["silhouette"] and changed["fill_material"] != second["fill_material"] and absf(fill_colour.r - other.r) <= TOLERANCE and absf(fill_colour.b - other.b) <= TOLERANCE and absf(fill_colour.a - settings.strength) <= TOLERANCE, "a Unit given the other Team's colour kept its silhouette (%s) or drew its fill in %s, not %s at strength %.2f" % [changed["silhouette"] == second["silhouette"], fill_colour, other, settings.strength])
	unit.team_material = own_colour
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	_q.kit.verdict("respawn_cost", problems, "a second spawn of the same type made a new model but not a new silhouette or a new fill material, and its %d copies are drawn with the settings' own mask and sight materials, the same two objects as every copy of every Unit; a Unit given the other Team's colour got a silhouette of its own whose fill is in that colour at the strength" % copies_first.size())


## undressed (AC-4): a Unit no Player owns (player_index below 0: the driving toy's, a stand-in) and a Unit with no Team material are given no copy and no fill quad, though both carry
## the settings.
func _undressed() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for case: String in ["no Player", "no Team material"]:
		var stand_in: Unit = load("res://src/gameplay/units/motorbike.tscn").instantiate() as Unit
		stand_in.stats = _q.units.stats(Quick.MOTORBIKE)
		stand_in.silhouette = _k.settings()
		stand_in.team_material = _k.unit(0).team_material if case == "no Player" else null
		stand_in.player_index = -1 if case == "no Player" else 0
		_q.harness.add_child(stand_in)
		stand_in.spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)), _q.units.stats(Quick.MOTORBIKE))
		var model: Node = stand_in.get_node_or_null("Model")
		var meshes: int = model.find_children("*", "MeshInstance3D", true, false).size() if model != null else 0
		var nodes: int = 0
		for node: Node in stand_in.find_children("*", "MeshInstance3D", true, false):
			nodes += 1 if node.is_in_group(UnitSilhouette.COPY_GROUP) or node.is_in_group(UnitSilhouette.FILL_GROUP) else 0
		_q.kit.need(problems, model != null and meshes > 0 and nodes == 0, "a Unit with %s has %d silhouette nodes among %d meshes (and a model: %s)" % [case, nodes, meshes, model != null])
		seen.append("%s: %d meshes, %d silhouette nodes" % [case, meshes, nodes])
		_q.harness.remove_child(stand_in)
		stand_in.free()
	_q.kit.verdict("undressed", problems, "a Unit that carries the settings but has no Player or no Team material is drawn as before, with no copy and no fill quad (%s)" % "; ".join(seen))
