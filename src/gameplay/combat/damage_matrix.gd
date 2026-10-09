class_name DamageMatrix
extends Resource
## The damage-multiplier matrix of the Unit triangle: how much an attacker's damage is scaled by
## its type against the target's type, as data behind one function.
##
## Implements: design/game-brief.md MVP feature 5 (Four Units and the triangle) and
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-4 and AC-9;
## design/rules.md "Units" (Damage multipliers): the Buggy, the Truck and the Gyrocopter deal 1.5
## against the Unit they beat and 0.5 against the one that beats them, 1.0 against their own type,
## and the Motorbike deals and receives 1.0 against every type. Damage taken = the attacker's
## damage (UnitStats.damage) * multiplier(attacker type, target type). One .tres holds it
## (data/damage_matrix.tres, referenced by MatchRules.damage_matrix); a Shot reads it when it
## hits.
##
## No branch in code names a type: the table is keyed by the type id of the attacker and of the
## target ("attacker>target"), a UnitStats' or a StructureStats' (the Motorbike deals nothing to a
## Flag Wall: &"motorbike>flag_wall", Story 012), and every pair the table does not list reads
## default_multiplier, so the Motorbike's row and column, the own-type pairs and the fallback of
## design/rules.md (every multiplier 1.0, if the triangle shows without the matrix) are data
## edits, never code changes.
##
## Data only: read, never written, at runtime (duplicate_deep() it for a private copy: duplicate()
## shares the multipliers dictionary with the original, measured on Godot 4.7.2 in Story 008).
## Every default below is zero or empty on purpose, for the reason UnitStats gives: the engine
## leaves a property out of a saved .tres when it equals the script default, so the 1.0 fallback
## lives in damage_matrix.tres, not here. A matrix whose default_multiplier is zero would make
## every unlisted pair deal nothing: write it in the data.

## The multiplier of every attacker-target pair the table does not list: the shape of the matrix
## in design/rules.md puts 1.0 here (the own-type pairs, the Motorbike both ways). Zero by default
## (class doc); the tuned value lives in the .tres.
@export var default_multiplier: float = 0.0

## The listed pairs, keyed "attacker>target" from the two type ids, each a UnitStats.type_id or a
## StructureStats.type_id (for example &"buggy>truck" or &"motorbike>flag_wall"), each mapped to
## its multiplier. Only the pairs that differ from default_multiplier need an entry.
@export var multipliers: Dictionary[StringName, float] = {}


## The multiplier the attacker's damage is scaled by against the target: the table's entry for the
## pair "attacker_type>target_type", or default_multiplier when the pair is not listed (an empty or
## unknown type id included).
func multiplier(attacker_type: StringName, target_type: StringName) -> float:
	var key: StringName = StringName("%s>%s" % [attacker_type, target_type])
	var value: float = multipliers.get(key, default_multiplier)
	return value
