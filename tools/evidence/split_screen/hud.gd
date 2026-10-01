extends RefCounted
## Scenario hud of the split screen evidence harness (split_screen_harness.gd): the per-Player HUD
## of Story 004, read from the nodes under each Player's SubViewport and compared with what that
## Player's Unit and the MatchController say at the same moment. Three CHECK lines, every number
## measured, the texts read from the scene's exports and never typed here: the hit-point bar and
## line through three debug-key hits and the one that destroys the Unit (AC-7); the canister status
## line of BOTH Players in four situations of one canister run: at home, stolen, dropped, carried
## back by its owner (AC-7); and the layout, every element inside its 640 x 720 view with
## a margin and every stored text inside its label (AC-8). Real key events (the debug key 1, W and
## the arrows); the runner's teleport only shortens canister_run's lanes. Tooling only: nothing
## under src/ depends on this file; the shared helpers are check_kit.gd and canister_kit.gd.
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-7 and AC-8.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=hud

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 004 helpers (canister_kit.gd): the signal record, the moves and the names.
const Canisters: GDScript = preload("res://tools/evidence/split_screen/canister_kit.gd")

## Player 1: takes the debug-key hits and steals canister 2.
const THIEF: int = Harness.PLAYER_1
## Player 2: owns canister 2 and recovers it.
const OWNER: int = Harness.PLAYER_2
## Debug-key hits the Unit survives before the one that destroys it (100, 75, 50, 25 with the data).
const SURVIVED_HITS: int = 3
## Least room between a HUD element and the edge of its view, pixels (AC-8).
const MARGIN_PX: float = 8.0
## Where Player 2 waits out of the lane (canister_run's spot).
const PARK_SPOT: Vector3 = Vector3(-12.0, 0.0, -8.0)
## Where the thief is destroyed (outside both zones).
const RIDE_START: Vector3 = Vector3(12.0, 0.0, 0.0)
## Toward Base 1 (+Z), the side the approaches come from.
const TO_BASE_1: Vector3 = Vector3(0.0, 0.0, 1.0)
## Toward Base 2 (-Z).
const TO_BASE_2: Vector3 = Vector3(0.0, 0.0, -1.0)

var _harness: Harness
var _kit: Kit
var _cans: Canisters
## The two HUDs by player_index, each found directly under its own Player's SubViewport.
var _huds: Array[PlayerHud] = [null, null]


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_cans = Canisters.new(harness, _kit)
	await _kit.advance(Kit.START_TICKS)
	if not _find_huds():
		_kit.verdict("hp_display", PackedStringArray(["no PlayerHud with player_index 0 and 1 under the SubViewports"]), "huds=%s" % [_huds])
		_harness.finish("reason=no_huds")
		return
	await _check_hp_display()
	await _check_canister_status_display()
	_check_fits_view()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("picked_up=%d dropped=%d seated=%d spawned=%d" % [
		_cans.pick_ups.size(), _cans.drops.size(), _cans.seats.size(), _cans.spawns.size()])


## AC-7: both HUDs show their Unit's hit points (bar value and maximum, line numbers) at the start;
## through SURVIVED_HITS presses of Player 1's debug key they fall by rules.debug_damage on Player
## 1's HUD only; the press that destroys the Unit shows zero.
func _check_hp_display() -> void:
	_harness.phase = &"hp_display"
	var problems: PackedStringArray = []
	var thief: Unit = _cans.units[THIEF]
	var max_hp: float = thief.stats.max_hit_points
	var damage: float = _cans.controller.rules.debug_damage
	var presses_max: int = ceili(max_hp / damage) if damage > 0.0 else 0
	var steps: PackedStringArray = ["start: " + _read_hit_points(max_hp, max_hp, problems, "start")]
	for count: int in range(1, SURVIVED_HITS + 1):
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
		steps.append("hit %d: %s" % [count, _read_hit_points(max_hp - float(count) * damage, max_hp, problems, "hit %d" % count)])
	var more: int = 0
	while thief.is_alive and more < presses_max:
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
		more += 1
	_kit.need(problems, not thief.is_alive, "the thief survived %d more presses" % more)
	steps.append("destroyed by %d more: %s" % [more, _read_hit_points(0.0, max_hp, problems, "destroyed")])
	_harness.print_progress()
	_kit.verdict("hp_display", problems, "max_hit_points=%.1f (%s) debug_damage=%.1f (match_rules.tres) | %s" % [
		max_hp, thief.stats.resource_path.get_file(), damage, " | ".join(steps)])


## Reads both HUDs' bars and lines against their Units, which must hold the expected hit points.
func _read_hit_points(expected_thief: float, expected_owner: float, problems: PackedStringArray, label: String) -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var hud: PlayerHud = _huds[player]
		var unit: Unit = _cans.units[player]
		var bar: ProgressBar = hud.find_child("HitPointsBar", true, false) as ProgressBar
		var line: Label = hud.find_child("HitPointsLabel", true, false) as Label
		var max_hp: float = unit.stats.max_hit_points
		var expected: float = expected_thief if player == THIEF else expected_owner
		var text: String = hud.tr(hud.hit_points_format) % [ceili(unit.hit_points), ceili(max_hp)]
		var shown: bool = is_equal_approx(bar.value, unit.hit_points) and is_equal_approx(bar.max_value, max_hp) and line.text == text
		_kit.need(problems, is_equal_approx(unit.hit_points, expected) and shown,
			"%s: player_%d's HUD does not show %.1f of %.1f" % [label, player + 1, expected, max_hp])
		parts.append("p%d unit=%.1f/%.1f (expected %.1f) bar=%.1f/%.1f line=\"%s\"" % [
			player + 1, unit.hit_points, max_hp, expected, bar.value, bar.max_value, line.text])
	return " ".join(parts)


## AC-7: each Player's status line equals the text the scene stores for the status the controller
## reports, in four situations: both at home; canister 2 stolen (the thief carrying, the owner
## away); dropped at the wreck (the owner away, the thief home); carried back by its owner (still
## away). Each situation also has to be the one the run meant. It first waits out the thief's
## respawn after the hit-point check, then parks the owner and puts the thief down SETTLE_TICKS
## later (a Unit put down beside a spot another Unit just left is thrown off it).
func _check_canister_status_display() -> void:
	_harness.phase = &"canister_status"
	var problems: PackedStringArray = []
	var canister: WaterCanister = _cans.canisters[OWNER]
	var home: int = MatchController.CanisterStatus.OWN_AT_HOME
	var away: int = MatchController.CanisterStatus.OWN_AWAY
	var carrying: int = MatchController.CanisterStatus.CARRYING_ENEMY
	await _kit.advance(_harness.ticks_in(_cans.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS)
	var moments: PackedStringArray = [_read_status("at_home", [home, home] as Array[int], problems)]
	await _kit.advance(Harness.SETTLE_TICKS)
	_cans.teleport(OWNER, PARK_SPOT, TO_BASE_1)
	await _kit.advance(Harness.SETTLE_TICKS)
	_cans.approach(THIEF, canister.global_position, TO_BASE_1)
	var steal: int = await _cans.drive_until(THIEF, 1, Canisters.APPROACH_SPEED,
		func() -> bool: return canister.carrier == _cans.units[THIEF])
	_kit.need(problems, steal > 0, "the thief never picked up canister 2")
	moments.append(_read_status("stolen", [carrying, away] as Array[int], problems))
	await _cans.rest(THIEF)
	_cans.teleport(THIEF, RIDE_START, TO_BASE_2)
	var damage: float = _cans.controller.rules.debug_damage
	var presses: int = ceili(_cans.units[THIEF].stats.max_hit_points / damage) if damage > 0.0 else 0
	for _press: int in presses:
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
	_kit.need(problems, canister.state == WaterCanister.State.DROPPED, "canister 2 did not drop at the wreck")
	moments.append(_read_status("dropped", [home, away] as Array[int], problems))
	_cans.approach(OWNER, canister.global_position, TO_BASE_1)
	var recovery: int = await _cans.drive_until(OWNER, 1, Canisters.APPROACH_SPEED,
		func() -> bool: return canister.carrier == _cans.units[OWNER])
	_kit.need(problems, recovery > 0, "the owner never picked up its dropped canister")
	moments.append(_read_status("carried_back", [home, away] as Array[int], problems))
	_harness.print_progress()
	var hud: PlayerHud = _huds[THIEF]
	_kit.verdict("canister_status_display", problems, "texts (player_hud.tscn): home=\"%s\" away=\"%s\" carrying=\"%s\" | %s" % [
		hud.home_text, hud.away_text, hud.carrying_text, " | ".join(moments)])


## Reads both status lines against the controller's status, which must be the situation's own.
func _read_status(moment: String, expected: Array[int], problems: PackedStringArray) -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var hud: PlayerHud = _huds[player]
		var status: int = _cans.controller.canister_status(player)
		var shown: String = (hud.find_child("CanisterStatusLabel", true, false) as Label).text
		var matches: bool = shown == _text_for(hud, status)
		var wanted: String = MatchController.CanisterStatus.keys()[expected[player]]
		_kit.need(problems, status == expected[player] and matches,
			"%s: player_%d's status is not %s, or its line is not the scene's text for it" % [moment, player + 1, wanted])
		parts.append("p%d status=%s (expected %s) line=\"%s\"" % [player + 1, _cans.status_name(player), wanted, shown])
	return "%s (canister_1=%s canister_2=%s): %s" % [moment, _cans.state_name(0), _cans.state_name(1), " ".join(parts)]


## The text the scene stores on the HUD for a CanisterStatus value, through the HUD's own tr().
func _text_for(hud: PlayerHud, status: int) -> String:
	if status == MatchController.CanisterStatus.CARRYING_ENEMY:
		return hud.tr(hud.carrying_text)
	if status == MatchController.CanisterStatus.OWN_AWAY:
		return hud.tr(hud.away_text)
	return hud.tr(hud.home_text)


## AC-8: each HUD's root is exactly its Player's view (640 x 720), every element lies inside the
## view by MARGIN_PX or more, and no label text (shown or any stored status text) is wider than it.
func _check_fits_view() -> void:
	_harness.phase = &"fits_view"
	var problems: PackedStringArray = []
	var readings: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		readings.append(_read_layout(player, problems))
	_kit.verdict("fits_view", problems, "window=%dx%d margin_min=%.0f px | %s" % [
		_harness.get_window().size.x, _harness.get_window().size.y, MARGIN_PX, " | ".join(readings)])


## Reads one HUD's layout: its root against its view, each element's rect against the view shrunk
## by MARGIN_PX, each label's widest text against its width and the lines it shows. The rectangles.
func _read_layout(player: int, problems: PackedStringArray) -> String:
	var hud: PlayerHud = _huds[player]
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2((_cans.cameras[player].get_viewport() as SubViewport).size))
	var inner: Rect2 = view.grow(-MARGIN_PX)
	var root_is_view: bool = hud.get_global_rect().is_equal_approx(view)
	_kit.need(problems, root_is_view, "player_%d's HUD root is not its view" % (player + 1))
	var parts: PackedStringArray = ["view=%s root=%s root_is_view=%s" % [_rect(view), _rect(hud.get_global_rect()), root_is_view]]
	var lowest: float = 0.0
	for child: Node in hud.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		var rect: Rect2 = control.get_global_rect()
		var inside: bool = inner.encloses(rect) and control.is_visible_in_tree()
		lowest = maxf(lowest, rect.end.y)
		_kit.need(problems, inside, "player_%d's %s is outside its view's margin, or hidden" % [player + 1, control.name])
		var note: String = ""
		var label: Label = control as Label
		if label != null:
			var widest: float = 0.0
			for text: String in _texts_of(hud, label):
				widest = maxf(widest, _text_width(label, text))
			var fits: bool = widest <= label.size.x and label.get_line_count() == 1
			_kit.need(problems, fits, "player_%d's %s text is wider than the label, or wraps" % [player + 1, label.name])
			note = " widest_text=%.0f of %.0f px lines=%d" % [widest, label.size.x, label.get_line_count()]
		parts.append("%s=%s inside_margin=%s%s" % [control.name, _rect(rect), inside, note])
	parts.append("lowest_edge_y=%.0f" % lowest)
	return "player_%d: %s" % [player + 1, " ".join(parts)]


## The texts a label must hold: the one it shows and, for the status line, every stored status text.
func _texts_of(hud: PlayerHud, label: Label) -> PackedStringArray:
	var texts: PackedStringArray = [label.text]
	if label.name == "CanisterStatusLabel":
		texts.append(hud.tr(hud.home_text))
		texts.append(hud.tr(hud.away_text))
		texts.append(hud.tr(hud.carrying_text))
	return texts


## The width the label's font draws the text at, pixels.
func _text_width(label: Label, text: String) -> float:
	return label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x


## Files each PlayerHud that sits directly under its own Player's SubViewport, by player_index.
func _find_huds() -> bool:
	for player: int in Kit.PLAYERS:
		for node: Node in (_cans.cameras[player].get_viewport() as SubViewport).get_children():
			if node is PlayerHud and (node as PlayerHud).player_index == player:
				_huds[player] = node as PlayerHud
	return _huds[0] != null and _huds[1] != null


## A rect as "(x,y wxh)", whole pixels.
func _rect(rect: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
