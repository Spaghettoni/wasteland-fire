class_name KitMerge
extends RefCounted
## Builds the two meshes of a Unit model from one of the author's concept-kit models
## (res://assets/art/vehicles/wasteland_<type>/wasteland_<type>.tscn): the Team accent, which the
## Unit paints with its Team material, and the neutral parts. KitUnitModel shows them.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-11 (each Unit wears its
## Team's colour and no other), AC-12 (each type reads by the silhouette of the concept sheet
## assets/art/vehicles/vehicle-design.png) and AC-14 (the draw calls); design/rules.md "Teams and
## visual style". Vocabulary: CONTEXT.md (Unit, Team).
##
## The kit is the author's, loaded by path and never edited: each kit model's script builds its
## parts in its _ready() as MeshInstance3D nodes of engine primitives, each with a palette
## material as material_override, and keeps the palette in a private dictionary
## (KIT_PALETTE_PROPERTY: kit key -> material). get_or_build() instances the kit under a host in the
## tree, so the kit builds; reads each part's arrays once with PrimitiveMesh.get_mesh_arrays(), a
## read back from the GPU too slow to repeat, which is why a build is cached (measured on 4.7.2; the
## Story 007 evidence doc keeps the run); bakes the part's transform into its vertices (normals by
## the inverse-transpose basis, UVs kept, tangents dropped); folds the parts by kit key; and frees
## the kit. The accent mesh is one surface: the parts of ACCENT_KEYS at a white vertex colour and
## those of ACCENT_DARK_KEYS at DARK_TONE. The neutral mesh is one surface of every other key, each
## part at its key's kit colour as its vertex colour (the kit's paint textures dropped: flat, and
## clean at 40 m), plus one surface per key of APART_KEYS the kit uses, with the kit's own material.
## That is four surfaces a Unit.
##
## Two remaps change a part's key before it folds: a part remap (one part, found by its BoxMesh size
## and its centre in the kit's frame) and a key remap (every part of a key). The part remap is keyed
## on the kit part's geometry, so a kit edit that moves or resizes that part leaves it unmatched:
## the build reports an error naming the kit scene and the entries, and the part keeps its kit key.

## The kit keys that are the Team accent at full tone: the kit's two Team paints and the rims.
const ACCENT_KEYS: Array[String] = ["teal", "orange", "rim"]
## The kit keys that are the Team accent at DARK_TONE: the kit's two dark Team paints.
const ACCENT_DARK_KEYS: Array[String] = ["teal_dark", "orange_dark"]
## The vertex tone of ACCENT_DARK_KEYS: under a Team material it gives the kit's ORANGE_DARK and
## TEAL_DARK within 0.02 a channel (computed from the kit's palette constants, in sRGB and in the
## linear space the renderer multiplies in; the Story 007 evidence doc keeps the sums).
const DARK_TONE: float = 0.68
## The kit keys that keep the kit's own material, each as its own surface of the neutral mesh: the
## lamp (it glows), the skull decal (its texture) and the Gyrocopter's screen.
const APART_KEYS: Array[String] = ["lamp", "skull", "screen"]
## The kit key whose colour the accent surface's own material wears, seen only on a Unit with no
## team_material: a neutral steel, never white and never a Team colour.
const FALLBACK_KEY: String = "steel"
## Roughness of the neutral fold's material, one value for every folded neutral part, whose kit
## materials (assets/art/shared/wasteland_palette.gd) range from 0.25 to 1.0: a matte middle, the
## value the folded look was judged with (the Story 007 evidence doc).
const NEUTRAL_ROUGHNESS: float = 0.8
## Metallic of the neutral fold's material, one value for every folded neutral part, whose kit
## materials range from 0.0 to 0.7; chosen with NEUTRAL_ROUGHNESS.
const NEUTRAL_METALLIC: float = 0.1
## The kit script's private palette, kit key -> material, read with get().
const KIT_PALETTE_PROPERTY: StringName = &"_m"
## The kit script's rust seed, set before the kit builds.
const KIT_SEED_PROPERTY: StringName = &"rust_seed"
## The kit's posable parts and the game pose they take before the kit builds: steer_deg zeroed on
## the Motorbike, Buggy and Truck kits (front wheels straight) and pod_yaw_deg on the Truck kit (its
## pod aimed forward); a kit without the property keeps its authored pose (the Gyrocopter's rotor
## yaw and tilt, the Truck's pod pitch). KitUnitModel's model_scale and offset fit this pose.
const KIT_POSE: Dictionary[String, float] = {"steer_deg": 0.0, "pod_yaw_deg": 0.0}
## Vertices up to this height in the kit's frame, metres, make Built.hull: the kits' bodies,
## without the Gyrocopter's mast and rotor above them.
const HULL_TOP: float = 2.0
## How near a part's BoxMesh size and centre must come to a part remap entry's, metres.
const PART_TOLERANCE: float = 0.001
## A part remap entry's key for the part's BoxMesh size (a Vector3).
const PART_SIZE: String = "size"
## A part remap entry's key for the part's centre in the kit's frame (a Vector3).
const PART_AT: String = "at"
## A part remap entry's key for the kit key the part takes (a String).
const PART_KEY: String = "key"
## The surface group of the Team accent while the parts fold.
const ACCENT_GROUP: String = "accent"
## The surface group of the neutral fold while the parts fold.
const NEUTRAL_GROUP: String = "neutral"

## Every build so far, by kit scene path, rust seed and remaps: made once per key and shared by
## every model of that key after (its meshes are never written after the build).
static var _cache: Dictionary[String, Built] = {}


## The build of kit_scene with rust_seed and the remaps, made the first time it is asked for and
## cached (a later call returns the same meshes at once). The kit is instanced under host, which
## must be in the tree (the kit builds its parts in its _ready()), and freed before this returns.
## Each part_remap entry is {PART_SIZE: Vector3, PART_AT: Vector3, PART_KEY: String}: the part
## whose mesh is a BoxMesh of that size with its centre there (within PART_TOLERANCE) takes that
## key. key_remap then gives every other part of a key (a String) another key (a String). Returns
## null, with an error naming the kit scene, when the build cannot run.
static func get_or_build(host: Node3D, kit_scene: PackedScene, rust_seed: int,
		key_remap: Dictionary[String, String], part_remap: Array[Dictionary]) -> Built:
	if kit_scene == null:
		push_error("KitMerge: no kit scene to build a model from.")
		return null
	var cache_key: String = "%s|%d|%s|%s" % [kit_scene.resource_path, rust_seed, key_remap,
			part_remap]
	if _cache.has(cache_key):
		return _cache[cache_key] as Built
	if host == null or not host.is_inside_tree():
		push_error("KitMerge: the kit scene '%s' needs a host in the tree to build in, so no model is built." % kit_scene.resource_path)
		return null
	var kit: Node3D = _instance_kit(kit_scene, rust_seed)
	if kit == null:
		return null
	host.add_child(kit)
	var built: Built = _build(kit, kit_scene.resource_path, key_remap, part_remap)
	host.remove_child(kit)
	kit.free()
	if built != null:
		_cache[cache_key] = built
	return built


## The kit scene instanced, not yet in the tree, with its rust seed and the game pose (KIT_POSE)
## set; null, with an error naming the kit scene, when its root is not a Node3D.
static func _instance_kit(kit_scene: PackedScene, rust_seed: int) -> Node3D:
	var instance: Node = kit_scene.instantiate()
	if not (instance is Node3D):
		push_error("KitMerge: the kit scene '%s' is not a Node3D scene, so no model is built." % kit_scene.resource_path)
		if instance != null:
			instance.free()
		return null
	var kit: Node3D = instance as Node3D
	kit.set(KIT_SEED_PROPERTY, rust_seed)
	for property: String in KIT_POSE:
		if property in kit:
			kit.set(property, KIT_POSE[property])
	return kit


## Folds the parts of a kit that has built (in the tree) into a Built; null, with an error naming
## the kit scene, when the kit has no palette or no part of it folds (a kit that builds its parts
## after its _ready() has none yet), so get_or_build() caches nothing. A part that cannot fold (its
## mesh is not a PrimitiveMesh, or its material or remapped key is not in the palette) is left out
## with an error naming the kit scene and the part. A part remap that does not match one part per
## entry is an error naming the kit scene and the entries (a part it does not match keeps its kit
## key).
static func _build(kit: Node3D, kit_path: String, key_remap: Dictionary[String, String],
		part_remap: Array[Dictionary]) -> Built:
	var palette: Dictionary[String, Material] = _palette_of(kit, kit_path)
	if palette.is_empty():
		return null
	var key_of: Dictionary[Material, String] = {}
	for key: String in palette:
		key_of[palette[key]] = key
	var parts: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	_collect(kit, Transform3D.IDENTITY, parts, transforms)
	var built: Built = Built.new()
	var surfaces: Dictionary[String, _Surface] = {}
	var remapped: int = 0
	for index: int in parts.size():
		var by_part: String = _part_remap_key(parts[index], transforms[index], part_remap)
		remapped += int(not by_part.is_empty())
		var key: String = _key_of_part(parts[index], by_part, key_of, key_remap)
		if not palette.has(key):
			push_error("KitMerge: part '%s' of the kit scene '%s' has a mesh or material the palette cannot fold (key '%s'), so it is left out." % [kit.get_path_to(parts[index]), kit_path, key])
			continue
		var arrays: Array = (parts[index].mesh as PrimitiveMesh).get_mesh_arrays()
		_append(_surface_for(surfaces, key, palette), arrays, transforms[index],
				_tone_of(key, palette))
	if surfaces.is_empty():
		push_error("KitMerge: the kit scene '%s' built no part the palette can fold, so no model is built." % kit_path)
		return null
	built.hull = _hull_of(surfaces)
	if remapped != part_remap.size():
		push_error("KitMerge: the part remap %s matched %d part(s) of the kit scene '%s', not one per entry, so a part it does not match keeps its kit key." % [part_remap, remapped, kit_path])
	_commit(surfaces, built)
	return built


## The kit's palette (KIT_PALETTE_PROPERTY), copied once into a typed dictionary, kit key ->
## Material (the kit declares its own untyped; an entry whose value is not a Material is left out);
## an empty one, with an error naming the kit scene, when the kit has none. Each Team accent key
## (ACCENT_KEYS, ACCENT_DARK_KEYS) the palette lacks is an error naming the kit scene and the key:
## a renamed accent key would fold into the neutral parts at its kit colour, and every Unit would
## wear it whichever Team owns it.
static func _palette_of(kit: Node3D, kit_path: String) -> Dictionary[String, Material]:
	var palette: Dictionary[String, Material] = {}
	var kit_palette: Variant = kit.get(KIT_PALETTE_PROPERTY)
	if kit_palette is Dictionary:
		# The kit's own dictionary is untyped: each entry is checked as it is copied.
		var kit_entries: Dictionary = kit_palette as Dictionary
		for key: Variant in kit_entries:
			if kit_entries[key] is Material:
				palette[str(key)] = kit_entries[key] as Material
	if palette.is_empty():
		push_error("KitMerge: the kit scene '%s' has no palette (%s), so no model is built." % [kit_path, KIT_PALETTE_PROPERTY])
		return palette
	for key: String in ACCENT_KEYS + ACCENT_DARK_KEYS:
		if not palette.has(key):
			push_error("KitMerge: the palette of the kit scene '%s' has no Team accent key '%s', so a part of a renamed accent key folds into the neutral parts at its kit colour." % [kit_path, key])
	return palette


## Every MeshInstance3D below node, depth first, with its transform in the kit's frame (the kit
## root's own transform left out: KitUnitModel places the model).
static func _collect(node: Node, parent_transform: Transform3D, parts: Array[MeshInstance3D],
		transforms: Array[Transform3D]) -> void:
	for child: Node in node.get_children():
		var child_transform: Transform3D = parent_transform
		if child is Node3D:
			child_transform = parent_transform * (child as Node3D).transform
		if child is MeshInstance3D:
			parts.append(child as MeshInstance3D)
			transforms.append(child_transform)
		_collect(child, child_transform, parts, transforms)


## The kit key a part folds under: by_part, the key of the part remap entry the part matched
## (_part_remap_key(), empty when none), else its material's key through key_remap; an empty string
## when its mesh is not a PrimitiveMesh or its material is not in the palette.
static func _key_of_part(part: MeshInstance3D, by_part: String,
		key_of: Dictionary[Material, String], key_remap: Dictionary[String, String]) -> String:
	if not (part.mesh is PrimitiveMesh) or not key_of.has(part.material_override):
		return ""
	if not by_part.is_empty():
		return by_part
	var key: String = key_of[part.material_override]
	return String(key_remap.get(key, key))


## The key of the part remap entry whose BoxMesh size and centre (in the kit's frame) the part
## matches within PART_TOLERANCE, or an empty string.
static func _part_remap_key(part: MeshInstance3D, part_transform: Transform3D,
		part_remap: Array[Dictionary]) -> String:
	var box: BoxMesh = part.mesh as BoxMesh
	if box == null:
		return ""
	for entry: Dictionary in part_remap:
		var size: Vector3 = entry.get(PART_SIZE, Vector3.INF)
		var at: Vector3 = entry.get(PART_AT, Vector3.INF)
		if box.size.distance_to(size) <= PART_TOLERANCE and part_transform.origin.distance_to(at) <= PART_TOLERANCE:
			return String(entry.get(PART_KEY, ""))
	return ""


## The surface a key folds into, made on first use: the accent (ACCENT_KEYS, ACCENT_DARK_KEYS), the
## key's own (APART_KEYS) or the neutral fold (every other key).
static func _surface_for(surfaces: Dictionary[String, _Surface], key: String,
		palette: Dictionary[String, Material]) -> _Surface:
	var group: String = NEUTRAL_GROUP
	if key in ACCENT_KEYS or key in ACCENT_DARK_KEYS:
		group = ACCENT_GROUP
	elif key in APART_KEYS:
		group = key
	if not surfaces.has(group):
		var surface: _Surface = _Surface.new()
		surface.tinted = group == ACCENT_GROUP or group == NEUTRAL_GROUP
		surface.material = _material_of(group, palette)
		surfaces[group] = surface
	return surfaces[group] as _Surface


## A surface group's material: for the accent a vertex-coloured one of the FALLBACK_KEY colour (the
## Unit's team_material replaces it as material_override), for the neutral fold a vertex-coloured
## one of NEUTRAL_ROUGHNESS and NEUTRAL_METALLIC, for an apart key the kit's own.
static func _material_of(group: String, palette: Dictionary[String, Material]) -> Material:
	if group != ACCENT_GROUP and group != NEUTRAL_GROUP:
		return palette[group]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if group == NEUTRAL_GROUP:
		material.roughness = NEUTRAL_ROUGHNESS
		material.metallic = NEUTRAL_METALLIC
	else:
		material.albedo_color = _colour_of(FALLBACK_KEY, palette)
	return material


## The vertex colour a part of a key gets: white for ACCENT_KEYS (and APART_KEYS, whose surfaces
## carry no colour), DARK_TONE grey for ACCENT_DARK_KEYS, the key's kit colour for the neutral fold.
static func _tone_of(key: String, palette: Dictionary[String, Material]) -> Color:
	if key in ACCENT_DARK_KEYS:
		return Color(DARK_TONE, DARK_TONE, DARK_TONE)
	if key in ACCENT_KEYS or key in APART_KEYS:
		return Color.WHITE
	return _colour_of(key, palette)


## The albedo colour of a key's kit material, or white when it has none.
static func _colour_of(key: String, palette: Dictionary[String, Material]) -> Color:
	var material: BaseMaterial3D = palette.get(key) as BaseMaterial3D
	return material.albedo_color if material != null else Color.WHITE


## Adds a part's arrays to a surface with its transform baked in: vertices by the transform,
## normals by the inverse-transpose basis, UVs as they are, the tone as the vertex colour of a
## tinted surface, indices offset past the surface's vertices.
static func _append(surface: _Surface, arrays: Array, part_transform: Transform3D, tone: Color) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var first: int = surface.vertices.size()
	var normal_basis: Basis = part_transform.basis.inverse().transposed()
	for index: int in vertices.size():
		surface.vertices.append(part_transform * vertices[index])
		surface.normals.append((normal_basis * normals[index]).normalized())
		surface.uvs.append(uvs[index])
		if surface.tinted:
			surface.colours.append(tone)
	for vertex_index: int in indices:
		surface.indices.append(first + vertex_index)


## The box of the folded vertices, every surface's, up to HULL_TOP in the kit's frame (Built.hull).
static func _hull_of(surfaces: Dictionary[String, _Surface]) -> AABB:
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	for group: String in surfaces:
		for point: Vector3 in (surfaces[group] as _Surface).vertices:
			if point.y <= HULL_TOP:
				low = low.min(point)
				high = high.max(point)
	return AABB(low, high - low)


## Turns the folded surfaces into built's two meshes: the accent group into built.accent, every
## other group into built.neutral, each surface with its material.
static func _commit(surfaces: Dictionary[String, _Surface], built: Built) -> void:
	built.accent = ArrayMesh.new()
	built.neutral = ArrayMesh.new()
	for group: String in surfaces:
		var surface: _Surface = surfaces[group] as _Surface
		var target: ArrayMesh = built.accent if group == ACCENT_GROUP else built.neutral
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_TEX_UV] = surface.uvs
		if surface.tinted:
			arrays[Mesh.ARRAY_COLOR] = surface.colours
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		target.surface_set_material(target.get_surface_count() - 1, surface.material)


## One built model: the two meshes a KitUnitModel shows and the box of its hull.
class Built:
	## The Team accent: one surface with vertex tones, painted by the Unit's team_material.
	var accent: ArrayMesh
	## The neutral parts: the vertex-coloured fold and one surface per APART_KEYS key the kit uses.
	var neutral: ArrayMesh
	## The box of the vertices up to HULL_TOP in the kit's frame, unscaled: the body without the
	## rotor and the mast (UnitModel's rise over cliffs reads its footprint and lowest point).
	var hull: AABB


## One surface being folded: its baked arrays and its material.
class _Surface:
	## Vertices in the kit's frame.
	var vertices: PackedVector3Array = PackedVector3Array()
	## Normals in the kit's frame.
	var normals: PackedVector3Array = PackedVector3Array()
	## UVs as the primitives made them.
	var uvs: PackedVector2Array = PackedVector2Array()
	## One vertex colour per vertex, on a tinted surface only.
	var colours: PackedColorArray = PackedColorArray()
	## Triangle indices into vertices.
	var indices: PackedInt32Array = PackedInt32Array()
	## The surface's material.
	var material: Material
	## Whether the vertices carry a colour: the accent and the neutral fold.
	var tinted: bool = false
