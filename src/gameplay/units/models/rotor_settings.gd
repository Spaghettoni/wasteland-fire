class_name RotorSettings
extends Resource
## The turning parts of a model type and how their smear looks: the Gyrocopter's main rotor and
## pusher propeller (src/gameplay/units/data/gyrocopter_rotor_settings.tres).
##
## Implements: production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-2 (the smear: how
## far behind a blade it reaches and how strong it is at the blade), AC-4 (the strobe limit: the
## settings refuse a rate that moves a blade too far in one tick) and AC-6 (every value is data,
## never a literal in a script); design/rules.md "Teams and visual style". Vocabulary: CONTEXT.md
## (Unit, Gyrocopter, Team colour).
##
## Data only. A MeshUnitModel that has these in its rotor_settings turns each part of parts about
## its own hub (RotorPivot); every model of the type shares one resource, so treat it as read-only
## at runtime (duplicate_deep() it for a private copy: duplicate() would share the parts). Every
## default below is zero or empty on purpose, for the reason UnitStats gives: the engine leaves a
## property that equals its script default out of a saved .tres, so a tuned number would vanish from
## the data file. Write every number into the .tres. first_problem() says whether the values can
## turn a part at all; MeshUnitModel asks it once when it builds, and a bad .tres is one named error
## and a model whose parts stand still.
##
## The strobe limit. The physics runs at Engine.physics_ticks_per_second (60), and a blade that
## moves by about the gap between two blades in one tick seems to stand still or to go backwards, so
## a fast rotor strobes. The share of the gap a blade moves in one tick is its turns a second times
## the number of blades over the ticks a second (RotorPart.step_share()); strobe_share is the most
## the data may ask for, at the idle rate and at the full rate, and it must stay under a half: at
## half the gap or more the interpolation between two ticks no longer takes the short way round.
## The smear then hides the step between two frames, not a step so big that the blades cannot be
## counted.

## The parts that turn, in the order they are built: each names two meshes of the model's mesh file.
@export var parts: Array[RotorPart] = []

## How far behind a blade its smear reaches, degrees: at most the gap between two blades of every
## part (a quarter turn, 90, is "about a quarter turn" for the two-blade rotor, whose gap is 180).
## Zero draws no smear.
@export_range(0.0, 180.0, 1.0, "suffix:°") var smear_arc_degrees: float = 0.0

## How solid the smear is at the blade, as an alpha from 0 to 1: it fades to nothing over its arc.
@export_range(0.0, 1.0, 0.01) var smear_strength: float = 0.0

## The most a blade may move in one physics tick, as a share of the gap between two blades (the
## strobe limit, above).
@export_range(0.0, 0.5, 0.01) var strobe_share: float = 0.0

## The material every smear is drawn with: a ShaderMaterial of spatial_unit_rotor_smear.gdshader,
## all of whose values are set on each smear instance, so one material serves every Unit. Required.
@export var smear_material: ShaderMaterial


## The reason these settings cannot turn a part, or an empty String when they can: no parts, a part
## with a mesh missing, no blades, an axis or a blade direction of length zero (or one along the
## other), a part with no name or the name of an earlier one (the name is its pivot's), a negative,
## NaN or zero rate, a strobe share of half or more, a rate over the strobe limit, a smear with no
## reach or no inner fade, a share outside 0 to 1, an arc outside 0 to one gap between two blades,
## or no smear material. Each test is written as "not above" so a NaN, which is above nothing, is
## refused too.
func first_problem() -> String:
	if parts.is_empty():
		return "parts is empty"
	if not (strobe_share > 0.0 and strobe_share < 1.0 - strobe_share):
		return ("strobe_share is not above 0 and under a half (a step of half the gap between two "
				+ "blades or more is not drawn the short way round)")
	if not (smear_strength >= 0.0 and smear_strength <= 1.0):
		return "smear_strength is not from 0 to 1"
	if not (smear_arc_degrees >= 0.0):
		return "smear_arc_degrees is negative or not a number"
	if smear_material == null or smear_material.shader == null:
		return "smear_material is not a ShaderMaterial with a shader"
	for index: int in parts.size():
		var problem: String = _first_part_problem(parts[index], index)
		if not problem.is_empty():
			return problem
	return ""


## The smear arc as radians (smear_arc_degrees).
func smear_arc() -> float:
	return deg_to_rad(smear_arc_degrees)


## The most turns a second the strobe limit allows a part, the rate at which a blade moves
## strobe_share of the gap between two blades in one tick (zero for a part without blades).
func strobe_limit_turns_per_second(part: RotorPart) -> float:
	if part.blade_count <= 0:
		return 0.0
	return strobe_share * Engine.physics_ticks_per_second / part.blade_count


func _first_part_problem(part: RotorPart, index: int) -> String:
	var label: String = "parts[%d]" % index
	if part == null:
		return "%s is empty" % label
	if part.accent_mesh == &"" or part.neutral_mesh == &"" or part.accent_mesh == part.neutral_mesh:
		return "%s does not name two meshes (accent_mesh and neutral_mesh)" % label
	if part.resource_name.is_empty():
		return "%s has no resource_name, which names its pivot" % label
	for earlier: int in index:
		if parts[earlier] != null and parts[earlier].resource_name == part.resource_name:
			return "%s has the resource_name of parts[%d]" % [label, earlier]
	if part.blade_count < 1:
		return "%s has no blades" % label
	var geometry: String = _first_geometry_problem(part, label)
	if not geometry.is_empty():
		return geometry
	var rates: String = _first_rate_problem(part, label)
	if not rates.is_empty():
		return rates
	return _first_smear_problem(part, label)


func _first_geometry_problem(part: RotorPart, label: String) -> String:
	if not (part.hub.is_finite() and part.axis.is_finite() and part.blade_direction.is_finite()):
		return "%s has a hub, an axis or a blade direction that is not a number" % label
	if not (part.axis.length() > 0.0):
		return "%s has an axis of length zero" % label
	if not (part.blade_side().length() > 0.0):
		return "%s has a blade direction of length zero or along its axis" % label
	return ""


func _first_rate_problem(part: RotorPart, label: String) -> String:
	if not (part.idle_turns_per_second >= 0.0 and is_finite(part.idle_turns_per_second)):
		return "%s has a negative or non-numeric idle rate" % label
	if not (part.full_turns_per_second > 0.0 and is_finite(part.full_turns_per_second)):
		return "%s has a full rate that is not above zero" % label
	var limit: float = strobe_limit_turns_per_second(part)
	for rate: float in [part.idle_turns_per_second, part.full_turns_per_second]:
		if not (part.step_share(rate) <= strobe_share):
			return ("%s turns %.2f times a second, which moves a blade %.3f of the gap between two in "
					+ "a tick, over the strobe share %.3f (the most is %.2f turns a second)") % [
					label, rate, part.step_share(rate), strobe_share, limit]
	return ""


func _first_smear_problem(part: RotorPart, label: String) -> String:
	if not (part.smear_reach > 0.0 and is_finite(part.smear_reach)):
		return "%s has a smear_reach that is not above zero" % label
	if not (part.smear_tip_start > 0.0 and part.smear_tip_start <= 1.0):
		return "%s has a smear_tip_start outside above 0 to 1" % label
	if not (part.smear_inner_share > 0.0 and part.smear_inner_share < 1.0):
		return "%s has a smear_inner_share outside above 0 to below 1" % label
	if not (part.smear_body_team_share >= 0.0 and part.smear_body_team_share <= 1.0):
		return "%s has a smear_body_team_share outside 0 to 1" % label
	if not (part.smear_tip_team_tone >= 0.0 and part.smear_tip_team_tone <= 1.0):
		return "%s has a smear_tip_team_tone outside 0 to 1" % label
	if not (smear_arc() <= part.blade_gap() or is_equal_approx(smear_arc(), part.blade_gap())):
		return "%s: smear_arc_degrees %.1f is wider than the %.1f degrees between two blades" % [
				label, smear_arc_degrees, rad_to_deg(part.blade_gap())]
	return ""
