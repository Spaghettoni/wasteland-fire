extends RefCounted
## The strokes for the tyre_tracks scenario (Story 026 AC-1), played with real keys on the shipped data and Map 01, every row the watch's
## (tyre_tracks_watch.gd): lines (a straight run of each ground type: on every tick one stroke for each tyre of the Unit's data, from where that
## tyre touched the ground two rows back to where it touched it one row back, as wide as the tyre and stamped with the tracks' clock, one line for
## the Motorbike and two for the Buggy and the Truck), quad_widths (the three quads the stroke is drawn with are the tyre's width across at half
## strength, and meet edge to edge), reverse (backing up draws the same strokes, behind the tyres) and gyrocopter_none (the Gyrocopter, flown, turned and braked, leaves
## none, and its data lists no tyre) and two_ticks_a_frame (with two physics ticks in every frame, the painter's last redraw in each frame holds the
## quads of every stroke of both ticks). The turns are tyre_tracks_turns.gd's. Run by tyre_tracks.gd. Tooling only. Every number comes from the game's data; the
## scenario types only its test inputs and its tolerances.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where Player 1 stands to start a case (the open middle of the Map's salt flat, facing east); Player 2 stands at the mirror across x = 0
## facing west. The Units drive toward each other's side of x = 0 for at most 90 ticks; a straight run at full throttle starts from
## LINES, farther out, so the two never meet (from OPEN two Motorbikes touched at the end of their run), and every drive here is
## checked to touch nothing but the ground.
const OPEN: Vector3 = Vector3(-22.0, 0.0, -16.0)
const LINES: Vector3 = Vector3(-30.0, 0.0, -16.0)
const RUN_TICKS: int = 90
## The ground types, by index into the data.
const GROUND_TYPES: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]
## Above this real speed (metres a second) every tyre moves more than the minimum step on every tick, so every tyre strokes on every tick.
const MOVING_SPEED: float = 1.0
## Two lateral places closer than this are one line, metres.
const LINE_TOLERANCE: float = 0.005

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit26
var _q: Quick


func _init(kit: Kit26) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().turrets_down()
	await _lines()
	_quad_widths()
	await _reverse()
	await _gyrocopter()
	await _two_ticks_a_frame()


## Both Players' Units staged as one type at the open spots, facing each other's way.
func _stage(type_index: int, at: Vector3 = OPEN) -> void:
	await _k.stage(type_index, [at, Quick.mirrored(at)], [Vector3.RIGHT, Vector3.LEFT])


## Whether the tyres of a Player's Unit stroke in row `index`: the Unit was alive and on the floor, as the same type, and moving, in the two rows before.
func _rolling(rows: Array[Dictionary], index: int, player: int) -> bool:
	var before: Dictionary = rows[index - 1]
	var then: Dictionary = rows[index - 2]
	var alive: bool = (before["alive"] as Array)[player] and (then["alive"] as Array)[player] and (before["on_floor"] as Array)[player]
	var same: bool = (before["stats"] as Array)[player] == (then["stats"] as Array)[player]
	return alive and same and float((before["speed"] as Array)[player]) > MOVING_SPEED and float((then["speed"] as Array)[player]) > MOVING_SPEED


## lines (AC-1): see the class doc, for the three ground types, both Players.
func _lines() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	var summary: PackedStringArray = []
	for type_index: int in GROUND_TYPES:
		await _stage(type_index, LINES)
		var plan: Array[Vector2i] = Kit26.plan([[RUN_TICKS, 1, 0]])
		var rows: Array[Dictionary] = await _k.record([plan, plan])
		_q.kit.need(problems, Kit26.touched_nothing(rows), "%s: the Units touched something but the ground on %s ticks" % [_q.units.stats(type_index).type_id, Kit26.touches(rows)])
		var stats: UnitStats = _q.units.stats(type_index)
		var across: PackedFloat64Array = PackedFloat64Array()
		var places: PackedFloat64Array = PackedFloat64Array()
		for tyre: TyreContact in stats.tyres:
			places.append(tyre.offset.x)
		for index: int in range(2, rows.size()):
			var made_now: int = (rows[index]["strokes"] as Array).size()
			_q.kit.need(problems, int(rows[index]["queued"]) == made_now * _k.tracks().quad_edges().size(), "row %d: the painter holds %d quads for %d strokes" % [index, rows[index]["queued"], made_now])
		for player: int in Kit26.Kit.PLAYERS:
			var lateral: PackedFloat64Array = PackedFloat64Array()
			var rolled: int = 0
			for index: int in range(2, rows.size()):
				if not _rolling(rows, index, player):
					continue
				var made: Array[Dictionary] = Kit26.strokes_of(rows[index], player)
				_q.kit.need(problems, made.size() == stats.tyres.size(), "row %d Player %d: %d strokes for %d tyres" % [index, player + 1, made.size(), stats.tyres.size()])
				for stroke: Dictionary in made:
					var problem: String = Kit26.stroke_problem(rows, index, player, stroke)
					_q.kit.need(problems, problem.is_empty(), problem)
					lateral.append((stroke["to"] as Vector2).y)
				rolled += 1
			checked += rolled
			_q.kit.need(problems, rolled >= RUN_TICKS / 2, "%s Player %d: only %d of the %d rows had every tyre rolling" % [stats.type_id, player + 1, rolled, rows.size()])
			var lines: int = Kit26.distinct(lateral, LINE_TOLERANCE)
			var expected: int = Kit26.distinct(places, LINE_TOLERANCE)
			var spread: float = _extent(lateral) - _extent(places)
			_q.kit.need(problems, lines == expected and absf(spread) <= LINE_TOLERANCE, "%s Player %d: %d lines (data: %d) and a spread differing by %.4f m" % [stats.type_id, player + 1, lines, expected, spread])
			across.append(lines)
		summary.append("%s=%d" % [stats.type_id, int(across[0])])
	measured.append("stroke_rows=%d" % checked)
	_q.kit.verdict("lines", problems, "a straight run of each ground type, both Players: on %d rows every tyre of the data made one stroke from where it touched the ground two rows back to where it touched it one row back, as wide as the tyre and stamped with the clock, and the painter held three quads a stroke until the frame drew them; lines drawn: %s" % [checked, ", ".join(summary)])


## quad_widths (AC-1): the three quads a stroke is drawn with (TyreTracks.pixel_quads()) are, in metres, the outer reach and the inner reach on each side of
## the stroke's line, whose mean width is the tyre's (the mark falls to half strength at the tyre's width), each rim as wide as the settings' rim in
## pixels, and neighbouring quads share their edge corners exactly (no gap, no overlap).
func _quad_widths() -> void:
	var problems: PackedStringArray = []
	var tracks: TyreTracks = _k.tracks()
	var settings: TyreTrackSettings = tracks.settings
	var pixel: Vector2 = settings.metres_per_pixel()
	var rim: float = settings.rim_pixels * minf(pixel.x, pixel.y)
	var heading: Vector2 = Vector2.RIGHT
	var checked: int = 0
	for type_index: int in GROUND_TYPES:
		for tyre: TyreContact in _q.units.stats(type_index).tyres:
			for angle: float in [0.0, 0.3, 1.0, 2.5]:
				var stroke: TyreTracks.Stroke = TyreTracks.Stroke.new()
				stroke.from = Vector2(1.0, 2.0)
				stroke.to = stroke.from + heading.rotated(angle) * 0.4
				stroke.width = tyre.width
				var quads: Array[PackedVector2Array] = tracks.pixel_quads(stroke)
				var outer: float = ((quads[2][1] - quads[0][0]) * pixel).length()
				var inner: float = ((quads[2][0] - quads[0][1]) * pixel).length()
				_q.kit.need(problems, quads.size() == 3 and absf((outer + inner) / 2.0 - tyre.width) <= Kit26.POSITION_TOLERANCE, "width %.2f at %.1f rad: outer %.4f inner %.4f m" % [tyre.width, angle, outer, inner])
				var across: Vector2 = (quads[2][1] - quads[0][0]) * pixel
				_q.kit.need(problems, absf(across.normalized().dot((stroke.to - stroke.from).normalized())) <= Kit26.POSITION_TOLERANCE, "width %.2f at %.1f rad: the quad's width is not square to the stroke" % [tyre.width, angle])
				_q.kit.need(problems, absf((outer - inner) / 2.0 - rim) <= Kit26.POSITION_TOLERANCE or tyre.width < rim, "width %.2f at %.1f rad: each rim %.4f m, the settings' %.4f m" % [tyre.width, angle, (outer - inner) / 2.0, rim])
				_q.kit.need(problems, quads[0][1] == quads[1][0] and quads[0][2] == quads[1][3] and quads[1][1] == quads[2][0] and quads[1][2] == quads[2][3], "width %.2f at %.1f rad: the quads' shared corners differ" % [tyre.width, angle])
				checked += 1
	_q.kit.verdict("quad_widths", problems, "%d strokes of every tyre of the data, at four headings: the mark's width at half strength is the tyre's, each rim is %.2f pixels wide and the three quads meet edge to edge" % [checked, settings.rim_pixels])


## reverse (AC-1): backing up at full reverse throttle draws the strokes of driving forward, each from where its tyre touched the ground two
## rows back to where it touched it one row back, and every one runs backward along the Unit's facing (its end is behind its start).
func _reverse() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	for type_index: int in GROUND_TYPES:
		await _stage(type_index)
		var stats: UnitStats = _q.units.stats(type_index)
		var plan: Array[Vector2i] = Kit26.plan([[RUN_TICKS, -1, 0]])
		var rows: Array[Dictionary] = await _k.record([plan, plan])
		_q.kit.need(problems, Kit26.touched_nothing(rows), "%s: the Units touched something but the ground on %s ticks" % [_q.units.stats(type_index).type_id, Kit26.touches(rows)])
		for player: int in Kit26.Kit.PLAYERS:
			for index: int in range(2, rows.size()):
				if not _rolling(rows, index, player):
					continue
				var facing: Vector3 = -((rows[index - 1]["poses"] as Array)[player] as Transform3D).basis.z
				var made: Array[Dictionary] = Kit26.strokes_of(rows[index], player)
				_q.kit.need(problems, made.size() == stats.tyres.size(), "%s Player %d row %d: %d strokes for %d tyres" % [stats.type_id, player + 1, index, made.size(), stats.tyres.size()])
				for stroke: Dictionary in made:
					var problem: String = Kit26.stroke_problem(rows, index, player, stroke)
					_q.kit.need(problems, problem.is_empty(), problem)
					var run: Vector2 = (stroke["to"] as Vector2) - (stroke["from"] as Vector2)
					_q.kit.need(problems, run.dot(Vector2(facing.x, facing.z)) < 0.0, "%s Player %d row %d: the stroke runs %s along a facing of %s" % [stats.type_id, player + 1, index, run, facing])
				checked += 1
	_q.kit.need(problems, checked >= RUN_TICKS, "only %d rows rolled backward" % checked)
	_q.kit.verdict("reverse", problems, "backing up at full throttle, each ground type, both Players: on %d rows every tyre of the data made one stroke, from where it touched the ground two rows back to where it touched it one row back, running backward along the Unit's facing" % checked)


## gyrocopter_none (AC-1): the Gyrocopter's data lists no tyre, and flown at full throttle, turned at full lock and braked for 380 ticks, with
## both Players' Gyrocopters really moving, it leaves not one stroke: nothing in the tracks asks which type it is.
func _gyrocopter() -> void:
	var problems: PackedStringArray = []
	await _stage(Quick.GYROCOPTER)
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	_q.kit.need(problems, stats.tyres.is_empty(), "the Gyrocopter's data lists %d tyres" % stats.tyres.size())
	var plan: Array[Vector2i] = Kit26.plan([[60, 1, 0], [200, 1, 1], [60, -1, 0], [60, 0, 0]])
	var mirrored: Array[Vector2i] = Kit26.plan([[60, 1, 0], [200, 1, -1], [60, -1, 0], [60, 0, 0]])
	var rows: Array[Dictionary] = await _k.record([plan, mirrored])
	_q.kit.need(problems, Kit26.touched_nothing(rows), "gyrocopter: the Units touched something but the ground on %s ticks" % [Kit26.touches(rows)])
	var strokes: int = 0
	var flown: int = 0
	for row: Dictionary in rows:
		strokes += (row["strokes"] as Array).size()
		for player: int in Kit26.Kit.PLAYERS:
			flown += 1 if float((row["speed"] as Array)[player]) > MOVING_SPEED else 0
	_q.kit.need(problems, strokes == 0, "%d strokes were made" % strokes)
	_q.kit.need(problems, flown >= RUN_TICKS, "the Gyrocopters moved on only %d Player-ticks" % flown)
	_q.kit.verdict("gyrocopter_none", problems, "both Gyrocopters flown, turned and braked over %d ticks, moving on %d Player-ticks: %d strokes, and the data lists %d tyres" % [rows.size(), flown, strokes, stats.tyres.size()])


## two_ticks_a_frame (AC-1 and AC-5, the engine review's finding): with the physics ticks at twice the project's rate and the run's fixed frame rate,
## every frame holds two ticks, as a frame does whenever the frame rate is under the tick rate. A CanvasItem's redraw replaces the commands of its redraw
## before and a frame renders the last one, so in each frame the painter's last redraw (read on its draw signal, which comes before _draw() empties the
## list) must hold the quads of every stroke of the frame's ticks. A redraw on each tick, the build before the review, kept only the second tick's quads:
## dashed tracks, seen windowed at --fixed-fps 30. The first and the last frame of the run are not judged (a tick of either may fall outside the rows).
func _two_ticks_a_frame() -> void:
	var problems: PackedStringArray = []
	var rate: int = Engine.physics_ticks_per_second
	await _stage(Quick.BUGGY)
	var painter: TyreTrackPainter = _k.tracks().painter
	var per_stroke: int = _k.tracks().quad_edges().size()
	var draws: Array[Vector2i] = []
	var hook: Callable = func() -> void: draws.append(Vector2i(Engine.get_process_frames(), painter.waiting()))
	painter.draw.connect(hook)
	Engine.physics_ticks_per_second = rate * 2
	var plan: Array[Vector2i] = Kit26.plan([[RUN_TICKS, 1, 0]])
	var rows: Array[Dictionary] = await _k.record([plan, plan])
	Engine.physics_ticks_per_second = rate
	_q.kit.need(problems, Kit26.touched_nothing(rows), "buggy: the Units touched something but the ground on %s ticks" % [Kit26.touches(rows)])
	painter.draw.disconnect(hook)
	var made: Dictionary = {}
	var ticks: Dictionary = {}
	for row: Dictionary in rows:
		var frame: int = row["frame"]
		made[frame] = int(made.get(frame, 0)) + (row["strokes"] as Array).size() * per_stroke
		ticks[frame] = int(ticks.get(frame, 0)) + 1
	var drawn: Dictionary = {}
	for draw: Vector2i in draws:
		drawn[draw.x] = draw.y
	var frames: Array = made.keys()
	frames.sort()
	var doubled: int = 0
	var quads: int = 0
	for index: int in range(1, frames.size() - 1):
		var frame: int = frames[index]
		doubled += 1 if int(ticks[frame]) == 2 else 0
		quads += int(made[frame])
		_q.kit.need(problems, int(drawn.get(frame, 0)) == int(made[frame]), "frame %d: its %d ticks made %d quads and the painter's last redraw in it held %d" % [frame, ticks[frame], made[frame], drawn.get(frame, 0)])
	_q.kit.need(problems, frames.size() > 2 and doubled == frames.size() - 2 and quads > 0, "premise: %d of the %d frames judged held two ticks, with %d quads" % [doubled, frames.size() - 2, quads])
	_q.kit.verdict("two_ticks_a_frame", problems, "both Buggies driven straight with the physics ticks at %d a second, twice the project's rate, and the run's fixed frame rate: all %d frames judged held two ticks, and in every one the painter's last redraw, the one the frame renders, held the quads of the strokes of both (%d quads in all), so no tick's strokes are left out of the track map" % [rate * 2, doubled, quads])


## The distance between the largest and the smallest of the values.
static func _extent(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var low: float = values[0]
	var high: float = values[0]
	for value: float in values:
		low = minf(low, value)
		high = maxf(high, value)
	return high - low
