class_name PropMultiMesh
extends MultiMeshInstance3D
## Many copies of one piece of the Map drawn from a mesh file built in Blender by a script under
## tools/blender/: Map 01's tyre stacks, boulders and depot posts (map_01_dressing.tscn), each copy
## where its MultiMesh puts it.
##
## Implements: the developer's request of 2026-10-10 ("models for the rocks, walls and other
## objects"); production/qa/evidence/map-art-2026-10-10-evidence.md. Vocabulary: CONTEXT.md (Map).
##
## _ready() gives the node's MultiMesh the mesh named mesh_name from mesh_file
## (MeshFile.meshes_of(), read once per file); the copies' transforms stay the scene's. The scene
## gives the node its material (material_override, a vertex-coloured material or shader). Only what
## is drawn.

## The mesh file, a .glb that holds the mesh named mesh_name. Required, with no default.
@export var mesh_file: PackedScene
## The name of the mesh in mesh_file (the Blender object's name). Required, with no default.
@export var mesh_name: StringName


func _ready() -> void:
	if mesh_file == null or multimesh == null:
		push_error("PropMultiMesh '%s': no mesh_file or no multimesh, so nothing is drawn." % name)
		return
	var meshes: Dictionary = MeshFile.meshes_of(mesh_file)
	if not meshes.has(mesh_name):
		push_error("PropMultiMesh '%s': the mesh file '%s' has no mesh '%s', so nothing is drawn." % [
				name, mesh_file.resource_path, mesh_name])
		return
	multimesh.mesh = meshes[mesh_name]
