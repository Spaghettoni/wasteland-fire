extends RefCounted
## The band the turning parts sweep, for the rotors scenario (Story 025 AC-5): band (the highest and lowest drawn points of the
## rotor and of the propeller over a full turn, in the mesh file's frame and in the world at the flying height, against the
## numbers the Blender script's tilt and coning give, and the rotor's highest point under the water towers' platforms) and
## sweep (how far the swept rotor reaches into a water tower's legs when the body is centred between them, against the 0.416 m
## the story of the Heights recorded at rest, and the least distance between each swept part and the model's frame: the
## propeller's blades and the keel, the rotor's blades and the fin and the propeller, and each against the whole frame). The
## swept volume of a part is a surface of revolution about its axis, so a body point is judged by its distance along the axis and
## from it (the part's envelope, sampled from the blades' own triangles). Run by rotors.gd. Tooling only. Every number comes from the
## game's meshes and data; the scenario types only its test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The constants of tools/blender/build_gyrocopter.py the swept heights are checked against: the rotor's radius, tilt and coning.
const ROTOR_RADIUS: float = 2.3
const ROTOR_TILT_DEGREES: float = 6.0
const ROTOR_CONING_DEGREES: float = 2.5
## The story of the Heights recorded the rotor's span 0.416 m into a water tower's legs at rest (design/rules.md, Heights).
const RECORD_REACH: float = 0.416
## The poses of a turn (a degree each) and of the finer sweep of the tips (a quarter of a degree).
const POSES: int = 360
const TIP_POSES: int = 1440
## What a swept height may differ from the number the script's angles give by (the blades are boxes with a thickness), metres.
const HEIGHT_TOLERANCE: float = 0.02
## The spacing of the points sampled on a triangle, metres, the width of an envelope's bins, and how far from a part's reach and
## from its plane a body triangle must have a vertex to be sampled.
const SPACING: float = 0.01
const BIN: float = 0.02
const NEAR: float = 1.0
## The share of a part's longest reach a vertex must have to be a tip, and the radius under which a part's mesh is its hub (the
## propeller's hub cylinder and spinner are 0.07 m in radius and turn into themselves, so they sweep nothing new).
const TIP_SHARE: float = 0.98
const HUB_RADIUS: float = 0.075
## The least gap the story's check accepts between a swept part and the frame, metres (a millimetre: nothing is drawn through).
const MIN_GAP: float = 0.001
## The tubes under the propeller's hub, in the mesh file's frame: how far from the axis of the Gyrocopter a point may stand to belong
## to a tube (the keel's and the brace's radii are 0.035 and 0.024, the pylon's half width 0.05), the height of the keel's top and
## of the brace's top where they cross the propeller's plane, and the story's number for the keel (about 3 cm, from the script's
## constants), with what the measure may differ from it by.
const TUBE_HALF_WIDTH: float = 0.04
const KEEL_TOP: float = 0.376
const BRACE_TOP: float = 0.6
const KEEL_RECORD: float = 0.0235
const KEEL_SLACK: float = 0.01
## An overlap of a swept blade with the thin brace that is called a graze: under 2 cm (the question for the author is whether to
## thin the brace).
const BRACE_GRAZE: float = 0.02
## Where the rotor's fin begins in the file's frame: its points are at least this far back, up and near the Gyrocopter's axis.
const FIN_FROM_Z: float = 0.9
const FIN_FROM_Y: float = 0.9
const FIN_HALF_WIDTH: float = 0.05

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick
var _settings: RotorSettings
var _file: PackedScene
## The point of the last _gap() that stood closest to the envelope, in the mesh file's frame.
var _closest: Vector3 = Vector3.ZERO


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()
	_settings = kit.settings()
	_file = load(Kit25.MESH_FILE_PATH) as PackedScene


## The checks, in order. A coroutine: await it.
func run() -> void:
	_band()
	await _sweep()


## The vertices of a part's two meshes.
func _part_vertices(part: RotorPart) -> PackedVector3Array:
	var found: PackedVector3Array = Kit25.vertices_of(Kit25.mesh_in(_file, part.accent_mesh))
	found.append_array(Kit25.vertices_of(Kit25.mesh_in(_file, part.neutral_mesh)))
	return found


## The lowest and highest y of a set of points over a full turn about a part's axis, a degree at a time: Vector2(low, high).
func _swept_heights(part: RotorPart, points: PackedVector3Array) -> Vector2:
	var axis: Vector3 = part.axis_direction()
	var low: float = INF
	var high: float = -INF
	for pose: int in POSES:
		var basis: Basis = Basis(axis, TAU * pose / POSES)
		for point: Vector3 in points:
			var y: float = (part.hub + basis * (point - part.hub)).y
			low = minf(low, y)
			high = maxf(high, y)
	return Vector2(low, high)


## band (AC-5): see the class doc.
func _band() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var model: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	var lift: float = model.hover_height + model.offset.y
	model.free()
	var rest: AABB = MeshUnitModel.hull_of(_file, INF)
	var rotor: RotorPart = _settings.parts[0]
	var propeller: RotorPart = _settings.parts[1]
	var tilt: float = deg_to_rad(ROTOR_TILT_DEGREES)
	var coning: float = deg_to_rad(ROTOR_CONING_DEGREES)
	var hub_y: float = rotor.hub.y
	var up_front: float = hub_y + ROTOR_RADIUS * sin(tilt + coning)
	var up_back: float = hub_y + ROTOR_RADIUS * sin(coning - tilt)
	var swept: Vector2 = _swept_heights(rotor, Kit25.vertices_of(Kit25.mesh_in(_file, rotor.accent_mesh)))
	var swept_all: Vector2 = _swept_heights(rotor, _part_vertices(rotor))
	var swept_prop: Vector2 = _swept_heights(propeller, _part_vertices(propeller))
	_q.kit.need(problems, absf(swept.y - up_front) <= HEIGHT_TOLERANCE and absf(swept.x - up_back) <= HEIGHT_TOLERANCE, "the blades sweep %.4f to %.4f m in the file's frame, the script's tilt and coning give %.4f (front) and %.4f (back)" % [swept.x, swept.y, up_front, up_back])
	_q.kit.need(problems, swept_all.y >= rest.end.y - 0.000001 and swept.y >= rest.end.y - 0.000001, "the swept top (%.4f) is under the rest pose's top %.4f" % [swept_all.y, rest.end.y])
	var platform: float = INF
	for base_index: int in Kit25.Kit.PLAYERS:
		var mesh: MeshInstance3D = _k.k.flags().bases[base_index].get_node("WaterTower/Platform") as MeshInstance3D
		platform = minf(platform, (mesh.global_transform * mesh.get_aabb()).position.y)
	var top_world: float = lift + swept_all.y
	_q.kit.need(problems, top_world < platform, "the swept rotor's top (%.4f m up) is not under the water towers' platforms (%.4f m)" % [top_world, platform])
	var frame_top: float = lift + _frame_top()
	var flying: float = lift + rest.position.y
	_q.kit.need(problems, swept_prop.x >= rest.position.y - 0.000001 and lift + swept_prop.y < top_world and flying > 0.0, "the propeller sweeps %.4f to %.4f m in the file's frame" % [swept_prop.x, swept_prop.y])
	notes.append("the rotor's blades sweep %.4f to %.4f m in the file's frame (the script's tilt and coning: %.4f and %.4f; at rest the top is %.4f), so %.4f to %.4f m in the world at the flying height, the whole rotor %.4f to %.4f m; the propeller sweeps %.4f to %.4f m in the file's frame (%.4f to %.4f m in the world); the lowest platform is %.4f m up, %.4f m over the swept rotor's top; the frame under the rotor tops out at %.4f m" % [swept.x, swept.y, up_back, up_front, rest.end.y, lift + swept.x, lift + swept.y, lift + swept_all.x, top_world, swept_prop.x, swept_prop.y, lift + swept_prop.x, lift + swept_prop.y, platform, platform - top_world, frame_top])
	measured.append("rotor_swept_top=%.4f rotor_swept_low=%.4f propeller_swept_top=%.4f" % [swept.y, swept.x, swept_prop.y])
	_q.kit.verdict("band", problems, "over a full turn the drawn band of the Gyrocopter's turning parts is: %s" % notes[0])


## The highest vertex of the body's two meshes (the Accent and the Neutral), in the file's frame, that is not on the mast's line
## under the rotor: just the highest of all, the mast's.
func _frame_top() -> float:
	var top: float = -INF
	for mesh_name: StringName in [&"Accent", &"Neutral"]:
		for point: Vector3 in Kit25.vertices_of(Kit25.mesh_in(_file, mesh_name)):
			top = maxf(top, point.y)
	return top


## The points of a mesh's triangles at SPACING, for the triangles `keep` accepts (it is given the three vertices): each triangle
## sampled on a grid of its own barycentric coordinates, its corners and edges included.
func _surface(mesh: Mesh, keep: Callable) -> PackedVector3Array:
	var found: PackedVector3Array = PackedVector3Array()
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for corner: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[corner]]
			var b: Vector3 = vertices[indices[corner + 1]]
			var c: Vector3 = vertices[indices[corner + 2]]
			if not bool(keep.call(a, b, c)):
				continue
			var steps: int = maxi(1, ceili(maxf((b - a).length(), maxf((c - b).length(), (a - c).length())) / SPACING))
			for i: int in steps + 1:
				for j: int in steps + 1 - i:
					found.append(a + (b - a) * (float(i) / steps) + (c - a) * (float(j) / steps))
	return found


## A part's envelope from points on its blades: for each radial bin of BIN metres from the axis, the lowest and highest distance
## along the axis from the hub's plane that a point in the bin has: {low, high} (INF and -INF where the bin holds no point), the
## number of bins, and the last bin that holds a point (the blades' tips' end).
func _envelope(part: RotorPart, points: PackedVector3Array, from_radius: float) -> Dictionary:
	var axis: Vector3 = part.axis_direction()
	var bins: int = ceili((part.smear_reach + BIN) / BIN) + 1
	var low: PackedFloat64Array = PackedFloat64Array()
	var high: PackedFloat64Array = PackedFloat64Array()
	low.resize(bins)
	high.resize(bins)
	low.fill(INF)
	high.fill(-INF)
	var last: int = 0
	var reach: float = 0.0
	for point: Vector3 in points:
		var read: Vector2 = Kit25.about(point, part.hub, axis)
		if read.y < from_radius:
			continue
		var bin: int = int(read.y / BIN)
		if bin < bins:
			low[bin] = minf(low[bin], read.x)
			high[bin] = maxf(high[bin], read.x)
			last = maxi(last, bin)
			reach = maxf(reach, read.y)
	return {"low": low, "high": high, "bins": bins, "last": last, "reach": reach}


## The least gap between a set of points and a part's envelope, metres, and the number judged: Vector2(least gap, points judged).
## A point whose radial bin holds the blades is judged along the axis: its distance from the blades' slab there (negative: it
## lies inside the slab, by the distance to the nearer face). A point out past the blades' tips is judged by its distance from the
## tips' end: along the radius and the axis together. A point inside the hub's radius is not judged. The point that gave the least
## gap is left in _closest.
func _gap(part: RotorPart, envelope: Dictionary, points: PackedVector3Array) -> Vector2:
	var axis: Vector3 = part.axis_direction()
	var low: PackedFloat64Array = envelope["low"]
	var high: PackedFloat64Array = envelope["high"]
	var last: int = int(envelope["last"])
	var reach: float = float(envelope["reach"])
	var least: float = INF
	var judged: int = 0
	for point: Vector3 in points:
		var read: Vector2 = Kit25.about(point, part.hub, axis)
		var bin: int = int(read.y / BIN)
		var gap: float = INF
		if bin < int(envelope["bins"]) and low[bin] != INF:
			gap = maxf(low[bin] - read.x, read.x - high[bin])
		elif read.y > reach:
			gap = Vector2(read.y - reach, maxf(0.0, maxf(low[last] - read.x, read.x - high[last]))).length()
		if gap == INF:
			continue
		judged += 1
		if gap < least:
			least = gap
			_closest = point
	return Vector2(least, judged)


## Whether any vertex of a triangle is within NEAR metres of a part's plane and of its reach (the triangle is worth sampling).
func _near(part: RotorPart) -> Callable:
	var axis: Vector3 = part.axis_direction()
	var hub: Vector3 = part.hub
	var reach: float = part.smear_reach + NEAR
	return func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		for point: Vector3 in [a, b, c]:
			var read: Vector2 = Kit25.about(point, hub, axis)
			if absf(read.x) <= NEAR and read.y <= reach:
				return true
		return false


## sweep (AC-5): see the class doc.
func _sweep() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var rotor: RotorPart = _settings.parts[0]
	var propeller: RotorPart = _settings.parts[1]
	var rest: AABB = MeshUnitModel.hull_of(_file, INF)
	# The legs: the half-width the rotor must stay inside to touch none, from the legs' inner faces on the Base's axis.
	var base: Base = _k.k.flags().bases[0]
	var to_base: Transform3D = base.global_transform.affine_inverse()
	var inner: float = INF
	var leg_text: PackedStringArray = []
	for leg_name: String in ["LegGateLeft", "LegGateRight", "LegGarageLeft", "LegGarageRight"]:
		var shape_node: CollisionShape3D = base.get_node("WaterTower/%s/CollisionShape3D" % leg_name) as CollisionShape3D
		var box: AABB = to_base * (shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb())
		var face: float = box.end.x if box.get_center().x < 0.0 else box.position.x
		inner = minf(inner, absf(face))
		leg_text.append("%s x %.3f to %.3f" % [leg_name, box.position.x, box.end.x])
	var tips: PackedVector3Array = PackedVector3Array()
	var blades: PackedVector3Array = Kit25.vertices_of(Kit25.mesh_in(_file, rotor.accent_mesh))
	var reach: float = 0.0
	for point: Vector3 in blades:
		reach = maxf(reach, Kit25.about(point, rotor.hub, rotor.axis_direction()).y)
	for point: Vector3 in blades:
		if Kit25.about(point, rotor.hub, rotor.axis_direction()).y >= reach * TIP_SHARE:
			tips.append(point)
	var half: float = 0.0
	for pose: int in TIP_POSES:
		var basis: Basis = Basis(rotor.axis_direction(), TAU * pose / TIP_POSES)
		for tip: Vector3 in tips:
			half = maxf(half, absf((rotor.hub + basis * (tip - rotor.hub)).x - rotor.hub.x))
	var rest_reach: float = rest.end.x - inner
	var swept_reach: float = half - inner
	_q.kit.need(problems, absf(rest_reach - RECORD_REACH) <= 0.001, "at rest the rotor's span reaches %.4f m into the legs (inner faces at %.3f m), the story of the Heights recorded %.3f m" % [rest_reach, inner, RECORD_REACH])
	_q.kit.need(problems, swept_reach >= rest_reach and swept_reach < half, "the swept rotor reaches %.4f m into the legs, %.4f m at rest" % [swept_reach, rest_reach])
	notes.append("with the body centred between a water tower's legs (inner faces %.3f m from its axis: %s) the rotor's blades reach %.4f m into them at rest (the %.3f m of the story of the Heights) and %.4f m over a full turn (their half-width %.4f m, which is the blades' tips' reach of %.4f m about a hub on the axis)" % [inner, "; ".join(leg_text), rest_reach, RECORD_REACH, swept_reach, half, reach])
	measured.append("legs_reach_rest=%.4f legs_reach_swept=%.4f" % [rest_reach, swept_reach])
	# The frame: the body's two meshes sampled where a part sweeps.
	var body: Dictionary = {}
	for part: RotorPart in [rotor, propeller]:
		var points: PackedVector3Array = PackedVector3Array()
		for mesh_name: StringName in [&"Accent", &"Neutral"]:
			points.append_array(_surface(Kit25.mesh_in(_file, mesh_name), _near(part)))
		body[part.resource_name] = points
	var rotor_envelope: Dictionary = _envelope(rotor, _surface(Kit25.mesh_in(_file, rotor.accent_mesh), func(_a: Vector3, _b: Vector3, _c: Vector3) -> bool: return true), 0.0)
	var prop_points: PackedVector3Array = _surface(Kit25.mesh_in(_file, propeller.accent_mesh), func(_a: Vector3, _b: Vector3, _c: Vector3) -> bool: return true)
	prop_points.append_array(_surface(Kit25.mesh_in(_file, propeller.neutral_mesh), func(_a: Vector3, _b: Vector3, _c: Vector3) -> bool: return true))
	var prop_envelope: Dictionary = _envelope(propeller, prop_points, HUB_RADIUS)
	var rotor_gap: Vector2 = _gap(rotor, rotor_envelope, body["Rotor"])
	# The propeller's frame is told apart where the mesh file's tubes cross its plane under the hub: the keel (the tube the engine
	# stands over, its top 3 cm under the lowest tip by the script's numbers), the mast brace (the tube that climbs from the keel to
	# the rotor's mast, which the story did not name), and the rest of the frame (the engine, the pylon, the exhaust, the gear).
	var keel: PackedVector3Array = PackedVector3Array()
	var brace: PackedVector3Array = PackedVector3Array()
	var rest_of_frame: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in body["Propeller"]:
		var on_axis: bool = absf(point.x) <= TUBE_HALF_WIDTH
		if on_axis and point.y <= KEEL_TOP:
			keel.append(point)
		elif on_axis and point.y <= BRACE_TOP:
			brace.append(point)
		else:
			rest_of_frame.append(point)
	var keel_gap: Vector2 = _gap(propeller, prop_envelope, keel)
	var brace_gap: Vector2 = _gap(propeller, prop_envelope, brace)
	var brace_at: Vector3 = _closest
	var rest_gap: Vector2 = _gap(propeller, prop_envelope, rest_of_frame)
	var rest_at: Vector3 = _closest
	var fin: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in body["Rotor"]:
		if point.z >= FIN_FROM_Z and absf(point.x) <= FIN_HALF_WIDTH and point.y >= FIN_FROM_Y:
			fin.append(point)
	var fin_gap: Vector2 = _gap(rotor, rotor_envelope, fin)
	_q.kit.need(problems, rotor_gap.y > 0.0 and rotor_gap.x > MIN_GAP, "the rotor's blades come within %.4f m of the frame (%d points judged)" % [rotor_gap.x, rotor_gap.y])
	_q.kit.need(problems, fin_gap.y > 0.0 and fin_gap.x > MIN_GAP, "the rotor's sweep comes within %.4f m of the fin (%d points)" % [fin_gap.x, fin_gap.y])
	_q.kit.need(problems, keel_gap.y > 0.0 and keel_gap.x > MIN_GAP and absf(keel_gap.x - KEEL_RECORD) <= KEEL_SLACK, "the propeller's lowest sweep comes within %.4f m of the keel (%d points), the script's numbers give about %.3f" % [keel_gap.x, keel_gap.y, KEEL_RECORD])
	_q.kit.need(problems, rest_gap.y > 0.0 and rest_gap.x > MIN_GAP, "the propeller's blades come within %.4f m of the rest of the frame (%d points), at %s" % [rest_gap.x, rest_gap.y, rest_at])
	_q.kit.need(problems, brace_gap.y > 0.0 and brace_gap.x > -BRACE_GRAZE, "the propeller's blades pass %.4f m into the mast brace (%d points): more than the %.3f m that is called a graze" % [-brace_gap.x, brace_gap.y, BRACE_GRAZE])
	var least: float = INF
	var counted: int = 0
	for step: int in 72:
		var basis: Basis = Basis(propeller.axis_direction(), TAU * step / 72.0)
		var turned: PackedVector3Array = PackedVector3Array()
		for point: Vector3 in prop_points:
			if Kit25.about(point, propeller.hub, propeller.axis_direction()).y >= propeller.smear_reach * TIP_SHARE - BIN:
				turned.append(propeller.hub + basis * (point - propeller.hub))
		var gap: Vector2 = _gap(rotor, rotor_envelope, turned)
		least = minf(least, gap.x)
		counted += int(gap.y)
	_q.kit.need(problems, counted > 0 and least > MIN_GAP, "the rotor's sweep comes within %.4f m of the propeller's tips (%d points)" % [least, counted])
	notes.append("along the axis the rotor's blades stay %.4f m clear of the frame (the fin %.4f m, the propeller's tips %.4f m) and the propeller's blades are %.4f m over the keel (the script's numbers: about %.3f), %.4f m clear of the rest of the frame (the nearest point of it at %s), and %.4f m into the mast brace, a tube 4.8 cm thick that crosses the propeller's plane under the hub: the lowest tip of the turn grazes it by %.1f mm, at %s" % [rotor_gap.x, fin_gap.x, least, keel_gap.x, KEEL_RECORD, rest_gap.x, rest_at, -brace_gap.x, -brace_gap.x * 1000.0, brace_at])
	measured.append("rotor_to_frame=%.4f rotor_to_fin=%.4f rotor_to_propeller=%.4f propeller_to_keel=%.4f propeller_to_rest=%.4f propeller_into_brace_mm=%.1f" % [rotor_gap.x, fin_gap.x, least, keel_gap.x, rest_gap.x, -brace_gap.x * 1000.0])
	await _q.kit.advance(1)
	_q.kit.verdict("sweep", problems, "%s" % "; ".join(notes))
