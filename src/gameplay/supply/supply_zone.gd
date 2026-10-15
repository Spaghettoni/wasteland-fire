class_name SupplyZone
extends Area3D
## A supply zone: a marked place on the ground in front of a supply building where a Unit that
## has stopped is topped up, gradually, for as long as it stands there. Map 01's depot is the
## Fuel building, with a Fuel zone on each of its two Base-facing sides; its two ammunition
## buildings, one on each half of the Map, each have an ammunition zone on the side that faces the
## centre.
##
## Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-2 (the zone is drawn
## on the ground), AC-3 (a Unit that has stopped in a Fuel zone refuels from empty to full in
## about 4 s; stopped means a real speed of about zero; both Players at one zone at once; a zone
## never runs dry), AC-4 (a hovering Gyrocopter refuels as a ground Unit does) and AC-6 (every
## value is data); production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-1 (an
## ammunition zone is drawn on the ground), AC-2 (a Unit that has stopped in it rearms from empty
## to a full load in about 4 s, ammo only), AC-3 (a hovering Gyrocopter rearms as a ground Unit
## does) and AC-5 (every value is data); design/rules.md "Supply buildings" (the author's comment 8
## of 2026-10-10: ammo and fuel are refilled only at the buildings meant for it, in a zone right in
## front of each). Vocabulary: CONTEXT.md (Fuel, Ammo, Unit, Gyrocopter, Map).
##
## The zone acts on its own and calls down, as the Ford does. Once per physics tick, in its own
## _physics_process, it reads get_overlapping_bodies() and gives every Unit that qualifies a share
## of the refill: a Fuel zone through Unit.refuel(), the Unit's fuel_capacity over SupplySettings.
## fuel_seconds_to_full, times delta, so a stopped Unit fills from empty to full in that time less
## its own standing burn; an ammunition zone through Weapon.rearm() of that Unit's Weapon, the
## capacity in Shots the Weapon reports over SupplySettings.ammo_seconds_to_full, times delta (a
## whole Shot at a time, the fraction kept by the Weapon), so a stopped Unit fills from empty to a
## full load in that time, nothing being spent while it stands. Nothing is owned and nothing is
## stocked: the zone never runs dry, it serves every qualifying Unit of both Players on the same
## tick, and it holds nothing that a Round that starts again has to restore, for it keeps only the
## list of its last tick. It reads no input, emits nothing, never moves a Unit and never calls the
## Round. A zone gives what its kind says and nothing else: a Fuel zone Fuel only, an ammunition
## zone Shots only, and neither gives Mines (the Truck's Mines stay apart) or hit points; no zone
## calls both.
##
## Who rearms whom (Story 024). The Weapons are handed to the zone, never found by a search of the
## tree: SplitScreen sets `weapons` to both Players' Weapons before the Round begins, and an
## ammunition zone rearms the Weapon whose `unit` is the Unit it lists. The zone sits under the Map,
## which World ticks before the Units, and a Weapon ticks just after its Unit (priority plus one),
## so a rearm lands before the Weapon's own tick: a Shot fired on the tick a Unit rolls off follows
## that tick's rearm.
##
## Who qualifies. A Unit that the zone lists on this tick and listed on its previous tick too, that
## is alive, and that has stopped. An entry seen on one tick alone is stale: the physics server
## keeps a teleported Unit at its old place for one more step, so a Unit destroyed in the zone and
## put on its Base is listed once more (FuelCan's rule, kept; Unit.refuel() adding nothing to the
## full tank a new Unit starts with is the second guard). The is_alive test is load-bearing for
## the same reason: the zone still lists a Unit on the tick it was destroyed or benched, and keeps
## a frozen list while the tree is paused; Unit.refuel() refusing a Unit out of play is the second
## guard. The Units are served in node-name order, because the engine's list order is not
## reproducible when two Units overlap on one tick.
##
## Stopped (reading 2026-10-10, read the way the Turret reads a target's motion). The horizontal
## length of the Unit's get_real_velocity(), the motion of its last move, is at most
## SupplySettings.stopped_speed. It is not the drive speed that picks the standing burn, which
## stays up for a Unit held against a tank with the throttle on: that Unit's real motion is zero, so
## it refuels, and one rolling through at any speed does not. A Gyrocopter hovering still counts.
## The zone sits under the Map, which World ticks before the Units, so it reads the velocity of the
## Unit's previous tick and refuels before the Unit burns in its own tick: a Gyrocopter hovering in
## a Fuel zone gains the refill less its standing burn and never reaches an empty tank.
##
## Polled, never signalled: there is no body_entered handler and monitoring is never toggled,
## because on this engine (Godot 4.7.2, Jolt) an Area3D's signal handler may not change monitoring
## and work done inside it cannot be ordered against a tick (the Story 004 evidence doc keeps the
## probe). The Round-over pause stops the zone with everything else (process_mode stays INHERIT).
##
## Latency (measured on 4.7.2 with Jolt; the Story 023 evidence doc keeps the runs). The zone
## reports the physics server's last step: it lists a Unit driven in 2 ticks after the Unit's box
## first overlaps its box, one spawned in it on the second tick after the spawn (and, by the rule
## above, gives to it on the third), and still lists a Unit 2 ticks after its box has left. A Unit
## that sets off is given Fuel on the tick it first moves and on none after it, because the zone
## reads its speed before the Unit's own tick.
##
## Which Units it lists is the mask: the zone is on no physics layer (layer 0: nothing detects it)
## and watches mask 18, ground Units (2) and Gyrocopters (16), so a benched or destroyed Unit
## (layer 0) is never listed. Its box is its own shape, made in _ready() from `size` (a new shape,
## never a write to a shared one), standing on the floor and reaching through both Heights: a
## Gyrocopter's body stays on the floor while only its model flies (Story 020), and the height
## covers its drawn model as well.
##
## The scene (supply_zone.tscn), origin on the floor at the zone's centre:
##   SupplyZone (this Area3D): layer 0, mask 18, monitoring on, settings data/supply_settings.tres
##     Box (CollisionShape3D): no shape in the scene; _ready() gives it a box of `size`, centred
##       half its height up
##     Marking (Node3D): the zone drawn on the ground, in both Players' views, in the Fuel bar's
##       amber (the ammunition building's scene gives its zone's Slab the pale yellow of the Shots'
##       tracer instead, as an override of the Slab's mesh)
##       Slab (MeshInstance3D): a flat box of unit footprint, scaled to the zone's x and z, its top
##         0.03 m up (10 mm over the depot's ring dashes at 0.02 m, the salt flat at 0.01 m), no
##         shadow
##       Edge (Node3D): 0.04 m up; _ready() lays the dashes of its edge here, 10 mm over the Slab
## Every dash shares the one mesh and its material, so the dashes of every zone are drawn together.
## No solid collision: an Area3D neither blocks nor pushes, so a zone changes no Unit's path.

## What a zone gives.
enum Kind {
	## Fuel, to the Unit's tank, over SupplySettings.fuel_seconds_to_full.
	FUEL,
	## Ammunition, to the Unit's Weapon, over SupplySettings.ammo_seconds_to_full (Story 024).
	AMMO,
}

## The shared tuning values (SupplySettings): the time from empty to full of each kind and the
## speed below which a Unit counts as stopped. supply_zone.tscn sets data/supply_settings.tres, which every
## zone shares; it is read-only at runtime. A zone with none, or with values first_problem()
## refuses, pushes one error in _ready() and gives nothing.
@export var settings: SupplySettings

## What this zone gives. Stored on each placed instance in the Map's scene.
@export var kind: Kind = Kind.FUEL

## The zone's box in metres: x and z the footprint (the marking is drawn as large), y the height
## from the floor up. Zero by default, so a placed zone must say it; every component must be above
## zero.
@export var size: Vector3 = Vector3.ZERO

## The CollisionShape3D that receives the box. The scene sets it to the Box child.
@export var zone_shape: CollisionShape3D

## The flat box of the marking, scaled to the footprint. The scene sets it to Marking/Slab.
@export var slab: Node3D

## The node the dashes of the edge are added under. The scene sets it to Marking/Edge.
@export var edge: Node3D

## The one mesh every dash shares, long side along x. The scene sets it.
@export var edge_dash: Mesh

## Metres from the middle of one dash to the next along a side; each side holds as many dashes as
## fit its length at this pitch, at least one, spread evenly. Must be above zero.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m") var edge_pitch: float = 0.0

## Metres from the zone's boundary to the middle line of the dashes, inside it.
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:m") var edge_inset: float = 0.0

## Both Players' Weapons, handed by SplitScreen before the Round begins (Story 024): an ammunition
## zone rearms the one whose `unit` is the Unit it lists. A Fuel zone does not read it, and an
## ammunition zone with none handed gives nothing.
var weapons: Array[Weapon] = []

## The Units the zone listed on its previous tick: a Unit listed now and then is no stale entry
## (class doc). Noted on every tick.
var _listed_before: Array[Unit] = []


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("SupplyZone '%s': %s, so the zone gives nothing." % [name, problem])
		set_physics_process(false)
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	zone_shape.shape = box
	zone_shape.position = Vector3(0.0, size.y / 2.0, 0.0)
	slab.scale = Vector3(size.x, 1.0, size.z)
	_lay_edge()


func _physics_process(delta: float) -> void:
	var listed: Array[Unit] = []
	for body: Node3D in get_overlapping_bodies():
		var unit: Unit = body as Unit
		if unit != null:
			listed.append(unit)
	listed.sort_custom(func(a: Unit, b: Unit) -> bool: return String(a.name) < String(b.name))
	var before: Array[Unit] = _listed_before
	_listed_before = listed
	for unit: Unit in listed:
		if before.has(unit) and unit.is_alive and _is_stopped(unit):
			_give(unit, delta)


## Gives the Unit its share of one tick. A Fuel zone: the Unit's tank over the time to full, times
## delta, through Unit.refuel() (which stops at the capacity and refuses a Unit out of play). An
## ammunition zone: the capacity in Shots of the Unit's Weapon over the time to full, times delta,
## through Weapon.rearm() (whole Shots, up to the capacity, the fraction kept; nothing for a Unit
## out of play, a gun with no count or a full one); a Unit none of the handed Weapons belongs to is
## given nothing.
func _give(unit: Unit, delta: float) -> void:
	match kind:
		Kind.FUEL:
			unit.refuel(unit.fuel_capacity / settings.fuel_seconds_to_full * delta)
		Kind.AMMO:
			for weapon: Weapon in weapons:
				if weapon.unit == unit:
					weapon.rearm(float(weapon.capacity) / settings.ammo_seconds_to_full * delta)


## True when the Unit's real horizontal speed is at most settings.stopped_speed (class doc).
func _is_stopped(unit: Unit) -> bool:
	var velocity: Vector3 = unit.get_real_velocity()
	return Vector2(velocity.x, velocity.z).length() <= settings.stopped_speed


## Lays the dashes of the zone's edge under `edge`: four sides, a row of dashes along each at
## edge_pitch, edge_inset inside the boundary, all sharing edge_dash. Those along z are turned a
## quarter round.
func _lay_edge() -> void:
	var inner: Vector2 = Vector2(size.x, size.z) / 2.0 - Vector2(edge_inset, edge_inset)
	for side: int in 4:
		var along_x: bool = side < 2
		var length: float = size.x if along_x else size.z
		var across: float = (inner.y if along_x else inner.x) * (-1.0 if side % 2 == 0 else 1.0)
		var count: int = maxi(roundi(length / edge_pitch), 1)
		for index: int in count:
			var along: float = (index + 0.5) * length / count - length / 2.0
			var dash: MeshInstance3D = MeshInstance3D.new()
			dash.mesh = edge_dash
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if along_x:
				dash.position = Vector3(along, 0.0, across)
			else:
				dash.position = Vector3(across, 0.0, along)
				dash.rotation.y = PI / 2.0
			edge.add_child(dash)


## The reason this zone cannot run, or an empty String when it can: settings that are missing or
## refused, a size with a component not above zero, a pitch not above zero, or an export the scene
## did not assign. Written `not (x > 0.0)`, so a NaN is refused too.
func _first_problem() -> String:
	if settings == null:
		return "settings is not assigned"
	var problem: String = settings.first_problem()
	if not problem.is_empty():
		return "settings: " + problem
	if not (size.x > 0.0 and size.y > 0.0 and size.z > 0.0):
		return "size has a component not above zero"
	if not (edge_pitch > 0.0):
		return "edge_pitch is not above zero"
	if zone_shape == null:
		return "zone_shape is not assigned"
	if slab == null:
		return "slab is not assigned"
	if edge == null:
		return "edge is not assigned"
	if edge_dash == null:
		return "edge_dash is not assigned"
	return ""
