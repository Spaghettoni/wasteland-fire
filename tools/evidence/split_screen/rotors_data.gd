extends RefCounted
## The data of the turning parts for the rotors scenario (Story 025 AC-2 to AC-6): data (the shipped settings read back: the rotor's
## steady rate, the propeller's idle and full rates, the smear's arc and strength, the strobe share, the two parts' meshes and
## blades), mesh_match (each part's hub, axis, blade direction and reach checked against the vertices of the mesh file, and
## against the constants of the Blender script they come from), refusals (first_problem() refuses a rate over the strobe limit,
## a negative or NaN rate, an arc wider than a gap and the other unusable values, passes the limit itself; and a model given
## unusable settings draws its parts at rest and says so once) and lint (no number but 0 and 1 in the new scripts and the shader,
## and no branch names a Unit type). Run by rotors.gd. Tooling only. Every number comes from the game's data and the meshes; the
## scenario types only its test inputs and the story's values.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The story's values (AC-1 to AC-4): the main rotor turns 4 times a second, the propeller 2 times a second standing and 5 at
## its top speed, the smear trails about a quarter turn, and no blade may move more than 0.35 of the gap between two in a tick.
const ROTOR_RATE: float = 4.0
const PROP_IDLE: float = 2.0
const PROP_FULL: float = 5.0
const ARC_DEGREES: float = 90.0
const STROBE_SHARE: float = 0.35
## The constants of tools/blender/build_gyrocopter.py, in the mesh file's frame (a Blender point (x, y, z) is (x, z, -y)): the
## rotor's hub (ROTOR_HUB), the tilt back and the yaw of its blades and their coning (ROTOR_TILT, ROTOR_YAW, ROTOR_CONING), the
## radius (ROTOR_R), the propeller's hub (PROP_Y and ENGINE's height), its radius (PROP_R) and the angle of its first blade from up.
const ROTOR_HUB: Vector3 = Vector3(0.0, 1.58, 0.1)
const ROTOR_TILT_DEGREES: float = 6.0
const ROTOR_YAW_DEGREES: float = 25.0
const ROTOR_CONING_DEGREES: float = 2.5
const ROTOR_RADIUS: float = 2.3
const PROP_HUB: Vector3 = Vector3(0.0, 0.9, 0.63)
const PROP_RADIUS: float = 0.5
const PROP_FIRST_BLADE_DEGREES: float = 20.0
## What the data may differ from the meshes by: a point in metres (a millimetre), a direction in degrees, a radius in metres
## (the box corners of a tip stand a little past the radius), and how far from the plane of a blade a vertex may stand (half its
## thickness, 0.024 m for the propeller's, and a little over).
const POINT_TOLERANCE: float = 0.001
const ANGLE_TOLERANCE_DEGREES: float = 1.0
const RADIUS_SLACK: float = 0.02
const PLANE_SLACK: float = 0.013
## The share of the longest reach from the axis a vertex must have to count as a blade's tip.
const TIP_SHARE: float = 0.98
## The files the lint reads, and the functions of the model it reads from mesh_unit_model.gd.
const LINT_FILES: Array[String] = [
	"res://src/gameplay/units/models/rotor_part.gd", "res://src/gameplay/units/models/rotor_settings.gd",
	"res://src/gameplay/units/models/rotor_pivot.gd", "res://src/gameplay/units/models/spatial_unit_rotor_smear.gdshader"]
const LINT_MODEL_FILE: String = "res://src/gameplay/units/models/mesh_unit_model.gd"
const LINT_MODEL_FUNCTIONS: Array[String] = ["_build_rotors", "_first_missing_rotor_mesh"]
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_data()
	_mesh_match()
	await _refusals()
	_lint()


## data (AC-2, AC-3, AC-6): the shipped settings are usable and hold the story's starting values.
func _data() -> void:
	var problems: PackedStringArray = []
	var settings: RotorSettings = _k.settings()
	_q.kit.need(problems, settings != null and settings.first_problem().is_empty(), "the shipped settings read '%s'" % (settings.first_problem() if settings != null else "nothing"))
	var rotor: RotorPart = settings.parts[0]
	var propeller: RotorPart = settings.parts[1]
	_q.kit.need(problems, settings.parts.size() == 2 and rotor.resource_name == "Rotor" and propeller.resource_name == "Propeller", "the parts are %s" % [settings.parts.map(func(p: RotorPart) -> String: return p.resource_name)])
	_q.kit.need(problems, rotor.idle_turns_per_second == ROTOR_RATE and rotor.full_turns_per_second == ROTOR_RATE and rotor.blade_count == 2, "the rotor turns %s to %s times a second with %d blades" % [rotor.idle_turns_per_second, rotor.full_turns_per_second, rotor.blade_count])
	_q.kit.need(problems, propeller.idle_turns_per_second == PROP_IDLE and propeller.full_turns_per_second == PROP_FULL and propeller.blade_count == 3, "the propeller turns %s to %s times a second with %d blades" % [propeller.idle_turns_per_second, propeller.full_turns_per_second, propeller.blade_count])
	_q.kit.need(problems, settings.smear_arc_degrees == ARC_DEGREES and settings.strobe_share == STROBE_SHARE, "the smear's arc is %s degrees, the strobe share %s" % [settings.smear_arc_degrees, settings.strobe_share])
	_q.kit.need(problems, settings.smear_strength > 0.0 and settings.smear_strength <= 1.0, "the smear's strength is %s" % settings.smear_strength)
	_q.kit.need(problems, rotor.accent_mesh == &"RotorAccent" and rotor.neutral_mesh == &"RotorNeutral" and propeller.accent_mesh == &"PropellerAccent" and propeller.neutral_mesh == &"PropellerNeutral", "the meshes named are %s %s %s %s" % [rotor.accent_mesh, rotor.neutral_mesh, propeller.accent_mesh, propeller.neutral_mesh])
	_q.kit.need(problems, settings.smear_material.shader.resource_path.ends_with("spatial_unit_rotor_smear.gdshader"), "the smear's shader is %s" % settings.smear_material.shader.resource_path)
	var model: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	_q.kit.need(problems, model.rotor_settings == settings and model.rotor_settings.resource_path == Kit25.SETTINGS_PATH, "the Gyrocopter's model scene holds %s" % model.rotor_settings)
	model.free()
	var steps: PackedStringArray = []
	for part: RotorPart in settings.parts:
		for rate: float in [part.idle_turns_per_second, part.full_turns_per_second]:
			steps.append("%s %.1f deg a tick, %.3f of the gap" % [part.resource_name.to_lower(), rate * 360.0 / Engine.physics_ticks_per_second, part.step_share(rate)])
			_q.kit.need(problems, part.step_share(rate) <= STROBE_SHARE, "%s at %s turns a second moves a blade %.3f of the gap in a tick" % [part.resource_name, rate, part.step_share(rate)])
	measured.append("rates=%s/%s/%s arc=%s strength=%s strobe=%s" % [rotor.idle_turns_per_second, propeller.idle_turns_per_second, propeller.full_turns_per_second, settings.smear_arc_degrees, settings.smear_strength, settings.strobe_share])
	_q.kit.verdict("data", problems, "rotors_data: gyrocopter_rotor_settings.tres is usable and holds the main rotor at a steady %s turns a second (2 blades), the pusher propeller at %s standing and %s at its top speed (3 blades), a smear trailing %s degrees behind each blade at an alpha of %s, and the strobe share %s; the step a tick is %s, never over the share" % [ROTOR_RATE, PROP_IDLE, PROP_FULL, settings.smear_arc_degrees, settings.smear_strength, settings.strobe_share, "; ".join(steps)])


## The blades' tips of a part: each blade's centroid of the vertices at 98% of the longest reach from the axis, in the mesh file's
## frame, found by the nearest of the blades' expected directions. {centroids (one Vector3 for each blade, in the order of the
## blades from blade_direction), reach (the longest distance from the axis), mean_along (the mean distance of the tip vertices
## along the axis from the hub's plane)}.
func _tips(part: RotorPart, vertices: PackedVector3Array) -> Dictionary:
	var axis: Vector3 = part.axis_direction()
	var reach: float = 0.0
	for point: Vector3 in vertices:
		reach = maxf(reach, Kit25.about(point, part.hub, axis).y)
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	for blade: int in part.blade_count:
		sums.append(Vector3.ZERO)
		counts.append(0)
	var along: float = 0.0
	var along_count: int = 0
	for point: Vector3 in vertices:
		var read: Vector2 = Kit25.about(point, part.hub, axis)
		if read.y < reach * TIP_SHARE:
			continue
		var side: Vector3 = (point - part.hub - axis * read.x).normalized()
		var best: int = 0
		var best_dot: float = -INF
		for blade: int in part.blade_count:
			var dot: float = side.dot(Basis(axis, part.blade_gap() * blade) * part.blade_side())
			if dot > best_dot:
				best_dot = dot
				best = blade
		sums[best] += point
		counts[best] += 1
		along += read.x
		along_count += 1
	var centroids: Array[Vector3] = []
	for blade: int in part.blade_count:
		centroids.append(sums[blade] / float(maxi(counts[blade], 1)))
	return {"centroids": centroids, "reach": reach, "mean_along": along / float(maxi(along_count, 1))}


## mesh_match (AC-5, AC-6): the data of each part stands where the mesh file has the part. The main rotor: the hub is the centre
## of the neutral mesh (the hub box), the axis is the line the two tips' middle stands on over the hub (the blades are coned up
## about it) and the first blade runs where the file's blades run; the propeller: its blades lie in the plane through the hub
## square to the axis, the three tips' middle is the hub, and the blades are where the data says; the reach is the longest
## distance of a vertex from the axis. The data also equals what the constants of the Blender script give.
func _mesh_match() -> void:
	var problems: PackedStringArray = []
	var file: PackedScene = load(Kit25.MESH_FILE_PATH) as PackedScene
	var settings: RotorSettings = _k.settings()
	var notes: PackedStringArray = []
	var tilt: float = deg_to_rad(ROTOR_TILT_DEGREES)
	var yaw: float = deg_to_rad(ROTOR_YAW_DEGREES)
	var rotor: RotorPart = settings.parts[0]
	var propeller: RotorPart = settings.parts[1]
	var rotor_axis: Vector3 = Vector3(0.0, cos(tilt), sin(tilt))
	var rotor_blade: Vector3 = Vector3(cos(yaw), sin(yaw) * sin(tilt), -sin(yaw) * cos(tilt))
	var prop_blade: Vector3 = Vector3(sin(deg_to_rad(PROP_FIRST_BLADE_DEGREES)), cos(deg_to_rad(PROP_FIRST_BLADE_DEGREES)), 0.0)
	_q.kit.need(problems, rotor.hub.distance_to(ROTOR_HUB) <= POINT_TOLERANCE and propeller.hub.distance_to(PROP_HUB) <= POINT_TOLERANCE, "the hubs are %s and %s, the script's %s and %s" % [rotor.hub, propeller.hub, ROTOR_HUB, PROP_HUB])
	_q.kit.need(problems, rad_to_deg(rotor.axis_direction().angle_to(rotor_axis)) <= ANGLE_TOLERANCE_DEGREES / 10.0, "the rotor's axis %s is %.3f degrees from the script's tilt %s" % [rotor.axis_direction(), rad_to_deg(rotor.axis_direction().angle_to(rotor_axis)), rotor_axis])
	_q.kit.need(problems, rad_to_deg(rotor.blade_side().angle_to(rotor_blade)) <= ANGLE_TOLERANCE_DEGREES / 10.0, "the rotor's blade %s is %.3f degrees from the script's yaw %s" % [rotor.blade_side(), rad_to_deg(rotor.blade_side().angle_to(rotor_blade)), rotor_blade])
	_q.kit.need(problems, rad_to_deg(propeller.axis_direction().angle_to(Vector3.FORWARD)) <= ANGLE_TOLERANCE_DEGREES / 10.0 and rad_to_deg(propeller.blade_side().angle_to(prop_blade)) <= ANGLE_TOLERANCE_DEGREES / 10.0, "the propeller's axis %s and first blade %s against forward and %s" % [propeller.axis_direction(), propeller.blade_side(), prop_blade])
	# The rotor.
	var rotor_neutral: PackedVector3Array = Kit25.vertices_of(Kit25.mesh_in(file, rotor.neutral_mesh))
	var box_low: Vector3 = Vector3.INF
	var box_high: Vector3 = -Vector3.INF
	for point: Vector3 in rotor_neutral:
		box_low = box_low.min(point)
		box_high = box_high.max(point)
	_q.kit.need(problems, ((box_low + box_high) / 2.0).distance_to(rotor.hub) <= POINT_TOLERANCE, "the rotor's hub box is centred on %s, the data's hub is %s" % [(box_low + box_high) / 2.0, rotor.hub])
	var rotor_tips: Dictionary = _tips(rotor, Kit25.vertices_of(Kit25.mesh_in(file, rotor.accent_mesh)))
	var tips: Array[Vector3] = rotor_tips["centroids"]
	var middle: Vector3 = (tips[0] + tips[1]) / 2.0 - rotor.hub
	var coning: float = rad_to_deg(asin(middle.length() / (tips[0] - rotor.hub).length()))
	_q.kit.need(problems, rad_to_deg(middle.normalized().angle_to(rotor.axis_direction())) <= ANGLE_TOLERANCE_DEGREES, "the middle of the rotor's two tips stands %.2f degrees off the data's axis over the hub" % rad_to_deg(middle.normalized().angle_to(rotor.axis_direction())))
	_q.kit.need(problems, absf(coning - ROTOR_CONING_DEGREES) <= ANGLE_TOLERANCE_DEGREES, "the blades are coned %.2f degrees, the script's %s" % [coning, ROTOR_CONING_DEGREES])
	var blade_error: float = 0.0
	for index: int in 2:
		var from_hub: Vector3 = tips[index] - rotor.hub
		from_hub -= rotor.axis_direction() * from_hub.dot(rotor.axis_direction())
		blade_error = maxf(blade_error, rad_to_deg(from_hub.normalized().angle_to(Basis(rotor.axis_direction(), rotor.blade_gap() * index) * rotor.blade_side())))
	_q.kit.need(problems, blade_error <= ANGLE_TOLERANCE_DEGREES, "a rotor blade runs %.2f degrees off the data's blade direction" % blade_error)
	_q.kit.need(problems, rotor.smear_reach >= float(rotor_tips["reach"]) - RADIUS_SLACK and rotor.smear_reach <= float(rotor_tips["reach"]) + RADIUS_SLACK, "the rotor's smear reaches %.3f m, the blades' tips %.3f m" % [rotor.smear_reach, rotor_tips["reach"]])
	notes.append("rotor: hub box centre %.4f m from the data's hub, tips %.3f m out, coned %.2f deg, blades %.2f deg off, the tips' middle %.2f deg off the axis" % [((box_low + box_high) / 2.0).distance_to(rotor.hub), rotor_tips["reach"], coning, blade_error, rad_to_deg(middle.normalized().angle_to(rotor.axis_direction()))])
	# The propeller.
	var prop_accent: PackedVector3Array = Kit25.vertices_of(Kit25.mesh_in(file, propeller.accent_mesh))
	var prop_neutral: PackedVector3Array = Kit25.vertices_of(Kit25.mesh_in(file, propeller.neutral_mesh))
	var prop_axis: Vector3 = propeller.axis_direction()
	var thickest: float = 0.0
	for point: Vector3 in prop_accent:
		thickest = maxf(thickest, absf(Kit25.about(point, propeller.hub, prop_axis).x))
	var prop_tips: Dictionary = _tips(propeller, prop_accent)
	var prop_centroids: Array[Vector3] = prop_tips["centroids"]
	var middle_of_three: Vector3 = (prop_centroids[0] + prop_centroids[1] + prop_centroids[2]) / 3.0 - propeller.hub
	var off_axis: float = Kit25.about(middle_of_three + propeller.hub, propeller.hub, prop_axis).y
	var prop_error: float = 0.0
	for index: int in 3:
		var from_hub: Vector3 = prop_centroids[index] - propeller.hub
		from_hub -= prop_axis * from_hub.dot(prop_axis)
		prop_error = maxf(prop_error, rad_to_deg(from_hub.normalized().angle_to(Basis(prop_axis, propeller.blade_gap() * index) * propeller.blade_side())))
	_q.kit.need(problems, thickest <= PLANE_SLACK and absf(float(prop_tips["mean_along"])) <= PLANE_SLACK, "the propeller's tips stand up to %.4f m from the plane through the hub (mean %.4f)" % [thickest, prop_tips["mean_along"]])
	_q.kit.need(problems, off_axis <= POINT_TOLERANCE * 5.0, "the middle of the propeller's three tips stands %.4f m off the axis" % off_axis)
	_q.kit.need(problems, prop_error <= ANGLE_TOLERANCE_DEGREES, "a propeller blade runs %.2f degrees off the data's blade direction" % prop_error)
	_q.kit.need(problems, propeller.smear_reach >= float(prop_tips["reach"]) - RADIUS_SLACK and propeller.smear_reach <= float(prop_tips["reach"]) + RADIUS_SLACK, "the propeller's smear reaches %.3f m, the blades' tips %.3f m" % [propeller.smear_reach, prop_tips["reach"]])
	var spans: Vector2 = Vector2(INF, -INF)
	for point: Vector3 in prop_neutral:
		spans = Vector2(minf(spans.x, Kit25.about(point, propeller.hub, prop_axis).x), maxf(spans.y, Kit25.about(point, propeller.hub, prop_axis).x))
	notes.append("propeller: tips %.3f m out, within %.4f m of the plane, the middle of the three %.4f m off the axis, blades %.2f deg off, hub and spinner span %.3f to %.3f m along the axis" % [prop_tips["reach"], thickest, off_axis, prop_error, spans.x, spans.y])
	measured.append("rotor_reach=%.4f propeller_reach=%.4f" % [rotor_tips["reach"], prop_tips["reach"]])
	_q.kit.verdict("mesh_match", problems, "the data stands where the mesh file has the parts and equals the constants of the Blender script: the hubs, the rotor's tilt (%s degrees back) and yaw (%s) and the propeller's first blade (%s degrees from up) within a tenth of a degree and a millimetre; %s" % [ROTOR_TILT_DEGREES, ROTOR_YAW_DEGREES, PROP_FIRST_BLADE_DEGREES, "; ".join(notes)])


## A deep copy of the shipped settings (duplicate() of a Resource shares its Array and the parts in it), changed by `change`.
func _variant(change: Callable) -> RotorSettings:
	var copy: RotorSettings = _k.settings().duplicate_deep() as RotorSettings
	change.call(copy)
	return copy


## The change that makes one kind of unusable settings out of the shipped ones: a Callable that takes a copy.
func _breaker(kind: String, limit_rotor: float, limit_prop: float) -> Callable:
	return func(s: RotorSettings) -> void:
		match kind:
			"rotor_fast":
				s.parts[0].full_turns_per_second = limit_rotor * 1.01
			"prop_idle_fast":
				s.parts[1].idle_turns_per_second = limit_prop * 1.01
			"negative_idle":
				s.parts[1].idle_turns_per_second = -1.0
			"nan_full":
				s.parts[1].full_turns_per_second = NAN
			"zero_full":
				s.parts[0].full_turns_per_second = 0.0
			"arc_181":
				s.smear_arc_degrees = 181.0
			"arc_125":
				s.smear_arc_degrees = 125.0
			"arc_negative":
				s.smear_arc_degrees = -1.0
			"axis_zero":
				s.parts[0].axis = Vector3.ZERO
			"blade_along_axis":
				s.parts[1].blade_direction = s.parts[1].axis * 2.0
			"no_blades":
				s.parts[0].blade_count = 0
			"no_parts":
				var none: Array[RotorPart] = []
				s.parts = none
			"strobe_zero":
				s.strobe_share = 0.0
			"strobe_nan":
				s.strobe_share = NAN
			"strength_over":
				s.smear_strength = 1.5
			"no_material":
				s.smear_material = null
			"no_reach":
				s.parts[0].smear_reach = 0.0
			"same_mesh":
				s.parts[1].neutral_mesh = s.parts[1].accent_mesh
			"missing_mesh":
				s.parts[0].accent_mesh = &"NoSuchMesh"
			"strobe_half":
				s.strobe_share = 0.5
			"no_part_name":
				s.parts[0].resource_name = ""
			"same_part_name":
				s.parts[1].resource_name = s.parts[0].resource_name


## refusals (AC-4, AC-6): first_problem() refuses what cannot turn a part, each with its own sentence, and passes the shipped
## settings and a rate exactly at the strobe limit; and a model given unusable settings draws its turning parts at rest with no
## pivot and no smear, after exactly one error.
func _refusals() -> void:
	var problems: PackedStringArray = []
	var shipped: RotorSettings = _k.settings()
	var limit_rotor: float = shipped.strobe_limit_turns_per_second(shipped.parts[0])
	var limit_prop: float = shipped.strobe_limit_turns_per_second(shipped.parts[1])
	var cases: Array = [
		["a rotor rate over the strobe limit", "rotor_fast", "over the strobe share"],
		["an idle rate over it (the propeller)", "prop_idle_fast", "over the strobe share"],
		["a negative idle rate", "negative_idle", "negative or non-numeric idle rate"],
		["a rate that is not a number", "nan_full", "full rate that is not above zero"],
		["a full rate of zero", "zero_full", "full rate that is not above zero"],
		["an arc wider than the rotor's gap", "arc_181", "wider than the"],
		["an arc wider than the propeller's gap", "arc_125", "parts[1]: smear_arc_degrees"],
		["a negative arc", "arc_negative", "smear_arc_degrees is negative"],
		["an axis of length zero", "axis_zero", "axis of length zero"],
		["a blade direction along the axis", "blade_along_axis", "along its axis"],
		["no blades", "no_blades", "has no blades"],
		["no parts", "no_parts", "parts is empty"],
		["a strobe share of zero", "strobe_zero", "strobe_share is not above 0"],
		["a strobe share that is not a number", "strobe_nan", "strobe_share is not above 0"],
		["a strength over 1", "strength_over", "smear_strength is not from 0 to 1"],
		["no smear material", "no_material", "smear_material is not a ShaderMaterial"],
		["a smear that reaches nowhere", "no_reach", "smear_reach that is not above zero"],
		["two parts that name the same mesh", "same_mesh", "does not name two meshes"],
		["a strobe share of a half", "strobe_half", "under a half"],
		["a part with no name", "no_part_name", "has no resource_name"],
		["two parts with one name", "same_part_name", "has the resource_name of parts[0]"],
	]
	var refused: PackedStringArray = []
	for entry: Array in cases:
		var settings: RotorSettings = _variant(_breaker(String(entry[1]), limit_rotor, limit_prop))
		var text: String = settings.first_problem()
		_q.kit.need(problems, text.contains(String(entry[2])), "%s reads '%s', expected a sentence with '%s'" % [entry[0], text, entry[2]])
		refused.append(entry[0])
	var at_limit: RotorSettings = _variant(func(s: RotorSettings) -> void:
		s.parts[0].full_turns_per_second = limit_rotor
		s.parts[1].full_turns_per_second = limit_prop)
	_q.kit.need(problems, at_limit.first_problem().is_empty(), "rates exactly at the strobe limit (%.2f and %.2f turns a second) read '%s'" % [limit_rotor, limit_prop, at_limit.first_problem()])
	_q.kit.need(problems, shipped.first_problem().is_empty() and is_equal_approx(limit_rotor, shipped.strobe_share * Engine.physics_ticks_per_second / 2.0), "the shipped settings read '%s' and the rotor's limit is %.3f turns a second" % [shipped.first_problem(), limit_rotor])
	var arc_at_gap: RotorSettings = _variant(func(s: RotorSettings) -> void: s.smear_arc_degrees = rad_to_deg(s.parts[1].blade_gap()))
	_q.kit.need(problems, arc_at_gap.first_problem().is_empty(), "an arc exactly one gap of the propeller wide reads '%s'" % arc_at_gap.first_problem())
	var bad: RotorSettings = _variant(func(s: RotorSettings) -> void: s.parts[0].full_turns_per_second = limit_rotor * 2.0)
	var scratch: Node3D = Node3D.new()
	_q.harness.add_child(scratch)
	var errors_before: int = _q.tokens.engine_log.errors.size()
	var model: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	model.rotor_settings = bad
	scratch.add_child(model)
	var names: PackedStringArray = []
	var pivots: int = 0
	var smears: int = 0
	for child: Node in model.get_children():
		names.append(child.name)
		pivots += 1 if child is RotorPivot else 0
	smears = model.find_children("Smear", "MeshInstance3D", true, false).size()
	expected_errors += 1
	_q.kit.need(problems, _q.tokens.engine_log.errors.size() == errors_before + 1, "a model given unusable settings logged %d errors" % (_q.tokens.engine_log.errors.size() - errors_before))
	_q.kit.need(problems, pivots == 0 and smears == 0 and names.has("RotorAccent") and names.has("RotorNeutral") and names.has("PropellerAccent") and names.has("PropellerNeutral") and names.has("Accent") and names.has("Neutral"), "that model has %s with %d pivots and %d smears" % [names, pivots, smears])
	var rest: bool = true
	for node_name: String in ["RotorAccent", "RotorNeutral", "PropellerAccent", "PropellerNeutral"]:
		var part: Node3D = model.get_node_or_null(node_name) as Node3D
		rest = rest and part != null and part.position == Vector3.ZERO and part.basis == Basis.IDENTITY
	_q.kit.need(problems, rest, "the turning meshes of that model do not stand in the pose of the file")
	scratch.queue_free()
	# Settings that are usable but name a mesh the file does not hold: one error, the meshes the file has drawn at rest, no pivot.
	var absent: RotorSettings = _variant(_breaker("missing_mesh", limit_rotor, limit_prop))
	_q.kit.need(problems, absent.first_problem().is_empty(), "settings naming a missing mesh read '%s' (the model finds it out)" % absent.first_problem())
	var other: Node3D = Node3D.new()
	_q.harness.add_child(other)
	var errors_again: int = _q.tokens.engine_log.errors.size()
	var lacking: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	lacking.rotor_settings = absent
	other.add_child(lacking)
	var lacking_names: PackedStringArray = []
	for child: Node in lacking.get_children():
		lacking_names.append(child.name)
	expected_errors += 1
	_q.kit.need(problems, _q.tokens.engine_log.errors.size() == errors_again + 1 and lacking.find_children("*", "RotorPivot", true, false).is_empty() and lacking_names.has("RotorNeutral") and not lacking_names.has("NoSuchMesh"), "a model whose settings name a missing mesh logged %d errors and has %s" % [_q.tokens.engine_log.errors.size() - errors_again, lacking_names])
	other.queue_free()
	measured.append("refusals=%d" % cases.size())
	_q.kit.verdict("refusals", problems, "first_problem() refuses %d unusable settings, each with its own sentence (%s) and passes the shipped settings, rates exactly at the strobe limit (%.2f turns a second for the rotor) and an arc of exactly one gap; a model given settings whose rate is over the limit draws %d meshes with no pivot and no smear, the turning ones at rest, after one logged error" % [cases.size(), "; ".join(refused), limit_rotor, names.size()])


## The code of a source file with the comments (# in a script, // in a shader), quoted text and the editor's range hints taken out.
func _code_lines(text: String, comment: String) -> PackedStringArray:
	var quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
	var hint: RegEx = RegEx.create_from_string(r"@export_range\([^)]*\)")
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		lines.append(hint.sub(quoted.sub(line, "", true).get_slice(comment, 0), "", true))
	return lines


## The lines of a function of a script, from its `func` line to the line before the next top-level line.
func _function_text(text: String, function_name: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var found: PackedStringArray = []
	var inside: bool = false
	for line: String in lines:
		if line.begins_with("func %s(" % function_name):
			inside = true
		elif inside and not line.is_empty() and not line.begins_with("\t") and not line.begins_with("#"):
			inside = false
		if inside:
			found.append(line)
	return "\n".join(found)


## lint (AC-6): no number but 0 and 1 is a constant in code. Every code line of the new scripts and the shader, and of the
## functions of the model that build the parts, comments, quoted text and the editor's range hints taken out, is read for number
## literals other than LINT_INTEGERS and LINT_FLOATS, and for a branch that names a Unit type.
func _lint() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
	var sources: Dictionary = {}
	for path: String in LINT_FILES:
		sources[path.get_file()] = FileAccess.get_file_as_string(path)
	var model_text: String = FileAccess.get_file_as_string(LINT_MODEL_FILE)
	for function_name: String in LINT_MODEL_FUNCTIONS:
		sources["mesh_unit_model.gd %s" % function_name] = _function_text(model_text, function_name)
	var lines: int = 0
	for source_name: String in sources:
		var text: String = sources[source_name]
		_q.kit.need(problems, not text.is_empty(), "%s is empty or missing" % source_name)
		for code: String in _code_lines(text, "//" if source_name.ends_with(".gdshader") else "#"):
			lines += 0 if code.strip_edges().is_empty() else 1
			for hit: RegExMatch in literal.search_all(code):
				var number: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(number)) if number.contains(".") else LINT_INTEGERS.has(int(number))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [source_name, number, code.strip_edges()])
			for type_name: String in ["motorbike", "buggy", "truck", "gyrocopter"]:
				_q.kit.need(problems, not code.contains("&\"%s\"" % type_name) and not code.contains("type_id =="), "%s names a Unit type: %s" % [source_name, code.strip_edges()])
	measured.append("lint_lines=%d" % lines)
	_q.kit.verdict("lint", problems, "%d code lines of the three new scripts, the shader and the model's two functions that build the parts hold no number other than 0, 1, 0.0 and 1.0, and no branch names a Unit type" % lines)
