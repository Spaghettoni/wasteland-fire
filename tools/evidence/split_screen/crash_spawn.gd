extends RefCounted
## A spawn is never an arrival, for the crash scenario (Story 021 AC-5): spawn_never (a Gyrocopter appearing in its Garage at the Round's
## first spawn, at a respawn after a crash and after a Swap at the own Base, each with the Player holding the throttle from before
## it appeared, does not crash on its spawn tick or after it, flies out of the Base and lives; and one put down by a tool flush
## against a leg, on top of the motion of a life that was flying at the leg, carries none of that life's motion) and garage_exits (a
## Gyrocopter flown at full throttle straight out of each Garage spot of both Bases leaves the Base alive, no piece touched). It must
## run first in a run that makes the Round's first spawn: crash.gd leaves the Players' first choice to it. Run by crash.gd. Tooling
## only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")

## The ticks a Gyrocopter is followed after it appears, with the throttle held: long enough to leave a Base and its Gate by a long way.
const OUT_TICKS: int = 150
## The Base-local z past which a Gyrocopter has left the Base: beyond the Gate wall and the corner towers (z = -15 at the towers).
const LEFT_THE_BASE_Z: float = -20.0
## The ticks the previous life flies at the leg before a tool puts the next one down, and the gaps (m) between the leg's face and the
## nose of the new one (flush, the contact margin, and clear).
const PRIOR_TICKS: int = 40
const FLUSH_GAPS: Array[float] = [0.0, 0.05, 0.5]
## The ticks a flush spawn is followed.
const FLUSH_FOLLOW: int = 60

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick
var _problems: PackedStringArray = []
var _notes: PackedStringArray = []


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().restore_all(true)
	await _first_spawn()
	await _respawn_after_a_crash()
	await _spawn_after_a_swap()
	await _flush_on_a_prior_life()
	_q.kit.verdict("spawn_never", _problems, "a Gyrocopter that appeared with the Player already holding the throttle (the Round's first spawn, the respawn after a crash, the spawn after a Swap) or was put down flush against a leg by a tool did not crash on its spawn tick or after it: %s" % "; ".join(_notes))
	await _garage_exits()


## The row of a Player's rows from which the current life began: the first alive row after the last row it was not alive in (0 when
## it was alive on every row). -1 when it was alive on none.
func _born(player: int) -> int:
	var rows: Array = _k.watch.rows[player]
	var last_dead: int = -1
	for index: int in rows.size():
		if not bool(rows[index]["alive"]):
			last_dead = index
	return last_dead + 1 if last_dead + 1 < rows.size() else -1


## What a life that began at `born` did with the throttle held: alive on every row from it, no wall's collision but at most one on
## its first tick (a body whose teleport has not reached the physics space yet still touches what stood there, at zero arrival), and
## out of the Base. Adds the problems it finds, returns a note.
func _judge_life(label: String, player: int, born: int) -> String:
	var unit: Unit = _q.units.units[player]
	var base: Base = _k.flags().bases[player]
	var life: Dictionary = _k.watch.summary(player, maxi(born, 0))
	var out_z: float = base.to_local(unit.global_position).z
	_q.kit.need(_problems, born >= 0 and life["alive"] and unit.is_alive, "%s: born at row %d, alive on every row %s, alive now %s" % [label, born, life["alive"], unit.is_alive])
	var first_wall: int = _k.watch.first_wall(player, maxi(born, 0))
	var lagging: bool = int(life["wall_ticks"]) == 1 and first_wall == born
	_q.kit.need(_problems, (int(life["wall_ticks"]) == 0 or lagging) and float(life["max_arrival"]) < _k.crash_speed() and unit.hit_points == unit.stats.max_hit_points, "%s: %d ticks with a wall's collision (%s, the first at row %d, the largest arrival %.3f m/s), %.1f of %.1f hit points" % [label, life["wall_ticks"], str((life["walls"] as Dictionary).keys()), first_wall, life["max_arrival"], unit.hit_points, unit.stats.max_hit_points])
	_q.kit.need(_problems, out_z < LEFT_THE_BASE_Z and float(life["max_real"]) >= 0.99 * _k.gyro_stats().max_speed, "%s: left the Base to z %.1f (past %.0f) at %.2f m/s" % [label, out_z, LEFT_THE_BASE_Z, life["max_real"]])
	var lag_note: String = ", its first tick still touching %s where the last life ended (the teleport reaches the physics space a tick late), arriving at %.3f m/s" % [str((life["walls"] as Dictionary).keys()[0]).get_file(), life["max_arrival"]] if lagging else ""
	return "%s: %d ticks alive%s, out to Base-local z %.1f at %.1f m/s" % [label, life["ticks"], lag_note, out_z, life["max_real"]]


## The Round's first spawn (AC-5): both Players hold the throttle before they choose, and each Gyrocopter appears in its Garage and
## drives out of the Base at once.
func _first_spawn() -> void:
	_k.watch.clear()
	_k.watch.logging = true
	for player: int in Kit21.Kit.PLAYERS:
		_q.harness.drive(player, 1, 0)
	for player: int in Kit21.Kit.PLAYERS:
		_q.kit.need(_problems, await _q.tokens.spawn(player, Kit21.GYRO), "the Round's first spawn: player %d's Gyrocopter did not appear" % (player + 1))
	await _q.kit.advance(OUT_TICKS)
	_k.watch.logging = false
	_q.harness.release_all()
	for player: int in Kit21.Kit.PLAYERS:
		_notes.append(_judge_life("the Round's first spawn, player %d" % (player + 1), player, _born(player)))


## A respawn after a crash (AC-5): Player 1 flies at a leg and crashes with the throttle held, keeps it held through the wait,
## chooses the Gyrocopter again with its keys, and the new life drives out of the Garage at once and lives.
func _respawn_after_a_crash() -> void:
	var flight_line: Dictionary = _k.line(Kit21.path_of("leg", 0), Kit21.toward(0))
	await _k.stage(0, Kit21.GYRO, flight_line["start"], flight_line["dir"])
	var unit: Unit = _q.units.units[0]
	_k.watch.clear()
	_k.watch.logging = true
	for _tick: int in Kit21.FLIGHT_LIMIT:
		_q.harness.drive(0, 1, 0)
		await _q.kit.tick()
		if not unit.is_alive:
			break
	var died: int = _k.watch.rows[0].size() - 1
	_q.kit.need(_problems, not unit.is_alive and not _q.controller.is_alive(0), "the respawn after a crash: the Gyrocopter did not crash")
	_q.kit.need(_problems, await _q.tokens.spawn(0, Kit21.GYRO), "the respawn after a crash: the Gyrocopter did not appear again")
	await _q.kit.advance(OUT_TICKS)
	_k.watch.logging = false
	_q.harness.release_all()
	_notes.append(_judge_life("the respawn after a crash at row %d, throttle held throughout" % died, 0, _born(0)))


## A spawn after a Swap at the own Base (AC-5): Player 1's Gyrocopter stands on its Garage spot and swaps by its Self-destruct key,
## then holds the throttle and chooses the Gyrocopter again.
func _spawn_after_a_swap() -> void:
	var base: Base = _k.flags().bases[0]
	var spot: Marker3D = base.spawn_point
	await _k.stage(0, Kit21.GYRO, spot.global_position, -spot.global_transform.basis.z)
	await _k.swap().wait_swappable(0)
	var swaps: int = _k.swap().swaps.size()
	_k.watch.clear()
	_k.watch.logging = true
	await _q.tokens.destruct(0)
	_q.kit.need(_problems, _k.swap().swaps.size() == swaps + 1 and not _q.units.units[0].is_alive, "the spawn after a Swap: %d Swaps were made and the Unit is alive %s" % [_k.swap().swaps.size() - swaps, _q.units.units[0].is_alive])
	_q.harness.drive(0, 1, 0)
	_q.kit.need(_problems, await _q.tokens.spawn(0, Kit21.GYRO), "the spawn after a Swap: the Gyrocopter did not appear")
	await _q.kit.advance(OUT_TICKS)
	_k.watch.logging = false
	_q.harness.release_all()
	_notes.append(_judge_life("the spawn after a Swap, throttle held", 0, _born(0)))


## A spawn by a tool on top of a life's motion (AC-5): Player 1's Gyrocopter flies at a leg for PRIOR_TICKS, is benched while it moves at
## about 10 m/s toward the leg, and the next one is put down flush against the leg's face, facing it, with the throttle held: it
## carries none of the last life's motion, so it is alive FLUSH_FOLLOW ticks later, pinned or creeping, and never crashes.
func _flush_on_a_prior_life() -> void:
	var leg: String = Kit21.path_of("leg", 0)
	var half: float = _k.gyro_stats().collision_size.z / 2.0
	var leg_box: AABB = _k.box(leg)
	var unit: Unit = _q.units.units[0]
	for gap: float in FLUSH_GAPS:
		var flight_line: Dictionary = _k.line(leg, Kit21.toward(0))
		await _k.stage(0, Kit21.GYRO, flight_line["start"], flight_line["dir"])
		for _tick: int in PRIOR_TICKS:
			_q.harness.drive(0, 1, 0)
			await _q.kit.tick()
		var prior: float = Watch.flat(unit.get_real_velocity())
		unit.leave_play()
		var at: Vector3 = Vector3(leg_box.end.x + half + gap, 0.0, leg_box.get_center().z)
		_k.watch.clear()
		_k.watch.logging = true
		_q.harness.drive(0, 1, 0)
		_q.units.retype(0, Kit21.GYRO, at, Kit21.toward(0))
		for _tick: int in FLUSH_FOLLOW:
			_q.harness.drive(0, 1, 0)
			await _q.kit.tick()
		_k.watch.logging = false
		_q.harness.release_all()
		var life: Dictionary = _k.watch.summary(0)
		_q.kit.need(_problems, prior > _k.crash_speed() and life["alive"] and unit.is_alive, "flush spawn at %.2f m after a life at %.2f m/s: alive %s" % [gap, prior, unit.is_alive])
		_q.kit.need(_problems, float(life["max_arrival"]) < _k.crash_speed(), "flush spawn at %.2f m: the largest arrival was %.3f m/s" % [gap, life["max_arrival"]])
		_notes.append("put down %.2f m from a leg's face after a life flying at it at %.1f m/s (over the crash speed): alive %d ticks, the largest arrival %.2f m/s, contact on %d ticks" % [gap, prior, life["ticks"], life["max_arrival"], life["wall_ticks"]])
	measured.append("flush_spawns=%d" % FLUSH_GAPS.size())


## garage_exits (AC-5): a Gyrocopter flown at full throttle straight out of each of the Garage's spots at both Bases, the way the
## Garage faces, leaves the Base alive with no piece touched; the nearest leg is passed with room to spare.
func _garage_exits() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var unit: Unit = _q.units.units[0]
	var runs: int = 0
	for base_index: int in Kit21.Kit.PLAYERS:
		var base: Base = _k.flags().bases[base_index]
		var spots: Array[Marker3D] = [base.spawn_point]
		spots.append_array(base.spare_spawn_points)
		for spot: Marker3D in spots:
			var out: Vector3 = -spot.global_transform.basis.z
			var flight: Dictionary = await _k.fly(0, Kit21.GYRO, spot.global_position, out, OUT_TICKS)
			var summary: Dictionary = _k.watch.summary(0)
			var out_z: float = base.to_local(unit.global_position).z
			_q.kit.need(problems, flight["dead"] < 0 and flight["hit"] < 0 and unit.is_alive and out_z < LEFT_THE_BASE_Z, "Base %d, %s: dead at row %d, first wall's collision at row %d, out to z %.1f" % [base_index + 1, spot.name, flight["dead"], flight["hit"], out_z])
			notes.append("Base %d %s: out to Base-local z %.1f at %.1f m/s, no contact" % [base_index + 1, spot.name, out_z, summary["max_real"]])
			runs += 1
	measured.append("garage_exits=%d" % runs)
	_q.kit.verdict("garage_exits", problems, "flown at full throttle straight out of each of the %d Garage spots of both Bases, the way they face, a Gyrocopter left the Base alive without touching a piece: %s" % [runs, "; ".join(notes)])
