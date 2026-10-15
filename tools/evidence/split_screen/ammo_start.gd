extends RefCounted
## The full start of the Story 022 scenario ammo: AC-3 for the Round's first spawn, the Swap and what a benched Unit holds.
## Every new Unit starts with the whole tank (100 Fuel, every type) and the whole load of its type, whatever the Unit before it
## held: the Round's first spawn (a Truck for Player 1 and a Gyrocopter for Player 2, chosen by the entry with real keys), and
## a Swap at the own Base from a worn Unit (a third of a tank, five Shots spent) to the same type and to another, which is a
## free full resupply. A benched Unit holds no Fuel and no Shots, at once and a while later. The Weapon reports the load in the
## very physics frame of the spawn, and the earliest Shot of a new Unit comes two frames after it (both measured). Real keys.
## Tooling only. Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## The worn Unit a Swap starts from: this share of a tank at its spawn, and this many Shots spent.
const WORN_TANK: float = 0.3
const SPENT: int = 5
## Ticks a benched Unit is watched for, to see that it still holds nothing.
const BENCH_TICKS: int = 120
## The frames between a spawn and the earliest Shot of the new Unit that the story's reading expects: the trigger is armed on the
## first tick the key is seen up with the Unit alive (the frame after the spawn) and a press then fires in the frame after that.
const EARLIEST_SHOT_FRAMES: int = 2

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	_first_spawn()
	await _swap(Quick.BUGGY, Quick.BUGGY, "swap_to_the_same_type")
	await _swap(Quick.MOTORBIKE, Quick.GYROCOPTER, "swap_to_another_type")
	await _first_shot()
	await _first_tick_fires_from_the_load()


## The Round's first spawn, made by the entry before any module: both Players' new Units, read from the records.
func _first_spawn() -> void:
	var problems: PackedStringArray = []
	var types: Array[int] = [Quick.TRUCK, Quick.GYROCOPTER]
	var lags: PackedStringArray = []
	for player: int in Kit22.Kit.PLAYERS:
		var got: Dictionary = _k.judge_new_unit(problems, "first spawn of Player %d" % (player + 1), player, 0, 0, types[player])
		if not got.is_empty():
			lags.append("%d" % int(got["lag"]))
	measured.append("report_lag=%s" % ",".join(lags))
	_q.kit.verdict("first_spawn_is_full", problems, "at the Round's first spawn Player 1's Truck and Player 2's Gyrocopter each started with 100 of 100 Fuel and whole hit points, and each Weapon reported its full load (25 and 40, 'Ammo 25 / 25' and 'Ammo 40 / 40' inside the report) in the physics frame of the spawn")


## A worn Unit (a third of a tank, five Shots spent) is swapped at the own Base for a new one: it starts full, the Swap costs no Token.
func _swap(first_type: int, second_type: int, label: String) -> void:
	var problems: PackedStringArray = []
	await _k.k.walls().park(1)
	await _k.mines().revive(0)
	await _k.mines().put_stats(0, _q.small_tank(first_type, WORN_TANK), Kit14.ARENA + Kit22.ARENA_SPOT, Vector3.RIGHT)
	var unit: Unit = _k.unit(0)
	var gun: Weapon = _k.weapon(0)
	await _k.fire_n(0, SPENT)
	var worn_fuel: float = unit.fuel
	var worn_left: int = gun.shots_left
	var worn_capacity: int = gun.capacity
	_q.kit.need(problems, worn_fuel <= unit.fuel_capacity * WORN_TANK and worn_left == worn_capacity - SPENT, "the worn Unit holds %.1f Fuel and %d of %d Shots" % [worn_fuel, worn_left, worn_capacity])
	await _k.swap().enter(0)
	var swappable: int = await _k.swap().wait_swappable(0)
	var tokens: int = _k.k.tokens(0, first_type)
	var swaps: int = _k.swap().swaps.size()
	await _q.tokens.destruct(0)
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, swappable >= 0 and _k.swap().swaps.size() == swaps + 1, "the Swap did not happen (swappable %d, swaps %d -> %d)" % [swappable, swaps, _k.swap().swaps.size()])
	_k.judge_out_of_play(problems, "%s, benched" % label, 0)
	await _q.kit.advance(BENCH_TICKS)
	_k.judge_out_of_play(problems, "%s, benched %d ticks" % [label, BENCH_TICKS], 0)
	var spawn_mark: int = _k.spawned.size()
	var change_mark: int = _k.changes[0].size()
	var came: bool = await _q.tokens.spawn(0, second_type)
	_q.kit.need(problems, came, "no new Unit came after the Swap")
	var got: Dictionary = _k.judge_new_unit(problems, label, 0, spawn_mark, change_mark, second_type)
	_q.kit.need(problems, _k.k.tokens(0, first_type) == tokens, "the Swap took a Token: %d -> %d" % [tokens, _k.k.tokens(0, first_type)])
	var fresh_fuel: float = float(got["spawn"]["fuel"]) if not got.is_empty() else -1.0
	_q.kit.need(problems, fresh_fuel > worn_fuel, "the new Unit's Fuel %.1f is not above the worn Unit's %.1f" % [fresh_fuel, worn_fuel])
	measured.append("%s_fuel=%.0f" % [label, fresh_fuel])
	_q.kit.verdict(label, problems, "a %s that had spent %d Shots (%d of %d left) on %.1f Fuel was swapped at the own Base: benched with 0 Fuel and 0 of 0 Shots and a hidden line, still so %d ticks later, and the %s chosen next started with %.1f Fuel and a full load reported in the frame of its spawn; the Swap took no Token" % [_q.units.stats(first_type).type_id, SPENT, worn_left, worn_capacity, worn_fuel, BENCH_TICKS, _q.units.stats(second_type).type_id, fresh_fuel])


## Player 2's new Unit is pressed to fire as early as the arming rule lets it: the frames from its spawn to its first Shot, and the
## count that Shot takes it from (the full load, so a new Unit never fires on a stale count).
func _first_shot() -> void:
	var problems: PackedStringArray = []
	await _k.mines().revive(1)
	await _q.tokens.destruct(1)
	await _q.kit.advance(Kit22.SETTLE)
	var spawn_mark: int = _k.spawned.size()
	var change_mark: int = _k.changes[1].size()
	_q.kit.need(problems, await _q.tokens.spawn(1, Quick.BUGGY), "no Buggy came")
	await _q.kit.tick()
	var fired: Array[Dictionary] = await _k.press(1)
	var spawn: Dictionary = _k.spawn_since(1, spawn_mark)
	_q.kit.need(problems, fired.size() == 1 and not spawn.is_empty(), "the press made %d Shots (spawn %s)" % [fired.size(), spawn])
	if fired.size() == 1 and not spawn.is_empty():
		var frames: int = int(fired[0]["frame"]) - int(spawn["frame"])
		_q.kit.need(problems, frames == EARLIEST_SHOT_FRAMES, "the first Shot came %d frames after the spawn, expected %d" % [frames, EARLIEST_SHOT_FRAMES])
		var after: Dictionary = _k.changes[1][-1]
		var first_load: Dictionary = _k.load_since(1, change_mark)
		var full: int = _q.units.stats(Quick.BUGGY).ammo_capacity
		_q.kit.need(problems, int(first_load["left"]) == full and int(after["left"]) == full - 1 and int(after["capacity"]) == full and after["text"] == "Ammo %d / %d" % [full - 1, full], "the first Shot took the count from %d to %d of %d (line '%s')" % [first_load["left"], after["left"], after["capacity"], after["text"]])
		measured.append("earliest_shot=%d" % frames)
	_q.kit.verdict("earliest_shot_follows_the_load", problems, "a new Buggy pressed to fire as early as the trigger's arming allows fired its first Shot %d frames after its spawn, from a load that had been reported in the frame of the spawn: 50 -> 49 of 50, 'Ammo 49 / 50' on that tick" % EARLIEST_SHOT_FRAMES)


## A trigger held by the Weapon's own call (the Player's fire input switched off for the check, as a tool may) from an empty gun
## through a Swap fires in the very physics frame of the new Unit's spawn, from its full load: the load is refilled before the
## decision to fire, so no stale count refuses the Shot, the refusals of the empty gun left no cadence behind (the last real Shot's
## own cadence is waited out first: the Weapon keeps that across lives) and no "out of ammo" is said.
func _first_tick_fires_from_the_load() -> void:
	var problems: PackedStringArray = []
	await _k.k.walls().park(0)
	await _k.mines().revive(1)
	await _k.arena_put(1, Quick.BUGGY)
	await _k.empty_gun(1)
	var gun: Weapon = _k.weapon(1)
	var input: Node = null
	for node: Node in _q.harness.split.find_children("*", "PlayerFireInput", true, false):
		if (node as PlayerFireInput).weapon == gun:
			input = node
	_q.kit.need(problems, input != null and gun.shots_left == 0, "no fire input found for the Weapon, or its gun is not empty")
	if input == null:
		_q.kit.verdict("first_tick_fires_from_the_load", problems, "no fire input")
		return
	input.set_physics_process(false)
	await _q.kit.advance(_k.cadence_ticks(Quick.BUGGY))
	gun.set_trigger(true)
	await _k.swap().enter(1)
	await _k.swap().wait_swappable(1)
	await _q.tokens.destruct(1)
	await _q.kit.advance(Kit22.SETTLE)
	var spawn_mark: int = _k.spawned.size()
	var shot_mark: int = _k.shots.size()
	var empty_mark: int = _k.empties[1].size()
	var came: bool = await _q.tokens.spawn(1, Quick.BUGGY)
	gun.set_trigger(false)
	input.set_physics_process(true)
	var spawn: Dictionary = _k.spawn_since(1, spawn_mark)
	_q.kit.need(problems, came and not spawn.is_empty() and _k.shots.size() > shot_mark, "no new Buggy came, or it fired no Shot (spawn %s)" % [spawn])
	if came and not spawn.is_empty() and _k.shots.size() > shot_mark:
		_q.kit.need(problems, int(_k.shots[shot_mark]["frame"]) == int(spawn["frame"]), "the first Shot came in frame %d, the Unit spawned in frame %d" % [_k.shots[shot_mark]["frame"], spawn["frame"]])
		var full: int = _q.units.stats(Quick.BUGGY).ammo_capacity
		var refill: Dictionary = _k.load_since(1, _k.changes[1].size() - 2)
		_q.kit.need(problems, int(refill.get("left", -1)) == full and int(_k.changes[1][-1]["left"]) == full - 1, "the load was %s and then %d, expected %d and %d" % [refill, _k.changes[1][-1]["left"], full, full - 1])
	_q.kit.need(problems, _k.empties[1].size() == empty_mark, "%d reports of an empty gun came on the way" % (_k.empties[1].size() - empty_mark))
	_q.kit.verdict("first_tick_fires_from_the_load", problems, "a trigger held by the Weapon's own call through an empty Buggy's Swap fired the new Buggy's first Shot in the very physics frame of its spawn, from the refilled load (50, then 49), and the gun never said it was out of ammo")

