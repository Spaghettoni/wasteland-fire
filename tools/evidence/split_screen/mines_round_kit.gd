extends RefCounted
## What the Story 014 round scenarios share (mines_rounds.gd and mines_doubles.gd): a Round restarted with a number of
## Motorbikes a Player, the wait for a Round to end, the Round-over screens' first lines, a Unit spawned in this very
## tick (and the physics frame it was spawned in), the wait for a physics frame before a key is set, and what the
## Round did to the Players since a mark: the frames of the destructions, how often the Round ended and who won.
## Tooling only. Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-6.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## The Motorbikes a Player has in the loss Rounds.
const LAST_MOTORBIKE: int = 1
const WIN_TEXT: String = "Player %d wins!"
const NOBODY_TEXT: String = "Nobody wins!"
## Ticks a wait for the Round to end may take.
const WAIT_TICKS: int = 400

## The Motorbikes each Player had when the scenario began, for the Round that follows the loss Rounds.
var stock_before: int = 0
var _k: Kit14
var _q: Object
var _ui: UiKit


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q
	_ui = UiKit.new(_q.tokens)
	stock_before = int(_q.harness.split.field.token_stock.counts.get(&"motorbike", 0))


## Sets the Motorbikes each Player starts a Round with, on the field's own stock (the runner's copy, never the shared
## file), then restarts the Round (R and both Players choose the Motorbike). A coroutine.
func restart_with(count: int) -> void:
	_q.harness.split.field.token_stock.counts[&"motorbike"] = count
	await _k.w.restart()


## Waits at most WAIT_TICKS for the Round to be over. A coroutine.
func wait_over() -> void:
	for _tick: int in WAIT_TICKS:
		if _q.controller.is_round_over():
			return
		await _q.kit.tick()


## The Round-over screens' first lines, Player 1's first.
func screens() -> PackedStringArray:
	return [_ui.over_screen(0).find_child("WinnerLabel", true, false).text, _ui.over_screen(1).find_child("WinnerLabel", true, false).text]


## Spawns a Player's Unit as a type at a place in this tick, as a new Unit the MineLayer sees (it leaves play first when
## it is in play): the physics frame of the call.
func spawn_now(player: int, type_index: int, at: Vector3, facing: Vector3) -> int:
	var unit: Unit = _q.units.units[player]
	if unit.is_alive:
		unit.leave_play()
	_q.units.retype(player, type_index, at, facing)
	return Engine.get_physics_frames()


## Waits until the physics frame, however far off, then sets the keys (TokenKit.press_on() waits 60 ticks at most). A coroutine.
func press_on(frame: int, keys: Array[Key]) -> void:
	while Engine.get_physics_frames() < frame - 1:
		await _q.kit.tick()
	await _q.tokens.press_on(frame, keys)


## The frame of the first destruction of the Player's Unit since the mark of the Token kit's events, or -1.
func frame_of(player: int, mark: int) -> int:
	for event: Dictionary in _q.tokens.events_of(&"destroyed", mark):
		if event["arg"] == player:
			return int(event["now"]["frame"])
	return -1


## What the Round did since the mark: the destruction frames and Players, how many times it ended, the winner and the screens.
func outcome(mark: int) -> Dictionary:
	var killed: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	return {"frames": killed.map(func(e: Dictionary) -> int: return int(e["now"]["frame"])), "players": killed.map(func(e: Dictionary) -> int: return int(e["arg"])),
		"overs": _q.tokens.events_of(&"over", mark).size(), "winner": _q.controller.winner_index(), "screens": screens()}


## Whether an outcome is the double loss: both Motorbikes in one frame, the Round ended once, nobody won.
func is_double(result: Dictionary) -> bool:
	return result["frames"].size() == 2 and result["frames"][0] == result["frames"][1] and result["players"].has(0) and result["players"].has(1) \
			and result["overs"] == 1 and result["winner"] == MatchController.NO_WINNER and result["screens"] == PackedStringArray([NOBODY_TEXT, NOBODY_TEXT])
