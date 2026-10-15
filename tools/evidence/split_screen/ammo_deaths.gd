extends RefCounted
## The respawn after each kind of destruction of the Story 022 scenario ammo: AC-3. A Unit that dies with Shots left does not
## carry them into its next life and one that dies empty does not come back empty: six Units, one for each way the build destroys
## one (an enemy Shot, a Turret's Shot, a Mine, the Self-destruct, the Gyrocopter's Fuel crash, story 021's crash into a Tall
## piece), each spends some or all of its load first (by a real key, in the arena), is brought to its death, holds no Fuel and no
## Shots while it waits, and the Unit its Player then chooses (a different type most times) starts with the whole tank and the
## whole load of the chosen type, reported in the physics frame of the spawn. Real keys and real causes. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## Shots spent before a partial death, and the whole load (-1).
const SOME: int = 5
const ALL: int = -1
## The middle of Map 01, each Unit this far out of the centre line, facing east: the duel and the Mine.
const MIDDLE_X: float = 5.0
## Metres in front of Base A's right Turret the Turret's victim stands (the explosions scenario's), and that Turret's side index.
const TURRET_AHEAD: float = 15.0
const TURRET_RIGHT: int = 1
## The share of its tank a Gyrocopter that must run dry soon spawns with (the explosions scenario's).
const SMALL_TANK: float = 0.005
## Ticks a destruction is waited for, and a destroyed Unit is watched for.
const KILL_WAIT: int = 600
const WATCH_TICKS: int = 60

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _k.k.walls().restore_all(true)
	await _case("enemy_shot", Quick.BUGGY, SOME, Quick.BUGGY)
	await _case("turret_shot", Quick.TRUCK, ALL, Quick.GYROCOPTER)
	await _case("mine", Quick.MOTORBIKE, SOME, Quick.MOTORBIKE)
	await _case("self_destruct", Quick.BUGGY, ALL, Quick.MOTORBIKE)
	await _case("fuel_crash", Quick.GYROCOPTER, 1, Quick.GYROCOPTER)
	await _case("tall_piece_crash", Quick.GYROCOPTER, ALL, Quick.TRUCK)
	await _k.k.walls().restore_all(true)


## One Player-2 Unit of a type: spends `spent` Shots, is destroyed by the cause, waits, and the choice of `next_type` brings a
## full Unit.
func _case(cause: String, victim_type: int, spent: int, next_type: int) -> void:
	var problems: PackedStringArray = []
	await _k.k.walls().park(0)
	await _k.mines().revive(1)
	var victim: Unit = _k.unit(1)
	var gun: Weapon = _k.weapon(1)
	if cause == "fuel_crash":
		await _k.mines().put_stats(1, _q.small_tank(victim_type, SMALL_TANK), Kit14.ARENA + Kit22.ARENA_SPOT, Vector3.RIGHT)
	else:
		await _k.arena_put(1, victim_type)
	var capacity: int = gun.capacity
	if spent == ALL:
		await _k.empty_gun(1)
	else:
		await _k.fire_n(1, spent)
	var left: int = gun.shots_left
	_q.kit.need(problems, left == 0 if spent == ALL else left == capacity - spent, "the %s holds %d of %d Shots before its death" % [_q.units.stats(victim_type).type_id, left, capacity])
	var before: int = _q.units.destroyed.size()
	await _kill(cause, victim_type)
	for _wait: int in KILL_WAIT:
		if _q.units.destroyed.size() > before:
			break
		await _q.kit.tick()
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, _q.units.destroyed.size() == before + 1 and int(_q.units.destroyed[before].x) == 1, "the %s death did not come (destroyed %d -> %d)" % [cause, before, _q.units.destroyed.size()])
	_k.judge_out_of_play(problems, "%s, destroyed" % cause, 1)
	await _q.kit.advance(WATCH_TICKS)
	_k.judge_out_of_play(problems, "%s, destroyed %d ticks" % [cause, WATCH_TICKS], 1)
	var spawn_mark: int = _k.spawned.size()
	var change_mark: int = _k.changes[1].size()
	_q.kit.need(problems, await _q.tokens.spawn(1, next_type), "no %s came after the %s death" % [_q.units.stats(next_type).type_id, cause])
	var got: Dictionary = _k.judge_new_unit(problems, cause, 1, spawn_mark, change_mark, next_type)
	var loaded: int = int(got["load"]["left"]) if not got.is_empty() else -1
	_q.kit.need(problems, next_type != victim_type or loaded != left, "the new Unit carried the dead one's %d Shots into its life" % left)
	measured.append("%s=%d>%d" % [cause, left, loaded])
	_q.kit.verdict("respawn_full_after_%s" % cause, problems, "a %s that %s (%d of %d Shots left) was destroyed by %s: it held 0 Fuel and 0 of 0 Shots with a hidden line at once and %d ticks later, and the %s its Player chose next started with 100 Fuel and %d of %d Shots reported in the frame of its spawn" % [_q.units.stats(victim_type).type_id, "dies empty" if spent == ALL else "dies with Shots left", left, capacity, _cause_words(cause), WATCH_TICKS, _q.units.stats(next_type).type_id, loaded, loaded])
	await _k.mines().clear_mines()
	if cause == "tall_piece_crash":
		await _k.k.walls().restore_all(true)


## The words of a cause, for the verdicts.
func _cause_words(cause: String) -> String:
	var words: Dictionary = {"enemy_shot": "an enemy Shot", "turret_shot": "a Turret's Shot", "mine": "a live Mine", "self_destruct": "its Player's Self-destruct",
		"fuel_crash": "its own Fuel crash (it spawned with 0.5 Fuel)", "tall_piece_crash": "its crash into Base A's corner tower at speed (story 021)"}
	return words[cause]


## Brings Player 2's Unit to its death by a cause. The Unit is alive, in the arena, with its Shots spent.
func _kill(cause: String, victim_type: int) -> void:
	var victim: Unit = _k.unit(1)
	match cause:
		"enemy_shot":
			_q.units.retype(0, Quick.MOTORBIKE, Vector3(-MIDDLE_X, 0.0, 0.0), Vector3.RIGHT)
			_q.units.retype(1, victim_type, Vector3(MIDDLE_X, 0.0, 0.0), Vector3.RIGHT)
			await _q.kit.advance(Kit22.SETTLE + 15)
			victim.apply_damage(victim.hit_points - 1.0)
			await _q.tokens.shoot(0)
		"turret_shot":
			var turret: Turret = _k.k.walls().turret(0, TURRET_RIGHT)
			var forward: Vector3 = _k.k.flags().way(0, Vector3.FORWARD).normalized()
			_q.units.retype(1, victim_type, turret.global_position + forward * TURRET_AHEAD, -forward)
			await _q.kit.advance(Kit22.SETTLE)
			victim.apply_damage(victim.hit_points - 1.0)
		"mine":
			var centre: Vector3 = Vector3(0.0, 0.0, 0.0)
			await _k.mines().place_mine(centre, 0)
			_q.units.retype(1, victim_type, centre, Vector3.LEFT)
		"self_destruct":
			await _q.tokens.destruct(1)
		"fuel_crash":
			pass
		"tall_piece_crash":
			await _k.k.walls().turrets_down()
			var flight: Dictionary = _k.k.line(Kit21.path_of("tower", 0), Kit21.toward(0))
			_q.units.retype(1, victim_type, flight["start"], flight["dir"])
			await _q.kit.advance(Kit22.SETTLE)
			await _k.k.drive(1, Kit21.FLIGHT_LIMIT, 1.0, 0, func() -> bool: return not victim.is_alive)
