extends RefCounted
## What the Story 008 scenarios (tokens, tokens_data, token_choice, loss, token_ui, token_layout,
## tokens_showcase) share beyond check_kit.gd and unit_kit.gd: readings of the Token counts (the
## controller's, a HUD's Tokens line, a choice panel's slots, a Round-over screen); a record of the
## Round's signals with a reading taken inside each handler (connected after every UI node, so it is
## what the UI shows when the signal arrives) and another a frame later; a choice, a Self-destruct,
## a restart and a Shot made with real keys; Token stocks built in code; a counter of the engine's
## ERROR and WARNING lines. Make one with TokenKit.new(harness, kit) (it makes the Story 005 record,
## `units`: make no other) and call close() before finish(). No count is typed here.
## Fixtures: stock(), counts_copy(). Keys: keys(). Readings: counts(), rows_of(), charged(),
## carrier_index(), hud_line(), hud_text(), panel_counts(), count_texts(), slots(), looks(),
## fonts(), over_lines(), state(), shows(). Record: events, events_of(), wait_for(), shot_frames,
## engine_log. Real keys: choose(), spawn(), destruct(), restart(), shoot(), press_on(). Staging:
## stage_duel().
## Tooling only: nothing under src/ depends on this file; loaded with a preload constant.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): Units, cameras, HUDs, choice panels, the signal record.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The physical key of each Player's actions, Player 1 first (only tools name key codes): the
## Self-destruct (Tab, Enter), the fire key that also confirms a choice (Space, Period), the
## steer-left key that moves the cursor to the previous type (A, Left) and the steer-right key to
## the next (D, Right).
const _KEYS: Dictionary[StringName, Array] = {&"destruct": [KEY_TAB, KEY_ENTER], &"fire": [KEY_SPACE, KEY_PERIOD],
	&"previous": [KEY_A, KEY_LEFT], &"next": [KEY_D, KEY_RIGHT]}
## Frames after a Shot node was added at which a Motorbike's Shot, fired 10 m from its target (see
## stage_duel()), is one frame short of its kill: measured, it kills in frame N + 8 and a key set in
## frame N + 7 acts in frame N + 8.
const LETHAL_LEAD: int = 7


## Keeps the engine's ERROR and WARNING lines with OS.add_logger (Godot 4.5 and later; the engine
## may log from any thread, so the appends are locked): size() is the count, [-1] the last text.
class ErrorLog extends Logger:
	## The text of every ERROR line (every error type but a warning) since the log was added.
	var errors: Array[String] = []
	## The text of every WARNING line (push_warning) since the log was added.
	var warnings: Array[String] = []
	var _lock: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		(warnings if error_type == ERROR_TYPE_WARNING else errors).append((code + " " + rationale).strip_edges())
		_lock.unlock()


## The runner this kit is handed.
var harness: Harness
## The check helpers (ticks, key presses, verdicts).
var kit: Kit
## The Story 005 record this kit made: Units, cameras, HUDs, choice panels, signal records.
var units: Units
## The MatchController of the launch scene.
var controller: MatchController
## The engine log counter, installed by _init() and removed by close().
var engine_log: ErrorLog = ErrorLog.new()
## Every unit_destroyed and unit_spawned (arg: the Player), round_started and round_over (arg: the
## winner) since the kit was made: {kind, arg, now: state() in the handler, later: state() a physics
## frame after, type: the type_id of the Unit destroyed or spawned}.
var events: Array[Dictionary] = []
## The physics frame each Shot node was added in, in order.
var shot_frames: Array[int] = []


## Makes the Story 005 record, installs the engine log counter and connects the signal record.
func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	units = Units.new(harness, kit)
	controller = units.controller
	OS.add_logger(engine_log)
	controller.unit_destroyed.connect(func(player: int) -> void: _note(&"destroyed", player))
	controller.unit_spawned.connect(func(player: int) -> void: _note(&"spawned", player))
	controller.round_started.connect(func() -> void: _note(&"started", -1))
	controller.round_over.connect(func(winner: int) -> void: _note(&"over", winner))
	harness.get_tree().node_added.connect(func(node: Node) -> void:
		if node is Shot:
			shot_frames.append(Engine.get_physics_frames()))


## Removes the engine log counter: call it before the scenario's finish().
func close() -> void:
	OS.remove_logger(engine_log)


## The key of an action (&"destruct", &"fire", &"previous" or &"next") for a Player (0 is Player 1),
## as the array check_kit.gd's press() takes. Press both Players' keys on one tick with
## Kit.KEYS_DESTRUCT_BOTH, or with an array of your own.
static func keys(action: StringName, player: int) -> Array[Key]:
	var key: Key = _KEYS[action][player]
	return [key]


## A Token stock made in code, one assignment per key (an untyped Dictionary cannot be assigned to
## counts as a whole, and duplicate() of the shipped stock would share its counts).
static func stock(counts_by_id: Dictionary) -> TokenStock:
	var made: TokenStock = TokenStock.new()
	for type_id: Variant in counts_by_id:
		made.counts[StringName(str(type_id))] = int(counts_by_id[type_id])
	return made


## A copy by value of a stock's counts, per key: the snapshot to compare the live stock with.
static func counts_copy(source: TokenStock) -> Dictionary[StringName, int]:
	var copy: Dictionary[StringName, int] = {}
	for type_id: StringName in source.counts:
		copy[type_id] = source.counts[type_id]
	return copy


## The rows a stock gives both Players: [[Player 1's counts], [Player 2's]], in unit_types() order.
func rows_of(source: TokenStock) -> Array:
	var row: Array[int] = []
	for stats: UnitStats in controller.unit_types():
		row.append(source.count_of(stats.type_id))
	return [row, row.duplicate()]


## The controller's Tokens now, in the shape of rows_of(): tokens_left() per Player and type.
func counts() -> Array:
	var rows: Array = []
	for player: int in Kit.PLAYERS:
		var row: Array[int] = []
		for type_index: int in controller.unit_types().size():
			row.append(controller.tokens_left(player, type_index))
		rows.append(row)
	return rows


## A copy of rows with one Token less of the type at type_index for the Player.
static func charged(rows: Array, player: int, type_index: int) -> Array:
	var copy: Array = [rows[0].duplicate(), rows[1].duplicate()]
	copy[player][type_index] -= 1
	return copy


## The index into unit_types() of the one type that can carry the Flag, read from the data now.
func carrier_index() -> int:
	for type_index: int in controller.unit_types().size():
		if controller.unit_types()[type_index].can_carry:
			return type_index
	return -1


## The Tokens line a Player's HUD must show for `count`: the scene's format, the carrier's name
## ("" when the data has no carrier type).
func hud_text(player: int, count: int) -> String:
	var hud: PlayerHud = units.huds[player]
	var carrier: int = carrier_index()
	return hud.tr(hud.tokens_format) % [hud.tr(controller.unit_types()[carrier].display_name), count] if carrier >= 0 else ""


## The Tokens line a Player's HUD shows now ("" while its label is hidden and empty).
func hud_line(player: int) -> String:
	return (units.huds[player].find_child("TokensLabel", true, false) as Label).text


## The count lines a Player's choice panel must show for a row of counts: the scene's format.
func count_texts(player: int, row: Array) -> PackedStringArray:
	var texts: PackedStringArray = []
	for count: int in row:
		texts.append(units.panels[player].tr(units.panels[player].count_format) % count)
	return texts


## The slots of a Player's choice panel, in the order of unit_types() (the template is left out).
func slots(player: int) -> Array[PanelContainer]:
	var found: Array[PanelContainer] = []
	for child: Node in units.panels[player].find_child("Slots", true, false).get_children():
		if child is PanelContainer and (child as PanelContainer).visible:
			found.append(child as PanelContainer)
	return found


## The count line each slot of a Player's choice panel shows now (the panel need not be visible).
func panel_counts(player: int) -> PackedStringArray:
	var texts: PackedStringArray = []
	for slot: PanelContainer in slots(player):
		texts.append((slot.get_node(^"Lines/CountLabel") as Label).text)
	return texts


## How each slot of a Player's choice panel is drawn, by the panel style it wears: "cursor" (the
## marked slot), "dim" (no Token left), "plain", or "other".
func looks(player: int) -> PackedStringArray:
	var panel: UnitChoice = units.panels[player]
	var found: PackedStringArray = []
	for slot: PanelContainer in slots(player):
		var style: StyleBox = slot.get_theme_stylebox(&"panel")
		found.append("cursor" if style == panel.cursor_style else "dim" if style == panel.dim_style
				else "plain" if style == panel.slot_style else "other")
	return found


## How the text of each slot of a Player's choice panel is coloured: "normal" or "dim" when both of
## its labels wear the panel's normal_font_color or dim_font_color, else "other".
func fonts(player: int) -> PackedStringArray:
	var panel: UnitChoice = units.panels[player]
	var found: PackedStringArray = []
	for slot: PanelContainer in slots(player):
		var colors: Array[Color] = []
		for path: NodePath in [^"Lines/NameLabel", ^"Lines/CountLabel"]:
			colors.append((slot.get_node(path) as Label).get_theme_color(&"font_color"))
		found.append("normal" if colors == [panel.normal_font_color, panel.normal_font_color]
				else "dim" if colors == [panel.dim_font_color, panel.dim_font_color] else "other")
	return found


## The Round-over screen of a Player's view as text: its winner line and its restart line, or an
## empty array while the screen is hidden (the screen is a child of that Player's SubViewport).
func over_lines(player: int) -> PackedStringArray:
	for node: Node in (units.cameras[player].get_viewport() as SubViewport).get_children():
		if node is RoundOverScreen and (node as RoundOverScreen).visible:
			return PackedStringArray([(node.find_child("WinnerLabel", true, false) as Label).text,
					(node.find_child("RestartLabel", true, false) as Label).text])
	return PackedStringArray()


## Everything a Token can change, read now: the physics frame, counts(), both HUD lines, both
## panels' count lines, looks() and fonts(), the Map's stock counts, each Player's cursor and chosen
## type, whether each is alive and choosing, and the Round (over, winner, the tree paused).
func state() -> Dictionary:
	var shared: TokenStock = harness.split.field.token_stock
	var players: Array[int] = Kit.PLAYERS
	return {"frame": Engine.get_physics_frames(), "counts": counts(), "hud": [hud_line(0), hud_line(1)],
		"panels": [panel_counts(0), panel_counts(1)], "stock": counts_copy(shared) if shared != null else {},
		"looks": [looks(0), looks(1)], "fonts": [fonts(0), fonts(1)],
		"cursor": players.map(func(p: int) -> int: return units.panels[p].choice_input.cursor),
		"chosen": players.map(func(p: int) -> int: return controller.chosen_type_index(p)),
		"alive": players.map(func(p: int) -> bool: return controller.is_alive(p)),
		"choosing": players.map(func(p: int) -> bool: return controller.is_choosing(p)),
		"over": controller.is_round_over(), "winner": controller.winner_index(), "paused": harness.get_tree().paused}


## True when a state() shows exactly what `rows` say: the counts, each Player's HUD line for its
## carrier count and each Player's panel count lines.
func shows(seen: Dictionary, rows: Array) -> bool:
	var carrier: int = carrier_index()
	for player: int in Kit.PLAYERS:
		if (carrier < 0 or seen.get("hud", ["", ""])[player] != hud_text(player, rows[player][carrier])
				or seen.get("panels", [PackedStringArray(), PackedStringArray()])[player] != count_texts(player, rows[player])):
			return false
	return seen.get("counts") == rows


## The recorded events of one kind from index `since` on (an earlier events.size() marks a point).
func events_of(kind: StringName, since: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index: int in range(since, events.size()):
		if events[index]["kind"] == kind:
			found.append(events[index])
	return found


## Waits, at most 60 ticks, for an event of the kind after index `since`, then two ticks more so its
## later reading is filed: true when it arrived.
func wait_for(kind: StringName, since: int) -> bool:
	for _wait: int in 60:
		if events_of(kind, since).is_empty():
			await kit.tick()
	await kit.advance(2)
	return not events_of(kind, since).is_empty()


## Player `player` chooses the type at type_index with its real keys: the steer-right key until the
## cursor is on it (it skips types with no Token, so it may never get there), then the fire key; two
## ticks pass after each press. True when the controller accepted the choice (unit_chosen).
func choose(player: int, type_index: int) -> bool:
	var input: PlayerChoiceInput = units.panels[player].choice_input
	for _step: int in controller.unit_types().size():
		if input.cursor != type_index:
			await kit.press_settled(keys(&"next", player))
	var before: int = units.chosen.size()
	if input.cursor == type_index:
		await kit.press_settled(keys(&"fire", player))
	return units.chosen.size() > before


## choose(), then waits until the Unit is in play: true when it is, within the respawn delay and
## the check kit's slack.
func spawn(player: int, type_index: int) -> bool:
	var limit: int = harness.ticks_in(controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	return await choose(player, type_index) and await units.wait_alive(player, limit) >= 0


## The Player's Self-destruct by its real key, two ticks (a key acts one step after it is set).
func destruct(player: int) -> void:
	await kit.press_settled(keys(&"destruct", player))


## The restart key (R), two ticks: true when a round_started arrived.
func restart() -> bool:
	var started: int = events_of(&"started").size()
	await kit.press_settled([KEY_R] as Array[Key])
	return events_of(&"started").size() > started


## Puts both Units in play 10 m apart on the middle of Map 01 (x = -5 and +5, facing each other),
## waits for them to settle and leaves the `victim` Player's Unit at 1 hit point: one Shot kills it.
func stage_duel(victim: int) -> void:
	for player: int in Kit.PLAYERS:
		var facing: Vector3 = Vector3.RIGHT if player == 0 else Vector3.LEFT
		harness.place(units.units[player], units.pose(Vector3(-5.0 + 10.0 * player, 0.0, 0.0), facing), units.cameras[player])
	await kit.advance(Units.SETTLE_TICKS + 15)
	units.units[victim].apply_damage(units.units[victim].hit_points - 1.0)


## `shooter` fires one Shot with its real fire key: the physics frame its node was added in, or -1.
func shoot(shooter: int) -> int:
	var before: int = shot_frames.size()
	await units.hold_fire(shooter, 1)
	for _wait: int in 10:
		if shot_frames.size() > before:
			return shot_frames[before]
		await kit.tick()
	return -1


## Waits until physics frame `frame`, then presses `keys` (may be empty) and waits two ticks.
func press_on(frame: int, keys: Array[Key]) -> void:
	for _wait: int in 60:
		if Engine.get_physics_frames() < frame:
			await kit.tick()
	await kit.press_settled(keys)


## Files an event with the reading inside the handler, then the one a physics frame later.
func _note(kind: StringName, arg: int) -> void:
	var event: Dictionary = {"kind": kind, "arg": arg, "now": state(), "later": {}}
	if kind == &"destroyed" or kind == &"spawned":
		event["type"] = units.units[arg].type_id
	events.append(event)
	await harness.get_tree().physics_frame
	event["later"] = state()
