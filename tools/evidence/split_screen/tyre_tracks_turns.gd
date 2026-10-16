extends RefCounted
## The turns for the tyre_tracks scenario (Story 026 AC-1), played with real keys on the shipped data and Map 01, every row the watch's
## (tyre_tracks_watch.gd): steady_turn (at full lock the front and rear tyres of a side run on one line, within a quarter of the tyre's width), slow_roll (a
## stick pressed only a little rolls each ground type slower than a tyre moves the minimum step in a tick: the tyres keep their last place until they have
## moved enough and then stroke from it, so a slow roll still draws) and spot_turn (a turn on the spot leaves a ring: every stroke at its tyre's distance from the
## Unit's middle and the strokes go all the way round). Run by tyre_tracks.gd. Tooling only. Every number comes from the game's data; the scenario types only
## its test inputs and its tolerances.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where Player 1 stands to start a case (the open middle of the Map's salt flat, facing east); Player 2 stands at the mirror across x = 0
## facing west.
const OPEN: Vector3 = Vector3(-22.0, 0.0, -16.0)
const RUN_TICKS: int = 90
## The ground types, by index into the data.
const GROUND_TYPES: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]
## Above this real speed (metres a second) every tyre moves more than the minimum step on every tick, so every tyre strokes on every tick.
const MOVING_SPEED: float = 1.0
## Where Player 1's whole-circle turns start, by type, facing east (Player 2 at the mirror, facing west): the circle (its radius is the type's
## max_speed / turn_rate, 8.6 m for the Motorbike and the Buggy, 12.3 m for the Truck, whatever the speed) goes round the outer wreck near
## Base A, WreckWestOuterSouth, which stands inside it, and its ring misses every wreck, container, tank, wall, rock and ford of the Map
## (found by a scan of the Map's colliders, then driven: no contact); the salt flat's middle has no room for one.
const TURN_SPOTS: Dictionary = {Quick.MOTORBIKE: Vector3(-77.0, 0.0, -6.5), Quick.BUGGY: Vector3(-77.0, 0.0, -6.5), Quick.TRUCK: Vector3(-80.0, 0.0, -9.5)}
## The share of the narrower tyre's width within which the front and the rear tyre of a side are on one line. The Unit turns about its middle in steps
## (it rotates, then moves along the new facing), so a tyre ahead of its middle runs a little outside the circle of the middle and a tyre behind it a
## little inside, by the tyre's distance times the sine of half the yaw of a tick: the Motorbike's two tyres, 1.48 m apart at 2.8 rad/s, run 34 mm apart,
## a sixth of the front tyre's width; the marks overlap and read as one line.
const ONE_LINE_SHARE: float = 0.25
## How far a stroke's distance from the Unit's middle may differ from its tyre's, metres, and how far short of a whole turn (radians) the
## strokes of one tyre may stop for the ring to be closed.
const RING_RADIUS_TOLERANCE: float = 0.001
const RING_SHORT: float = 0.25
## The share of the yaw the Unit turned that the strokes of its first tyre must add up to.
const ANGLE_SHARE: float = 0.05
## The slow roll's speed (metres a second: under the 0.6 at which a tyre moves the minimum step of a centimetre on every tick) and its length in ticks.
const SLOW_SPEED: float = 0.4
const SLOW_TICKS: int = 180

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
	await _steady_turn()
	await _slow_roll()
	await _spot_turn()


## Both Players' Units staged as one type at the open spots, facing each other's way.
func _stage(type_index: int) -> void:
	await _k.stage(type_index, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])


## Whether the tyres of a Player's Unit stroke in row `index`: the Unit was alive and on the floor, as the same type, and moving, in the two rows before.
func _rolling(rows: Array[Dictionary], index: int, player: int) -> bool:
	return Kit26.explained(rows, index, player) and float(((rows[index - 1]["speed"]) as Array)[player]) > MOVING_SPEED and float(((rows[index - 2]["speed"]) as Array)[player]) > MOVING_SPEED


## steady_turn (AC-1): at full lock and top speed, in the last third of one whole circle, the front and the rear tyre of each side of a Unit run
## on one line: a circle is fitted to the places the rear tyre ended its strokes at (least squares, and it must fit within an eighth of the
## narrower tyre's width, so the turn was steady), and the places the front tyre ended its strokes at are within a quarter of that width of it
## (ONE_LINE_SHARE says why not nearer). The Unit turns about its middle, so the two share a circle.
func _steady_turn() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	var worst: float = 0.0
	for type_index: int in GROUND_TYPES:
		var start: Vector3 = TURN_SPOTS[type_index]
		await _k.stage(type_index, [start, Quick.mirrored(start)], [Vector3.RIGHT, Vector3.LEFT])
		var stats: UnitStats = _q.units.stats(type_index)
		var ticks: int = _k.circle_ticks(stats)
		var rows: Array[Dictionary] = await _k.record([Kit26.plan([[ticks, 1, -1]]), Kit26.plan([[ticks, 1, 1]])])
		_q.kit.need(problems, Kit26.touched_nothing(rows), "%s: the Units touched something but the ground on %s ticks" % [stats.type_id, Kit26.touches(rows)])
		for player: int in Kit26.Kit.PLAYERS:
			var ends: Array[PackedVector2Array] = []
			for _tyre: TyreContact in stats.tyres:
				ends.append(PackedVector2Array())
			for index: int in range(rows.size() * 2 / 3, rows.size()):
				for stroke: Dictionary in Kit26.strokes_of(rows[index], player) if _rolling(rows, index, player) else ([] as Array[Dictionary]):
					ends[int(stroke["tyre"])].append(stroke["to"])
			for front: int in stats.tyres.size():
				for rear: int in stats.tyres.size():
					var a: TyreContact = stats.tyres[front]
					var b: TyreContact = stats.tyres[rear]
					if not (a.offset.y < 0.0 and b.offset.y > 0.0 and is_equal_approx(a.offset.x, b.offset.x)):
						continue
					var share: float = minf(a.width, b.width)
					var fit: Vector4 = _fit_circle(ends[rear])
					_q.kit.need(problems, ends[rear].size() >= RUN_TICKS / 4 and fit.w <= share * ONE_LINE_SHARE / 2.0, "%s Player %d: the rear tyre's %d strokes fit a circle within %.4f m only" % [stats.type_id, player + 1, ends[rear].size(), fit.w])
					for point: Vector2 in ends[front]:
						var gap: float = absf(point.distance_to(Vector2(fit.x, fit.y)) - fit.z)
						worst = maxf(worst, gap / share)
						_q.kit.need(problems, gap <= ONE_LINE_SHARE * share, "%s Player %d: a front stroke ends %.4f m off the rear tyre's circle" % [stats.type_id, player + 1, gap])
						checked += 1
	_q.kit.need(problems, checked > 0, "no front tyre was judged")
	_q.kit.verdict("steady_turn", problems, "%d places the front tyres ended their strokes at, in a whole circle at full lock of each ground type, both Players: the worst is %.3f of the narrower tyre's width off the circle the rear tyre of its side ran on (a quarter allowed)" % [checked, worst])


## A circle fitted to points by least squares (Kasa's algebraic fit, about the points' mean so that the sums stay small): Vector4(centre x, centre
## y, radius, the largest distance of a point from the circle).
static func _fit_circle(points: PackedVector2Array) -> Vector4:
	var mean: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		mean += point
	mean /= maxf(float(points.size()), 1.0)
	var suu: float = 0.0
	var svv: float = 0.0
	var suv: float = 0.0
	var suz: float = 0.0
	var svz: float = 0.0
	var sz: float = 0.0
	for point: Vector2 in points:
		var offset: Vector2 = point - mean
		var z: float = offset.length_squared()
		suu += offset.x * offset.x
		svv += offset.y * offset.y
		suv += offset.x * offset.y
		suz += offset.x * z
		svz += offset.y * z
		sz += z
	var det: float = suu * svv - suv * suv
	if is_zero_approx(det):
		return Vector4(mean.x, mean.y, 0.0, INF)
	var centre: Vector2 = mean + Vector2((suz * svv - svz * suv) / det, (svz * suu - suz * suv) / det) / 2.0
	var radius: float = sqrt((centre - mean).length_squared() + sz / float(points.size()))
	var worst: float = 0.0
	for point: Vector2 in points:
		worst = maxf(worst, absf(point.distance_to(centre) - radius))
	return Vector4(centre.x, centre.y, radius, worst)


## slow_roll (AC-1): a stick pressed only a little (an action pressed by a call has no dead zone) rolls each ground type at SLOW_SPEED, under the speed (the minimum step a tick) at which a tyre
## moves enough on every tick, for SLOW_TICKS: the tyres keep their last place until they have moved the minimum step and then stroke from it, so a slow roll still
## draws: strokes come on about every other tick, each longer than the minimum step, each from a place its tyre touched the ground (the audit's slow-roll rule),
## and the strokes of the first tyre add up to the distance it travelled, less the part not yet long enough to draw.
func _slow_roll() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	for type_index: int in GROUND_TYPES:
		await _stage(type_index)
		var stats: UnitStats = _q.units.stats(type_index)
		for player: int in Kit26.Kit.PLAYERS:
			Input.action_press(Kit26.Kit25.Kit21.THROTTLE_ACTIONS[player], SLOW_SPEED / stats.max_speed)
		_k.begin_rows()
		await _q.kit.advance(SLOW_TICKS)
		for player: int in Kit26.Kit.PLAYERS:
			Input.action_release(Kit26.Kit25.Kit21.THROTTLE_ACTIONS[player])
		_q.harness.release_all()
		var rows: Array[Dictionary] = _k.end_rows()
		_q.kit.need(problems, Kit26.touched_nothing(rows), "%s: the Units touched something but the ground on %s ticks" % [_q.units.stats(type_index).type_id, Kit26.touches(rows)])
		var minimum: float = _k.tracks().settings.min_step
		for player: int in Kit26.Kit.PLAYERS:
			var length: float = 0.0
			var made: int = 0
			for index: int in range(2, rows.size()):
				for stroke: Dictionary in Kit26.strokes_of(rows[index], player):
					if int(stroke["tyre"]) == 0:
						length += (stroke["from"] as Vector2).distance_to(stroke["to"] as Vector2)
						made += 1
						_q.kit.need(problems, (stroke["from"] as Vector2).distance_to(stroke["to"] as Vector2) > minimum, "%s Player %d: a stroke of %.4f m, not over the minimum step %.3f m" % [stats.type_id, player + 1, (stroke["from"] as Vector2).distance_to(stroke["to"] as Vector2), minimum])
					var problem: String = Kit26.stroke_problem(rows, index, player, stroke, SLOW_TICKS) if index >= Kit26.EDGE_ROWS else ""
					_q.kit.need(problems, problem.is_empty(), problem)
			var travelled: float = Kit26.contact(rows[2], player, 0).distance_to(Kit26.contact(rows[rows.size() - 1], player, 0))
			var speed: float = float((rows[rows.size() - 1]["speed"] as Array)[player])
			_q.kit.need(problems, speed > 0.0 and speed < minimum * float(Engine.physics_ticks_per_second), "%s Player %d: the roll is at %.3f m/s, not under %.2f m/s" % [stats.type_id, player + 1, speed, minimum * float(Engine.physics_ticks_per_second)])
			_q.kit.need(problems, made >= SLOW_TICKS / 4 and absf(length - travelled) <= minimum * 2.0, "%s Player %d: %d strokes of the first tyre add up to %.4f m, the tyre travelled %.4f m" % [stats.type_id, player + 1, made, length, travelled])
			checked += made
	measured.append("slow_strokes=%d" % checked)
	_q.kit.verdict("slow_roll", problems, "each ground type, both Players, on a stick pressed a little (about %.1f m/s, under the %.2f m/s at which a tyre moves the minimum step on every tick) for %d ticks: %d strokes of the first tyres, each longer than the minimum step and from a place the tyre touched the ground, adding up to the distance travelled" % [SLOW_SPEED, _k.tracks().settings.min_step * float(Engine.physics_ticks_per_second), SLOW_TICKS, checked])


## spot_turn (AC-1): throttle released and the stick held, a Unit turns on the spot (spot_turn_rate) for one whole turn, and its tyres' strokes
## make a ring: every stroke ends at its tyre's distance from the Unit's middle, and the strokes of the first tyre sweep an angle that is the
## yaw the Unit turned within a twentieth and, with the Unit's turn, all the way round.
func _spot_turn() -> void:
	var problems: PackedStringArray = []
	var swept_all: PackedStringArray = []
	for type_index: int in GROUND_TYPES:
		await _stage(type_index)
		var stats: UnitStats = _q.units.stats(type_index)
		var ticks: int = int(ceil(TAU / stats.spot_turn_rate * float(Engine.physics_ticks_per_second)))
		var rows: Array[Dictionary] = await _k.record([Kit26.plan([[ticks, 0, 1]]), Kit26.plan([[ticks, 0, 1]])])
		_q.kit.need(problems, Kit26.touched_nothing(rows), "%s: the Units touched something but the ground on %s ticks" % [_q.units.stats(type_index).type_id, Kit26.touches(rows)])
		for player: int in Kit26.Kit.PLAYERS:
			var swept: float = 0.0
			var first_row: int = -1
			for index: int in range(2, rows.size()):
				var middle: Vector3 = ((rows[index - 1]["poses"] as Array)[player] as Transform3D).origin
				for stroke: Dictionary in Kit26.strokes_of(rows[index], player):
					var tyre: TyreContact = stats.tyres[int(stroke["tyre"])]
					var centre: Vector2 = Vector2(middle.x, middle.z)
					var radius: float = (stroke["to"] as Vector2).distance_to(centre)
					_q.kit.need(problems, absf(radius - tyre.offset.length()) <= RING_RADIUS_TOLERANCE, "%s Player %d row %d: stroke %.4f m from the middle, tyre %.4f m" % [stats.type_id, player + 1, index, radius, tyre.offset.length()])
					if int(stroke["tyre"]) == 0:
						first_row = index if first_row < 0 else first_row
						swept += ((stroke["from"] as Vector2) - centre).angle_to((stroke["to"] as Vector2) - centre)
			var turned: float = 0.0
			for index: int in range(maxi(first_row - 1, 1), rows.size()):
				turned += wrapf(_yaw(rows[index], player) - _yaw(rows[index - 1], player), -PI, PI)
			_q.kit.need(problems, first_row >= 0 and absf(absf(swept) - absf(turned)) <= ANGLE_SHARE * absf(turned), "%s Player %d: strokes sweep %.3f rad, the Unit turned %.3f" % [stats.type_id, player + 1, swept, turned])
			_q.kit.need(problems, absf(swept) >= TAU - RING_SHORT, "%s Player %d: the ring stops at %.3f rad of %.3f" % [stats.type_id, player + 1, absf(swept), TAU])
			swept_all.append("%s %.2f" % [stats.type_id, absf(swept)])
	_q.kit.verdict("spot_turn", problems, "a whole turn on the spot of each ground type, both Players: every stroke ends at its tyre's distance from the Unit's middle (within %.3f m) and the strokes of the first tyre sweep the yaw the Unit turned, all the way round (radians: %s)" % [RING_RADIUS_TOLERANCE, ", ".join(swept_all)])


## The yaw of a Player's Unit after the tick a row is of, radians, from its basis (it wraps at pi: the caller takes differences).
func _yaw(row: Dictionary, player: int) -> float:
	return ((row["poses"] as Array)[player] as Transform3D).basis.get_euler().y
