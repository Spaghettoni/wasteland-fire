extends RefCounted
## One destruction, from the unit_destroyed signal to the unit_spawned that ends it, as the destruction
## scenario records it (wait_log.gd). An empty one (destroyed_tick -1) stands for a destruction that
## never came, so a key that did not destroy its Unit fails a check instead of raising an error.
##
## Loaded with a preload constant: nothing under tools/ declares a class_name. Tooling only: nothing
## under src/ depends on this file.

## The Player whose Unit was destroyed (0 is Player 1).
var player: int = 0
## The runner's tick when unit_destroyed arrived, or -1.
var destroyed_tick: int = -1
## The runner's tick when the matching unit_spawned arrived, or -1 while the wait is open.
var spawned_tick: int = -1
## Where the wreck lies.
var wreck: Vector3 = Vector3.ZERO
## seconds_until_respawn at the signal and after every tick of the wait.
var seconds: Array[float] = []
## Samples in which the Unit was in play or the controller said alive.
var in_play: int = 0
## Metres from the camera to its offset point at the Base, at the last sample.
var camera_gap: float = 0.0


## Ticks from the destruction to the respawn.
func length() -> int:
	return spawned_tick - destroyed_tick
