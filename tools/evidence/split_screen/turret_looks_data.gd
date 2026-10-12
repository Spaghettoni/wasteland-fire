extends RefCounted
## The looks_data check of the turret_looks scenario (Story 015 AC-2 and AC-7): what the shipped
## Turret's data and scene hold, read while all four stand whole. The fractions of turret_stats.tres
## are the story's 0.8 and 0.35, the Flag Walls' own. Each Turret's two damaged drums are direct
## MeshInstance3D children of Look that share the drum's mesh and draw it in its place and as it is
## drawn, wear the Flag Wall's damaged material of their stage, darker in order, and carry chunks at
## the foot that pile up from the first look to the second: every chunk low, unshadowed, on the
## ground, outside the drum's footprint and at its foot, shared by all four Turrets, with no collider
## anywhere under a look. The head's dome and barrel (worn_parts, never the band) take one steel per
## fraction, untextured so nothing slides over a head that turns, darker than the whole head's and
## the second darker than the first; the band wears its Base's Team material. In a fresh instance of
## the scene the damaged drums and the rubble are hidden. Run by turret_looks.gd. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md AC-2 and AC-7. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd).
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
## The Flag Wall's damaged materials and chips, the stats the fractions are the same as, and the
## whole head's steel: what the Turret's looks are made of, by path.
const WALL_DAMAGED: Array[String] = ["res://src/gameplay/defences/materials/flag_wall_damaged_1.tres", "res://src/gameplay/defences/materials/flag_wall_damaged_2.tres"]
const CHIPS_PATH: String = "res://src/gameplay/defences/materials/flag_wall_chips.tres"
const FLAG_WALL_STATS_PATH: String = "res://src/gameplay/defences/data/flag_wall_stats.tres"
const TOWER_PATH: String = "res://src/gameplay/maps/map_01/materials/tower.tres"
## A chunk's top stays under CHUNK_TOP metres (low, under the shooting height), its bottom no deeper
## than GROUND, and its centre within FOOT of the drum's surface (at its foot).
const CHUNK_TOP: float = 0.4
const GROUND: float = 0.05
const FOOT: float = 0.6
## The chunks each damaged drum is built with (AC-2: they pile up from the first look to the second).
const CHUNKS_BY_LOOK: Array[int] = [4, 8]

var _k: Kit13
## What the check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The looks_data check: the data, each Turret in the Round, and a fresh instance of the scene.
func run() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	var wall_stats: StructureStats = load(FLAG_WALL_STATS_PATH) as StructureStats
	var tower: BaseMaterial3D = load(TOWER_PATH) as BaseMaterial3D
	var first: Turret = _k.turret(0, Kit13.LEFT)
	q.kit.need(problems, first.stats.damaged_below == Looks.DAMAGED_BELOW and first.stats.damaged_below == wall_stats.damaged_below, "the Turret's damaged_below is %s, the story's %s and the Flag Walls' %s" % [first.stats.damaged_below, Looks.DAMAGED_BELOW, wall_stats.damaged_below])
	for base_index: int in Kit13.NAMES.size():
		for side: int in Kit13.NAMES.size():
			var who: Turret = _k.turret(base_index, side)
			_in_the_round(who, _k.w.bases[base_index], tower, problems)
			if base_index == 0 and side == 0:
				notes = _drums(who, problems)
	_shared(problems)
	_fresh_instance(problems)
	q.kit.verdict("looks_data", problems, "4 Turrets with damaged_below %s (the Flag Walls' own), whole, the head shown in its own steel and the band in its Base's Team material; two damaged drums each, direct children of Look drawing the drum's mesh in its place and as it is drawn, hidden in the scene, wearing the Flag Wall's damaged materials (%s) with %s chunks on the ground at the foot, outside the footprint, low, unshadowed, one mesh and one material shared by all four, no collider under a look; the dome and the barrel wear one untextured steel per fraction (%s) and the band none; a fresh instance of the scene hides both damaged drums and the rubble" % [
		Looks.DAMAGED_BELOW, ", ".join(WALL_DAMAGED.map(func(path: String) -> String: return path.get_file())), CHUNKS_BY_LOOK, ", ".join(notes)])


## One Turret as the Round has it, whole: the fractions and the look the story calls for, the head
## and its steel, the band, and the worn parts being the dome and the barrel and no other.
func _in_the_round(who: Turret, base: Base, tower: BaseMaterial3D, problems: PackedStringArray) -> void:
	var q: Quick = _k.w.s.q
	q.kit.need(problems, who.stats.damaged_below == Looks.DAMAGED_BELOW and Looks.look_shown(who) == 0 and Looks.head_visible(who), "%s: damaged_below %s, look shown %d, head shown %s" % [who.name, who.stats.damaged_below, Looks.look_shown(who), Looks.head_visible(who)])
	q.kit.need(problems, Looks.head_dressed(who, 0, base.color_material), "%s: its worn parts or its band are not dressed as a whole Turret's (steel %s, band %s)" % [who.name, Looks.steel_of(who, 0), (who.get_node(Looks.BAND_NAME) as MeshInstance3D).material_override])
	var parts: Array[GeometryInstance3D] = who.worn_parts
	var wanted: Array[Node] = [who.get_node(Looks.WORN_NAMES[0]), who.get_node(Looks.WORN_NAMES[1])]
	q.kit.need(problems, parts.size() == wanted.size() and parts[0] == wanted[0] and parts[1] == wanted[1] and not parts.has(who.get_node(Looks.BAND_NAME)), "%s: worn_parts %s is not the dome and the barrel alone" % [who.name, parts])
	q.kit.need(problems, who.intact == who.get_node(Looks.LOOK_NAMES[0]) and who.damaged_looks.size() == 2 and who.damaged_looks[0] == who.get_node(Looks.LOOK_NAMES[1]) and who.damaged_looks[1] == who.get_node(Looks.LOOK_NAMES[2]) and who.wreck == who.get_node(Looks.RUBBLE_NAME) and who.head == who.get_node(Looks.HEAD_NAME), "%s: intact, damaged_looks, wreck or head are not the nodes of the looks" % who.name)
	for index: int in Looks.WORN_NAMES.size():
		var part: MeshInstance3D = who.get_node(Looks.WORN_NAMES[index]) as MeshInstance3D
		q.kit.need(problems, (part.mesh as PrimitiveMesh).material == tower, "%s/%s's own mesh does not carry tower.tres" % [who.name, part.name])


## The drums and the steels of one Turret, as the scene holds them; returns the notes of the verdict
## (the steels' brightness, the whole drum's and the damaged drums').
func _drums(who: Turret, problems: PackedStringArray) -> PackedStringArray:
	var q: Quick = _k.w.s.q
	var whole: MeshInstance3D = who.get_node(Looks.LOOK_NAMES[0]) as MeshInstance3D
	var wall: BaseMaterial3D = (whole.mesh as PrimitiveMesh).material as BaseMaterial3D
	var drum_shade: float = Looks.shade(wall)
	var counted: int = 0
	var notes: PackedStringArray = ["drum %.2f" % drum_shade]
	var counts: Array[int] = []
	for index: int in range(1, Looks.LOOK_NAMES.size()):
		var look: MeshInstance3D = who.get_node(Looks.LOOK_NAMES[index]) as MeshInstance3D
		q.kit.need(problems, look.get_parent() == whole.get_parent() and look.mesh == whole.mesh and look.transform == whole.transform and look.layers == whole.layers and look.transparency == whole.transparency and look.cast_shadow == whole.cast_shadow and look.visibility_range_begin == whole.visibility_range_begin and look.visibility_range_end == whole.visibility_range_end, "%s is not the whole drum's mesh drawn in its place as it is drawn (layers %d, transparency %.2f, shadow %d)" % [look.name, look.layers, look.transparency, look.cast_shadow])
		var material: BaseMaterial3D = look.material_override as BaseMaterial3D
		q.kit.need(problems, material != null and material.resource_path == WALL_DAMAGED[index - 1], "%s wears %s, not the Flag Wall's %s" % [look.name, material.resource_path if material != null else "nothing", WALL_DAMAGED[index - 1].get_file()])
		var shade: float = Looks.shade(material) if material != null else INF
		q.kit.need(problems, shade < drum_shade, "%s is not darker than the look before it (%.3f, before it %.3f)" % [look.name, shade, drum_shade])
		drum_shade = shade
		notes.append("%.2f" % shade)
		var chunks: Array[MeshInstance3D] = []
		for child: Node in look.get_children():
			if String(child.name).begins_with("Chunk"):
				chunks.append(child as MeshInstance3D)
		q.kit.need(problems, chunks.size() > counted and chunks.size() == CHUNKS_BY_LOOK[index - 1], "%s has %d chunks, the look before it %d (the story's build: %d)" % [look.name, chunks.size(), counted, CHUNKS_BY_LOOK[index - 1]])
		counted = chunks.size()
		counts.append(counted)
		q.kit.need(problems, look.find_children("*", "CollisionObject3D", true, false).is_empty() and look.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has a collider under it" % look.name)
		for chunk: MeshInstance3D in chunks:
			_chunk(who, look, chunk, problems)
	var steels: Array[Material] = who.worn_steel
	var tower: BaseMaterial3D = ((who.get_node(Looks.WORN_NAMES[0]) as MeshInstance3D).mesh as PrimitiveMesh).material as BaseMaterial3D
	var head_shade: float = Looks.shade(tower)
	notes.append("head %.2f" % head_shade)
	q.kit.need(problems, steels.size() == Looks.DAMAGED_BELOW.size(), "%d worn steels for %d fractions" % [steels.size(), Looks.DAMAGED_BELOW.size()])
	for steel: Material in steels:
		var base_steel: BaseMaterial3D = steel as BaseMaterial3D
		var value: float = Looks.shade(base_steel) if base_steel != null else INF
		q.kit.need(problems, base_steel != null and base_steel.albedo_texture == null and base_steel.normal_texture == null and not base_steel.detail_enabled and base_steel.uv1_triplanar == false, "a worn steel (%s) is textured, so something could slide over a turning head" % [steel.resource_path.get_file() if steel != null else "none"])
		q.kit.need(problems, value < head_shade, "a worn steel is not darker than the steel before it (%.3f, before it %.3f)" % [value, head_shade])
		head_shade = value
		notes.append("%.2f" % value)
	return notes


## One chunk: low, unshadowed, on the ground, outside the drum's footprint and at its foot, in the
## Flag Wall's chip material. The footprint is measured on the rectangle the chunk's box covers in
## the horizontal plane, from the drum's axis.
func _chunk(who: Turret, look: MeshInstance3D, chunk: MeshInstance3D, problems: PackedStringArray) -> void:
	var q: Quick = _k.w.s.q
	var to_turret: Transform3D = who.global_transform.affine_inverse() * chunk.global_transform
	var box: AABB = chunk.get_aabb()
	var low: float = INF
	var high: float = -INF
	var corners: Array[Vector2] = []
	for corner: int in 8:
		var point: Vector3 = to_turret * box.get_endpoint(corner)
		low = minf(low, point.y)
		high = maxf(high, point.y)
		corners.append(Vector2(point.x, point.z))
	var near: float = INF
	var hull: PackedVector2Array = Geometry2D.convex_hull(PackedVector2Array(corners))
	for index: int in hull.size() - 1:
		near = minf(near, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, hull[index], hull[index + 1]).length())
	var centre: Vector3 = to_turret * box.get_center()
	var from_axis: float = Vector2(centre.x, centre.z).length()
	var cylinder: CylinderShape3D = (who.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	q.kit.need(problems, chunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and high < CHUNK_TOP and low > -GROUND and near >= cylinder.radius and from_axis - cylinder.radius < FOOT, "%s/%s/%s: shadow %d, bottom %.2f and top %.2f m, nearest %.3f m and centre %.2f m from the axis (drum radius %.1f)" % [who.name, look.name, chunk.name, chunk.cast_shadow, low, high, near, from_axis, cylinder.radius])
	var material: Material = (chunk.mesh as PrimitiveMesh).material
	q.kit.need(problems, material != null and material.resource_path == CHIPS_PATH, "%s/%s/%s is not in the Flag Wall's chip material" % [who.name, look.name, chunk.name])


## One mesh and one material for the chunks of all four Turrets (the scene's sub-resources are shared
## by every instance): the same-named chunk of two Turrets draws the same Mesh object.
func _shared(problems: PackedStringArray) -> void:
	var q: Quick = _k.w.s.q
	var mine: MeshInstance3D = _k.turret(0, Kit13.LEFT).get_node(Looks.LOOK_NAMES[1] + "/Chunk1") as MeshInstance3D
	for who: Turret in _k.all():
		var other: MeshInstance3D = who.get_node(Looks.LOOK_NAMES[1] + "/Chunk1") as MeshInstance3D
		q.kit.need(problems, other.mesh == mine.mesh and (other.mesh as PrimitiveMesh).material == (mine.mesh as PrimitiveMesh).material, "%s's first chunk draws a mesh or a material of its own" % who.name)


## A fresh instance of the scene, outside the tree: the damaged drums and the rubble are hidden, the
## whole drum and the head shown, as the scene authors them.
func _fresh_instance(problems: PackedStringArray) -> void:
	var q: Quick = _k.w.s.q
	var fresh: Turret = q.harness.turret_scene.instantiate() as Turret
	var seen: Array[bool] = []
	for path: String in Looks.LOOK_NAMES + [Looks.RUBBLE_NAME, Looks.HEAD_NAME]:
		seen.append((fresh.get_node(path) as Node3D).visible)
	q.kit.need(problems, seen == [true, false, false, false, true], "a fresh Turret shows (whole drum, drum 1, drum 2, rubble, head) %s, expected [true, false, false, false, true]" % [seen])
	fresh.free()
