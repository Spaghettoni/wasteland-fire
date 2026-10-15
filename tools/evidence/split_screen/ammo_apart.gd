extends RefCounted
## What stays apart from the ammunition in the Story 022 scenario ammo: AC-6. The Turrets fire as before, with no count: a Turret
## firing at a parked target for longer than the largest load keeps firing, and has no Weapon and nothing named ammo. The Mines
## stay separate: a Shot never takes a Mine and a lay never spends a Shot (a refused lay neither), a Truck that has laid its last
## Mine still fires, one that has fired its last Shot still lays (the empty module), and every new Truck still brings 5 Mines,
## after a respawn and after a Swap, with its 25 Shots. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-6.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")

## The Turret watched (Base A's right one, index 1) and how far ahead of it its parked target stands, metres.
const TURRET_RIGHT: int = 1
const TURRET_AHEAD: float = 15.0
## The target's hit points: more than any number of Turret Shots can take, so that it stays a target.
const TARGET_HIT_POINTS: float = 1000000.0
## The most any Unit's load holds (the Motorbike's): a Turret that fires more Shots than this has no load of that size.
const LARGEST_LOAD: int = 100
## Ticks the Turret fires at its target: its 0.8 s interval is 48 ticks, so 6,000 ticks are 125 Shots.
const WATCH_TICKS: int = 6000
## Shots a Truck fires before its lays, and Mines laid before the load is read.
const FIRED: int = 10
const LAID: int = 3

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _turret_keeps_firing()
	await _mines_and_shots_apart()
	await _new_truck_brings_five()


## A Turret fires at a Truck that cannot be killed for 6,000 ticks: more Shots than any load, the last of them as late as the first.
func _turret_keeps_firing() -> void:
	var problems: PackedStringArray = []
	await _k.k.walls().restore_all(true)
	var turret: Turret = _k.k.walls().turret(0, TURRET_RIGHT)
	var forward: Vector3 = _k.k.flags().way(0, Vector3.FORWARD).normalized()
	var frames: Array[int] = []
	var counter: Callable = func(_shot: Shot) -> void: frames.append(Engine.get_physics_frames())
	turret.fired.connect(counter)
	var target: UnitStats = _q.units.stats(Quick.TRUCK).duplicate() as UnitStats
	target.max_hit_points = TARGET_HIT_POINTS
	await _k.k.walls().park(0)
	await _k.mines().revive(1)
	await _k.mines().put_stats(1, target, turret.global_position + forward * TURRET_AHEAD, -forward)
	await _q.kit.advance(WATCH_TICKS)
	turret.fired.disconnect(counter)
	_q.kit.need(problems, frames.size() > LARGEST_LOAD, "the Turret fired %d Shots in %d ticks, not more than %d" % [frames.size(), WATCH_TICKS, LARGEST_LOAD])
	_q.kit.need(problems, _k.unit(1).is_alive and _k.unit(1).hit_points > 0.0 and _k.unit(1).hit_points < TARGET_HIT_POINTS, "the target is alive %s with %.0f hit points" % [_k.unit(1).is_alive, _k.unit(1).hit_points])
	var late: int = 0
	for frame: int in frames:
		late += 1 if frame >= frames[0] + LARGEST_LOAD * _k.cadence_ticks(Quick.MOTORBIKE) else 0
	_q.kit.need(problems, late > 0, "no Turret Shot came after the span of the largest load")
	_q.kit.need(problems, turret.find_children("*", "Weapon", true, false).is_empty(), "the Turret holds a Weapon")
	var named: PackedStringArray = []
	for property: Dictionary in turret.get_property_list() + ((turret.get("_data") as TurretStats).get_property_list() if turret.get("_data") != null else []):
		if String(property["name"]).to_lower().contains("ammo") or String(property["name"]).to_lower().contains("shots_left"):
			named.append(property["name"])
	_q.kit.need(problems, named.is_empty(), "the Turret or its data has properties %s" % [named])
	await _k.mines().put(1, Quick.MOTORBIKE, Vector3(-30.0, 0.0, 12.0), Vector3.RIGHT)
	measured.append("turret_shots=%d" % frames.size())
	_q.kit.verdict("turret_keeps_firing", problems, "Base A's right Turret fired %d Shots at a Truck of %.0f hit points in %d ticks (a load is at most %d Shots), %d of them after the span of the largest load, and has no Weapon and no property named for ammunition (R2)" % [frames.size(), TARGET_HIT_POINTS, WATCH_TICKS, LARGEST_LOAD, late])


## A Truck fires ten Shots (no Mine goes), lays three Mines (no Shot goes), lays its last two and is refused a sixth (no Shot goes),
## and then still fires.
func _mines_and_shots_apart() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.TRUCK)
	var layer: MineLayer = _k.mines().layers[0]
	var gun: Weapon = _k.weapon(0)
	var load_size: int = gun.capacity
	var loads: int = layer.capacity
	await _k.fire_n(0, FIRED)
	_q.kit.need(problems, gun.shots_left == load_size - FIRED and layer.mines_left == loads, "after %d Shots the Truck holds %d Shots and %d of %d Mines" % [FIRED, gun.shots_left, layer.mines_left, loads])
	for _lay: int in LAID:
		_q.kit.need(problems, not (await _k.mines().lay(0)).is_empty(), "a lay laid no Mine")
	_q.kit.need(problems, gun.shots_left == load_size - FIRED and layer.mines_left == loads - LAID, "after %d lays the Truck holds %d Shots and %d Mines" % [LAID, gun.shots_left, layer.mines_left])
	_q.kit.need(problems, _k.line(0) == "Ammo %d / %d" % [load_size - FIRED, load_size] and _k.mines().line(0) == "Mines %d / %d" % [loads - LAID, loads], "the lines read '%s' and '%s'" % [_k.line(0), _k.mines().line(0)])
	while layer.mines_left > 0:
		await _k.mines().lay(0)
	var refused: Dictionary = await _k.mines().lay(0)
	_q.kit.need(problems, refused.is_empty() and gun.shots_left == load_size - FIRED, "a lay with none left laid %s and the Truck holds %d Shots" % [refused, gun.shots_left])
	var more: Array[Dictionary] = await _k.fire_n(0, FIRED)
	_q.kit.need(problems, more.size() == FIRED and gun.shots_left == load_size - 2 * FIRED and layer.mines_left == 0, "with no Mine left the Truck fired %d Shots and holds %d (Mines %d)" % [more.size(), gun.shots_left, layer.mines_left])
	_q.kit.verdict("mines_and_shots_apart", problems, "a Truck's %d Shots took no Mine (5 of 5), its lays took no Shot (15 of 25 at 2 Mines left, again at 0), a refused sixth lay took no Shot, and with its last Mine laid it fired %d more Shots (5 left of 25)" % [FIRED, FIRED])


## A new Truck, by a respawn after a Self-destruct and by a Swap at the own Base, brings 5 Mines and 25 Shots whatever the last held.
func _new_truck_brings_five() -> void:
	var problems: PackedStringArray = []
	var layer: MineLayer = _k.mines().layers[0]
	var gun: Weapon = _k.weapon(0)
	await _q.tokens.destruct(0)
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.TRUCK), "no Truck came after the Self-destruct")
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, layer.mines_left == 5 and layer.capacity == 5 and gun.shots_left == 25 and gun.capacity == 25, "the respawned Truck holds %d of %d Mines and %d of %d Shots" % [layer.mines_left, layer.capacity, gun.shots_left, gun.capacity])
	await _k.fire_n(0, FIRED)
	await _k.mines().lay(0)
	await _k.swap().enter(0)
	await _k.swap().wait_swappable(0)
	await _q.tokens.destruct(0)
	_q.kit.need(problems, await _q.tokens.spawn(0, Quick.TRUCK), "no Truck came after the Swap")
	await _q.kit.advance(Kit22.SETTLE)
	_q.kit.need(problems, layer.mines_left == 5 and layer.capacity == 5 and gun.shots_left == 25 and gun.capacity == 25 and _k.line(0) == "Ammo 25 / 25" and _k.mines().line(0) == "Mines 5 / 5", "the swapped Truck holds %d of %d Mines and %d of %d Shots, the lines read '%s' and '%s'" % [layer.mines_left, layer.capacity, gun.shots_left, gun.capacity, _k.line(0), _k.mines().line(0)])
	_q.kit.verdict("new_truck_brings_both_loads", problems, "a Truck that had laid a Mine and fired ten Shots was destroyed by the Self-destruct and then swapped at the own Base: each new Truck came with 5 Mines and 25 Shots ('Ammo 25 / 25' beside 'Mines 5 / 5')")
