class_name TokenStock
extends Resource
## The Token stock a Map sets: how many Tokens of each Unit type each Player starts the Round
## with, one count per type.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-9 (the Token stock is data
## in the Map, not a constant in code; Map 01 holds the source's example, Motorbike 5, Buggy 3,
## Truck 2, Gyrocopter 2) and design/rules.md "Tokens and the Garage" (each Player has a stock of
## Tokens, one count per Unit type; the counts are set by the Map and each Map may differ; the
## example is an example, not a rule). Vocabulary: CONTEXT.md (Token, Unit, Map, Player).
##
## Story 008 reads it (production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1:
## each Player's stock is copied from the Map's data when the Round starts); Story 007 only holds
## it. So nothing in the game reads the counts yet and nothing here checks them: the rule that a
## Map gives every Player at least 1 Motorbike Token (design/rules.md) is Story 008's to enforce.
## A MapField hands the stock out as its token_stock.
##
## The counts are keyed by the id UnitStats.type_id carries (&"motorbike", &"buggy", &"truck",
## &"gyrocopter"), the key the damage matrix uses too, so no script names a Unit type and a new
## type needs only data. count_of() reads one count, with 0 for a type the stock does not list.
##
## Data only. One .tres (data/token_stock.tres) holds the source's example; a Map with other
## counts references a .tres of its own. A .tres is shared by everything that loads it, so treat
## the stock as read-only at runtime (duplicate() it for a private copy). Write every count in the
## .tres as an int: on 4.7.2 one value that does not convert to an int (a String) empties the whole
## typed dictionary on load, with an ERROR, so one typo loses every count; a float such as 5.0 is
## converted (the Story 007 evidence doc keeps the run).

## How many Tokens of each Unit type each Player starts the Round with, keyed by the type's
## UnitStats.type_id. A type the dictionary does not list has none (count_of() reads 0 for it).
## Empty by default: the Map's .tres writes every count.
@export var counts: Dictionary[StringName, int] = {}


## The number of Tokens of the Unit type type_id (a UnitStats.type_id) each Player starts the
## Round with: its entry in counts, or 0 for an id counts does not list (an unknown type, or the
## empty id of a UnitStats that has none).
func count_of(type_id: StringName) -> int:
	return counts.get(type_id, 0)
