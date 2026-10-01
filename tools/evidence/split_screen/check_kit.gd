extends RefCounted
## What the Story 003 scenarios (bases, destruction, countdown, respawn_showcase) share: the keys they
## press, the constants each of them used to declare for itself, and the helpers each had a private
## copy of: one CHECK verdict from a list of problems, a physics tick with a hook for a reading, and
## a key press. TD-003 (docs/tech-debt-register.md) asked for the runner to hold what every scenario
## needs; this holds what every scenario of Story 003 needs and the runner does not.
##
## A scenario makes one with Kit.new(harness) and sets on_tick to whatever it wants done after every
## tick it waits (a reading, a sample). The delay in ticks is the runner's ticks_in(): the one place
## that rule is written in tools/ (the MatchController has its own copy in src/, which the scenarios
## judge from outside). Loaded with a preload constant: nothing under tools/ declares a class_name.
## Tooling only: nothing under src/ depends on this file.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

## Player 1's debug-damage key: project.godot binds p1_debug_damage to it.
const KEYS_DEBUG_1: Array[Key] = [KEY_1]
## Player 2's debug-damage key (p2_debug_damage).
const KEYS_DEBUG_2: Array[Key] = [KEY_2]
## Player 1's Self-destruct key (p1_self_destruct).
const KEYS_DESTRUCT_1: Array[Key] = [KEY_TAB]
## Player 2's Self-destruct key (p2_self_destruct).
const KEYS_DESTRUCT_2: Array[Key] = [KEY_ENTER]
## Both Self-destruct keys, pressed in the same tick.
const KEYS_DESTRUCT_BOTH: Array[Key] = [KEY_TAB, KEY_ENTER]
## Both Players, in the order of the controller's indices (0 is Player 1).
const PLAYERS: Array[int] = [0, 1]

## Ticks waited before anything is read.
const START_TICKS: int = 10
## A count of ticks may differ from the one the delay gives by this many: a key acts on its tick or
## the next, and a label shown for a whole number may start or end a tick off the controller's reading.
const TICK_SLACK: int = 1
## Ticks a wait may run past the delay before a scenario gives up on the respawn.
const RESPAWN_SLACK_TICKS: int = 60
## A Unit on its Base is within this distance of the spawn point, and its camera of its offset point, metres.
const SPAWN_TOLERANCE: float = 0.05
## A Unit on its Base faces the spawn point's way: the dot product of the two facings is at least this.
const FACING_DOT_MIN: float = 0.999

## Called with no arguments after every tick this kit waits (tick, advance, press), if set.
var on_tick: Callable = Callable()

var _harness: Harness


func _init(harness: Node) -> void:
	_harness = harness as Harness


## Prints one CHECK line: a pass when there is no problem, else a fail that lists them.
func verdict(check_name: String, problems: PackedStringArray, detail: String) -> void:
	_harness.check(check_name, problems.is_empty(),
		detail + ("" if problems.is_empty() else " | PROBLEMS: " + "; ".join(problems)))


## Adds a problem unless the condition holds.
func need(problems: PackedStringArray, holds: bool, problem: String) -> void:
	if not holds:
		problems.append(problem)


## Waits one physics tick, then calls on_tick. A coroutine: await it.
func tick() -> void:
	await _harness.advance_ticks(1)
	if on_tick.is_valid():
		on_tick.call()


## Waits the given number of ticks. A coroutine: await it.
func advance(count: int) -> void:
	for _i: int in count:
		await tick()


## Presses the keys for one tick, then lets them go. The action acts on that tick or the next, so the
## caller waits on. Returns the runner's tick when the keys went down. A coroutine: await it.
func press(keys: Array[Key]) -> int:
	var at: int = _harness.ticks
	for key: Key in keys:
		_harness.set_key(key, true)
	await tick()
	for key: Key in keys:
		_harness.set_key(key, false)
	return at


## press() and one tick more, so the action has acted on whichever tick it lands on. Returns the
## tick the keys went down. A coroutine: await it.
func press_settled(keys: Array[Key]) -> int:
	var at: int = await press(keys)
	await tick()
	return at
