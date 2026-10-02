class_name FuelCanSettings
extends Resource
## Tuning values shared by the Fuel Cans: how much Fuel one Can gives and how long a taken Can stays
## away.
##
## Implements: design/game-brief.md MVP feature 6 (Fuel and Fuel Cans) and
## production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-6; design/rules.md
## "Resources": Fuel Cans (the source's kanister) respawn at fixed places on the Map, and the Fuel
## Can's amount and its respawn time are tuning values. A Unit that touches an available Can is
## refilled by refill_amount, and the Can vanishes and comes back at the same spot
## respawn_delay_seconds later (FuelCan). One .tres (data/fuel_can_settings.tres) holds the shipped
## values and fuel_can.tscn references it, so every Can tunes together.
##
## Data only. A FuelCan reads these numbers and never writes them. One .tres is shared by every Can
## that references it, so treat it as read-only at runtime (duplicate() it for a private copy).
## Every default below is zero on purpose, for the reason UnitStats gives: the engine leaves a
## property out of a saved .tres when it equals the script default. Write every tuned number into
## the .tres.

## Fuel units one Can gives the Unit that touches it (Story 006 AC-6), never more than the room left
## in that Unit's tank (Unit.refuel() stops at the Unit's fuel_capacity). A Unit with a full tank
## leaves the Can where it is. Zero by default (class doc): a Can whose settings have no line gives
## nothing, so no Unit ever takes it.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:fuel") var refill_amount: float = 0.0

## Seconds a taken Can stays away before it is back at the same spot (Story 006 AC-6). The Can
## counts it in physics ticks (rounded, never under one tick), so it does not depend on the frame
## rate, and the Round-over pause counts toward it (a restart brings every Can back anyway). Zero by
## default (class doc): a Can whose settings have no line is back one tick after it was taken.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:s") var respawn_delay_seconds: float = 0.0
