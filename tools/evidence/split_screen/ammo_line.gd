extends RefCounted
## The Ammo line of the Story 022 scenario ammo: AC-4. While a Player's Unit is in play that Player's view, and only that one,
## shows its Shots left as "Ammo n / n", updated on the tick of every Shot (the text read inside the Weapon's own report); the
## line is hidden while the Player chooses or waits to respawn and shown again when the new Unit appears; under the Round-over
## screen it keeps the count the Round ended with; and in the 640 x 720 view it sits at x 16 to 316 and y 92 to 120, inside the
## view, below the HUD band, on the Mines line's row and clear of it, of the notice line, the out-of-Fuel hint, the choice panel
## and the respawn countdown, with its widest text on one line. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-4.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## Shots whose line is read, and Shots a Motorbike spends before the Round ends.
const SHOTS: int = 6
const SPENT: int = 7
## The least gap in pixels the line keeps to every other element.
const MARGIN_PX: float = 8.0
## The place the story gives the line (x, y, width, height), the test input of the layout check.
const LINE_RECT: Rect2 = Rect2(16.0, 92.0, 300.0, 28.0)
## The widest text the line shows, and the two lines of a Truck's row.
const WIDEST: String = "Ammo 100 / 100"
const TRUCK_AMMO: String = "Ammo 25 / 25"
const TRUCK_MINES: String = "Mines 5 / 5"
## Where a stranded Truck stands in front of its own Gate (a lay is refused there) and where the other Player waits.
const GATE_TRUCK: Vector3 = Vector3(-98.0, 0.0, 0.0)
const OTHER_SPOT: Vector3 = Vector3(-30.0, 0.0, 12.0)

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick
var _ui: UiKit


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()
	_ui = UiKit.new(kit.q().tokens)


func run() -> void:
	await _follows_every_shot()
	await _hidden_while_choosing_and_waiting()
	await _layout()
	await _under_the_round_over_screen()


## A new Buggy fires six Shots: the line reads one less after each, in the physics frame of the Shot, in its own view only.
func _follows_every_shot() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.BUGGY)
	var full: int = _k.weapon(0).capacity
	var mark: int = _k.changes[0].size()
	var other_mark: int = _k.changes[1].size()
	var other_line: String = _k.line(1)
	var fired: Array[Dictionary] = await _k.fire_n(0, SHOTS)
	_q.kit.need(problems, fired.size() == SHOTS and _k.changes[0].size() == mark + SHOTS, "%d Shots made %d reports" % [fired.size(), _k.changes[0].size() - mark])
	for index: int in mini(fired.size(), _k.changes[0].size() - mark):
		var report: Dictionary = _k.changes[0][mark + index]
		_q.kit.need(problems, int(report["frame"]) == int(fired[index]["frame"]) and int(report["left"]) == full - index - 1, "Shot %d (frame %d) was reported in frame %d with %d left" % [index + 1, fired[index]["frame"], report["frame"], report["left"]])
		_q.kit.need(problems, report["text"] == "Ammo %d / %d" % [full - index - 1, full], "after Shot %d the line read '%s'" % [index + 1, report["text"]])
	_q.kit.need(problems, _k.line(0) == "Ammo %d / %d" % [full - SHOTS, full], "the line reads '%s' after %d Shots" % [_k.line(0), SHOTS])
	_q.kit.need(problems, _k.line(1) == other_line and _k.changes[1].size() == other_mark, "the other Player's line changed: '%s' -> '%s', %d reports" % [other_line, _k.line(1), _k.changes[1].size() - other_mark])
	_q.kit.verdict("line_follows_every_shot", problems, "a new Buggy's line read 'Ammo 50 / 50', then one less in the physics frame of each of its first %d Shots (the text read inside the Weapon's own report), 'Ammo %d / 50' after them, and the other Player's line ('%s') did not move" % [SHOTS, full - SHOTS, other_line])


## The line is hidden while the Player chooses and while it waits to respawn, and shown with the full load when the Unit appears.
func _hidden_while_choosing_and_waiting() -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, _k.line(0).begins_with("Ammo "), "the line is not shown before the Self-destruct: '%s'" % _k.line(0))
	await _q.tokens.destruct(0)
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, _q.units.panels[0].visible and _k.line(0) == "hidden", "while the Player chooses the panel is shown %s and the line reads '%s'" % [_q.units.panels[0].visible, _k.line(0)])
	_q.kit.need(problems, await _q.tokens.choose(0, Quick.MOTORBIKE), "the choice was not accepted")
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, _q.units.countdowns[0].visible and _k.line(0) == "hidden", "while the Player waits to respawn the countdown is shown %s and the line reads '%s'" % [_q.units.countdowns[0].visible, _k.line(0)])
	_q.kit.need(problems, await _q.units.wait_alive(0, _q.harness.ticks_in(_q.controller.rules.respawn_delay_seconds) + Kit22.Kit.RESPAWN_SLACK_TICKS) >= 0, "no Motorbike came")
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, _k.line(0) == "Ammo 100 / 100", "with the new Motorbike in play the line reads '%s'" % _k.line(0))
	_q.kit.verdict("line_hidden_while_choosing_and_waiting", problems, "after a Self-destruct the line was hidden while the choice panel showed and while the respawn countdown ran, and read 'Ammo 100 / 100' once the new Motorbike was in play")


## A stranded Truck in front of its own Gate shows both lines, the refusal's notice and the out-of-Fuel hint at once: the Ammo line
## sits where the story puts it, clear of all of them, with its widest text on one line; the choice panel and the countdown that
## come after its destruction are clear of its place too.
func _layout() -> void:
	var problems: PackedStringArray = []
	await _k.mines().revive(1)
	await _k.mines().put(1, Quick.MOTORBIKE, OTHER_SPOT, Vector3.RIGHT)
	await _k.mines().revive(0)
	await _k.mines().put_stranded(0, GATE_TRUCK, Vector3.LEFT)
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	await _q.kit.advance(Kit22.SETTLE)
	var label: AmmoCount = _k.count_label(0)
	var mines_label: MineCount = _k.mines().count_label(0)
	var notice: PlayerNotice = _k.mines().notice(0)
	var hint: SelfDestructHint = _q.hints[0]
	var hud: PlayerHud = _q.units.huds[0]
	var view: Rect2 = _ui.view_of(0)
	var rect: Rect2 = label.get_global_rect()
	var mines_rect: Rect2 = mines_label.get_global_rect()
	var band: float = 0.0
	for child: Node in hud.get_children():
		if child is Control:
			band = maxf(band, (child as Control).get_global_rect().end.y)
	band += hud.edge_style.get_margin(SIDE_BOTTOM) if hud.edge_style != null else 0.0
	_q.kit.need(problems, label.visible and mines_label.visible and notice.visible and hint.visible and label.text == TRUCK_AMMO and mines_label.text == TRUCK_MINES, "the lines '%s' and '%s', the notice (%s) and the hint (%s) were not all shown" % [label.text, mines_label.text, notice.visible, hint.visible])
	_q.kit.need(problems, rect == LINE_RECT, "the line lies at %s, not at %s" % [UiKit.rs(rect), UiKit.rs(LINE_RECT)])
	_q.kit.need(problems, view.grow(-MARGIN_PX).encloses(rect), "the line %s leaves the view %s by less than %.0f px" % [UiKit.rs(rect), UiKit.rs(view), MARGIN_PX])
	_q.kit.need(problems, rect.position.y >= band + MARGIN_PX, "the line %s is within %.0f px of the HUD band (bottom %.0f)" % [UiKit.rs(rect), MARGIN_PX, band])
	_q.kit.need(problems, is_equal_approx(rect.position.y, mines_rect.position.y) and is_equal_approx(rect.size.y, mines_rect.size.y) and rect.end.x + MARGIN_PX <= mines_rect.position.x, "the line %s is not on the Mines line's row %s with %.0f px between them" % [UiKit.rs(rect), UiKit.rs(mines_rect), MARGIN_PX])
	for other: Rect2 in [notice.get_global_rect(), hint.get_global_rect()]:
		_q.kit.need(problems, not rect.grow(MARGIN_PX).intersects(other), "the line %s is within %.0f px of %s" % [UiKit.rs(rect), MARGIN_PX, UiKit.rs(other)])
	var width: float = _ui.fits(label, WIDEST, "the line", problems)
	_q.kit.need(problems, _k.count_label(1) != label and label.get_viewport() != _k.count_label(1).get_viewport() and _k.line(1) == "Ammo 100 / 100", "the other view's line reads '%s'" % _k.line(1))
	var mark: int = _q.tokens.events.size()
	await _q.tokens.destruct(0)
	await _q.tokens.wait_for(&"destroyed", mark)
	await _q.kit.advance(Kit22.SETTLE)
	var panel_rect: Rect2 = (_q.units.panels[0].find_child("Panel", true, false) as PanelContainer).get_global_rect()
	_q.kit.need(problems, _q.units.panels[0].visible and view.grow(-MARGIN_PX).encloses(panel_rect) and not panel_rect.grow(MARGIN_PX).intersects(rect), "the choice panel %s is within %.0f px of the line's place %s" % [UiKit.rs(panel_rect), MARGIN_PX, UiKit.rs(rect)])
	await _q.tokens.choose(0, Quick.TRUCK)
	await _q.kit.advance(Kit22.SETTLE)
	var countdown: Label = _q.units.countdowns[0] as Label
	var drawn: Vector2 = countdown.get_theme_font(&"font").get_string_size(countdown.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, countdown.get_theme_font_size(&"font_size")) + Vector2.ONE * float(countdown.get_theme_constant(&"outline_size"))
	var countdown_rect: Rect2 = Rect2(view.get_center() - drawn / 2.0, drawn)
	_q.kit.need(problems, countdown.visible and not countdown_rect.grow(MARGIN_PX).intersects(rect), "the countdown '%s' drawn at %s is within %.0f px of the line's place %s" % [countdown.text, UiKit.rs(countdown_rect), MARGIN_PX, UiKit.rs(rect)])
	await _q.units.wait_alive(0, 400)
	measured.append("ammo_line=%s" % UiKit.rs(rect).replace(" ", ":"))
	_q.kit.verdict("line_layout", problems, "'%s' at %s in the 640 x 720 view, %.0f px wide at its widest ('%s') on one line in a label %.0f px wide: on the Mines line's row (%s) with %.0f px between, %.0f px below the HUD band (bottom %.0f), %.0f px above the notice %s, %.0f px from the hint %s, and clear of the choice panel %s and of the countdown %s" % [TRUCK_AMMO, UiKit.rs(rect), width, WIDEST, label.size.x, UiKit.rs(mines_rect), mines_rect.position.x - rect.end.x, rect.position.y - band, band, notice.get_global_rect().position.y - rect.end.y, UiKit.rs(notice.get_global_rect()), hint.get_global_rect().position.y - rect.end.y, UiKit.rs(hint.get_global_rect()), UiKit.rs(panel_rect), UiKit.rs(countdown_rect)])


## The Round ends by the delivery of the Flag by Player 2's Motorbike that had spent seven Shots: the Round-over screen shows over the
## line, which keeps the count the Round ended with, and R then starts a fresh Round with full loads.
func _under_the_round_over_screen() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(1, Quick.MOTORBIKE)
	await _k.fire_n(1, SPENT)
	var full: int = _k.weapon(1).capacity
	await _k.k.walls().restore_all(true)
	await _k.k.walls().turrets_down()
	_k.k.flags().wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await _k.k.flags().take_flag(1, 0, Walls.GATE)
	await _k.k.flags().back_out(1, 0, Walls.GATE)
	var delivered: bool = await _k.k.flags().deliver(1)
	var screen: RoundOverScreen = _ui.over_screen(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by the delivery (taken %s, delivered %s)" % [taken, delivered])
	_q.kit.need(problems, screen != null and screen.visible, "the Round-over screen is not shown")
	var expected: String = "Ammo %d / %d" % [full - SPENT, full]
	_q.kit.need(problems, _k.line(1) == expected and _k.count_label(1).visible, "under the Round-over screen the line reads '%s', expected '%s'" % [_k.line(1), expected])
	await _k.k.flags().restart()
	_q.kit.need(problems, _k.line(1) == "Ammo 100 / 100" and _k.line(0) == "Ammo 100 / 100", "after R the lines read '%s' and '%s'" % [_k.line(0), _k.line(1)])
	_q.kit.verdict("line_under_the_round_over_screen", problems, "with the Round over by Player 2's delivery the screen showed and Player 2's line kept the count the Round ended with ('%s'); R then started a fresh Round and both lines read 'Ammo 100 / 100'" % expected)
