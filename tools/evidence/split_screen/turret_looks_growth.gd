extends RefCounted
## The growth check of the turret_looks scenario (Story 015 AC-3 and AC-8): the Turret grows to about
## 3 m on the same 2 m footprint, sized so that its head overlaps the band the Gyrocopter's model will
## fly in. The band is measured as the story measures it, from the mesh files as the game draws them:
## the tallest drawn ground body (the thin parts left out: a whip, a pennant, an aerial; the
## measurements/ probe lists them) plus the clearance the Gyrocopter's rise keeps is the flying
## height, its lowest drawn point, and its top is that height plus the model's drawn extent. Then the
## Turret: the drum's top, the dome's top and the barrel's drawn height from its nodes, the collider
## from the ground to the dome's top on the same radius, its place and rest heading, the barrel wholly
## inside the band and the dome's top about 0.5 m over its lowest point; a Shot leaves 1.6 m from the
## centre at the one shooting height (0.5 m: it is not drawn from the raised head, R17), and the
## Mines' open-ground test refuses a standing Turret and reads its rubble open. A Unit of every type
## stopping at its face is the solid check of turrets_clear.gd, which turret_looks runs on the
## shipped Turret. Run by turret_looks.gd. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md AC-3 and AC-8. Tooling only.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd).
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
## The Flag Wall's scene: its drawn box is a Wall Panel's height (A1, decided 2026-10-10).
const FLAG_WALL_PATH: String = "res://src/gameplay/defences/flag_wall.tscn"

## The thin parts of the ground types' files, by type id: boxes in the file's frame found by the
## probe (measurements/probe_heights.gd.txt), left out of the body's top. The Buggy's whip and
## pennant, the Truck's whip antenna.
const THIN: Dictionary = {
	&"buggy": [AABB(Vector3(0.38, 1.2, 0.95), Vector3(0.08, 0.85, 0.6))],
	&"truck": [AABB(Vector3(-0.82, 1.5, 0.2), Vector3(0.14, 1.25, 0.25))],
}
## The story's figures for the Turret (AC-3), metres, each "about": the drum's top, the dome's top, the
## barrel's drawn height, the flying height, how far the dome's top stands over the band's lowest
## point. The tolerance of an "about", and of two places that must be one.
const DRUM_TOP: float = 2.2
const DOME_TOP: float = 3.0
const BARREL_FROM: float = 2.5
const BARREL_TO: float = 2.8
const FLYING: float = 2.5
const DOME_OVER_BAND: float = 0.5
const ABOUT: float = 0.1
const SAME: float = 0.01
## The Shot's muzzle may differ from the data's 1.6 m and the shooting height by this, metres.
const SHOT_TOLERANCE: float = 0.01
## Ticks the fixture gets to fire its first Shot and a settled physics space.
const FIRE_TICKS: int = 90

var _k: Kit13
## What the check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The check: the band, the Turret's geometry, its Shot and the Mines' test.
func run() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var band: Dictionary = _band(problems)
	var who: Turret = _k.turret(0, Kit13.LEFT)
	var tops: Dictionary = _geometry(who, band, problems)
	for each: Turret in _k.all():
		var side: int = Kit13.LEFT if each.name == &"TurretLeft" else Kit13.RIGHT
		var want: Vector3 = _k.place_of(each.player_index, side)
		var facing: Vector3 = -each.global_transform.basis.z
		q.kit.need(problems, each.global_position.distance_to(want) <= SAME and facing.distance_to(_k.w.way(each.player_index, Vector3.FORWARD).normalized()) <= SAME, "%s stands at %s facing %s, expected %s facing out of its Gate" % [each.name, each.global_position, facing, want])
	var shot: String = await _shot(problems)
	var mines: String = await _mines(who, problems)
	measured.append("growth=drum:%.2f/dome:%.2f/band:%.3f" % [tops["drum"], tops["dome"], band["low"]])
	q.kit.verdict("growth", problems, "the drum's top %.2f m, the dome's %.2f m, the barrel drawn %.2f to %.2f m; the collider from the ground to %.2f m on the drum's radius %.1f; the Gyrocopter's band, from the mesh files with the thin parts left out (the tallest ground body %.3f m + the rise's clearance %.2f m = the flying height): %.3f to %.3f m, so the barrel stands wholly inside it and the dome's top %.2f m over its lowest point; %s; %s" % [
		tops["drum"], tops["dome"], tops["barrel_low"], tops["barrel_high"], tops["dome"], Kit13.RADIUS, band["body"], band["clearance"], band["low"], band["high"], float(tops["dome"]) - float(band["low"]), shot, mines])


## The band the Gyrocopter's model flies in, from the mesh files as the story measures it: {low (the
## flying height: the tallest ground body's drawn top plus the clearance its rise keeps, which is its
## lowest drawn point's height), body, clearance, extent (its drawn height) and high (low plus extent)}.
## Asserts a Unit and not a Wall Panel sets the flying height (the panel is lower than the tallest
## body). The flyer is the model that rises over cliffs, the others are ground types.
func _band(problems: PackedStringArray) -> Dictionary:
	var q: Quick = _k.w.s.q
	var tallest: float = 0.0
	var clearance: float = 0.0
	var extent: float = 0.0
	for type_index: int in q.controller.unit_types().size():
		var stats: UnitStats = q.units.stats(type_index)
		var model: MeshUnitModel = stats.model.instantiate() as MeshUnitModel
		if model.rise_over_cliffs:
			var hull: AABB = MeshUnitModel.hull_of(model.mesh_scene, INF)
			clearance = model.rise_clearance
			extent = hull.end.y - hull.position.y
		else:
			tallest = maxf(tallest, _body_top(model.mesh_scene, THIN.get(stats.type_id, []) as Array) + model.hover_height + model.offset.y)
		model.free()
	var panel_node: Node = (load(FLAG_WALL_PATH) as PackedScene).instantiate()
	var panel_top: float = ((panel_node.get_node("Mesh") as MeshInstance3D).mesh as PrimitiveMesh).get_aabb().size.y
	panel_node.free()
	q.kit.need(problems, tallest > panel_top and extent > 0.0, "the tallest ground body (%.3f m) does not stand over a Wall Panel (%.2f m), or the flyer has no extent (%.3f)" % [tallest, panel_top, extent])
	q.kit.need(problems, absf(tallest + clearance - FLYING) <= ABOUT, "the flying height %.3f m (the tallest body %.3f m + the clearance %.2f m) is not about the story's %.1f m" % [tallest + clearance, tallest, clearance, FLYING])
	return {"low": tallest + clearance, "body": tallest, "clearance": clearance, "extent": extent, "high": tallest + clearance + extent}


## The highest vertex of a mesh file outside the thin boxes: the drawn body's top.
func _body_top(file: PackedScene, thin: Array) -> float:
	var top: float = -INF
	var meshes: Dictionary = MeshFile.meshes_of(file)
	for mesh_name: StringName in meshes:
		var mesh: Mesh = meshes[mesh_name]
		for surface: int in mesh.get_surface_count():
			for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				if not thin.any(func(box: AABB) -> bool: return box.has_point(point)):
					top = maxf(top, point.y)
	return top


## The Turret's geometry from its nodes, in its own frame, against the band: {drum (its top), dome
## (its top), barrel_low and barrel_high (the barrel's drawn bottom and top)}.
func _geometry(who: Turret, band: Dictionary, problems: PackedStringArray) -> Dictionary:
	var q: Quick = _k.w.s.q
	var to_turret: Transform3D = who.global_transform.affine_inverse()
	var drum_node: MeshInstance3D = who.get_node(Looks.LOOK_NAMES[0]) as MeshInstance3D
	var dome_node: MeshInstance3D = who.get_node(Looks.WORN_NAMES[0]) as MeshInstance3D
	var barrel_node: MeshInstance3D = who.get_node(Looks.WORN_NAMES[1]) as MeshInstance3D
	var drum: AABB = to_turret * drum_node.global_transform * drum_node.get_aabb()
	var dome: AABB = to_turret * dome_node.global_transform * dome_node.get_aabb()
	var barrel: AABB = to_turret * barrel_node.global_transform * barrel_node.get_aabb()
	var shape_node: CollisionShape3D = who.get_node("CollisionShape3D") as CollisionShape3D
	var cylinder: CylinderShape3D = shape_node.shape as CylinderShape3D
	var drum_mesh: CylinderMesh = drum_node.mesh as CylinderMesh
	var collider_top: float = shape_node.position.y + cylinder.height / 2.0
	var collider_bottom: float = shape_node.position.y - cylinder.height / 2.0
	q.kit.need(problems, absf(drum.end.y - DRUM_TOP) <= ABOUT and absf(dome.end.y - DOME_TOP) <= ABOUT and barrel.position.y >= BARREL_FROM - ABOUT and barrel.end.y <= BARREL_TO + ABOUT, "the drum's top is %.3f m (about %.1f), the dome's %.3f m (about %.1f), the barrel drawn %.3f to %.3f m (about %.1f to %.1f)" % [drum.end.y, DRUM_TOP, dome.end.y, DOME_TOP, barrel.position.y, barrel.end.y, BARREL_FROM, BARREL_TO])
	q.kit.need(problems, absf(collider_top - dome.end.y) <= SAME and absf(collider_bottom) <= SAME, "the collider reaches %.3f to %.3f m, the dome's top is %.3f m (the collider reaches from the ground to it)" % [collider_bottom, collider_top, dome.end.y])
	q.kit.need(problems, is_equal_approx(cylinder.radius, Kit13.RADIUS) and is_equal_approx(drum_mesh.top_radius, Kit13.RADIUS) and is_equal_approx(drum_mesh.bottom_radius, Kit13.RADIUS), "the collider's radius %.3f and the drum's %.3f/%.3f are not the footprint's %.1f" % [cylinder.radius, drum_mesh.top_radius, drum_mesh.bottom_radius, Kit13.RADIUS])
	q.kit.need(problems, barrel.position.y >= float(band["low"]) - SAME and barrel.end.y <= float(band["high"]) and absf(dome.end.y - float(band["low"]) - DOME_OVER_BAND) <= ABOUT, "the barrel (drawn %.3f to %.3f m) must stand inside the band (%.3f to %.3f m) and the dome's top (%.3f m) about %.1f m over its lowest point" % [barrel.position.y, barrel.end.y, band["low"], band["high"], dome.end.y, DOME_OVER_BAND])
	return {"drum": drum.end.y, "dome": dome.end.y, "barrel_low": barrel.position.y, "barrel_high": barrel.end.y}


## A Shot of the grown Turret leaves muzzle_forward from its centre at the shooting height, level,
## along the barrel: the fixture fires at a Truck on its rest heading. Returns the note.
func _shot(problems: PackedStringArray) -> String:
	var q: Quick = _k.w.s.q
	var who: Turret = _k.make_arena(0)
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.TRUCK, Kit13.ARENA_CENTRE + Vector3(0.0, 0.0, -20.0), Vector3.BACK)
	await q.kit.advance(FIRE_TICKS)
	var first: Dictionary = _k.firing[mark] if _k.firing.size() > mark else {}
	var rules: MatchRules = q.controller.rules
	var out: float = 0.0
	var height: float = -1.0
	if not first.is_empty():
		var muzzle: Vector3 = first["muzzle"]
		out = Vector2(muzzle.x - who.global_position.x, muzzle.z - who.global_position.z).length()
		height = muzzle.y
		q.kit.need(problems, absf(out - who.stats.muzzle_forward) <= SHOT_TOLERANCE and absf(height - rules.shooting_height) <= SHOT_TOLERANCE and absf((first["direction"] as Vector3).y) <= SHOT_TOLERANCE, "the first Shot left %.3f m from the centre (the data: %.2f) at %.3f m (the shooting height %.2f), direction %s" % [out, who.stats.muzzle_forward, height, rules.shooting_height, first["direction"]])
	q.kit.need(problems, not first.is_empty(), "the fixture fired no Shot at a Truck on its rest heading")
	_k.free_arena()
	return "a Shot leaves %.2f m from the centre at %.2f m, the one shooting height" % [out, height]


## The Mines' open-ground test (MineLayer.is_open_ground()) at the Turret's place: refused while it
## stands, open once it has fallen, refused again when it is restored. Returns the note.
func _mines(who: Turret, problems: PackedStringArray) -> String:
	var q: Quick = _k.w.s.q
	var layer: MineLayer = q.harness.split.player_1_mine_layer
	await _k.restore_all()
	await q.kit.tick()
	var standing: bool = layer.is_open_ground(who.global_position)
	who.destroy()
	await q.kit.advance(Kit13.SETTLE)
	var fallen: bool = layer.is_open_ground(who.global_position)
	await _k.restore_all()
	await q.kit.tick()
	var back: bool = layer.is_open_ground(who.global_position)
	q.kit.need(problems, not standing and fallen and not back, "the open-ground test at the Turret's place: standing %s, fallen %s, restored %s (expected false, true, false)" % [standing, fallen, back])
	return "the Mines' open-ground test refuses its place while it stands and reads its rubble open"
