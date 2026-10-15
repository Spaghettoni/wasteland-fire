@abstract
class_name UnitModel
extends Node3D
## A Unit type's model, whatever builds its meshes: the root of the scene UnitStats.model points
## at. Two kinds extend it: MeshUnitModel, drawn from a mesh file built in Blender (each type's
## <type>_mesh_model.tscn since 2026-10-10), and KitUnitModel, built from one of the author's
## concept-kit models (each type's <type>_kit_model.tscn, the models from Story 007 until then).
## This class places the model in the Unit's frame, at the height its scene gives it (the Gyrocopter's
## flying height, Story 020), and can lift it over the cliffs and the cover it crosses when its scene
## asks for it (no shipped scene does since Story 020); each kind adds its own meshes.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-13 (the Gyrocopter stays
## visible over the canyon walls and the ridge: the story's open question 3, a visual offset only);
## production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-2 (the Gyrocopter flies over
## the Map's cover and its model rises over each piece, rise_body_mask);
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-4 (a badly damaged Unit
## smokes from its drawn body: smoke_scene);
## production/epics/wasteland-fire/story-020-two-heights.md AC-2 and AC-9 (the Gyrocopter's model
## stands at one flying height, hover_height, from the tick it is made and never rises; the rise
## switched off in its scene); design/rules.md "Heights", "Teams and visual style" and "Units".
## Vocabulary: CONTEXT.md (Unit, Gyrocopter, Height, Tall piece, Map, Cover).
##
## _ready() scales the model by model_scale, stands it at offset plus hover_height in the Unit's
## frame and calls _build_meshes(), which each kind implements: it adds the MeshInstance3D
## children, among them Accent in Unit.TEAM_COLOUR_GROUP, which Unit._paint_team_colour() paints
## with the Unit's team_material, and sets _hull, the box of the model's body in its own frame. The
## collider, the shots and the Fuel are the Unit's: this node is only what is drawn.
##
## Rise over cliffs (rise_over_cliffs, set on no shipped scene since Story 020, so no code names a
## type): the Gyrocopter's model flew at 0.78 m and rose over what it crossed from Story 007 to
## Story 019; its scene now stands at the flying height with no rise, and this code stays for the
## frozen copy of that earlier model which the evidence runner gives the scenarios written before
## (tools/evidence/frozen/gyrocopter_model_story_019.tscn): evidence-only code. A flying Unit's
## collider stays on the floor and passes under the canyon rock and the ridge (2.0 m
## tall, on the cliffs_water layer), so its model rises over them instead. Each physics tick one box
## query (intersect_shape) tests the model's hull footprint, widened by rise_margin on every side
## and stretched along the Unit's motion by rise_lead_seconds of it, from the floor up to
## RISE_BOX_HEIGHT, against rise_mask. A collider that is drawn geometry itself, a
## GeometryInstance3D (the query returns each of the Map's CSG cliffs as its CSGPolygon3D node:
## measured on 4.7.2; the Story 007 evidence doc keeps the run), lifts the model until its lowest
## point stands rise_clearance above that collider's top; a bare body is not drawn at its collider's
## height (a channel's water: an invisible 1.5 m StaticBody3D under a flat surface) and is flown
## over at the hover. The model rises at rise_rate and settles back at settle_rate once the box is
## clear. The lead has the model up before its hull reaches a cliff ahead at speed, and the margin
## before it reaches one from a standstill or by turning toward it, which the lead along the motion
## cannot see; so no part of the model enters rock. The one exception is a Unit put down against a
## cliff by spawn() or place() and driven before the model has had the rise's time at rise_rate; in
## a Round a Unit appears only in its Garage.
##
## Rise over the cover (Story 009 AC-2): the Gyrocopter's collider also passes under the Map's cover
## (the wrecks and the containers, on the cover layer), and each piece is a body drawn by its Mesh
## child, not drawn geometry itself. So the same query also tests rise_body_mask, and a body on it
## lifts the model until its lowest point stands rise_clearance above the highest of its
## GeometryInstance3D children, with the same margin, lead and rates. A body on rise_mask alone is
## still a bare body, flown over at the hover (the water), so the rise over the cliffs and the water
## is what it was before Story 009. The Flag Walls of Story 012 and the Wall Panels of Stories 018
## and 019 (the Base walls, the Garage walls and the scrap walls in the field) stand on the cover
## layer too, each drawn by a direct Mesh child, so the model rises over them as over a piece of
## cover (its lowest point at rise_clearance over a 2 m panel's top); a piece that has fallen has no
## layer and is not found.
##
## Smoke (Story 017 AC-4, smoke_scene, set on the mesh models of the four types; the kit models and
## the greybox models of the older scenarios leave it empty and show none): the model listens to
## its parent Unit's badly_damaged_changed and, on the first tick of a state, instances the scene
## as its last child at the top centre of its hull, so the smoke rises from what is drawn: a
## Gyrocopter's hover and its rise over cliffs and cover carry it. The scene is instanced on that
## first tick and never when the model is built, so a Round in which no Unit is badly damaged adds
## no node. It is shown on every change and hidden on the tick the state ends (the Unit's
## destroy(), leave_play() and spawn()); the node stays for the next state and goes with the model
## at a retype.

## Name of the child that carries the Team accent, which the Unit paints.
const ACCENT_NODE_NAME: StringName = &"Accent"
## Name of the child that carries the neutral parts.
const NEUTRAL_NODE_NAME: StringName = &"Neutral"
## Name of the child that carries the smoke of a badly damaged Unit (Story 017).
const SMOKE_NODE_NAME: StringName = &"Smoke"
## Height of the rise query's box above the Unit's floor, metres: above any cliff a Map stands
## (Map 01's are 2.0 m tall), so the box always crosses a cliff's top face.
const RISE_BOX_HEIGHT: float = 20.0
## Colliders the rise query reports at most. A CSG collider is reported once per overlapping piece
## of its collision shape, so one cliff fills several results (measured on 4.7.2; the Story 007
## evidence doc keeps the run). The cap must exceed the duplicates, or one cliff could crowd a
## taller one out of the results.
const RISE_MAX_RESULTS: int = 64
## The key of a rise query result that holds the collider (intersect_shape()).
const COLLIDER_KEY: String = "collider"

## Uniform scale of the model: 1.0 for a mesh file built to the type's collider in metres; a kit
## model's length fitted to the collider.
@export var model_scale: float = 1.0
## Height of the model above the Unit's floor, metres: the Gyrocopter's flying height, where its
## model's lowest drawn point stands from the tick it is made (Story 020), while its collider stays
## on the floor.
@export var hover_height: float = 0.0
## Shift of the model in the Unit's frame, metres (the kit Gyrocopter's hull centred on its
## collider).
@export var offset: Vector3 = Vector3.ZERO

@export_group("Rise over cliffs")
## Whether the model rises over the drawn cliffs it crosses: a visual offset, the collider stays on
## the floor. No shipped scene sets it since Story 020; the frozen model of the evidence runner does.
@export var rise_over_cliffs: bool = false
## The physics layers the rise query tests: the cliffs_water layer (value 32). Required, with no
## default, when rise_over_cliffs is set.
@export_flags_3d_physics var rise_mask: int = 0
## The physics layers whose bodies the model also rises over, at the top of what each draws (its
## GeometryInstance3D children): the cover layer (value 64) on the Gyrocopter's scene (Story 009),
## where the Flag Walls (Story 012) stand too.
## Optional: 0, the default, rises over the drawn colliders of rise_mask alone.
@export_flags_3d_physics var rise_body_mask: int = 0
## Height the model's lowest point keeps above a cliff's top, metres. Required, with no default,
## when rise_over_cliffs is set.
@export var rise_clearance: float = 0.0
## Speed the model rises at, metres per second. Required, with no default, when
## rise_over_cliffs is set.
@export var rise_rate: float = 0.0
## Speed the model settles back to its hover at, metres per second. Required, with no default,
## when rise_over_cliffs is set.
@export var settle_rate: float = 0.0
## Seconds of the Unit's motion the query box looks ahead: longer than the whole rise takes at
## rise_rate, so the model is up before its hull reaches a cliff ahead at speed. Required, with
## no default, when rise_over_cliffs is set.
@export var rise_lead_seconds: float = 0.0
## The farthest the query box looks ahead, metres (so a teleport is not taken for motion).
## Required, with no default, when rise_over_cliffs is set.
@export var rise_lead_max: float = 0.0
## Metres the query box reaches past the hull on every side, so the model is up before its hull
## reaches a cliff from a standstill or by turning toward it (the lead sees only the motion ahead):
## from rest the hull covers about 0.5 m while the model rises fully at rise_rate. Required, with
## no default, when rise_over_cliffs is set.
@export var rise_margin: float = 0.0

@export_group("Smoke")
## The smoke a badly damaged Unit gives off (badly_damaged_smoke.tscn, whose root is a
## BadlyDamagedSmoke). Optional: null, the default, shows none.
@export var smoke_scene: PackedScene

## The box of the model's body in its own frame, unscaled: its footprint and its lowest point are
## what the rise reads. Set by _build_meshes().
var _hull: AABB = AABB()
## Metres the model stands above its hover now (0.0 off the cliffs).
var _rise: float = 0.0
## Where the Unit stood on the last physics tick, for its motion.
var _last_origin: Vector3 = Vector3.ZERO
## Whether _last_origin holds a place yet.
var _has_last_origin: bool = false
## The rise query's box, sized every tick.
var _rise_box: BoxShape3D
## The rise query.
var _rise_query: PhysicsShapeQueryParameters3D
## The smoke, instanced on the first tick of the first badly damaged state and kept (hidden) after.
var _smoke: BadlyDamagedSmoke


func _ready() -> void:
	scale = Vector3.ONE * model_scale
	position = _rest_position()
	set_physics_process(false)
	if not _build_meshes():
		return
	_connect_smoke()
	if rise_over_cliffs:
		var unset: String = _first_unset_rise_export()
		if not unset.is_empty():
			push_error("%s '%s': rise_over_cliffs is on but %s is not set, so the model does not rise over cliffs." % [
					(get_script() as Script).get_global_name(), name, unset])
			return
		_rise_box = BoxShape3D.new()
		_rise_query = PhysicsShapeQueryParameters3D.new()
		_rise_query.shape = _rise_box
		_rise_query.collision_mask = rise_mask | rise_body_mask
		set_physics_process(true)


## Adds the model's MeshInstance3D children (_add_mesh()) and sets _hull; returns false when there
## is nothing to show, after an error naming the model and the cause, and the model then stays
## empty and does not rise.
@abstract func _build_meshes() -> bool


## The rise over cliffs, once per physics tick (rise_over_cliffs only): the Unit's motion since the
## last tick sets the lead, the query sets the target, and the model moves toward it at its rate.
func _physics_process(delta: float) -> void:
	var unit_frame: Node3D = get_parent_node_3d()
	if unit_frame == null or delta <= 0.0:
		return
	var origin: Vector3 = unit_frame.global_position
	var lead: Vector3 = Vector3.ZERO
	if _has_last_origin:
		lead = (origin - _last_origin) / delta * rise_lead_seconds
		lead.y = 0.0
		lead = lead.limit_length(rise_lead_max)
	_last_origin = origin
	_has_last_origin = true
	var target: float = _rise_target(unit_frame, lead)
	var rate: float = rise_rate if target > _rise else settle_rate
	_rise = move_toward(_rise, target, rate * delta)
	position = _rest_position() + Vector3.UP * _rise


## Metres above its hover the model needs for its lowest point to stand rise_clearance above the
## top of every drawn collider of rise_mask and every drawn body of rise_body_mask under its hull
## footprint (_drawn_top()), widened by rise_margin and stretched by lead (world metres, level), or
## 0.0 where there is none.
func _rise_target(unit_frame: Node3D, lead: Vector3) -> float:
	var frame: Transform3D = unit_frame.global_transform.orthonormalized()
	var local_lead: Vector3 = frame.basis.inverse() * lead
	var margin: Vector3 = Vector3(rise_margin, 0.0, rise_margin)
	var low: Vector3 = _hull.position * model_scale + offset - margin
	var high: Vector3 = _hull.end * model_scale + offset + margin
	low += local_lead.min(Vector3.ZERO)
	high += local_lead.max(Vector3.ZERO)
	_rise_box.size = Vector3(high.x - low.x, RISE_BOX_HEIGHT, high.z - low.z)
	var centre: Vector3 = Vector3((low.x + high.x) / 2.0, RISE_BOX_HEIGHT / 2.0, (low.z + high.z) / 2.0)
	_rise_query.transform = Transform3D(frame.basis, frame * centre)
	var top: float = -INF
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for hit: Dictionary in space.intersect_shape(_rise_query, RISE_MAX_RESULTS):
		top = maxf(top, _drawn_top(hit.get(COLLIDER_KEY)))
	if top == -INF:
		return 0.0
	var lowest: float = frame.origin.y + _rest_position().y + _hull.position.y * model_scale
	return maxf(0.0, top + rise_clearance - lowest)


## The world height of the top of what is drawn for a collider the rise query met: its own box when
## it is drawn geometry itself (a CSG cliff), the highest box of its GeometryInstance3D children
## when it is a body on rise_body_mask (a piece of cover, drawn by its Mesh), or -INF for anything
## else (a bare body such as a channel's water, flown over at the hover; a freed collider).
func _drawn_top(collider: Object) -> float:
	var drawn: GeometryInstance3D = collider as GeometryInstance3D
	if drawn != null:
		return (drawn.global_transform * drawn.get_aabb()).end.y
	var body: CollisionObject3D = collider as CollisionObject3D
	if body == null or (body.collision_layer & rise_body_mask) == 0:
		return -INF
	var top: float = -INF
	for child: Node in body.get_children():
		var part: GeometryInstance3D = child as GeometryInstance3D
		if part != null:
			top = maxf(top, (part.global_transform * part.get_aabb()).end.y)
	return top


## The first rise export that rise_over_cliffs needs and the model scene left unset (a mask of 0,
## a rate, a lead or a limit not above 0, a clearance or a margin below 0), or an empty string when
## all are set: each is Required, with no default, when the rise is on.
func _first_unset_rise_export() -> String:
	if rise_mask == 0:
		return "rise_mask"
	if rise_rate <= 0.0 or settle_rate <= 0.0:
		return "rise_rate or settle_rate"
	if rise_lead_seconds <= 0.0 or rise_lead_max <= 0.0:
		return "rise_lead_seconds or rise_lead_max"
	if rise_clearance < 0.0 or rise_margin < 0.0:
		return "rise_clearance or rise_margin"
	return ""


## Listens to the parent Unit's badly_damaged_changed when the scene has smoke and the parent is
## a Unit (a model instanced under another node, for a warm-up, has no state to show). The
## connection goes with this model when the Unit retypes: the model is freed then.
func _connect_smoke() -> void:
	var unit: Unit = get_parent() as Unit
	if smoke_scene == null or unit == null:
		return
	unit.badly_damaged_changed.connect(_on_badly_damaged_changed)


## Shows the smoke from the tick the state begins, instancing it the first time, and ends it on the
## tick the state ends.
func _on_badly_damaged_changed(badly_damaged: bool) -> void:
	if badly_damaged:
		if _smoke == null:
			_smoke = _instance_smoke()
		if _smoke != null:
			_smoke.start()
	elif _smoke != null:
		_smoke.stop()


## The smoke scene as this model's last child at the top centre of the hull (in this model's own
## frame, which model_scale scales), or null, after an error, when the scene's root is not a
## BadlyDamagedSmoke.
func _instance_smoke() -> BadlyDamagedSmoke:
	var instance: Node = smoke_scene.instantiate()
	var smoke: BadlyDamagedSmoke = instance as BadlyDamagedSmoke
	if smoke == null:
		push_error("%s '%s': the root of smoke_scene is not a BadlyDamagedSmoke, so the model shows no smoke." % [
				(get_script() as Script).get_global_name(), name])
		instance.free()
		return null
	smoke.name = SMOKE_NODE_NAME
	smoke.position = Vector3(_hull.get_center().x, _hull.end.y, _hull.get_center().z)
	add_child(smoke)
	return smoke


## Where the model stands in the Unit's frame off the cliffs: offset, hover_height up.
func _rest_position() -> Vector3:
	return offset + Vector3.UP * hover_height


## Adds a MeshInstance3D child showing mesh, with material as its material_override when one is
## given (null keeps the mesh's own surface materials); team_coloured puts it in
## Unit.TEAM_COLOUR_GROUP, stored with the node, for Unit._paint_team_colour(), which replaces the
## override with the Unit's team_material.
func _add_mesh(node_name: StringName, mesh: Mesh, team_coloured: bool,
		material: Material = null) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	if team_coloured:
		instance.add_to_group(Unit.TEAM_COLOUR_GROUP, true)
	add_child(instance)
