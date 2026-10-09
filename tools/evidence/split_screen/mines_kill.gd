extends RefCounted
## What a live Mine does in the Story 014 scenario mines (AC-4): it destroys at once every ground Unit on it,
## a Motorbike, a Buggy, a Truck at full hit points and its owner's own Truck (a destruction, one Token
## each); the latency and the grazing offset are measured first; it is spent on the Unit it took and a
## stacked second Mine stays and takes the next; a Unit that respawns after a Mine kill sets off no Mine
## where it was destroyed; the Gyrocopter never sets one off (hovering until its tank runs dry, crossing
## at top speed, crashing on it) and a Shot flies over one. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-014-truck-mines.md AC-4.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## The trigger's radius (the data), and half the Motorbike's width (UnitStats.collision_size).
const RADIUS: float = 0.8
## A Unit that has gone this far past a Mine is not going to set it off.
const PAST: float = 12.0

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	_k.make_arena()
	await _graze_and_latency()
	await _types()
	await _owner()
	await _stacked_and_ghost()
	await _air()
	await _shots()
	_k.free_arena()


## Drives a Player's Unit, put in play as a type start metres west of the place at a lateral offset and facing east
## with its throttle held, until it is destroyed, the Mine is spent or it is PAST the place: what was seen.
func _run_over(player: int, type_index: int, centre: Vector3, d: float, start: float) -> Dictionary:
	await _k.revive(player)
	await _k.put(player, type_index, centre + Vector3(-start, 0.0, d), Vector3.RIGHT)
	var unit: Unit = _q.units.units[player]
	var seen: Dictionary = {"first_touch": -1, "blast": -1, "x_at_blast": INF, "vmax": 0.0, "hp": unit.hit_points, "least_gap": INF}
	_q.harness.drive(player, 1, 0)
	for tick: int in 400:
		await _q.kit.tick()
		seen["vmax"] = maxf(seen["vmax"], unit.get_real_velocity().length())
		seen["least_gap"] = minf(seen["least_gap"], _k.gap(unit, centre, RADIUS))
		if seen["first_touch"] < 0 and _k.gap(unit, centre, RADIUS) <= 0.0:
			seen["first_touch"] = tick
		if seen["blast"] < 0 and not unit.is_alive:
			seen["blast"] = tick
			seen["x_at_blast"] = unit.global_position.x - centre.x
		if seen["blast"] >= 0 or unit.global_position.x - centre.x > PAST:
			break
	_q.harness.drive(player, 0, 0)
	return seen


## The largest lateral offset at which a Motorbike at top speed sets a Mine off, found from above; and the
## latency from the first touch to the blast on the centre line.
func _graze_and_latency() -> void:
	var problems: PackedStringArray = []
	var record: Dictionary = await _k.live_mine(Kit14.ARENA)
	var mine: Mine = record["mine"] as Mine
	var centre: Vector3 = _k.place_of(record)
	var first_hit: float = INF
	var miss_all: bool = true
	var d: float = 1.60
	var top: float = 0.0
	while d >= 1.30:
		var seen: Dictionary = await _run_over(1, Quick.MOTORBIKE, centre, d, 50.0)
		top = maxf(top, seen["vmax"])
		if int(seen["blast"]) >= 0:
			first_hit = d
			break
		miss_all = miss_all and mine.state == Mine.State.LIVE
		d = snappedf(d - 0.01, 0.01)
	_q.kit.need(problems, first_hit < INF and miss_all, "no blast down to 1.30 m, or a miss spent the Mine")
	_q.kit.need(problems, top >= 23.0, "the Motorbike reached only %.1f m/s" % top)
	_q.kit.need(problems, mine.state == Mine.State.SPENT or not is_instance_valid(mine) or not mine.is_inside_tree(), "the Mine is not spent after the blast")
	_q.kit.need(problems, first_hit >= 1.40 and first_hit <= 1.50, "the largest offset that blasts is %.2f m (half the box 0.7 m + the trigger 0.8 m is 1.5 m)" % first_hit)
	measured.append("graze=%.2f" % first_hit)
	_q.kit.verdict("grazing_offset", problems, "a Motorbike at top speed (%.1f m/s) passed %.2f m beside a live Mine's centre unhurt at every offset above, and was destroyed at %.2f m (the geometry says 1.5 m: half its box's width 0.7 m plus the trigger's 0.8 m); the misses left the Mine live" % [top, first_hit + 0.01, first_hit])
	problems = []
	record = await _k.live_mine(Kit14.ARENA)
	mine = record["mine"] as Mine
	centre = _k.place_of(record)
	var tokens: Array = _q.tokens.counts()
	var seen: Dictionary = await _run_over(1, Quick.MOTORBIKE, centre, 0.0, 50.0)
	var latency: int = int(seen["blast"]) - int(seen["first_touch"])
	_q.kit.need(problems, int(seen["blast"]) >= 0 and int(seen["first_touch"]) >= 0, "no blast or no touch: %s" % [seen])
	_q.kit.need(problems, latency == 3, "the blast came %d ticks after the box first touched the trigger" % latency)
	_q.kit.need(problems, _q.tokens.counts()[1][Quick.MOTORBIKE] == tokens[1][Quick.MOTORBIKE] - 1, "the Motorbike Tokens went %d -> %d" % [tokens[1][Quick.MOTORBIKE], _q.tokens.counts()[1][Quick.MOTORBIKE]])
	_q.kit.need(problems, float(seen["x_at_blast"]) < 0.0, "the Motorbike's origin was %.2f m past the Mine's centre when it was destroyed" % float(seen["x_at_blast"]))
	measured.append("latency=%d" % latency)
	_q.kit.verdict("blast_latency", problems, "a Motorbike at %.1f m/s over a live Mine's centre was destroyed %d ticks after its box first touched the trigger (a tick of listing lag and the two-tick touch rule), with its origin %.2f m short of the centre, one Motorbike Token taken" % [float(seen["vmax"]), latency, -float(seen["x_at_blast"])])


## A Buggy and a Truck at full hit points are destroyed too, not damaged.
func _types() -> void:
	for type_index: int in [Quick.BUGGY, Quick.TRUCK]:
		var problems: PackedStringArray = []
		var record: Dictionary = await _k.live_mine(Kit14.ARENA)
		var mine: Mine = record["mine"] as Mine
		var centre: Vector3 = _k.place_of(record)
		var tokens: Array = _q.tokens.counts()
		var seen: Dictionary = await _run_over(1, type_index, centre, 0.0, 25.0)
		var name: String = String(_q.units.stats(type_index).type_id)
		_q.kit.need(problems, float(seen["hp"]) == _q.units.stats(type_index).max_hit_points, "the %s started with %.0f hit points" % [name, seen["hp"]])
		_q.kit.need(problems, int(seen["blast"]) >= 0 and mine.state == Mine.State.SPENT, "the %s was not destroyed (blast tick %d, Mine state %d)" % [name, seen["blast"], mine.state])
		_q.kit.need(problems, _q.tokens.counts()[1][type_index] == tokens[1][type_index] - 1, "the %s Tokens went %d -> %d" % [name, tokens[1][type_index], _q.tokens.counts()[1][type_index]])
		_q.kit.verdict("destroys_a_%s" % name, problems, "a %s with its full %.0f hit points, driven over a live Mine, was destroyed %d ticks after its box touched the trigger (a destruction, not damage), one %s Token taken" % [name, seen["hp"], int(seen["blast"]) - int(seen["first_touch"]), name])
		await _q.kit.advance(20)


## The owner's own Truck, reversing onto its own live Mine, is destroyed.
func _owner() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	await _q.kit.advance(Kit14.LIVE_WAIT)
	var tokens: Array = _q.tokens.counts()
	_q.harness.drive(0, -1, 0)
	var truck: Unit = _q.units.units[0]
	for _tick: int in 200:
		await _q.kit.tick()
		if not truck.is_alive:
			break
	_q.harness.drive(0, 0, 0)
	_q.kit.need(problems, not truck.is_alive and mine.state == Mine.State.SPENT, "the owner's Truck alive=%s, the Mine's state %d" % [truck.is_alive, mine.state])
	_q.kit.need(problems, _q.tokens.counts()[0][Quick.TRUCK] == tokens[0][Quick.TRUCK] - 1, "the Truck Tokens went %d -> %d" % [tokens[0][Quick.TRUCK], _q.tokens.counts()[0][Quick.TRUCK]])
	_q.kit.verdict("destroys_its_owner", problems, "Player 1's Truck, reversing onto the live Mine it had laid, was destroyed and cost its owner a Truck Token")


## Two stacked Mines spend one on the first Unit and keep the other for the next; the Unit that respawns
## after the kill, listed once at its old place, sets the second off no more than a Unit that is not there.
func _stacked_and_ghost() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var first: Dictionary = await _k.lay(0)
	var second: Dictionary = await _k.lay(0)
	await _q.kit.advance(Kit14.LIVE_WAIT)
	var centre: Vector3 = _k.place_of(first)
	_q.kit.need(problems, _k.place_of(second).distance_to(centre) <= 0.001, "the second Mine lies %.3f m from the first" % _k.place_of(second).distance_to(centre))
	var mines: Array[Mine] = [first["mine"] as Mine, second["mine"] as Mine]
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(120.0, 0.0, 120.0), Vector3.RIGHT)
	var tokens: Array = _q.tokens.counts()
	var seen: Dictionary = await _run_over(1, Quick.MOTORBIKE, centre, 0.0, 50.0)
	await _q.kit.advance(4)
	var spent: int = 0
	for mine: Mine in mines:
		spent += 1 if mine.state == Mine.State.SPENT else 0
	_q.kit.need(problems, int(seen["blast"]) >= 0 and spent == 1, "after the first Unit %d of the two stacked Mines were spent (blast tick %d)" % [spent, seen["blast"]])
	_q.kit.need(problems, _q.tokens.counts()[1][Quick.MOTORBIKE] == tokens[1][Quick.MOTORBIKE] - 1, "the Motorbike Tokens went %d -> %d" % [tokens[1][Quick.MOTORBIKE], _q.tokens.counts()[1][Quick.MOTORBIKE]])
	_q.kit.verdict("stacked_mines_spend_one_per_unit", problems, "two Mines laid on one spot, live together: a Motorbike over them destroyed one Token's worth once and spent one Mine, the other stayed live")
	problems = []
	var survivor: Mine = mines[0] if mines[0].state == Mine.State.LIVE else mines[1]
	await _k.revive(1)
	var calm: bool = true
	for _tick: int in 20:
		await _q.kit.tick()
		calm = calm and survivor.state == Mine.State.LIVE and _q.units.units[1].is_alive
	_q.kit.need(problems, calm, "the respawned Unit or the Mine did not last 20 ticks: Mine state %d, Unit alive %s" % [survivor.state, _q.units.units[1].is_alive])
	_q.kit.need(problems, _q.units.units[1].global_position.distance_to(centre) > 50.0, "the Unit respawned %.1f m from the Mine" % _q.units.units[1].global_position.distance_to(centre))
	seen = await _run_over(1, Quick.MOTORBIKE, centre, 0.0, 50.0)
	await _q.kit.advance(4)
	_q.kit.need(problems, int(seen["blast"]) >= 0 and survivor.state == Mine.State.SPENT, "the next Unit was not taken by the second Mine (blast %d, state %d)" % [seen["blast"], survivor.state])
	_q.kit.verdict("respawn_ghost_sets_off_nothing", problems, "the Unit destroyed on a stacked Mine respawned at its Base, %.0f m from the Mine (the respawn delay is 3 s, long after the zone has let go of a destroyed Unit); the Mine still live where it was destroyed took nothing of it over the next 20 ticks, and then took the next Unit driven over it" % _q.units.units[1].global_position.distance_to(centre))


## The Gyrocopter never sets a Mine off: not hovering over it until its tank runs dry (it crashes there), and not crossing it at top speed.
func _air() -> void:
	var problems: PackedStringArray = []
	var record: Dictionary = await _k.live_mine(Kit14.ARENA)
	var mine: Mine = record["mine"] as Mine
	var centre: Vector3 = _k.place_of(record)
	await _k.revive(1)
	var tokens: Array = _q.tokens.counts()
	await _k.put_stats(1, _q.small_tank(Quick.GYROCOPTER, 0.04), centre, Vector3.RIGHT)
	var gyro: Unit = _q.units.units[1]
	var hover: int = 0
	while gyro.is_alive and hover < 600:
		await _q.kit.tick()
		hover += 1
	_q.kit.need(problems, not gyro.is_alive and mine.state == Mine.State.LIVE, "the Gyrocopter alive=%s after %d ticks, the Mine's state %d" % [gyro.is_alive, hover, mine.state])
	_q.kit.need(problems, hover > 30 and hover < 600, "the Gyrocopter hovered %d ticks before it crashed" % hover)
	_q.kit.need(problems, _q.tokens.counts()[1][Quick.GYROCOPTER] == tokens[1][Quick.GYROCOPTER] - 1, "the crash cost %d Gyrocopter Tokens" % (tokens[1][Quick.GYROCOPTER] - _q.tokens.counts()[1][Quick.GYROCOPTER]))
	_q.kit.verdict("gyrocopter_hovers_and_crashes_on_a_mine", problems, "a Gyrocopter hovering exactly over a live Mine ran its tank dry after %d ticks and crashed there (a Token), and the Mine stayed live" % hover)
	problems = []
	var seen: Dictionary = await _run_over(1, Quick.GYROCOPTER, centre, 0.0, 40.0)
	_q.kit.need(problems, int(seen["blast"]) < 0 and mine.state == Mine.State.LIVE and _q.units.units[1].is_alive, "the Gyrocopter crossing: blast tick %d, Mine state %d, alive %s" % [seen["blast"], mine.state, _q.units.units[1].is_alive])
	_q.kit.need(problems, float(seen["vmax"]) >= 15.0 and float(seen["least_gap"]) <= -0.5, "the Gyrocopter's top speed was %.1f m/s and its box came %.2f m inside the trigger" % [float(seen["vmax"]), -float(seen["least_gap"])])
	await _q.kit.advance(3)
	_q.kit.verdict("gyrocopter_crosses_a_mine", problems, "a Gyrocopter crossing a live Mine's centre at %.1f m/s, its box %.2f m deep inside the trigger, destroyed nothing and the Mine stayed live" % [float(seen["vmax"]), -float(seen["least_gap"])])
	mine.queue_free()


## A Shot flies over a live Mine and ends beyond it, at its range.
func _shots() -> void:
	var problems: PackedStringArray = []
	var record: Dictionary = await _k.live_mine(Kit14.ARENA)
	var mine: Mine = record["mine"] as Mine
	var centre: Vector3 = _k.place_of(record)
	await _k.revive(1)
	await _k.put(1, Quick.BUGGY, centre + Vector3(-10.0, 0.0, 0.0), Vector3.RIGHT)
	var before: int = _q.units.shots.size()
	await _q.units.hold_fire(1, 1)
	await _q.kit.advance(60)
	_q.kit.need(problems, _q.units.shots.size() > before, "the Buggy fired no Shot")
	if _q.units.shots.size() > before:
		var end: Vector3 = _q.units.shot_ends[before]
		_q.kit.need(problems, end != Vector3.INF and end.x - centre.x > 20.0, "the Shot ended at %s, %.1f m past the Mine" % [end, end.x - centre.x])
		_q.kit.need(problems, absf(end.z - centre.z) < 0.01 and mine.state == Mine.State.LIVE, "the Shot ended off the line (%.3f m) or the Mine is %d" % [end.z - centre.z, mine.state])
		_q.kit.verdict("shots_fly_over_mines", problems, "a Buggy's Shot fired along a line through a live Mine's centre ended %.1f m beyond it (35 m of range) and the Mine stayed live: a Shot neither stops on a Mine nor sets it off" % (end.x - centre.x))
	else:
		_q.kit.verdict("shots_fly_over_mines", problems, "no Shot")
	mine.queue_free()
