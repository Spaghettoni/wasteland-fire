class_name MeshUnitModel
extends UnitModel
## A Unit type's model drawn from a mesh file built in Blender by a script under tools/blender/
## (build_<type>.py, which writes res://assets/art/vehicles/wasteland_<type>/wasteland_<type>.glb):
## the root of motorbike_mesh_model.tscn, buggy_mesh_model.tscn, truck_mesh_model.tscn and
## gyrocopter_mesh_model.tscn, the scenes each type's UnitStats.model points at.
##
## Implements: the developer's decisions of 2026-10-10 (the Truck modelled in Blender as a test,
## judged in the game's own cameras, then kept, and the other three Units modelled the same way);
## production/epics/wasteland-fire/story-007-the-map.md AC-11 (a Unit wears its Team's colour and
## no other) and AC-12 (each type reads by its silhouette; the Motorbike's cream heading cue, a lamp
## part of its file); design/rules.md "Teams and visual style". The Gyrocopter's rise over cliffs
## and cover is UnitModel's. Vocabulary: CONTEXT.md (Unit, Team, Motorbike, Gyrocopter).
##
## The file holds three meshes, named by tools/blender/wasteland_kit.py: Accent, the Team paint;
## Neutral, the metal, rubber and cargo; and Lamp, the lamp lenses. _build_meshes() adds one
## MeshInstance3D child for each, with the materials KitMerge gives a kit model's folds, so a model
## from a mesh file and a kit model are drawn alike: Accent in Unit.TEAM_COLOUR_GROUP, which
## Unit._paint_team_colour() paints with the Unit's team_material (a vertex-coloured steel until
## then); Neutral vertex-coloured at KitMerge.NEUTRAL_ROUGHNESS and KitMerge.NEUTRAL_METALLIC; Lamp
## in the palette's glowing lamp colour. The vertex colours of the file are sRGB numbers (the
## script writes them so), read with vertex_color_is_srgb as the kit folds' are. The hull the rise
## reads is the box of the file's vertices up to hull_top (the Gyrocopter's rotor left out).
##
## The meshes and the hull are read from the file once per file and shared by every model of it
## after (_cache, _hulls): SplitScreen instances each type's model once before the Round begins.

## Name of the mesh, and of the child, that carries the lamp lenses.
const LAMP_NODE_NAME: StringName = &"Lamp"
## Roughness of the lamp lenses (the palette's lamp, assets/art/shared/wasteland_palette.gd).
const LAMP_ROUGHNESS: float = 0.3
## Glow of the lamp lenses (the palette's lamp).
const LAMP_EMISSION_ENERGY: float = 0.4

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")

## The mesh file, a .glb that holds the Accent, Neutral and Lamp meshes. Required, with no
## default: each model scene stores it.
@export var mesh_scene: PackedScene
## Vertices up to this height in the file's frame, metres, make the hull the rise reads: on the
## Gyrocopter's scene, above its body and below its rotor, whose blades reach far past the body.
## Optional: INF, the default, takes every vertex (a model that does not rise never reads it).
@export var hull_top: float = INF

## The meshes of every file read so far, by its path: mesh name -> Mesh.
static var _cache: Dictionary[String, Dictionary] = {}
## The hull of every file and hull_top read so far, by the file's path and the height.
static var _hulls: Dictionary[String, AABB] = {}
## The materials, made on first use and shared by every model.
static var _accent_fallback: StandardMaterial3D
static var _neutral: StandardMaterial3D
static var _lamp: StandardMaterial3D


## Adds the file's Accent, Neutral and (when it has one) Lamp meshes and takes the hull of its
## vertices up to hull_top; false, after an error naming the model, when there is no mesh_scene,
## the file lacks Accent or Neutral, or no vertex lies at or below hull_top.
func _build_meshes() -> bool:
	if mesh_scene == null:
		push_error("MeshUnitModel '%s': no mesh_scene, so the model is empty." % name)
		return false
	var meshes: Dictionary = meshes_of(mesh_scene)
	if not meshes.has(ACCENT_NODE_NAME) or not meshes.has(NEUTRAL_NODE_NAME):
		push_error("MeshUnitModel '%s': the mesh file '%s' has no %s or no %s mesh, so the model is empty." % [
				name, mesh_scene.resource_path, ACCENT_NODE_NAME, NEUTRAL_NODE_NAME])
		return false
	var hull: AABB = hull_of(mesh_scene, hull_top)
	if not hull.has_volume():
		push_error("MeshUnitModel '%s': no vertex of the mesh file '%s' lies at or below hull_top %.2f, so the model is empty." % [
				name, mesh_scene.resource_path, hull_top])
		return false
	_add_mesh(ACCENT_NODE_NAME, meshes[ACCENT_NODE_NAME], true, _accent_material())
	_add_mesh(NEUTRAL_NODE_NAME, meshes[NEUTRAL_NODE_NAME], false, _neutral_material())
	if meshes.has(LAMP_NODE_NAME):
		_add_mesh(LAMP_NODE_NAME, meshes[LAMP_NODE_NAME], false, _lamp_material())
	_hull = hull
	return true


## The meshes of a mesh file by name (each MeshInstance3D of the file's scene under the name of
## its node), read the first time the file is asked for and cached: the scene is instanced, read
## and freed once.
static func meshes_of(file: PackedScene) -> Dictionary:
	if _cache.has(file.resource_path):
		return _cache[file.resource_path]
	var meshes: Dictionary = {}
	var root: Node = file.instantiate()
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance != null and instance.mesh != null:
			meshes[StringName(instance.name)] = instance.mesh
	root.free()
	_cache[file.resource_path] = meshes
	return meshes


## The box of every vertex of a mesh file's meshes (meshes_of()) at or below top, in the file's
## frame, read the first time the file and the height are asked for and cached; a box with no
## volume when no vertex qualifies.
static func hull_of(file: PackedScene, top: float) -> AABB:
	var key: String = "%s|%s" % [file.resource_path, top]
	if _hulls.has(key):
		return _hulls[key]
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	var meshes: Dictionary = meshes_of(file)
	for mesh_name: StringName in meshes:
		var mesh: Mesh = meshes[mesh_name]
		for surface: int in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in vertices:
				if point.y <= top:
					low = low.min(point)
					high = high.max(point)
	var hull: AABB = AABB(low, high - low) if low.x <= high.x else AABB()
	_hulls[key] = hull
	return hull


## A vertex-coloured material: the vertex colours are sRGB numbers, multiplied into albedo.
static func _vertex_coloured(albedo: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = albedo
	return material


## The Accent's own material, seen only on a Unit with no team_material: a neutral steel, never
## white and never a Team colour (as KitMerge's accent fold).
static func _accent_material() -> StandardMaterial3D:
	if _accent_fallback == null:
		_accent_fallback = _vertex_coloured(Palette.STEEL)
	return _accent_fallback


## The Neutral's material: its vertex colours at the kit folds' roughness and metallic.
static func _neutral_material() -> StandardMaterial3D:
	if _neutral == null:
		_neutral = _vertex_coloured(Color.WHITE)
		_neutral.roughness = KitMerge.NEUTRAL_ROUGHNESS
		_neutral.metallic = KitMerge.NEUTRAL_METALLIC
	return _neutral


## The Lamp's material: the palette's lamp colour, glowing.
static func _lamp_material() -> StandardMaterial3D:
	if _lamp == null:
		_lamp = StandardMaterial3D.new()
		_lamp.albedo_color = Palette.LAMP
		_lamp.roughness = LAMP_ROUGHNESS
		_lamp.emission_enabled = true
		_lamp.emission = Palette.LAMP
		_lamp.emission_energy_multiplier = LAMP_EMISSION_ENERGY
	return _lamp
