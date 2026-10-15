extends RefCounted
## How the Fuel zones are drawn in the Story 023 scenario fuel_building, AC-2 (the look): each zone's marking is a flat amber box as large as the
## zone, its top at least 10 mm over everything it lies on (the depot's ring dashes at 0.02 m, the salt flat at 0.01 m), casting no shadow, on
## render layer 1; edged with dashes like the depot's ring (the ring's own dark colour), all sharing one mesh and one material, every one inside
## the footprint and 10 mm over the slab; both zones share the same meshes; and in both Players' views and both of each Player's camera views
## the camera draws that layer and the zone is on the screen. The frames themselves are the showcase's. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-023-fuel-building.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

## The camera keys of the two Players (project.godot: p1_camera, p2_camera).
const CAMERA_KEYS: Array[Key] = [KEY_Q, KEY_SLASH]
## The least a drawn flat surface stands over the one it lies on, metres (Story 014's 10 mm).
const OVER_BY: float = 0.01
## Ticks the camera is given to settle after it is stepped to another view.
const VIEW_TICKS: int = 150
## The most steps of the camera key a view may take.
const MOST_STEPS: int = 4
## A tolerance on a drawn height, metres.
const HEIGHT_SLACK: float = 1.0e-6

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	_the_marking()
	await _in_both_views()


## The albedo of a mesh instance's mesh surface material.
func _albedo(mesh: Mesh) -> Color:
	return (mesh.surface_get_material(0) as StandardMaterial3D).albedo_color if mesh.surface_get_material(0) != null else (mesh.get("material") as StandardMaterial3D).albedo_color


func _the_marking() -> void:
	var problems: PackedStringArray = []
	var amber: Color = ((_k.fuel_bar(0).get_theme_stylebox("fill") as StyleBoxFlat).bg_color)
	var ring: MeshInstance3D = _q.map.find("Depot/RingMarking/Dash01") as MeshInstance3D
	var flat: MeshInstance3D = _q.map.find("Terrain/SaltFlat") as MeshInstance3D
	var floor_tops: float = maxf(ring.global_position.y, flat.global_position.y)
	var dash_total: int = 0
	var slab_tops: PackedFloat64Array = []
	for side: int in 2:
		var zone: SupplyZone = _k.zone(side)
		var slab: MeshInstance3D = zone.slab as MeshInstance3D
		var box: BoxMesh = slab.mesh as BoxMesh
		var scale: Vector3 = slab.global_transform.basis.get_scale()
		var top: float = slab.global_position.y + box.size.y / 2.0 * scale.y
		slab_tops.append(top)
		_q.kit.need(problems, slab.get_parent().get_parent() == zone, "zone %d: the slab is not under the zone's Marking" % side)
		_q.kit.need(problems, top >= floor_tops + OVER_BY - HEIGHT_SLACK, "zone %d: the slab's top is %.4f m up, over the ring dashes at %.2f and the salt flat at %.2f" % [side, top, ring.global_position.y, flat.global_position.y])
		_q.kit.need(problems, absf(scale.x * box.size.x - zone.size.x) < HEIGHT_SLACK and absf(scale.z * box.size.z - zone.size.z) < HEIGHT_SLACK, "zone %d: the slab is %.3f by %.3f m, the zone %.1f by %.1f" % [side, scale.x * box.size.x, scale.z * box.size.z, zone.size.x, zone.size.z])
		_q.kit.need(problems, slab.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and slab.layers == 1, "zone %d: the slab casts shadows (%d) or is on layers %d" % [side, slab.cast_shadow, slab.layers])
		_q.kit.need(problems, _albedo(box).is_equal_approx(amber), "zone %d: the slab is %s, the Fuel bar %s" % [side, _albedo(box), amber])
		var dashes: Array[Node] = zone.edge.get_children()
		var expected: int = 2 * maxi(roundi(zone.size.x / zone.edge_pitch), 1) + 2 * maxi(roundi(zone.size.z / zone.edge_pitch), 1)
		_q.kit.need(problems, dashes.size() == expected, "zone %d: %d dashes, expected %d" % [side, dashes.size(), expected])
		dash_total += dashes.size()
		for node: Node in dashes:
			var dash: MeshInstance3D = node as MeshInstance3D
			var area: AABB = dash.global_transform * dash.mesh.get_aabb()
			var centre: Vector3 = _k.centre(side)
			_q.kit.need(problems, dash.mesh == zone.edge_dash and dash.mesh == _k.zone(0).edge_dash, "zone %d: a dash has a mesh of its own" % side)
			_q.kit.need(problems, dash.global_position.y >= top + OVER_BY - HEIGHT_SLACK, "zone %d: a dash is %.4f m up, the slab's top %.4f" % [side, dash.global_position.y, top])
			_q.kit.need(problems, dash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and dash.layers == 1, "zone %d: a dash casts shadows or is on layers %d" % [side, dash.layers])
			_q.kit.need(problems, area.position.x >= centre.x - zone.size.x / 2.0 - HEIGHT_SLACK and area.end.x <= centre.x + zone.size.x / 2.0 + HEIGHT_SLACK and area.position.z >= centre.z - zone.size.z / 2.0 - HEIGHT_SLACK and area.end.z <= centre.z + zone.size.z / 2.0 + HEIGHT_SLACK, "zone %d: a dash reaches outside the footprint (%s)" % [side, area])
		_q.kit.need(problems, _albedo(zone.edge_dash).is_equal_approx(_albedo(ring.mesh)), "zone %d: the dashes are %s, the depot's ring %s" % [side, _albedo(zone.edge_dash), _albedo(ring.mesh)])
	_q.kit.need(problems, (_k.zone(0).slab as MeshInstance3D).mesh == (_k.zone(1).slab as MeshInstance3D).mesh, "the two slabs do not share one mesh")
	measured.append("marking=slab_top_%.3f_dashes_%d" % [slab_tops[0], dash_total])
	_q.kit.verdict("marking_is_drawn_on_the_ground", problems, "each zone's slab is its 6 x 6 m footprint in the Fuel bar's amber %s, its top %.3f m up (the depot's ring dashes %.2f m, the salt flat %.2f m), no shadow, layer 1; %d dashes in the ring's dark colour %s share one mesh, all inside the footprint and at least 10 mm over the slab; the two zones share their meshes" % [amber, slab_tops[0], ring.global_position.y, flat.global_position.y, dash_total, _albedo(_k.zone(0).edge_dash)])


## Each Player in the zone on its side, its camera stepped to each of its views with the real camera key: the camera draws the marking's
## layer, the middle of the zone is on the screen, and in the view from above so are its four corners.
func _in_both_views() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	await _k.put(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 1.0)
	await _k.put(1, Quick.TRUCK, _k.centre(1), Vector3.LEFT, 1.0)
	for player: int in 2:
		var camera: ChaseCamera = _q.units.cameras[player]
		var input: PlayerCameraInput = _camera_input(player)
		var views: Array[ChaseCameraSettings] = input.views
		for wanted: ChaseCameraSettings in views:
			var steps: int = 0
			while camera.settings != wanted and steps < MOST_STEPS:
				await _q.kit.press_settled([CAMERA_KEYS[player]] as Array[Key])
				steps += 1
			await _q.kit.advance(VIEW_TICKS)
			var above: bool = wanted.distance > 0.0
			var zone: SupplyZone = _k.zone(player)
			var rect: Rect2 = camera.get_viewport().get_visible_rect()
			var points: Array[Vector3] = [_k.centre(player) + Vector3.UP * (zone.slab as Node3D).global_position.y]
			if above:
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					points.append(_k.centre(player) + Vector3(corner.x * zone.size.x / 2.0, (zone.slab as Node3D).global_position.y, corner.y * zone.size.z / 2.0))
			var on_screen: int = 0
			for point: Vector3 in points:
				on_screen += 1 if rect.has_point(camera.unproject_position(point)) and not camera.is_position_behind(point) else 0
			_q.kit.need(problems, camera.settings == wanted and (camera.cull_mask & (zone.slab as MeshInstance3D).layers) != 0, "P%d %s view: the camera draws mask %d against layers %d (settings %s)" % [player + 1, "above" if above else "chase", camera.cull_mask, (zone.slab as MeshInstance3D).layers, camera.settings == wanted])
			_q.kit.need(problems, on_screen == points.size(), "P%d %s view: %d of %d points of the zone are on the screen" % [player + 1, "above" if above else "chase", on_screen, points.size()])
			seen.append("P%d %s %d/%d" % [player + 1, "above" if above else "chase", on_screen, points.size()])
	measured.append("views=%s" % ";".join(seen))
	_q.kit.verdict("zone_is_seen_in_both_players_views", problems, "with each Player's Truck stopped in the zone on its side, in every view of each camera (%s) the camera draws the marking's render layer and the points of the zone are on the screen" % ", ".join(seen))
	await _k.park(0)
	await _k.park(1)


## The PlayerCameraInput of a Player: the node in the world that holds its list of views.
func _camera_input(player: int) -> PlayerCameraInput:
	for node: Node in _q.harness.split.find_children("*", "PlayerCameraInput", true, false):
		if (node as PlayerCameraInput).camera == _q.units.cameras[player]:
			return node as PlayerCameraInput
	return null
