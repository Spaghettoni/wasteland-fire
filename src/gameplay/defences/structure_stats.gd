class_name StructureStats
extends Resource
## What one kind of Structure is made of: its type id, the name the game may show for it, its hit
## points, the fractions of them below which it looks hurt and whether it keeps its Base's Flag
## from the other Player, as data.
##
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-3, AC-8 and AC-9 (a Flag
## Wall has 40 hit points and looks hurt below 80% and 35% of them, and every value is data, never
## a literal in a script) and production/epics/wasteland-fire/story-013-turrets.md AC-5 and AC-9
## (a Turret locks its Base's Flag while it stands, a switch in the data, not a class the Flag
## rules name); design/rules.md "Turrets, Flag Walls and Mines". Vocabulary: CONTEXT.md (Flag Wall,
## Turret).
##
## The type id is what the damage matrix keys on ("attacker>target", for example
## &"motorbike>flag_wall"), the way a UnitStats' type id is, so a Shot treats a Structure and a Unit
## alike and no branch in code names a type. Data only: a Structure reads these numbers and never
## writes them. One .tres is shared by every Structure that references it, so treat it as
## read-only at runtime (duplicate() it for a private copy).
##
## Every default below is empty or zero on purpose, for the reason UnitStats gives: the engine
## leaves a property out of a saved .tres when it equals the script default, so a tuned number that
## happened to match a default would live in this script and vanish from the data file. Write every
## value into the .tres. A Structure refuses stats whose type id is empty, whose hit points are not
## above zero or whose damaged_below fractions are out of order.

## The kind of Structure this is, the key of the damage matrix (&"flag_wall" for a Flag Wall). Empty
## by default (class doc): stats without one are refused.
@export var type_id: StringName = &""

## The name the game would show for it ("Flag Wall"). Nothing shows it yet; it is data so that a
## label never has to be a literal.
@export var display_name: String = ""

## Hit points of a standing Structure; it falls when they reach zero. Zero by default (class doc):
## stats without a value above zero are refused.
@export_range(0.0, 1000.0, 0.5, "or_greater") var max_hit_points: float = 0.0

## The fractions of max_hit_points below which a standing Structure shows its damaged looks,
## highest first: below the first it shows its first damaged look, below the second its second, and
## so on (Structure.damaged_looks; a Flag Wall's are 0.8 and 0.35, Story 012 AC-9). Empty by
## default (class doc): a Structure with none shows its intact look until it falls. Each must be
## above 0, below 1 and below the one before it, or the stats are refused.
@export var damaged_below: Array[float] = []

## Whether a standing Structure of this kind keeps its Base's Flag from the other Player (Story 013
## AC-5): the Flag rules read it from the Structures of a Base and name no class, so a Turret locks
## the Flag and a Flag Wall does not. False by default (class doc): only the stats that say true
## lock.
@export var locks_flag: bool = false


## The reason a Structure cannot use these stats, or an empty String when it can: the type id must
## name a type, max_hit_points must be above zero (the rule UnitStats.first_problem() applies to a
## Unit) and every damaged_below fraction must be above 0, below 1 and below the one before it.
## Both tests are written as "not above" so a NaN, which is above nothing, is refused too.
## Structure._ready() asks it, so a bad .tres is one named error and never a piece that is solid
## and can never be broken.
func first_problem() -> String:
	if type_id.is_empty():
		return "type_id is empty"
	if not (max_hit_points > 0.0):
		return "max_hit_points is not above zero"
	var above: float = 1.0
	for fraction: float in damaged_below:
		if not (fraction > 0.0 and fraction < above):
			return "damaged_below is not fractions above 0 and below 1, highest first"
		above = fraction
	return ""
