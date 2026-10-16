class_name RotorPivot
extends Node3D
## One turning part of a Unit's model: the main rotor or the pusher propeller of the Gyrocopter. It
## stands at the part's hub, holds the part's two meshes (so they turn about it) and the smear its
## blades trail, and turns them about the part's axis on every physics tick.
##
## Implements: production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-1 (the rotor turns
## at a steady rate from the tick the Unit appears until it leaves play, both blades always
## countable), AC-2 (a see-through smear behind each blade in the Team colour, no shadow), AC-3 (the
## propeller's rate follows the Unit's speed), AC-4 (the same step on every tick, drawn between
## ticks) and AC-6 (every value is RotorSettings and RotorPart data); design/rules.md "Teams and
## visual style". Vocabulary: CONTEXT.md (Unit, Gyrocopter, Team colour).
##
## MeshUnitModel makes one for each RotorPart of its rotor_settings, as its child, and hands it the
## two meshes it has added under it (start()); a model with no rotor_settings makes none and draws
## as it did before the story. A picture only: nothing here is a physics body, on a collision layer
## or read by the rules.
##
## The frame. This node is at the part's hub in the model's frame and its two meshes are at minus
## the hub under it, so every vertex of the mesh file stands where the file has it while the angle
## is zero; turning the node turns the part about the line through the hub along the axis. The smear
## is a flat disc in the plane through the hub square to the axis (RotorPart.smear_basis()), a child
## of this node, so it turns with the blades; it is spatial_unit_rotor_smear.gdshader on a
## PlaneMesh.
##
## The turn. Each physics tick, while the Unit is in play (its model is visible in the tree), the
## angle grows by a whole turn times the current rate times the tick's time, kept below a whole
## turn; the rate is the part's turns_per_second() at the Unit's speed share: the length of its real
## velocity along the way it faces over its top speed in the direction it moves (max_speed forward,
## reverse_max_speed backward), from 0 to 1. A Unit out of play (destroyed, benched by a Swap or the
## Round's start) draws nothing, and its angle is zero. Every spawn the Round makes gives the Unit
## the type's stats, which makes a new model (Unit.spawn() swaps in the type's scene), and a node
## added inside a physics tick has its first physics tick in the next one, so a new Gyrocopter is
## first drawn with its parts at rest and turns by one step a tick from the tick after: every life
## begins at rest and the same frames follow. A model that stays through a spawn (one given no
## stats) has been out of play for a tick at least, unless it was destroyed and spawned within one,
## and turns on from the angle it had. A model that is not a Unit's (a warm-up instance) turns at
## the idle rate. The node ticks one priority after the default, after every node of the tick at
## the default priority (the Unit's own move and the MatchController among them), and the
## Round-over pause stops it with everything else that counts ticks.
##
## Smooth. The turn is made in the physics tick, so under the World's physics interpolation (Story
## 002) the part is drawn between its last two angles on a faster display. A step is under half the
## gap between two blades (RotorSettings' strobe limit), so the interpolation takes the short way
## round.
##
## The smear's colour. The meshes' Team-coloured part is painted by Unit._paint_team_colour() right
## after the model enters the tree, so the smear reads the painted material's colour one deferred
## call later, before the next frame is drawn, and sets it on its own instance uniforms (the one
## shared ShaderMaterial is never changed). Until then its alpha is zero, so a smear is never drawn
## in a colour that is not the Team's. The numbers go to the shader as linear colours in a Vector4:
## the renderer reads a Color given to an instance uniform as sRGB and converts it to linear (the
## engine's source for 4.7.2, which the story's review read, and the frames agree), which would
## darken a colour that is already linear; a Vector4 reaches the shader as it is.

## The name of the smear node.
const SMEAR_NODE_NAME: StringName = &"Smear"

## The disc every smear is drawn on: a PlaneMesh of its default size (2 m across, facing +Y), made
## on first use and shared by every smear.
static var _plane: PlaneMesh

## The part this pivot turns. Set by start().
var part: RotorPart

## The angle the part has turned from rest, radians, from 0 up to a whole turn.
var angle: float = 0.0

## The turns a second of the last physics tick; 0 while the Unit is out of play.
var current_turns_per_second: float = 0.0

var _settings: RotorSettings
var _model: Node3D
var _unit: Unit
var _axis: Vector3 = Vector3.ZERO
var _accent: MeshInstance3D
var _smear: MeshInstance3D


func _init() -> void:
	process_physics_priority = 1


## Sets the pivot up once it is a child of its model, with the two meshes already added under it at
## minus the hub (accent is the Team-coloured one): puts it at the part's hub, at rest, makes the
## smear (unless the settings draw none) and reads the Team colour for it after the paint.
func start(settings: RotorSettings, rotor_part: RotorPart, accent: MeshInstance3D) -> void:
	_settings = settings
	part = rotor_part
	_accent = accent
	_axis = part.axis_direction()
	_model = get_parent() as Node3D
	_unit = _model.get_parent() as Unit if _model != null else null
	position = part.hub
	_make_smear()
	_read_team_colour.call_deferred()


## The smear node, or null when the settings draw none.
func smear() -> MeshInstance3D:
	return _smear


func _physics_process(delta: float) -> void:
	if _model == null or not _model.is_visible_in_tree():
		current_turns_per_second = 0.0
		_turn_to(0.0)
		return
	current_turns_per_second = part.turns_per_second(_speed_share())
	_turn_to(fposmod(angle + TAU * current_turns_per_second * delta, TAU))


## Turns the part to an angle from rest, writing the node's basis only when the angle changes.
func _turn_to(new_angle: float) -> void:
	if new_angle == angle:
		return
	angle = new_angle
	basis = Basis(_axis, angle)


## The Unit's speed along the way it faces as a share of its top speed in the direction it moves,
## from 0 to 1; 0 for a model with no Unit or a Unit with no top speed.
func _speed_share() -> float:
	if _unit == null or _unit.stats == null:
		return 0.0
	var along: float = _unit.get_real_velocity().dot(-_unit.global_transform.basis.z.normalized())
	var top: float = _unit.stats.max_speed if along >= 0.0 else _unit.stats.reverse_max_speed
	if not (top > 0.0):
		return 0.0
	return clampf(absf(along) / top, 0.0, 1.0)


## Adds the smear: a MeshInstance3D of the shared disc with the settings' material, no shadow, its
## numbers set on its own instance uniforms. Its colours stay clear until the Team colour is read.
func _make_smear() -> void:
	if _settings.smear_arc() <= 0.0 or _settings.smear_strength <= 0.0:
		return
	if _plane == null:
		_plane = PlaneMesh.new()
	_smear = MeshInstance3D.new()
	_smear.name = SMEAR_NODE_NAME
	_smear.mesh = _plane
	_smear.material_override = _settings.smear_material
	_smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smear.transform = Transform3D(part.smear_basis(), Vector3.ZERO)
	add_child(_smear)
	_smear.set_instance_shader_parameter(&"blades", float(part.blade_count))
	_smear.set_instance_shader_parameter(&"arc", _settings.smear_arc())
	_smear.set_instance_shader_parameter(&"tip_start", part.smear_tip_start)
	_smear.set_instance_shader_parameter(&"inner_share", part.smear_inner_share)


## Sets the smear's two colours from the Team colour the Accent mesh has been painted with (the
## albedo of the Unit's team_material; a Unit with none leaves the Accent in its steel, and the
## smear follows it), as linear colours in a Vector4 (the class doc says why) with the settings'
## strength as their alpha.
func _read_team_colour() -> void:
	if _smear == null or not is_instance_valid(_accent):
		return
	var painted: StandardMaterial3D = _accent.material_override as StandardMaterial3D
	var team: Color = part.smear_body_colour
	if painted != null:
		team = painted.albedo_color
	team = team.srgb_to_linear()
	var body: Color = part.smear_body_colour.srgb_to_linear().lerp(team, part.smear_body_team_share)
	var tone: float = Color(part.smear_tip_team_tone, part.smear_tip_team_tone,
			part.smear_tip_team_tone).srgb_to_linear().r
	body.a = _settings.smear_strength
	_smear.set_instance_shader_parameter(&"body_colour", Vector4(body.r, body.g, body.b, body.a))
	_smear.set_instance_shader_parameter(&"tip_colour", Vector4(team.r * tone, team.g * tone,
			team.b * tone, _settings.smear_strength))
