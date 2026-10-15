extends Node
## What the heights scenario (Story 020) watches over the whole run, after the Units' own tick: the lowest drawn
## point of every flying Unit's model on each tick it is in play, and on the tick each Unit is spawned. Added under
## the launch scene by heights_kit.gd with a physics priority above every Unit's, so that on each tick this node reads
## what the Unit and its model have done (the runner's coroutines run before the nodes' tick, so a hook of the kit
## would read one tick late). It reads and writes nothing of the game. Tooling only: nothing under src/ depends on it.
## Implements: production/epics/wasteland-fire/story-020-two-heights.md AC-2.

## The quick-fix helpers (quick_fix_kit.gd): the lowest point of a Unit's model.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The physics priority of this node: later than the Units' default of 0.
const LATE_PRIORITY: int = 100
## A lowest point this far (m) from `expected` is filed in `strays`.
const STRAY: float = 0.002

## The runner, for the tick count of a spawn's reading.
var harness: Node
## Each Player's Unit, in the order of the Players.
var units: Array[Unit] = []
## The height the lowest point of a flying Unit's model should stand at, metres.
var expected: float = 0.0
## Ticks sampled with a flying Unit in play, over both Players.
var samples: int = 0
## The ticks on which a flying Unit's model did a physics tick of its own (a rise would).
var ticks_ticking: int = 0
## The worst distance of a sampled lowest point from `expected` (above the floor: the Unit's body floats up to its safe
## margin, 1 mm, over it), and the biggest change of one Unit's lowest point between two ticks, metres. Then the same
## two measured from the Unit's own origin, which is where the model's scene puts it: the model alone.
var worst: float = 0.0
var biggest_step: float = 0.0
var worst_model: float = 0.0
var biggest_model_step: float = 0.0
## One entry per spawn of a flying Unit: {player, tick, low, at}, read inside the controller's own tick.
var spawn_reads: Array[Dictionary] = []
## The first ticks on which a lowest point stood more than 2 mm from `expected`: {tick, player, low, at} (a defect's trace).
var strays: Array[Dictionary] = []
## While true, each tick's lowest point of each Player's flying Unit goes to the Player's list in `lows`.
var recording: bool = false
var lows: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]

var _last: Array[float] = [NAN, NAN]
var _last_model: Array[float] = [NAN, NAN]


func _init() -> void:
	process_physics_priority = LATE_PRIORITY


## Samples both Units after their own tick.
func _physics_process(_delta: float) -> void:
	for player: int in units.size():
		var unit: Unit = units[player]
		var model: Node3D = _flying_model(unit)
		if model == null:
			_last[player] = NAN
			_last_model[player] = NAN
			continue
		var low: float = Quick.model_bottom(unit)
		var above_body: float = low - unit.global_position.y
		samples += 1
		if absf(low - expected) > STRAY and strays.size() < 6:
			strays.append({"tick": harness.ticks, "player": player, "low": low, "at": unit.global_position, "speed": unit.current_speed})
		worst = maxf(worst, absf(low - expected))
		worst_model = maxf(worst_model, absf(above_body - expected))
		if not is_nan(_last[player]):
			biggest_step = maxf(biggest_step, absf(low - _last[player]))
			biggest_model_step = maxf(biggest_model_step, absf(above_body - _last_model[player]))
		_last[player] = low
		_last_model[player] = above_body
		ticks_ticking += 1 if model.is_physics_processing() else 0
		if recording:
			lows[player].append(low)


## Reads a flying Unit the controller has just put in play (connect MatchController.unit_spawned to this).
func on_spawned(player: int) -> void:
	var unit: Unit = units[player]
	if _flying_model(unit) != null:
		spawn_reads.append({"player": player, "tick": harness.ticks, "low": Quick.model_bottom(unit), "at": unit.global_position})


## Starts a fresh recording of both Players' lowest points.
func start_recording() -> void:
	lows = [PackedFloat64Array(), PackedFloat64Array()]
	recording = true


## The model of a Unit that is in play and flies, or null.
func _flying_model(unit: Unit) -> Node3D:
	if unit == null or not unit.is_alive or unit.stats == null or not unit.stats.can_fly:
		return null
	return unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as Node3D
