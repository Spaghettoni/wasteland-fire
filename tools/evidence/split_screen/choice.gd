extends RefCounted
## Scenario choice of the split screen evidence harness (split_screen_harness.gd): the Unit choice
## of Story 005, played with real key events (Space and Period to confirm, A and D to move Player
## 1's cursor, Tab to Self-destruct, the arrows to drive, R to restart) and judged from the
## MatchController, Player 1's PlayerChoiceInput and the two choice panels under the SubViewports.
## Two CHECK lines, every number measured: choice_flow (AC-6: both Units out of play at the start
## with both Players choosing and no delay; a confirm on the first tick lands the Unit exactly on
## its spawn point; the cursor steps and wraps with the steer keys and a confirm puts the Unit in
## play at once; the other Player plays on meanwhile; a choice made during the respawn countdown
## waits for the delay; a choice made after the delay ran out appears at once; a restart after a win
## returns both Players to choosing; every type was chosen at least once) and choice_panel (AC-6,
## AC-8: each panel shows for its own Player only, names the four types from the data, marks the
## cursor's slot, reads ready after the confirm with no mark, hides when the Unit appears and when
## the Round is over, names its keys as the Input Map binds them, and its rect sits inside its 640 x
## 720 view by the margin, at most 560 px wide, clear of the respawn countdown's text). The shipped
## data; the runner makes no choice for this scenario (OWN_CHOICE). Tooling only; the shared helpers
## are check_kit.gd, unit_kit.gd and flag_kit.gd (the delivery that ends the Round).
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6 and AC-8.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=choice

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the signal record, the screens, the waits.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 004 helpers (flag_kit.gd): the drive at a Flag, the run home, the Round record.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The restart key (round_restart). Tools are the only place key codes appear.
const KEYS_RESTART: Array[Key] = [KEY_R]
## Player 1's cursor dance over the four types from 0: true steps to the next type, false to the
## previous (the third false wraps from the first type to the last, the next true back to the
## first).
const DANCE_NEXT: Array[bool] = [true, true, false, false, false, true, true]
## The cursor each step of DANCE_NEXT leaves, that is the slot the panel must mark after it.
const DANCE_CURSORS: Array[int] = [1, 2, 1, 0, 3, 0, 1]
## Ticks a spawn may follow a confirm that acts at once: the key acts on its tick or the next.
const AT_ONCE_SLACK: int = 2
## Ticks a confirm on the first tick of the run may take to put the Unit in play: the bench settle
## and the key's tick.
const FIRST_TICK_LIMIT: int = 10
## Seconds Player 2 drives while Player 1 still chooses.
const PLAY_ON_SECONDS: float = 1.0
## The least Player 2 must have moved in that time, metres.
const MOVE_MIN: float = 1.0
## Ticks into the respawn countdown at which the choice is made, well before the delay runs out.
const CHOOSE_AFTER_TICKS: int = 30
## Ticks waited after a change before a panel is read, so that it has been laid out.
const LAYOUT_TICKS: int = 2
## Least room between a panel and the edge of its view, pixels (AC-8).
const MARGIN_PX: float = 16.0
## The widest a panel may be, pixels (AC-8).
const PANEL_MAX_WIDTH: float = 560.0
## Where Player 1 is parked and destroyed before the delivery (the steps of the round_over
## scenario).
const PARK_SPOT: Vector3 = Vector3(-12.0, 0.0, 8.0)
## Where Player 2 is put, carrying Flag 1, to run home into Base 2's zone.
const BASE_2_RUN_START: Vector3 = Vector3(0.0, 0.0, -6.0)
## The direction Player 2 faces when it approaches Flag 1 and when it runs home: toward Base 2
## (-Z).
const TO_BASE_2: Vector3 = Vector3(0.0, 0.0, -1.0)

var _harness: Harness
var _kit: Kit
var _units: Units
var _flag_kit: Flags
## The problems and the readings of the two checks, and the cursor_moved emits of Player 1's input.
var _flow: PackedStringArray = []
var _flow_notes: PackedStringArray = []
var _panel: PackedStringArray = []
var _panel_notes: PackedStringArray = []
var _moves: int = 0


## Runs the scenario; the code order is the order of the readings. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_flag_kit = Flags.new(harness, _kit)
	_units.panels[0].choice_input.cursor_moved.connect(func(_type_index: int) -> void: _moves += 1)
	_units.controller.unit_chosen.connect(func(player: int, _type_index: int) -> void: _harness.set_key(_harness.fire_key(player), false))
	await _check_start()
	await _check_cursor_and_confirm()
	await _check_countdown_choice()
	await _check_restart()
	var types: Array[int] = []
	for choice: Vector3i in _units.chosen:
		if not types.has(choice.y):
			types.append(choice.y)
	types.sort()
	_kit.need(_flow, types.size() == Units.TYPE_IDS.size(), "types chosen across the scenario: %s" % [types])
	_kit.verdict("choice_flow", _flow, " | ".join(_flow_notes) + " | types chosen=%s of %d" % [types, Units.TYPE_IDS.size()])
	_kit.verdict("choice_panel", _panel, " | ".join(_panel_notes))
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("chosen=%d spawned=%d destroyed=%d round_started=%d round_over=%d cursor_moves=%d" % [
		_units.chosen.size(), _units.spawns.size(), _units.destroyed.size(), _flag_kit.round_started, _flag_kit.round_overs.size(), _moves])


## The start: both out of play and choosing, no delay; Player 2 confirms on the first tick (its fire
## key held until the choice is accepted) and lands exactly on its spawn point.
func _check_start() -> void:
	_harness.phase = &"start"
	var controller: MatchController = _units.controller
	var p1: Unit = _units.units[0]
	var p2: Unit = _units.units[1]
	var benched: bool = (controller.is_choosing(0) and controller.is_choosing(1) and not p1.is_alive and not p2.is_alive and not p1.visible
		and not p2.visible and is_zero_approx(controller.seconds_until_respawn(0)) and is_zero_approx(controller.seconds_until_respawn(1))
		and _units.spawns.is_empty() and _harness.round_start_spawns.is_empty())
	_kit.need(_flow, benched, "the Round did not start with both Players choosing and no Unit in play")
	_flow_notes.append("start: choosing=%s/%s alive=%s/%s visible=%s/%s seconds_until_respawn=%.2f/%.2f spawns=%d" % [controller.is_choosing(0),
		controller.is_choosing(1), p1.is_alive, p2.is_alive, p1.visible, p2.visible, controller.seconds_until_respawn(0), controller.seconds_until_respawn(1), _units.spawns.size()])
	_panel_notes.append(_read_panel(0, &"choosing", 0))
	_panel_notes.append(_read_panel(1, &"choosing", 0))
	var pressed: int = _harness.ticks
	_harness.set_key(_harness.fire_key(Harness.PLAYER_2), true)
	var waited: int = await _units.wait_alive(Harness.PLAYER_2, FIRST_TICK_LIMIT)
	_harness.set_key(_harness.fire_key(Harness.PLAYER_2), false)
	var spawn: Vector2i = _units.spawns[-1] if not _units.spawns.is_empty() else Vector2i(-1, -1)
	var spot: Transform3D = _units.bases[1].spawn_point.global_transform
	var home: float = p2.global_position.distance_to(spot.origin)
	var facing: float = (-p2.global_transform.basis.z).dot(-spot.basis.z)
	var landed: bool = (waited >= 0 and spawn.x == 1 and home <= Kit.SPAWN_TOLERANCE and facing >= Kit.FACING_DOT_MIN and p2.type_id == Units.TYPE_IDS[0]
		and spawn.y - pressed <= GarageQueue.SPAWN_SETTLE_TICKS + AT_ONCE_SLACK and controller.is_choosing(0))
	_kit.need(_flow, landed, "Player 2's first-tick confirm did not land the Motorbike on its spawn point (waited %d, %.4f m off)" % [waited, home])
	_flow_notes.append("p2 Period on tick %d of the run: unit_spawned(%d) at tick %d (%d after the key; bench settle %d), type=%s, %.4f m from its spawn point (max %.2f), facing dot %.4f, p1 still choosing=%s" % [
		pressed, spawn.x, spawn.y, spawn.y - pressed, GarageQueue.SPAWN_SETTLE_TICKS, p2.type_id, home, Kit.SPAWN_TOLERANCE, facing, controller.is_choosing(0)])
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(1, &"hidden", -1))


## Player 1's cursor dance, Player 2 playing on meanwhile, and Player 1's confirm at once.
func _check_cursor_and_confirm() -> void:
	_harness.phase = &"cursor"
	var controller: MatchController = _units.controller
	var input: PlayerChoiceInput = _units.panels[0].choice_input
	var p1: Unit = _units.units[0]
	var p2: Unit = _units.units[1]
	var moves_before: int = _moves
	var cursors: PackedInt32Array = []
	var followed: bool = true
	for step: int in DANCE_NEXT.size():
		await _kit.press_settled(Kit.KEYS_NEXT_1 if DANCE_NEXT[step] else Kit.KEYS_PREVIOUS_1)
		cursors.append(input.cursor)
		followed = followed and input.cursor == DANCE_CURSORS[step]
		var note: String = _read_panel(0, &"choosing", DANCE_CURSORS[step])
		if step == DANCE_NEXT.size() - 1:
			_panel_notes.append(note)
	_kit.need(_flow, followed and _moves - moves_before == DANCE_NEXT.size(), "the cursor did not follow the keys: %s expected %s, cursor_moved %d" % [cursors, DANCE_CURSORS, _moves - moves_before])
	_flow_notes.append("p1 cursor after D D A A A D D: %s (expected %s, two wraps), cursor_moved emitted %d times" % [cursors, DANCE_CURSORS, _moves - moves_before])
	_harness.phase = &"play_on"
	var start: Vector3 = p2.global_position
	_harness.drive(Harness.PLAYER_2, 1, 0)
	await _kit.advance(_harness.ticks_in(PLAY_ON_SECONDS))
	_harness.drive(Harness.PLAYER_2, 0, 0)
	var moved: float = start.distance_to(p2.global_position)
	_kit.need(_flow, moved >= MOVE_MIN and controller.is_choosing(0) and not p1.is_alive, "Player 2 did not play on while Player 1 chose (moved %.2f m)" % moved)
	_flow_notes.append("p2 drove %.1f s while p1 chose: moved %.2f m (at least %.1f), p1 choosing=%s alive=%s" % [PLAY_ON_SECONDS, moved, MOVE_MIN, controller.is_choosing(0), p1.is_alive])
	_harness.phase = &"confirm"
	var pressed: int = _harness.ticks
	await _kit.press_settled(Kit.KEYS_FIRE_1)
	var waited: int = await _units.wait_alive(Harness.PLAYER_1, AT_ONCE_SLACK)
	var spawn: Vector2i = _units.spawns[-1] if not _units.spawns.is_empty() else Vector2i(-1, -1)
	var choice: Vector3i = _units.chosen[-1] if not _units.chosen.is_empty() else Vector3i(-1, -1, -1)
	var home: float = p1.global_position.distance_to(_units.bases[0].spawn_point.global_position)
	var at_once: bool = (waited >= 0 and spawn.x == 0 and choice.x == 0 and choice.y == DANCE_CURSORS[-1] and spawn.y == choice.z
		and p1.type_id == Units.TYPE_IDS[choice.y] and home <= Kit.SPAWN_TOLERANCE)
	_kit.need(_flow, at_once, "Player 1's confirm did not put the chosen type in play at once (waited %d, chosen %s, spawn %s)" % [waited, choice, spawn])
	_flow_notes.append("p1 Space at tick %d: unit_chosen(0, %d) at tick %d, unit_spawned(0) at tick %d (the tick of the choice=%s), type=%s, %.4f m from its spawn point" % [
		pressed, choice.y, choice.z, spawn.y, spawn.y == choice.z, p1.type_id, home])
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"hidden", -1))


## A choice during the countdown waits for the delay; a choice after the delay ran out acts at once.
func _check_countdown_choice() -> void:
	_harness.phase = &"countdown"
	var controller: MatchController = _units.controller
	var p1: Unit = _units.units[0]
	var delay: float = controller.rules.respawn_delay_seconds
	var expected: int = _harness.ticks_in(delay)
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	var gone: Vector2i = _units.destroyed[-1] if not _units.destroyed.is_empty() else Vector2i(-1, -1)
	var counting: bool = (gone.x == 0 and not p1.is_alive and controller.is_choosing(0) and controller.chosen_type_index(0) == MatchController.NO_CHOICE
		and controller.seconds_until_respawn(0) > 0.0 and _units.countdowns[0].visible)
	_kit.need(_flow, counting, "the Self-destruct did not leave Player 1 choosing with a countdown")
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"choosing", DANCE_CURSORS[-1]))
	_panel_notes.append(_read_overlap(0))
	await _kit.advance(CHOOSE_AFTER_TICKS)
	await _kit.press_settled(Kit.KEYS_NEXT_1)
	var left: float = controller.seconds_until_respawn(0)
	await _kit.press_settled(Kit.KEYS_FIRE_1)
	var choice: Vector3i = _units.chosen[-1] if not _units.chosen.is_empty() else Vector3i(-1, -1, -1)
	var standing: bool = (choice.x == 0 and choice.y == DANCE_CURSORS[-1] + 1 and controller.chosen_type_index(0) == choice.y and not controller.is_choosing(0)
		and not p1.is_alive and controller.seconds_until_respawn(0) > 0.0)
	_kit.need(_flow, standing, "the choice during the countdown did not stand while the delay ran")
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"ready", choice.y))
	var waited: int = await _units.wait_alive(Harness.PLAYER_1, expected + Kit.RESPAWN_SLACK_TICKS)
	var spawn: Vector2i = _units.spawns[-1] if not _units.spawns.is_empty() else Vector2i(-1, -1)
	var on_time: bool = waited >= 0 and spawn.x == 0 and absi((spawn.y - gone.y) - expected) <= Kit.TICK_SLACK and p1.type_id == Units.TYPE_IDS[choice.y]
	_kit.need(_flow, on_time, "the Unit chosen during the countdown did not appear at the delay (%d ticks after the destruction, expected %d)" % [spawn.y - gone.y, expected])
	_flow_notes.append("p1 Tab at tick %d (countdown shown, choosing), D and Space at tick %d with %.2f s left: the choice stood (is_choosing=false, chosen_type_index=%d), unit_spawned at tick %d = %d ticks after the destruction (round(%.1f x %d) = %d, +-%d), type=%s" % [
		gone.y, choice.z, left, choice.y, spawn.y, spawn.y - gone.y, delay, Engine.physics_ticks_per_second, expected, Kit.TICK_SLACK, p1.type_id])
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"hidden", -1))
	await _check_late_choice(expected, choice.y)


## A choice after the delay ran out acts at once: with no choice made the Player stays out of play
## through the delay, then a choice puts the Unit in play on the next tick. `previous_type` is the
## type chosen during the countdown, `expected` the delay in ticks.
func _check_late_choice(expected: int, previous_type: int) -> void:
	var controller: MatchController = _units.controller
	var p1: Unit = _units.units[0]
	_harness.phase = &"late_choice"
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	var gone_again: Vector2i = _units.destroyed[-1] if not _units.destroyed.is_empty() else Vector2i(-1, -1)
	await _kit.advance(expected + Kit.RESPAWN_SLACK_TICKS)
	var waiting: bool = not p1.is_alive and controller.is_choosing(0) and is_zero_approx(controller.seconds_until_respawn(0)) and not _units.countdowns[0].visible
	_kit.need(_flow, waiting, "with no choice made the Player did not stay out of play after the delay")
	_panel_notes.append(_read_panel(0, &"choosing", previous_type))
	await _kit.press_settled(Kit.KEYS_NEXT_1)
	var pressed: int = _harness.ticks
	await _kit.press_settled(Kit.KEYS_FIRE_1)
	var waited_again: int = await _units.wait_alive(Harness.PLAYER_1, AT_ONCE_SLACK)
	var spawn_again: Vector2i = _units.spawns[-1] if not _units.spawns.is_empty() else Vector2i(-1, -1)
	var choice_again: Vector3i = _units.chosen[-1] if not _units.chosen.is_empty() else Vector3i(-1, -1, -1)
	var at_once: bool = waited_again >= 0 and spawn_again.y == choice_again.z and choice_again.y == previous_type + 1 and p1.type_id == Units.TYPE_IDS[choice_again.y]
	_kit.need(_flow, at_once, "the choice after the delay did not put the Unit in play at once")
	_flow_notes.append("p1 Tab at tick %d, no choice for %d ticks: out of play=%s choosing=%s seconds_until_respawn=%.2f countdown hidden=%s; then D and Space at tick %d: unit_chosen(0, %d) at tick %d and unit_spawned at tick %d, type=%s" % [
		gone_again.y, expected + Kit.RESPAWN_SLACK_TICKS, not p1.is_alive, controller.is_choosing(0), controller.seconds_until_respawn(0),
		not _units.countdowns[0].visible, pressed, choice_again.y, choice_again.z, spawn_again.y, p1.type_id])


## Player 1 parked and destroyed while Player 2's delivery ends the Round (panels hidden). Returns
## the first part of the flow note: the steal and run ticks and whether the Round ended with the
## tree paused.
func _check_delivery() -> String:
	_harness.phase = &"delivery"
	var controller: MatchController = _units.controller
	var p1: Unit = _units.units[0]
	var p2: Unit = _units.units[1]
	_harness.place(p1, _units.pose(PARK_SPOT, Vector3.RIGHT), _units.cameras[0])
	await _kit.advance(Units.SETTLE_TICKS)
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"choosing", Units.TYPE_IDS.size() - 1))
	var flag: Flag = _flag_kit.flags[0]
	_flag_kit.approach(Harness.PLAYER_2, flag.global_position, TO_BASE_2)
	var steal: int = await _flag_kit.drive_until(Harness.PLAYER_2, 1, Flags.APPROACH_SPEED, func() -> bool: return flag.carrier == p2)
	await _flag_kit.rest(Harness.PLAYER_2)
	_flag_kit.teleport(Harness.PLAYER_2, BASE_2_RUN_START, TO_BASE_2)
	var run_ticks: int = await _flag_kit.drive_until(Harness.PLAYER_2, 1, Flags.APPROACH_SPEED, func() -> bool: return not _flag_kit.round_overs.is_empty())
	await _kit.advance(LAYOUT_TICKS)
	var over: bool = steal > 0 and run_ticks > 0 and controller.is_round_over() and _harness.get_tree().paused
	_kit.need(_flow, over, "Player 2's delivery did not end the Round (steal %d, run %d)" % [steal, run_ticks])
	_panel_notes.append(_read_panel(0, &"hidden", -1) + " (p1 was choosing when the Round ended)")
	_panel_notes.append(_read_panel(1, &"hidden", -1))
	return "p2's delivery ended the Round (steal %d ticks, run %d ticks, paused=%s) while p1 chose" % [steal, run_ticks, over]


## Player 2's delivery ends the Round with Player 1 parked and destroyed (panels hidden), the
## restart returns both to choosing on their Bases, and both confirm the Motorbike (the runner's
## presses).
func _check_restart() -> void:
	var delivery_note: String = await _check_delivery()
	var controller: MatchController = _units.controller
	var p1: Unit = _units.units[0]
	var p2: Unit = _units.units[1]
	_harness.phase = &"restart"
	var starts: int = _flag_kit.round_started
	await _kit.press_settled(KEYS_RESTART)
	var home_1: float = p1.global_position.distance_to(_units.bases[0].spawn_point.global_position)
	var home_2: float = p2.global_position.distance_to(_units.bases[1].spawn_point.global_position)
	var benched: bool = (_flag_kit.round_started == starts + 1 and controller.is_choosing(0) and controller.is_choosing(1) and not p1.is_alive and not p2.is_alive
		and not controller.is_round_over() and not _harness.get_tree().paused and home_1 <= Kit.SPAWN_TOLERANCE and home_2 <= Kit.SPAWN_TOLERANCE)
	_kit.need(_flow, benched, "the restart did not return both Players to choosing on their Bases")
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"choosing", Units.TYPE_IDS.size() - 1))
	_panel_notes.append(_read_panel(1, &"choosing", 0))
	await _kit.press_settled(Kit.KEYS_NEXT_1)
	var cursor: int = _units.panels[0].choice_input.cursor
	var spawned: int = _units.spawns.size()
	await _harness.confirm_choices()
	var both: bool = (cursor == 0 and p1.is_alive and p2.is_alive and p1.type_id == Units.TYPE_IDS[0] and p2.type_id == Units.TYPE_IDS[0]
		and _units.spawns.size() == spawned + 2)
	_kit.need(_flow, both, "after the restart both Players did not come back as the Motorbike (cursor %d)" % cursor)
	_flow_notes.append(delivery_note + "; R: round_started=%d (before %d), both choosing on their Bases (%.4f m / %.4f m from the spawn points), paused=%s; p1 D wrapped the cursor to %d; Space and Period: both alive as %s/%s, spawns %d (before %d)" % [
		_flag_kit.round_started, starts, home_1, home_2, _harness.get_tree().paused, cursor, p1.type_id, p2.type_id, _units.spawns.size(), spawned])
	await _kit.advance(LAYOUT_TICKS)
	_panel_notes.append(_read_panel(0, &"hidden", -1))
	_panel_notes.append(_read_panel(1, &"hidden", -1))


## Reads one Player's panel against a state: hidden; choosing with the cursor's slot marked and the
## hint naming the Input Map's keys; ready with the chosen type named. Adds to the panel problems.
func _read_panel(player: int, state: StringName, cursor: int) -> String:
	var choice: UnitChoice = _units.panels[player]
	var types: Array[UnitStats] = _units.controller.unit_types()
	var panel: PanelContainer = choice.find_child("Panel", true, false) as PanelContainer
	var title: Label = choice.find_child("TitleLabel", true, false) as Label
	var hint: Label = choice.find_child("HintLabel", true, false) as Label
	var names: PackedStringArray = []
	var marked: int = -1
	for child: Node in (choice.find_child("Slots", true, false) as HBoxContainer).get_children():
		var slot: PanelContainer = child as PanelContainer
		if slot == null or not slot.visible:
			continue
		if slot.get_theme_stylebox(&"panel") == choice.cursor_style:
			marked = names.size()
		elif slot.get_theme_stylebox(&"panel") != choice.slot_style:
			marked = -2
		names.append((slot.get_node(^"Lines/NameLabel") as Label).text)
	var expected_names: PackedStringArray = []
	for stats: UnitStats in types:
		expected_names.append(choice.tr(stats.display_name))
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2((_units.cameras[player].get_viewport() as SubViewport).size))
	var rect: Rect2 = panel.get_global_rect()
	var inside: bool = view.grow(-MARGIN_PX).encloses(rect) and rect.size.x <= PANEL_MAX_WIDTH
	var right: bool = not choice.visible
	var what: String = "visible=%s" % choice.visible
	if state != &"hidden":
		var choosing: bool = state == &"choosing"
		var expected_title: String = choice.tr(choice.title_text) if choosing else choice.tr(choice.ready_format) % choice.tr(types[cursor].display_name)
		var expected_mark: int = cursor if choosing else -1
		right = (choice.visible and panel.is_visible_in_tree() and title.text == expected_title and names == expected_names and marked == expected_mark
			and inside and hint.visible == choosing and (not choosing or hint.text == _hint_for(choice)))
		what = "visible=%s title=\"%s\" (expected \"%s\") slots=%s marked=%d (expected %d) hint=%s\"%s\" panel=(%.0f,%.0f %.0fx%.0f) inside_margin_%.0f=%s width_max=%.0f" % [
			choice.visible, title.text, expected_title, names, marked, expected_mark, "" if hint.visible else "hidden ", hint.text, rect.position.x,
			rect.position.y, rect.size.x, rect.size.y, MARGIN_PX, inside, PANEL_MAX_WIDTH]
	_kit.need(_panel, right, "p%d panel at %s: expected %s" % [player + 1, _harness.phase, state])
	return "p%d %s %s: %s" % [player + 1, _harness.phase, state, what]


## The countdown's text rect against the panel's rect, both shown: no overlap.
func _read_overlap(player: int) -> String:
	var countdown: RespawnCountdown = _units.countdowns[player]
	var rect: Rect2 = (_units.panels[player].find_child("Panel", true, false) as PanelContainer).get_global_rect()
	var size: Vector2 = countdown.get_theme_font(&"font").get_string_size(countdown.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, countdown.get_theme_font_size(&"font_size"))
	var label_rect: Rect2 = countdown.get_global_rect()
	var text_rect: Rect2 = Rect2(label_rect.position + (label_rect.size - size) / 2.0, size)
	var clear: bool = countdown.visible and not text_rect.intersects(rect)
	_kit.need(_panel, clear, "p%d's panel overlaps the countdown's text, or the countdown is hidden" % (player + 1))
	return "p%d countdown \"%s\" text rect=(%.0f,%.0f %.0fx%.0f) vs panel=(%.0f,%.0f %.0fx%.0f): overlap=%s" % [player + 1, countdown.text, text_rect.position.x,
		text_rect.position.y, text_rect.size.x, text_rect.size.y, rect.position.x, rect.position.y, rect.size.x, rect.size.y, not clear]


## The hint a panel must show: its format with the names of its three keys as the Input Map binds
## them (the physical key of each action's first key event, its side in front when it has one).
func _hint_for(choice: UnitChoice) -> String:
	var names: PackedStringArray = []
	for suffix: String in ["steer_left", "steer_right", "fire"]:
		var key_name: String = ""
		for event: InputEvent in InputMap.action_get_events(StringName(String(choice.action_prefix) + suffix)):
			var key_event: InputEventKey = event as InputEventKey
			if key_event != null and key_name.is_empty():
				var side: String = key_event.as_text_location()
				key_name = key_event.as_text_physical_keycode() if side.is_empty() else "%s %s" % [side.capitalize(), key_event.as_text_physical_keycode()]
		names.append(key_name)
	return choice.tr(choice.hint_format) % [names[0], names[1], names[2]]
