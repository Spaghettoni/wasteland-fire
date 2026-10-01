## Static helpers for kitbashing models out of engine primitives.
##
## Each builder adds one MeshInstance3D under [param parent] with the given
## material, position and rotation (in degrees) and returns it, so a model is a
## readable list of parts rather than a wall of node setup.
extends RefCounted


## Flat, matte-by-default material. With [param tex] the texture is applied
## triplanar in world space at [param tex_scale] repeats per metre, so every
## part shares one texel density whatever its UVs.
static func flat_material(albedo: Color, roughness: float, metallic: float,
		tex: Texture2D = null, tex_scale: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * tex_scale
	return m


## Empty, named Node3D under [param parent] for grouping parts.
static func group(parent: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


## Axis-aligned box of [param size] centred at [param pos].
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return place(parent, mesh, pos, mat, rot)


## Cylinder with its axis along local Y; rotate to orient it.
static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material, rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return place(parent, mesh, pos, mat, rot)


## Cone whose tip points along local +Y; rotate to aim it.
static func cone(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return place(parent, mesh, pos, mat, rot)


## Flat quad decal of [param size], facing local +Z; rotate it onto a panel and
## sit it a few millimetres proud of the surface.
static func decal(parent: Node3D, size: Vector2, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := place(parent, mesh, pos, mat, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Cylinder run from [param from] to [param to], for tube frames and cages.
static func tube(parent: Node3D, from: Vector3, to: Vector3, radius: float,
		mat: Material, segments: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	# looking_at points local -Z along the run; the extra quarter turn brings
	# the cylinder's Y axis onto it.
	var basis := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI / 2.0)
	mi.transform = Transform3D(basis, (from + to) * 0.5)
	parent.add_child(mi)
	return mi


## Low-poly torus with its axis along local Y; a tyre when rotated onto X.
static func torus(parent: Node3D, inner_radius: float, outer_radius: float, pos: Vector3,
		mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 10
	return place(parent, mesh, pos, mat, rot)


## Low-poly sphere, optionally squashed by [param scale].
static func ball(parent: Node3D, radius: float, pos: Vector3, mat: Material,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	var mi := place(parent, mesh, pos, mat, Vector3.ZERO)
	mi.scale = scale
	return mi


## Adds any [param mesh] as a MeshInstance3D and returns it.
static func place(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material,
		rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi
