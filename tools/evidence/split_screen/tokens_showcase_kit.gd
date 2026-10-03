extends RefCounted
## What the tokens_showcase scenario shares beyond token_kit.gd, token_ui_kit.gd and check_kit.gd:
## the Tokens each Player must have by the scenario's own count (the stock less every destruction
## the scenario made), the reading of both views as a viewer sees them (the HUD line, the choice
## panel, the countdown, the Round-over screen), the judgement of that reading against the count
## and the Round (the premise of a moment), and the SPLIT line a moment or an event prints with
## the number of the PNG that shows it. Make one with ShowKit.new(harness, kit) and call tk.close()
## before finish(). Tooling only: nothing under src/ depends on this file.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 008 screen readers (token_ui_kit.gd): the screens' own lines, the HUD label.
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")
## The Story 008 model of a choice panel (token_choice_kit.gd): which slot is dim or marked.
const ChoiceKit: GDScript = preload("res://tools/evidence/split_screen/token_choice_kit.gd")

## What a moment passes as the winner while the Round runs: no round_over has come.
const NOT_OVER: int = -2
## Main-loop iterations from a moment's line back to the PNG that shows it: the line is printed on
## the first tick after the hold, before that tick's physics step, so the picture it describes is
## the one the iteration before drew. Measured on the countdown digit at its flip, with two holds
## one tick apart: the line with frame=191 reads "Respawn in 3" and the one with frame=192
## "Respawn in 2", and PNG 191 is the last that shows the 3, PNG 192 the first that shows the 2.
const MOMENT_FRAME_LAG: int = 1
## The fields of a view that a moment's line prints, in order (read()).
const SHOWN: Array[String] = ["unit", "panel", "counts", "looks", "cursor", "hud", "countdown", "screen"]

## The Story 008 kit: readings, the signal record, the engine log.
var tk: Tokens
## The Story 008 screen readers.
var ui: UiKit
## The index into unit_types() of the one type that can carry the Flag, read from the data.
var carrier: int = -1
## The rows the Map's stock gives both Players, read from its resource: [[Player 1], [Player 2]].
var start: Array = []
## The Tokens each Player must have now by the scenario's own count: the stock less every
## destruction the scenario made, the stock again after a restart.
var rows: Array = []
## What did not happen as the scenario expects, each tagged with the phase it came in.
var problems: PackedStringArray = []
## The moments reached, in order.
var moments: Array[StringName] = []
var _h: Harness
var _kit: Kit


## Makes the Story 008 and UI kits, reads the stock and prints a line at every choice, spawn,
## destruction, pick-up and Round signal.
func _init(harness_node: Node, check_kit: Kit) -> void:
	_h = harness_node as Harness
	_kit = check_kit
	tk = Tokens.new(_h, _kit)
	ui = UiKit.new(tk)
	carrier = tk.carrier_index()
	start = tk.rows_of(_h.split.field.token_stock)
	rows = start.duplicate(true)
	var game: MatchController = tk.controller
	game.unit_chosen.connect(func(player: int, type_index: int) -> void:
		line("event=p%d_chose_%s" % [player + 1, game.unit_types()[type_index].type_id]))
	game.unit_spawned.connect(func(player: int) -> void:
		line("event=p%d_spawned_as_%s" % [player + 1, tk.units.units[player].type_id]))
	game.unit_destroyed.connect(func(player: int) -> void: line("event=p%d_destroyed" % (player + 1)))
	game.flag_picked_up.connect(func(taker: int, flag_index: int) -> void:
		line("event=p%d_takes_flag_of_p%d" % [taker + 1, flag_index + 1]))
	game.round_started.connect(func() -> void: line("event=round_started"))
	game.round_over.connect(func(winner: int) -> void:
		line("event=round_over_" + ("nobody_wins" if winner == MatchController.NO_WINNER else "p%d_wins" % (winner + 1))))


## Adds a problem, tagged with the running phase, unless the condition holds; returns the condition.
func need(holds: bool, problem: String) -> bool:
	_kit.need(problems, holds, "%s: %s" % [_h.phase, problem])
	return holds


## Prints one SPLIT line: time, the PNG number (main-loop iterations so far less `lag`), phase,
## the label (moment= or event=), the Round state, then `extra`. In a --write-movie run the
## iterations so far are the number of the next PNG.
func line(label: String, lag: int = 0, extra: String = "") -> void:
	print("SPLIT %s t=%.3f frame=%d phase=%s %s round=%s%s" % [_h.scenario, _h.time(),
		Engine.get_process_frames() - lag, _h.phase, label,
		"OVER" if tk.controller.is_round_over() else "RUNNING", extra])


## Holds the keys as they are for `hold` seconds under the moment's name, then reads both views,
## judges them (judge()), files the problems and the moment, and prints the line with what each
## view shows. `panels` is the state each Player's choice panel must be in (&"hidden",
## &"choosing" or &"ready"); `winner` the Player the Round-over screens must name, NO_WINNER for
## "Nobody wins!", or NOT_OVER while the Round runs.
func moment(name: StringName, hold: float, panels: Array[StringName], winner: int = NOT_OVER) -> void:
	_h.phase = name
	await _kit.advance(_h.ticks_in(hold))
	var seen: Array[Dictionary] = [read(Harness.PLAYER_1), read(Harness.PLAYER_2)]
	problems.append_array(judge(name, panels, winner, seen))
	moments.append(name)
	line("moment=%s" % name, MOMENT_FRAME_LAG, " " + describe(seen))


## What a Player's view shows now: the Unit's type, the choice panel (state, title, count lines,
## slot styles, text colours, marked slots, cursor), the HUD line and whether it is shown, the
## countdown (shown, text) and the lines of the Round-over screen.
func read(player: int) -> Dictionary:
	var panel: UnitChoice = tk.units.panels[player]
	var unit: Unit = tk.units.units[player]
	var countdown: RespawnCountdown = tk.units.countdowns[player]
	var state: StringName = &"hidden"
	if panel.visible:
		state = &"choosing" if tk.controller.is_choosing(player) else &"ready"
	var title: Label = panel.find_child("TitleLabel", true, false) as Label
	return {"unit": unit.type_id if unit.is_alive else &"none", "panel": state, "title": title.text, "counts": tk.panel_counts(player),
		"looks": tk.looks(player), "fonts": tk.fonts(player), "marked": tk.looks(player).count("cursor"),
		"cursor": panel.choice_input.cursor, "hud": tk.hud_line(player), "hud_shown": ui.tokens_label(player).is_visible_in_tree(),
		"counting": countdown.visible, "countdown": countdown.text if countdown.visible else "", "screen": tk.over_lines(player)}


## What read() must give for a Player: the HUD line for the scenario's count of the carrier type;
## the panel in the state `panel` and, when it is shown, its count lines, slot styles (the model: a
## type with no Token is dim, the slot under the cursor is marked only while its type has Tokens)
## and text colours for the count, and exactly while choosing one marked slot and the choosing
## title; the countdown while the Round runs and the delay does; the Round-over screen's own lines
## for `winner`, or none. What a hidden panel keeps inside it is not judged: those keys keep what
## it shows.
func expect(player: int, panel: StringName, winner: int, got: Dictionary) -> Dictionary:
	var row: Array = rows[player]
	var choosing: bool = panel == &"choosing"
	var wanted: Dictionary = got.duplicate()
	wanted["hud"] = tk.hud_text(player, row[carrier])
	wanted["hud_shown"] = true
	wanted["panel"] = panel
	wanted["screen"] = PackedStringArray() if winner == NOT_OVER else ui.expected_lines(player, winner)
	wanted["counting"] = winner == NOT_OVER and tk.controller.seconds_until_respawn(player) > 0.0
	if panel != &"hidden":
		wanted["counts"] = tk.count_texts(player, row)
		wanted["looks"] = ChoiceKit.model_looks(row, got["cursor"], choosing)
		wanted["fonts"] = ChoiceKit.model_fonts(row)
		wanted["marked"] = int(choosing)
		wanted["title"] = tk.units.panels[player].tr(tk.units.panels[player].title_text) if choosing else got["title"]
	return wanted


## Judges the readings of both views against the scenario's count and the Round: the controller's
## Tokens are `rows`; the Round is over, with the tree paused and `winner` named, exactly when
## `winner` says so; one round_over for every Round that ended and none for one that runs; and each
## Player's view is expect(). Returns the problems, each tagged with the moment.
func judge(moment_name: StringName, panels: Array[StringName], winner: int, seen: Array[Dictionary]) -> PackedStringArray:
	var state: Dictionary = tk.state()
	var over: bool = winner != NOT_OVER
	var wanted_overs: int = tk.events_of(&"started").size() + int(over)
	var found: PackedStringArray = []
	_kit.need(found, state["counts"] == rows, "Tokens %s, expected %s" % [state["counts"], rows])
	_kit.need(found, state["over"] == over and state["paused"] == over and (not over or state["winner"] == winner),
		"over %s, paused %s, winner %d, expected over %s with winner %d" % [state["over"], state["paused"], state["winner"], over, winner])
	_kit.need(found, tk.events_of(&"over").size() == wanted_overs, "%d round_over, expected %d" % [tk.events_of(&"over").size(), wanted_overs])
	for player: int in Kit.PLAYERS:
		var wanted: Dictionary = expect(player, panels[player], winner, seen[player])
		for key: String in wanted:
			_kit.need(found, seen[player][key] == wanted[key], "player %d's %s is %s, expected %s" % [player + 1, key, seen[player][key], wanted[key]])
	var tagged: PackedStringArray = []
	for problem: String in found:
		tagged.append("%s: %s" % [moment_name, problem])
	return tagged


## Waits for the round_over after the events index `mark` and judges the loss of AC-4: it came
## once, in the physics frame of every destruction since `mark` (the Round ends on the tick of the
## destruction, not later). True when it did.
func ended_by_loss(mark: int) -> bool:
	var came: bool = await tk.wait_for(&"over", mark)
	var over: Array[Dictionary] = tk.events_of(&"over", mark)
	var down: Array[Dictionary] = tk.events_of(&"destroyed", mark)
	var frame: int = over[0]["now"]["frame"] if over.size() == 1 else -1
	var frames: Array = down.map(func(event: Dictionary) -> int: return event["now"]["frame"])
	return need(came and over.size() == 1 and not down.is_empty() and frames.all(func(at: int) -> bool: return at == frame),
		"round_over came %d times, in frame %d; destructions in frames %s" % [over.size(), frame, frames])


## The fields SHOWN of both views as p1_key=value p2_key=value: texts quoted (the Round-over
## screen's two lines in one text), lists joined by commas.
func describe(seen: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		for key: String in SHOWN:
			var value: Variant = seen[player][key]
			var text: String = str(value)
			if value is PackedStringArray:
				text = "\"%s\"" % " / ".join(value) if key == "screen" else ",".join(value)
			elif value is String:
				text = "\"%s\"" % value
			parts.append("p%d_%s=%s" % [player + 1, key, text])
	return " ".join(parts)
