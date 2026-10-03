class_name Base
extends Node3D
## A Player's home on the Map: where that Player's Units start the Round and respawn. It holds the
## marker a Unit is put on (and the spare ones it is put on when that one is taken), an invisible
## zone over it, the Player's Flag on its seat, and the meshes in the Player's
## colour that show whose Base it is: a pad on the ground, a beacon that marks it from across the
## Map and any further parts the scene lists. Two scenes carry this script: the greybox Base of
## stories 003 to 006 (base.tscn) and Map 01's walled compound (map_01/compound_base.tscn, Story
## 007).
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1 (two
## greybox Bases stand on the plane, one per Player, visually distinct in the Player colours, each
## with a spawn point; each Player's Unit starts the Round at its own Base), AC-3 and AC-4 (a
## destroyed Unit always respawns at its Base: the spare spawn points are where it goes when
## another Unit stands on the spawn point) and that story's implementation notes (a Base is a scene
## with an Area3D zone, a Marker3D spawn point and a coloured greybox mesh; the Map instances two
## and hands the MatchController their references); design/rules.md "Destruction, respawn and unit
## swap" (a destroyed Unit respawns at its Player's Base);
## production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-1 (at Round start each
## Base holds one visible Flag in its Player's colour: the Flag child on its seat,
## painted in _ready()) and AC-4 (where the owner's Flag is re-seated: flag_seat);
## design/rules.md "Resources" (one Flag sits in each Base);
## production/epics/wasteland-fire/story-007-the-map.md AC-6 (Map 01's Bases are walled compounds
## with one gate that faces the centre, whose walls stop every Unit and every shot, with a Garage
## where the Units appear and the Flag's seat under a water tower: compound_base.tscn), AC-11 (a
## Base wears its Team colour where the illustrated drawing puts it, on the four corner towers and
## the dashed rectangle in front of the Garage and on the water tower's roof, its walls dark and its
## Garage rust: color_meshes)
## and AC-12 (the water tower's tank is the beacon, in place of story 003's pillar);
## design/rules.md "Teams and visual style". Vocabulary: CONTEXT.md (Player, Unit, Base, Map,
## Garage, Flag, Team colour: a Base holds that Player's Flag at the start of a Round).
##
## The greybox scene (base.tscn):
##   Base (this Node3D): its transform places and turns the whole Base
##     Pad (MeshInstance3D): a flat 12 x 12 m slab, 2 cm thick, a hair above the floor
##     Beacon (MeshInstance3D): a 1.5 x 8 x 1.5 m pillar on the pad's front right corner
##     SpawnPoint (Marker3D): the Base origin, facing local -Z
##     SpareSpawnLeft, SpareSpawnRight (Marker3D): 4 m left and right of the spawn point, facing
##       local -Z
##     Zone (Area3D): a 12 x 4 x 12 m box over the pad
##     FlagSeat (Marker3D): 4.5 m behind the spawn point (local +Z), on the pad, facing local -Z
##     Flag (an instance of flag.tscn): this Base's Flag, standing on the
##       seat
## Map 01's compound (compound_base.tscn), a walled yard 32 m across and 30 m deep, its gate in
## local -Z:
##   Base (this Node3D): its transform places and turns the whole Base, the gate to the centre
##     SpawnPoint, SpareSpawnLeft, SpareSpawnRight (Marker3D): on the Garage floor, 5 m behind
##       the Base origin (local +Z) and 4 m apart, facing local -Z, out of the Garage to the gate
##     Pad (MeshInstance3D): hidden, the Garage floor's 12 x 10 m footprint (first_spawn_problem()
##       measures the spawn points against it)
##     Zone (Area3D): a 29.4 x 4 x 27.5 m box over the inside of the walls
##     FlagSeat (Marker3D) and Flag: 7 m in front of the Base origin (local -Z), between
##       the water tower's four legs
##     Walls: the back wall, the two side walls, the two gate walls either side of the 11 m gate
##       and the four corner towers on the wall corners, each a StaticBody3D with its box and Mesh
##     Garage: its floor (GarageFloor), three walls, open to the gate and roofless, and Marking,
##       the dashed rectangle on the ground in front of it (Dash01 to Dash14, one shared mesh)
##     WaterTower: four legs (StaticBody3D), the Tank (MeshInstance3D), the beacon, its lowest
##       point 8 m or more up, above where the chase camera rides, its Roof (one of color_meshes)
##       and a steel platform, band and braces, all with no collision
## The script checks that the references are wired, paints the pad, the beacon, each mesh of
## color_meshes and the Flag's body in _ready(), and says whether its spawn points lie on its
## pad (first_spawn_problem()); a Base has no behaviour of its own. The Map places it, the
## MatchController asks it for spawn_point, spare_spawn_points, flag and flag_seat and
## polls zone (Story 004: a delivery into the own Base), and Story 005 listens to zone.
##
## Collision. In base.tscn only the Zone has a shape: a greybox Base is ground a Unit drives over,
## not an obstacle, and the Story 001 evidence harness drives on this same field: a solid slab or
## pillar in the playfield would change where its runs end. A Unit that drives into the Beacon
## passes through it: it is a landmark, there only so a Base can be found from anywhere on the
## 80 x 80 m field. It stands on the front right corner and not at the back edge, because a Unit's
## chase camera sits behind the Unit and a pillar behind the spawn point would stand between a
## Player and their own Unit. compound_base.tscn is walled: its walls, corner towers, Garage walls
## and the water tower's legs are StaticBody3D on physics layer 1 (the Map's) and stop every Unit,
## the Gyrocopter included, and every shot (Story 007 AC-6), so a Unit comes and goes through the
## gate; the pad, the tank, the Marking and the Garage floor have no shape, and the tank stands
## higher than the chase camera rides, so it never comes between a Player and their own Unit.
##
## Spawn points. A Unit is put down at spawn_point, or, when another Unit stands on spawn_point on
## the tick the respawn falls due, at the first free spare spawn point, on that same tick
## (MatchController). Every one of them must lie on the pad. first_spawn_problem() says whether
## they do, and the MatchController asks it when the Round begins and refuses to begin while it
## names a problem, so a Base that was moved without its spawn point is an error at launch and
## never a silent drift: GreyboxField points spawn_point at a loose marker, for a reason its
## comment gives, and nothing else ties the two. It is the start of the Round that asks, not
## _ready(): a tool that moves that loose marker before the field enters the tree (the Story 001
## drive harness does) must not raise an error in a scene that has no Round. In both scenes the two
## spares stand 4 m left and right of the spawn point, 8 m apart, so no Unit (the largest, the
## Truck, is 2.4 x 4.4 m) can stand on both of them and a Round of two Players always has a free
## spot.
##
## Player colour. The mesh resources are shared by every instance of a scene, so a material on the
## mesh would paint every Base alike. color_material is applied instead as a material_override on
## this instance's Pad and Beacon, on each mesh of color_meshes, and on the body of its Flag
## (Flag.apply_color(); its steel parts stay steel), in _ready(), and the Map sets it per
## instance: greybox_field.tscn gives the Bases the Player body materials of Story 002, and Map 01
## the Team colours of Story 007 (team_orange_material.tres for Base A, team_teal_material.tres for
## Base B). Because the override is per instance, compound_base.tscn's corner towers wear the Team
## colour while the walls, which share their material, stay dark.
##
## Zone. An Area3D on physics layer 3 ("zones", project.godot) that watches layer 2 ("units"). It
## reports Units entering and leaving and never touches them: no Unit's collision mask includes
## layer 3, so the zone neither blocks nor slows one. Story 004 consumes it (the MatchController
## polls zone.overlaps_body() once per physics tick for a Unit delivering a Flag to the
## own Base, or bringing its own home) and Story 005 (swapping Unit type at the own Base) will.
## What the zone watches is a Unit's collision layer, which Unit.destroy() zeroes and Unit.spawn()
## restores, so a Unit destroyed inside the zone leaves it and one spawned inside it enters it: a
## respawn at the own Base is an enter, and so is the first spawn of a Round. The physics server
## reports both on its own schedule: a tick after a layer change, about two after a Unit drives or
## is put in or out (measured on Godot 4.7.2 with Jolt; the Story 004 evidence doc keeps the runs),
## so a consumer polls and never counts on the same tick.
##
## Flag (built in Story 004 as the Water Canister, renamed in Story 008). Each Base holds its
## Player's Flag: the Flag child, an instance of flag.tscn, stands on FlagSeat at the start of the
## Round and whenever its owner brings it home, and _ready() paints its body in color_material so
## a Flag shows whose it is (AC-1). In base.tscn the seat is 4.5 m behind the spawn point (local
## +Z: a Unit on it faces -Z, away from it), inside the pad and the zone; in compound_base.tscn it
## is under the water tower, 12 m in front of the spawn points, inside the zone. Both are clear of
## the spawn point and both spares: the pick-up sphere is 1 m and a Unit at most 4.4 m long, so a
## Unit put on any spawn point does not touch its own Flag. The Base never moves the Flag: the
## MatchController seats it (seat_at() at flag_seat's global transform), gives it to a Unit and
## drops it where the Carrier was destroyed, and a dropped Flag stays a child of this Base wherever
## on the Map it lies.

## Where a Unit is put when it starts the Round or respawns at this Base: its global transform is
## the Unit's position and heading, the Unit facing the marker's local -Z as every Unit faces its
## own. Both scenes set it to the SpawnPoint child (at the Base origin in base.tscn, on the Garage
## floor in compound_base.tscn); a Map may point it at another Marker3D instead (GreyboxField
## does), and the SpawnPoint child then stays unused. It must lie on the pad (first_spawn_problem()
## reports it when it does not). The MatchController reads it.
@export var spawn_point: Marker3D

## Where a Unit is put when it respawns while another Unit stands on spawn_point: the
## MatchController tries them in this order, on the tick the respawn falls due, and uses the first
## free one, so a parked Unit cannot hold a respawn up (Story 003 AC-3 and AC-4). Each is a
## Marker3D whose global transform is the Unit's position and heading, like spawn_point, and each
## must lie on the pad. Optional, but a Base without one keeps a blocked Player waiting until the
## spawn point frees, and _ready() warns. Keep them clear of each other for the largest Unit (both
## scenes put two, 4 m left and right of the spawn point: class doc).
@export var spare_spawn_points: Array[Marker3D] = []

## The zone over the pad that reports Units entering and leaving this Base. The MatchController
## polls it once per physics tick for a delivery (Story 004), and Story 005 will for the Unit
## swap. Its layer (3, "zones") and mask (2, "units") are set in the scene.
@export var zone: Area3D

## The flat slab that marks the Base on the ground. It gets color_material in _ready(). No
## collision, by design. compound_base.tscn hides it (the Garage floor shows there) and keeps it
## because first_spawn_problem() measures the spawn points against its box, the Garage floor's.
@export var pad: MeshInstance3D

## What marks the Base from afar: base.tscn's tall pillar, compound_base.tscn's water tower tank
## (Story 007 AC-12). It gets color_material in _ready(). No collision, by design.
@export var beacon: MeshInstance3D

## This Base's Flag (Story 004 AC-1): the Flag child, an instance of
## flag.tscn, which starts the Round on flag_seat. Its body gets color_material in
## _ready(). The MatchController seats, carries and drops it; the Base never moves it, and a dropped
## Flag stays a child of this Base wherever on the Map it lies. The Round needs it: begin()
## reads it.
@export var flag: Flag

## Where this Base's Flag stands at the start of a Round and whenever it is brought home:
## its global transform is the Flag's (upright, the origin on the ground). base.tscn puts it
## 4.5 m behind the spawn point, on the pad, and compound_base.tscn under the water tower; both
## inside the zone and clear of the spawn point and both spares (class doc). The MatchController
## reads it.
@export var flag_seat: Marker3D

## The Player colour of this Base (on Map 01 its Team colour, Story 007 AC-11), put on the pad,
## the beacon and each mesh of color_meshes as a material_override, and on the Flag's body,
## when the Base enters the tree, so it is read once. Set it on each instance: neither scene
## carries one, because a default in the scene would leave two Bases alike (Story 003 AC-1).
@export var color_material: Material

## Further meshes that wear this Base's colour (Story 007 AC-11): compound_base.tscn lists its four
## corner towers and the dashes of the rectangle in front of its Garage, where the illustrated
## drawing puts the Team colour, and its water tower's roof. _ready() puts color_material on each
## as a material_override, per instance, so the walls, which share the corner towers' material,
## stay dark. Optional and empty by default: base.tscn lists none and paints what it always did.
## An entry that is not assigned is skipped with a warning.
@export var color_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	var missing: String = _first_unassigned()
	if not missing.is_empty():
		push_error("Base '%s': %s is not assigned, so the Base is not set up. A Base needs its spawn point, zone, pad and beacon." % [name, missing])
		return
	if spare_spawn_points.is_empty():
		push_warning("Base '%s': spare_spawn_points is empty, so a Player whose respawn is blocked by a Unit standing on the spawn point waits until the spawn point frees." % name)
	if color_material == null:
		push_warning("Base '%s': color_material is not assigned, so the pad and the beacon keep their default look and this Base cannot be told from the other one." % name)
		return
	pad.material_override = color_material
	beacon.material_override = color_material
	_paint_color_meshes()
	if flag == null or flag_seat == null:
		push_warning("Base '%s': flag or flag_seat is not assigned, so this Base holds no Flag to paint, and the Round needs both (MatchController.begin() reads them)." % name)
		return
	flag.apply_color(color_material)


## What is wrong with this Base's spawn points (spawn_point and the spares), as a sentence naming
## the first one, or an empty string when all are fine: a required reference that is not assigned,
## an entry that is not assigned or not in the tree, or a point that does not lie inside the
## footprint of the pad (the pad mesh's own box, so it holds for any pad size). The MatchController
## asks it when the Round begins. It judges where the points are at the moment it is called, so
## call it once the Base is in the tree. It moves and fixes nothing: a wrong Base is data for
## whoever placed it to correct.
func first_spawn_problem() -> String:
	var missing: String = _first_unassigned()
	if not missing.is_empty():
		return "Base '%s': %s is not assigned" % [name, missing]
	var points: Array[Marker3D] = [spawn_point]
	points.append_array(spare_spawn_points)
	var footprint: AABB = pad.get_aabb()
	for point: Marker3D in points:
		if point == null:
			return "Base '%s': spare_spawn_points has an entry that is not assigned" % name
		if not point.is_inside_tree() or not pad.is_inside_tree():
			return "Base '%s': spawn point '%s' or the pad is not in the tree" % [name, point.name]
		var at: Vector3 = pad.to_local(point.global_position)
		if at.x < footprint.position.x or at.x > footprint.end.x or at.z < footprint.position.z or at.z > footprint.end.z:
			return "Base '%s': spawn point '%s' is at (%.2f, %.2f) in the pad's frame, outside the %.1f x %.1f m pad (a Unit put there would start off the Base: move the spawn point with the Base)" % [
				name, point.name, at.x, at.z, footprint.size.x, footprint.size.z]
	return ""


## The name of the first required reference that is not assigned, or an empty string when all four
## are. color_material, color_meshes and the spare spawn points are not among them: a Base works
## without a colour, it only looks plain.
func _first_unassigned() -> String:
	if spawn_point == null:
		return "spawn_point"
	if zone == null:
		return "zone"
	if pad == null:
		return "pad"
	if beacon == null:
		return "beacon"
	return ""


## Puts color_material on each mesh of color_meshes as a material_override, on this instance only,
## so the parts that share a mesh or a material with it keep their own look. An entry that is not
## assigned is skipped with a warning that names its index.
func _paint_color_meshes() -> void:
	for index: int in color_meshes.size():
		var mesh: MeshInstance3D = color_meshes[index]
		if mesh == null:
			push_warning("Base '%s': color_meshes entry %d is not assigned, so that part keeps its own look." % [name, index])
			continue
		mesh.material_override = color_material
