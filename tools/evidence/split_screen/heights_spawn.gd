extends RefCounted
## Where the Gyrocopter's model stands from the tick it exists, for the heights scenario (Story 020 AC-2): spawn_height
## (the model's lowest drawn point is at the flying height on the tick each Gyrocopter is spawned: the Round's first
## spawn, which the runner makes with the real keys, a spawn after a Swap at the own Base on each of the four Garage
## spots, and a spawn after a destruction in the open; every one is read inside the controller's own tick by the
## watch), flight_heights (it holds there while the Gyrocopter stands, turns on the spot and flies at its top speed)
## and explosion_up_there (a destroyed Gyrocopter explodes where its model was drawn, in the air). Run by heights.gd.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Ticks a Gyrocopter stands, turns on the spot and flies at full throttle while its height is recorded.
const STAND_TICKS: int = 30
const TURN_TICKS: int = 90
const FLY_TICKS: int = 240
## A Unit that has spawned stands within this of its spot, metres.
const SPOT_TOLERANCE: float = 0.05
## The share of its top speed a Gyrocopter must have reached in the flight.
const TOP_SPEED_SHARE: float = 0.99

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick
## What the destructions in the open showed: the drawn model's box just before, and where the Explosion was put.
var _blasts: Array[Dictionary] = []


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.k.turrets_down()
	await _spawn_height()
	await _flight_heights()
	_explosion_up_there()


## The spawn reads the watch has taken since `since`, for one Player.
func _reads_of(player: int, since: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index: int in range(since, _k.watch.spawn_reads.size()):
		if int(_k.watch.spawn_reads[index]["player"]) == player:
			found.append(_k.watch.spawn_reads[index])
	return found


## One spawn by the real keys: Player `player` presses Self-destruct where it stands (a Swap in its Garage, a
## destruction in the open), chooses the Gyrocopter, and the watch's read of the spawn is judged: one spawn, at the
## Base's spot `spot_index` (-1: anywhere), at the flying height. A destruction also files where its Explosion was put.
## Returns a note.
func _respawn(player: int, spot_index: int, label: String, problems: PackedStringArray) -> String:
	var base: Base = _k.k.k.m.w.bases[player]
	var unit: Unit = _q.units.units[player]
	var before: int = _k.watch.spawn_reads.size()
	var box: AABB = Quick.model_box(unit)
	var blasts_before: int = _q.harness.split.find_children("*", "Explosion", true, false).size()
	await _q.tokens.destruct(player)
	if spot_index < 0:
		var blasts: Array[Node] = _q.harness.split.find_children("*", "Explosion", true, false)
		_q.kit.need(problems, blasts.size() == blasts_before + 1, "%s: %d Explosions after the destruction, expected %d" % [label, blasts.size(), blasts_before + 1])
		if blasts.size() > blasts_before:
			_blasts.append({"box": box, "at": (blasts[-1] as Node3D).global_position})
	var came: bool = await _q.tokens.spawn(player, Quick.GYROCOPTER)
	var reads: Array[Dictionary] = _reads_of(player, before)
	_q.kit.need(problems, came and reads.size() == 1, "%s: the Gyrocopter came %s with %d spawn reads" % [label, came, reads.size()])
	if reads.size() != 1:
		return label + ": no spawn"
	var read: Dictionary = reads[0]
	var marker: Marker3D = null
	if spot_index == 0:
		marker = base.spawn_point
	elif spot_index == 1:
		marker = base.spare_spawn_points[0]
	if marker != null:
		_q.kit.need(problems, (read["at"] as Vector3).distance_to(marker.global_position) <= SPOT_TOLERANCE, "%s: spawned %.3f m from the spot" % [label, (read["at"] as Vector3).distance_to(marker.global_position)])
	_q.kit.need(problems, absf(float(read["low"]) - _k.height) <= Kit20.TOLERANCE, "%s: the lowest point was %.4f m on the spawn tick, the flying height is %.4f" % [label, read["low"], _k.height])
	return "%s %.4f m" % [label, read["low"]]


## spawn_height (AC-2).
func _spawn_height() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var first: Array[Dictionary] = _k.watch.spawn_reads.duplicate()
	_q.kit.need(problems, first.size() == 2, "the runner's two first spawns left %d reads" % first.size())
	for read: Dictionary in first:
		var base: Base = _k.k.k.m.w.bases[int(read["player"])]
		_q.kit.need(problems, absf(float(read["low"]) - _k.height) <= Kit20.TOLERANCE and (read["at"] as Vector3).distance_to(base.spawn_point.global_position) <= SPOT_TOLERANCE, "first spawn of p%d: lowest point %.4f m, %.3f m from its Garage spot" % [int(read["player"]) + 1, read["low"], (read["at"] as Vector3).distance_to(base.spawn_point.global_position)])
		notes.append("first p%d %.4f m" % [int(read["player"]) + 1, read["low"]])
	var swaps: int = 0
	for base_index: int in Kit20.Kit.PLAYERS:
		var base: Base = _k.k.k.m.w.bases[base_index]
		for spot_index: int in 2:
			await _k.k.k.m.revive(base_index)
			await _k.k.k.m.w.park(1 - base_index)
			if spot_index == 1:
				_k.k.k.m.w.s.flags.teleport(1 - base_index, base.spawn_point.global_position, -base.spawn_point.global_transform.basis.z)
				await _q.kit.advance(Kit20.Kit19.Kit18.SETTLE)
			notes.append(await _respawn(base_index, spot_index, "swap %s spot %d" % [base.name, spot_index + 1], problems))
			swaps += 1
	for player: int in Kit20.Kit.PLAYERS:
		await _k.k.k.m.revive(player)
		await _k.k.k.m.w.park(player)
		notes.append(await _respawn(player, -1, "destroyed in the open, p%d" % (player + 1), problems))
	measured.append("spawn_reads=%d" % _k.watch.spawn_reads.size())
	_q.kit.verdict("spawn_height", problems, "the lowest drawn point of the Gyrocopter's model stood at the flying height (%.4f m, within 1 mm) on the tick it was spawned, read inside the controller's own tick: the Round's first spawn of both Players (the runner's real keys), %d spawns after a Swap at the own Base on the first and the spare spot of each Garage (the spare taken by the other Player's Unit standing on the first), and 2 after a destruction in the open (%s)" % [_k.height, swaps, "; ".join(notes)])


## flight_heights (AC-2): Player 1's Gyrocopter in the open stands (hovering still), turns on the spot and flies at full throttle,
## its height recorded on each tick by the watch: the lowest drawn point does not move from the flying height, and at
## full throttle the Gyrocopter reaches its top speed.
func _flight_heights() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _k.k.k.m.revive(0)
	await _k.k.k.stage(0, Quick.GYROCOPTER, Quick.LANE_SPOT, Vector3.RIGHT)
	var unit: Unit = _q.units.units[0]
	var steps: Array = [["standing (hovering still)", STAND_TICKS, 0, 0], ["turning on the spot", TURN_TICKS, 0, 1], ["flying at full throttle", FLY_TICKS, 1, 0]]
	for step: Array in steps:
		_k.watch.start_recording()
		var fastest: float = 0.0
		var turned: float = 0.0
		var start_yaw: float = Quick.yaw(unit)
		for _tick: int in int(step[1]):
			_q.harness.drive(0, int(step[2]), int(step[3]))
			await _q.kit.tick()
			fastest = maxf(fastest, unit.current_speed)
		_k.watch.recording = false
		_q.harness.release_all()
		turned = absf(Quick.turned(start_yaw, Quick.yaw(unit)))
		var lows: PackedFloat64Array = _k.watch.lows[0]
		var least: float = INF
		var most: float = -INF
		for low: float in lows:
			least = minf(least, low)
			most = maxf(most, low)
		_q.kit.need(problems, lows.size() == int(step[1]) and least >= _k.height - Kit20.TOLERANCE - Kit20.FLOAT_SLACK and most <= _k.height + Kit20.TOLERANCE + Kit20.FLOAT_SLACK, "%s: %d samples between %.5f and %.5f m, the flying height is %.4f" % [step[0], lows.size(), least, most, _k.height])
		if int(step[3]) != 0:
			_q.kit.need(problems, turned > 0.5, "%s: turned only %.2f rad" % [step[0], turned])
		if int(step[2]) != 0:
			_q.kit.need(problems, fastest >= TOP_SPEED_SHARE * unit.stats.max_speed, "%s: reached %.2f m/s of %.1f" % [step[0], fastest, unit.stats.max_speed])
		notes.append("%s %d ticks %.5f to %.5f m%s%s" % [step[0], lows.size(), least, most, ", turned %.2f rad" % turned if int(step[3]) != 0 else "", ", %.2f m/s" % fastest if int(step[2]) != 0 else ""])
	_q.kit.verdict("flight_heights", problems, "in the open the Gyrocopter's lowest drawn point holds the flying height (%.4f m) on every tick it stands, turns on the spot and flies at full throttle: %s" % [_k.height, "; ".join(notes)])


## explosion_up_there (design/rules.md "Heights", "Destruction and respawn"): the Explosion of each Gyrocopter destroyed in the open
## was put inside its model's drawn height, in the air: between its lowest point and its top.
func _explosion_up_there() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	_q.kit.need(problems, _blasts.size() == 2, "%d Explosions were filed, expected 2" % _blasts.size())
	for blast: Dictionary in _blasts:
		var box: AABB = blast["box"]
		var at: Vector3 = blast["at"]
		_q.kit.need(problems, at.y >= box.position.y and at.y <= box.end.y, "an Explosion at %.3f m, the model was drawn from %.3f to %.3f m" % [at.y, box.position.y, box.end.y])
		notes.append("%.3f m (the model %.3f to %.3f m)" % [at.y, box.position.y, box.end.y])
	_q.kit.verdict("explosion_up_there", problems, "each Gyrocopter destroyed in the open exploded where its model was drawn, in the air: %s" % ", ".join(notes))
