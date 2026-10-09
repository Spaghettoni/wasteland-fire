class_name Mine
extends Area3D
## A Mine laid by a Truck: it blinks in its owner's Team colour and is harmless while it arms,
## then shines steadily and, once live, destroys at once every ground Unit standing on it, its
## owner's included, and is gone in a short flash.
##
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-3 (a new Mine blinks in
## its owner's Team colour for the arming time and is harmless, then shines steadily and is live;
## both Players see every Mine), AC-4 (a live Mine destroys every ground Unit on it at once, a full
## Truck too, and is gone in a flash; the Gyrocopter never sets it off, Shots fly over it, and a
## Unit that respawns after a Mine kill sets off no Mine where it was destroyed), AC-6 (a Mine's
## kill is an ordinary destruction), AC-7 (a Mine stays when its Truck is gone; R removes it) and
## AC-9 (every value is data: MineSettings); design/rules.md "Turrets, Flag Walls and Mines".
## Vocabulary: CONTEXT.md (Mine, Truck, Unit, Gyrocopter, Flag, Round).
##
## The Mine acts on its own and calls down. Once per physics tick, in its own _physics_process, it
## reads get_overlapping_bodies() and, when it is live, calls Unit.destroy() on every Unit that is
## alive and was listed on its previous tick as well: that is the whole rule. destroy(), never
## apply_damage() through the damage matrix, because a Truck at full hit points must go too (the
## board: "even a Truck"). It reads no input, emits nothing, moves nothing and never calls the
## Round: the MatchController hears the Unit's destroyed signal and does the rest (the Token, a
## Carrier's Flag, the loss).
##
## Polled, never signalled, as Ford and FuelCan are: on this engine (Godot 4.7.2, Jolt) a handler
## of an Area3D's signal may not reparent, and destroy() makes the controller reparent a Carrier's
## Flag, so it is called from this node's own tick and never from a physics signal. The list is
## noted on every tick, arming ones included.
##
## Who sets it off. The zone is on no physics layer (layer 0: nothing detects it) and watches mask
## 2 alone, the ground Units' layer, so the Gyrocopter (layer 16) is never listed and flies over
## with no type check anywhere, and a Unit that is destroyed or benched (layer 0) drops out of the
## list. Shots test bodies only, so they fly through. A Unit sets it off when the zone lists it on
## this tick and listed it on the Mine's previous tick too: an entry seen on one tick alone is
## stale, because the physics server keeps a teleported Unit at its old place for one more step,
## so a Unit destroyed on a Mine and respawned at its Base is listed here once, at the old place,
## and must not set it off (as FuelCan's touch rule). The zone also lists a destroyed Unit for a
## tick, so every Unit it destroys is tested with is_alive. A Unit still on a Mine when it goes
## live is destroyed on the tick it does. The engine's list order is not reproducible when two
## Units are on one Mine, so the victims are destroyed in node-name order. A Mine that destroyed
## nobody (every listed Unit was already gone) stays live: stacked Mines spend one per Unit.
##
## Latency: the zone lists a Unit a tick after its box first overlaps the trigger, and the touch
## rule needs two listings, so a Unit moving over a Mine is destroyed three or four ticks after its
## box first touches it (the Story 014 evidence doc keeps the measurement).
##
## Time is counted in this node's own ticks, a counter its _physics_process raises, never in
## Engine.get_physics_frames(), which keeps counting under the Round-over pause: a Round that ends
## freezes every Mine. The durations are MineSettings seconds rounded to ticks as the Weapon rounds
## its cadence, never under one tick. The first tick is the one after the Mine entered the tree.
##
## Ordering: the priority stays 0. A Mine is a child of World added after the Units, so in every
## frame it ticks after them and before the MatchController (World comes first among the launch
## scene's children): its kill is in the ledger when that frame's loss check reads it, so a Mine and
## a Self-destruct that take both Players' last Motorbike in one frame make one double loss. A
## priority above 0 would split that over two frames.
##
## The scene (mine.tscn), origin on the ground at the drop point, its root in the node group
## "mines" (the scene stores it; SplitScreen frees the group at every restart):
##   Mine (this Area3D): layer 0, mask 2, monitoring on, settings data/mine_settings.tres
##     Trigger (CollisionShape3D): a cylinder of trigger_radius and trigger_height standing on the
##       ground, made in _ready() from the settings, a new shape for every Mine
##     Body (MeshInstance3D): the disc, a thin cylinder of unit radius drawn 0.03 to 0.07 m above
##       the ground (clear of the terrain's 0.01 m and a ford's 0.02 m) and scaled in _ready() to
##       trigger_radius; lay() gives it its owner's Team material, so what a Player sees is what
##       sets the Mine off, and it blinks by being shown and hidden
##     Flash (MeshInstance3D): an unshaded pale yellow ball of unit radius scaled in _ready() to
##       flash_radius, hidden until the Mine goes off
## Every Mine shares one disc mesh, one flash mesh and, per Player, one material.

## What a Mine is doing. The table is complete; a pair it does not list cannot happen.
enum State {
	## Blinking in the owner's colour and harmless. The state at _ready().
	ARMING,
	## Shining steadily and live: destroys the Units on it.
	LIVE,
	## Gone off: the flash shows for flash_seconds, then the Mine frees itself.
	SPENT,
}
# ARMING -> LIVE   the arming time has run out
# LIVE   -> SPENT  its tick found a Unit on it and destroyed it (every Unit on it)

## The shared tuning values (MineSettings): mine.tscn sets data/mine_settings.tres, which every
## Mine and both MineLayers share, so it is read-only at runtime. A Mine whose settings fail
## first_problem() pushes one error in _ready() and does nothing.
@export var settings: MineSettings

## The cylinder the Mine polls through the Area3D: its shape is made in _ready().
@export var trigger_shape: CollisionShape3D

## The disc: shown while the Mine is lit, hidden while it blinks dark, hidden once it is spent.
## A MeshInstance3D, because lay() gives it its owner's material (material_override).
@export var body: MeshInstance3D

## The flash of a spent Mine, hidden until it goes off.
@export var flash: Node3D

## The Player who laid this Mine (0 is Player 1), set by lay(): -1 for a Mine nobody laid. Only
## the colour and the record read it: a Mine sets off for every ground Unit, its owner's included.
var player_index: int = -1

## What the Mine is doing (State). Read-only: assigning to it pushes an error and changes nothing.
var state: State:
	get:
		return _state
	set(_value):
		push_error("Mine '%s': state is read-only. A Mine arms with time and goes off under a Unit." % name)

var _state: State = State.ARMING
## This node's own ticks since it entered the tree.
var _ticks: int = 0
var _arming_ticks: int = 0
var _period_ticks: int = 1
var _lit_ticks: int = 0
var _flash_ticks: int = 0
var _flash_left: int = 0
## The Units the zone listed on the previous tick (see the class doc, "Who sets it off").
var _listed_before: Array[Unit] = []


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("Mine '%s': %s, so it never goes live." % [name, problem])
		set_physics_process(false)
		return
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = settings.trigger_radius
	cylinder.height = settings.trigger_height
	trigger_shape.shape = cylinder
	trigger_shape.position = Vector3.UP * settings.trigger_height / 2.0
	body.scale = Vector3(settings.trigger_radius, 1.0, settings.trigger_radius)
	flash.scale = Vector3.ONE * settings.flash_radius
	var ticks_per_second: int = Engine.physics_ticks_per_second
	_arming_ticks = maxi(roundi(settings.arming_seconds * ticks_per_second), 1)
	_period_ticks = maxi(roundi(settings.blink_period_seconds * ticks_per_second), 1)
	_lit_ticks = roundi(_period_ticks * clampf(settings.blink_lit_fraction, 0.0, 1.0))
	_flash_ticks = maxi(roundi(settings.flash_seconds * ticks_per_second), 1)


func _physics_process(_delta: float) -> void:
	_ticks += 1
	var touching: Array[Unit] = _touching_units()
	if _state == State.ARMING:
		if _ticks < _arming_ticks:
			body.visible = (_ticks - 1) % _period_ticks < _lit_ticks
			return
		_state = State.LIVE
		body.visible = true
	if _state == State.LIVE:
		_detonate(touching)
		return
	_flash_left -= 1
	if _flash_left <= 0:
		queue_free()


## Puts the Mine on the ground at a place, for the Player who laid it, in that Player's Team
## material (the laying Unit's team_material, shared by every Mine of the Player). Call it right
## after the Mine entered the tree, in the tick of the lay. It also resets the physics
## interpolation: a Mine moved in the tick it entered the tree is drawn in place anyway, but one
## laid a tick or more later was drawn 26 to 47 m off its place on its first frame without the
## reset (measured windowed; the Story 014 evidence doc keeps the runs).
func lay(at: Vector3, owner_index: int, team_material: Material) -> void:
	global_position = at
	player_index = owner_index
	body.material_override = team_material
	reset_physics_interpolation()


## The Units the zone lists on this tick that it listed on the previous tick too, in the zone's
## order. Notes this tick's list for the next tick.
func _touching_units() -> Array[Unit]:
	var listed: Array[Unit] = []
	var touching: Array[Unit] = []
	for node: Node3D in get_overlapping_bodies():
		var unit: Unit = node as Unit
		if unit == null:
			continue
		listed.append(unit)
		if _listed_before.has(unit):
			touching.append(unit)
	_listed_before = listed
	return touching


## Destroys every live Unit among the touching ones, in node-name order, and goes off when it
## destroyed any: SPENT, the disc hidden, the flash shown. A Mine whose touching Units are all gone
## stays live.
func _detonate(touching: Array[Unit]) -> void:
	var victims: Array[Unit] = []
	for unit: Unit in touching:
		if unit.is_alive:
			victims.append(unit)
	if victims.is_empty():
		return
	victims.sort_custom(_name_sorts_first)
	for unit: Unit in victims:
		unit.destroy()
	_state = State.SPENT
	_flash_left = _flash_ticks
	body.visible = false
	flash.visible = true


## True when the first Unit's node name sorts before the second's (the order of a blast).
func _name_sorts_first(first: Unit, second: Unit) -> bool:
	return String(first.name) < String(second.name)


## What is wrong with the exports and the settings, as a sentence, or an empty string.
func _first_problem() -> String:
	if settings == null:
		return "settings is not assigned"
	if trigger_shape == null or body == null or flash == null:
		return "trigger_shape, body and flash must all be assigned"
	return settings.first_problem()
