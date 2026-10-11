class_name MeshFile
extends RefCounted
## The meshes of a mesh file built in Blender (a .glb under assets/art/, written by a script under
## tools/blender/), read once per file and shared by everything that draws it after: the Units'
## MeshUnitModel and the Map's PropMesh read their meshes here.
##
## Implements: the developer's decisions of 2026-10-10 (the Units, then the Map's rocks, walls and
## other objects, modelled in Blender); production/qa/evidence/blender-units-2026-10-10-evidence.md
## and map-art-2026-10-10-evidence.md.
##
## A file's scene is instanced, read and freed the first time the file is asked for: each
## MeshInstance3D of it gives its mesh under the name of its node (Blender's object name). The
## meshes are never written after, so every model and prop of a file shares them.

## The meshes of every file read so far, by its path: mesh name -> Mesh.
static var _cache: Dictionary[String, Dictionary] = {}


## The meshes of a mesh file by name, read the first time the file is asked for and cached.
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
