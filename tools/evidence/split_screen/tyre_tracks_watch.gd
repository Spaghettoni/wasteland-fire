extends Node
## What the tyre_tracks scenario (Story 026) watches, after every Unit's tick: on every physics tick while `logging` is on, one row
## with the strokes the Map's TyreTracks made on that tick and, for each Player, the Unit's pose, whether it is alive and on the
## floor, its stats and its real speed after the tick. Added under the launch scene by tyre_tracks_kit.gd with a physics priority
## above the tracks' own (0, in the Map, which ticks before the Units) and every Unit's (0), so that a row holds what the tracks
## read at the END of the tick before (the row before this one's poses) and what the Units did on THIS tick (the runner's
## coroutines run before the nodes' tick, so a hook of the kit would read one tick late). It reads and writes nothing of the game.
## Tooling only: nothing under src/ depends on it.
## Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-1, AC-3 and AC-4.

## The physics priority of this node: later than the Units' default of 0.
const LATE_PRIORITY: int = 100

## The runner, for the tick count of a row.
var harness: Node
## The Map's TyreTracks.
var tracks: TyreTracks
## Each Player's Unit, in the order of the Players.
var units: Array[Unit] = []
## While true, a row is filed on every tick.
var logging: bool = false
## The rows, oldest first: see read().
var rows: Array[Dictionary] = []
## The Story 011 map kit (map_kit.gd), whose wall_contact() tells whether a Unit's last move touched anything but the ground.
var map_kit: Object


func _init() -> void:
	process_physics_priority = LATE_PRIORITY


func _physics_process(_delta: float) -> void:
	if logging:
		rows.append(read())


## Empties the rows.
func clear() -> void:
	rows = []


## One row now: {tick, frame (the process frame the tick ran in, which every tick of one frame shares), now (the tracks' clock), strokes (one {unit, tyre, from, to, width, time} for each stroke of this tick, in
## the order the node made them), queued (the quads the painter holds, waiting for the frame's redraw), poses (each Unit's global
## transform after this tick), alive, on_floor, stats (each Unit's stats), speed (each Unit's real speed along the ground, metres a
## second), walls (whether each Unit's move on this tick touched anything but the ground: a wreck, a tank, a wall, a rock)}.
func read() -> Dictionary:
	var made: Array[Dictionary] = []
	for stroke: TyreTracks.Stroke in tracks.strokes:
		made.append({"unit": stroke.unit_index, "tyre": stroke.tyre_index, "from": stroke.from, "to": stroke.to, "width": stroke.width, "time": stroke.time})
	var poses: Array[Transform3D] = []
	var alive: Array[bool] = []
	var floored: Array[bool] = []
	var stats: Array[UnitStats] = []
	var speeds: Array[float] = []
	var walls: Array[bool] = []
	for unit: Unit in units:
		poses.append(unit.global_transform)
		alive.append(unit.is_alive)
		floored.append(unit.is_on_floor())
		stats.append(unit.stats)
		var real: Vector3 = unit.get_real_velocity()
		speeds.append(Vector2(real.x, real.z).length())
		walls.append(map_kit != null and bool(map_kit.wall_contact(unit)))
	return {"tick": harness.ticks, "frame": Engine.get_process_frames(), "now": tracks.now, "strokes": made, "queued": tracks.painter.waiting(), "poses": poses, "alive": alive, "on_floor": floored, "stats": stats, "speed": speeds, "walls": walls}
