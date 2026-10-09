class_name TurretStats
extends StructureStats
## What a Turret is made of beyond a Structure's hit points: the weapon it fires, how fast its
## barrel turns, how close the barrel must be to the aim before it fires and what hides a target
## from it, as data. One .tres (data/turret_stats.tres) is shared by every Turret that references
## it, so treat it as read-only at runtime (duplicate() it for a private copy).
##
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-3 (the barrel turns at 90
## degrees a second, one Shot every 0.8 s at 60 m/s, 12 damage), AC-2 (a range of 35 m, and what
## hides a target) and AC-9 (every value and switch is data, never a literal in a script);
## design/rules.md "Turrets, Flag Walls and Mines". Vocabulary: CONTEXT.md (Turret).
##
## The weapon's numbers are the Buggy's (damage, range, Shot speed) with the interval doubled, the
## board's "half the Buggy's rate of fire"; the others are starting values to tune by playing
## (design/rules.md). Every default below is zero or empty on purpose, for the reason UnitStats and
## StructureStats give: a tuned number equal to the script's default would vanish from the .tres.
## Write every value into the .tres. A Turret refuses stats that leave any of the numbers below at
## or under zero (first_problem()).

## The damage one Shot carries before the damage matrix's multiplier (12, the Buggy's).
@export var damage: float = 0.0

## Seconds between two Shots (0.8: half the Buggy's rate). The Turret counts it in its own physics
## ticks, rounded as the Weapon rounds, so a paused tree stops the count.
@export var fire_interval_seconds: float = 0.0

## Metres a Shot flies at most from the aimed muzzle (35, the Buggy's): a target whose aim point is
## farther is not fired on.
@export var weapon_range: float = 0.0

## Metres per second a Shot flies at (60, like every Shot).
@export var shot_speed: float = 0.0

## Radians per second the barrel turns at, in the same unit as UnitStats.turn_rate (90 degrees a
## second is 1.5707963).
@export var turn_rate: float = 0.0

## Metres from the Turret's centre along the barrel to where a Shot leaves (1.6, past its 1.0 m
## drum). The aimed muzzle, where reach, sight and path are measured from, is this far from the
## centre toward the aim point.
@export var muzzle_forward: float = 0.0

## Metres, at the aim point, by which the barrel may miss the aim and still fire (0.25: under half
## the narrowest Unit, the Motorbike's 1.4 m).
@export var aim_tolerance: float = 0.0

## The physics layers that hide a target from the Turret's sight beyond what stops a Shot (32, the
## cliffs_water layer: a cliff hides a target although every Shot passes through cliffs, told to
## the developer on 2026-10-07). The Bushes' layer joins it later, as data.
@export_flags_3d_physics var sight_extra_mask: int = 0


## The reason a Turret cannot use these stats, or an empty String when it can: what StructureStats
## refuses, and any weapon number that is not above zero. A NaN is refused, the tests being written
## as "not above". sight_extra_mask may be zero (nothing extra hides a target).
func first_problem() -> String:
	var problem: String = super.first_problem()
	if not problem.is_empty():
		return problem
	if not (damage > 0.0):
		return "damage is not above zero"
	if not (fire_interval_seconds > 0.0):
		return "fire_interval_seconds is not above zero"
	if not (weapon_range > 0.0):
		return "weapon_range is not above zero"
	if not (shot_speed > 0.0):
		return "shot_speed is not above zero"
	if not (turn_rate > 0.0):
		return "turn_rate is not above zero"
	if not (muzzle_forward > 0.0):
		return "muzzle_forward is not above zero"
	if not (aim_tolerance > 0.0):
		return "aim_tolerance is not above zero"
	return ""
