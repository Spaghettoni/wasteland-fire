extends RefCounted
## The colours and the shadows of the turning parts for the rotors scenario (Story 025 AC-2 and AC-6): paint (each Player's
## Gyrocopter has its Team's material on every Team-coloured mesh, the Accent and the two turning ones, and the neutral material
## on the others, and every smear's instance colours are the Team's albedo, in linear colour, with the settings' strength as their
## alpha: Orange for Player 1, Teal for Player 2; they are set before the first frame a new model is drawn in) and no_shadow
## (a smear casts no shadow, has no collider and no layer of its own, and shares one material; the blades keep casting theirs, and
## they turn with their pivot by the step about the axis of the data). Run by rotors.gd. Tooling only. Every number comes from
## the game's data and files; the scenario types only its test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Each Player's Team material, by Player.
const TEAM_PATHS: Array[String] = [
	"res://src/gameplay/split_screen/data/team_orange_material.tres", "res://src/gameplay/split_screen/data/team_teal_material.tres"]
## The Team-coloured and the neutral meshes of a Gyrocopter's model, by name.
const TEAM_MESHES: Array[String] = ["Accent", "PropellerAccent", "RotorAccent"]
const NEUTRAL_MESHES: Array[String] = ["Neutral", "PropellerNeutral", "RotorNeutral"]
## What a colour read back may differ from the colour computed from the data by (a float32's rounding).
const COLOUR_TOLERANCE: float = 0.000001
## What the angle between two consecutive poses of a blade may differ from the step by, and how closely the axis must be the data's.
const TURN_TOLERANCE: float = 0.00001

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick
var _settings: RotorSettings
## What each new model's smears held on the first frame it was drawn in: {player, uniforms: [[body, tip] for each smear]}.
var _first_frames: Array[Dictionary] = []


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()
	_settings = kit.settings()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.walls().turrets_down()
	await _paint()
	await _no_shadow()


## A colour the engine gave back from an instance uniform of a vec4, as a Color.
func _colour(value: Variant) -> Color:
	if value is Vector4:
		return Color((value as Vector4).x, (value as Vector4).y, (value as Vector4).z, (value as Vector4).w)
	return value as Color if value is Color else Color(-1.0, -1.0, -1.0, -1.0)


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= COLOUR_TOLERANCE and absf(a.g - b.g) <= COLOUR_TOLERANCE and absf(a.b - b.b) <= COLOUR_TOLERANCE and absf(a.a - b.a) <= COLOUR_TOLERANCE


## The two colours a smear should hold for a part under a Team material, from the Team's albedo and the data: the body, mixed from the
## part's own colour toward the Team colour by its share, and the tip, the Team colour at the tone of the blades' tips; both linear,
## with the settings' strength as their alpha.
func _expected(part: RotorPart, team: Color) -> Array[Color]:
	var linear: Color = team.srgb_to_linear()
	var own: Color = part.smear_body_colour.srgb_to_linear()
	var body: Color = Color(lerpf(own.r, linear.r, part.smear_body_team_share), lerpf(own.g, linear.g, part.smear_body_team_share), lerpf(own.b, linear.b, part.smear_body_team_share), _settings.smear_strength)
	var tone: float = Color(part.smear_tip_team_tone, part.smear_tip_team_tone, part.smear_tip_team_tone).srgb_to_linear().r
	return [body, Color(linear.r * tone, linear.g * tone, linear.b * tone, _settings.smear_strength)]


## The smears under a Player's model, by part name: {"Rotor": MeshInstance3D, "Propeller": MeshInstance3D}.
func _smears(player: int) -> Dictionary:
	var found: Dictionary = {}
	for pivot: RotorPivot in _k.pivots_of(player):
		if pivot.smear() != null:
			found[String(pivot.name)] = pivot.smear()
	return found


## Whether every smear of a Player holds its two colours as a Vector4: a Color given to an instance uniform is converted from sRGB to
## linear by the renderer (the engine's source, 4.7.2), so the linear numbers must go as a Vector4, which it passes through. The readback
## returns the Variant as it was set, so the type is the only thing a readback can say about it.
func _colours_are_vectors(player: int) -> bool:
	var smears: Dictionary = _smears(player)
	var all: bool = not smears.is_empty()
	for part_name: String in smears:
		for uniform: StringName in [&"body_colour", &"tip_colour"]:
			all = all and typeof((smears[part_name] as MeshInstance3D).get_instance_shader_parameter(uniform)) == TYPE_VECTOR4
	return all


## Reads each smear's two colours from its instance uniforms: [[body, tip] for each part, in the settings' order].
func _read_colours(player: int) -> Array:
	var read: Array = []
	var smears: Dictionary = _smears(player)
	for part: RotorPart in _settings.parts:
		var smear: MeshInstance3D = smears.get(part.resource_name) as MeshInstance3D
		if smear == null:
			read.append([Color(-1.0, -1.0, -1.0, -1.0), Color(-1.0, -1.0, -1.0, -1.0)])
		else:
			read.append([_colour(smear.get_instance_shader_parameter(&"body_colour")), _colour(smear.get_instance_shader_parameter(&"tip_colour"))])
	return read


## Files what the smears of a Unit's new model hold on the first frame it is drawn in: the frame after the controller put it in play.
func _on_spawned(player: int) -> void:
	await _q.harness.get_tree().process_frame
	_first_frames.append({"player": player, "colours": _read_colours(player)})


## paint (AC-2): see the class doc.
func _paint() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	_q.controller.unit_spawned.connect(_on_spawned)
	for player: int in 2:
		await _q.tokens.destruct(player)
		var came: bool = await _q.tokens.spawn(player, Kit25.GYRO)
		_q.kit.need(problems, came, "Player %d's new Gyrocopter did not appear" % (player + 1))
	await _q.kit.advance(3)
	_q.controller.unit_spawned.disconnect(_on_spawned)
	_q.kit.need(problems, _first_frames.size() == 2, "%d first frames were read, expected 2" % _first_frames.size())
	for player: int in 2:
		var unit: Unit = _q.units.units[player]
		var model: Node3D = _k.model_of(player)
		var team: StandardMaterial3D = load(TEAM_PATHS[player]) as StandardMaterial3D
		_q.kit.need(problems, unit.team_material != null and unit.team_material.resource_path == TEAM_PATHS[player], "Player %d's Unit has the Team material %s" % [player + 1, unit.team_material.resource_path if unit.team_material != null else "none"])
		var painted: PackedStringArray = []
		for mesh_name: String in TEAM_MESHES:
			var mesh: MeshInstance3D = model.find_child(mesh_name, true, false) as MeshInstance3D
			_q.kit.need(problems, mesh != null and mesh.is_in_group(Unit.TEAM_COLOUR_GROUP) and mesh.material_override == unit.team_material, "Player %d: %s is not painted with the Team material (in the group %s, override %s)" % [player + 1, mesh_name, mesh != null and mesh.is_in_group(Unit.TEAM_COLOUR_GROUP), mesh.material_override if mesh != null else null])
			painted.append(mesh_name)
		for mesh_name: String in NEUTRAL_MESHES:
			var mesh: MeshInstance3D = model.find_child(mesh_name, true, false) as MeshInstance3D
			_q.kit.need(problems, mesh != null and not mesh.is_in_group(Unit.TEAM_COLOUR_GROUP) and mesh.material_override != unit.team_material and mesh.material_override is StandardMaterial3D and (mesh.material_override as StandardMaterial3D).vertex_color_use_as_albedo, "Player %d: %s is a Team mesh or lacks the neutral vertex-coloured material" % [player + 1, mesh_name])
		var group_size: int = 0
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			group_size += 1 if node.is_in_group(Unit.TEAM_COLOUR_GROUP) else 0
		_q.kit.need(problems, group_size == TEAM_MESHES.size(), "Player %d has %d Team-coloured meshes, expected %d (a smear or a neutral part is in the group)" % [player + 1, group_size, TEAM_MESHES.size()])
		var smears: Dictionary = _smears(player)
		_q.kit.need(problems, smears.size() == _settings.parts.size(), "Player %d has smears for %s" % [player + 1, smears.keys()])
		_q.kit.need(problems, _colours_are_vectors(player), "Player %d: a smear's colour is not a Vector4: the renderer would read it as sRGB and convert it again" % (player + 1))
		var now: Array = _read_colours(player)
		var first: Array = []
		for frame: Dictionary in _first_frames:
			if int(frame["player"]) == player:
				first = frame["colours"]
		for index: int in _settings.parts.size():
			var part: RotorPart = _settings.parts[index]
			var smear: MeshInstance3D = smears.get(part.resource_name) as MeshInstance3D
			var numbers: Array = [float(smear.get_instance_shader_parameter(&"blades")), float(smear.get_instance_shader_parameter(&"arc")), float(smear.get_instance_shader_parameter(&"tip_start")), float(smear.get_instance_shader_parameter(&"inner_share"))] if smear != null else []
			var wanted: Array = [float(part.blade_count), _settings.smear_arc(), part.smear_tip_start, part.smear_inner_share]
			var same: bool = numbers.size() == wanted.size()
			for k: int in numbers.size():
				same = same and absf(float(numbers[k]) - float(wanted[k])) <= COLOUR_TOLERANCE
			_q.kit.need(problems, same, "Player %d, %s: the smear's blades, arc, tip_start and inner_share are %s, expected %s" % [player + 1, part.resource_name, numbers, wanted])
			var want: Array[Color] = _expected(_settings.parts[index], team.albedo_color)
			_q.kit.need(problems, _same(now[index][0], want[0]) and _same(now[index][1], want[1]), "Player %d, %s: the smear holds body %s and tip %s, expected %s and %s" % [player + 1, _settings.parts[index].resource_name, now[index][0], now[index][1], want[0], want[1]])
			_q.kit.need(problems, not first.is_empty() and _same(first[index][0], want[0]) and _same(first[index][1], want[1]), "Player %d, %s: on the first frame the smear held %s, expected %s and %s" % [player + 1, _settings.parts[index].resource_name, first, want[0], want[1]])
		var rotor_body: Color = now[0][0]
		var linear: Color = team.albedo_color.srgb_to_linear()
		_q.kit.need(problems, absf(rotor_body.r - linear.r) <= COLOUR_TOLERANCE and absf(rotor_body.g - linear.g) <= COLOUR_TOLERANCE and absf(rotor_body.b - linear.b) <= COLOUR_TOLERANCE and absf(rotor_body.a - _settings.smear_strength) <= COLOUR_TOLERANCE, "Player %d: the rotor's smear is %s, not the Team's albedo %s in linear colour at the strength %s" % [player + 1, rotor_body, linear, _settings.smear_strength])
		notes.append("Player %d (%s): Team albedo %s, rotor smear body %s, tip %s, propeller smear body %s, tip %s" % [player + 1, TEAM_PATHS[player].get_file(), team.albedo_color, now[0][0], now[0][1], now[1][0], now[1][1]])
	_q.kit.need(problems, not _same(_read_colours(0)[0][0], _read_colours(1)[0][0]), "Orange's and Teal's smears are the same colour")
	measured.append("smear_colours=%s/%s" % [_read_colours(0)[0][0], _read_colours(1)[0][0]])
	_q.kit.verdict("paint", problems, "each Player's Gyrocopter has %d Team-coloured meshes (%s) painted with its own Team's material and three neutral ones with the vertex-coloured steel; the smears' instance colours are the Team's albedo in linear colour (the rotor's body exactly it, the tips at the blades' tip tones, the propeller's body the steel) at the settings' strength %s, set on the first frame a new model is drawn in; %s" % [TEAM_MESHES.size(), ", ".join(TEAM_MESHES), _settings.smear_strength, "; ".join(notes)])


## no_shadow (AC-2): see the class doc.
func _no_shadow() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var materials: Dictionary = {}
	var drawn: Array[int] = []
	for player: int in 2:
		var model: Node3D = _k.model_of(player)
		var smears: Dictionary = _smears(player)
		for part_name: String in smears:
			var smear: MeshInstance3D = smears[part_name]
			_q.kit.need(problems, smear.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Player %d's %s smear casts a shadow (mode %d)" % [player + 1, part_name, smear.cast_shadow])
			_q.kit.need(problems, smear.layers == 1 and smear.visible and smear.is_visible_in_tree(), "Player %d's %s smear is on layers %d, visible %s" % [player + 1, part_name, smear.layers, smear.visible])
			var part_of_smear: RotorPart = null
			for candidate: RotorPart in _settings.parts:
				part_of_smear = candidate if candidate.resource_name == part_name else part_of_smear
			var local: Basis = smear.transform.basis
			var want: Basis = part_of_smear.smear_basis()
			_q.kit.need(problems, smear.position == Vector3.ZERO and local.x.is_equal_approx(want.x) and local.y.is_equal_approx(want.y) and local.z.is_equal_approx(want.z), "Player %d's %s smear stands at %s with the frame %s, expected the part's %s at the hub" % [player + 1, part_name, smear.position, local, want])
			_q.kit.need(problems, local.y.normalized().dot(part_of_smear.axis_direction()) >= 1.0 - COLOUR_TOLERANCE and absf(local.x.length() - part_of_smear.smear_reach) <= COLOUR_TOLERANCE and absf(local.z.length() - part_of_smear.smear_reach) <= COLOUR_TOLERANCE and local.determinant() > 0.0 and local.x.normalized().dot(local.y.normalized()) <= COLOUR_TOLERANCE, "Player %d's %s smear is not a right-handed disc square to the axis of the part with the part's reach (determinant %.3f)" % [player + 1, part_name, local.determinant()])
			_q.kit.need(problems, smear.material_override == _settings.smear_material and smear.material_overlay == null and smear.mesh is PlaneMesh, "Player %d's %s smear has a material of its own or a mesh that is no PlaneMesh" % [player + 1, part_name])
			materials[smear.material_override.get_instance_id()] = true
		_q.kit.need(problems, model.find_children("*", "CollisionObject3D", true, false).is_empty() and model.find_children("*", "CollisionShape3D", true, false).is_empty() and model.find_children("*", "Area3D", true, false).is_empty(), "Player %d's model holds a collider" % (player + 1))
		var geometry: int = model.find_children("*", "GeometryInstance3D", true, false).size()
		drawn.append(geometry)
		_q.kit.need(problems, geometry == TEAM_MESHES.size() + NEUTRAL_MESHES.size() + smears.size(), "Player %d's model draws %d meshes: the six meshes and %d smears are %d" % [player + 1, geometry, smears.size(), TEAM_MESHES.size() + NEUTRAL_MESHES.size() + smears.size()])
		for mesh_name: String in TEAM_MESHES + NEUTRAL_MESHES:
			var mesh: MeshInstance3D = model.find_child(mesh_name, true, false) as MeshInstance3D
			_q.kit.need(problems, mesh != null and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Player %d's %s does not cast a shadow" % [player + 1, mesh_name])
		for part: RotorPart in _settings.parts:
			var mesh: MeshInstance3D = model.find_child(String(part.accent_mesh), true, false) as MeshInstance3D
			var before: Basis = mesh.global_transform.basis
			await _q.kit.tick()
			var after: Basis = mesh.global_transform.basis
			var turned: Quaternion = (before.inverse() * after).orthonormalized().get_rotation_quaternion()
			var step: float = TAU * part.turns_per_second(0.0) / Engine.physics_ticks_per_second
			var expected_axis: Vector3 = part.axis_direction()
			_q.kit.need(problems, absf(turned.get_angle() - step) <= TURN_TOLERANCE and turned.get_axis().dot(expected_axis) >= 1.0 - TURN_TOLERANCE, "Player %d's %s turned %.6f rad about %s in a tick, expected %.6f rad right-handed about %s" % [player + 1, part.accent_mesh, turned.get_angle(), turned.get_axis(), step, expected_axis])
	_q.kit.need(problems, materials.size() == 1, "%d different smear materials are in use, expected the one the settings hold" % materials.size())
	notes.append("%d and %d drawn meshes under the two models (the Accent, the Neutral, the four turning meshes and the two smears are 8)" % [drawn[0], drawn[1]])
	measured.append("geometry_per_gyrocopter=%d" % drawn[0])
	_q.kit.verdict("no_shadow", problems, "all four smears (two a Gyrocopter) cast no shadow, stand on render layer 1 and share the one ShaderMaterial of the settings, and no model holds a collider or a zone; the six meshes of each model cast shadows, and the Team-coloured turning ones turn with their pivots by the step of their rate about the axis of the data (rotor %s turns a second at a standstill, propeller %s); %s" % [_settings.parts[0].turns_per_second(0.0), _settings.parts[1].turns_per_second(0.0), "; ".join(notes)])
