extends RefCounted
## Scenario countdown of the split screen evidence harness (split_screen_harness.gd): AC-6 of Story 003,
## while a Player waits to respawn their own viewport shows the seconds remaining. Played with real key
## events (Tab and Enter, the Self-destruct keys) and judged by comparing what each RespawnCountdown
## label shows with what the MatchController says about the same Player: whether it is visible, its
## text, the whole numbers it shows in turn and for how many ticks, and where it sits in its viewport.
## Nine CHECK lines, every number measured, one of them reading the text under another format (the text is
## data, not a literal). The delay is read from the match rules, never assumed. The readings are in
## countdown_trace.gd and their judgement (numbers, layout) in countdown_audit.gd.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-6 (while a
## Player is waiting to respawn, their viewport shows the seconds remaining). Tooling only: nothing
## under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=countdown

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The readings (countdown_trace.gd).
const Trace: GDScript = preload("res://tools/evidence/split_screen/countdown_trace.gd")
## Their judgement (countdown_audit.gd).
const Audit: GDScript = preload("res://tools/evidence/split_screen/countdown_audit.gd")

## Ticks of each quiet stretch: no key pressed, before a destruction and after the respawn.
const QUIET_TICKS: int = 30
## Ticks waited after a key press before a label's layout is read, so the label is shown.
const LAYOUT_TICKS: int = 2
## Where the second Player's destruction falls in the staggered phase, as a fraction of the delay.
const STAGGER_FRACTION: float = 0.5
## A countdown format other than the scene's, with one placeholder: the text must follow the data.
const FORMAT_OTHER: String = "Wait %d"

var _harness: Harness
var _kit: Kit
var _trace: Trace
var _audit: Audit
var _split: SplitScreen
var _controller: MatchController
## The two labels, by the player_index each carries.
var _labels: Array[RespawnCountdown] = [null, null]
## The distinct texts Player 1's label showed while the format check ran, in order.
var _format_texts: PackedStringArray = []


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_split = _harness.split
	_controller = _split.match_controller
	await _harness.advance_ticks(Kit.START_TICKS)
	if not _check_labels_exist():
		_harness.finish("reason=no_labels")
		return
	_trace = Trace.new(harness, _labels)
	_audit = Audit.new(harness, _kit, _trace, _labels)
	_kit.on_tick = _trace.on_tick
	_trace.add_probe()
	await _check_hidden_while_alive()
	await _check_single(Harness.PLAYER_1, Kit.KEYS_DESTRUCT_1)
	await _check_single(Harness.PLAYER_2, Kit.KEYS_DESTRUCT_2)
	await _check_both_destroyed()
	await _check_staggered()
	await _check_format_is_data()
	_audit.check_label_layout()
	_audit.check_mouse_filter()
	_harness.phase = &"end"
	_harness.print_progress()
	_trace.remove_probe()
	_harness.finish("delay_seconds=%.3f delay_ticks=%d tick_readings=%d frame_readings=%d" % [
		_controller.rules.respawn_delay_seconds, _delay_ticks(), _trace.tick_total, _trace.frame_total])


## The respawn delay in physics ticks, by the runner's rule (round, at least one).
func _delay_ticks() -> int:
	return _harness.ticks_in(_controller.rules.respawn_delay_seconds)


## Ticks until every listed Player has been seen waiting and is alive again. Returns false when the
## limit passes first.
func _until_respawned(players: Array[int]) -> bool:
	var destroyed: Dictionary[int, bool] = {}
	var limit: int = 2 * _delay_ticks() + Kit.RESPAWN_SLACK_TICKS
	while limit > 0:
		await _kit.tick()
		limit -= 1
		if _all_back(players, destroyed):
			return true
	return false


## Notes which listed Players are waiting and tells whether every one that was seen waiting is alive again.
func _all_back(players: Array[int], destroyed: Dictionary[int, bool]) -> bool:
	var back: int = 0
	for player: int in players:
		if not _controller.is_alive(player):
			destroyed[player] = true
		elif destroyed.has(player):
			back += 1
	return back == players.size()


## What the labels' own tree says: two RespawnCountdown nodes, each directly under a different
## SubViewport, the one its Player's camera is in, each reading this scene's MatchController. Fills
## _labels by player_index. Returns whether the rest can run.
func _check_labels_exist() -> bool:
	var found: Array[RespawnCountdown] = []
	for node: Node in _harness.get_tree().root.find_children("*", "", true, false):
		if node is RespawnCountdown:
			found.append(node as RespawnCountdown)
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	var parents: Array[Node] = []
	_kit.need(problems, found.size() == 2, "%d RespawnCountdown nodes in the tree, expected 2" % found.size())
	for label: RespawnCountdown in found:
		parents.append(label.get_parent())
		detail.append(_inspect_label(label, problems))
	var distinct: bool = parents.size() == 2 and parents[0] != parents[1]
	_kit.need(problems, distinct, "the two labels share one parent")
	_kit.verdict("labels_exist", problems, "labels_in_tree=%d | %s | different_viewports=%s" % [
		found.size(), " | ".join(detail), distinct])
	return problems.is_empty() and _labels[0] != null and _labels[1] != null


## Files one label by its player_index and judges where it sits: directly under the SubViewport of its own
## Player's camera, reading this scene's MatchController, with a format. Adds to problems and returns the
## numbers.
func _inspect_label(label: RespawnCountdown, problems: PackedStringArray) -> String:
	var parent: Node = label.get_parent()
	var index: int = label.player_index
	var own_view: bool = false
	if index >= 0 and index < _labels.size():
		_kit.need(problems, _labels[index] == null, "two labels carry player_index %d" % index)
		_labels[index] = label
		var camera: ChaseCamera = _split.player_1_camera if index == 0 else _split.player_2_camera
		own_view = parent is SubViewport and camera.get_viewport() == parent
	else:
		problems.append("label '%s' has player_index %d" % [label.name, index])
	_kit.need(problems, parent is SubViewport, "label '%s' is under %s, not a SubViewport" % [label.name, parent.name])
	_kit.need(problems, own_view, "label '%s' is not in its own Player's viewport" % label.name)
	_kit.need(problems, label.match_controller == _controller, "label '%s' reads another MatchController" % label.name)
	_kit.need(problems, not label.format.is_empty(), "label '%s' has no format" % label.name)
	return "%s player_index=%d directly under %s (%s) in_own_players_viewport=%s reads_scene_controller=%s format='%s'" % [
		label.name, index, parent.name, parent.get_class(), own_view, label.match_controller == _controller, label.format]


## AC-6: with both Units alive neither label is shown, on any tick or any frame.
func _check_hidden_while_alive() -> void:
	_trace.begin()
	await _kit.advance(QUIET_TICKS)
	_trace.end()
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	_kit.need(problems, _trace.frame_log.size() > 0, "the probe took no frame readings")
	for player: int in Kit.PLAYERS:
		var seen: int = _trace.shown_ticks(player) + _trace.shown_frames(player)
		var not_alive: int = _trace.waiting_ticks(player) + _trace.waiting_frames(player)
		_kit.need(problems, seen == 0 and not_alive == 0,
			"player_%d label shown on %d readings, Unit not alive on %d" % [player + 1, seen, not_alive])
		detail.append("player_%d label shown on %d of %d tick readings and %d of %d frame readings, Unit not alive on %d" % [
			player + 1, _trace.shown_ticks(player), _trace.tick_log.size(), _trace.shown_frames(player),
			_trace.frame_log.size(), not_alive])
	_kit.verdict("hidden_while_alive", problems, " | ".join(detail))


## AC-6: one Player's Self-destruct key. That Player's label counts the wait down and is gone after
## the respawn; the other Player's label is never shown. Also reads the label's layout while shown.
func _check_single(player: int, keys: Array[Key]) -> void:
	var other: int = 1 - player
	_trace.begin()
	await _kit.advance(QUIET_TICKS)
	await _kit.press(keys)
	await _kit.advance(LAYOUT_TICKS)
	_audit.read_layout(player)
	var back: bool = await _until_respawned([player] as Array[int])
	await _kit.advance(QUIET_TICKS)
	_trace.end()
	var problems: PackedStringArray = []
	_kit.need(problems, back, "player_%d never respawned" % (player + 1))
	var detail: String = _audit.audit(player, problems)
	var other_seen: int = _trace.shown_ticks(other) + _trace.shown_frames(other)
	_kit.need(problems, other_seen == 0 and _trace.waiting_ticks(other) == 0,
		"player_%d label shown on %d readings while only player_%d was destroyed" % [other + 1, other_seen, player + 1])
	_kit.verdict("player_%d_countdown" % (player + 1), problems,
		"%s | player_%d label shown on %d of %d tick readings and %d of %d frame readings" % [
			detail, other + 1, _trace.shown_ticks(other), _trace.tick_log.size(), _trace.shown_frames(other), _trace.frame_log.size()])


## AC-6: both Self-destruct keys in the same tick. Both labels count their own wait at once and both are
## gone after the respawns.
func _check_both_destroyed() -> void:
	_trace.begin()
	await _kit.advance(QUIET_TICKS)
	await _kit.press(Kit.KEYS_DESTRUCT_BOTH)
	var back: bool = await _until_respawned(Kit.PLAYERS)
	await _kit.advance(QUIET_TICKS)
	_trace.end()
	var problems: PackedStringArray = []
	_kit.need(problems, back, "a Player never respawned")
	var together: int = _trace.together()
	_kit.need(problems, absi(together - _delay_ticks()) <= Kit.TICK_SLACK,
		"both labels were shown together for %d ticks, not the delay's %d" % [together, _delay_ticks()])
	var details: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		details.append(_audit.audit(player, problems))
	_kit.verdict("both_destroyed", problems, "both labels shown together on %d tick readings | %s" % [together, " | ".join(details)])


## AC-6: two destructions a fraction of the delay apart. The labels are independent: each counts its own
## Player's wait, the two show different numbers at the same time, and the first is gone while the
## second still counts.
func _check_staggered() -> void:
	_trace.begin()
	await _kit.advance(QUIET_TICKS)
	await _kit.press(Kit.KEYS_DESTRUCT_1)
	await _kit.advance(maxi(roundi(STAGGER_FRACTION * float(_delay_ticks())), 1))
	await _kit.press(Kit.KEYS_DESTRUCT_2)
	var back: bool = await _until_respawned(Kit.PLAYERS)
	await _kit.advance(QUIET_TICKS)
	_trace.end()
	var problems: PackedStringArray = []
	_kit.need(problems, back, "a Player never respawned")
	var differing: int = _trace.differing()
	var first_gone: int = _trace.first_gone()
	_kit.need(problems, differing > 0, "the two labels never showed different numbers at once")
	_kit.need(problems, first_gone > 0, "Player 1's label was never gone while Player 2's still counted")
	var details: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		details.append(_audit.audit(player, problems))
	_kit.verdict("staggered", problems, ("second destruction %.3f of the delay after the first | both shown with different numbers on %d "
		+ "tick readings | first gone while second counts on %d | %s") % [STAGGER_FRACTION, differing, first_gone, " | ".join(details)])


## AC-6: the countdown text is data. With another format on Player 1's label the countdown reads that text,
## once for each whole second of the delay, counting down (a literal in the script would show), and the
## scene's format is put back afterwards.
func _check_format_is_data() -> void:
	var label: RespawnCountdown = _labels[Harness.PLAYER_1]
	var original: String = label.format
	var previous: Callable = _kit.on_tick
	_format_texts = PackedStringArray()
	label.format = FORMAT_OTHER
	_kit.on_tick = _note_format_text
	await _kit.press(Kit.KEYS_DESTRUCT_1)
	var back: bool = await _until_respawned([Harness.PLAYER_1] as Array[int])
	await _kit.advance(QUIET_TICKS)
	_kit.on_tick = previous
	label.format = original
	var expected: PackedStringArray = []
	for seconds: int in range(ceili(_controller.rules.respawn_delay_seconds), 0, -1):
		expected.append(FORMAT_OTHER % seconds)
	var problems: PackedStringArray = []
	_kit.need(problems, back, "player_1 never respawned")
	_kit.need(problems, _format_texts == expected,
		"the label showed [%s], expected [%s]" % [", ".join(_format_texts), ", ".join(expected)])
	_kit.need(problems, label.format == original and not label.visible, "the format was not put back or the label is still shown")
	_kit.verdict("format_is_data", problems, "format '%s' instead of '%s': the label showed [%s] (expected [%s])" % [
		FORMAT_OTHER, original, ", ".join(_format_texts), ", ".join(expected)])


## Notes the text Player 1's label shows, when it is shown and it is not the text noted last.
func _note_format_text() -> void:
	var label: RespawnCountdown = _labels[Harness.PLAYER_1]
	if label.visible and (_format_texts.is_empty() or _format_texts[_format_texts.size() - 1] != label.text):
		_format_texts.append(label.text)
