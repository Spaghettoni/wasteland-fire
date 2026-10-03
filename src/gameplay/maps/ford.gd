class_name Ford
extends Area3D
## A shallow ford on a Map: a zone that holds every live ground Unit inside it to a fraction of
## its type's top speed (FordSettings.speed_fraction) and lets it go once it has left.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-5 (inside either ford a
## ground Unit's speed is clamped to its type's top speed times the ford speed fraction; the cap
## lifts once the Unit has left and the Unit then accelerates as usual; the Gyrocopter crosses at
## full speed) and AC-9 (the fraction is data in the Map: FordSettings); the blueprint's legend
## "Shallow ford: creek, vehicles slowed" (design/source/map01_blueprint.png) and the author's
## answer of 2026-10-02 to the story's open question 2; design/rules.md "Units". Vocabulary:
## CONTEXT.md (Map, Unit, Gyrocopter).
##
## The ford acts on its own and calls down. Once per physics tick, in its own _physics_process, it
## reads get_overlapping_bodies() and calls Unit.limit_speed(settings.speed_fraction) on every
## listed Unit that is alive: that is the whole rule. The Unit holds the cap on the tick of the
## call and the next one and drops it by itself (Unit, movement model step 6), so nothing here
## tracks who came in or left and nothing switches a cap off. The ford reads no input, emits
## nothing, never moves a Unit and never calls the Round. The is_alive test matters: the zone
## still lists a Unit on the tick after it was destroyed or benched.
##
## Polled, never signalled: there is no body_entered handler and monitoring is never toggled,
## because on this engine (Godot 4.7.2, Jolt) an Area3D's signal handler may not change monitoring
## and work done inside it cannot be ordered against a tick (the Story 004 evidence doc keeps the
## probe).
##
## Which Units it slows is data: the zone is on no physics layer (layer 0: nothing detects it) and
## watches mask 2 alone, the ground Units' layer, so the Gyrocopter (layer 16) is never listed and
## crosses at full speed, with no type check anywhere.
##
## Latency (measured on 4.7.2; the Story 007 evidence doc keeps the run). The zone reports the
## physics server's last step: it lists a Unit on the tick after the Unit's box first overlaps the
## zone and drops it on the tick after the box has left. With the ford before the Units in the
## tree (the Map is World's first child and holds its fords) the cap bites on the second tick
## after the box first overlaps the zone (on the third with the ford after the Units), and in
## either order it lifts on the third tick after the box has wholly left: the late listing plus
## the cap's one tick of grace. A Unit at 24 m/s is never skipped, and the held speed is exactly
## the fraction of the type's top speed. A test of each Unit's position in place of the zone was
## measured too: it lifts the cap two ticks after the Unit's centre leaves, which is too early for
## AC-5's window, so it is not used.
##
## The scene (ford.tscn), origin on the floor at the ford's centre; the ford bed is the Map's plain
## floor:
##   Ford (this Area3D): layer 0, mask 2, monitoring on, settings data/ford_settings.tres
##     CollisionShape3D: a box 12 m across (x), 3 m tall and 40 m long (z), centred 1.5 m up so it
##       stands on the floor; its edges are the ford's edges, not padded
##     Water (MeshInstance3D): the greybox water, a 12 x 40 m plane 0.02 m above the floor, over
##       the ground surfaces below it, translucent cyan from the shared material file
##       maps/map_01/materials/ford.tres, casting no shadow
## No solid collision: an Area3D neither blocks nor pushes, so a ford changes no Unit's path.

## The shared tuning values (FordSettings): the fraction of a ground Unit's top speed the ford
## allows. ford.tscn sets data/ford_settings.tres, which every ford shares, so the fords of a Map
## tune together; it is read-only at runtime. A ford with no settings, or with a speed_fraction
## outside (0, 1], pushes one error in _ready() and slows nothing.
@export var settings: FordSettings


func _ready() -> void:
	if settings != null and settings.speed_fraction > 0.0 and settings.speed_fraction <= 1.0:
		return
	push_error("Ford '%s': settings is not assigned or its speed_fraction is outside (0, 1], so the ford slows nothing." % name)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		var unit: Unit = body as Unit
		if unit != null and unit.is_alive:
			unit.limit_speed(settings.speed_fraction)
