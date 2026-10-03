extends RefCounted
## Scenario tokens_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames and the playtest record of Story 008 (AC-3, AC-4, AC-6, AC-7) on Map 01, three
## Rounds in about 26 simulated seconds (RESULT t=) with every Player key a real event (Space and
## Period confirm, A and D steer Player 1's cursor, Tab and Enter Self-destruct, R restarts). The
## Token stock is the scenario's own (STOCK_COUNTS: Motorbike 2, Buggy 4, Truck 3, Gyrocopter 1) so
## a Round is short and no two counts are alike. Round A: both choose (Player 1 the Gyrocopter,
## Player 2 the Motorbike); Player 1 Self-destructs the Gyrocopter (its slot goes dim at x0 and the
## cursor leaves it; one step of the cursor skips it), chooses a Motorbike during the countdown,
## Self-destructs that one (the HUD falls to 1) and then its next: its last Motorbike is gone,
## Player 1 has lost and Player 2 wins, with Player 2 driving on all the while. R. Round B: Player
## 1's Motorbike takes Player 2's Flag and delivers it into Base A: Player 1 wins by delivery, no
## Token spent. R. Round C: both Self-destruct their first Motorbike on one tick, choose again and
## lose their last on one frame: nobody wins. R.
##
## Output: SPLIT lines at every moment (moment=, after its hold, with what each view shows) and at
## every choice, spawn, destruction, pick-up and Round signal (event=), each with frame=, the
## number of the PNG that shows it in a --write-movie recording (a moment's line counts back
## ShowKit.MOMENT_FRAME_LAG iterations, an event's own iteration). No CHECK in a normal run: it
## ends with RESULT ok. A step that did not happen, or a view that shows anything but what the
## scenario's own count and the Round make of it, prints one failing CHECK named premise, so an
## empty or false recording cannot pass as evidence (ShowKit.judge()). Helpers:
## tokens_showcase_kit.gd, token_kit.gd, token_ui_kit.gd, token_choice_kit.gd, flag_kit.gd and
## loss_kit.gd (the Flag run of Round B).
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md, Test Evidence
## (the choice with its counts, the Round-over screen after a loss, both views after the restart;
## a Round lost by the last Motorbike and one won by a delivery). Tooling only: nothing under src/
## depends on this file.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/tokens.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=tokens_showcase
##
## Kills: the wrong implementation each moment's premise fails. Every line was shown by a seeded
## defect in a scratch copy of src/; the moment named is the first at which it failed.
##  choose_start        counts not written, or all of the first type's; the panel not shown by
##                      round_started or not titled as choosing; a HUD line hidden, or reading the
##                      Buggy's count
##  units_in_play       a Token taken at the spawn; a HUD line that follows the spawned Unit's type
##  choose_after_gyro   a Self-destruct that costs no Token, another type's or both Players'; counts
##                      read once or the other Player's; no dim slot, its text not grey (or one
##                      label only); no cursor snap (also with the mark winning over the dim), or a
##                      snap that goes down; no countdown; a HUD line on the cursor's type, the
##                      other Player's count or hidden at the destruction
##  cursor_skips_dim    a steer key that stops on the empty slot
##  hud_tokens          a Unit that respawns after a destruction costing a second Token
##  hud_after_destruct  a HUD line read at the spawn and not at the destruction; a loss at one
##                      Motorbike Token left
##  round_over_loss     a loss never decided, a tick late or announced twice (caught in the step
##                      before the moment); naming the loser; no pause; the choice panel left up;
##                      the screen in one view only
##  restart_a           a restart that refills nothing or leaves the screen up; a dim slot not
##                      undone
##  round_over_delivery a delivery that does not end the Round (also caught in its step), costs a
##                      Token or always names Player 2
##  restart_b           Flags not seated again by the restart (caught in the step before)
##  both_destroyed      two destructions in one frame charged once, or Player 1's only
##  round_over_nobody   a double loss won by Player 1 or read as 'Player 0 wins!'; one not announced
##                      (caught in the step before the moment)
##  restart_c           a restart that refills the stock only after a Round that had a winner
##  end                 an engine ERROR or WARNING anywhere in the run

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and key presses.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the type ids of the data in order, the settle time.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 008 helpers (token_kit.gd): the real keys of the choice, the Self-destruct, R.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 004 helpers (flag_kit.gd): the moves of a Flag run.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")
## This scenario's helpers (tokens_showcase_kit.gd): the count, the judgement, the lines.
const ShowKit: GDScript = preload("res://tools/evidence/split_screen/tokens_showcase_kit.gd")
## The loss scenario's helpers (loss_kit.gd): the static carry_to_gate() and deliver() of Round B.
const Loss: GDScript = preload("res://tools/evidence/split_screen/loss_kit.gd")

## The Token stock the runner builds for this scenario, type_id to count, for each Player.
const STOCK_COUNTS: Dictionary = {&"motorbike": 2, &"buggy": 4, &"truck": 3, &"gyrocopter": 1}
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## Simulated seconds before the watchdog.
const WATCHDOG_SECONDS: float = 150.0
## The types as indexes into the data (the premise checks the data's order).
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }
## The seconds each moment is held still before its line (and its frame) is taken, in the order the
## moments are reached.
const HOLDS: Dictionary[StringName, float] = {&"choose_start": 1.0, &"units_in_play": 1.0,
	&"choose_after_gyro": 1.2, &"cursor_skips_dim": 1.0, &"hud_tokens": 1.0, &"hud_after_destruct": 1.0,
	&"round_over_loss": 1.5, &"restart_a": 1.0, &"round_over_delivery": 1.5, &"restart_b": 1.0,
	&"both_destroyed": 1.0, &"round_over_nobody": 1.5, &"restart_c": 1.5}
## Seconds the last Motorbike of Round A is seen before its Player Self-destructs it.
const LEAD_SECONDS: float = 0.5
## The speed Player 2's throttle is feathered under while it drives on in Round A, m/s.
const P2_CRUISE: float = 10.0
## The state of a choice panel whose Player is out of play and has not chosen.
const CHOOSING: StringName = &"choosing"
## The state of a choice panel while its Player's Unit is in play.
const HIDDEN: StringName = &"hidden"

var _h: Harness
var _kit: Kit
var _sk: ShowKit
var _tk: Tokens
var _fk: Flags
## The type ids of the data in order.
var _ids: Array[StringName] = []
## Whether Player 2's throttle is held (feathered under P2_CRUISE after every tick).
var _driving: bool = false


## Plays the three Rounds. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_sk = ShowKit.new(harness, _kit)
	_tk = _sk.tk
	_fk = Flags.new(harness, _kit)
	_kit.on_tick = _feather
	_h.phase = &"setup"
	_check_data()
	await _round_a()
	await _round_b()
	await _round_c()
	_finish()


## The premise on the data: the types in the order the scenario names them, the Motorbike the
## carrier, and the stock the runner built from STOCK_COUNTS.
func _check_data() -> void:
	var row: Array[int] = []
	for stats: UnitStats in _tk.controller.unit_types():
		_ids.append(stats.type_id)
		row.append(int(STOCK_COUNTS.get(stats.type_id, 0)))
	_sk.need(_ids == Units.TYPE_IDS and _sk.carrier == Type.MOTORBIKE, "the types are %s and the carrier is %d" % [_ids, _sk.carrier])
	_sk.need(_sk.start == [row, row], "the runner gave the Players %s, expected %s from STOCK_COUNTS" % [_sk.start, row])


## Round A: the choice with its counts, a Gyrocopter spent (dim, the cursor away from it), a
## Motorbike spent (the HUD falls), the last Motorbike spent: Player 1 loses, Player 2 wins; R.
func _round_a() -> void:
	await _sk.moment(&"choose_start", HOLDS[&"choose_start"], [CHOOSING, CHOOSING])
	await _start_with([Type.GYROCOPTER, Type.MOTORBIKE])
	_driving = true
	await _sk.moment(&"units_in_play", HOLDS[&"units_in_play"], [HIDDEN, HIDDEN])
	_h.phase = &"p1_destroys_gyrocopter"
	await _destruct([Harness.PLAYER_1], Type.GYROCOPTER)
	await _sk.moment(&"choose_after_gyro", HOLDS[&"choose_after_gyro"], [CHOOSING, HIDDEN])
	_sk.need(_cursor(Harness.PLAYER_1) == Type.MOTORBIKE, "the cursor did not snap up from the empty Gyrocopter and wrap to the Motorbike")
	_h.phase = &"p1_steers_back"
	await _kit.press_settled(Tokens.keys(&"previous", Harness.PLAYER_1))
	await _sk.moment(&"cursor_skips_dim", HOLDS[&"cursor_skips_dim"], [CHOOSING, HIDDEN])
	_sk.need(_cursor(Harness.PLAYER_1) == Type.TRUCK, "A from the Motorbike did not skip the empty Gyrocopter to the Truck")
	_h.phase = &"p1_chooses_motorbike"
	await _choose_all([Harness.PLAYER_1], Type.MOTORBIKE)
	await _sk.moment(&"hud_tokens", HOLDS[&"hud_tokens"], [HIDDEN, HIDDEN])
	_h.phase = &"p1_destroys_motorbike"
	await _destruct([Harness.PLAYER_1], Type.MOTORBIKE)
	await _sk.moment(&"hud_after_destruct", HOLDS[&"hud_after_destruct"], [CHOOSING, HIDDEN])
	_h.phase = &"p1_chooses_last_motorbike"
	await _choose_all([Harness.PLAYER_1], Type.MOTORBIKE)
	await _kit.advance(_h.ticks_in(LEAD_SECONDS))
	_h.phase = &"p1_loses_last_motorbike"
	await _sk.ended_by_loss(await _destruct([Harness.PLAYER_1], Type.MOTORBIKE))
	_driving = false
	_h.drive(Harness.PLAYER_2, 0, 0)
	await _sk.moment(&"round_over_loss", HOLDS[&"round_over_loss"], [HIDDEN, HIDDEN], Harness.PLAYER_2)
	await _restart(&"restart_a")


## Round B: Player 1's Motorbike takes Player 2's Flag and drives it into Base A: a delivery; R.
func _round_b() -> void:
	await _start_with([Type.MOTORBIKE, Type.MOTORBIKE])
	_h.phase = &"p1_takes_flag_2"
	var carried: bool = await Loss.carry_to_gate(_fk, Harness.PLAYER_1, Harness.PLAYER_2, Harness.PLAYER_1)
	_sk.need(carried, "Player 1 does not carry Player 2's Flag")
	_h.phase = &"p1_delivers"
	var ticks: int = await Loss.deliver(_fk, Harness.PLAYER_1)
	_sk.need(ticks > 0, "the Round did not end by Player 1's delivery")
	await _sk.moment(&"round_over_delivery", HOLDS[&"round_over_delivery"], [HIDDEN, HIDDEN], Harness.PLAYER_1)
	await _restart(&"restart_b")


## Round C: both Self-destruct a Motorbike on one tick, choose again and lose the last on one
## frame: nobody wins; R.
func _round_c() -> void:
	await _start_with([Type.MOTORBIKE, Type.MOTORBIKE])
	_h.phase = &"both_destroy_motorbike"
	await _destruct(Kit.PLAYERS, Type.MOTORBIKE)
	await _sk.moment(&"both_destroyed", HOLDS[&"both_destroyed"], [CHOOSING, CHOOSING])
	_h.phase = &"both_choose_last_motorbike"
	await _choose_all(Kit.PLAYERS, Type.MOTORBIKE)
	_h.phase = &"both_lose_last_motorbike"
	await _sk.ended_by_loss(await _destruct(Kit.PLAYERS, Type.MOTORBIKE))
	await _sk.moment(&"round_over_nobody", HOLDS[&"round_over_nobody"], [HIDDEN, HIDDEN], MatchController.NO_WINNER)
	await _restart(&"restart_c")


## Both Players steer to `types` (one type index each) with the real steer keys and confirm
## together with Space and Period: both Units must be in play within the bench settle and two
## ticks of the press, as the types chosen.
func _start_with(types: Array[int]) -> void:
	_h.phase = &"both_choose"
	for player: int in Kit.PLAYERS:
		for _step: int in _ids.size():
			if _cursor(player) != types[player]:
				await _kit.press_settled(Tokens.keys(&"next", player))
	var appeared: Array[int] = await _sk.ui.fire_both()
	await _kit.advance(Units.SETTLE_TICKS)
	var soon: int = MatchController.SPAWN_SETTLE_TICKS + 2
	var made: Array[StringName] = [_tk.units.units[0].type_id, _tk.units.units[1].type_id]
	var wanted: Array[StringName] = [_ids[types[0]], _ids[types[1]]]
	_sk.need(made == wanted and appeared.all(func(ticks: int) -> bool: return ticks >= 0 and ticks <= soon),
		"the Units are %s after %s ticks (at most %d), expected %s" % [made, appeared, soon, wanted])


## Each Player of `players` chooses the type with its real keys during the countdown, then all wait
## until their Units are in play (the respawn delay and the check kit's slack at most).
func _choose_all(players: Array[int], type_index: int) -> void:
	var ok: bool = true
	for player: int in players:
		ok = await _tk.choose(player, type_index) and ok
	var limit: int = _h.ticks_in(_tk.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	for player: int in players:
		ok = await _tk.units.wait_alive(player, limit) >= 0 and ok
	await _kit.advance(Units.SETTLE_TICKS)
	_sk.need(ok, "the Players %s did not choose and come into play" % [players])


## The Self-destruct keys of the Players on one tick: one Token of `type_index` is spent from each
## in the scenario's own count and the destructions are waited for. Returns the events index
## before the press.
func _destruct(players: Array[int], type_index: int) -> int:
	var mark: int = _tk.events.size()
	var pressed: Array[Key] = []
	for player: int in players:
		pressed.append_array(Tokens.keys(&"destruct", player))
		_sk.rows[player][type_index] -= 1
	await _kit.press_settled(pressed)
	await _tk.wait_for(&"destroyed", mark)
	_sk.need(_tk.events_of(&"destroyed", mark).size() == players.size(), "%d unit_destroyed for the Players %s" % [_tk.events_of(&"destroyed", mark).size(), players])
	return mark


## R, then the moment after it: the scenario's count is the stock again, both Flags stand on their
## seats, both Players are choosing and no Round-over screen is up.
func _restart(moment: StringName) -> void:
	_h.phase = &"restart"
	_sk.rows = _sk.start.duplicate(true)
	var started: bool = await _tk.restart()
	_sk.need(started and _sk.ui.flags_home().is_empty(), "R gave round_started %s; Flags: %s" % [started, _sk.ui.flags_home()])
	await _sk.moment(moment, HOLDS[moment], [CHOOSING, CHOOSING])


## The type index Player `player`'s choice cursor points at.
func _cursor(player: int) -> int:
	return _tk.units.panels[player].choice_input.cursor


## After every tick the kit waits: keeps Player 2's throttle under P2_CRUISE while it drives on.
func _feather() -> void:
	if _driving:
		_h.drive(Harness.PLAYER_2, 1 if _tk.units.units[Harness.PLAYER_2].current_speed < P2_CRUISE else 0, 0)


## Prints the failing premise check when a step did not happen or a view showed anything else (the
## moments reached, the problems the moments and steps filed, an engine ERROR or WARNING), then
## the RESULT line.
func _finish() -> void:
	_tk.close()
	_h.phase = &"end"
	var logged: Array = [_tk.engine_log.errors, _tk.engine_log.warnings]
	var wanted: Array[StringName] = []
	wanted.assign(HOLDS.keys())
	_sk.need(_sk.moments == wanted, "the moments reached are %s, expected %s" % [_sk.moments, wanted])
	_sk.need(logged == [[], []], "the engine logged %s" % [logged])
	if not _sk.problems.is_empty():
		_h.check("premise", false, "the run did not reach its steps or a view showed something else: %d problems, the first %d: %s" % [
			_sk.problems.size(), mini(_sk.problems.size(), 6), " | ".join(_sk.problems.slice(0, 6))])
	_h.finish("moments=%d chosen=%d spawned=%d destroyed=%d round_over=%d round_started=%d errors=%d warnings=%d" % [
		_sk.moments.size(), _tk.units.chosen.size(), _tk.events_of(&"spawned").size(), _tk.events_of(&"destroyed").size(),
		_tk.events_of(&"over").size(), _tk.events_of(&"started").size(), logged[0].size(), logged[1].size()])
