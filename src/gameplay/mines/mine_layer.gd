class_name MineLayer
extends Node
## One Player's Mines: how many that Player's Unit has left, and the lay itself. A press of the lay
## key lays one Mine on the ground just behind the Truck's tail, unless the spot is in or near a
## Base or is not open ground, in which case nothing is laid, the count stays and the Player is
## told why.
##
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-1 (one press lays one
## Mine just behind the Truck's tail; a stranded Truck lays; a type that carries none lays none and
## shows nothing), AC-2 (every new Truck comes with its full load, at the first spawn, at every
## respawn and after every Swap; the count is shown only while the Unit is in play), AC-5 (the lay
## is refused in and near both Bases and wherever the Mine would not lie on open ground), AC-7
## (Mines stay when their Truck is gone) and AC-9 (every number is data: UnitStats.mine_capacity
## and mine_drop_offset, and MineSettings); design/rules.md "Turrets, Flag Walls and Mines".
## Vocabulary: CONTEXT.md (Mine, Truck, Base, Gate, Unit, Swap).
##
## Driven by command, not by input, like the Weapon: whoever presses the lay key (PlayerMineInput
## for a Player, a test) calls request_lay(), and the request is applied in this node's own tick,
## so the drop point is where the Truck stands after its move. One MineLayer per Player's Unit,
## stored in split_screen.tscn beside the Weapons; it knows its Unit, the settings and the Mine
## scene, and SplitScreen hands it the two Bases (bases) before the Round begins. It reads the
## Player's index from the Unit (Unit.player_index), never from a second index of its own, which
## could disagree with it in silence.
##
## The count. The MineLayer watches whether its Unit is in play. On the first tick it finds the
## Unit alive after a tick it was not, it refills the count to the type's mine_capacity and emits
## mines_changed; on the first tick it finds the Unit out of play it zeroes both the count and the
## capacity it reports and emits mines_changed with (0, 0). A signal goes out only when the count or
## the capacity differs from what was last reported, so a Motorbike coming and going says nothing.
## The Round never puts a Unit in play
## that is already in play, so every spawn, respawn and Swap is seen (GarageQueue spawns only a
## waiting Player); and a destroyed or benched Unit keeps its stats until its next spawn, which is
## why the capacity is read at the refill and not asked of the Unit later. A type with mine_capacity
## zero reports (0, 0) always. Mines already laid are not this node's: they stay when the Truck is
## destroyed or swapped.
##
## A press, in this order: the Unit is out of play or carries none: nothing happens, no signal.
## None left: refused, NONE_LEFT. The drop point in a no-mine area: refused, NEAR_BASE. Not open
## ground: refused, NO_ROOM. Else the Mine is instanced under the Unit's parent, laid at the drop
## point (the Unit's transform times mine_drop_offset), and the count goes down by one.
##
## The no-mine areas (is_in_no_mine_area()). A geometric test, deterministic, never
## overlaps_body(), which reports a Unit a tick or two late. For each Base, in the frame of its
## zone's box, the zone and the approach: as wide as the zone and reaching approach_past_zone past
## its Gate-side face (the box's local -Z side, the Gate side of every Base). A drop point is
## refused when it lies inside either grown by the trigger radius on every side, so no part of a
## Mine lies in a Base or less than the approach's depth in front of its Gate wall. The height is
## ignored.
##
## Open ground (is_open_ground()). One shape query at the drop point: a box of the Mine's footprint
## (twice the trigger radius, square) from probe_floor to probe_top above the drop point, on
## open_ground_mask, bodies only. Areas never count: a ford, a Fuel Can, a Flag and another Mine
## leave the ground open. The probe starts above the floor so the Map's floor never counts, and
## reaches far above the cliffs because a cliff is a hollow shell of faces: a footprint wholly
## inside the rock meets none of them, and a box that crosses the shell's top face always does.
##
## Ordering: _ready() sets process_physics_priority one above the Unit's own, as the Weapon does.
## The MineLayer destroys nothing, so its priority does not matter to a double loss.

## Why a press was refused (lay_refused).
enum Refusal {
	## The Truck has no Mine left.
	NONE_LEFT,
	## The drop point is inside a Base or on the approach in front of its Gate.
	NEAR_BASE,
	## The drop point is not open ground: a wall, a tower, the cover, a tank, a Turret, a Flag Wall,
	## a cliff or water would meet the Mine.
	NO_ROOM,
}

## Added to the Unit's process_physics_priority so this node runs just after it.
const PRIORITY_OFFSET: int = 1

## Emitted from this node's tick when the count or the capacity changes: a lay, a new Truck in play,
## the Truck leaving play (with 0 and 0). It is for display: a handler shows the numbers.
signal mines_changed(mines_left: int, capacity: int)

## Emitted from this node's tick for a press that was refused, with the reason. Nothing was laid
## and the count did not change.
signal lay_refused(reason: Refusal)

## The Unit this node lays for. Assign it before this node enters the tree.
@export var unit: Unit

## The shared tuning values (MineSettings): the trigger's size, the approach's depth and the
## open-ground probe. Required. The resource is shared, so never write to it at runtime.
@export var settings: MineSettings

## The Mine scene (mine.tscn) this node instances for every lay. Required.
@export var mine_scene: PackedScene

## Both Bases of the Map, handed by SplitScreen before the Round begins: where a Mine may not be
## laid. With none (a stand-in) no area is refused.
var bases: Array[Base] = []

## Mines left in the Truck's load: the type's mine_capacity after a spawn, down by one for every
## Mine laid, zero while the Unit is out of play. Read-only: assigning to it pushes an error.
var mines_left: int:
	get:
		return _left
	set(_value):
		push_error("MineLayer '%s': mines_left is read-only. A lay takes one; a new Unit refills it." % name)

## The load of the Unit in play: its type's mine_capacity, zero while the Unit is out of play.
## Read-only like mines_left.
var capacity: int:
	get:
		return _capacity
	set(_value):
		push_error("MineLayer '%s': capacity is read-only. It is the Unit type's data." % name)

var _left: int = 0
var _capacity: int = 0
var _in_play: bool = false
var _lay_requested: bool = false


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("MineLayer '%s': %s, so it lays nothing." % [name, problem])
		set_physics_process(false)
		return
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	_follow_unit()
	if not _lay_requested:
		return
	_lay_requested = false
	if _in_play:
		_lay()


## Asks for one Mine. It is applied in this node's next tick, once however long the key was held:
## the caller presses on an edge. A request made while the Unit is out of play is dropped.
func request_lay() -> void:
	_lay_requested = true


## True when a Mine dropped at the point would lie in or near a Base: the point is inside the zone
## of either Base or its approach in front of the Gate, grown by the trigger radius (the class doc).
func is_in_no_mine_area(point: Vector3) -> bool:
	for base: Base in bases:
		var box_node: CollisionShape3D = _zone_box(base)
		if box_node == null:
			continue
		var half: Vector3 = (box_node.shape as BoxShape3D).size / 2.0
		var local: Vector3 = box_node.global_transform.affine_inverse() * point
		var reach: float = settings.trigger_radius
		var along: float = half.z + settings.approach_past_zone + reach
		if absf(local.x) <= half.x + reach and local.z >= -along and local.z <= half.z + reach:
			return true
	return false


## True when nothing on the open-ground layers meets the footprint of a Mine dropped at the point
## (the class doc). Call it inside a physics tick: it queries the physics space.
func is_open_ground(point: Vector3) -> bool:
	var height: float = settings.probe_top - settings.probe_floor
	var side: float = settings.trigger_radius * 2.0
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(side, height, side)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY,
			point + Vector3.UP * (settings.probe_floor + height / 2.0))
	query.collision_mask = settings.open_ground_mask
	return unit.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Refills the count when the Unit has come into play and zeroes it when the Unit has left play,
## each with one mines_changed (the class doc, "The count").
func _follow_unit() -> void:
	var in_play: bool = is_instance_valid(unit) and unit.is_alive
	if in_play == _in_play:
		return
	_in_play = in_play
	var load_size: int = maxi(unit.stats.mine_capacity, 0) if in_play else 0
	_report(load_size, load_size)


## Sets the count and the capacity and emits mines_changed, unless both are what they were.
func _report(left: int, load_size: int) -> void:
	if left == _left and load_size == _capacity:
		return
	_left = left
	_capacity = load_size
	mines_changed.emit(_left, _capacity)


## Applies one press for a Unit in play (the class doc, "A press, in this order").
func _lay() -> void:
	if _capacity <= 0:
		return
	if _left <= 0:
		lay_refused.emit(Refusal.NONE_LEFT)
		return
	var point: Vector3 = unit.global_transform * unit.stats.mine_drop_offset
	if is_in_no_mine_area(point):
		lay_refused.emit(Refusal.NEAR_BASE)
		return
	if not is_open_ground(point):
		lay_refused.emit(Refusal.NO_ROOM)
		return
	var mine: Mine = mine_scene.instantiate() as Mine
	if mine == null:
		push_error("MineLayer '%s': mine_scene '%s' is not a Mine scene, so it lays nothing." % [
				name, mine_scene.resource_path])
		return
	unit.get_parent().add_child(mine)
	mine.lay(point, unit.player_index, unit.team_material)
	_report(_left - 1, _capacity)


## The box of a Base's zone (the first CollisionShape3D child of its zone that holds a box), or
## null for a Base without one.
func _zone_box(base: Base) -> CollisionShape3D:
	if base == null or base.zone == null:
		return null
	for child: Node in base.zone.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node
	return null


## What is wrong with the exports and the settings, as a sentence, or an empty string.
func _first_problem() -> String:
	if unit == null:
		return "unit is not assigned"
	if settings == null:
		return "settings is not assigned"
	if mine_scene == null:
		return "mine_scene is not assigned"
	return settings.first_problem()
