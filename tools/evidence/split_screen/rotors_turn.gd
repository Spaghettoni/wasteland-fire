extends RefCounted
## The rotor's turn for the rotors scenario (Story 025 AC-1 and AC-4): turn (the main rotor turns by the same step on every tick,
## 4 turns a second, while a Gyrocopter stands, flies at full throttle and backs up, for both Players), strobe (no blade of
## either part moves more than the strobe share of the gap between two blades in a tick, the propeller at its full rate
## included), out_of_play (a Gyrocopter's model is drawn exactly while the Unit is in play; out of play, after a destruction in
## the open and after a Swap at the own Base, its parts stand at angle 0, and a new Gyrocopter's rotor starts from rest and
## turns by the same step from its first tick; the other Player's rotor is never disturbed) and round_over (the Round ends by a
## real Flag delivery: the parts stand still under the Round-over screen and turn again in the next Round). Every row is the
## watch's (rotors_watch.gd), read after the pivots' own tick. Run by rotors.gd. Tooling only. Every number comes from the game's
## data; the scenario types only its test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Gate side a Flag is taken at.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## Where Player 1's Gyrocopter stands and flies from: the open middle of the Map, clear of both Bases' Turrets, 30 m west of its
## middle, facing east. Ticks it stands, flies at full throttle and backs up while the rows are filed.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
const STAND_TICKS: int = 240
const FLY_TICKS: int = 120
const BACK_TICKS: int = 60
## What an angle may differ from the step it should have grown by, radians (a double's rounding over the wraps).
const ANGLE_TOLERANCE: float = 0.000000001
## Ticks a destroyed or benched Unit is watched for before its Player chooses again, and ticks a new Gyrocopter is watched for.
const GONE_TICKS: int = 30
const LIFE_TICKS: int = 60
## Ticks the Round-over screen is watched for.
const FROZEN_TICKS: int = 45

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick
var _settings: RotorSettings
## The rows of the flight of turn(), for strobe(): [Player 1's, Player 2's].
var _flight: Array[Array] = [[], []]


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()
	_settings = kit.settings()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.walls().turrets_down()
	await _turn()
	_strobe()
	await _out_of_play()
	await _round_over()


## The turn a tick of a part makes, radians.
func _step(part: RotorPart, turns_per_second: float) -> float:
	return TAU * turns_per_second / Engine.physics_ticks_per_second


## The part's pivot entry of a row, by name; an empty Dictionary when the row has none.
func _of(row: Dictionary, part_name: String) -> Dictionary:
	for pivot: Dictionary in row["pivots"]:
		if pivot["name"] == part_name:
			return pivot
	return {}


## turn (AC-1): both Players' Gyrocopters in play, Player 1 staged in the open and standing, then flown at full throttle and
## backed up; on every tick of both Players the rotor is in the Unit's model, drawn, and has turned by the step of 4 turns a
## second since the tick before, at the rate of 4 turns a second, whatever the speed.
func _turn() -> void:
	var problems: PackedStringArray = []
	await _k.k.stage(0, Kit25.GYRO, OPEN, Vector3.RIGHT)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(STAND_TICKS)
	await _k.k.drive(0, FLY_TICKS, 1.0)
	await _k.k.drive(0, BACK_TICKS, -1.0)
	_k.watch.logging = false
	_flight = [_k.watch.rows[0].duplicate(), _k.watch.rows[1].duplicate()]
	var rotor: RotorPart = _settings.parts[0]
	var step: float = _step(rotor, rotor.full_turns_per_second)
	var fastest: float = 0.0
	var slowest: float = INF
	var counts: PackedStringArray = []
	for player: int in 2:
		var rows: Array = _flight[player]
		var worst: float = 0.0
		var speeds: Vector2 = Vector2(INF, -INF)
		_q.kit.need(problems, rows.size() == STAND_TICKS + FLY_TICKS + BACK_TICKS, "Player %d: %d rows were filed, expected %d" % [player + 1, rows.size(), STAND_TICKS + FLY_TICKS + BACK_TICKS])
		for index: int in rows.size():
			var row: Dictionary = rows[index]
			var entry: Dictionary = _of(row, "Rotor")
			if not (bool(row["alive"]) and bool(row["shown"]) and not entry.is_empty() and float(entry["rate"]) == rotor.full_turns_per_second):
				_q.kit.need(problems, false, "Player %d, row %d: alive %s, shown %s, the rotor reads %s" % [player + 1, index, row["alive"], row["shown"], entry])
				break
			speeds = Vector2(minf(speeds.x, float(row["along"])), maxf(speeds.y, float(row["along"])))
			_q.kit.need(problems, float(entry["angle"]) >= 0.0 and float(entry["angle"]) < TAU, "Player %d, row %d: the rotor's angle %.6f is not under a whole turn" % [player + 1, index, entry["angle"]])
			if index > 0:
				var grown: float = wrapf(float(entry["angle"]) - float(_of(rows[index - 1], "Rotor")["angle"]), -PI, PI)
				worst = maxf(worst, absf(grown - step))
				fastest = maxf(fastest, grown)
				slowest = minf(slowest, grown)
		_q.kit.need(problems, worst <= ANGLE_TOLERANCE, "Player %d's rotor turned %.12f rad a tick off the step %.9f at worst" % [player + 1, worst, step])
		counts.append("P%d %d ticks, speeds %.1f to %.1f m/s, worst step error %s rad" % [player + 1, rows.size(), speeds.x, speeds.y, worst])
	_q.kit.need(problems, fastest - slowest <= ANGLE_TOLERANCE * 2.0, "the rotor's biggest step was %.12f rad and its smallest %.12f" % [fastest, slowest])
	measured.append("rotor_step_deg=%.6f" % rad_to_deg(step))
	_q.kit.verdict("turn", problems, "on all %d ticks of both Players (%s) the rotor, drawn in the model of a Gyrocopter in play, turned %.6f degrees (4 turns a second over %d ticks) from the tick before, within %s rad, at 4 turns a second while the Gyrocopter stood for %d ticks, flew at full throttle for %d (up to its top speed) and backed up for %d" % [_flight[0].size(), "; ".join(counts), rad_to_deg(step), Engine.physics_ticks_per_second, ANGLE_TOLERANCE, STAND_TICKS, FLY_TICKS, BACK_TICKS])


## strobe (AC-4): over the rows of the flight, no part of either Player's Gyrocopter moved a blade more than the strobe share of
## the gap between two blades in a tick; the biggest of each part is measured (the propeller's at its full rate).
func _strobe() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for part: RotorPart in _settings.parts:
		var biggest: float = 0.0
		var lowest: float = INF
		var samples: int = 0
		for player: int in 2:
			var rows: Array = _flight[player]
			for index: int in range(1, rows.size()):
				var grown: float = wrapf(float(_of(rows[index], part.resource_name)["angle"]) - float(_of(rows[index - 1], part.resource_name)["angle"]), -PI, PI)
				var share: float = grown / part.blade_gap()
				biggest = maxf(biggest, share)
				lowest = minf(lowest, share)
				samples += 1
		_q.kit.need(problems, samples > 0 and biggest <= _settings.strobe_share and lowest > 0.0, "%s: a blade moved %.4f of a gap in a tick at most (the share %.2f), %.4f at least" % [part.resource_name, biggest, _settings.strobe_share, lowest])
		notes.append("%s moved a blade %.4f of the gap between two at most and %.4f at least in a tick over %d samples" % [part.resource_name.to_lower(), biggest, lowest, samples])
		measured.append("%s_step_share_max=%.4f" % [part.resource_name.to_lower(), biggest])
	_q.kit.verdict("strobe", problems, "%s; the strobe share is %.2f and no sample was over it, and every sample was forward (the part turns the one way)" % ["; ".join(notes), _settings.strobe_share])


## One Player's rows of a stretch in which its Unit went out of play and came back, judged: a row's model is drawn exactly when the
## Unit is alive; a row that is not drawn holds every part at angle 0 and a rate of 0; the first drawn row after one that is not
## holds the rotor at rest (a new model is made inside the controller's tick, and its parts' first physics tick is the next one)
## and every later row one step on from the row before. Returns {hidden (rows not drawn), lives (drawn stretches), first (the
## first drawn row's angle in steps of the rotor)}.
func _judge_rows(rows: Array, label: String, problems: PackedStringArray) -> Dictionary:
	var rotor: RotorPart = _settings.parts[0]
	var step: float = _step(rotor, rotor.full_turns_per_second)
	var hidden: int = 0
	var lives: int = 0
	var first: PackedFloat64Array = PackedFloat64Array()
	var previous_shown: bool = false
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var shown: bool = bool(row["shown"])
		_q.kit.need(problems, shown == bool(row["alive"]), "%s, row %d: the model is drawn (%s) but the Unit is alive (%s)" % [label, index, shown, row["alive"]])
		for pivot: Dictionary in row["pivots"]:
			if not shown:
				_q.kit.need(problems, float(pivot["angle"]) == 0.0 and float(pivot["rate"]) == 0.0, "%s, row %d: %s stands at %.6f rad at %.2f turns a second while the model is not drawn" % [label, index, pivot["name"], pivot["angle"], pivot["rate"]])
		if not shown:
			hidden += 1
		else:
			var angle: float = float(_of(row, "Rotor")["angle"])
			if previous_shown:
				var grown: float = wrapf(angle - float(_of(rows[index - 1], "Rotor")["angle"]), -PI, PI)
				_q.kit.need(problems, absf(grown - step) <= ANGLE_TOLERANCE, "%s, row %d: the rotor turned %.9f rad from the row before, the step is %.9f" % [label, index, grown, step])
			else:
				lives += 1
				first.append(angle / step)
		previous_shown = shown
	return {"hidden": hidden, "lives": lives, "first": first}


## One life ended and a new Gyrocopter chosen by the real keys, both Players' rows filed throughout: `kind` "destroyed" has Player 1
## press Self-destruct in the open (a destruction), "swapped" has it enter its own Base and press it there (a Swap, which benches
## the Unit). The other Player's rows must show its rotor turning, drawn, without a break.
func _cycle(kind: String, problems: PackedStringArray, notes: PackedStringArray) -> void:
	var swap: Object = _k.k.swap()
	if kind == "swapped":
		await swap.enter(0)
		await swap.wait_swappable(0)
	else:
		await _k.k.stage(0, Kit25.GYRO, OPEN, Vector3.RIGHT)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(GONE_TICKS)
	await _q.tokens.destruct(0)
	await _q.kit.advance(GONE_TICKS)
	var came: bool = await _q.tokens.spawn(0, Kit25.GYRO)
	await _q.kit.advance(LIFE_TICKS)
	_k.watch.logging = false
	_q.kit.need(problems, came, "%s: Player 1's new Gyrocopter did not appear" % kind)
	var mine: Dictionary = _judge_rows(_k.watch.rows[0], "%s, Player 1" % kind, problems)
	var other: Dictionary = _judge_rows(_k.watch.rows[1], "%s, Player 2" % kind, problems)
	_q.kit.need(problems, int(mine["hidden"]) > 0 and int(mine["lives"]) == 2, "%s: Player 1's rows show %d rows out of play and %d lives" % [kind, mine["hidden"], mine["lives"]])
	_q.kit.need(problems, int(other["hidden"]) == 0 and int(other["lives"]) == 1, "%s: Player 2's rows show %d rows out of play and %d lives" % [kind, other["hidden"], other["lives"]])
	var firsts: PackedFloat64Array = mine["first"]
	_q.kit.need(problems, firsts.size() == 2 and firsts[1] == 0.0, "%s: the first drawn rows of Player 1 read %s steps (the new model appears at rest)" % [kind, firsts])
	notes.append("%s: %d rows out of play, the new Gyrocopter's rotor at %s steps (rest) on its first drawn tick" % [kind, mine["hidden"], "%.1f" % firsts[1] if firsts.size() > 1 else "?"])
	measured.append("first_tick_steps_%s=%.1f" % [kind, firsts[1] if firsts.size() > 1 else -1.0])


## out_of_play (AC-1): see the class doc.
func _out_of_play() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _cycle("destroyed", problems, notes)
	await _cycle("swapped", problems, notes)
	_q.kit.verdict("out_of_play", problems, "a Gyrocopter's model is drawn exactly while its Unit is alive; out of play every part stands at angle 0 at a rate of 0; a new Gyrocopter appears with its rotor at rest and turns by the step from the next tick, never from where the last life's stopped; the other Player's rotor was drawn and turned by the step on every tick (%s)" % "; ".join(notes))


## round_over (AC-1; the story's question 4): Player 2 keeps a Gyrocopter in play while Player 1's Motorbike takes the Flag and
## delivers it with real keys; when the Round is over the tree is paused, so the rotor and the propeller of the Gyrocopter stand
## at the angle they had for FROZEN_TICKS ticks, and the next Round's Gyrocopter turns again from rest.
func _round_over() -> void:
	var problems: PackedStringArray = []
	var flags: Object = _k.k.flags()
	await _k.k.stage(1, Kit25.GYRO, OPEN, Vector3.RIGHT)
	flags.wall(1, Walls.GATE).destroy()
	var took: bool = await flags.take_flag(0, 1, Walls.GATE)
	_q.kit.need(problems, took, "Player 1's Motorbike did not take the Flag")
	var delivered: bool = await flags.deliver(0)
	_q.kit.need(problems, delivered and _k.k.swap().controller.is_round_over(), "the Flag was not delivered (the Round is over: %s)" % _k.k.swap().controller.is_round_over())
	var tree: SceneTree = _q.harness.get_tree()
	var before: Array[float] = []
	for pivot: RotorPivot in _k.pivots_of(1):
		before.append(pivot.angle)
	var turning: bool = before.size() == 2 and before[0] > 0.0
	_q.kit.need(problems, turning and tree.paused, "the Round is over but Player 2's Gyrocopter shows angles %s and the tree is paused: %s" % [before, tree.paused])
	await _q.kit.advance(FROZEN_TICKS)
	var after: Array[float] = []
	for pivot: RotorPivot in _k.pivots_of(1):
		after.append(pivot.angle)
	_q.kit.need(problems, after == before, "the parts moved under the Round-over screen: %s then %s" % [before, after])
	await _q.tokens.restart()
	await _k.k.swap().play(0, Kit25.GYRO)
	await _k.k.swap().play(1, Kit25.GYRO)
	await _q.kit.advance(FROZEN_TICKS)
	var now: Array[float] = []
	for pivot: RotorPivot in _k.pivots_of(1):
		now.append(pivot.angle)
	_q.kit.need(problems, now.size() == 2 and now[0] > 0.0 and not tree.paused and not _k.k.swap().controller.is_round_over(), "in the next Round Player 2's Gyrocopter shows angles %s, paused %s" % [now, tree.paused])
	await _k.k.walls().restore_all(true)
	measured.append("round_over_angles=%.3f/%.3f" % [before[0], before[1]] if before.size() == 2 else "round_over_angles=none")
	_q.kit.verdict("round_over", problems, "the Round was over (the tree paused) with Player 2's rotor at %.4f rad and propeller at %.4f rad, and after %d more ticks they stood at %.4f and %.4f: nothing turns under the Round-over screen, as nothing else that counts ticks does; in the next Round the new Gyrocopters turn again (rotor %.4f rad after %d ticks)" % [before[0], before[1], FROZEN_TICKS, after[0], after[1], now[0], FROZEN_TICKS])
