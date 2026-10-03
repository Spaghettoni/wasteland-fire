extends RefCounted
## Scenario fuel_hint of the split screen evidence harness (split_screen_harness.gd): the out-of-Fuel
## Self-destruct hint, on the shipped data and Map with a Token stock of its own (Story 009 AC-5).
## A Round with real keys: both Players choose Motorbikes; Player 1's runs dry standing (a copy of
## its stats with a small tank), is refuelled by a little (Unit.refuel(), what a Fuel Can calls) and
## runs dry again; Player 2's Buggy runs dry the same way; Player 1 Self-destructs with Tab, chooses
## the Gyrocopter, which hovers dry and crashes, then chooses its last Motorbike and Self-destructs
## it, losing the Round while Player 2 is still stranded; R restarts. Four CHECK lines: hint_states
## (on every tick of the run each hint is shown exactly while its own Player's Unit is stranded and
## the Round runs, and was both shown and hidden for each Player), hint_moments (the readings at
## each step: shown on the tick the tank runs dry, hidden on the tick of the refuel, of the
## Self-destruct, of the Round's end and of the restart, never for the Gyrocopter or in the other
## Player's view), hint_text (each hint names its own Player's Self-destruct key, read from the
## Input Map: Tab and Enter) and hint_layout (inside the 640 x 720 view by 8 px, below the HUD band's
## Team edge, on one line inside its panel), plus no_engine_noise. A SPLIT line per step.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-5. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=fuel_hint

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 008 helpers (token_kit.gd): real-key choices, Self-destructs, the restart.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## The Token stock the runner builds for this scenario: two Motorbikes, so the second Self-destruct
## of Player 1's Motorbike loses the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 2, &"buggy": 3, &"truck": 2, &"gyrocopter": 2}
## The share of its tank a stranded run's copy of a type spawns with: dry within a second standing.
const SMALL_TANK: float = 0.005
## The share the Gyrocopter's copy spawns with: one Fuel unit, under a second of hovering.
const GYRO_TANK: float = 0.01
## Fuel units the refuel gives: dry again within a second standing.
const REFUEL: float = 0.25
## Ticks a wait for a Unit to run dry, to crash or to be in play may take.
const WAIT_TICKS: int = 300
## Least room between the hint and the edge of its view, pixels (token_layout.gd's margin).
const MARGIN_PX: float = 8.0

var _q: Quick
## Every tick's reading: {tick, visible: [p1, p2], stranded: [..], over}.
var _log: Array[Dictionary] = []
var _moments: PackedStringArray = []
var _moment_problems: PackedStringArray = []
var _gyro_shown: bool = false


## Plays the Round of the class doc, then the CHECK lines and the RESULT line. The runner awaits
## this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_q.kit.on_tick = _on_tick
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	_moment("start", [false, false])
	await _strand(Harness.PLAYER_1, Quick.MOTORBIKE)
	_moment("p1 dry", [true, false])
	var texts: Array[String] = [_q.hints[0].text, ""]
	var layout: String = _layout(Harness.PLAYER_1)
	_q.units.units[0].refuel(REFUEL)
	_moment("p1 refuelled", [false, false])
	await _wait(func() -> bool: return _q.units.units[0].is_stranded)
	_moment("p1 dry again", [true, false])
	await _strand(Harness.PLAYER_2, Quick.BUGGY)
	_moment("p2 dry", [true, true])
	texts[1] = _q.hints[1].text
	layout += " | " + _layout(Harness.PLAYER_2)
	await _q.tokens.destruct(Harness.PLAYER_1)
	_moment("p1 Self-destruct", [false, true])
	await _gyro_crash()
	_moment("p1 Gyrocopter crashed", [false, true])
	await _q.tokens.spawn(Harness.PLAYER_1, Quick.MOTORBIKE)
	await _q.tokens.destruct(Harness.PLAYER_1)
	_moment("p1 lost the Round", [false, false])
	await _q.tokens.restart()
	_moment("restart", [false, false])
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	_moment("both in play again", [false, false])
	_verdicts(texts, layout)
	_q.close()
	_q.harness.finish("ticks_read=%d over=%s %s" % [_log.size(), _q.controller.is_round_over(), _q.engine_counts()])


## The check kit's hook after every tick: both hints' visibility, both Units' stranded state and
## whether the Round is over; whether the hint ever showed while Player 1 flew the Gyrocopter.
func _on_tick() -> void:
	var units: Array[Unit] = _q.units.units
	_log.append({"tick": _q.harness.ticks, "visible": [_q.hints[0].visible, _q.hints[1].visible],
		"stranded": [units[0].is_stranded, units[1].is_stranded], "over": _q.controller.is_round_over()})
	if units[0].is_alive and units[0].stats.can_fly and _q.hints[0].visible:
		_gyro_shown = true


## Files a reading now: each hint's visibility against the expected one, with a SPLIT line.
func _moment(name: String, expected: Array[bool]) -> void:
	var seen: Array[bool] = [_q.hints[0].visible, _q.hints[1].visible]
	_q.kit.need(_moment_problems, seen == expected, "%s: hints shown %s, expected %s" % [name, seen, expected])
	_moments.append("%s: %s" % [name, seen])
	print("SPLIT %s t=%.3f moment=%s p1_hint=%s p2_hint=%s p1_stranded=%s p2_stranded=%s over=%s" % [
		_q.harness.scenario, _q.harness.time(), name.replace(" ", "_"), seen[0], seen[1],
		_q.units.units[0].is_stranded, _q.units.units[1].is_stranded, _q.controller.is_round_over()])


## A Player's Unit put down standing as a copy of the type with a small tank, then waited on until
## it is stranded. A coroutine.
func _strand(player: int, type_index: int) -> void:
	var spot: Vector3 = Quick.LANE_SPOT if player == 0 else Quick.mirrored(Quick.LANE_SPOT)
	await _q.put(player, _q.small_tank(type_index, SMALL_TANK), spot, Vector3.RIGHT if player == 0 else Vector3.LEFT)
	var unit: Unit = _q.units.units[player]
	await _wait(func() -> bool: return unit.is_stranded)


## Ticks until the condition holds, at most WAIT_TICKS. A coroutine.
func _wait(condition: Callable) -> void:
	for _tick: int in WAIT_TICKS:
		if condition.call():
			return
		await _q.kit.tick()


## Player 1 chooses the Gyrocopter with real keys, then flies a copy of it with a small tank that
## hovers dry and crashes. A coroutine.
func _gyro_crash() -> void:
	await _q.tokens.spawn(Harness.PLAYER_1, Quick.GYROCOPTER)
	await _q.put(Harness.PLAYER_1, _q.small_tank(Quick.GYROCOPTER, GYRO_TANK), Quick.LANE_SPOT, Vector3.RIGHT)
	var unit: Unit = _q.units.units[0]
	await _wait(func() -> bool: return not unit.is_alive)


## A Player's hint as shown: its rectangle inside the view by MARGIN_PX, below the HUD band's Team
## edge by MARGIN_PX, its text on one line inside the panel's content (the label less its style's
## margins); the problems go to the moments' list. The measured note.
func _layout(player: int) -> String:
	var hint: SelfDestructHint = _q.hints[player]
	var rect: Rect2 = hint.get_global_rect()
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2((_q.units.cameras[player].get_viewport() as SubViewport).size))
	var hud: PlayerHud = _q.units.huds[player]
	var band: float = 0.0
	for child: Node in hud.get_children():
		if child is Control:
			band = maxf(band, (child as Control).get_global_rect().end.y)
	band += hud.edge_style.get_margin(SIDE_BOTTOM) if hud.edge_style != null else 0.0
	var style: StyleBox = hint.get_theme_stylebox(&"normal")
	var room: float = rect.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	var font: Font = hint.get_theme_font(&"font")
	var width: float = font.get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, hint.get_theme_font_size(&"font_size")).x + float(hint.get_theme_constant(&"outline_size"))
	var tag: String = "p%d hint" % (player + 1)
	_q.kit.need(_moment_problems, hint.get_viewport() == _q.units.cameras[player].get_viewport(), "%s is not in its own Player's view" % tag)
	_q.kit.need(_moment_problems, view.grow(-MARGIN_PX).encloses(rect) and rect.position.y >= band + MARGIN_PX,
		"%s (%.0f,%.0f %.0fx%.0f) leaves the view by %.0f px or comes within it of the band's edge at %.0f" % [tag, rect.position.x, rect.position.y, rect.size.x, rect.size.y, MARGIN_PX, band])
	_q.kit.need(_moment_problems, hint.get_line_count() == 1 and width <= room, "%s '%s' is %.0f px on %d lines in %.0f px" % [tag, hint.text, width, hint.get_line_count(), room])
	return "%s (%.0f,%.0f %.0fx%.0f) in a %.0fx%.0f view, %.0f px below the band's edge at %.0f, text %.0f of %.0f px on %d line" % [
		tag, rect.position.x, rect.position.y, rect.size.x, rect.size.y, view.size.x, view.size.y, rect.position.y - band, band, width, room, hint.get_line_count()]


## The CHECK lines, from the per-tick log, the moments, the texts and the layout notes.
func _verdicts(texts: Array[String], layout: String) -> void:
	var problems: PackedStringArray = []
	var shown: Array[int] = [0, 0]
	var hidden: Array[int] = [0, 0]
	for reading: Dictionary in _log:
		for player: int in Kit.PLAYERS:
			var expected: bool = bool(reading["stranded"][player]) and not bool(reading["over"])
			var visible: bool = bool(reading["visible"][player])
			if visible != expected:
				problems.append("tick %d: p%d hint shown=%s, stranded=%s over=%s" % [reading["tick"], player + 1, visible, reading["stranded"][player], reading["over"]])
			shown[player] += 1 if visible else 0
			hidden[player] += 0 if visible else 1
	for player: int in Kit.PLAYERS:
		_q.kit.need(problems, shown[player] > 0 and hidden[player] > 0, "p%d's hint was shown on %d and hidden on %d ticks" % [player + 1, shown[player], hidden[player]])
	_q.kit.verdict("hint_states", problems.slice(0, 8), "%d ticks read: p1 shown %d hidden %d, p2 shown %d hidden %d, every tick shown exactly while stranded and the Round runs" % [
		_log.size(), shown[0], hidden[0], shown[1], hidden[1]])
	_q.kit.need(_moment_problems, not _gyro_shown, "the hint showed while Player 1 flew the Gyrocopter")
	_q.kit.verdict("hint_moments", _moment_problems, " | ".join(_moments) + " | Gyrocopter hint shown: %s | %s" % [_gyro_shown, layout])
	var text_problems: PackedStringArray = []
	var keys: Array[String] = []
	for player: int in Kit.PLAYERS:
		var key: String = OS.get_keycode_string(Tokens.keys(&"destruct", player)[0])
		keys.append(key)
		var expected: String = _q.hints[player].tr(_q.hints[player].format) % key
		_q.kit.need(text_problems, texts[player] == expected, "p%d's hint read '%s', not '%s'" % [player + 1, texts[player], expected])
	_q.kit.verdict("hint_text", text_problems, "p1 '%s' | p2 '%s' (keys %s from the Input Map's physical keys)" % [texts[0], texts[1], ", ".join(keys)])
	var noise: PackedStringArray = []
	_q.kit.need(noise, _q.tokens.engine_log.errors.is_empty() and _q.tokens.engine_log.warnings.is_empty(), "the engine logged %s" % [_q.tokens.engine_log.errors + _q.tokens.engine_log.warnings])
	_q.kit.verdict("no_engine_noise", noise, _q.engine_counts())
