class_name MatchRules
extends Resource
## Tuning values for one Round: how long a destroyed Unit waits before it respawns at its
## Player's Base, and how hard the debug-damage key hits.
##
## Implements: design/game-brief.md MVP feature 3 (Bases, destruction and respawn) and
## production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-3 (the respawn delay
## defaults to 3 seconds and is a data tuning value) and AC-8 (a debug key damaged the local Unit
## until Story 005 brought weapons, and is gated so it can be switched off); design/rules.md
## "Destruction and respawn" ("a delay of about three seconds (tuning value)"). One .tres holds them
## (data/match_rules.tres); MatchController and PlayerMatchInput read it.
##
## Story 005 (production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3, AC-4,
## AC-6 and AC-9; design/rules.md "Units") adds the Round's Unit and combat data: the four Unit
## types a Player chooses from at every spawn (unit_types, each one UnitStats .tres), the
## damage-multiplier matrix of the triangle (damage_matrix), the one shooting height every Unit
## fires and is hit at (shooting_height) and the layers that stop a shot (shot_collision_mask).
## MatchController reads the types; the Weapon and the Shot read the rest.
##
## Story 011 (production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md AC-5; design/rules.md
## "Destruction and respawn") adds one switch: whether the Self-destruct key swaps a Unit inside its
## own Base instead of destroying it (own_base_swap). MatchController reads it.
##
## Data only. Both read these numbers and never write them. The .tres is shared, so treat it as
## read-only at runtime. A copy for a test: duplicate() makes the numbers private but shares the
## unit_types array with the original (writing the copy's array writes the original's: measured on
## Godot 4.7.2 in Story 008), so replace unit_types with an array of its own instead of changing its
## entries.
##
## Every default below is 0.0 on purpose, for the reason UnitStats gives: the engine leaves a
## property out of a saved .tres when it equals the script default, so a tuned number that
## happened to match a default would live in this script and vanish from the data file. The 3
## seconds of AC-3 is the value in match_rules.tres, not in this script. MatchController refuses
## to begin a Round while respawn_delay_seconds is zero or less.

## Seconds a destroyed Unit waits before it respawns at its Player's Base (Story 003 AC-3). The
## MatchController counts it in physics time, so it does not depend on the frame rate. It must
## stay above zero.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var respawn_delay_seconds: float = 0.0

## Hit points one press of a Player's debug-damage key takes off that Player's own Unit (Story 003
## AC-8), the stand-in for a weapon before Story 005. Zero turns the debug keys off: that is the
## gate which keeps them out of a build with weapons. Story 005 ships it at zero in
## match_rules.tres, so the debug keys are off in the game; the code stays, gated by this value.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:hp") var debug_damage: float = 0.0

## Whether the Self-destruct key puts a Unit away instead of destroying it while that Unit is inside
## its own Base (Story 011 AC-1 and AC-5): no Token is taken, no respawn delay runs, and the Player
## chooses the next Unit type at once from the types that have Tokens left. "Inside" is each Base's
## zone, which the Map's scenes set (a zone must watch the physics layer of every Unit type, and
## MatchController refuses to begin a Round with this on while one does not). Off, the key is the
## Self-destruct of Stories 003 and 008 everywhere, which is also what a scenario written before
## Story 011 runs with. False by default (class doc: a flag left at its default would live in this
## script and vanish from the data file); the shipped data turns it on in match_rules.tres.
@export var own_base_swap: bool = false

## The Unit types a Player may choose from at every spawn, in the order the choice panel lists
## them: Motorbike, Buggy, Truck, Gyrocopter (Story 005 AC-1 and AC-6; design/rules.md "Units").
## Each entry is one UnitStats .tres, the very resource its scene uses (one object in the
## resource cache, so a change reaches every reader). A type may be chosen while the Player has a
## Token of it: the stock that limits the choice is the Map's (TokenStock, Story 008), which counts
## by each entry's type_id. MatchController refuses to begin a Round while the list is empty, while
## an entry's first_problem() is not empty, and while the Map's stock does not fit the list
## (TokenLedger.first_problem()). Empty by default (class doc).
@export var unit_types: Array[UnitStats] = []

## The damage-multiplier matrix of the triangle (Story 005 AC-4): a Shot scales its attacker's
## damage by damage_matrix.multiplier(attacker type, target type) when it hits. One resource,
## data/damage_matrix.tres, shared by every Shot. Null by default (class doc).
@export var damage_matrix: DamageMatrix

## Metres above a Unit's origin at which every shot flies: the one shooting height all Units
## share (Story 005 AC-3 and AC-5; design/rules.md "Units": the Gyrocopter shoots and is shot
## like everyone else, whatever height its model is drawn at). Zero by default (class doc); the
## tuned height lives in match_rules.tres.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var shooting_height: float = 0.0

## The physics layers that stop a shot (Story 005 AC-3 and AC-5): the map, the units, the
## gyrocopters and the cover layers of project.godot [layer_names] (1 + 2 + 16 + 64 = 83; the cover
## layer since Story 009, when the Map's cover left the map layer so the Gyrocopter could fly over
## it), and NOT the cliffs_water layer, so a shot passes over cliffs and water and stops at walls,
## at the cover and at Units. A bit mask, written as a plain int in the .tres. Zero by default
## (class doc): a zero mask would stop a shot nowhere, so the tuned mask lives in match_rules.tres.
@export_flags_3d_physics var shot_collision_mask: int = 0
