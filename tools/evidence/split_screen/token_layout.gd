extends RefCounted
## Scenario token_layout of the split screen evidence harness (split_screen_harness.gd): the worst
## case of Story 008's screens (AC-3, AC-6, AC-7) on Map 01 with a Token stock of its own, three
## digits on the HUD and the choice panel (Motorbike 100, Buggy 99, Truck 100, Gyrocopter 99, built
## by the runner from STOCK_COUNTS). One CHECK, T27_layout_worst_case, with every measured
## rectangle: both Players' HUDs at the start and with a Unit in play (every child inside the view
## by 8 px and shown, the Tokens label on one line with its text inside it and its rectangle clear
## of the status label and the bars, the children's union still (16,16) to (624,76), the lowest
## edge at most 90 px); the Tokens label written with every type's name and counts of 0, 9, 10, 99
## and 100, its own text put back (a capacity probe: the game shows only the carrier's name); both
## Players' choice panels at the start, choosing with the respawn countdown and ready with it, the
## longest display name of the data chosen (inside 560 px and the view, clear of the HUD band and
## the countdown, every name and count on one line); both Round-over panels with nobody_text,
## shown by emitting round_over(-1) by hand, because a double loss at this stock takes a hundred
## destructions each. Real key events. Helpers: token_ui_kit.gd, token_kit.gd, check_kit.gd.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-3, AC-6, AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=token_layout
##
## Kills (T27): a status label widened back over the Tokens label (their rectangles meet); a
## Tokens label or line too wide for its place at three digits (the text wraps or leaves the label,
## or the label leaves the band or the view); a HUD child pushed below 90 px or out of the view; a
## choice panel that grows past 560 px, out of the view, into the HUD band or the countdown, or
## whose names and counts wrap at 99 and 100; a Round-over panel for nobody_text that wraps or
## leaves the view; an engine ERROR or WARNING while any of it is read.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, real-key choices, the engine log counter.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The readers of the Story 008 UI scenarios (token_ui_kit.gd).
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## The Token stock the runner builds for this scenario, type_id to count: the worst case for the
## width of a count on every screen.
const STOCK_COUNTS: Dictionary = {&"motorbike": 100, &"buggy": 99, &"truck": 100, &"gyrocopter": 99}
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## The counts the capacity probe writes into the Tokens label with every type's name: one, two and
## three digits at their boundaries and the stock's own.
const PROBE_COUNTS: Array[int] = [0, 9, 10, 99, 100]
## Least room between an element and the edge of its view, pixels (design 13.6).
const MARGIN_PX: float = 8.0
## What the union of a HUD's children must still be with the Tokens label in it: (16, 16) to
## (624, 76) (design 13.6), so the Team edge stays at (8, 8) to (632, 84).
const BAND: Rect2 = Rect2(16.0, 16.0, 608.0, 60.0)
## The lowest edge a HUD child may have, pixels (player_hud.gd: nothing lower than about 90 px).
const LOWEST_Y_MAX: float = 90.0
## The widest the choice panel may be, pixels (unit_choice.gd: 560 px, 40 px of margin each side).
const PANEL_WIDTH_MAX: float = 560.0
## The widest the Round-over panel may be, pixels (round_over_screen.gd: 520 px).
const OVER_WIDTH_MAX: float = 520.0
## The check as printed.
const CHECK_NAME: String = "T27_layout_worst_case"

var _h: Harness
var _kit: Kit
var _tk: Tokens
var _ui: UiKit
var _problems: PackedStringArray = []
var _notes: PackedStringArray = []


## Runs the scenario in the order of the notes. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_ui = UiKit.new(_tk)
	await _kit.advance(Kit.START_TICKS)
	var stock: TokenStock = _h.split.field.token_stock
	var rows: Array = _tk.rows_of(stock)
	var fixture: bool = true
	for type_id: StringName in STOCK_COUNTS:
		fixture = fixture and stock.count_of(type_id) == int(STOCK_COUNTS[type_id])
	_need(fixture and _tk.shows(_tk.state(), rows) and str(rows[0].max()).length() == 3, "the fixture %s did not reach the game: the stock holds %s, the Tokens are %s" % [STOCK_COUNTS, stock.counts, _tk.counts()])
	_notes.append("Tokens %s on screen: panels %s, HUD lines '%s' '%s'" % [rows[0], _tk.panel_counts(0), _tk.hud_line(0), _tk.hud_line(1)])
	_measure_huds("start")
	_measure_panels("start, choosing")
	_capacity()
	var longest: int = _longest_type()
	for player: int in Kit.PLAYERS:
		_need(await _tk.spawn(player, longest), "player %d's %s did not appear" % [player + 1, _tk.controller.unit_types()[longest].type_id])
	await _kit.advance(Harness.SETTLE_TICKS)
	_measure_huds("in play")
	await _countdown_states(longest)
	await _nobody_wins()
	_report()


## The index of the type whose display name is the widest in the choice panel's name font.
func _longest_type() -> int:
	var label: Label = _tk.units.panels[0].find_child("NameLabel", true, false) as Label
	var types: Array[UnitStats] = _tk.controller.unit_types()
	var longest: int = 0
	for type_index: int in types.size():
		if UiKit.text_width(label, label.tr(types[type_index].display_name)) > UiKit.text_width(label, label.tr(types[longest].display_name)):
			longest = type_index
	_notes.append("longest display name: '%s' (index %d) of %d types" % [types[longest].display_name, longest, types.size()])
	return longest


## Reads both Players' HUDs against the limits.
func _measure_huds(moment: String) -> void:
	for player: int in Kit.PLAYERS:
		_notes.append("%s: %s" % [moment, _hud_geometry(player)])


## Reads both Players' choice panels against the limits.
func _measure_panels(moment: String) -> void:
	for player: int in Kit.PLAYERS:
		_notes.append("%s: %s" % [moment, _panel_geometry(player)])


## A Player's HUD: every child inside the view by MARGIN_PX and shown, each Label's text on one
## line and inside itself, the Tokens label's rectangle clear of every other child's, the union of
## the children BAND, its lowest edge at most LOWEST_Y_MAX. The measured rectangles.
func _hud_geometry(player: int) -> String:
	var hud: PlayerHud = _tk.units.huds[player]
	var inner: Rect2 = _ui.view_of(player).grow(-MARGIN_PX)
	var rects: Dictionary[String, Rect2] = {}
	var union: Rect2 = Rect2()
	for child: Node in hud.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		var rect: Rect2 = control.get_global_rect()
		union = rect if rects.is_empty() else union.merge(rect)
		rects[String(control.name)] = rect
		_need(inner.encloses(rect) and control.is_visible_in_tree(), "p%d HUD %s %s is outside the view by %.0f px, or hidden" % [player + 1, control.name, UiKit.rs(rect), MARGIN_PX])
		if control is Label:
			_ui.fits(control as Label, (control as Label).text, "p%d HUD %s" % [player + 1, control.name], _problems)
	var tokens: Rect2 = rects.get("TokensLabel", Rect2())
	for other: String in rects:
		_need(other == "TokensLabel" or not tokens.intersects(rects[other]), "p%d HUD Tokens label %s overlaps %s %s" % [player + 1, UiKit.rs(tokens), other, UiKit.rs(rects[other])])
	_need(union.is_equal_approx(BAND) and union.end.y <= LOWEST_Y_MAX, "p%d HUD children span %s, not %s (lowest edge at most %.0f)" % [player + 1, UiKit.rs(union), UiKit.rs(BAND), LOWEST_Y_MAX])
	return "p%d HUD union=%s status=%s tokens=%s '%s'" % [player + 1, UiKit.rs(union), UiKit.rs(rects.get("FlagStatusLabel", Rect2())), UiKit.rs(tokens), _ui.tokens_label(player).text]


## A Player's choice panel while it is shown: inside the view by MARGIN_PX and at most
## PANEL_WIDTH_MAX wide, below the HUD band and clear of the respawn countdown's text (its widest,
## the full delay), every slot inside the panel and the same size, the name and the count of every
## slot on one line inside their label. The measured rectangle and the widest slot label.
func _panel_geometry(player: int) -> String:
	var choice: UnitChoice = _tk.units.panels[player]
	var panel: PanelContainer = choice.find_child("Panel", true, false) as PanelContainer
	var rect: Rect2 = panel.get_global_rect()
	var tag: String = "p%d panel" % (player + 1)
	_need(choice.visible and panel.is_visible_in_tree(), tag + " is hidden")
	_need(_ui.view_of(player).grow(-MARGIN_PX).encloses(rect) and rect.size.x <= PANEL_WIDTH_MAX, "%s %s leaves the view by %.0f px or is wider than %.0f" % [tag, UiKit.rs(rect), MARGIN_PX, PANEL_WIDTH_MAX])
	var band_bottom: float = BAND.end.y + _tk.units.huds[player].edge_style.get_margin(SIDE_BOTTOM)
	var countdown: RespawnCountdown = _tk.units.countdowns[player]
	var size: Vector2 = countdown.get_theme_font(&"font").get_string_size(countdown.tr(countdown.format) % ceili(_tk.controller.rules.respawn_delay_seconds),
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, countdown.get_theme_font_size(&"font_size"))
	var text_rect: Rect2 = Rect2(countdown.get_global_rect().get_center() - size / 2.0, size)
	_need(rect.position.y >= band_bottom + MARGIN_PX and not rect.intersects(text_rect.grow(MARGIN_PX)), "%s %s is within %.0f px of the HUD band (bottom %.0f) or the countdown text %s" % [tag, UiKit.rs(rect), MARGIN_PX, band_bottom, UiKit.rs(text_rect)])
	var widest: float = 0.0
	for slot: PanelContainer in _tk.slots(player):
		_need(rect.encloses(slot.get_global_rect()) and slot.size.is_equal_approx(_tk.slots(player)[0].size), "%s slot %s is outside the panel or not the size of the first" % [tag, UiKit.rs(slot.get_global_rect())])
		for path: NodePath in [^"Lines/NameLabel", ^"Lines/CountLabel"]:
			var label: Label = slot.get_node(path) as Label
			widest = maxf(widest, _ui.fits(label, label.text, tag + " slot", _problems))
	return "%s=%s, %.0f px below the band, widest slot label %.0f px" % [tag, UiKit.rs(rect), rect.position.y - band_bottom, widest]


## A Player's Round-over screen while it is shown: its panel inside the view by MARGIN_PX and at
## most OVER_WIDTH_MAX wide, both lines on one line inside their label. The measured rectangle.
func _over_geometry(player: int) -> String:
	var screen: RoundOverScreen = _ui.over_screen(player)
	var panel: PanelContainer = screen.find_child("Panel", true, false) as PanelContainer
	var rect: Rect2 = panel.get_global_rect()
	var tag: String = "p%d Round-over panel" % (player + 1)
	_need(screen.visible and panel.is_visible_in_tree(), tag + " is hidden")
	_need(_ui.view_of(player).grow(-MARGIN_PX).encloses(rect) and rect.size.x <= OVER_WIDTH_MAX, "%s %s leaves the view by %.0f px or is wider than %.0f" % [tag, UiKit.rs(rect), MARGIN_PX, OVER_WIDTH_MAX])
	var widths: PackedStringArray = []
	for label_name: String in ["WinnerLabel", "RestartLabel"]:
		var label: Label = screen.find_child(label_name, true, false) as Label
		widths.append("%.0f" % _ui.fits(label, label.text, tag + " " + label_name, _problems))
	return "%s=%s lines %s px" % [tag, UiKit.rs(rect), " / ".join(widths)]


## The capacity probe: the Tokens label of both Players written with every type's name and each of
## PROBE_COUNTS, judged each time (one line, inside the label), its own text put back.
func _capacity() -> void:
	var widest: float = 0.0
	var widest_line: String = ""
	for player: int in Kit.PLAYERS:
		var hud: PlayerHud = _tk.units.huds[player]
		for stats: UnitStats in _tk.controller.unit_types():
			for count: int in PROBE_COUNTS:
				var text: String = hud.tr(hud.tokens_format) % [hud.tr(stats.display_name), count]
				var width: float = _ui.fits(_ui.tokens_label(player), text, "p%d Tokens label" % (player + 1), _problems)
				if width > widest:
					widest = width
					widest_line = text
	_notes.append("capacity: %d texts per Player, the widest '%s' %.0f px in a label %.0f px wide" % [
		_tk.controller.unit_types().size() * PROBE_COUNTS.size(), widest_line, widest, _ui.tokens_label(0).size.x])


## Both Units are destroyed together (Tab and Enter): both panels choosing with the countdown shown;
## both Players choose the longest name again: both panels ready, the countdown still running.
func _countdown_states(longest: int) -> void:
	await _kit.press_settled(Kit.KEYS_DESTRUCT_BOTH)
	await _kit.advance(Harness.SETTLE_TICKS)
	_countdown_state("choosing", longest)
	for player: int in Kit.PLAYERS:
		_need(await _tk.choose(player, longest), "player %d's choice of the longest name was refused" % (player + 1))
	await _kit.advance(Harness.SETTLE_TICKS)
	_countdown_state("ready", longest)
	_measure_huds("countdown")


## Adds a problem unless both countdowns and panels are shown, the panels' titles are those of the
## state and their counts the controller's; then reads both panels.
func _countdown_state(state: String, longest: int) -> void:
	for player: int in Kit.PLAYERS:
		var panel: UnitChoice = _tk.units.panels[player]
		var title: String = (panel.find_child("TitleLabel", true, false) as Label).text
		var expected: String = panel.tr(panel.title_text)
		if state == "ready":
			expected = panel.tr(panel.ready_format) % panel.tr(_tk.controller.unit_types()[longest].display_name)
		_need(_tk.units.countdowns[player].visible and panel.visible and title == expected and _tk.panel_counts(player) == _tk.count_texts(player, _tk.counts()[player]),
				"player %d, %s: countdown shown=%s, title '%s' (expected '%s'), counts %s of %s" % [player + 1, state, _tk.units.countdowns[player].visible, title, expected, _tk.panel_counts(player), _tk.counts()[player]])
	_measure_panels("countdown, " + state)


## The Round-over screens with nobody_text, shown by round_over(-1) emitted by hand.
func _nobody_wins() -> void:
	_tk.controller.round_over.emit(MatchController.NO_WINNER)
	await _kit.advance(Harness.SETTLE_TICKS)
	for player: int in Kit.PLAYERS:
		var lines: PackedStringArray = _tk.over_lines(player)
		_need(lines == _ui.expected_lines(player, MatchController.NO_WINNER), "player %d's Round-over screen reads %s, not the nobody line" % [player + 1, lines])
		_notes.append("round_over(-1) by hand: " + _over_geometry(player))


## Adds a problem unless the condition holds.
func _need(holds: bool, problem: String) -> void:
	_kit.need(_problems, holds, problem)


## Prints the verdict and the RESULT line.
func _report() -> void:
	_tk.close()
	_need(_tk.engine_log.errors.is_empty() and _tk.engine_log.warnings.is_empty(), "the engine logged errors %s and warnings %s" % [_tk.engine_log.errors, _tk.engine_log.warnings])
	_kit.verdict(CHECK_NAME, _problems, " | ".join(_notes))
	_h.finish("tokens=%s errors=%d warnings=%d" % ["/".join(_tk.counts()[0].map(func(count: int) -> String: return str(count))), _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])
