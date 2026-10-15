class_name SupplySettings
extends Resource
## Tuning values shared by every supply zone: how long a Fuel zone takes to fill an empty tank, how
## long an ammunition zone takes to fill an empty gun, and the speed below which a Unit counts as
## stopped in a zone.
##
## Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-3 (a Unit that has
## stopped in a Fuel zone refuels from empty to full in about 4 s) and AC-6 (every value is
## data); production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2 (a Unit that has
## stopped in an ammunition zone rearms from empty to a full load in about 4 s) and AC-5 (every
## value is data); design/rules.md "Supply buildings" (about 4 s from empty to full, decided
## 2026-10-10; stopped means the Unit's real velocity is about zero, reading 2026-10-10) and its
## tuning list. Vocabulary: CONTEXT.md (Fuel, Ammo, Unit, Gyrocopter, Map).
##
## Data only. A SupplyZone reads these numbers and never writes them. One .tres
## (data/supply_settings.tres) is shared by supply_zone.tscn, so every zone tunes together; treat
## it as read-only at runtime (duplicate() it for a private copy). Every default below is zero on
## purpose, for the reason UnitStats gives: the engine leaves a property that equals its script
## default out of a saved .tres, so a tuned number would vanish from the data file. Write every
## tuned number into the .tres. first_problem() says whether the values can run a zone at all.

## Seconds a Fuel zone takes to fill a stopped Unit's tank from empty to full, whatever the tank's
## size: the zone gives the Unit's fuel_capacity over this time, so every type fills at the same
## pace in seconds (about 4 s, decided 2026-10-10). The Unit's own standing burn is taken out of
## it. Must be above zero (first_problem()).
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var fuel_seconds_to_full: float = 0.0

## Seconds an ammunition zone takes to fill a stopped Unit's gun from empty to a full load,
## whatever the load's size: the zone gives the Weapon's capacity in Shots over this time, so every
## type fills at the same pace in seconds (about 4 s, decided 2026-10-10), a whole Shot at a time
## (Weapon.rearm() keeps the fraction between ticks). Nothing is spent while the Unit stands, so
## the time to full is this and no more. Must be above zero (first_problem()).
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var ammo_seconds_to_full: float = 0.0

## The horizontal speed, in metres a second, at or below which a Unit counts as stopped in a zone.
## It is read from the Unit's real velocity, the motion of its last move, and is set above the
## noise of a Unit standing still (reading 2026-10-10; the Story 023 evidence doc keeps the
## measurement). Must be above zero (first_problem()).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:m/s") var stopped_speed: float = 0.0


## The reason these settings cannot run a zone, or an empty String when they can: the time to
## full of each kind and the stopped speed must each be above zero. Each test is written
## `not (x > 0.0)`, so a NaN is refused too (TD-012). SupplyZone._ready() applies it and pushes one
## named error when it is not empty.
func first_problem() -> String:
	if not (fuel_seconds_to_full > 0.0):
		return "fuel_seconds_to_full is not above zero"
	if not (ammo_seconds_to_full > 0.0):
		return "ammo_seconds_to_full is not above zero"
	if not (stopped_speed > 0.0):
		return "stopped_speed is not above zero"
	return ""
