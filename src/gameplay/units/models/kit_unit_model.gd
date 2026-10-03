class_name KitUnitModel
extends Node3D
## A Unit type's model built from one of the author's concept-kit models: the root of
## motorbike_kit_model.tscn, buggy_kit_model.tscn, truck_kit_model.tscn and
## gyrocopter_kit_model.tscn, the scenes UnitStats.model points at.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-11 (a Unit wears its Team's
## colour and no other), AC-12 (each type reads by its silhouette; the Motorbike's cream heading
## cue), AC-13 (the Gyrocopter stays visible over the canyon walls and the ridge: the story's open
## question 3, a visual offset only) and AC-14 (one build per type, cached);
## production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-2 (the Gyrocopter flies over
## the Map's cover and its model rises over each piece, rise_body_mask); design/rules.md "Teams and
## visual style" and "Units". Vocabulary: CONTEXT.md (Unit, Team, Motorbike, Gyrocopter, Map,
## Cover).
##
## _ready() takes the build of kit_scene from KitMerge (made the first time a model of that kit,
## seed and remaps enters the tree, then cached: SplitScreen builds the match's types once before
## the Round begins) and adds two MeshInstance3D children: Accent, in Unit.TEAM_COLOUR_GROUP, which
## Unit._swap_model() paints with the Unit's team_material, and Neutral, which keeps the kit's
## colours. It scales itself by model_scale (the kit's length fitted to the type's collider) and
## stands at offset plus hover_height in the Unit's frame. The collider, the shots and the Fuel are
## the Unit's: this node is only what is drawn.
##
## Rise over cliffs (rise_over_cliffs, set on the Gyrocopter's scene only, so no code names a type):
## a flying Unit's collider stays on the floor and passes under the canyon rock and the ridge (2.0 m
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
## (the wrecks, the containers and the scrap walls, on the cover layer), and each piece is a body
## drawn by its Mesh child, not drawn geometry itself. So the same query also tests rise_body_mask,
## and a body on it lifts the model until its lowest point stands rise_clearance above the highest
## of its GeometryInstance3D children, with the same margin, lead and rates. A body on rise_mask
## alone is still a bare body, flown over at the hover (the water), so the rise over the cliffs and
## the water is what it was before Story 009.

## Name of the child that carries the Team accent, which the Unit paints.
const ACCENT_NODE_NAME: StringName = &"Accent"
## Name of the child that carries the neutral parts.
const NEUTRAL_NODE_NAME: StringName = &"Neutral"
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

@export_group("Kit")
## The kit model this Unit model is built from: the author's
## res://assets/art/vehicles/wasteland_<type>/wasteland_<type>.tscn, loaded by path, never edited.
@export var kit_scene: PackedScene
## The kit's rust seed. The palette builds its paint textures once per seed, so all four models
## share one. Required, with no default: each model scene stores it.
@export var rust_seed: int = 0
## Uniform scale of the kit model: its length fitted to the type's collider.
@export var model_scale: float = 1.0
## Height of the model above the Unit's floor, metres: the Gyrocopter's body hovers while its
## collider stays on the floor.
@export var hover_height: float = 0.0
## Shift of the model in the Unit's frame, metres (the Gyrocopter's hull centred on its collider).
@export var offset: Vector3 = Vector3.ZERO
## Kit key -> the kit key every part of it takes instead (the Buggy's pennant becomes the Team
## accent and the Truck's rust-orange drum dark steel: nothing neutral reads as a Team colour).
@export var material_remap: Dictionary[String, String] = {}
## Single parts that take another kit key: entries {"size": the part's BoxMesh size, "at": its
## centre in the kit's frame, "key": the key it takes} (KitMerge.get_or_build()); the Motorbike's
## tank-top patch takes the lamp's cream, its heading cue.
@export var part_remap: Array[Dictionary] = []

@export_group("Rise over cliffs")
## Whether the model rises over the drawn cliffs it crosses (the Gyrocopter's scene only): a visual
## offset, the collider stays on the floor.
@export var rise_over_cliffs: bool = false
## The physics layers the rise query tests: the cliffs_water layer (value 32). Required, with no
## default, when rise_over_cliffs is set.
@export_flags_3d_physics var rise_mask: int = 0
## The physics layers whose bodies the model also rises over, at the top of what each draws (its
## GeometryInstance3D children): the cover layer (value 64) on the Gyrocopter's scene (Story 009).
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

## The build this model shows; null before _ready() or when the build failed.
var _built: KitMerge.Built
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


func _ready() -> void:
	scale = Vector3.ONE * model_scale
	position = _rest_position()
	set_physics_process(false)
	if kit_scene == null:
		push_error("KitUnitModel '%s': no kit_scene, so the model is empty." % name)
		return
	_built = KitMerge.get_or_build(self, kit_scene, rust_seed, material_remap, part_remap)
	if _built == null:
		return
	_add_mesh(ACCENT_NODE_NAME, _built.accent, true)
	_add_mesh(NEUTRAL_NODE_NAME, _built.neutral, false)
	if rise_over_cliffs:
		var unset: String = _first_unset_rise_export()
		if not unset.is_empty():
			push_error("KitUnitModel '%s': rise_over_cliffs is on but %s is not set, so the model does not rise over cliffs." % [name, unset])
			return
		_rise_box = BoxShape3D.new()
		_rise_query = PhysicsShapeQueryParameters3D.new()
		_rise_query.shape = _rise_box
		_rise_query.collision_mask = rise_mask | rise_body_mask
		set_physics_process(true)


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
	var low: Vector3 = _built.hull.position * model_scale + offset - margin
	var high: Vector3 = _built.hull.end * model_scale + offset + margin
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
	var lowest: float = frame.origin.y + _rest_position().y + _built.hull.position.y * model_scale
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


## Where the model stands in the Unit's frame off the cliffs: offset, hover_height up.
func _rest_position() -> Vector3:
	return offset + Vector3.UP * hover_height


## Adds a MeshInstance3D child showing mesh; team_coloured puts it in Unit.TEAM_COLOUR_GROUP,
## stored with the node, for Unit._paint_team_colour().
func _add_mesh(node_name: StringName, mesh: ArrayMesh, team_coloured: bool) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if team_coloured:
		instance.add_to_group(Unit.TEAM_COLOUR_GROUP, true)
	add_child(instance)
