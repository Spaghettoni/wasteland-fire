class_name ExplosionSettings
extends Resource
## Tuning values of the explosion a destroyed Unit plays: how long it lasts, how big each of its four
## pieces is for a Unit of a given size, how the pieces move, and every colour.
##
## Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-3 (about 2 s, then it
## frees itself), AC-5 (the look: a flash, a fireball, a few chunks, some smoke) and AC-9 (every value
## is data, never a literal in a script); design/rules.md "Destruction and respawn" and "Teams and
## visual style". Vocabulary: CONTEXT.md (Unit).
##
## Data only. An Explosion reads these numbers and never writes them. One .tres
## (data/explosion_settings.tres) is shared by explosion.tscn, so every explosion tunes together; treat
## it as read-only at runtime (duplicate() it for a private copy). Every default below is zero or
## empty on purpose, for the reason UnitStats gives: the engine leaves a property that equals its
## script default out of a saved .tres, so a tuned number would vanish from the data file. Write every
## tuned number into the .tres. first_problem() says whether the values can play an explosion at all.
##
## Sizes. Every length is a factor of the destroyed type's size, the larger horizontal side of its
## collision_size (2.6 m for the Motorbike, 4.4 m for the Truck), so a Truck's explosion is larger
## than a Motorbike's with no type named anywhere. Speeds and the gravity are metres per second and
## stay as they are for every type. Durations are seconds; the Explosion counts them in its own
## physics ticks, rounded and never under one tick.
##
## Directions and speeds are tables: chunk i flies from the centre along chunk_directions[i] at
## chunk_speeds[i] and falls under chunk_gravity, so the blast looks the same on every run (no random
## number anywhere) and the number of chunks is the length of the tables. The smoke is the same: one
## puff per entry of smoke_offsets.

## Slack allowed when seconds are added up, so that 0.2 s and 1.8 s fit a lifetime of 2.0 s.
const SECONDS_SLACK: float = 0.001

## Seconds from the tick a Unit is destroyed to the tick its explosion frees itself ("about 2 s": the
## reading of 2026-10-10). Every piece must end by then (first_problem()).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var lifetime_seconds: float = 0.0

## Seconds the flash shows: a short bright ball over the place of the blast.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:s") var flash_seconds: float = 0.0

## Radius of the flash, as a share of the destroyed type's size.
@export_range(0.0, 4.0, 0.01, "or_greater") var flash_radius_factor: float = 0.0

## Colour of the flash (the pale yellow of a Mine's flash).
@export var flash_colour: Color = Color(0.0, 0.0, 0.0, 0.0)

## Seconds the fireball lasts: it swells, then shrinks and darkens.
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:s") var fireball_seconds: float = 0.0

## Radius of the fireball at its largest, as a share of the destroyed type's size.
@export_range(0.0, 4.0, 0.01, "or_greater") var fireball_radius_factor: float = 0.0

## The share of fireball_seconds it takes to swell from fireball_start_scale to its full radius; the
## rest of the time it shrinks to fireball_end_scale and darkens. Must be above 0 and below 1.
@export_range(0.0, 1.0, 0.01) var fireball_swell_fraction: float = 0.0

## The share of its full radius the fireball starts at.
@export_range(0.0, 1.0, 0.01) var fireball_start_scale: float = 0.0

## The share of its full radius the fireball ends at.
@export_range(0.0, 1.0, 0.01) var fireball_end_scale: float = 0.0

## Colour of the fireball while it swells and where it starts to darken.
@export var fireball_colour_start: Color = Color(0.0, 0.0, 0.0, 0.0)

## Colour of the fireball when it ends.
@export var fireball_colour_end: Color = Color(0.0, 0.0, 0.0, 0.0)

## The direction chunk i is thrown in, one entry per chunk (up and out; normalised when it is used).
## The length of this table is the number of chunks.
@export var chunk_directions: PackedVector3Array = PackedVector3Array()

## The speed chunk i is thrown at, metres per second, one entry per chunk.
@export var chunk_speeds: PackedFloat32Array = PackedFloat32Array()

## The edge of chunk i's cube, as a share of the destroyed type's size, one entry per chunk.
@export var chunk_size_factors: PackedFloat32Array = PackedFloat32Array()

## The gravity the chunks fall under, metres per second squared. Each chunk is hidden when it reaches
## the floor the Unit stood on.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m/s²") var chunk_gravity: float = 0.0

## Colour of the chunks (dark steel).
@export var chunk_colour: Color = Color(0.0, 0.0, 0.0, 0.0)

## Where puff i begins, as a share of the destroyed type's size, from the centre of the blast: one
## entry per puff. The length of this table is the number of puffs (none: no smoke).
@export var smoke_offsets: PackedVector3Array = PackedVector3Array()

## Radius of a puff when it begins, as a share of the destroyed type's size.
@export_range(0.0, 4.0, 0.01, "or_greater") var smoke_radius_factor: float = 0.0

## Seconds after the blast the first puff begins.
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:s") var smoke_start_seconds: float = 0.0

## Seconds between the start of one puff and the next one's.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:s") var smoke_stagger_seconds: float = 0.0

## Seconds from the start of the first puff to the end of the smoke: every puff ends then, fading to
## nothing, so a later puff lives for less.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var smoke_seconds: float = 0.0

## Metres per second a puff rises at.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m/s") var smoke_rise_speed: float = 0.0

## How many times larger a puff is when it ends than when it began.
@export_range(0.0, 10.0, 0.05, "or_greater") var smoke_growth: float = 0.0

## Colour of the smoke; its alpha is how thick a puff is when it begins (it fades to nothing).
@export var smoke_colour: Color = Color(0.0, 0.0, 0.0, 0.0)


## The reason an Explosion cannot play these settings, or an empty String when it can: the lifetime and
## the durations, the factors, the fireball's fractions and the gravity must be above zero where they
## are used, the chunk tables must be the same length with a direction that points somewhere, every
## colour must be visible, and every piece must end within the lifetime. Each test is written as "not
## above" so a NaN, which is above nothing, is refused too. Explosion._ready() asks it, so a bad .tres
## is one named error and never a blast that is missing a piece.
func first_problem() -> String:
	var shared: String = _first_shared_problem()
	if not shared.is_empty():
		return shared
	var chunks: String = _first_chunk_problem()
	if not chunks.is_empty():
		return chunks
	return _first_smoke_problem()


func _first_shared_problem() -> String:
	if not (lifetime_seconds > 0.0):
		return "lifetime_seconds is not above zero"
	if not (flash_seconds > 0.0) or not (flash_seconds <= lifetime_seconds + SECONDS_SLACK):
		return "flash_seconds is not above zero or is longer than the lifetime"
	if not (fireball_seconds > 0.0) or not (fireball_seconds <= lifetime_seconds + SECONDS_SLACK):
		return "fireball_seconds is not above zero or is longer than the lifetime"
	if not (flash_radius_factor > 0.0) or not (fireball_radius_factor > 0.0):
		return "flash_radius_factor and fireball_radius_factor must be above zero"
	if not (fireball_swell_fraction > 0.0) or not (fireball_swell_fraction < 1.0):
		return "fireball_swell_fraction is not above 0 and below 1"
	if not (fireball_start_scale > 0.0) or not (fireball_end_scale > 0.0):
		return "fireball_start_scale and fireball_end_scale must be above zero"
	for colour: Color in [flash_colour, fireball_colour_start, fireball_colour_end, chunk_colour, smoke_colour]:
		if not (colour.a > 0.0):
			return "a colour has no alpha, so that piece would be invisible"
	return ""


func _first_chunk_problem() -> String:
	var count: int = chunk_directions.size()
	if chunk_speeds.size() != count or chunk_size_factors.size() != count:
		return "chunk_directions, chunk_speeds and chunk_size_factors must have the same length"
	if count > 0 and not (chunk_gravity > 0.0):
		return "chunk_gravity is not above zero"
	for index: int in count:
		if not (chunk_directions[index].length() > 0.0):
			return "chunk_directions[%d] points nowhere" % index
		if not (chunk_speeds[index] > 0.0) or not (chunk_size_factors[index] > 0.0):
			return "chunk_speeds[%d] and chunk_size_factors[%d] must be above zero" % [index, index]
	return ""


func _first_smoke_problem() -> String:
	var puffs: int = smoke_offsets.size()
	if puffs == 0:
		return ""
	if not (smoke_radius_factor > 0.0) or not (smoke_growth > 0.0) or not (smoke_seconds > 0.0):
		return "smoke_radius_factor, smoke_growth and smoke_seconds must be above zero"
	if not (smoke_start_seconds >= 0.0) or not (smoke_stagger_seconds >= 0.0) or not (smoke_rise_speed >= 0.0):
		return "smoke_start_seconds, smoke_stagger_seconds and smoke_rise_speed must not be below zero"
	if not (smoke_start_seconds + smoke_seconds <= lifetime_seconds + SECONDS_SLACK):
		return "the smoke ends after the lifetime"
	if not (smoke_stagger_seconds * float(puffs - 1) < smoke_seconds):
		return "the last puff would begin after the smoke ended"
	return ""
