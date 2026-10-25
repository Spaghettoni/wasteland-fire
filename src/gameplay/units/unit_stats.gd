class_name UnitStats
extends Resource
## Feel values and controller settings for one Unit type: the numbers a designer tunes to change
## how it drives, and the CharacterBody3D settings the Unit copies into its body.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-4: every feel value is read
## from a data resource (one .tres per Unit type), never hardcoded in a script. Story 003 AC-2
## (production/epics/wasteland-fire/story-003-bases-destruction-respawn.md) adds the hit points
## to the same file: max_hit_points is a tuning value here, not a literal in the Unit. Story 004
## AC-2 (production/epics/wasteland-fire/story-004-water-canister-and-win.md) adds the Cargo
## group: whether a Unit type carries the Flag, and where it rides, is data here too,
## so the Round rules never ask what type a Unit is.
##
## Story 005 AC-1, AC-2 and AC-9
## (production/epics/wasteland-fire/story-005-three-units-and-triangle.md; design/rules.md
## "Units") add the other three types and three groups: Identity (which type this is, for the
## damage matrix and the choice panel), Weapon (the one straight-ahead weapon every type has: its
## damage, cadence, range, shot speed and muzzle) and Body (whether it flies, its greybox model,
## its box collider and its physics layers). One .tres per type (data/motorbike_stats.tres,
## buggy_stats.tres, truck_stats.tres, gyrocopter_stats.tres) holds the source's starting values
## for the Round to hand a Unit at every spawn; the Motorbike keeps the movement Story 001 tuned
## by playing (decided 2026-10-01) and the other three are scaled by its tuned-to-source ratio,
## so it stays the fastest and most agile (the values the source does not give, acceleration,
## braking, coasting and reverse, are starting values chosen there, to tune by playing). A Unit
## applies a type's Body group when it spawns as that type (Unit.spawn()), never in _ready(), so
## a Unit nobody spawns (the driving toy's) keeps its scene's own look, collider and layers.
## first_problem() is the one rule of what is usable: MatchController and Unit.spawn() apply it, and
## Unit._ready() keeps its own inline copy of the same three tests.
##
## Story 006 AC-1, AC-3 and AC-5 (production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md;
## design/rules.md "Resources" and "Destruction and respawn") add the Fuel group: the size of each
## type's tank (fuel_capacity), what it burns per second while the Unit moves (fuel_use, the
## source's field name; the Gyrocopter's is the highest of the four), the share of the tank a
## freshly spawned Unit starts with (spawn_fuel_fraction: a half until Story 022, all of it since)
## and how fast a ground Unit with an empty tank turns on the spot (empty_turn_rate). A type whose
## fuel_capacity is zero has no Fuel system: nothing burns and a Unit of it is never empty, as
## before Story 006. empty_turn_rate is unused by a flying type (can_fly), which crashes when its
## tank runs dry instead of standing still. The four .tres hold starting values, to tune by playing.
##
## Story 009 (production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-3, AC-4 and
## AC-6; design/rules.md "Units" and "Resources"; the first playtest, 2026-10-03) adds two values:
## how fast a Unit of this type turns on the spot (spot_turn_rate, beside turn_rate: also the least
## it turns at while it rolls) and what it burns per second while it stands (fuel_use_idle, beside
## fuel_use, which is now the moving rate). The four .tres hold starting values, to tune by
## playing: a quarter of each fuel_use, and spot_turn_rate three quarters of each turn_rate since
## Story 049 (Martin, 2026-10-25: "ked sa otacas na mieste malo by to byt rychlejsie ako teraz"; it
## was half, 1.5 times as fast now). empty_turn_rate stays the old half.
##
## Story 014 (production/epics/wasteland-fire/story-014-truck-mines.md AC-1, AC-2 and AC-9;
## design/rules.md "Turrets, Flag Walls and Mines") adds the Mines group: how many Mines a Unit of
## this type carries (mine_capacity) and where its MineLayer drops one (mine_drop_offset), so the
## Truck alone lays them by data and nothing in code asks what type a Unit is. A type whose .tres
## has no line carries none.
##
## Story 017 (production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-1, AC-2 and
## AC-7; design/rules.md "Units", the Badly damaged bullet) adds the Badly damaged group: the
## share of max_hit_points at or below which a Unit of this type is badly damaged
## (badly_damaged_fraction) and the share of its top speed it keeps while it is
## (badly_damaged_speed_share), so the state is data per type and nothing in code asks what type
## a Unit is. A type whose .tres has no line has no such state. The four .tres hold starting
## values, to tune by playing: 0.2 and 0.5.
##
## Story 021 (production/epics/wasteland-fire/story-021-gyrocopter-crash.md AC-7; design/rules.md
## "Heights", the crash) adds the crash speed to the Body group: the speed at which a Unit of this
## type that flies straight into a Tall piece is destroyed (crash_speed), data per type like every
## other value here, so nothing in code asks what type a Unit is. A type whose .tres has no line
## never crashes. The Gyrocopter's .tres holds 4.0, to tune by playing.
##
## Story 022 (production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-1, AC-3 and AC-7;
## design/rules.md "Units", "Resources" and "Destruction and respawn") adds the load of ammunition
## to the Weapon group: the Shots a Unit of this type fires on one load (ammo_capacity), where zero
## means no count at all, so a type whose .tres has no line fires without limit, the way
## fuel_capacity zero means no Fuel system and mine_capacity zero no Mines. It also changes the
## shipped spawn_fuel_fraction to 1.0: every new Unit starts with a full tank and a full load, so a
## Self-destruct trades a Token for full supplies and a Swap at the own Base is a free resupply.
## The four .tres hold 100, 50, 25 and 40 Shots, to tune by playing.
##
## Story 026 (production/epics/wasteland-fire/story-026-tyre-tracks.md AC-1 and AC-6; design/rules.md
## "Teams and visual style") adds the Tyres group: where each tyre of a ground type touches the ground
## and how wide it is (tyres, a list of TyreContact), which a Map's TyreTracks reads to draw the track
## each tyre leaves. A type whose .tres lists none (the Gyrocopter) leaves no tracks, the way
## fuel_capacity zero means no Fuel system, and nothing in code asks what type a Unit is. The Motorbike
## lists two tyres, the Buggy and the Truck four, from the Blender scripts that build the models.
##
## Data only. A Unit reads these numbers and never writes them. One .tres is shared by every
## Unit that references it, so treat it as read-only at runtime (duplicate() it for a private
## copy).
##
## Every default below is zero on purpose (0.0, false, Vector3.ZERO). The engine leaves a property
## out of a saved .tres when it equals the script default, so a tuned number that happened to match
## a default would live in this script and vanish from the data file. Write every tuned number into
## the .tres. A Unit refuses to drive while max_speed, ground_snap_length or max_hit_points is zero
## or less.
##
## The Controller group is not feel: it holds engine controller settings (how the body handles
## the floor and walls). They are data for the same reasons, one set per Unit type, and the
## Unit copies them into the body once, in _ready().

## Top forward speed at full throttle, in metres per second. It is also the divisor that turns
## speed into the speed fraction scaling steering, so it must stay above zero.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s") var max_speed: float = 0.0

## How fast speed builds toward the throttle target, in metres per second squared.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var acceleration: float = 0.0

## How fast speed is shed while the throttle opposes the direction of travel (forward throttle
## while rolling backward, or reverse throttle while rolling forward), in metres per second
## squared.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var braking: float = 0.0

## How fast speed is shed toward zero while no throttle is held, in metres per second squared.
## This is the coast-to-a-stop feel of Story 001 AC-2.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s^2") var coast_deceleration: float = 0.0

## Top reverse speed at full reverse throttle, in metres per second, written as a positive
## number.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s") var reverse_max_speed: float = 0.0

## Yaw rate at max_speed with steering fully held, in radians per second. The Unit turns slower
## at lower speed (in proportion to speed / max_speed), down to spot_turn_rate, below which it never
## turns (Story 009).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:rad/s") var turn_rate: float = 0.0

## Yaw rate with steering fully held at which a Unit of this type turns on the spot, in radians per
## second (Story 009 AC-3: a standing Unit turns without moving, so it can aim, since every weapon
## fires straight ahead). It is also the least a rolling Unit turns at: the yaw rate is turn_rate
## scaled by the speed fraction while that is at least this, and this below it (flipped while
## rolling backward), so the turn does not die away as a pivoting Unit drives off (Unit, movement
## model step 2). Keep it below turn_rate, or the Unit turns at this rate at every speed. A ground
## Unit with an empty tank turns at empty_turn_rate instead. Zero by default (class doc): a type
## whose .tres has no line cannot turn at a standstill, as before Story 009.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:rad/s") var spot_turn_rate: float = 0.0

## Hit points a Unit of this type spawns with, and the most it can have (Story 003 AC-2). Damage
## takes them off (Unit.apply_damage()) and a Unit whose hit points reach zero is destroyed and
## leaves play. Zero by default, like every value here, so the tuned number lives in the .tres
## (see the class doc). A Unit refuses to drive while it is zero or less, because it would spawn
## already destroyed.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:hp") var max_hit_points: float = 0.0

@export_group("Cargo")

## Whether a Unit of this type may pick up the Flag and carry it (Story 004 AC-2,
## production/epics/wasteland-fire/story-004-water-canister-and-win.md; design/rules.md
## "Resources"): only the Motorbike carries, and that is decided here, by data, never by a type
## check in code. The Round rules (MatchController) read Unit.can_carry and nothing else.
## False by default for the reason the class doc gives: the engine leaves a property that equals
## its script default out of a saved .tres, so a type that carries must say so in its data file,
## and a .tres without the line (an older file, or a type that never carries) loads as one that
## cannot carry.
@export var can_carry: bool = false

## Where a carried Flag rides, in this Unit type's local space, in metres: the
## Flag's origin (the centre of its base) is placed here, upright, and moves with the Unit.
## Read only while can_carry is true. Zero by default like every value here, so the tuned offset
## lives in the .tres (class doc). The Motorbike's is a tail mount, chosen so the Flag hides
## none of the cream nose from the chase camera (the Story 004 evidence doc keeps the comparison).
@export var carry_offset: Vector3 = Vector3.ZERO

@export_group("Controller")

## Floor snap distance in metres, copied into CharacterBody3D.floor_snap_length. It keeps the
## body glued to the floor over seams and while pushing against walls and corners; zero drops
## floor contact for a tick or two there, so a Unit refuses to drive while it is zero or less.
## The engine default is 0.1.
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:m") var ground_snap_length: float = 0.0

## Angle from head-on, in degrees, under which a wall stops the Unit dead instead of letting it
## slide along it; copied into CharacterBody3D.wall_min_slide_angle (radians). Measured
## 2026-09-30 on Godot 4.7.2 with Jolt (the Story 001 evidence doc keeps the run): it applies in
## the GROUNDED motion mode, although the class reference says it only affects FLOATING. At 15, a
## hit 10 degrees off head-on stopped dead and one 25 degrees off slid at max_speed * sin(25
## degrees); at 0 the 10 degree hit slid. The engine default is 15. Zero lets every hit slide.
@export_range(0.0, 90.0, 0.5, "suffix:deg") var wall_min_slide_angle_degrees: float = 0.0

## Real speed along the facing direction, in metres per second, under which a Unit touching a
## wall counts as blocked by it. A blocked Unit whose throttle is then pushed the other way drops
## its held drive speed at once instead of braking it off first (Unit, movement model step 4).
## Zero disables that, and leaving a wall then takes as long as braking from the drive speed.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var blocked_speed: float = 0.0

@export_group("Identity")

## Which Unit type this is, as a short lower-case id (&"motorbike", &"buggy", &"truck",
## &"gyrocopter"): the key of the damage matrix (DamageMatrix.multiplier() takes the attacker's
## and the target's type_id) and what Unit.type_id reports (Story 005 AC-4,
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md). Only data ever
## compares it: no branch in a script names a type. Empty by default (class doc); a .tres
## without the line reads as no type, and a matrix pair with an empty id reads the matrix's
## default_multiplier.
@export var type_id: StringName = &""

## The name the choice panel shows for this type ("Motorbike", "Buggy", "Truck", "Gyrocopter",
## the CONTEXT.md vocabulary), through tr(), so a translation replaces it without touching code
## (Story 005 AC-6: the Player chooses the type in their own viewport). Display only: nothing in
## gameplay compares it. Empty by default (class doc).
@export var display_name: String = ""

@export_group("Weapon")

## Hit points one hit of this type's weapon takes off the Unit hit, before the damage matrix
## scales it (the source's DMG; Story 005 AC-3 and AC-4; design/rules.md "Units"): damage taken =
## damage * DamageMatrix.multiplier(this type, the target's type). Zero by default (class doc);
## the tuned number lives in the .tres, and a type whose .tres has no line shoots for nothing.
@export_range(0.0, 1000.0, 0.5, "or_greater", "suffix:hp") var damage: float = 0.0

## Seconds between two shots while the fire key is held (Story 005 AC-3: the fire rate is data).
## The Weapon counts it in physics ticks (rounded, never under one tick), so it does not depend
## on the frame rate, and a press cannot beat it. Zero by default (class doc): a type whose .tres
## has no line fires every tick.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var fire_interval_seconds: float = 0.0

## Metres a shot of this type flies from the muzzle before it ends without a hit (Story 005
## AC-3: the range is data). Zero by default (class doc): a type whose .tres has no line hits
## nothing.
@export_range(0.0, 500.0, 0.5, "or_greater", "suffix:m") var weapon_range: float = 0.0

## Speed of this type's shot along the Unit's heading, in metres per second: a shot is a short
## projectile, not a hitscan, so a target can still drive out of its path (Story 005 AC-3). Zero
## by default (class doc): a type whose .tres has no line fires a shot that never leaves the
## muzzle.
@export_range(0.0, 500.0, 0.5, "or_greater", "suffix:m/s") var shot_speed: float = 0.0

## Metres ahead of the Unit's origin, along its heading, where its shot starts: just past the
## type's own collider, so a Unit never meets its own shot (Story 005 AC-3: a hit is never applied
## to the shooter). The shot's height is not here: every type fires at MatchRules.shooting_height,
## the one height all Units share. Zero by default (class doc).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var muzzle_forward: float = 0.0

## How many Shots a Unit of this type fires on one load of ammunition (Story 022 AC-1;
## design/rules.md "Units", the Weapons and Data bullets, and "Resources", the Ammo bullet): the
## Weapon refills its count to this on the first tick it finds the Unit in play, so a first spawn, a
## respawn and a Swap at the own Base all bring a full load; each Shot it fires spends one; and a
## Weapon with none left fires nothing until the next new Unit. 20 s of continuous fire at the
## type's own fire_interval_seconds: 100, 50, 25 and 40 in the four .tres, to tune by playing. Zero
## by default (class doc), and zero means no count at all: a type whose .tres has no line fires
## without limit, as before Story 022. No branch anywhere names a type for this. first_problem()
## refuses a negative one.
@export_range(0, 1000, 1, "or_greater") var ammo_capacity: int = 0

@export_group("Body")

## Whether this type flies (Story 005 AC-1 and AC-5; design/rules.md "Units": "Flying means only
## crossing cliffs and water"): true for the Gyrocopter only. What flying does is in its layers
## below (its collision_mask leaves the cliffs_water layer out); the Unit reads this flag only for
## Story 006's empty-tank rule: a flying Unit whose tank runs dry is destroyed, where a ground Unit
## stops but can still turn (Unit._burn_fuel() and _is_stranded()). False by default (class doc),
## so a type that flies must say so in its .tres.
@export var can_fly: bool = false

## Whether a Unit of this type flattens a Bush it drives into (Story 038 AC-6; the author's board of
## 2026-10-07, Bushes: "Keď cezeň prejde bugina alebo truck, spľasne", when a Buggy or a Truck drives
## through it, it collapses): true for the Buggy and the Truck, so the Motorbike passes and leaves it
## standing and the Gyrocopter, which no Bush's trigger sees, flies over. False by default (class
## doc), so a type that flattens Bushes must say so in its .tres. No branch anywhere names a type.
@export var crushes_bushes: bool = false

## The greybox visual of this type (models/<type>_model.tscn): a Model root with MeshInstance3D
## children, those in the node group "team_colour" painted with the Player's team material when
## the Unit spawns as this type (Story 005 AC-1 and AC-8: each type has a distinct silhouette, in
## both views). Null by default (class doc): with no model the Unit keeps the look its scene
## gives it (the Motorbike's own Body and Nose).
@export var model: PackedScene

## Size of this type's box collider, in metres, given to the Unit's CollisionShape3D when it
## spawns as this type (as a new BoxShape3D, never the scene's shared one; Story 005 AC-1). Zero
## by default (class doc), and Vector3.ZERO means keep the collider the Unit's scene has.
@export var collision_size: Vector3 = Vector3.ZERO

## Where the collider of collision_size sits, in the Unit's local space, in metres (its centre:
## a ground type's box stands on the floor when y is half its height). Read only while
## collision_size is not zero. The Gyrocopter's stays at ground level like everyone's, because it
## is hit at the one shooting height, whatever height its model is drawn at (Story 005 AC-5).
@export var collision_center: Vector3 = Vector3.ZERO

## The physics layer the Unit is on while it drives as this type (project.godot [layer_names]:
## 2 "units" for a ground type, 16 "gyrocopters" for the Gyrocopter; Story 005 AC-5), a bit mask
## written as a plain int in the .tres. Zero by default (class doc), and zero means keep the
## layer the Unit's scene has.
@export_flags_3d_physics var collision_layer: int = 0

## The physics layers the Unit collides with while it drives as this type (Story 005 AC-5): a ground
## type takes the map, the units, the cliffs_water and the cover layers (1 + 2 + 32 + 64 = 99), so
## cliffs, water and the Map's cover stop it; the Gyrocopter takes the map alone (1), so it crosses
## cliffs and water, flies over the cover (Story 009 AC-2), passes through ground Units and they
## through it (decided 2026-10-01), and still meets the Tall pieces on the map layer (towers, legs,
## tanks, Turrets), which stop it or, at its crash_speed, destroy it (Story 021). Zero by default
## (class doc), and zero means keep the mask the Unit's scene has.
@export_flags_3d_physics var collision_mask: int = 0

## The physics layers a spawn spot must be free of before the Unit is put down there as this type
## (the units and the gyrocopters layers, 2 + 16 = 18, for every type: a Truck is never put down
## inside a Gyrocopter parked in its Garage although the two never collide; Story 005 AC-5 and
## AC-6). Zero by default (class doc), and zero means test the Unit's own layer, as Story 003 did.
@export_flags_3d_physics var spot_mask: int = 0

## The speed in metres per second at which a Unit of this type that flies straight into a Tall piece
## is destroyed (Story 021 AC-7; design/rules.md "Heights", the crash): the real velocity it arrived
## with, along the normal of the collision, at or above this destroys it in the tick of the contact
## (Unit, movement model step 7), and a graze, a slow nudge or a turn on the spot only stops it. A
## quarter of the Gyrocopter's 16.4 m/s top speed to start, 4.0 in its .tres, to tune by playing:
## with its 15 m/s^2 it reaches that in about half a metre. Zero by default (class doc), and zero
## means the type never crashes, as the Motorbike, the Buggy and the Truck, which leave the line
## out: no branch anywhere names a type for this. first_problem() refuses a negative one.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s") var crash_speed: float = 0.0

@export_group("Fuel")

## Size of this type's Fuel tank, in Fuel units (Story 006 AC-1,
## production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md; design/rules.md "Resources"):
## the most Fuel a Unit of this type holds, the top of its Fuel gauge and what a Fuel zone fills it
## up to. Zero by default (class doc), and zero means this type has no Fuel system: a Unit of it
## burns nothing and is never empty, as before Story 006. A Unit has a tank only once it has spawned
## (Unit.spawn()), so a Unit nobody spawns (the driving toy's) burns nothing whatever this says.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:fuel") var fuel_capacity: float = 0.0

## Fuel units this type burns per second while the Unit moves (the source's field name; Story 006
## AC-1 and AC-2; design/rules.md "Resources": every Unit burns Fuel, the Gyrocopter the most).
## Moving reads the drive speed: a Unit burns this while its drive speed is not approximately zero,
## so one coasting to a stop burns it until it stands and one held against a wall with the throttle
## on keeps burning it; a Unit standing still burns fuel_use_idle instead (Story 009). The
## Gyrocopter's is the highest of the four. Zero by default (class doc): a type whose .tres has no
## line burns nothing while it moves.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:fuel/s") var fuel_use: float = 0.0

## Fuel units this type burns per second while the Unit stands, its drive speed approximately zero
## (Story 009 AC-4; design/rules.md "Resources": a standing Unit burns slower than a moving one, so
## keep it below fuel_use). A Gyrocopter hovering still burns it too, and crashes when its tank runs
## dry. Zero by default (class doc): a type whose .tres has no line burns nothing while it stands,
## as before Story 009.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:fuel/s") var fuel_use_idle: float = 0.0

## The share of fuel_capacity a Unit of this type starts with every time it spawns, from 0 to 1.
## Story 006 AC-5 made it a fixed half, so that dying was never a free refuel; Story 022 AC-3
## (design/rules.md "Destruction and respawn": every new Unit starts with full supplies, a full
## tank and a full load of ammo) makes it 1.0 in the four .tres, so a Self-destruct trades a Token
## for full supplies and a Swap at the own Base is a free resupply. The Unit clamps it to that
## range. The knob stays: the evidence runner gives the scenarios written before Story 022 their
## half tank back through it. Zero by default (class doc): a type whose .tres has no line spawns
## with an empty tank, which leaves a ground Unit unable to drive and crashes a flying one on its
## first tick.
@export_range(0.0, 1.0, 0.01) var spawn_fuel_fraction: float = 0.0

## How fast a ground Unit of this type turns on the spot while its tank is empty, in radians per
## second with steering fully held (Story 006 AC-3; design/rules.md "Destruction and respawn": a
## ground Unit with no Fuel stops but can still turn and fire). Unlike turn_rate it does not scale
## with speed, so an empty Unit turns at a standstill. Unused by a flying type (can_fly), which
## crashes when its tank runs dry: the Gyrocopter's .tres leaves it out. Zero by default (class
## doc): an empty ground Unit of a type whose .tres has no line cannot turn.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:rad/s") var empty_turn_rate: float = 0.0

@export_group("Mines")

## How many Mines a Unit of this type carries after every spawn (Story 014 AC-2; design/rules.md
## "Turrets, Flag Walls and Mines": only the Truck lays them, five per Truck): the MineLayer
## refills its count to this on the first tick it finds the Unit in play, so a respawn and a Swap
## at the own Base both bring a full load. Zero by default (class doc), and zero means the type
## lays none: the Motorbike, the Buggy and the Gyrocopter leave it out, and the lay key does
## nothing for them. No branch anywhere names a type for this.
@export_range(0, 100, 1, "or_greater") var mine_capacity: int = 0

## Where the MineLayer drops a Mine, in this Unit type's local space, in metres (Story 014 AC-1;
## a Unit faces its local -Z, so a positive z is behind it): just clear of the type's own collider
## and of the trigger, so a Unit standing or turning on the spot never sets off its own Mine. Read
## only while mine_capacity is above zero, and then it must not be zero (first_problem()). Zero by
## default (class doc). The Truck's box is 2.4 x 4.4 m, so a drop 3.4 m behind its origin leaves a
## 0.8 m trigger 0.4 m clear of it.
@export var mine_drop_offset: Vector3 = Vector3.ZERO

## Seconds the Mine takes to recharge after a lay (Story 044; Martin, 2026-10-22: "skusme dat aj miny
## ze sa nabijaju 15s"). Above zero the load is unlimited: no lay takes a Mine from mines_left and
## the next lay waits this long; zero (the default, and every scenario before story 044) keeps the
## count of Story 014 with no wait.
@export_range(0.0, 120.0, 0.5, "or_greater", "suffix:s") var mine_cooldown_seconds: float = 0.0

@export_group("Secondary")

## Seconds the nitro lasts, the Buggy's secondary weapon on the secondary key (Story 042; Martin,
## 2026-10-22: "skusme nitro"). Zero by default (class doc): a type with none has no nitro. While it
## lasts the type's top speed forward and its acceleration are nitro_speed_share times their own.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var nitro_seconds: float = 0.0

## How many times the type's own top speed and acceleration the nitro gives (Story 042).
@export_range(1.0, 5.0, 0.05, "or_greater") var nitro_speed_share: float = 1.0

## Seconds after the nitro ends before it can be fired again (Story 042). A new Unit starts ready.
@export_range(0.0, 120.0, 0.5, "or_greater", "suffix:s") var nitro_cooldown_seconds: float = 0.0

## Seconds the smoke screen takes to recharge after a drop, the Gyrocopter's secondary weapon on
## the secondary key (Story 042; Martin, 2026-10-22: "velka dymova clona - gyro bude v strede a nikto
## nebude vediet kam poleti"; story 044, the same day: "nech sa spravi pred gyro, nech trva 3 sek a
## tiez sa nabija ale 15s"). Zero by default: a type with none has no smoke. A new Unit starts ready.
@export_range(0.0, 120.0, 0.5, "or_greater", "suffix:s") var smoke_cooldown_seconds: float = 0.0

@export_group("Badly damaged")

## The share of max_hit_points at or below which a Unit of this type is badly damaged (Story 017
## AC-1; design/rules.md "Units": the author's "for example" 20%, so a Motorbike of 40 hit points is
## badly damaged at 8, a Buggy of 100 at 20, a Truck of 220 at 44 and a Gyrocopter of 70 at 14):
## smoke rises from it and its top speed is badly_damaged_speed_share of its own until it is
## destroyed or put away. The edge belongs to the state: a Unit left on exactly this share is badly
## damaged. Zero by default (class doc), and zero means the type has no such state: a type whose
## .tres has no line is never badly damaged, the way fuel_capacity zero means no Fuel system (never
## a type check). first_problem() refuses a value outside 0 to under 1, a NaN included.
@export_range(0.0, 0.99, 0.01) var badly_damaged_fraction: float = 0.0

## The share of its top speed a badly damaged Unit of this type keeps (Story 017 AC-2; the author's
## "for example" half), forward and in reverse alike: a Motorbike's 24 m/s becomes 12, its 9 m/s in
## reverse 4.5. Read only while badly_damaged_fraction is above zero, and then it must be above zero
## and at most 1 (first_problem()). Zero by default (class doc). Turning, braking, the weapon and
## the Fuel burn do not read it.
@export_range(0.0, 1.0, 0.01) var badly_damaged_speed_share: float = 0.0

@export_group("Tyres")

## Where each tyre of this type touches the ground, in the Unit's frame, and how wide it is (Story 026
## AC-1): one TyreContact per tyre, which a Map's TyreTracks turns into a track as wide as the tyre. The
## Motorbike lists its front and rear tyres (one line, the two are in line), the Buggy and the Truck
## their four. Empty by default (class doc), and empty means the type leaves no tracks: the Gyrocopter
## lists none because it flies. first_problem() refuses an entry that is missing or unusable.
@export var tyres: Array[TyreContact] = []


## The reason these stats cannot drive a Unit, or an empty String when they can: max_speed,
## ground_snap_length and max_hit_points must each be above zero (the rule Unit._ready() applies;
## the class doc says why), and a type that carries Mines must say where it drops them: a zero
## mine_drop_offset would lay every Mine under the Unit's own origin, where it destroys the Unit
## once it is live (Story 014). MatchController asks it of every entry of MatchRules.unit_types
## before a Round begins, and Unit.spawn() of the type it is handed, so a bad .tres is one named
## error and never a Unit that spawns already destroyed. A type with a badly damaged state must
## keep a share of its speed above zero (Story 017): a fraction outside 0 to under 1 is refused,
## and so is a share outside above 0 to 1 while the fraction is above 0; both are tested so that
## a NaN fails them. A crash_speed below zero is refused too (Story 021), a NaN included, and so is
## an ammo_capacity below zero (Story 022): a negative load would otherwise read as no count at all.
## A tyre (Story 026) that is missing or whose TyreContact.first_problem() names a fault is refused too.
func first_problem() -> String:
	if max_speed <= 0.0:
		return "max_speed is not above zero"
	if ground_snap_length <= 0.0:
		return "ground_snap_length is not above zero"
	if max_hit_points <= 0.0:
		return "max_hit_points is not above zero"
	if mine_capacity > 0 and mine_drop_offset.is_zero_approx():
		return "mine_drop_offset is zero while mine_capacity is above zero"
	if not (badly_damaged_fraction >= 0.0 and badly_damaged_fraction < 1.0):
		return "badly_damaged_fraction is not from 0 to under 1"
	var share_usable: bool = badly_damaged_speed_share > 0.0 and badly_damaged_speed_share <= 1.0
	if badly_damaged_fraction > 0.0 and not share_usable:
		return "badly_damaged_speed_share is not above 0 and at most 1 while badly_damaged_fraction is above 0"
	if not (crash_speed >= 0.0):
		return "crash_speed is not zero or above"
	if ammo_capacity < 0:
		return "ammo_capacity is below zero"
	for index: int in tyres.size():
		var problem: String = "is missing" if tyres[index] == null else tyres[index].first_problem()
		if not problem.is_empty():
			return "tyres[%d] %s" % [index, problem]
	return ""
