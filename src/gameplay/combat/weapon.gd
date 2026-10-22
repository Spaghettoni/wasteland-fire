class_name Weapon
extends Node
## The one weapon of a Unit: while its trigger is held it fires a Shot straight ahead along the
## Unit's heading, from the muzzle at the shooting height, at the Unit type's fire rate, until the
## load of ammunition the Unit started its life with is spent.
##
## Implements: design/game-brief.md MVP feature 5 (one weapon each that fires straight ahead at one
## height, so turning is aiming; the Carrier can shoot) and
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3 (every Unit has one
## weapon, fired with one key per Player, that fires straight ahead at the one shooting height all
## Units share; the fire rate and range are data), AC-4 (the shot carries the attacker's damage and
## the matrix) and AC-7 (the Carrier shoots like anyone: nothing here looks at the cargo);
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-1 to AC-3, AC-5 and AC-6 (a
## load of ammunition per Unit type, one Shot spent by every Shot; a Unit with none left fires
## nothing; every new Unit starts with a full load; the Turrets and the Mines are apart);
## design/rules.md "Units", "Resources" and "Destruction and respawn". Vocabulary: CONTEXT.md
## (Player, Unit, Carrier, Ammo).
##
## Driven by command, not by input, like the Unit: whoever holds the trigger (PlayerFireInput for
## a Player, later a bot or a test) calls set_trigger() every physics tick, and the weapon reads
## nothing from the Input singleton. One Weapon per Player's Unit, stored in split_screen.tscn
## beside the input nodes; it knows its Unit, the MatchRules and the Shot scene and nothing else.
##
## Every number is data: the damage, the fire interval, the range, the shot speed, the muzzle
## offset and the load are the Unit's current UnitStats (read live, so a Unit respawned as another
## type fires that type's weapon, with that type's load, from the same node), the shooting height
## and the layers that stop a shot are MatchRules (shooting_height, shot_collision_mask) and the
## multipliers are MatchRules.damage_matrix. The muzzle is the Unit's origin plus muzzle_forward
## along its facing (-Z of its basis) plus shooting_height up.
##
## Cadence, in physics frames, never seconds: a shot is fired on a tick when the trigger is held,
## the Unit is alive, a Shot is left and Engine.get_physics_frames() has reached the next-fire
## frame; that frame is then set to now plus the interval in ticks, at least one. A held trigger
## gives exact spacing (a Buggy held for 3 s fired 8 shots exactly 24 ticks apart for its 0.4 s on
## 4.7.2; the Story 005 evidence doc keeps the run) and press-release-press cannot beat it. A
## destroyed or benched Unit fires nothing, and PlayerFireInput arms the trigger only once the key
## was seen up since the Unit came alive, so the confirm of a Unit choice (the same key) is never a
## shot.
##
## The load (Story 022). The count of a life belongs to this node, the MineLayer's way, not to the
## Unit. On the first tick it finds the Unit alive after a tick it was not (and on its own first
## tick), the Weapon refills the count to the type's ammo_capacity and emits ammo_changed; on the
## first tick it finds the Unit out of play it zeroes both the count and the capacity it reports and
## emits ammo_changed with (0, 0). The Round never puts a Unit in play that is already in play, so
## every spawn, respawn and Swap is seen, and a destroyed or benched Unit keeps its stats until its
## next spawn, which is why the capacity is read at the refill and not asked of the Unit later: a
## dead Truck's stats still say 25. A Unit that dies with Shots left does not carry them into its
## next life, and one that dies empty does not come back empty. The follow-up runs at the top of the
## tick, before the early return for a released trigger or a dead Unit, so the refill comes before
## any decision to fire and a new Unit never fires on a stale count. Each Shot spends one, once it
## is launched (a scene that is not a Shot fires nothing and spends nothing). A Weapon with none
## left fires nothing and its refusals stamp no cadence, so they never hold a new Unit back; the
## cadence of the last real Shot still counts across lives, as it did before the story. A type whose
## ammo_capacity is zero has no count at all: the Weapon counts, spends and emits nothing, and fires
## bit for bit as before Story 022. The Turrets have no Weapon and keep unlimited ammunition, and
## the MineLayer's Mines are a count of their own: a Shot never takes a Mine and a lay never spends
## a Shot.
##
## out_of_ammo goes out on the tick the last Shot goes and on every tick the trigger goes from
## released to held while the Unit in play has none left, so a key held down says it once, not once
## per tick (the Weapon notes the last tick's trigger). rearm() is for the supply zones: it adds
## Shots up to the capacity and keeps the fraction, so a zone that gives 25 Shots a second can call
## it every tick with 0.4167.
##
## Ordering: _ready() sets process_physics_priority one above the Unit's own (higher runs later),
## so the muzzle is where the Unit stands after its own move of this tick, and PlayerFireInput
## sits one below this node, so a press reaches the weapon in the tick it is read. The Shot is
## added to the Unit's parent and launched in the same tick, as Shot requires; it then owns
## itself (and is where the damage is applied, from its own tick: see Shot). The process_mode
## stays INHERIT, so a paused tree stops the weapon with everything else.

## Emitted from this node's tick when the count or the capacity changes: a Shot, a new Unit in
## play, a rearm that added a Shot, the Unit leaving play (with 0 and 0). It is for display: a
## handler shows the numbers.
signal ammo_changed(shots_left: int, capacity: int)

## Emitted from this node's tick on the tick the last Shot of a load goes and on every tick the
## trigger goes from released to held while the Unit in play has no Shot left (a type with no count
## never says it). It is for display: a handler tells the Player.
signal out_of_ammo

## Added to the Unit's process_physics_priority so this node runs just after it.
const PRIORITY_OFFSET: int = 1

## The Unit this weapon belongs to. Assign it before this node enters the tree.
@export var unit: Unit

## The Round's tuning values: shooting_height, shot_collision_mask and damage_matrix. Required. The
## resource is shared, so never write to it at runtime.
@export var rules: MatchRules

## The Shot scene (shot.tscn) this weapon instances for every shot. Required.
@export var shot_scene: PackedScene

## Shots left in the load: the type's ammo_capacity after a spawn, down by one for every Shot fired,
## zero while the Unit is out of play and for a type with no count. Read-only: assigning to it
## pushes an error.
var shots_left: int:
	get:
		return _left
	set(_value):
		push_error("Weapon '%s': shots_left is read-only. A Shot takes one; a new Unit refills it." % name)

## The load of the Unit in play: its type's ammo_capacity, zero while the Unit is out of play and
## for a type with no count. Read-only like shots_left.
var capacity: int:
	get:
		return _capacity
	set(_value):
		push_error("Weapon '%s': capacity is read-only. It is the Unit type's data." % name)

var _trigger: bool = false
## The high trigger (Story 041): held, the Weapon fires high shots, at the same cadence and from the
## same load as the low ones; with both held the high one wins.
var _trigger_high: bool = false
## Whether the trigger was held on the previous tick, to tell a new press from a held key.
var _was_held: bool = false
## The physics frame from which the next shot may be fired; zero lets the first held tick fire.
var _next_fire_frame: int = 0
var _left: int = 0
var _capacity: int = 0
var _in_play: bool = false
## The fraction of a Shot rearm() has been given and not yet turned into a whole one.
var _carry: float = 0.0


func _ready() -> void:
	if unit == null:
		push_error("Weapon '%s': unit is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if rules == null:
		push_error("Weapon '%s': rules is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if rules.damage_matrix == null:
		push_error("Weapon '%s': rules.damage_matrix is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if shot_scene == null:
		push_error("Weapon '%s': shot_scene is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	_follow_unit()
	var held: bool = _trigger or _trigger_high
	var pressed: bool = held and not _was_held
	_was_held = held
	if not held or not is_instance_valid(unit) or not unit.is_alive:
		return
	if _capacity > 0 and _left <= 0:
		if pressed:
			out_of_ammo.emit()
		return
	var now: int = Engine.get_physics_frames()
	if now < _next_fire_frame:
		return
	_fire(_trigger_high)
	var interval_ticks: int = roundi(
			unit.stats.fire_interval_seconds * Engine.physics_ticks_per_second)
	_next_fire_frame = now + maxi(interval_ticks, 1)


## Holds or releases the trigger: true fires at the cadence from this tick on, false stops. Call
## it every physics tick before this node's own tick (see PlayerFireInput); the value stays until
## the next call.
func set_trigger(held: bool) -> void:
	_trigger = held


## Holds or releases the high trigger (Story 041): high shots, stopped by MatchRules.high_shot_collision_mask.
func set_high_trigger(held: bool) -> void:
	_trigger_high = held


## Adds Shots to the load of the Unit in play, up to its capacity, and returns the whole Shots it
## added (the class doc): the fraction of a Shot stays in a carry that the next call adds to, so a
## zone that gives 25 Shots a second calls it with 0.4167 every tick and a whole Shot comes every
## 2.4 ticks. ammo_changed goes out once for a call that adds a Shot. Returns 0, and keeps nothing,
## for a Unit out of play, a type with no count, a full load and an amount that is not above zero
## (a NaN included); a full load and the Unit leaving play clear the carry. Call it from a tick.
func rearm(shots: float) -> int:
	if not _in_play or not is_instance_valid(unit) or not unit.is_alive:
		return 0
	if _capacity <= 0 or _left >= _capacity or not (shots > 0.0):
		return 0
	_carry += minf(shots, float(_capacity))
	var whole: int = floori(_carry)
	if is_equal_approx(_carry, float(whole + 1)):
		whole += 1
	whole = mini(whole, _capacity - _left)
	_carry = maxf(_carry - float(whole), 0.0)
	_left += whole
	if _left >= _capacity:
		_carry = 0.0
	if whole > 0:
		ammo_changed.emit(_left, _capacity)
	return whole


## Fires one Shot from the muzzle along the Unit's facing with the Unit type's weapon values and
## the Round's, added to the Unit's parent and launched in this tick, and spends one Shot of the
## load.
func _fire(high: bool) -> void:
	var stats: UnitStats = unit.stats
	var facing: Vector3 = -unit.global_transform.basis.z.normalized()
	var muzzle: Vector3 = (unit.global_position + facing * stats.muzzle_forward
			+ Vector3.UP * rules.shooting_height)
	var instance: Node = shot_scene.instantiate()
	var shot: Shot = instance as Shot
	if shot == null:
		if instance != null:
			instance.free()
		push_error("Weapon '%s': shot_scene '%s' is not a Shot scene, so it fires nothing." % [
				name, shot_scene.resource_path])
		return
	unit.get_parent().add_child(shot)
	shot.launch(unit, muzzle, facing, stats.damage, stats.shot_speed, stats.weapon_range,
			rules.damage_matrix, rules.shot_mask(high))
	if high:
		shot.lift_tracer(rules.high_shot_lift)
	_spend()


## Takes one Shot off the load once a Shot has been launched, and says so; the last one also says
## out_of_ammo. A type with no count spends and says nothing.
func _spend() -> void:
	if _capacity <= 0:
		return
	_left -= 1
	ammo_changed.emit(_left, _capacity)
	if _left <= 0:
		out_of_ammo.emit()


## Refills the count when the Unit has come into play and zeroes it when the Unit has left play,
## each with one ammo_changed unless the numbers are what they were (the class doc, "The load").
func _follow_unit() -> void:
	var in_play: bool = is_instance_valid(unit) and unit.is_alive
	if in_play == _in_play:
		return
	_in_play = in_play
	_carry = 0.0
	var load_size: int = maxi(unit.stats.ammo_capacity, 0) if in_play else 0
	_report(load_size, load_size)


## Sets the count and the capacity and emits ammo_changed, unless both are what they were.
func _report(left: int, load_size: int) -> void:
	if left == _left and load_size == _capacity:
		return
	_left = left
	_capacity = load_size
	ammo_changed.emit(_left, _capacity)
