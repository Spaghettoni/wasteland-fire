extends RefCounted
## Where the Mines line sits in the 640 x 720 view (Story 014 AC-2): inside the view with nothing clipped, on one
## line, under the HUD band, and clear of the notice line, the out-of-Fuel hint, the Unit choice panel and the
## respawn countdown, each measured as the node lays itself out while shown. A stranded Truck in front of the own
## Gate shows the line, the hint and a refusal's notice together; its destruction then shows the choice panel and,
## once it has chosen again, the countdown. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-014-truck-mines.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## The least gap in pixels the line keeps to every other element.
const MARGIN_PX: float = 8.0
## Where the Truck stands in front of its own Gate: the drop point lies in the approach, so a press is refused.
const GATE_TRUCK: Vector3 = Vector3(-98.0, 0.0, 0.0)
const TEXT: String = "Mines 5 / 5"
## Where the other Player's Motorbike stands meanwhile: open flat ground, far from the Truck.
const OTHER_SPOT: Vector3 = Vector3(-30.0, 0.0, 12.0)

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object
var _ui: UiKit


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q
	_ui = UiKit.new(kit.w.s.q.tokens)


func run() -> void:
	await _layout()


func _layout() -> void:
	var problems: PackedStringArray = []
	await _k.revive(1)
	await _k.put(1, Quick.MOTORBIKE, OTHER_SPOT, Vector3.RIGHT)
	await _k.revive(0)
	await _k.put_stranded(0, GATE_TRUCK, Vector3.LEFT)
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	await _q.kit.advance(Kit14.SETTLE)
	var label: MineCount = _k.count_label(0)
	var notice: PlayerNotice = _k.notice(0)
	var hint: SelfDestructHint = _q.hints[0]
	var hud: PlayerHud = _q.units.huds[0]
	var view: Rect2 = _ui.view_of(0)
	var rect: Rect2 = label.get_global_rect()
	var band: float = 0.0
	for child: Node in hud.get_children():
		if child is Control:
			band = maxf(band, (child as Control).get_global_rect().end.y)
	band += hud.edge_style.get_margin(SIDE_BOTTOM) if hud.edge_style != null else 0.0
	_q.kit.need(problems, label.visible and notice.visible and hint.visible and label.text == TEXT, "the line '%s' (%s), the notice (%s) and the hint (%s) were not all shown" % [label.text, label.visible, notice.visible, hint.visible])
	_q.kit.need(problems, not _k.count_label(1).visible and not _k.notice(1).visible, "the other Player's view shows the line or the notice")
	_q.kit.need(problems, view.grow(-MARGIN_PX).encloses(rect), "the line %s leaves the view %s by less than %.0f px" % [UiKit.rs(rect), UiKit.rs(view), MARGIN_PX])
	_q.kit.need(problems, rect.position.y >= band + MARGIN_PX, "the line %s is within %.0f px of the HUD band (bottom %.0f)" % [UiKit.rs(rect), MARGIN_PX, band])
	_q.kit.need(problems, not rect.grow(MARGIN_PX).intersects(notice.get_global_rect()), "the line %s is within %.0f px of the notice %s" % [UiKit.rs(rect), MARGIN_PX, UiKit.rs(notice.get_global_rect())])
	_q.kit.need(problems, not rect.grow(MARGIN_PX).intersects(hint.get_global_rect()), "the line %s is within %.0f px of the hint %s" % [UiKit.rs(rect), MARGIN_PX, UiKit.rs(hint.get_global_rect())])
	var width: float = _ui.fits(label, TEXT, "the line", problems)
	var mark: int = _q.tokens.events.size()
	await _q.tokens.destruct(0)
	await _q.tokens.wait_for(&"destroyed", mark)
	await _q.kit.advance(Kit14.SETTLE)
	var panel: PanelContainer = _q.units.panels[0].find_child("Panel", true, false) as PanelContainer
	var panel_rect: Rect2 = panel.get_global_rect()
	_q.kit.need(problems, _q.units.panels[0].visible and not label.visible and view.grow(-MARGIN_PX).encloses(panel_rect) and not panel_rect.grow(MARGIN_PX).intersects(rect), "the choice panel %s is within %.0f px of the line's place %s (line shown %s)" % [UiKit.rs(panel_rect), MARGIN_PX, UiKit.rs(rect), label.visible])
	await _q.tokens.choose(0, Quick.TRUCK)
	await _q.kit.advance(Kit14.SETTLE)
	var countdown: Label = _q.units.countdowns[0] as Label
	var drawn: Vector2 = countdown.get_theme_font(&"font").get_string_size(countdown.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, countdown.get_theme_font_size(&"font_size")) + Vector2.ONE * float(countdown.get_theme_constant(&"outline_size"))
	var countdown_rect: Rect2 = Rect2(view.get_center() - drawn / 2.0, drawn)
	_q.kit.need(problems, countdown.visible and countdown.text.begins_with("Respawn in") and not countdown_rect.grow(MARGIN_PX).intersects(rect), "the countdown '%s' (shown %s) drawn at %s is within %.0f px of the line's place %s" % [countdown.text, countdown.visible, UiKit.rs(countdown_rect), MARGIN_PX, UiKit.rs(rect)])
	await _q.units.wait_alive(0, 400)
	measured.append("mines_line=%s" % UiKit.rs(rect).replace(" ", ":"))
	_q.kit.verdict("mines_line_layout", problems, "'%s' at %s in the 640 x 720 view, %.0f px wide on one line in its label: %.0f px below the HUD band (bottom %.0f), %.0f px above the notice %s and %.0f px from the out-of-Fuel hint %s, clear of the choice panel %s and of the respawn countdown %s, and in that Player's view alone" % [
		TEXT, UiKit.rs(rect), width, rect.position.y - band, band, notice.get_global_rect().position.y - rect.end.y, UiKit.rs(notice.get_global_rect()), hint.get_global_rect().position.y - rect.end.y, UiKit.rs(hint.get_global_rect()), UiKit.rs(panel_rect), UiKit.rs(countdown_rect)])
