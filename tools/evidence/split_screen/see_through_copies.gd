extends RefCounted
## What a Unit's model is dressed with, for the see_through scenario (Story 027 AC-4): copies (every mesh a Unit of every type draws has exactly two copies beside it, the
## mask copy and the sight copy, sharing its Mesh and its transform, on its Player's render layer only, drawn with the data's own mask and sight materials, casting no shadow and
## holding no collider; the model has exactly one fill quad, on the same layer, in the Team colour at the strength of the data, sized and never culled as the data says),
## passes (the Unit's own meshes keep the materials they were painted with and use no stencil, the shared Team material is untouched, none of the Map's meshes uses the
## stencil, and the three passes are drawn in the order mask, sight, fill), turning_parts (the Gyrocopter's rotor and propeller copies hang under their pivots and turn with
## them, and the smear has none) and small_things (a badly damaged Unit's smoke gets no copy). Run by see_through.gd. Tooling only. Every number comes from the game's data
## and files; the scenario types only its test inputs.

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The types, by index into the data: the Motorbike, the Buggy, the Truck and the Gyrocopter.
const TYPES: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK, Quick.GYROCOPTER]
## Where each Player's Unit is staged: the open middle of the Map, 30 m either side of its middle.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## Ticks a turning part is given to turn, and a hurt Unit to smoke.
const TURN_TICKS: int = 7
const SMOKE_TICKS: int = 20
## The share of its hit points a smoking Unit has left (the badly damaged state is at 20%).
const HURT_SHARE: float = 0.15
## What a drawn colour or a float may differ from the data's by.
const TOLERANCE: float = 0.0001

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit27
var _q: Quick
var _copy_problems: PackedStringArray = []
var _pass_problems: PackedStringArray = []
var _lines: PackedStringArray = []
var _copy_total: int = 0
var _mesh_total: int = 0
var _units_read: int = 0


func _init(kit: Kit27, _at_start: Dictionary) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().turrets_down()
	for type_index: int in TYPES:
		for player: int in 2:
			await _k.stage(player, type_index, _spot(player), Vector3.RIGHT if player == 0 else Vector3.LEFT)
			_read_unit(player)
	_finish_copies()
	_passes()
	await _turning_parts()
	await _small_things()


## Where a Player's Unit is staged.
func _spot(player: int) -> Vector3:
	return OPEN if player == 0 else Vector3(-OPEN.x, OPEN.y, OPEN.z)


## Judges the Unit a Player has now (the model of the type just staged: the next staging frees it): its copies and its fill quad, and what its meshes are drawn with.
func _read_unit(player: int) -> void:
	var settings: SilhouetteSettings = _k.settings()
	var unit: Unit = _k.unit(player)
	var label: String = "Player %d's %s" % [player + 1, unit.type_id]
	var meshes: Array[MeshInstance3D] = _k.drawn_meshes(player)
	var copies: Array[MeshInstance3D] = _k.copies_of(player)
	var expected: int = _k.expected_meshes(unit.stats)
	_units_read += 1
	_q.kit.need(_copy_problems, meshes.size() == expected and meshes.size() > 0, "%s draws %d meshes, the mesh file and settings say %d" % [label, meshes.size(), expected])
	_q.kit.need(_copy_problems, copies.size() == 2 * meshes.size(), "%s has %d copies for %d drawn meshes (two each)" % [label, copies.size(), meshes.size()])
	_copy_total += copies.size()
	_mesh_total += meshes.size()
	for mesh: MeshInstance3D in meshes:
		var beside: Array[MeshInstance3D] = _k.copies_beside(mesh)
		_q.kit.need(_copy_problems, beside.size() == 2 and beside[0].material_override == settings.mask_material and beside[1].material_override == settings.sight_material, "%s: %s has %d copies beside it, the first with the mask material and the second with the sight material expected" % [label, mesh.name, beside.size()])
		for copy: MeshInstance3D in beside:
			_q.kit.need(_copy_problems, copy.mesh == mesh.mesh and copy.get_parent() == mesh.get_parent() and copy.transform == mesh.transform, "%s: the copy %s of %s does not share its Mesh, parent and transform" % [label, copy.name, mesh.name])
			_q.kit.need(_copy_problems, copy.layers == settings.layer_of(player), "%s: the copy %s is on layers %d, not %d" % [label, copy.name, copy.layers, settings.layer_of(player)])
			_q.kit.need(_copy_problems, copy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and copy.ignore_occlusion_culling, "%s: the copy %s casts a shadow or can be culled by occlusion" % [label, copy.name])
			_q.kit.need(_copy_problems, copy.get_child_count() == 0 and copy.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s: the copy %s holds a child or a collider" % [label, copy.name])
	var team: Color = _k.team_colour(player)
	var fills: int = _k.fills_of(player)
	var fill: MeshInstance3D = _k.fill_of(player)
	_q.kit.need(_copy_problems, fills == 1 and fill != null, "%s has %d fill quads, not one" % [label, fills])
	if fill != null:
		var quad: QuadMesh = fill.mesh as QuadMesh
		var look: StandardMaterial3D = fill.material_override as StandardMaterial3D
		_q.kit.need(_copy_problems, fill.get_parent() == _k.model_of(player) and fill.layers == settings.layer_of(player) and fill.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and fill.ignore_occlusion_culling, "%s: the fill quad is under %s, on layers %d, shadow %d, ignoring occlusion culling %s" % [label, fill.get_parent(), fill.layers, fill.cast_shadow, fill.ignore_occlusion_culling])
		_q.kit.need(_copy_problems, quad != null and is_equal_approx(quad.size.x, settings.fill_extent) and is_equal_approx(quad.size.y, settings.fill_extent) and is_equal_approx(fill.extra_cull_margin, settings.fill_extent), "%s: the fill quad is %s with a cull margin of %s, the data says %s" % [label, quad.size if quad != null else "missing", fill.extra_cull_margin, settings.fill_extent])
		_q.kit.need(_copy_problems, look != null and look != settings.fill_material and absf(look.albedo_color.r - team.r) <= TOLERANCE and absf(look.albedo_color.g - team.g) <= TOLERANCE and absf(look.albedo_color.b - team.b) <= TOLERANCE and absf(look.albedo_color.a - settings.strength) <= TOLERANCE, "%s: the fill material's colour is %s, not the Team colour %s at strength %.2f, or it is the template itself" % [label, look.albedo_color if look != null else "missing", team, settings.strength])
		_q.kit.need(_copy_problems, look != null and look.stencil_mode == settings.fill_material.stencil_mode and look.stencil_flags == settings.fill_material.stencil_flags and look.stencil_compare == settings.fill_material.stencil_compare and look.stencil_reference == settings.fill_material.stencil_reference and look.render_priority == settings.fill_material.render_priority and look.billboard_mode == settings.fill_material.billboard_mode and look.no_depth_test == settings.fill_material.no_depth_test and look.shading_mode == settings.fill_material.shading_mode and look.transparency == settings.fill_material.transparency, "%s: the fill material is not the template's with the Team colour" % label)
	# What the Unit's own meshes are drawn with: as before the story, and no stencil.
	var shared_team: BaseMaterial3D = unit.team_material as BaseMaterial3D
	for mesh: MeshInstance3D in meshes:
		var drawn: BaseMaterial3D = mesh.material_override as BaseMaterial3D
		_q.kit.need(_pass_problems, drawn != null and drawn.stencil_mode == BaseMaterial3D.STENCIL_MODE_DISABLED and drawn.stencil_flags == 0, "%s: %s is drawn with %s, which uses the stencil or is none" % [label, mesh.name, drawn])
		if mesh.is_in_group(Unit.TEAM_COLOUR_GROUP):
			_q.kit.need(_pass_problems, mesh.material_override == shared_team, "%s: %s is not drawn with the Unit's own Team material" % [label, mesh.name])
	_lines.append("%s %d/%d" % [unit.type_id, copies.size(), meshes.size()])


## copies (AC-4): see the class doc.
func _finish_copies() -> void:
	var settings: SilhouetteSettings = _k.settings()
	measured.append("copies=%d" % _copy_total)
	_q.kit.verdict("copies", _copy_problems, "each of the %d Units staged (every type, both Players) has exactly two copies beside each mesh it draws (%s as copies/meshes, %d copies for %d meshes in all, the mesh counts read from the mesh files and rotor settings): the mask copy and the sight copy, sharing the Mesh, the parent and the transform, on its Player's render layer %d or %d only, drawn with the data's mask and sight materials, with no shadow, never culled by occlusion, no child and no collider; and exactly one fill quad under the model, on the same layer, %.0f m a side and never culled, in its Team colour at the strength %.2f" % [_units_read, ", ".join(_lines.slice(0, 4)), _copy_total, _mesh_total, settings.player_1_layer, settings.player_2_layer, settings.fill_extent, settings.strength])


## passes (AC-4): see the class doc.
func _passes() -> void:
	var settings: SilhouetteSettings = _k.settings()
	var map_pieces: int = 0
	var map_stencil: int = 0
	var team_pieces: int = 0
	for node: Node in _q.harness.split.field.find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = node as MeshInstance3D
		map_pieces += 1
		for material: Material in [piece.material_override, piece.mesh.surface_get_material(0) if piece.mesh != null and piece.mesh.get_surface_count() > 0 else null]:
			var drawn: BaseMaterial3D = material as BaseMaterial3D
			if drawn != null and drawn.stencil_mode != BaseMaterial3D.STENCIL_MODE_DISABLED:
				map_stencil += 1
			if material != null and (material == _k.unit(0).team_material or material == _k.unit(1).team_material):
				team_pieces += 1
	_q.kit.need(_pass_problems, map_stencil == 0, "%d of the Map's %d meshes are drawn with a material that uses the stencil" % [map_stencil, map_pieces])
	_q.kit.need(_pass_problems, team_pieces > 0, "no piece of the Map is drawn with a Team material, so the check of the shared material proves nothing")
	for player: int in 2:
		var team: BaseMaterial3D = _k.unit(player).team_material as BaseMaterial3D
		_q.kit.need(_pass_problems, team.stencil_mode == BaseMaterial3D.STENCIL_MODE_DISABLED and team.stencil_flags == 0, "Player %d's shared Team material uses the stencil (mode %d, flags %d)" % [player + 1, team.stencil_mode, team.stencil_flags])
	var order: Array[int] = [settings.mask_material.render_priority, settings.sight_material.render_priority, settings.fill_material.render_priority]
	_q.kit.need(_pass_problems, order[0] < order[1] and order[1] < order[2], "the passes' render priorities %s do not rise from the mask to the fill" % [order])
	_q.kit.need(_pass_problems, settings.mask_material.no_depth_test and not settings.sight_material.no_depth_test and settings.mask_material.stencil_reference != settings.sight_material.stencil_reference and settings.fill_material.stencil_reference == settings.mask_material.stencil_reference, "the mask pass ignores depth %s, the sight pass ignores it %s, the values are %d and %d, the fill reads %d" % [settings.mask_material.no_depth_test, settings.sight_material.no_depth_test, settings.mask_material.stencil_reference, settings.sight_material.stencil_reference, settings.fill_material.stencil_reference])
	measured.append("passes=%d/%d/%d" % [order[0], order[1], order[2]])
	_q.kit.verdict("passes", _pass_problems, "the %d drawn meshes of the Units staged are drawn with the materials they were painted with and none uses the stencil (the Team-coloured ones with the Unit's own shared Team material, which stays untouched: stencil mode disabled), none of the Map's %d meshes (%d of them drawn with a Team material) uses the stencil, so a Base piece of the same Team marks nothing; the three passes are drawn in the order mask (priority %d, no depth test, writes %d), sight (%d, depth tested, writes %d) and fill (%d, reads %d)" % [_mesh_total, map_pieces, team_pieces, order[0], settings.mask_material.stencil_reference, order[1], settings.sight_material.stencil_reference, order[2], settings.fill_material.stencil_reference])


## turning_parts (AC-4): the Gyrocopter's rotor and propeller copies hang under their pivots, turn with them and leave the smear alone.
func _turning_parts() -> void:
	var problems: PackedStringArray = []
	var pivots_seen: int = 0
	var turned: int = 0
	var copies_seen: int = 0
	for player: int in 2:
		await _k.stage(player, Quick.GYROCOPTER, _spot(player), Vector3.RIGHT if player == 0 else Vector3.LEFT)
		var pivots: Array[RotorPivot] = _k.k.pivots_of(player)
		_q.kit.need(problems, pivots.size() == 2, "Player %d's Gyrocopter has %d pivots, not the rotor's and the propeller's" % [player + 1, pivots.size()])
		for pivot: RotorPivot in pivots:
			pivots_seen += 1
			var smear: MeshInstance3D = pivot.smear()
			var own: Array[MeshInstance3D] = []
			for child: Node in pivot.get_children():
				if child is MeshInstance3D and child.is_in_group(UnitSilhouette.COPY_GROUP):
					own.append(child as MeshInstance3D)
			copies_seen += own.size()
			_q.kit.need(problems, own.size() == 4, "Player %d's %s holds %d copies, not the four of its two meshes" % [player + 1, pivot.name, own.size()])
			_q.kit.need(problems, smear != null and not smear.is_in_group(UnitSilhouette.COPY_GROUP) and own.all(func(copy: MeshInstance3D) -> bool: return copy.mesh != smear.mesh), "Player %d's %s: the smear is copied or missing" % [player + 1, pivot.name])
			var before: Array[Basis] = []
			for copy: MeshInstance3D in own:
				before.append(copy.global_transform.basis)
			await _q.kit.advance(TURN_TICKS)
			for index: int in own.size():
				var mesh: MeshInstance3D = null
				for child: Node in pivot.get_children():
					if child is MeshInstance3D and not child.is_in_group(UnitSilhouette.COPY_GROUP) and child != smear and (child as MeshInstance3D).mesh == own[index].mesh:
						mesh = child as MeshInstance3D
				_q.kit.need(problems, mesh != null and own[index].global_transform.is_equal_approx(mesh.global_transform), "Player %d's %s: the copy %s is not where its mesh is drawn" % [player + 1, pivot.name, own[index].name])
				if not own[index].global_transform.basis.is_equal_approx(before[index]):
					turned += 1
	_q.kit.need(problems, pivots_seen == 4 and turned == 16, "%d pivots seen and %d of the 16 copies turned" % [pivots_seen, turned])
	measured.append("turning_copies=%d" % turned)
	_q.kit.verdict("turning_parts", problems, "on each Player's Gyrocopter the rotor's and the propeller's four copies hang under their pivots (%d pivots, %d copies), stand where their meshes are drawn and turned with them over %d ticks (%d of 16 copies changed their basis), and the smear is not copied" % [pivots_seen, copies_seen, TURN_TICKS, turned])


## small_things (AC-4): a badly damaged Unit's smoke gets no copy, and the two Players' layers differ.
func _small_things() -> void:
	var problems: PackedStringArray = []
	var settings: SilhouetteSettings = _k.settings()
	await _k.stage(0, Quick.GYROCOPTER, _spot(0), Vector3.RIGHT)
	var unit: Unit = _k.unit(0)
	var before: int = _k.copies_of(0).size()
	unit.apply_damage(unit.hit_points - unit.stats.max_hit_points * HURT_SHARE)
	await _q.kit.advance(SMOKE_TICKS)
	var smoke: Node3D = _k.model_of(0).get_node_or_null("Smoke") as Node3D
	_q.kit.need(problems, unit.is_badly_damaged and smoke != null, "the Gyrocopter is badly damaged %s and its smoke is %s" % [unit.is_badly_damaged, smoke])
	var puffs: int = smoke.find_children("*", "MeshInstance3D", true, false).size() if smoke != null else 0
	_q.kit.need(problems, puffs > 0, "the smoke has no puffs, so the check proves nothing")
	_q.kit.need(problems, _k.copies_of(0).size() == before and _k.drawn_meshes(0).size() * 2 == before and _k.fills_of(0) == 1, "the Unit holds %d copies, %d drawn meshes and %d fill quads after the smoke began, %d copies before" % [_k.copies_of(0).size(), _k.drawn_meshes(0).size(), _k.fills_of(0), before])
	for puff: Node in smoke.find_children("*", "MeshInstance3D", true, false) if smoke != null else []:
		_q.kit.need(problems, not puff.is_in_group(UnitSilhouette.COPY_GROUP) and not puff.is_in_group(UnitSilhouette.FILL_GROUP) and not puff.is_in_group(Unit.SILHOUETTE_GROUP), "a puff of the smoke is a copy, a fill quad or a drawn mesh of the model")
	_q.kit.need(problems, settings.player_1_layer != settings.player_2_layer, "the Players share a silhouette layer")
	measured.append("smoke_puffs=%d" % puffs)
	_q.kit.verdict("small_things", problems, "the %d puffs of a badly damaged Gyrocopter's smoke are neither drawn meshes of the model, copies nor a fill quad (the Unit still holds its %d copies, %d drawn meshes and its one fill quad), and the two Players' silhouette layers (%d, %d) differ" % [puffs, before, before / 2, settings.player_1_layer, settings.player_2_layer])
