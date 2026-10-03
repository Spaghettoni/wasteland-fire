class_name FuelCan
extends Node3D
## A Fuel Can: a pickup at a fixed spot that refills the Unit touching it, vanishes, and is back
## at the same spot after a delay from data. This node is the thing itself, a red box with a
## touch zone, and it holds whether it stands at its spot (AVAILABLE) or is away
## (TAKEN) and the physics frame it comes back on.
##
## Implements: production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-6 (a Unit that
## touches an available Can gains refill_amount, never more than the room left in its tank; the Can
## vanishes and is back at the same spot respawn_delay_seconds later); design/game-brief.md MVP
## feature 6 (Fuel and Fuel Cans); design/rules.md "Resources" (Fuel Cans respawn at fixed places on
## the Map, and their amount and respawn time are tuning values: FuelCanSettings). Vocabulary:
## CONTEXT.md (Fuel Can, Fuel, Unit, Gyrocopter, Round, Map).
##
## The Can acts on its own, unlike the Flag (WaterCanister in code), because a refill needs no
## Player, Base or Round: the Unit's tank is the whole rule (Unit.refuel() adds Fuel up to the
## capacity and says how much it added). So the Can polls its own zone, calls down on the Unit and
## says what happened with `taken` and `restocked`, which nothing in v0.1 has to act on. It reads
## no input, never moves a Unit and never calls the Round; SplitScreen calls restock() when a Round
## starts again.
##
## Touches are polled. Once per physics tick, in this node's own _physics_process, the Can reads
## PickupZone.get_overlapping_bodies(), never body_entered: on this engine (Godot 4.7.2, Jolt)
## a handler of an Area3D's signal may not change monitoring or reparent, and work done inside it
## cannot be ordered against a tick (the Story 004 evidence doc keeps the probe). The zone's
## monitoring is never touched, taken or not: an off and an on within one tick leave it blind to a
## Unit already inside. A TAKEN Can takes nothing: it only notes the list, for the touch rule.
##
## Who takes it. A Unit touches the Can when the zone lists it on this tick and listed it on the
## Can's previous tick too. An entry seen on one tick alone is stale: the physics server keeps a
## teleported Unit at its old place for one more step (GarageQueue's spawn settle rule), so a Unit
## destroyed in the zone and respawned on its Base is listed here once, on the tick after the
## respawn, while it stands on its Base, and must not take the Can (the Story 006 evidence doc keeps
## the run). Among the touching Units that are alive and have room in their tank (fuel_capacity
## above zero and fuel below it), the one nearest to the Can in the ground plane (the x and z of the
## two global positions) is refuelled with settings.refill_amount, and an exact tie goes to the Unit
## whose node name sorts first. When refuel() added Fuel, the Can is taken: TAKEN, Body hidden,
## restock_frame stamped, then `taken` with that Unit. The engine's list order never decides: it is
## not reproducible when two Units touch on one tick (the Story 006 evidence doc keeps the run). The
## is_alive test is load-bearing, because the zone still lists a Unit on the tick it was destroyed
## or benched (it drops out a tick later) and keeps a frozen list while the tree is paused; refuel()
## refusing a Unit that is not alive is the second guard. A Unit with a full tank leaves the Can
## where it is; a Unit that moved on its last tick burned some Fuel, so it has room.
##
## Latency. The zone reports the physics server's last step: a Unit driven into it is listed a tick
## after its box first overlaps the sphere and touches the Can on the tick after that, one put
## there by spawn() is listed two ticks later and touches on the third, and one that left stays
## listed for a tick (the Story 006 evidence doc keeps the run).
##
## The return is a physics-frame stamp, never a Timer: a take stamps Engine.get_physics_frames()
## plus the delay in ticks (roundi of respawn_delay_seconds times Engine.physics_ticks_per_second,
## at least one), and the first tick that has reached it calls restock(). That tick takes nothing
## (it only notes the list, as every tick does) and the next one may, so a Unit parked in the zone
## with room in its tank takes the Can again on the tick after it is back: a Can that comes back
## under a Unit is grabbed at once.
##
## process_mode stays INHERIT, so a paused tree stops the Can while the physics frame count runs on:
## the Round-over pause counts toward the delay, a stamp that falls due inside it restocks on the
## Can's first tick after it, and a restart brings every Can back anyway (SplitScreen calls
## restock() on the "fuel_cans" group at round_started). Nothing compensates a pause.
##
## The scene (fuel_can.tscn), origin on the ground at the Can's spot, its root in the node group
## "fuel_cans" (the scene stores it):
##   FuelCan (this Node3D)
##     Body (Node3D): the Fuel Can's body, hidden while TAKEN: a red box 0.8 m wide, 1.0 m tall
##       and 0.4 m deep with a dark cap and a dark handle on top, unlike the Flag's round tank
##       (production/epics/wasteland-fire/story-007-the-map.md AC-11: the Fuel Cans are red and wear
##       no Team colour)
##     PickupZone (Area3D): a sphere of radius 1.6 m centred 0.6 m up, on no physics layer
##       (layer 0: nothing detects it) watching mask 18, ground Units (2) and Gyrocopters (16);
##       it only reports
## No solid collision: touching is driving into the zone, and an Area3D neither blocks nor pushes,
## so a Can changes no Unit's path.

## Emitted from the Can's own physics tick right after it refuelled the Unit (Story 006 AC-6): the
## Can is TAKEN and hidden by then, and restock_frame says when it is back. Once per take.
signal taken(unit: Unit)

## Emitted when a TAKEN Can is back at its spot, AVAILABLE and shown (restock()): from its own tick
## once the delay has passed, or when a Round starts again. Once per return.
signal restocked

## Whether the Can stands at its spot. The transitions are this node's own and the table is
## complete:
##   AVAILABLE -> TAKEN       its tick refuelled a Unit touching it (the nearest one with room)
##   TAKEN     -> AVAILABLE   restock(): its tick reached restock_frame, or a Round started again
## Nothing moves the Can: it is always at the spot the Map put it on.
enum State {
	## Standing at its spot, shown, polling its zone once per tick. The state at _ready().
	AVAILABLE,
	## Away: Body hidden; the zone's list is only noted, until restock_frame.
	TAKEN,
}

## The shared tuning values (FuelCanSettings): how much Fuel the Can gives and how long it stays
## away. fuel_can.tscn sets the shipped data/fuel_can_settings.tres, which every Can shares, so
## it is read-only at runtime.
@export var settings: FuelCanSettings

## The Area3D that reports Units touching the Can (physics layer 0, mask 18: ground Units and
## Gyrocopters; a sphere of radius 1.6 m). The Can polls it once per tick and never switches it
## off. The scene sets it to the PickupZone child.
@export var pickup_zone: Area3D

## The visual root of the Can, hidden while it is TAKEN and shown by restock(). The scene sets it to
## the Body child.
@export var can_body: Node3D

## Where the Can is (State): AVAILABLE from _ready() until a Unit takes it. Read-only: assigning to
## it pushes an error and changes nothing; it changes by a take and by restock().
var state: State:
	get:
		return _state
	set(_value):
		push_error("FuelCan '%s': state is read-only. A Unit takes the Can by touching it; restock() brings it back." % name)

## True while the Can stands at its spot and a Unit can take it (state AVAILABLE). Read-only like
## state.
var is_available: bool:
	get:
		return _state == State.AVAILABLE
	set(_value):
		push_error("FuelCan '%s': is_available is read-only. A Unit takes the Can by touching it; restock() brings it back." % name)

## The physics frame (Engine.get_physics_frames()) from which a TAKEN Can is back: the frame of the
## take plus the delay in ticks. Zero while the Can is AVAILABLE. Read-only like state.
var restock_frame: int:
	get:
		return _restock_frame
	set(_value):
		push_error("FuelCan '%s': restock_frame is read-only. A take stamps it from settings.respawn_delay_seconds." % name)

var _state: State = State.AVAILABLE
var _restock_frame: int = 0
## The Units the zone listed on the Can's previous tick: a Unit listed now and then touches the Can
## (class doc). Noted on every tick, AVAILABLE or TAKEN.
var _listed_before: Array[Unit] = []


func _ready() -> void:
	var missing: String = _first_unassigned()
	if missing.is_empty():
		return
	push_error("FuelCan '%s': %s is not assigned, so the Can never refills a Unit. settings, pickup_zone and can_body must all be assigned." % [name, missing])
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var touching: Array[Unit] = _touching_units()
	if _state == State.TAKEN:
		if Engine.get_physics_frames() >= _restock_frame:
			restock()
		return
	var unit: Unit = _nearest_unit_with_room(touching)
	if unit != null and unit.refuel(settings.refill_amount) > 0.0:
		_take(unit)


## Brings a TAKEN Can back (Story 006 AC-6): state AVAILABLE, restock_frame zero, Body shown, then
## `restocked`, once. The Can's own tick calls it when the delay has passed, and SplitScreen calls
## it on every Can when a Round starts again. Does nothing on an AVAILABLE Can. The Can never leaves
## its spot, so it is back at the same place. It touches no physics state: the zone, never switched
## off, lets the next tick see a Unit standing on the Can.
func restock() -> void:
	if _state != State.TAKEN:
		return
	_state = State.AVAILABLE
	_restock_frame = 0
	can_body.show()
	restocked.emit()


## Takes the Can for the Unit it has just refuelled: TAKEN, Body hidden, the return stamped
## respawn_delay_seconds of physics ticks from now (rounded, at least one tick), then `taken`.
func _take(unit: Unit) -> void:
	var delay_ticks: int = roundi(settings.respawn_delay_seconds * Engine.physics_ticks_per_second)
	_state = State.TAKEN
	can_body.hide()
	_restock_frame = Engine.get_physics_frames() + maxi(delay_ticks, 1)
	taken.emit(unit)


## The Units touching the Can on this tick (class doc): those the zone lists now that it listed on
## the Can's previous tick too, in the zone's order. Notes this tick's list for the next tick.
func _touching_units() -> Array[Unit]:
	var listed: Array[Unit] = []
	var touching: Array[Unit] = []
	for body: Node3D in pickup_zone.get_overlapping_bodies():
		var unit: Unit = body as Unit
		if unit == null:
			continue
		listed.append(unit)
		if _listed_before.has(unit):
			touching.append(unit)
	_listed_before = listed
	return touching


## The Unit the Can refuels on this tick (class doc): among the touching Units, the one that is
## alive, has room in its tank and stands nearest in the ground plane, an exact tie going to the
## node name that sorts first. Null when no touching Unit qualifies.
func _nearest_unit_with_room(touching: Array[Unit]) -> Unit:
	var nearest: Unit = null
	var nearest_distance: float = INF
	for unit: Unit in touching:
		if not _has_room(unit):
			continue
		var distance: float = _ground_distance(unit)
		if nearest == null or distance < nearest_distance or (
				distance == nearest_distance and String(unit.name) < String(nearest.name)):
			nearest = unit
			nearest_distance = distance
	return nearest


## True while the Unit is alive and its tank has room: a capacity above zero and Fuel below it. A
## destroyed or benched Unit, which the zone still lists for a tick, fails here.
func _has_room(unit: Unit) -> bool:
	return unit.is_alive and unit.fuel_capacity > 0.0 and unit.fuel < unit.fuel_capacity


## The distance from the Can to the Unit in the ground plane: the x and z of their global positions.
func _ground_distance(unit: Unit) -> float:
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	return here.distance_to(Vector2(unit.global_position.x, unit.global_position.z))


## The name of the first export that is not assigned, or an empty string when all three are.
func _first_unassigned() -> String:
	if settings == null:
		return "settings"
	if pickup_zone == null:
		return "pickup_zone"
	if can_body == null:
		return "can_body"
	return ""
