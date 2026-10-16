extends RefCounted
## The Round for the tyre_tracks scenario (Story 026 AC-3, AC-5 and AC-7), real keys and the game's own flows on Map 01: fade_arithmetic (the
## settings' line from full strength through the hold and down to nothing over the fade: at 0 s, at the end of the hold, half way down and after
## the fade), clock (the tracks' clock moves by the ticks, a sixtieth of a second each, whatever the wall clock does), round_over_pause (a Round won
## by a real Flag delivery pauses the tree, and the clock, the strokes and what is sent to the ground shader stand still for 45 ticks, while the
## strokes of the tick that ended the Round are drawn: the painter holds none),
## restart_clears (R: when the Round starts again the clock is zero, no stroke waits, and the track map is asked to clear once on its next update;
## the window's audit of strokes finds none that the node's own rule does not explain, across the Round's end, the pause and the restart),
## hand_off (SplitScreen handed the node both Units, from its own exports, and connected the restart to clear(); the greybox field has no node),
## drawn_first (the track map's SubViewport and both views' are drawn into the window, the track map first in the tree, so the renderer draws it first
## in every frame: sibling SubViewports are drawn in the order they entered the tree, measured on 4.7.2) and published (a node made from the scene
## sends the map, the area, the look with its strength 1 and the clock when it enters the tree, the clock on every tick, and the strength 0 when it
## leaves; entering again it sends them all again; and a second node that enters while the first is in the tree holds them: the first then sends nothing
## when it leaves, and the second the strength 0). Run by tyre_tracks.gd. Tooling only. Every number comes from the game's data; the scenario types only its
## test inputs.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Gate wall that is broken to take the Flag.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The greybox field of the older scenarios, which has no tyre tracks.
const GREYBOX_FIELD: PackedScene = preload("res://src/gameplay/maps/greybox_field.tscn")

## Ticks the clock is read over, and ticks the Round-over pause is watched.
const CLOCK_TICKS: int = 600
const PAUSED_TICKS: int = 45
## How far the clock may be from the ticks it counted, seconds (a float sum of 600 steps of a sixtieth).
const CLOCK_SLACK: float = 0.001
## The ages the line is read at, as a share of the hold (the first three) and of the fade after the hold (the rest), and what is left at each.
const HOLD_SHARES: Array[float] = [-1.0, 0.0, 1.0]
const FADE_SHARES: Array[float] = [0.5, 1.0, 2.0]
const HOLD_LEFT: Array[float] = [1.0, 1.0, 1.0]
const FADE_LEFT: Array[float] = [0.5, 0.0, 0.0]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit26
var _q: Quick
var _tracks: TyreTracks
var _settings: TyreTrackSettings


func _init(kit: Kit26) -> void:
	_k = kit
	_q = kit.q()
	_tracks = kit.tracks()
	_settings = _tracks.settings


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().turrets_down()
	_fade_arithmetic()
	await _clock()
	await _round()
	_hand_off()
	_drawn_first()
	await _published()


## fade_arithmetic (AC-3): see the class doc.
func _fade_arithmetic() -> void:
	var problems: PackedStringArray = []
	var read: PackedStringArray = []
	for index: int in HOLD_SHARES.size():
		var age: float = _settings.hold_seconds * HOLD_SHARES[index]
		_q.kit.need(problems, is_equal_approx(_settings.strength_at(age), HOLD_LEFT[index]), "age %.1f s: %.4f left, expected %.4f" % [age, _settings.strength_at(age), HOLD_LEFT[index]])
		read.append("%.0f s %.2f" % [age, _settings.strength_at(age)])
	for index: int in FADE_SHARES.size():
		var age: float = _settings.hold_seconds + _settings.fade_seconds * FADE_SHARES[index]
		_q.kit.need(problems, is_equal_approx(_settings.strength_at(age), FADE_LEFT[index]), "age %.1f s: %.4f left, expected %.4f" % [age, _settings.strength_at(age), FADE_LEFT[index]])
		read.append("%.0f s %.2f" % [age, _settings.strength_at(age)])
	var previous: float = 1.0
	for second: int in int(_settings.hold_seconds + _settings.fade_seconds * 2.0):
		var left: float = _settings.strength_at(float(second))
		_q.kit.need(problems, left <= previous, "the line rises at %d s" % second)
		previous = left
	_q.kit.verdict("fade_arithmetic", problems, "a mark keeps its full strength for %.0f s and fades to nothing over the next %.0f s, in a straight line that never rises (strength left at each age: %s)" % [_settings.hold_seconds, _settings.fade_seconds, ", ".join(read)])


## clock (AC-3): see the class doc.
func _clock() -> void:
	var problems: PackedStringArray = []
	var before: float = _tracks.now
	var at: int = _q.harness.ticks
	await _q.kit.advance(CLOCK_TICKS)
	var seconds: float = float(_q.harness.ticks - at) / float(Engine.physics_ticks_per_second)
	_q.kit.need(problems, absf((_tracks.now - before) - seconds) <= CLOCK_SLACK, "the clock moved %.4f s over %d ticks (%.4f s)" % [_tracks.now - before, _q.harness.ticks - at, seconds])
	_q.kit.verdict("clock", problems, "over %d ticks the tracks' clock moved %.4f s, the %.4f s the ticks count (within %.3f s), whatever the wall clock did" % [_q.harness.ticks - at, _tracks.now - before, seconds, CLOCK_SLACK])


## round_over_pause and restart_clears (AC-3): see the class doc.
func _round() -> void:
	var problems: PackedStringArray = []
	var paused: PackedStringArray = []
	var flags: Object = _k.flags()
	var published: Array[StringName] = []
	_tracks.published.connect(func(parameter: StringName, _value: Variant) -> void: published.append(parameter))
	var at_restart: Array[Dictionary] = []
	_q.controller.round_started.connect(func() -> void: at_restart.append({"now": _tracks.now, "strokes": _tracks.strokes.size(), "queued": _tracks.painter.waiting(), "clear": _tracks.track_viewport.render_target_clear_mode, "update": _tracks.track_viewport.render_target_update_mode}))
	_k.begin_rows()
	flags.wall(1, Walls.GATE).destroy()
	var took: bool = await flags.take_flag(0, 1, Walls.GATE)
	var won: bool = await flags.deliver(0)
	var over: bool = _q.controller.is_round_over()
	var tree: SceneTree = _q.harness.get_tree()
	var then: float = _tracks.now
	var sent: int = published.size()
	var strokes_then: Array[TyreTracks.Stroke] = _tracks.strokes
	await _q.kit.advance(PAUSED_TICKS)
	_q.kit.need(paused, took and won and over and tree.paused, "premise: the Flag taken %s, the Round won %s, over %s, the tree paused %s" % [took, won, over, tree.paused])
	_q.kit.need(paused, _tracks.now == then and published.size() == sent and _tracks.strokes == strokes_then, "over %d ticks of the pause the clock went %.4f to %.4f, %d values were sent, the strokes list changed %s" % [PAUSED_TICKS, then, _tracks.now, published.size() - sent, _tracks.strokes != strokes_then])
	_q.kit.need(paused, strokes_then.size() > 0 and _tracks.painter.waiting() == 0, "the tick that ended the Round made %d strokes, and in the pause the painter still held %d quads" % [strokes_then.size(), _tracks.painter.waiting()])
	_q.kit.verdict("round_over_pause", paused, "a Round won by a real Flag delivery: the tree paused and for %d ticks of the pause the tracks' clock stood at %.3f s, nothing was sent to the ground shader and the strokes did not change, and the %d strokes of the tick that ended the Round were drawn (the painter held no quad)" % [PAUSED_TICKS, then, strokes_then.size()])
	_tracks.track_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_tracks.track_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await flags.restart()
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _settings.jump_step, rows.size())
	for problem: String in audit["problems"]:
		problems.append(problem)
	var mark: Dictionary = at_restart[0] if at_restart.size() == 1 else {}
	_q.kit.need(problems, at_restart.size() == 1 and mark["now"] == 0.0 and mark["strokes"] == 0 and mark["queued"] == 0, "when the Round started again: %s (%d signals)" % [mark, at_restart.size()])
	_q.kit.need(problems, not mark.is_empty() and mark["clear"] == SubViewport.CLEAR_MODE_ONCE and mark["update"] == SubViewport.UPDATE_ONCE, "the track map was not asked to clear once: %s" % [mark])
	_q.kit.verdict("restart_clears", problems, "R after that Round: when it started again the clock was %.1f, no stroke and no quad waited and the track map, put to never clear and not to update, was asked to clear once on its next update; %d rows of the Round's end, the pause and the restart held %d strokes, all explained by the node's own rule" % [mark.get("now", -1.0), rows.size(), audit["strokes"]])


## hand_off (AC-7): see the class doc.
func _hand_off() -> void:
	var problems: PackedStringArray = []
	var split: SplitScreen = _q.harness.split
	_q.kit.need(problems, _tracks == split.field.tyre_tracks and _tracks.units.size() == 2 and _tracks.units[0] == split.player_1_unit and _tracks.units[1] == split.player_2_unit, "the node holds %d Units, the first Player 1's: %s" % [_tracks.units.size(), _tracks.units[0] == split.player_1_unit if _tracks.units.size() > 0 else "none"])
	_q.kit.need(problems, _q.controller.round_started.is_connected(_tracks.clear), "round_started is not connected to the node's clear()")
	var greybox: MapField = GREYBOX_FIELD.instantiate() as MapField
	_q.kit.need(problems, greybox != null and greybox.tyre_tracks == null, "the greybox field has a tyre tracks node")
	greybox.free()
	_q.kit.verdict("hand_off", problems, "SplitScreen handed the Map's tracks node both Units, Player 1's first, and connected the Round's restart to its clear(), from the field's own export; the greybox field has no tracks node")


## drawn_first (AC-3 and AC-4): see the class doc. A view drawn before the track map would read the map of the frame before: every mark a frame late,
## and after R the old marks against the clock at 0, at full strength for that frame. The rule was measured with two sibling SubViewports on 4.7.2
## (story 026's evidence, measurements/render-order-probe.txt); this check holds the shipped scene to it.
func _drawn_first() -> void:
	var problems: PackedStringArray = []
	var split: SplitScreen = _q.harness.split
	var map_viewport: SubViewport = _tracks.track_viewport
	var views: Array[Viewport] = [split.player_1_camera.get_viewport(), split.player_2_camera.get_viewport()]
	for index: int in views.size():
		var view: Viewport = views[index]
		_q.kit.need(problems, view is SubViewport and view.get_parent().get_viewport() == map_viewport.get_parent().get_viewport() and view.is_greater_than(map_viewport), "Player %d's view %s is not drawn after the track map %s" % [index + 1, view.get_path(), map_viewport.get_path()])
	_q.kit.verdict("drawn_first", problems, "the track map's SubViewport (%s) and both views' SubViewports are drawn into the window, and the track map comes first in the tree, so the renderer draws it before either view in every frame and a view never reads the map of the frame before" % map_viewport.get_path())


## published (AC-7): see the class doc. The node is made from the scene, so the real one keeps its own state.
func _published() -> void:
	var problems: PackedStringArray = []
	var node: TyreTracks = load("res://src/gameplay/maps/tyre_tracks.tscn").instantiate() as TyreTracks
	node.settings = _settings
	var seen: Array[Array] = []
	node.published.connect(func(parameter: StringName, value: Variant) -> void: seen.append([parameter, value]))
	_q.harness.add_child(node)
	var entry: Dictionary = {}
	for pair: Array in seen:
		entry[pair[0]] = pair[1]
	var area: Vector4 = Vector4(_settings.area_origin.x, _settings.area_origin.y, _settings.area_size.x, _settings.area_size.y)
	_q.kit.need(problems, entry.size() == 4 and entry.get(TyreTracks.MAP_GLOBAL) is Texture2D and entry.get(TyreTracks.AREA_GLOBAL) == area, "entering the tree it sent %s" % [entry.keys()])
	var look: Vector4 = entry.get(TyreTracks.LOOK_GLOBAL, Vector4.ZERO)
	_q.kit.need(problems, look == Vector4(_settings.darkness, _settings.rut_depth, _settings.smoothing, 1.0), "the look it sent was %s" % look)
	await _q.kit.advance(2)
	var clock: Vector4 = (seen[seen.size() - 1] as Array)[1] if seen.size() > 4 else Vector4.ZERO
	_q.kit.need(problems, (seen[seen.size() - 1] as Array)[0] == TyreTracks.CLOCK_GLOBAL and clock.x > 0.0 and clock.y == _settings.hold_seconds and clock.z == _settings.fade_seconds, "after two ticks the last value was %s" % [seen[seen.size() - 1]])
	_q.harness.remove_child(node)
	var last: Array = seen[seen.size() - 1]
	_q.kit.need(problems, last[0] == TyreTracks.LOOK_GLOBAL and last[1] == Vector4.ZERO, "leaving the tree the last value it sent was %s" % [last])
	seen.clear()
	_q.harness.add_child(node)
	var again: Dictionary = {}
	for pair: Array in seen:
		again[pair[0]] = pair[1]
	_q.kit.need(problems, again.size() == 4 and again.get(TyreTracks.MAP_GLOBAL) == entry.get(TyreTracks.MAP_GLOBAL) and again.get(TyreTracks.LOOK_GLOBAL) == look, "entering the tree again it sent %s" % [again])
	var other: TyreTracks = load("res://src/gameplay/maps/tyre_tracks.tscn").instantiate() as TyreTracks
	other.settings = _settings
	var other_seen: Array[Array] = []
	other.published.connect(func(parameter: StringName, value: Variant) -> void: other_seen.append([parameter, value]))
	_q.harness.add_child(other)
	seen.clear()
	_q.harness.remove_child(node)
	_q.kit.need(problems, seen.is_empty(), "the first node, leaving while a second one held the parameters, sent %s" % [seen])
	var before: int = other_seen.size()
	_q.harness.remove_child(other)
	var left: Array = other_seen[other_seen.size() - 1] if other_seen.size() > before else []
	_q.kit.need(problems, other_seen.size() == before + 1 and left[0] == TyreTracks.LOOK_GLOBAL and left[1] == Vector4.ZERO, "the second node, leaving, sent %s" % [other_seen.slice(before)])
	other.free()
	node.free()
	_q.kit.verdict("published", problems, "a tracks node made from the scene sent the map, the area (%s), the look with its strength at 1 and the clock when it entered the tree, the clock on each tick, and its strength at 0 when it left; entering again it sent all four again; and while a second node that entered after it held them, it sent nothing on leaving, and the second sent the strength at 0" % area)
