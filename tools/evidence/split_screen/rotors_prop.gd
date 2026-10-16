extends RefCounted
## The pusher propeller's rate for the rotors scenario (Story 025 AC-3): propeller (both Players' Gyrocopters, with real keys
## and a stick pressed half way: standing, the propeller turns at its idle rate; at half its top speed, half way between the idle
## and the full rate; at its top speed forward, and at its top speed in reverse, at the full rate; on every tick its rate is the
## straight line from the idle rate to the full one at the Unit's speed share, which rises with the speed; and the main rotor
## keeps its one rate in every case; and, for the story's question 5, a badly damaged Gyrocopter, whose top speed is the state's share of
## its type's, turns its propeller at the rate of the speed it really has and its rotor at the rate of a whole one's). Every row is the watch's (rotors_watch.gd), read after the pivots' own tick. Run by
## rotors.gd. Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where Player 1 stands to start a case (the open middle of the Map, 30 m west of its middle, facing east); Player 2 stands at the
## mirror across x = 0 facing west.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## The cases: [name, throttle (a share of full: 1 and -1 are the real keys, between is a stick), ticks held].
const CASES: Array = [["standing", 0.0, 60], ["half", 0.5, 150], ["full", 1.0, 100], ["reverse", -1.0, 100]]
## The ticks at the end of a case in which the speed is judged to have settled, and what it may differ from the speed it should
## have by there, metres a second (the Unit's top speed is reached asymptotically and its body floats on a millimetre of margin).
const SETTLED_TICKS: int = 20
## The share of its hit points a Gyrocopter has left in the badly damaged case (the state begins at 20%), and the ticks it flies at full throttle.
const HURT_SHARE: float = 0.15
const HURT_TICKS: int = 120
const SPEED_SLACK: float = 0.05
## What a rate may differ from the straight line of the speed share by, turns a second.
const RATE_TOLERANCE: float = 0.000000001
## What a rate at a settled speed may differ from the rate that speed should give, turns a second.
const RATE_SLACK: float = 0.02

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick
var _settings: RotorSettings


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()
	_settings = kit.settings()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.walls().turrets_down()
	await _propeller()
	await _badly_damaged()


## Both Players' sticks held for `ticks` ticks: 1 or -1 the real throttle or reverse key, a share between a stick pressed that far.
func _hold(throttle: float, ticks: int) -> void:
	var stick: bool = throttle > 0.0 and throttle < 1.0
	if stick:
		for player: int in 2:
			Input.action_press(Kit25.Kit21.THROTTLE_ACTIONS[player], throttle)
	for _tick: int in ticks:
		for player: int in 2:
			_q.harness.drive(player, 1 if throttle >= 1.0 else (-1 if throttle <= -1.0 else 0), 0)
		await _q.kit.tick()
	if stick:
		for player: int in 2:
			Input.action_release(Kit25.Kit21.THROTTLE_ACTIONS[player])
	_q.harness.release_all()


## propeller (AC-3): see the class doc.
func _propeller() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var rotor: RotorPart = _settings.parts[0]
	var propeller: RotorPart = _settings.parts[1]
	var stats: UnitStats = _q.units.stats(Kit25.GYRO)
	var cases_rates: Dictionary = {}
	for entry: Array in CASES:
		var case_name: String = entry[0]
		var throttle: float = entry[1]
		var ticks: int = entry[2]
		await _q.map.stage([Kit25.GYRO, Kit25.GYRO], [OPEN, Vector3(-OPEN.x, OPEN.y, OPEN.z)], [Vector3.RIGHT, Vector3.LEFT], true)
		_k.watch.clear()
		_k.watch.logging = true
		await _hold(throttle, ticks)
		_k.watch.logging = false
		var target: float = 0.0 if throttle == 0.0 else (stats.max_speed * throttle if throttle > 0.0 else -stats.reverse_max_speed)
		var share: float = absf(target) / (stats.max_speed if throttle >= 0.0 else stats.reverse_max_speed)
		var expected_rate: float = propeller.turns_per_second(share)
		for player: int in 2:
			var rows: Array = _k.watch.rows[player]
			_q.kit.need(problems, rows.size() == ticks, "%s, Player %d: %d rows, expected %d" % [case_name, player + 1, rows.size(), ticks])
			var last_share: float = -1.0
			var last_rate: float = -1.0
			var rising: bool = true
			var worst: float = 0.0
			var strictly: bool = false
			for index: int in rows.size():
				var row: Dictionary = rows[index]
				var read: Dictionary = _find(row, "Propeller")
				var steady: Dictionary = _find(row, "Rotor")
				_q.kit.need(problems, not read.is_empty() and not steady.is_empty() and float(steady["rate"]) == rotor.full_turns_per_second, "%s, Player %d, row %d: the rotor reads %s, not its steady %s turns a second" % [case_name, player + 1, index, steady, rotor.full_turns_per_second])
				if read.is_empty():
					break
				worst = maxf(worst, absf(float(read["rate"]) - propeller.turns_per_second(float(row["share"]))))
				if float(row["share"]) >= last_share and last_share >= 0.0:
					rising = rising and float(read["rate"]) >= last_rate - RATE_TOLERANCE
					strictly = strictly or float(read["rate"]) > last_rate + RATE_TOLERANCE
				last_share = float(row["share"])
				last_rate = float(read["rate"])
			_q.kit.need(problems, worst <= RATE_TOLERANCE, "%s, Player %d: a rate stood %s turns a second from the straight line of the speed share" % [case_name, player + 1, worst])
			_q.kit.need(problems, rising and (strictly or throttle == 0.0), "%s, Player %d: the rate did not rise with the speed share" % [case_name, player + 1])
			var tail: Array = rows.slice(rows.size() - SETTLED_TICKS)
			var worst_speed: float = 0.0
			var worst_rate: float = 0.0
			for row: Dictionary in tail:
				worst_speed = maxf(worst_speed, absf(float(row["along"]) - target))
				worst_rate = maxf(worst_rate, absf(float(_find(row, "Propeller")["rate"]) - expected_rate))
			_q.kit.need(problems, worst_speed <= SPEED_SLACK and worst_rate <= RATE_SLACK, "%s, Player %d: over the last %d ticks the speed stood %.3f m/s from %.2f and the rate %.4f from %.4f turns a second" % [case_name, player + 1, SETTLED_TICKS, worst_speed, target, worst_rate, expected_rate])
			cases_rates["%s_%d" % [case_name, player]] = float(_find(rows[-1], "Propeller")["rate"])
		notes.append("%s: speed %.2f m/s (%.2f of the top), propeller %.3f turns a second" % [case_name, target, share, expected_rate])
	_q.kit.need(problems, is_equal_approx(propeller.turns_per_second(0.5), (propeller.idle_turns_per_second + propeller.full_turns_per_second) / 2.0), "half the top speed does not give half way between the rates")
	measured.append("propeller_rates=%.3f/%.3f/%.3f/%.3f" % [cases_rates["standing_0"], cases_rates["half_0"], cases_rates["full_0"], cases_rates["reverse_0"]])
	_q.kit.verdict("propeller", problems, "on every tick of both Players' flights the propeller's rate was the straight line from %s to %s turns a second at the speed share (within %s turns a second) and rose with the speed; settled, it read %s; the main rotor stayed at %s turns a second throughout" % [propeller.idle_turns_per_second, propeller.full_turns_per_second, RATE_TOLERANCE, "; ".join(notes), rotor.full_turns_per_second])


## The pivot entry of a row by part name.
func _find(row: Dictionary, part_name: String) -> Dictionary:
	for pivot: Dictionary in row["pivots"]:
		if pivot["name"] == part_name:
			return pivot
	return {}


## badly_damaged (the story's question 5): both Players' Gyrocopters at 15% of their hit points, flown at full throttle, settle at the
## state's share of the type's top speed (half, 8.2 m/s), where the propeller turns at the rate that speed share gives (half way
## between its idle and full rates: the share is judged against the type's own top speed, not the reduced one) and the rotor at its
## steady rate: the propeller follows the speed the Gyrocopter has, the rotor does not slow.
func _badly_damaged() -> void:
	var problems: PackedStringArray = []
	var rotor: RotorPart = _settings.parts[0]
	var propeller: RotorPart = _settings.parts[1]
	var stats: UnitStats = _q.units.stats(Kit25.GYRO)
	await _q.map.stage([Kit25.GYRO, Kit25.GYRO], [OPEN, Vector3(-OPEN.x, OPEN.y, OPEN.z)], [Vector3.RIGHT, Vector3.LEFT], true)
	for player: int in 2:
		var unit: Unit = _q.units.units[player]
		unit.apply_damage(unit.hit_points - stats.max_hit_points * HURT_SHARE)
		_q.kit.need(problems, unit.is_badly_damaged, "Player %d's Gyrocopter is not badly damaged at %.0f%% of its hit points" % [player + 1, HURT_SHARE * 100.0])
	_k.watch.clear()
	_k.watch.logging = true
	await _hold(1.0, HURT_TICKS)
	_k.watch.logging = false
	var target: float = stats.max_speed * stats.badly_damaged_speed_share
	var expected_rate: float = propeller.turns_per_second(target / stats.max_speed)
	var notes: PackedStringArray = []
	for player: int in 2:
		var tail: Array = _k.watch.rows[player].slice(_k.watch.rows[player].size() - SETTLED_TICKS)
		var worst_speed: float = 0.0
		var worst_rate: float = 0.0
		var steady: bool = true
		for row: Dictionary in tail:
			worst_speed = maxf(worst_speed, absf(float(row["along"]) - target))
			worst_rate = maxf(worst_rate, absf(float(_find(row, "Propeller")["rate"]) - expected_rate))
			steady = steady and float(_find(row, "Rotor")["rate"]) == rotor.full_turns_per_second
		_q.kit.need(problems, worst_speed <= SPEED_SLACK and worst_rate <= RATE_SLACK and steady, "Player %d, badly damaged: over the last %d ticks the speed stood %.3f m/s from %.2f, the propeller's rate %.4f from %.4f turns a second, the rotor steady %s" % [player + 1, SETTLED_TICKS, worst_speed, target, worst_rate, expected_rate, steady])
		notes.append("Player %d settled at %.2f m/s with the propeller at %.3f turns a second" % [player + 1, float(tail[-1]["along"]), float(_find(tail[-1], "Propeller")["rate"])])
	measured.append("badly_damaged_propeller=%.3f" % expected_rate)
	_q.kit.verdict("propeller_badly_damaged", problems, "at %.0f%% of their hit points both Gyrocopters settle at %.2f m/s, %s of the type's top speed, and the propeller turns at %.3f turns a second, the rate of the speed it has (%s), while the rotor keeps its steady %s turns a second" % [HURT_SHARE * 100.0, target, stats.badly_damaged_speed_share, expected_rate, "; ".join(notes), rotor.full_turns_per_second])
