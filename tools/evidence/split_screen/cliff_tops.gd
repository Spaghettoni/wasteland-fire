extends RefCounted
## Scenario cliff_tops of the split screen evidence harness (split_screen_harness.gd): every rock of Map 01 is drawn with a
## top facing up (Story 037). RidgeWest's top was built facing down, so Godot culled it and the ridge looked hollow from
## above. CHECK lines:
##  C1 the tops: for each of the five rock meshes of map_01_rocks.glb, the area of its faces that face up (front side, normal
##     within 25 degrees of up) against the area of its collider's outline: at least TOP_SHARE of it, and the area facing
##     down under DOWN_SHARE of it.
##  C2 the mirror: RidgeWest and RidgeEast, mirror images in the outline, have up-facing areas within MIRROR_TOLERANCE.
## Implements: production/epics/wasteland-fire/story-037-cliff-top-and-turret-sight.md AC-1 and AC-2.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=cliff_tops

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

const OWN_CHOICE: bool = true
## The cliffs scene: its CSG colliders and its looks.
const CLIFFS_PATH: String = "res://src/gameplay/maps/map_01/map_01_cliffs.tscn"
## A face whose normal is within this of straight up faces up (cos 25 degrees).
const UP_COS: float = 0.9
## The share of the outline's area the up-facing faces must cover.
const TOP_SHARE: float = 0.8
## The largest share of the outline's area that may face down.
const DOWN_SHARE: float = 0.1
## Mirror images may differ in top area by this share.
const MIRROR_TOLERANCE: float = 0.05

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var cliffs: Node = (load(CLIFFS_PATH) as PackedScene).instantiate()
	_h.add_child(cliffs)
	await _kit.advance(1)
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	var tops: Dictionary = {}
	for look: MeshInstance3D in cliffs.get_node("RockLooks").get_children():
		var collider: CSGPolygon3D = cliffs.get_node(NodePath(String(look.name))) as CSGPolygon3D
		var outline: float = _polygon_area(collider.polygon)
		var areas: Vector2 = _up_down(look.mesh)
		tops[look.name] = areas.x
		lines.append("%s outline %.0f m2, up %.0f, down %.0f" % [look.name, outline, areas.x, areas.y])
		_kit.need(problems, areas.x >= outline * TOP_SHARE, "%s faces up over %.0f of %.0f m2" % [look.name, areas.x, outline])
		_kit.need(problems, areas.y <= outline * DOWN_SHARE, "%s faces down over %.0f m2" % [look.name, areas.y])
	_kit.verdict("C1_tops", problems, "; ".join(lines))
	var mirror: PackedStringArray = PackedStringArray()
	var west: float = tops.get(&"RidgeWest", 0.0)
	var east: float = tops.get(&"RidgeEast", 0.0)
	_kit.need(mirror, east > 0.0 and absf(west - east) <= east * MIRROR_TOLERANCE, "RidgeWest %.0f against RidgeEast %.0f" % [west, east])
	_kit.verdict("C2_mirror", mirror, "RidgeWest up %.0f m2, RidgeEast %.0f m2" % [west, east])
	cliffs.queue_free()
	_h.finish("rocks=%d" % tops.size())


func _polygon_area(points: PackedVector2Array) -> float:
	var twice: float = 0.0
	for index: int in points.size():
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		twice += a.x * b.y - b.x * a.y
	return absf(twice) * 0.5


## The area of the mesh's front faces that face up, and of those that face down. Godot's front faces wind clockwise, so a
## front face's normal is -(b - a).cross(c - a).
func _up_down(mesh: Mesh) -> Vector2:
	var up: float = 0.0
	var down: float = 0.0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for tri: int in indices.size() / 3:
			var a: Vector3 = vertices[indices[3 * tri]]
			var face: Vector3 = -(vertices[indices[3 * tri + 1]] - a).cross(vertices[indices[3 * tri + 2]] - a)
			var area: float = face.length() * 0.5
			if area <= 0.0:
				continue
			var y: float = face.normalized().y
			if y >= UP_COS:
				up += area
			elif y <= -UP_COS:
				down += area
	return Vector2(up, down)
