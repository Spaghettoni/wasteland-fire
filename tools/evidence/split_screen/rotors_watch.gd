extends Node
## What the rotors scenario (Story 025) watches, after the pivots' tick: for each Player, on every physics tick while `logging`
## is on, a row with the Unit's state, its model's turning parts and its speed. Added under the launch scene by rotors_kit.gd with
## a physics priority above the pivots' (1) and every Unit's (0), so that a row holds what the Unit, its model and the pivots
## did on THAT tick (the runner's coroutines run before the nodes' tick, so a hook of the kit would read one tick late). It reads
## and writes nothing of the game. Tooling only: nothing under src/ depends on it.
## Implements: production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-1, AC-3 and AC-4.

## The physics priority of this node: later than the Units' default of 0 and the pivots' 1.
const LATE_PRIORITY: int = 100

## The runner, for the tick count of a row.
var harness: Node
## Each Player's Unit, in the order of the Players.
var units: Array[Unit] = []
## While true, a row is filed for each Player on every tick.
var logging: bool = false
## The rows of each Player, oldest first: see read().
var rows: Array[Array] = [[], []]


func _init() -> void:
	process_physics_priority = LATE_PRIORITY


func _physics_process(_delta: float) -> void:
	if not logging:
		return
	for player: int in units.size():
		rows[player].append(read(player))


## Empties both Players' rows.
func clear() -> void:
	rows = [[], []]


## One Player's row now: {tick, alive, shown (the model is visible in the tree), pivots (one {name, angle, rate} for each
## RotorPivot under the model, in the order of its children), along (the real velocity along the facing, signed, metres a second),
## top (the top speed in the direction it moves), share (|along| / top, 0 to 1)}.
func read(player: int) -> Dictionary:
	var unit: Unit = units[player]
	var model: Node3D = unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as Node3D
	var pivots: Array[Dictionary] = []
	if model != null:
		for child: Node in model.get_children():
			var pivot: RotorPivot = child as RotorPivot
			if pivot != null:
				pivots.append({"name": pivot.name, "angle": pivot.angle, "rate": pivot.current_turns_per_second})
	var along: float = unit.get_real_velocity().dot(-unit.global_transform.basis.z.normalized())
	var top: float = unit.stats.max_speed if along >= 0.0 else unit.stats.reverse_max_speed
	return {"tick": harness.ticks, "alive": unit.is_alive, "shown": model != null and model.is_visible_in_tree(), "pivots": pivots,
			"along": along, "top": top, "share": clampf(absf(along) / top, 0.0, 1.0)}
