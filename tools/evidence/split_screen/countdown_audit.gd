extends RefCounted
## Judges what the countdown scenario (countdown.gd) read (countdown_trace.gd): the whole numbers a label
## shows in turn and for how long (audit), and where each label sits in its viewport (layout) and whether
## it takes a click (mouse_filter). Tick readings judge visibility and the length of each whole number
## (Kit.TICK_SLACK); frame readings judge the text exactly, as tr(format) % ceili(seconds), on every
## rendered frame at any frame rate.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-6. Made by
## countdown.gd. Tooling only: nothing under src/ depends on this file.

## The runner, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The readings (countdown_trace.gd).
const Trace: GDScript = preload("res://tools/evidence/split_screen/countdown_trace.gd")
## One instant (countdown_sample.gd).
const Sample: GDScript = preload("res://tools/evidence/split_screen/countdown_sample.gd")
## The text's centre is within this many pixels of its viewport's centre (AC-6).
const CENTRE_TOLERANCE: float = 10.0


## One label's layout as read_layout() read it while the label was shown; measured stays false until then.
class Layout extends RefCounted:
	## Whether read_layout() has read this label at all.
	var measured: bool = false
	## Whether the label was visible in the tree when read.
	var shown: bool = false
	## The rect of the label's viewport, pixels.
	var viewport: Rect2 = Rect2()
	## The label's global rect, pixels.
	var rect: Rect2 = Rect2()
	## The size the text needs, pixels.
	var text_size: Vector2 = Vector2.ZERO
	## The label's horizontal alignment (HorizontalAlignment).
	var horizontal: int = HORIZONTAL_ALIGNMENT_LEFT
	## The label's vertical alignment (VerticalAlignment).
	var vertical: int = VERTICAL_ALIGNMENT_TOP
	## The text shown when read.
	var text: String = ""


var _harness: Harness
var _kit: Kit
var _trace: Trace
var _controller: MatchController
## The two labels, by the player_index each carries.
var _labels: Array[RespawnCountdown] = []
## Each label's layout, read while it was shown, by Player; not measured until then.
var _layouts: Array[Layout] = [Layout.new(), Layout.new()]


func _init(harness: Node, check_kit: Kit, trace: Trace, labels: Array[RespawnCountdown]) -> void:
	_harness = harness as Harness
	_kit = check_kit
	_trace = trace
	_controller = _harness.split.match_controller
	_labels = labels


## Judges one Player's label over the logs, adds what is wrong to problems and returns the numbers as a
## sentence. Tick readings: the label is shown exactly while the Player waits, for as long as the delay
## says, and shows the whole numbers in turn, each for its share of the delay (Kit.TICK_SLACK). Frame
## readings: the label is shown exactly while the Player waits and its text is what the controller's
## seconds make, on every frame.
func audit(player: int, problems: PackedStringArray) -> String:
	var tag: String = "player_%d" % (player + 1)
	var ticks: Dictionary[String, Variant] = _read_ticks(player)
	var frames: Dictionary[String, Variant] = _read_frames(player)
	var numbers: Dictionary[String, Variant] = _compare_runs(ticks["runs"], _expected_runs(_labels[player]))
	var delay: int = _harness.ticks_in(_controller.rules.respawn_delay_seconds)
	var waiting: int = ticks["waiting"]
	var off: int = ticks["off"]
	var frames_waiting: int = frames["waiting"]
	var frames_off: int = frames["off"]
	var text_off: int = frames["text_off"]
	var first_bad: String = frames["first_bad"]
	var numbers_ok: bool = numbers["ok"]
	var shown: String = ", ".join(numbers["shown"])
	var wanted: String = ", ".join(numbers["wanted"])
	var frame_count: int = _trace.frame_log.size()
	_kit.need(problems, absi(waiting - delay) <= Kit.TICK_SLACK, "%s waited %d ticks, not the delay's %d" % [tag, waiting, delay])
	_kit.need(problems, off == 0, "%s label disagreed with the controller on %d tick readings" % [tag, off])
	_kit.need(problems, numbers_ok, "%s showed %s, expected %s" % [tag, shown, wanted])
	_kit.need(problems, frames_waiting > 0 and frames_off == 0,
		"%s label disagreed with the controller on %d of %d frame readings (%d while waiting)" % [
			tag, frames_off, frame_count, frames_waiting])
	_kit.need(problems, text_off == 0, "%s text was wrong on %d frames, first %s" % [tag, text_off, first_bad])
	return ("%s: waited %d ticks (delay %d) label_off=%d | numbers %s (expected %s, each within %d ticks) | frames=%d while_waiting=%d "
		+ "shown_off=%d text_off=%d (first bad: %s) | tick readings behind their own seconds=%d | hidden_after=%d ticks") % [
			tag, waiting, delay, off, shown, wanted, _run_slack(), frame_count, frames_waiting, frames_off, text_off, first_bad,
			_behind(player), _trace.tick_log.size() - 1 - int(ticks["last_waiting"])]


## Reads a label's layout now, while it is shown: where its rect is, how big its viewport is, how big its
## text is and how the text is aligned. check_label_layout() judges it.
func read_layout(player: int) -> void:
	var label: RespawnCountdown = _labels[player]
	var layout: Layout = Layout.new()
	layout.measured = true
	layout.shown = label.is_visible_in_tree()
	layout.viewport = label.get_viewport_rect()
	layout.rect = label.get_global_rect()
	layout.text_size = label.get_minimum_size()
	layout.horizontal = label.horizontal_alignment
	layout.vertical = label.vertical_alignment
	layout.text = label.text
	_layouts[player] = layout


## AC-6: while shown, each label's global rect lies inside its viewport, which is half the window
## wide and all of it high, its centre is within CENTRE_TOLERANCE of the viewport's centre, its text is
## centred in that rect and fits in the viewport.
func check_label_layout() -> void:
	var expected_size: Vector2 = Vector2(float(Harness.WINDOW_SIZE.x) / 2.0, float(Harness.WINDOW_SIZE.y))
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		detail.append(_judge_layout(player, expected_size, problems))
	_kit.verdict("label_layout", problems, " | ".join(detail))


## AC-6: a label never takes a click from what is under it: mouse_filter is ignore.
func check_mouse_filter() -> void:
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var filter: int = _labels[player].mouse_filter
		_kit.need(problems, filter == Control.MOUSE_FILTER_IGNORE, "player_%d label mouse_filter is %d" % [player + 1, filter])
		detail.append("player_%d mouse_filter=%d (ignore is %d)" % [player + 1, filter, Control.MOUSE_FILTER_IGNORE])
	_kit.verdict("mouse_filter", problems, " | ".join(detail))


## The text a label shows for this many seconds left: tr(format) % ceili(seconds), AC-6's formula.
func expected_text(label: RespawnCountdown, seconds: float) -> String:
	return label.tr(label.format) % ceili(seconds)


## The whole numbers a wait of the delay's length shows, in order, as [text, ticks] pairs: from
## ceil(delay) down to 1, each for the ticks in which ceil(ticks left / tick rate) is that number.
func _expected_runs(label: RespawnCountdown) -> Array[Array]:
	var per_second: int = Engine.physics_ticks_per_second
	var delay_ticks: int = _harness.ticks_in(_controller.rules.respawn_delay_seconds)
	var runs: Array[Array] = []
	for number: int in range(ceili(float(delay_ticks) / float(per_second)), 0, -1):
		runs.append([expected_text(label, float(number)), mini(delay_ticks, number * per_second) - (number - 1) * per_second])
	return runs


## What the tick readings say about one Player: how many show the Player waiting ("waiting"), how many
## disagree with the label ("off"), the last one that shows it waiting ("last_waiting") and the whole
## numbers the label showed, in order, as [text, ticks] pairs ("runs").
func _read_ticks(player: int) -> Dictionary[String, Variant]:
	var waiting: int = 0
	var off: int = 0
	var last_waiting: int = -1
	var runs: Array[Array] = []
	for index: int in _trace.tick_log.size():
		var sample: Sample = _trace.tick_log[index]
		var is_waiting: bool = not sample.alive[player]
		if is_waiting:
			waiting += 1
			last_waiting = index
		if sample.visible[player] != is_waiting:
			off += 1
		if sample.visible[player]:
			_extend_runs(runs, sample.text[player])
	var read: Dictionary[String, Variant] = {"waiting": waiting, "off": off, "last_waiting": last_waiting, "runs": runs}
	return read


## Counts one more tick of this text: a new run when it differs from the last one.
func _extend_runs(runs: Array[Array], text: String) -> void:
	if runs.is_empty() or runs[runs.size() - 1][0] != text:
		runs.append([text, 0])
	runs[runs.size() - 1][1] += 1


## What the frame readings say about one Player: frames showing it waiting ("waiting"), frames where the
## label disagrees with that ("off"), frames where the text is not the one the seconds make ("text_off")
## and the first such text ("first_bad").
func _read_frames(player: int) -> Dictionary[String, Variant]:
	var label: RespawnCountdown = _labels[player]
	var waiting: int = 0
	var off: int = 0
	var text_off: int = 0
	var first_bad: String = "none"
	for sample: Sample in _trace.frame_log:
		var is_waiting: bool = not sample.alive[player]
		waiting += 1 if is_waiting else 0
		off += 1 if sample.visible[player] != is_waiting else 0
		if not sample.visible[player]:
			continue
		var expected: String = expected_text(label, sample.seconds[player])
		if sample.text[player] != expected:
			text_off += 1
			if first_bad == "none":
				first_bad = "'%s' where the seconds %.4f make '%s'" % [sample.text[player], sample.seconds[player], expected]
	var read: Dictionary[String, Variant] = {"waiting": waiting, "off": off, "text_off": text_off, "first_bad": first_bad}
	return read


## Compares the runs shown with the runs expected: the same count, the same texts, each length within
## _run_slack(). Returns "ok" and both lists as sentences ("shown", "wanted").
func _compare_runs(runs: Array[Array], expected_runs: Array[Array]) -> Dictionary[String, Variant]:
	var ok: bool = runs.size() == expected_runs.size()
	var shown: PackedStringArray = []
	var wanted: PackedStringArray = []
	var slack: int = _run_slack()
	for index: int in maxi(runs.size(), expected_runs.size()):
		if index < runs.size():
			shown.append("'%s' x%d" % [runs[index][0], runs[index][1]])
		if index < expected_runs.size():
			wanted.append("'%s' x%d" % [expected_runs[index][0], expected_runs[index][1]])
		if index < runs.size() and index < expected_runs.size():
			ok = ok and runs[index][0] == expected_runs[index][0] \
				and absi(int(runs[index][1]) - int(expected_runs[index][1])) <= slack
	var compared: Dictionary[String, Variant] = {"ok": ok, "shown": shown, "wanted": wanted}
	return compared


## How far a whole number's run of tick readings may differ from its share of the delay: Kit.TICK_SLACK,
## or the physics ticks per rendered frame when that is more. A label only changes on a frame, so a tick
## reading can see it that many ticks late (a 30 fps run at 60 ticks a second needs 2).
func _run_slack() -> int:
	return maxi(Kit.TICK_SLACK, ceili(float(_trace.tick_log.size()) / float(maxi(_trace.frame_log.size(), 1))))


## How many tick readings show this Player's label with a text that is not tr(format) % ceili(seconds)
## of the same reading. The runner's continuation comes before the tick's own _process, so the label still
## shows its last frame while the controller has moved one tick on: this counts those readings for the
## record. It is no fault of the label, and the frame readings are the exact test.
func _behind(player: int) -> int:
	var label: RespawnCountdown = _labels[player]
	var count: int = 0
	for sample: Sample in _trace.tick_log:
		if sample.visible[player] and sample.text[player] != expected_text(label, sample.seconds[player]):
			count += 1
	return count


## Judges one label's measured layout against the expected viewport size. Adds to problems and returns
## the numbers.
func _judge_layout(player: int, expected_size: Vector2, problems: PackedStringArray) -> String:
	var layout: Layout = _layouts[player]
	var tag: String = "player_%d" % (player + 1)
	if not layout.measured:
		problems.append("%s label was never measured while shown" % tag)
		return "%s never measured" % tag
	var view: Rect2 = layout.viewport
	var rect: Rect2 = layout.rect
	var text_size: Vector2 = layout.text_size
	var centre_error: float = rect.get_center().distance_to(view.get_center())
	var centred: bool = layout.horizontal == HORIZONTAL_ALIGNMENT_CENTER and layout.vertical == VERTICAL_ALIGNMENT_CENTER
	_kit.need(problems, layout.shown, "%s label was not shown when measured" % tag)
	_kit.need(problems, view.size == expected_size, "%s viewport is %s, expected %s" % [tag, view.size, expected_size])
	_kit.need(problems, view.encloses(rect), "%s label rect %s is not inside its viewport %s" % [tag, rect, view])
	_kit.need(problems, centre_error <= CENTRE_TOLERANCE, "%s label centre is %.2f px from the viewport's centre" % [tag, centre_error])
	_kit.need(problems, centred, "%s text is not centred both ways" % tag)
	_kit.need(problems, text_size.x <= view.size.x and text_size.y <= view.size.y, "%s text %s does not fit its viewport" % [tag, text_size])
	return ("%s text='%s' viewport=%s (expected %s) label rect=%s inside=%s centre_error=%.2f px (max %.0f) "
		+ "text_size=%s centred_both_ways=%s") % [
			tag, layout.text, view.size, expected_size, rect, view.encloses(rect), centre_error, CENTRE_TOLERANCE, text_size, centred]
