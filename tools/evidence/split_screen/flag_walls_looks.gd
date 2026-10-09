extends RefCounted
## The looks check of the flag_walls scenario (Story 012 AC-9, added 2026-10-08): what a Flag Wall
## shows as it loses hit points. Static: every Flag Wall's damaged_below fractions read from the
## data are the story's 0.8 and 0.35, and its two damaged looks (MeshDamaged1 and MeshDamaged2) are
## direct MeshInstance3D children that draw Mesh's box in Mesh's place on Mesh's render layers,
## over the Base walls' texture with a crack layer of their own, darker in order, with more chunks
## in the second, every chunk low, on the ground at the panel's foot and outside it, with no
## collider or shadow; in the scene the damaged looks and the rubble are hidden. Played: after
## every Shot of the damage check's runs to the fall, the one look shown is the one the data's
## fractions predict from the hit points, and the runs are the story's; every hit_points_changed
## so far was emitted with the look its hit points call for; a wall at exactly 80% and 35% of its
## hit points still shows the look above; restore() brings back the whole look; a wall whose stats
## hold other fractions follows them. Refusals: a Flag Wall whose list of looks is short or has an
## empty slot logs one error and shows only its whole look until it falls; stats with the fractions
## out of order are refused with one error and the piece shows its whole look; fractions out of
## range or NaN, and a NaN maximum, are refused by first_problem(). Run by flag_walls.gd.
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-9. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs and the story's
## values.

## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the walls, the look names, look_shown().
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Flag Wall's scene.
const SCENE_PATH: String = "res://src/gameplay/defences/flag_wall.tscn"
## The story's fractions of the hit points below which a Flag Wall shows its two damaged looks.
const DAMAGED_BELOW: Array[float] = [0.8, 0.35]
## The story's look after each Shot of a run to the fall, by type (AC-9): 1 and 2 the damaged
## looks, -1 the rubble. The Motorbike's run shows the whole look, 0, after every Shot.
const RUNS: Dictionary = {&"buggy": [1, 1, 2, -1], &"truck": [1, -1], &"gyrocopter": [1, 2, -1]}
## Hit points taken off a whole Flag Wall to leave it exactly at the first fraction and at the
## second (32 and 14 of 40: the edge test's inputs), and then a little more to put it just below.
const TO_FIRST: float = 8.0
const TO_SECOND: float = 26.0
const JUST_BELOW: float = 0.5
## Other fractions, for a wall that must follow its own data, the hit points taken off it in turn
## and the look each step leaves (30 of 40 whole, 23.5 the first look, 7.5 the second).
const OTHER_BELOW: Array[float] = [0.6, 0.2]
const OTHER_STEPS: Array[float] = [10.0, 6.5, 16.0]
const OTHER_LOOKS: Array[int] = [0, 1, 2]
## Fraction lists first_problem() must refuse: written in percent, one at 1, one at 0, one NaN.
const BAD_BELOW: Array = [[80.0, 35.0], [1.0, 0.35], [0.8, 0.0], [0.8, NAN]]
## A chunk's top stays under CHUNK_TOP metres (AC-9: low, under the shooting height), its bottom no
## deeper than GROUND, and its centre within FOOT of the panel's face (at its foot).
const CHUNK_TOP: float = 0.4
const GROUND: float = 0.05
const FOOT: float = 0.6
## Where the built-wrong Flag Walls are put while they are tested: far under Base B, out of reach.
const ASIDE: Vector3 = Vector3(0.0, -50.0, -16.0)

## The engine errors this check causes on purpose (three Flag Walls built wrong).
var expected_errors: int = 0

var _w: Walls


func _init(kit: Walls) -> void:
	_w = kit


## The looks check: static, then the damage check's runs ({type id: [[hit points, look], ...]},
## one pair per Shot), every hit_points_changed so far, the edges, restore(), the built-wrong walls
## and other data. Prints its CHECK line. A coroutine: await it.
func run(runs: Dictionary) -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var stats: StructureStats = _w.wall(1, Walls.GATE).stats
	var shades: PackedStringArray = []
	var chunks: PackedStringArray = []
	for piece: Structure in _w.all():
		_static(piece, problems, shades, chunks)
	var played: PackedStringArray = []
	for type_id: StringName in runs.keys():
		var seen: Array = runs[type_id]
		var looks: Array = seen.map(func(pair: Array) -> int: return int(pair[1]))
		for pair: Array in seen:
			q.kit.need(problems, int(pair[1]) == _predicted(float(pair[0]), stats), "%s: at %.1f hit points the look shown is %d, the data predict %d" % [type_id, pair[0], pair[1], _predicted(float(pair[0]), stats)])
		var want: Array = RUNS.get(type_id, looks.map(func(_look: int) -> int: return 0))
		q.kit.need(problems, not looks.is_empty() and looks == want, "%s: looks after each Shot %s, the story's %s" % [type_id, looks, want])
		played.append("%s %s" % [type_id, looks])
	for hit: Dictionary in _w.hits:
		var piece: Structure = hit["wall"] as Structure
		q.kit.need(problems, int(hit["look"]) == _predicted(float(hit["hp"]), piece.stats), "%s emitted hit_points_changed at %.1f hit points while showing look %d" % [piece.name, hit["hp"], hit["look"]])
	var edges: Array[int] = await _edges(problems)
	q.kit.need(problems, edges.size() == 5, "the edge test did not run to its end (%s)" % [edges])
	q.kit.need(problems, await _built_wrong(problems) == true, "the built-wrong walls did not run to their end")
	q.kit.need(problems, _other_data(problems) == true, "the other data did not run to their end")
	q.kit.verdict("looks", problems, "8 Flag Walls with damaged_below %s, two damaged looks each drawing Mesh's box on its layers over the wall's texture with a crack layer of its own (albedo %s; chunks %s, on the ground at the foot), no collider, hidden while whole and in the scene; the look after each Shot of the runs to the fall, as the data predict (0 whole, 1 and 2 damaged, -1 rubble): %s; all %d hit_points_changed emitted with the predicted look; at exactly 80%%, just below, at exactly 35%%, just below and restored: %s; a short list or an empty slot: one error each and only the whole look until the fall; fractions out of order: refused with one error, whole look; other fractions %s followed: %s; fractions in percent, at 1, at 0 or NaN and a NaN maximum refused" % [
		DAMAGED_BELOW, shades[0] if not shades.is_empty() else "?", chunks[0] if not chunks.is_empty() else "?", ", ".join(played), _w.hits.size(), edges, OTHER_BELOW, OTHER_LOOKS])


## One Flag Wall's damaged looks as the data and the scene hold them, while it is whole: the story's
## fractions, each damaged look a direct MeshInstance3D child that draws Mesh's box in Mesh's place
## and as Mesh is drawn, in the list in name order, over the whole look's texture with a crack layer
## of its own, darker than the look before it, with more chunks than the one before it, no collider,
## and every chunk low, unshadowed, on the ground at the panel's foot and outside it. Adds the first
## wall's shades and chunk counts to the notes.
func _static(piece: Structure, problems: PackedStringArray, shades: PackedStringArray, chunks: PackedStringArray) -> void:
	var q: Quick = _w.s.q
	var mesh: MeshInstance3D = piece.get_node(Walls.LOOK_NAMES[0]) as MeshInstance3D
	var whole: BaseMaterial3D = (mesh.mesh as PrimitiveMesh).material as BaseMaterial3D
	var half: Vector3 = ((piece.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size / 2.0
	q.kit.need(problems, piece.stats.damaged_below == DAMAGED_BELOW and _w.look_shown(piece) == 0, "%s: damaged_below %s (the story's %s), look shown %d while whole" % [piece.name, piece.stats.damaged_below, DAMAGED_BELOW, _w.look_shown(piece)])
	var shade: float = _shade(whole)
	var counted: int = 0
	var cracks: Texture2D = null
	var notes: Array[String] = ["%.2f" % shade]
	var counts: Array[int] = []
	for index: int in range(1, Walls.LOOK_NAMES.size()):
		var look: MeshInstance3D = piece.get_node_or_null(Walls.LOOK_NAMES[index]) as MeshInstance3D
		if look == null or look.get_parent() != piece:
			q.kit.need(problems, false, "%s has no direct MeshInstance3D child %s" % [piece.name, Walls.LOOK_NAMES[index]])
			continue
		q.kit.need(problems, piece.damaged_looks.size() >= index and piece.damaged_looks[index - 1] == look, "%s: damaged_looks[%d] is not %s" % [piece.name, index - 1, look.name])
		q.kit.need(problems, look.mesh == mesh.mesh and look.transform == mesh.transform and look.layers == mesh.layers and look.transparency == mesh.transparency and look.cast_shadow == mesh.cast_shadow and look.visibility_range_begin == mesh.visibility_range_begin and look.visibility_range_end == mesh.visibility_range_end, "%s/%s is not Mesh's box drawn in Mesh's place as Mesh is (layers %d, transparency %.2f, shadow %d)" % [piece.name, look.name, look.layers, look.transparency, look.cast_shadow])
		var material: BaseMaterial3D = look.material_override as BaseMaterial3D
		q.kit.need(problems, material != null and whole != null and material.albedo_texture == whole.albedo_texture and material.detail_enabled and material.detail_mask != null and material.detail_albedo != null and material.detail_mask != cracks, "%s/%s is not the wall's texture with a crack layer of its own" % [piece.name, look.name])
		cracks = material.detail_mask if material != null else null
		var value: float = _shade(material)
		q.kit.need(problems, value < shade, "%s/%s is not darker than the look before it (%.3f, before it %.3f)" % [piece.name, look.name, value, shade])
		shade = value
		notes.append("%.2f" % value)
		var parts: Array[Node] = look.find_children("*", "MeshInstance3D", true, false)
		q.kit.need(problems, parts.size() > counted, "%s/%s has %d chunks, the look before it %d" % [piece.name, look.name, parts.size(), counted])
		counted = parts.size()
		counts.append(counted)
		q.kit.need(problems, look.find_children("*", "CollisionObject3D", true, false).is_empty() and look.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s/%s has a collider" % [piece.name, look.name])
		for node: Node in parts:
			var chunk: MeshInstance3D = node as MeshInstance3D
			var box: AABB = piece.global_transform.affine_inverse() * (chunk.global_transform * chunk.get_aabb())
			var centre: Vector3 = box.get_center()
			var near: float = absf(centre.z) - box.size.z / 2.0
			q.kit.need(problems, chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and box.end.y < CHUNK_TOP and box.position.y > -GROUND and near >= half.z and absf(centre.z) - half.z < FOOT and absf(centre.x) < half.x, "%s/%s/%s: shadow %d, bottom %.2f and top %.2f m, near side %.3f and centre %.2f m from the panel's mid-plane (half size %s)" % [piece.name, look.name, chunk.name, chunk.cast_shadow, box.position.y, box.end.y, near, absf(centre.z), half])
	shades.append(" > ".join(notes))
	chunks.append(str(counts))


## The look the given stats' fractions predict at `hit_points`: -1 the rubble at 0, else how many of
## their damaged_below fractions of their maximum it is below (0 whole, 1, 2).
func _predicted(hit_points: float, stats: StructureStats) -> int:
	if hit_points <= 0.0:
		return -1
	var look: int = 0
	for fraction: float in stats.damaged_below:
		look += 1 if hit_points < fraction * stats.max_hit_points else 0
	return look


## The edges, on Base B's Gate-side Flag Wall by apply_damage(): exactly at the first fraction (the
## whole look), just below it (the first damaged look), exactly at the second (the first), just
## below it (the second), then restore() (whole). Returns the five looks seen.
func _edges(problems: PackedStringArray) -> Array[int]:
	var q: Quick = _w.s.q
	var wall: Structure = _w.wall(1, Walls.GATE)
	var top: float = wall.stats.max_hit_points
	q.kit.need(problems, top - TO_FIRST == DAMAGED_BELOW[0] * top and top - TO_SECOND == DAMAGED_BELOW[1] * top, "the edge test's inputs do not land exactly on the fractions (%.17f, %.17f)" % [top - TO_FIRST, top - TO_SECOND])
	var seen: Array[int] = []
	await _w.restore_all()
	wall.apply_damage(TO_FIRST)
	seen.append(_w.look_shown(wall))
	wall.apply_damage(JUST_BELOW)
	seen.append(_w.look_shown(wall))
	await _w.restore_all()
	wall.apply_damage(TO_SECOND)
	seen.append(_w.look_shown(wall))
	wall.apply_damage(JUST_BELOW)
	seen.append(_w.look_shown(wall))
	await _w.restore_all()
	seen.append(_w.look_shown(wall))
	q.kit.need(problems, seen == [0, 1, 1, 2, 0], "at exactly 80%%, just below, at exactly 35%%, just below and restored the looks were %s, expected [0, 1, 1, 2, 0]" % [seen])
	for piece: Structure in _w.all():
		q.kit.need(problems, _w.look_shown(piece) == 0, "%s shows look %d after restore()" % [piece.name, _w.look_shown(piece)])
	return seen


## Three Flag Walls built wrong, each put far under Base B and freed: one whose list of damaged
## looks lost its second entry and one whose second entry is empty each log one error as they
## enter the tree, show only their whole look below both fractions and their rubble when they fall;
## one whose stats have the fractions out of order is refused, with one error, and shows its whole
## look. And in the scene itself the damaged looks and the rubble are hidden. Returns true at its
## end, so a run cut short by a script error is seen.
func _built_wrong(problems: PackedStringArray) -> bool:
	var q: Quick = _w.s.q
	var world: Node = q.harness.split.get_node("World")
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	var errors_before: int = q.tokens.engine_log.errors.size()
	for empty_slot: bool in [false, true]:
		var piece: Structure = scene.instantiate() as Structure
		var listed: Array[Node3D] = []
		if not piece.damaged_looks.is_empty():
			listed.append(piece.damaged_looks[0])
		if empty_slot:
			listed.append(null)
		piece.damaged_looks = listed
		world.add_child(piece)
		piece.global_position = _w.point(1, ASIDE)
		expected_errors += 1
		piece.apply_damage(piece.hit_points - JUST_BELOW)
		var hurt_look: int = _w.look_shown(piece)
		piece.apply_damage(piece.hit_points)
		q.kit.need(problems, q.tokens.engine_log.errors.size() == errors_before + expected_errors and hurt_look == 0 and _w.look_shown(piece) == -1, "a Flag Wall whose list %s: %d errors in all, look %d at %.1f hit points, look %d fallen" % ["has an empty slot" if empty_slot else "lost its second look", q.tokens.engine_log.errors.size() - errors_before, hurt_look, JUST_BELOW, _w.look_shown(piece)])
		world.remove_child(piece)
		piece.free()
	var bad: StructureStats = _w.wall(1, Walls.GATE).stats.duplicate() as StructureStats
	var reversed: Array[float] = [DAMAGED_BELOW[1], DAMAGED_BELOW[0]]
	bad.damaged_below = reversed
	var refused: Structure = scene.instantiate() as Structure
	refused.stats = bad
	world.add_child(refused)
	refused.global_position = _w.point(1, ASIDE)
	expected_errors += 1
	q.kit.need(problems, q.tokens.engine_log.errors.size() == errors_before + expected_errors and refused.type_id == &"" and not refused.is_standing and _w.look_shown(refused) == 0, "stats with the fractions out of order: %d errors in all, type '%s', standing %s, look %d" % [q.tokens.engine_log.errors.size() - errors_before, refused.type_id, refused.is_standing, _w.look_shown(refused)])
	world.remove_child(refused)
	refused.free()
	var fresh: Node = scene.instantiate()
	var hidden: bool = (fresh.get_node(Walls.LOOK_NAMES[0]) as Node3D).visible
	for name: String in [Walls.LOOK_NAMES[1], Walls.LOOK_NAMES[2], Walls.RUBBLE_NAME]:
		var node: Node3D = fresh.get_node_or_null(name) as Node3D
		hidden = hidden and node != null and not node.visible
	fresh.free()
	q.kit.need(problems, hidden, "in the Flag Wall's scene a damaged look or the rubble is shown, or the whole look hidden")
	return true


## A Flag Wall whose stats hold other fractions follows them, step by step, as _predicted() reads
## them from those stats; and first_problem() refuses fraction lists in percent, at 1, at 0 or with
## a NaN, and a NaN maximum. Logs nothing. Returns true at its end.
func _other_data(problems: PackedStringArray) -> bool:
	var q: Quick = _w.s.q
	var world: Node = q.harness.split.get_node("World")
	var other: StructureStats = _w.wall(1, Walls.GATE).stats.duplicate() as StructureStats
	var fractions: Array[float] = []
	fractions.assign(OTHER_BELOW)
	other.damaged_below = fractions
	var follower: Structure = (load(SCENE_PATH) as PackedScene).instantiate() as Structure
	follower.stats = other
	world.add_child(follower)
	follower.global_position = _w.point(1, ASIDE)
	var followed: Array[int] = []
	var predicted: Array[int] = []
	for step: float in OTHER_STEPS:
		follower.apply_damage(step)
		followed.append(_w.look_shown(follower))
		predicted.append(_predicted(follower.hit_points, other))
	world.remove_child(follower)
	follower.free()
	q.kit.need(problems, followed == predicted and followed == OTHER_LOOKS, "a Flag Wall with damaged_below %s showed %s, its data predict %s" % [OTHER_BELOW, followed, predicted])
	var refusals: int = 0
	for below: Array in BAD_BELOW:
		var probe: StructureStats = other.duplicate() as StructureStats
		var listed: Array[float] = []
		listed.assign(below)
		probe.damaged_below = listed
		refusals += 0 if probe.first_problem().is_empty() else 1
	var nan_top: StructureStats = other.duplicate() as StructureStats
	nan_top.max_hit_points = NAN
	q.kit.need(problems, refusals == BAD_BELOW.size() and not nan_top.first_problem().is_empty(), "first_problem() refused %d of %d bad fraction lists, and a NaN maximum: '%s'" % [refusals, BAD_BELOW.size(), nan_top.first_problem()])
	return true


## How light a look's material is: the luminance of its albedo_color (wall.tres is a grey of 0.55),
## or INF when it is not a BaseMaterial3D, so a missing material never passes as darker. The
## textures are checked to be the same resource, so this order is the order drawn.
func _shade(material: Material) -> float:
	var base: BaseMaterial3D = material as BaseMaterial3D
	return base.albedo_color.get_luminance() if base != null else INF
