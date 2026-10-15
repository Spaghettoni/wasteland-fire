extends RefCounted
## A crash and the Round, for the crash scenario (Story 021 AC-6, the sentences on the Round): crash_never_ends_a_round (a Gyrocopter's
## crash into a leg takes its Token and the Round plays on), crash_on_the_loss_tick (Player 1's last Motorbike Self-destructs in the
## very physics frame Player 2's Gyrocopter crashes: the Round ends once, Player 2 wins, and the crash's Token is taken in that
## frame), crash_then_double_loss (a crash earlier in a Round changes nothing of the Motorbikes: both Players' last Motorbikes
## Self-destructing in one frame still end it with "Nobody wins!") and nothing_after_over (once the Round is over, the tree is
## paused: a Gyrocopter frozen at top speed in front of a leg stays there, alive, with its Tokens, until R, which also brings the
## shipped Motorbike stock back). The frames are timed
## from a control Round, as story 014's doubles are, and each Round has one Motorbike a Player. A crash cannot meet a double loss
## in one frame: each Player has one Unit, a Gyrocopter or a Motorbike. Run by crash.gd. Tooling only. Every number comes from
## the game's data and the control; the scenario types only its test inputs.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Round14: GDScript = preload("res://tools/evidence/split_screen/mines_round_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## Where Player 1's Motorbike (and, in the double loss, Player 2's) waits in the open, out of every Base and every Turret's reach.
const OPEN_1: Vector3 = Vector3(-30.0, 0.0, 12.0)
const OPEN_2: Vector3 = Vector3(30.0, 0.0, 12.0)
## The frames before its contact that the Round ends in the last case, and the ticks the frozen Round is followed.
const CUT_FRAMES: int = 5
const FROZEN_TICKS: int = 120
## The ticks a crash may take after the tool put the Gyrocopter down.
const FLIGHT_FRAMES: int = 300

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick
var _r: Round14
var _line: Dictionary = {}
var _crash_frames: int = -1


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()
	_r = Round14.new(kit.mines())


## The checks, in order. A coroutine: await it.
func run() -> void:
	_line = _k.line(Kit21.path_of("leg", 1), Vector3.RIGHT)
	await _end_the_round()
	await _new_round()
	await _crash_never_ends_a_round()
	await _crash_then_double_loss()
	await _new_round()
	await _crash_on_the_loss_tick()
	await _new_round()
	await _nothing_after_over()


## Player 2 carries Base A's Flag home, so that the Round is over and R can start the loss Rounds (story 016's way).
func _end_the_round() -> void:
	var problems: PackedStringArray = []
	for player: int in Kit21.Kit.PLAYERS:
		await _k.mines().revive(player)
	await _k.walls().restore_all(true)
	await _k.walls().turrets_down()
	_k.flags().wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await _k.flags().take_flag(1, 0, Walls.GATE)
	await _k.flags().back_out(1, 0, Walls.GATE)
	var delivered: bool = await _k.flags().deliver(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by Player 2's delivery (taken %s, delivered %s)" % [taken, delivered])
	_q.kit.verdict("round_ended_for_the_loss_rounds", problems, "Player 2 carried Base A's Flag home: the Round was over, so that R could start the loss Rounds")


## A new Round with one Motorbike a Player, Player 1's Motorbike waiting in the open.
func _new_round() -> void:
	await _r.restart_with(Round14.LAST_MOTORBIKE)
	await _k.mines().put(0, Quick.MOTORBIKE, OPEN_1, Vector3.RIGHT)


## The Gyrocopter of Player 2, its throttle held, put down at the line's start by the tool in this very frame: the frame.
func _release_gyrocopter() -> int:
	_q.harness.drive(1, 1, 0)
	var frame: int = _r.spawn_now(1, Kit21.GYRO, _line["start"], _line["dir"])
	return frame


## The destructions of a Player since a mark.
func _deaths(player: int, mark: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in _q.tokens.events_of(&"destroyed", mark):
		if int(event["arg"]) == player:
			found.append(event)
	return found


## crash_never_ends_a_round (AC-6): the control Round. Player 2's Gyrocopter crashes into the leg; its Token is taken, the Round plays
## on with both Motorbikes, and the frames from the tool's spawn to the crash are measured for the Rounds that follow.
func _crash_never_ends_a_round() -> void:
	var problems: PackedStringArray = []
	var tokens_before: int = _k.tokens(1)
	var motorbikes: Array[int] = [_k.tokens(0, Quick.MOTORBIKE), _k.tokens(1, Quick.MOTORBIKE)]
	var mark: int = _q.tokens.events.size()
	var spawned: int = _release_gyrocopter()
	for _tick: int in FLIGHT_FRAMES:
		await _q.kit.tick()
		if not _deaths(1, mark).is_empty():
			break
	_q.harness.release_all()
	var died: Array[Dictionary] = _deaths(1, mark)
	_crash_frames = int(died[0]["now"]["frame"]) - spawned if not died.is_empty() else -1
	await _q.kit.advance(60)
	_q.kit.need(problems, died.size() == 1 and _crash_frames > 0, "the control: %d destructions of Player 2, %d frames to the crash" % [died.size(), _crash_frames])
	_q.kit.need(problems, tokens_before - _k.tokens(1) == 1 and [_k.tokens(0, Quick.MOTORBIKE), _k.tokens(1, Quick.MOTORBIKE)] == motorbikes, "the control: the Gyrocopter Tokens went %d to %d and the Motorbike Tokens %s to %s" % [tokens_before, _k.tokens(1), motorbikes, [_k.tokens(0, Quick.MOTORBIKE), _k.tokens(1, Quick.MOTORBIKE)]])
	_q.kit.need(problems, not _q.controller.is_round_over() and _q.controller.winner_index() == MatchController.NO_WINNER and _q.controller.is_alive(0), "the Round is over (%s) 60 ticks after the crash, winner %d" % [_q.controller.is_round_over(), _q.controller.winner_index()])
	measured.append("crash_frames=%d" % _crash_frames)
	_q.kit.verdict("crash_never_ends_a_round", problems, "Player 2's Gyrocopter crashed into a leg %d frames after the tool put it down: its Gyrocopter Token was taken (%d to %d), both Players' Motorbike Tokens stayed at %s, and the Round was still on 60 ticks later with no winner" % [_crash_frames, tokens_before, _k.tokens(1), motorbikes])
	await _k.mines().revive(1)


## crash_then_double_loss (AC-6): the same Round goes on after the crash; both Players Self-destruct their one Motorbike outside their
## Bases on one tick, and the Round ends once with no winner, "Nobody wins!" in both views.
func _crash_then_double_loss() -> void:
	var problems: PackedStringArray = []
	await _k.mines().put(1, Quick.MOTORBIKE, OPEN_2, Vector3.LEFT)
	var mark: int = _q.tokens.events.size()
	await _q.kit.press_settled(Kit21.Kit.KEYS_DESTRUCT_BOTH)
	await _r.wait_over()
	await _q.kit.advance(2)
	var outcome: Dictionary = _r.outcome(mark)
	_q.kit.need(problems, _r.is_double(outcome), "after a crash earlier in the Round the double loss came out as %s" % [outcome])
	_q.kit.verdict("crash_then_double_loss", problems, "after Player 2's crash earlier in the Round, both last Motorbikes Self-destructed on frame %s: the Round ended once with '%s' in both views, as it does with no crash before" % [outcome["frames"], Round14.NOBODY_TEXT])


## crash_on_the_loss_tick (AC-6): Player 1's last Motorbike Self-destructs in the frame Player 2's Gyrocopter crashes. The Round ends
## once, Player 2 wins, and the Gyrocopter Token was taken in that frame, before the Round's loss was decided.
func _crash_on_the_loss_tick() -> void:
	var problems: PackedStringArray = []
	var tokens_before: int = _k.tokens(1)
	var mark: int = _q.tokens.events.size()
	var records: int = _k.destroyed.size()
	var spawned: int = _release_gyrocopter()
	await _r.press_on(spawned + _crash_frames - 1, Tokens.keys(&"destruct", 0))
	await _r.wait_over()
	await _q.kit.advance(2)
	_q.harness.release_all()
	var outcome: Dictionary = _r.outcome(mark)
	var frames: Array = outcome["frames"]
	_q.kit.need(problems, frames.size() == 2 and frames[0] == frames[1] and frames[0] == spawned + _crash_frames, "the destructions came on frames %s (the crash frame is %d)" % [frames, spawned + _crash_frames])
	_q.kit.need(problems, outcome["overs"] == 1 and outcome["winner"] == 1 and outcome["screens"] == PackedStringArray([Round14.WIN_TEXT % 2, Round14.WIN_TEXT % 2]), "the Round ended %d times, winner %d, screens %s" % [outcome["overs"], outcome["winner"], outcome["screens"]])
	var crash: Dictionary = {}
	for index: int in range(records, _k.destroyed.size()):
		if int(_k.destroyed[index]["player"]) == 1:
			crash = _k.destroyed[index]
	_q.kit.need(problems, not crash.is_empty() and int(crash["frame"]) == frames[0] and int(crash["counts"][Kit21.GYRO]) == tokens_before - 1, "the crash's record %s: its Token count in the handler should be %d" % [crash.get("counts", []), tokens_before - 1])
	_q.kit.need(problems, _k.tokens(0, Quick.MOTORBIKE) == 0 and _k.tokens(1, Quick.MOTORBIKE) == Round14.LAST_MOTORBIKE and _k.tokens(1) == tokens_before - 1, "the Tokens after: Player 1's Motorbikes %d, Player 2's Motorbikes %d and Gyrocopters %d" % [_k.tokens(0, Quick.MOTORBIKE), _k.tokens(1, Quick.MOTORBIKE), _k.tokens(1)])
	_q.kit.verdict("crash_on_the_loss_tick", problems, "Player 1's last Motorbike Self-destructed in frame %s, the very frame Player 2's Gyrocopter crashed into a leg (%d frames after the tool put it down): the Round ended once, '%s' in both views, and the crash's Gyrocopter Token was already taken when its destruction was announced (%d to %d, Player 2's Motorbike still %d)" % [frames, _crash_frames, Round14.WIN_TEXT % 2, tokens_before, _k.tokens(1), _k.tokens(1, Quick.MOTORBIKE)])


## nothing_after_over (AC-6): the Round ends five frames before the Gyrocopter would reach the leg. The tree is paused with the Gyrocopter
## at top speed in front of the leg; for 120 ticks it does not move, does not crash and keeps its Token; R starts the next Round.
func _nothing_after_over() -> void:
	var problems: PackedStringArray = []
	var unit: Unit = _q.units.units[1]
	var tokens_before: int = _k.tokens(1)
	var mark: int = _q.tokens.events.size()
	var spawned: int = _release_gyrocopter()
	await _r.press_on(spawned + _crash_frames - CUT_FRAMES - 1, Tokens.keys(&"destruct", 0))
	await _r.wait_over()
	var at_over: Vector3 = unit.global_position
	var cmd_over: float = unit.current_speed
	var nose: float = _k.nose_gap(at_over, _line)
	for _tick: int in FROZEN_TICKS:
		await _q.kit.tick()
	_q.kit.need(problems, _q.controller.is_round_over() and _q.harness.get_tree().paused, "the Round is not over and paused")
	_q.kit.need(problems, unit.is_alive and unit.global_position.distance_to(at_over) <= Kit21.PLACE_TOLERANCE and _deaths(1, mark).is_empty() and _k.tokens(1) == tokens_before, "after %d ticks of the pause: alive %s, moved %.4f m, %d destructions of Player 2, Tokens %d to %d" % [FROZEN_TICKS, unit.is_alive, unit.global_position.distance_to(at_over), _deaths(1, mark).size(), tokens_before, _k.tokens(1)])
	_q.kit.need(problems, cmd_over >= 0.99 * _k.gyro_stats().max_speed and nose > 0.0 and nose < 2.0, "at the Round's end it commanded %.2f m/s, %.3f m from the leg's face" % [cmd_over, nose])
	await _r.restart_with(_r.stock_before)
	await _q.kit.advance(2)
	_q.kit.need(problems, not _q.controller.is_round_over() and _deaths(1, mark).is_empty() and _k.tokens(1) == tokens_before, "after R: the Round is over %s, %d destructions of Player 2, Tokens %d to %d" % [_q.controller.is_round_over(), _deaths(1, mark).size(), tokens_before, _k.tokens(1)])
	measured.append("frozen_nose=%.3f" % nose)
	_q.kit.verdict("nothing_after_over", problems, "the Round ended %d frames before Player 2's Gyrocopter would have crashed: it stood frozen at %.1f m/s %.3f m from the leg for %d ticks of the pause, alive, unmoved, with its Token, and R started the next Round with no destruction of it" % [CUT_FRAMES, cmd_over, nose, FROZEN_TICKS])
