extends RefCounted
## Scenario round_over of the split screen evidence harness (split_screen_harness.gd): the
## Round-over screen and the restart of Story 004. Player 2 steals canister 1 and delivers it (the
## other winner than canister_run's); both views are then read from the nodes under each SubViewport
## against the MatchController: the Round-over screen shown in both, its winner line from the
## scene's format, its restart line naming the key the Input Map binds to round_restart, its panel
## inside the view and at most 520 px wide, HUDs and countdowns still right (overlay_shown); the
## restart key puts both Units and canisters back at full hit points, hides the overlays, resets the
## HUD lines, the Round running and the tree unpaused (restart_resets); and the restart key during a
## running Round changes nothing (restart_ignored_while_running). Three CHECK lines, every number
## measured, real key events. Tooling only: nothing under src/ depends on this file.
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-6 and AC-8.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=round_over

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 004 helpers (canister_kit.gd): the signal record, the moves and the names.
const Canisters: GDScript = preload("res://tools/evidence/split_screen/canister_kit.gd")

## Player 2: steals canister 1 and delivers it, the winner.
const WINNER: int = Harness.PLAYER_2
## Player 1: parked, hit once, the loser.
const LOSER: int = Harness.PLAYER_1
## The restart key: project.godot binds round_restart to it (only tools name key codes).
const KEYS_RESTART: Array[Key] = [KEY_R]
## Ticks waited after the win before the overlay is read, so its panel is laid out.
const LAYOUT_TICKS: int = 2
## Least room between the panel and the edge of its view, pixels (AC-8).
const MARGIN_PX: float = 8.0
## The panel's widest, pixels (AC-8).
const PANEL_MAX_WIDTH: float = 520.0
## A seated canister stands within this of its seat, metres.
const PLACE_TOLERANCE: float = 0.05
## Where Player 1 waits (canister_run's park spot mirrored).
const PARK_SPOT: Vector3 = Vector3(-12.0, 0.0, 8.0)
## Where Player 2's run home starts, 8 m short of Base 2's zone.
const BASE_2_RUN_START: Vector3 = Vector3(0.0, 0.0, -6.0)
## Toward Base 1 (+Z).
const TO_BASE_1: Vector3 = Vector3(0.0, 0.0, 1.0)
## Toward Base 2 (-Z).
const TO_BASE_2: Vector3 = Vector3(0.0, 0.0, -1.0)

var _harness: Harness
var _kit: Kit
var _cans: Canisters
## The screens by Player, each found directly under its own Player's SubViewport.
var _huds: Array[PlayerHud] = [null, null]
var _overs: Array[RoundOverScreen] = [null, null]
var _countdowns: Array[RespawnCountdown] = [null, null]


## Runs the scenario in CHECK order, except the last check's first half (the key in Round one).
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_cans = Canisters.new(harness, _kit)
	await _kit.advance(Kit.START_TICKS)
	if not _find_screens():
		_kit.verdict("overlay_shown", PackedStringArray(["a screen is missing under a SubViewport"]),
			"huds=%s round_over_screens=%s countdowns=%s" % [_huds, _overs, _countdowns])
		_harness.finish("reason=screens_missing")
		return
	var ignored: PackedStringArray = []
	var first: String = await _press_restart_while_running("first Round", ignored)
	await _kit.press_settled(Kit.KEYS_DEBUG_1)
	await _check_overlay_shown()
	await _check_restart_resets()
	var second: String = await _press_restart_while_running("new Round", ignored)
	_kit.verdict("restart_ignored_while_running", ignored, first + " | " + second)
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("round_over=%d winner=%d round_started=%d spawned=%d restart_key=%s" % [
		_cans.round_overs.size(), _cans.round_overs[0].x if not _cans.round_overs.is_empty() else MatchController.NO_WINNER,
		_cans.round_started, _cans.spawns.size(), _restart_key_name()])


## AC-6, AC-8: Player 2 steals canister 1 and runs it into its own Base zone; after LAYOUT_TICKS
## both Round-over screens show the winner line for Player 2 and the restart line naming the bound
## key, each panel inside its view by MARGIN_PX and at most PANEL_MAX_WIDTH wide, both lines on one
## line; both HUDs still right (Player 1's one hit, the status texts), both countdowns hidden.
func _check_overlay_shown() -> void:
	_harness.phase = &"overlay_shown"
	var problems: PackedStringArray = []
	var canister: WaterCanister = _cans.canisters[LOSER]
	_cans.teleport(LOSER, PARK_SPOT, TO_BASE_2)
	await _kit.advance(Harness.SETTLE_TICKS)
	_cans.approach(WINNER, canister.global_position, TO_BASE_2)
	var steal: int = await _cans.drive_until(WINNER, 1, Canisters.APPROACH_SPEED,
		func() -> bool: return canister.carrier == _cans.units[WINNER])
	_kit.need(problems, steal > 0, "Player 2 never picked up canister 1")
	await _cans.rest(WINNER)
	_cans.teleport(WINNER, BASE_2_RUN_START, TO_BASE_2)
	var run_ticks: int = await _cans.drive_until(WINNER, 1, Canisters.APPROACH_SPEED,
		func() -> bool: return not _cans.round_overs.is_empty())
	await _kit.advance(LAYOUT_TICKS)
	var controller: MatchController = _cans.controller
	var paused: bool = _harness.get_tree().paused
	var won: bool = run_ticks > 0 and controller.is_round_over() and controller.winner_index() == WINNER and paused
	_kit.need(problems, won, "Player 2's delivery did not end the Round with the tree paused")
	var key_name: String = _restart_key_name()
	var bound: bool = _bound_restart_key() == KEYS_RESTART[0]
	_kit.need(problems, not key_name.is_empty() and bound, "round_restart is unbound, or bound to another key than the one pressed")
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		parts.append(_read_overlay(player, key_name, problems))
		parts.append(_read_hud(player, problems))
	_harness.print_progress()
	_kit.verdict("overlay_shown", problems, ("delivery by player_%d: steal after %d ticks, run %d ticks, round_over=%d "
		+ "is_round_over=%s winner_index=%d paused=%s | restart key from the Input Map: %s (bound to the key pressed: %s) | %s") % [
			WINNER + 1, steal, run_ticks, _cans.round_overs.size(), controller.is_round_over(), controller.winner_index(), paused,
			key_name, bound, " | ".join(parts)])


## AC-6: with the Round over, the restart key: the Round running with no winner, the tree unpaused,
## round_started once more and unit_spawned once per Player, each Unit on its spawn point at full
## hit points, each canister AT_HOME on its seat, each overlay hidden, each HUD and countdown right.
func _check_restart_resets() -> void:
	_harness.phase = &"restart_resets"
	var problems: PackedStringArray = []
	var controller: MatchController = _cans.controller
	var started: int = _cans.round_started
	var spawned: int = _cans.spawns.size()
	await _kit.press_settled(KEYS_RESTART)
	await _kit.advance(Kit.TICK_SLACK)
	var running: bool = (not controller.is_round_over() and controller.winner_index() == MatchController.NO_WINNER
		and not _harness.get_tree().paused and _cans.round_started == started + 1 and _cans.spawns.size() == spawned + Kit.PLAYERS.size())
	_kit.need(problems, running, "the restart key did not start a new Round")
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		parts.append(_read_reset(player, problems))
		parts.append(_read_hud(player, problems))
	_harness.print_progress()
	_kit.verdict("restart_resets", problems, ("restart key: is_round_over=%s winner_index=%d paused=%s round_started=%d (before %d) "
		+ "unit_spawned=%d (before %d) | %s") % [controller.is_round_over(), controller.winner_index(), _harness.get_tree().paused,
			_cans.round_started, started, _cans.spawns.size(), spawned, " | ".join(parts)])


## Reads one Player after the restart: Unit alive on its spawn point at full hit points, canister
## AT_HOME on its seat, overlay hidden, status OWN_AT_HOME.
func _read_reset(player: int, problems: PackedStringArray) -> String:
	var unit: Unit = _cans.units[player]
	var base: Base = _cans.bases[player]
	var canister: WaterCanister = _cans.canisters[player]
	var home: float = unit.global_position.distance_to(base.spawn_point.global_position)
	var seat: float = canister.global_position.distance_to(base.canister_seat.global_position)
	var status: int = _cans.controller.canister_status(player)
	var reset: bool = (unit.is_alive and is_equal_approx(unit.hit_points, unit.stats.max_hit_points)
		and home <= Kit.SPAWN_TOLERANCE and canister.state == WaterCanister.State.AT_HOME and seat <= PLACE_TOLERANCE
		and not _overs[player].visible and status == MatchController.CanisterStatus.OWN_AT_HOME)
	_kit.need(problems, reset, "player_%d was not reset" % (player + 1))
	return "p%d base_error=%.4f (max %.2f) alive=%s hp=%.1f/%.1f canister_%d=%s seat_error=%.4f (max %.2f) status=%s overlay_visible=%s" % [
		player + 1, home, Kit.SPAWN_TOLERANCE, unit.is_alive, unit.hit_points, unit.stats.max_hit_points, player + 1,
		_cans.state_name(player), seat, PLACE_TOLERANCE, _cans.status_name(player), _overs[player].visible]


## Presses the restart key with the Round running and reads what changed: nothing may (the Round
## still running, nothing spawned, nothing started, the world the same). The readings, labelled.
func _press_restart_while_running(label: String, problems: PackedStringArray) -> String:
	var before: String = _world_state()
	var started: int = _cans.round_started
	var spawned: int = _cans.spawns.size()
	await _kit.press_settled(KEYS_RESTART)
	await _kit.advance(Kit.TICK_SLACK)
	var after: String = _world_state()
	var controller: MatchController = _cans.controller
	var unchanged: bool = (after == before and _cans.round_started == started and _cans.spawns.size() == spawned
		and not controller.is_round_over() and not _harness.get_tree().paused and not _overs[0].visible and not _overs[1].visible)
	_kit.need(problems, unchanged, label + ": the restart key changed something while the Round ran")
	return "%s: unchanged=%s round_started=%d (before %d) unit_spawned=%d (before %d) is_round_over=%s paused=%s overlays=%s/%s" % [
		label, unchanged, _cans.round_started, started, _cans.spawns.size(), spawned, controller.is_round_over(),
		_harness.get_tree().paused, _overs[0].visible, _overs[1].visible]


## Reads one Player's Round-over screen: shown, the winner line the scene's format for the winner,
## the restart line the scene's format for the key name, both on one line, the panel in the view.
func _read_overlay(player: int, key_name: String, problems: PackedStringArray) -> String:
	var screen: RoundOverScreen = _overs[player]
	var panel: PanelContainer = screen.find_child("Panel", true, false) as PanelContainer
	var winner_line: Label = screen.find_child("WinnerLabel", true, false) as Label
	var restart_line: Label = screen.find_child("RestartLabel", true, false) as Label
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2((_cans.cameras[player].get_viewport() as SubViewport).size))
	var rect: Rect2 = panel.get_global_rect()
	var winner_text: String = screen.tr(screen.winner_format) % (_cans.controller.winner_index() + 1)
	var restart_text: String = screen.tr(screen.restart_format) % key_name
	var inside: bool = view.grow(-MARGIN_PX).encloses(rect)
	var shown: bool = (screen.visible and panel.is_visible_in_tree() and winner_line.text == winner_text and restart_line.text == restart_text
		and winner_line.get_line_count() == 1 and restart_line.get_line_count() == 1 and inside and rect.size.x <= PANEL_MAX_WIDTH)
	_kit.need(problems, shown, "player_%d's Round-over screen is not shown as expected" % (player + 1))
	return ("p%d overlay visible=%s winner_line=\"%s\" (expected \"%s\") restart_line=\"%s\" (expected \"%s\") "
		+ "lines=%d/%d panel=(%.0f,%.0f %.0fx%.0f) inside_margin=%s width_max=%.0f") % [player + 1, screen.visible,
			winner_line.text, winner_text, restart_line.text, restart_text, winner_line.get_line_count(),
			restart_line.get_line_count(), rect.position.x, rect.position.y, rect.size.x, rect.size.y, inside, PANEL_MAX_WIDTH]


## Reads one Player's HUD and countdown: the HUD shown, its bar and line the Unit's hit points, its
## status line the scene's text for the Player's status, the countdown hidden. The readings.
func _read_hud(player: int, problems: PackedStringArray) -> String:
	var hud: PlayerHud = _huds[player]
	var unit: Unit = _cans.units[player]
	var max_hp: float = unit.stats.max_hit_points
	var bar: ProgressBar = hud.find_child("HitPointsBar", true, false) as ProgressBar
	var hp_line: Label = hud.find_child("HitPointsLabel", true, false) as Label
	var status_line: Label = hud.find_child("CanisterStatusLabel", true, false) as Label
	var hp_text: String = hud.tr(hud.hit_points_format) % [ceili(unit.hit_points), ceili(max_hp)]
	var status_text: String = _text_for(hud, _cans.controller.canister_status(player))
	var right: bool = (hud.visible and is_equal_approx(bar.value, unit.hit_points) and is_equal_approx(bar.max_value, max_hp)
		and hp_line.text == hp_text and status_line.text == status_text and not _countdowns[player].visible)
	_kit.need(problems, right, "player_%d's HUD or countdown is off" % (player + 1))
	return "p%d hud visible=%s hp_line=\"%s\" (unit %.1f/%.1f) bar=%.1f/%.1f status_line=\"%s\" (status %s) countdown_visible=%s" % [
		player + 1, hud.visible, hp_line.text, unit.hit_points, max_hp, bar.value, bar.max_value, status_line.text,
		_cans.status_name(player), _countdowns[player].visible]


## The text the scene stores on the HUD for a CanisterStatus value, through the HUD's own tr().
func _text_for(hud: PlayerHud, status: int) -> String:
	var texts: Dictionary[int, String] = {MatchController.CanisterStatus.CARRYING_ENEMY: hud.carrying_text,
		MatchController.CanisterStatus.OWN_AWAY: hud.away_text, MatchController.CanisterStatus.OWN_AT_HOME: hud.home_text}
	return hud.tr(texts[status])


## The world as one string, so two readings compare: the Units and the canisters, where and how.
func _world_state() -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var at: Vector3 = _cans.units[player].global_position
		var can: Vector3 = _cans.canisters[player].global_position
		parts.append("p%d=(%.3f, %.3f, %.3f) hp=%.1f alive=%s canister_%d=%s@(%.3f, %.3f, %.3f)" % [player + 1, at.x, at.y, at.z,
			_cans.units[player].hit_points, _cans.units[player].is_alive, player + 1, _cans.state_name(player), can.x, can.y, can.z])
	return " ".join(parts)


## The physical key the Input Map binds to round_restart (its first key event), or KEY_NONE.
func _bound_restart_key() -> Key:
	for event: InputEvent in InputMap.action_get_events(&"round_restart"):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			return key_event.physical_keycode
	return KEY_NONE


## The name of that key as the engine spells it, or an empty string when none is bound.
func _restart_key_name() -> String:
	var key: Key = _bound_restart_key()
	return OS.get_keycode_string(key) if key != KEY_NONE else ""


## Files each PlayerHud, RoundOverScreen and RespawnCountdown under its own Player's SubViewport.
func _find_screens() -> bool:
	for player: int in Kit.PLAYERS:
		for node: Node in (_cans.cameras[player].get_viewport() as SubViewport).get_children():
			if node is PlayerHud and (node as PlayerHud).player_index == player:
				_huds[player] = node as PlayerHud
			elif node is RoundOverScreen:
				_overs[player] = node as RoundOverScreen
			elif node is RespawnCountdown and (node as RespawnCountdown).player_index == player:
				_countdowns[player] = node as RespawnCountdown
	return not (_huds.has(null) or _overs.has(null) or _countdowns.has(null))
