extends RefCounted
## The hard rule of the turrets scenario (Story 013 AC-5), on the shipped Turrets and Map 01, in
## real Rounds. lock: at each Base in turn the other Player's Motorbike drives in through a broken
## Flag Wall and touches the Flag: with both Turrets standing it picks nothing up and only its own
## view shows "Destroy the turrets first" for as long as it touches; with one Turret down the Flag is
## still locked; on the first tick the second falls the Motorbike that is already touching takes the
## Flag and the line goes; the Carrier delivers, the Round-over screen takes the view without the
## line, and the restart follows. line: where the line sits in the 640 x 720 view with the Unit
## choice panel, the out-of-Fuel hint and the HUD band shown by the Round itself. Run by turrets.gd.
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-5. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Walls' names and sizes.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The Story 008 UI helpers (token_ui_kit.gd): the view's rectangle, a label against its width.
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## The notice's text, as the story decided it.
const NOTICE_TEXT: String = "Destroy the turrets first"
## Ticks the lock is sampled for after a settle, and the ticks the Flag may take to be handed over
## once the last Turret is down (the tick of the fall and the next).
const SETTLE_TICKS: int = 10
const SAMPLE_TICKS: int = 50
const TAKEN_WITHIN_TICKS: int = 2
## Least room, pixels, between the line and the view's edge and between it and what it must clear
## (token_layout.gd's margin).
const MARGIN_PX: float = 8.0
## The share of its tank a stranded Motorbike spawns with: dry within a second standing.
const SMALL_TANK: float = 0.005
## Ticks a wait for a stranded Unit or a choice panel may take.
const WAIT_TICKS: int = 300

var _k: Kit13
var _ui: UiKit
## What each check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit
	_ui = UiKit.new(kit.w.s.q.tokens)


## The two checks, in order.
func run() -> void:
	await _lock()
	await _line()


## Counts, over SAMPLE_TICKS ticks after a settle, how often each reading held for the raider at a
## Base: {ticks, line (the raider's view shows the line), other_line (the other view does), touch,
## carry, locked (the controller says the lock alone stops the raider), owner_locked (it says so of
## the owner)}. A coroutine: await it.
func _sample(raider: int, base_index: int) -> Dictionary:
	var q: Quick = _k.w.s.q
	var flags: Object = _k.w.s.flags
	var seen: Dictionary = {"ticks": 0, "line": 0, "other_line": 0, "touch": 0, "carry": 0, "locked": 0, "owner_locked": 0}
	await q.kit.advance(SETTLE_TICKS)
	q.kit.on_tick = func() -> void:
		seen["ticks"] += 1
		seen["line"] += 1 if _k.notice(raider).visible else 0
		seen["other_line"] += 1 if _k.notice(1 - raider).visible else 0
		seen["touch"] += 1 if flags.touching(base_index, raider) else 0
		seen["carry"] += 1 if _k.w.carrying(raider) else 0
		seen["locked"] += 1 if q.controller.is_flag_locked_for(raider) else 0
		seen["owner_locked"] += 1 if q.controller.is_flag_locked_for(1 - raider) else 0
	await q.kit.advance(SAMPLE_TICKS)
	q.kit.on_tick = Callable()
	return seen


## True when a sample shows the lock holding: the raider touched the Flag and carried nothing on
## every tick, its view showed the line and the other view never did.
func _held(seen: Dictionary) -> bool:
	var ticks: int = int(seen["ticks"])
	return ticks == SAMPLE_TICKS and int(seen["line"]) == ticks and int(seen["locked"]) == ticks and int(seen["touch"]) == ticks \
			and int(seen["carry"]) == 0 and int(seen["other_line"]) == 0 and int(seen["owner_locked"]) == 0


## The rectangle of the Round-over panel of a Player's view, when the screen is shown.
func _over_rect(player: int) -> Rect2:
	var screen: RoundOverScreen = _ui.over_screen(player)
	var panel: PanelContainer = screen.find_child("Panel", true, false) as PanelContainer
	return panel.get_global_rect() if screen.visible and panel.is_visible_in_tree() else Rect2()


## lock (AC-5): see the class doc.
func _lock() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var flags: Object = _k.w.s.flags
	var notes: PackedStringArray = []
	for base_index: int in Kit.PLAYERS:
		var raider: int = 1 - base_index
		var label: String = "Base %d (Player %d raiding)" % [base_index + 1, raider + 1]
		await _k.restore_all()
		_k.w.wall(base_index, Walls.GATE).destroy()
		await q.kit.advance(Kit13.SETTLE)
		var picks: int = flags.pick_ups.size()
		await _k.w.face(raider, Quick.MOTORBIKE, base_index, Walls.GATE, Walls.FACE + Walls.RUN_UP)
		await q.kit.advance(SETTLE_TICKS)
		var away_line: bool = _k.notice(raider).visible or flags.touching(base_index, raider)
		var reached: bool = await flags.drive_until(raider, 1, Swap.CRUISE, func() -> bool: return flags.touching(base_index, raider)) > 0
		q.kit.need(problems, reached and q.units.units[raider].is_alive, "%s: the Motorbike did not reach the Flag through the breach alive" % label)
		var both: Dictionary = await _sample(raider, base_index)
		q.kit.need(problems, _held(both) and flags.flags[base_index].state == Flag.State.AT_HOME, "%s, both Turrets standing: %s" % [label, both])
		var notice: PlayerNotice = _k.notice(raider)
		q.kit.need(problems, notice.visible and notice.text == NOTICE_TEXT and not _k.notice(base_index).visible, "%s: the line reads '%s' (shown %s) and the owner's view shows it %s" % [label, notice.text, notice.visible, _k.notice(base_index).visible])
		await _k.w.back_out(raider, base_index, Walls.GATE)
		await q.kit.advance(SETTLE_TICKS)
		var left_line: bool = _k.notice(raider).visible or flags.touching(base_index, raider)
		var again: bool = await flags.drive_until(raider, 1, Swap.CRUISE, func() -> bool: return flags.touching(base_index, raider)) > 0
		await q.kit.advance(SETTLE_TICKS)
		q.kit.need(problems, not away_line and not left_line and again and _k.notice(raider).visible, "%s: the line before the Motorbike touched the Flag was %s, after it backed away %s, and on touching again %s" % [label, away_line, left_line, _k.notice(raider).visible])
		_k.turret(base_index, Kit13.LEFT).destroy()
		var one: Dictionary = await _sample(raider, base_index)
		q.kit.need(problems, _held(one) and flags.pick_ups.size() == picks, "%s, one Turret down: %s" % [label, one])
		var down_tick: int = q.harness.ticks
		_k.turret(base_index, Kit13.RIGHT).destroy()
		await q.kit.advance(TAKEN_WITHIN_TICKS)
		var taken_at: int = flags.pick_ups[picks].z if flags.pick_ups.size() > picks else -1
		q.kit.need(problems, flags.pick_ups.size() == picks + 1 and taken_at - down_tick <= TAKEN_WITHIN_TICKS and _k.w.carrying(raider) and not _k.notice(raider).visible and not q.controller.is_flag_locked_for(raider), "%s, both down: %d pick-ups after, taken at tick %d for a fall at %d, carrying %s, line shown %s" % [label, flags.pick_ups.size() - picks, taken_at, down_tick, _k.w.carrying(raider), _k.notice(raider).visible])
		await q.kit.advance(SAMPLE_TICKS)
		q.kit.need(problems, not _k.notice(raider).visible and _k.w.carrying(raider), "%s: the line came back while the Motorbike carried the Flag" % label)
		await _k.w.back_out(raider, base_index, Walls.GATE)
		var won: bool = await _k.w.deliver(raider)
		var rect: Rect2 = _over_rect(raider)
		var line_rect: Rect2 = _k.notice(raider).get_global_rect()
		q.kit.need(problems, won and q.controller.winner_index() == raider and not _k.notice(raider).visible and not _k.notice(base_index).visible, "%s: the delivery did not win with the line gone (won %s, line %s)" % [label, won, _k.notice(raider).visible])
		q.kit.need(problems, rect.size != Vector2.ZERO and not rect.grow(MARGIN_PX).intersects(line_rect), "%s: the Round-over panel %s is within %.0f px of the line's place %s" % [label, UiKit.rs(rect), MARGIN_PX, UiKit.rs(line_rect)])
		notes.append("%s: no line before the Motorbike touched the Flag or after it backed away, the line and no pick-up for %d ticks with both standing, again with one down, the Flag handed over %d tick(s) after the second fell, the line gone, then won" % [label, SAMPLE_TICKS, taken_at - down_tick])
		await _k.w.restart()
	q.kit.verdict("lock", problems, " | ".join(notes))


## Waits at most WAIT_TICKS for a condition. A coroutine: await it.
func _wait(condition: Callable) -> void:
	for _tick: int in WAIT_TICKS:
		if condition.call():
			return
		await _k.w.s.q.kit.tick()


## line (AC-5): where the line sits in the 640 x 720 view, with the out-of-Fuel hint shown beside it
## (a stranded Motorbike touching a locked Flag) and then the Unit choice panel (its Self-destruct).
func _line() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var base_index: int = 0
	var raider: int = 1
	var owner_player: int = 0
	var flags: Object = _k.w.s.flags
	await _k.restore_all()
	_k.w.wall(base_index, Walls.GATE).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var spot: Vector3 = _k.w.point(base_index, Walls.SEAT + Walls.OUT[Walls.GATE] * 1.0)
	await _k.w.park(base_index)
	await q.put(raider, q.small_tank(Quick.MOTORBIKE, SMALL_TANK), spot, _k.w.way(base_index, -Walls.OUT[Walls.GATE]))
	var unit: Unit = q.units.units[raider]
	await _wait(func() -> bool: return unit.is_stranded)
	await q.kit.advance(SETTLE_TICKS)
	var notice: PlayerNotice = _k.notice(raider)
	var hint: SelfDestructHint = q.hints[raider]
	var hud: PlayerHud = q.units.huds[raider]
	var view: Rect2 = _ui.view_of(raider)
	var rect: Rect2 = notice.get_global_rect()
	var band: float = 0.0
	for child: Node in hud.get_children():
		if child is Control:
			band = maxf(band, (child as Control).get_global_rect().end.y)
	band += hud.edge_style.get_margin(SIDE_BOTTOM) if hud.edge_style != null else 0.0
	q.kit.need(problems, notice.visible and hint.visible and unit.is_stranded and not _k.notice(base_index).visible, "the line (%s) and the hint (%s) were not both shown to the stranded Motorbike at the Flag" % [notice.visible, hint.visible])
	q.kit.need(problems, view.grow(-MARGIN_PX).encloses(rect), "the line %s leaves the view %s by less than %.0f px" % [UiKit.rs(rect), UiKit.rs(view), MARGIN_PX])
	q.kit.need(problems, rect.position.y >= band + MARGIN_PX, "the line %s is within %.0f px of the HUD band (bottom %.0f)" % [UiKit.rs(rect), MARGIN_PX, band])
	q.kit.need(problems, not rect.grow(MARGIN_PX).intersects(hint.get_global_rect()), "the line %s is within %.0f px of the hint %s" % [UiKit.rs(rect), MARGIN_PX, UiKit.rs(hint.get_global_rect())])
	_ui.fits(notice, notice.text, "the line", problems)
	q.kit.need(problems, notice.get_line_count() == 1 and notice.text == NOTICE_TEXT, "the line shows '%s' on %d lines" % [notice.text, notice.get_line_count()])
	var hint_rect: Rect2 = hint.get_global_rect()
	var mark: int = q.tokens.events.size()
	await q.tokens.destruct(raider)
	await q.tokens.wait_for(&"destroyed", mark)
	await _wait(func() -> bool: return q.units.panels[raider].visible)
	var panel: PanelContainer = q.units.panels[raider].find_child("Panel", true, false) as PanelContainer
	var panel_rect: Rect2 = panel.get_global_rect()
	q.kit.need(problems, q.units.panels[raider].visible and not notice.visible and not hint.visible, "after the Self-destruct the choice panel is shown (%s), the line %s and the hint %s still shown" % [q.units.panels[raider].visible, notice.visible, hint.visible])
	q.kit.need(problems, view.grow(-MARGIN_PX).encloses(panel_rect) and not panel_rect.grow(MARGIN_PX).intersects(rect), "the choice panel %s is within %.0f px of the line's place %s" % [UiKit.rs(panel_rect), MARGIN_PX, UiKit.rs(rect)])
	await _k.w.s.play(raider, Quick.MOTORBIKE)
	# the Round ends while the line is shown: Player 2's new Motorbike touches the locked Flag again and
	# Player 1 takes Base B's Flag (its Turrets down, its Gate-side Flag Wall broken) and delivers it
	flags.teleport(raider, spot, _k.w.way(base_index, -Walls.OUT[Walls.GATE]))
	await q.kit.advance(SETTLE_TICKS)
	q.kit.need(problems, notice.visible and _k.w.s.flags.touching(base_index, raider), "the line was not shown to Player 2's new Motorbike on the Flag (%s)" % notice.visible)
	_k.w.wall(1, Walls.GATE).destroy()
	for side: int in Kit13.NAMES.size():
		_k.turret(1, side).destroy()
	var pose: Array[Vector3] = _k.w.pose(1, Walls.GATE, Walls.FACE + Walls.RUN_UP)
	flags.teleport(owner_player, pose[0], pose[1])
	await q.kit.advance(Kit13.SETTLE)
	var taken: bool = await flags.drive_until(owner_player, 1, Swap.CRUISE, func() -> bool: return _k.w.carrying(owner_player)) > 0
	await _k.w.back_out(owner_player, 1, Walls.GATE)
	var shown_before: bool = notice.visible
	var won: bool = taken and await _k.w.deliver(owner_player)
	var over: Rect2 = _over_rect(raider)
	q.kit.need(problems, won and shown_before and not notice.visible and not _k.notice(owner_player).visible and flags.touching(base_index, raider), "the Round ended with the line shown %s before and %s after, Player 2 still on the Flag %s (won %s)" % [shown_before, notice.visible, flags.touching(base_index, raider), won])
	q.kit.need(problems, over.size != Vector2.ZERO and not over.grow(MARGIN_PX).intersects(rect), "the Round-over panel %s is within %.0f px of the line's place %s" % [UiKit.rs(over), MARGIN_PX, UiKit.rs(rect)])
	await _k.w.restart()
	measured.append("line=%s" % UiKit.rs(rect).replace(" ", ":"))
	q.kit.verdict("line", problems, "'%s' at %s in the 640 x 720 view: %.0f px below the HUD band (bottom %.0f), %.0f px above the hint %s, clear of the choice panel %s and of the Round-over panel %s, on one line inside its label, and gone with the Round when Player 1 won while Player 2 still touched the locked Flag" % [
		NOTICE_TEXT, UiKit.rs(rect), rect.position.y - band, band, hint_rect.position.y - rect.end.y, UiKit.rs(hint_rect), UiKit.rs(panel_rect), UiKit.rs(over)])
