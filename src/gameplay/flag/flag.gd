class_name Flag
extends Node3D
## The Flag, one per Base, that a Motorbike picks up by touching it, carries on its tail,
## drops where it is destroyed and, when it is the opponent's, delivers to its own Base to win the
## Round. This node is the thing itself: a small water tank in its owner's colour and a touch zone.
## It holds where it is (at home, carried, dropped) and the Unit carrying it, and nothing else.
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-1 (a visible
## Flag in its Player's colour: apply_color() paints the body, the steel parts stay steel), AC-2
## (picked up by touching: is_touching() says whether a Unit is in the PickupZone, carry_by() puts
## the Flag on the Unit, where it rides at the Unit's carry_offset), AC-3 (drop_at() stands it
## where the Carrier was destroyed, and nothing here ever moves it home) and AC-4 (seat_at() stands
## it back on its Base's seat when its owner brings it home); design/game-brief.md MVP feature 4;
## design/rules.md "Resources" (one Flag sits in each Base; when the Carrier is destroyed
## the Flag stays lying where it was; its handling: a Motorbike picks a Flag up by touching
## it, a dropped Flag never returns home on its own). Vocabulary: CONTEXT.md (Flag, Carrier,
## Unit, Base, Round, Player).
##
## A dumb actor. The Flag knows no Round, Player, Base or owner, connects no signal of its
## PickupZone, emits no signal and never calls a Unit. It answers is_touching() and does what it is
## told: carry_by(), drop_at(), seat_at(), apply_color(). Who may pick it up (a Unit whose data says
## can_carry, and not its owner while it stands at home), what a touch means, where it drops and
## when a delivery wins the Round are the Round's rules, and they live in one place, the
## MatchController, which polls is_touching() once per physics tick and calls down. Three reasons.
## The rules need a Unit's Player index and Base, which the Flag has no business knowing. A win
## decided inside one Flag's own body_entered handler could not be ordered against the other
## Flag's, or against a delivery, on the same tick (two Players touching one Flag on one
## tick: the lower index wins, decided by the controller). And the engine refuses, from inside an
## Area3D's body_entered handler, both a reparent of a CollisionObject3D and an assignment to
## monitoring, so a Flag that carried itself on body_entered would error twice and stay half
## carried (the Story 004 evidence doc keeps the probe). Signals up, calls down, as the Unit has it,
## except that the Flag has nothing to say.
##
## The scene (flag.tscn), origin at the centre of the base so a seat or a drop position is
## a point on the ground:
##   Flag (this Node3D)
##     Body (MeshInstance3D): a 0.56 m wide, 0.72 m tall cylinder from 0.10 m up, light grey
##       until apply_color() paints it in the owning Player's colour (on Map 01 its Team colour:
##       production/epics/wasteland-fire/story-007-the-map.md AC-12, the Flag is a carryable water
##       tank about 1 m tall)
##     Stand, BandLow, BandHigh, Lid (MeshInstance3D): its dark steel parts, a base ring, two bands
##       0.6 m across and a domed lid, 0.94 m tall in all; never painted, so the Flag reads as the
##       same tank in either Player colour, on its seat and on a Unit's tail
##     PickupZone (Area3D): a 1 m sphere about the body's middle, on physics layer 4 ("flags",
##       project.godot) watching layer 2 ("units"); it only reports
## No solid collision anywhere. Picking up is touching (AC-2): a Unit drives into the Flag and
## the overlap is the pick-up, so a collider that stopped the Unit at the Flag's surface would
## stop it short of the touch and bounce it off the Flag; a dropped Flag in a lane
## would be an obstacle no rule asked for; and a carried one with a collider would collide with its
## own Carrier. The PickupZone is the only CollisionObject3D here, an Area3D neither blocks nor
## pushes, and no Unit's collision mask includes layer 4, so Unit movement never notices it.
##
## Overlap data is late. PickupZone.overlaps_body() reports the physics server's last step: a Unit
## that drives onto the Flag is reported about two physics ticks after the tick whose end
## position overlaps, and a Unit that was destroyed (collision layer zeroed) leaves the list a tick
## later; the Story 004 evidence doc keeps the measurements. The rules poll, so they act on the
## first tick the touch is reported, and nothing is sized on same-tick detection.
##
## Carrying is reparenting. carry_by() moves the node under the Unit, upright, at the local position
## the Unit's data gives (Unit.carry_offset, a tail mount for the Motorbike), so the Flag is
## drawn at a constant offset from the Unit's interpolated pose and follows it without a line of
## per-frame code (physics interpolation is on; the Story 004 evidence doc keeps the ride
## measurement). The home parent, remembered in _ready() because reparent() does not run _ready()
## again, is where drop_at() and seat_at() put the node back, and only when it is somewhere else:
## the reparent takes the PickupZone out of the physics world and back in, and that re-insertion
## is what lets it report a Unit standing on the Flag again after a carry. While carried, the
## Flag is hidden with its Carrier when the Unit is destroyed (visibility inherits down the
## tree) and shows again the moment drop_at() reparents it home; nothing here writes its own
## visible flag.
##
## PickupZone.monitoring is never touched. Neither carry_by() nor drop_at() nor seat_at() switches
## the zone off and on: on this engine (Godot 4.7.2, Jolt) an off and an on in one tick, without a
## re-insertion between them, leave overlaps_body() blind for good to a Unit already inside, and an
## assignment from a signal handler is refused (the Story 004 evidence doc keeps both probes). The
## controller never asks is_touching() of a CARRIED Flag, and that is all the gating a carried
## Flag needs: its zone goes on reporting its Carrier and no rule reads it.
##
## Every placement (drop_at(), seat_at()) and every carry_by() runs inside a physics tick, from the
## controller's _physics_process, or from begin() before the first: a placement is followed by
## reset_physics_interpolation(), so the drawn Flag makes one jump and no streak, and a reparent
## of a CollisionObject3D is refused inside a physics callback (an Area3D's signal), which a tick's
## own code never is.

## Where the Flag is: on its Base's seat, on a Unit or lying where its Carrier was destroyed.
## The transitions are the MatchController's and the table is complete:
##   AT_HOME -> CARRIED   carry_by(): the other Player's Unit touched it (an owner cannot pick up
##                        its own Flag while it stands at home)
##   CARRIED -> DROPPED   drop_at(): the Carrier was destroyed
##   DROPPED -> CARRIED   carry_by(): either Player's Unit touched it
##   CARRIED -> AT_HOME   seat_at(): its owner carried it into the own Base, or the Round restarted
##   DROPPED -> AT_HOME   seat_at(): the Round restarted
## Nothing moves a DROPPED Flag on its own (AC-3).
enum State {
	## Standing on its Base's seat, where seat_at() put it. The state at _ready().
	AT_HOME,
	## Riding on a Unit, the Carrier: carrier is that Unit.
	CARRIED,
	## Standing where drop_at() put it, where its Carrier was destroyed, until a Unit touches it.
	DROPPED,
}

## The Area3D that reports Units touching the Flag (physics layer 4 "flags", mask 2
## "units", a 1 m sphere): is_touching() reads it. The scene sets it to the PickupZone child.
@export var pickup_zone: Area3D

## The body mesh apply_color() paints in the owning Player's colour. The scene sets it to the
## Body child; the steel parts are not exported because nothing paints them.
@export var body_mesh: MeshInstance3D

## Where the Flag is (State): AT_HOME from _ready() until the controller moves it. Read-only:
## assigning to it pushes an error and changes nothing; it moves only through carry_by(), drop_at()
## and seat_at().
var state: State:
	get:
		return _state
	set(_value):
		push_error("Flag '%s': state is read-only. Move the Flag with carry_by(), drop_at() or seat_at()." % name)

## The Unit carrying the Flag while state is CARRIED, null otherwise. Read-only like state:
## assigning to it pushes an error and changes nothing.
var carrier: Unit:
	get:
		return _carrier
	set(_value):
		push_error("Flag '%s': carrier is read-only. Move the Flag with carry_by(), drop_at() or seat_at()." % name)

var _state: State = State.AT_HOME
var _carrier: Unit = null
## The node the Flag started under (its Base), read once in _ready() because reparent() does
## not run _ready() again. drop_at() and seat_at() put the Flag back under it.
var _home_parent: Node = null


func _ready() -> void:
	_home_parent = get_parent()
	if pickup_zone == null or body_mesh == null:
		push_error("Flag '%s': pickup_zone or body_mesh is not assigned, so the Flag can neither report a touch nor take a colour." % name)


## Paints the Body in the given material, a material_override on body_mesh only (the steel parts
## stay steel, so the Flag reads the same in both colours), so each Base's Flag shows whose
## it is (AC-1). The Base calls it in _ready() with the material it puts on its pad and beacon. The
## mesh resources are shared by every instance of the scene, so a material on the mesh would paint
## both Flags alike; the override is per instance. The material is shared too: never write to
## it.
func apply_color(material: Material) -> void:
	body_mesh.material_override = material


## True while the Unit overlaps the PickupZone, as the physics server last reported it (a tick or
## two late; class doc). Only a Unit in play counts: a destroyed Unit's collision layer is zero, so
## it leaves the list a tick after destroy(). The MatchController polls it once per physics tick
## for every Flag that is not CARRIED, and never for one that is.
func is_touching(unit: Unit) -> bool:
	return pickup_zone.overlaps_body(unit)


## Puts the Flag on the Unit (AC-2): state CARRIED, carrier the Unit, the node reparented under
## the Unit with its global pose discarded (reparent(unit, false)) and placed upright at the Unit's
## carry_offset in the Unit's local space, so it rides at a fixed place on the Unit from the next
## drawn frame (class doc). The PickupZone keeps monitoring; the controller stops asking. Call it
## from a physics tick, with a Unit whose can_carry is true, once per pick-up: the rules (who may
## pick up what) are decided before the call, nothing here checks them.
func carry_by(unit: Unit) -> void:
	_state = State.CARRIED
	_carrier = unit
	reparent(unit, false)
	transform = Transform3D(Basis.IDENTITY, unit.carry_offset)


## Stands the Flag where its Carrier was destroyed (AC-3): state DROPPED, no carrier, the node
## back under its home parent (only when it is not already there), upright with its origin, the
## centre of its base, at the given global position, then reset_physics_interpolation() so the
## drawn Flag makes one jump from the wreck to the ground and no streak. It stays there until
## carry_by() or seat_at(): nothing here moves it home. Call it from a physics tick with the
## Unit's global position; the Unit is still at the wreck when its `destroyed` fires.
func drop_at(at: Vector3) -> void:
	_state = State.DROPPED
	_carrier = null
	_return_home()
	global_transform = Transform3D(Basis.IDENTITY, at)
	reset_physics_interpolation()


## Stands the Flag on its Base's seat: at the start of a Round (AC-1), when its owner carries
## it into the own Base (AC-4) and at a restart. State AT_HOME, no carrier, the node back under its
## home parent (only when it is not already there), its global transform the given seat (a Base's
## flag_seat; a Base turns about the up axis only, so the seat stands upright), then
## reset_physics_interpolation(). Call it from a physics tick, or from begin() before the first.
func seat_at(seat: Transform3D) -> void:
	_state = State.AT_HOME
	_carrier = null
	_return_home()
	global_transform = seat
	reset_physics_interpolation()


## Reparents the Flag under its home parent when it is somewhere else (on a Unit): the
## re-insertion of the PickupZone into the physics world is what lets it report a Unit standing on
## the Flag again (class doc). Nothing when it is already home, so a seat_at() at the start of
## the Round moves nothing in the tree.
func _return_home() -> void:
	if get_parent() != _home_parent:
		reparent(_home_parent, false)
