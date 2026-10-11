class_name PropMesh
extends MeshInstance3D
## A piece of the Map drawn from a mesh file built in Blender by a script under tools/blender/: the
## rocks over Map 01's cliffs (map_01_cliffs.tscn's RockLooks), and the other pieces modelled since
## 2026-10-10.
##
## Implements: the developer's request of 2026-10-10 ("models for the rocks, walls and other
## objects"); production/qa/evidence/map-art-2026-10-10-evidence.md; design/rules.md "Teams and
## visual style". Vocabulary: CONTEXT.md (Map).
##
## _ready() takes the mesh named mesh_name from mesh_file (MeshFile.meshes_of(), read once per file)
## as its mesh. The scene gives the node its material (material_override: a vertex-coloured material
## or shader, since the files carry their colours as vertex colours), or a Base paints it with its
## Team colour, as before. Only what is drawn: whatever collides stays the scene's own collider, and
## a mesh built to that collider draws the same box (the evidence measures them against each other).

## The mesh file, a .glb that holds the mesh named mesh_name. Required, with no default: each scene
## that uses one stores it.
@export var mesh_file: PackedScene
## The name of the mesh in mesh_file (the Blender object's name). Required, with no default.
@export var mesh_name: StringName


func _ready() -> void:
	if mesh_file == null:
		push_error("PropMesh '%s': no mesh_file, so nothing is drawn." % name)
		return
	var meshes: Dictionary = MeshFile.meshes_of(mesh_file)
	if not meshes.has(mesh_name):
		push_error("PropMesh '%s': the mesh file '%s' has no mesh '%s', so nothing is drawn." % [
				name, mesh_file.resource_path, mesh_name])
		return
	mesh = meshes[mesh_name]
