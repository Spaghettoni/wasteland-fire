class_name FordSettings
extends Resource
## Tuning values of a Map's fords: how fast a ground Unit may go inside one, as a fraction of its
## type's top speed.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-5 (inside either ford a
## ground Unit's speed is clamped to its type's top speed times one ford speed fraction, held as
## data in the Map; the starting value is 0.5, to tune by playing) and AC-9 (the ford speed
## fraction is data in the Map, not a constant in code); the author's answer of 2026-10-02 to the
## story's open question 2 (half speed, ground Units only); design/rules.md "Units". Vocabulary:
## CONTEXT.md (Map, Unit, Gyrocopter).
##
## Data only. A Ford reads the number and never writes it. Every ford of a Map references one .tres
## (data/ford_settings.tres for Map 01), so the fords tune together in one place. A .tres is shared
## by everything that loads it, so treat it as read-only at runtime (duplicate() it for a private
## copy). The default below is zero on purpose, for the reason UnitStats gives: the engine leaves a
## property out of a saved .tres when it equals the script default, so a .tres that lost its line
## makes no valid ford (the Ford refuses it with an error) instead of a silent change of speed.

## The fraction of a ground Unit's top speed, forward and in reverse, the ford allows, 0 to 1: 0.5
## holds each type at half its own top speed and 1.0 slows nothing. Which Units it slows is not
## here: the ford zone's collision mask lists ground Units only, so the Gyrocopter crosses at full
## speed. Zero (the default) means no valid ford: a Ford whose settings hold zero, or anything
## else outside (0, 1], pushes an error and slows nothing. Unit.limit_speed() applies it.
@export_range(0.0, 1.0, 0.01) var speed_fraction: float = 0.0
