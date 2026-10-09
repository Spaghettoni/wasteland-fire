class_name MineSettings
extends Resource
## Tuning values shared by every Mine and both MineLayers: how long a new Mine arms and how it
## blinks while it does, the size of its trigger, how far the no-mine approach in front of each
## Gate reaches, which layers make the ground not open and where the open-ground probe looks, and
## how long and how big the flash of a spent Mine is.
##
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-3 (a new Mine blinks for
## its arming time and is harmless, then shines steadily and is live), AC-4 (the flash), AC-5 (the
## no-mine approach and the open-ground test) and AC-9 (every value is data); design/rules.md
## "Turrets, Flag Walls and Mines" (the board's card Míny: about 3 s) and its tuning list.
## Vocabulary: CONTEXT.md (Mine, Truck, Base, Gate, Unit).
##
## Data only. A Mine and a MineLayer read these numbers and never write them. One .tres
## (data/mine_settings.tres) is shared by mine.tscn and both MineLayers, so every Mine tunes
## together; treat it as read-only at runtime (duplicate() it for a private copy). Every default
## below is zero on purpose, for the reason UnitStats gives: the engine leaves a property that
## equals its script default out of a saved .tres, so a tuned number would vanish from the data
## file. Write every tuned number into the .tres. first_problem() says whether the values can run
## a Mine at all.

## Seconds a new Mine blinks and is harmless before it goes live (the board's "about 3 s"). The
## Mine counts it in its own physics ticks (rounded, never under one tick), so it does not depend
## on the frame rate and the Round-over pause freezes it.
@export_range(0.0, 60.0, 0.1, "or_greater", "suffix:s") var arming_seconds: float = 0.0

## Seconds one blink lasts while the Mine arms: lit for blink_lit_fraction of it, then dark. Must
## be above zero (first_problem()). Counted in ticks like arming_seconds.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var blink_period_seconds: float = 0.0

## The share of each blink the Mine is lit for, from 0 to 1 (the Mine clamps it to that range).
@export_range(0.0, 1.0, 0.05) var blink_lit_fraction: float = 0.0

## Radius of the Mine's trigger, a cylinder on the ground, and of the disc that is drawn: what a
## Player sees is what sets it off. It also grows the no-mine areas and sets the footprint of the
## open-ground test. Must be above zero (first_problem()).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var trigger_radius: float = 0.0

## Height of the trigger cylinder above the ground. A ground Unit's box stands on the floor, so any
## height above zero meets it. Must be above zero (first_problem()).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var trigger_height: float = 0.0

## How far the no-mine approach reaches past a Base zone's Gate-side face, in metres: the zone and
## the approach together are where a lay is refused. On Map 01 the zone's Gate-side face lies 1.1 m
## inside the Gate wall's outer face, so 11.0 leaves no part of a Mine less than 9.9 m in front of
## the wall (the developer's "about 10 m", decided 2026-10-07).
@export_range(0.0, 100.0, 0.5, "or_greater", "suffix:m") var approach_past_zone: float = 0.0

## The physics layers that make the ground not open: a lay is refused when any body on them meets
## the Mine's footprint (the map, cliffs and water, and the cover in the shipped data). Must name a
## layer (first_problem()): with none, every place outside a Base would read as open ground.
@export_flags_3d_physics var open_ground_mask: int = 0

## Where the open-ground probe starts, metres above the drop point: above the Map's floor, whose top
## is the drop point, so the floor never counts.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var probe_floor: float = 0.0

## Where the open-ground probe ends, metres above the drop point. It must reach above every cliff:
## a cliff is a hollow shell of faces, so a footprint wholly inside the rock meets none of them,
## and only a probe that crosses the shell's top face finds it (the Gyrocopter's rise query
## reaches 20 m for the same reason). Must be above probe_floor (first_problem()).
@export_range(0.0, 100.0, 0.5, "or_greater", "suffix:m") var probe_top: float = 0.0

## Seconds the flash of a spent Mine stays, before the Mine is gone. Counted in ticks like the
## arming time.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var flash_seconds: float = 0.0

## Radius of the flash, a ball over the place of the Mine.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:m") var flash_radius: float = 0.0


## The reason these settings cannot run a Mine, or an empty String when they can: the trigger's
## radius and height, the blink period and the probe's height must each be above zero, and the
## open-ground mask must name a layer.
## Mine._ready() and MineLayer._ready() apply it and push one named error when it is not empty.
func first_problem() -> String:
	if trigger_radius <= 0.0:
		return "trigger_radius is not above zero"
	if trigger_height <= 0.0:
		return "trigger_height is not above zero"
	if blink_period_seconds <= 0.0:
		return "blink_period_seconds is not above zero"
	if probe_top <= probe_floor:
		return "probe_top is not above probe_floor"
	if open_ground_mask == 0:
		return "open_ground_mask names no layer"
	return ""
