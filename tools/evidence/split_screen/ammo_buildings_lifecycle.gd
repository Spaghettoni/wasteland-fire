extends RefCounted
## The ammunition zones through the Round in the Story 024 scenario ammo_buildings, AC-2 and the story's edge cases: a Unit destroyed in a
## zone is given nothing while it lies there out of play (its Weapon reports 0 of 0) and the new Unit that is put on its Base is whole
## from its first row (a new Unit starts with a full load, so a stale gift to it could not be seen: the zone's own is_alive test is a
## second guard behind the Weapon's refusal, an equivalent mutant); a zone stops with the paused tree and gives no more and no less for
## the pause; and R after a Round that ended by a delivery leaves a zone that fills a new Unit in the ticks it took before. Real keys.
## Tooling only. Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Ticks the Truck fills before the Self-destruct, ticks it lies dead in the zone, and ticks watched after the new Truck appears.
const FILL_TICKS: int = 60
const DEAD_TICKS: int = 30
const AFTER_TICKS: int = 120
## The row a Unit brought into a zone is first given Shots on (the rate module measures it).
const FIRST_GIFT_ROW: int = 3
## Ticks of a fill before the tree is paused, and ticks it stays paused.
const BEFORE_PAUSE: int = 100
const PAUSED_TICKS: int = 60
## A Unit is "at its Base" when it is this far from the zone, metres.
const FAR_FROM_ZONE: float = 20.0
## Rows recorded after a load is whole.
const TAIL_TICKS: int = 30

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit24
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	await _destroyed_in_a_zone()
	await _paused_mid_fill()
	await _after_r()


## The first row a Player's Unit was alive again in after row `from`, or -1.
func _alive_again(player: int, from: int) -> int:
	for index: int in range(from, _k.rows(player).size()):
		if bool(_k.rows(player)[index]["alive"]):
			return index
	return -1


## A Truck with an empty gun, filling in the west ammunition zone, is Self-destructed there, lies dead in it, and a new Truck is chosen: dead, it
## holds nothing (0 of 0) and gets no Shot; new, at its Base, it holds its full load from its first row and is given nothing and changes nothing,
## though the zone lists it once on the tick after it appears.
func _destroyed_in_a_zone() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var zone_index: int = _k.ammo_index(0)
	await _k.park(1)
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	_k.move(0, _k.centre(zone_index), Vector3.LEFT)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(FILL_TICKS)
	var held: int = _k.gun(0).shots_left
	await _q.tokens.destruct(0)
	await _q.kit.advance(DEAD_TICKS)
	var spawned: bool = await _q.tokens.spawn(0, Quick.TRUCK)
	await _q.kit.advance(AFTER_TICKS)
	_k.watch.logging = false
	var list: Array = _k.rows(0)
	var dead: int = -1
	for index: int in list.size():
		if not bool(list[index]["alive"]):
			dead = index
			break
	var back: int = _alive_again(0, maxi(dead, 0))
	_q.kit.need(problems, spawned and dead > 0 and back > dead and held > 0 and held < stats.ammo_capacity, "the Truck died in row %d and was back in row %d (spawned %s), holding %d of %d when it died" % [dead, back, spawned, held, stats.ammo_capacity])
	var held_by_the_dead: int = 0
	for index: int in range(maxi(dead, 0), maxi(back, 0)):
		held_by_the_dead += 1 if int(list[index]["left"]) != 0 or int(list[index]["capacity"]) != 0 else 0
	_q.kit.need(problems, held_by_the_dead == 0, "the dead Truck held Shots or a capacity on %d rows" % held_by_the_dead)
	var start: int = int(list[back]["left"])
	var changed: int = 0
	var stale: int = 0
	for index: int in range(back, list.size()):
		changed += 1 if int(list[index]["left"]) != start else 0
		stale += 1 if bool(list[index]["listed"][zone_index]) and (list[index]["at"] as Vector3).distance_to(_k.centre(zone_index)) > FAR_FROM_ZONE else 0
	_q.kit.need(problems, start == stats.ammo_capacity and changed == 0, "the new Truck started with %d of %d Shots and its load changed on %d rows" % [start, stats.ammo_capacity, changed])
	_q.kit.need(problems, stale >= 1, "the zone never listed the new Truck at its Base: the stale entry the two-tick rule guards against did not arise")
	measured.append("destroyed_in_zone=held_%d_dead_rows_%d_stale_listed_rows_%d" % [held, back - dead, stale])
	_q.kit.verdict("destroyed_in_a_zone_gets_nothing", problems, "a Truck with %d of %d Shots, rearming in the west ammunition zone, Self-destructed there and lay dead in it for %d rows reporting 0 of 0; the new Truck came with its full load of %d and kept it, though the zone listed it on %d row(s) while it stood at its Base" % [held, stats.ammo_capacity, back - dead, start, stale])
	await _k.park(0)


## The tree paused in the middle of a fill (the pause the Round's end makes): nothing is given while it is paused and the fill takes the ticks it
## would have, to the tick.
func _paused_mid_fill() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.BUGGY)
	var expected: int = _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	_k.watch.clear()
	_k.watch.logging = true
	_k.move(0, _k.centre(zone_index), Vector3.LEFT)
	await _q.kit.advance(BEFORE_PAUSE)
	var before: int = _k.gun(0).shots_left
	var tree: SceneTree = _q.harness.get_tree()
	tree.paused = true
	await _q.kit.advance(PAUSED_TICKS)
	var during: int = _k.gun(0).shots_left
	tree.paused = false
	await _q.kit.advance(expected + TAIL_TICKS)
	_k.watch.logging = false
	var fill: Dictionary = _k.fill_of(0, zone_index, _settings.stopped_speed)
	_q.kit.need(problems, before == during and before > 0, "the Buggy held %d Shots when the tree was paused and %d after %d paused ticks" % [before, during, PAUSED_TICKS])
	_q.kit.need(problems, int(fill["ticks"]) == expected, "the fill took %d ticks with a pause in the middle, the rule says %d" % [fill["ticks"], expected])
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "paused fill"))
	measured.append("paused_mid_fill=held_%d_for_%d_ticks" % [before, PAUSED_TICKS])
	_q.kit.verdict("zone_stops_with_the_paused_tree", problems, "the tree was paused for %d ticks %d ticks into a Buggy's fill (%d Shots): it held %d throughout, and the fill took %d ticks, what the rule gives" % [PAUSED_TICKS, BEFORE_PAUSE, before, during, fill["ticks"]])
	await _k.park(0)


## A Round that ends by a real delivery, then R: the zone fills a new Truck in the ticks it took before the Round, from the same row.
func _after_r() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var span: int = _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full) + TAIL_TICKS
	var walls: Object = _k.a().k.walls()
	var flags: Object = _k.a().k.flags()
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.record_after_move(0, _k.centre(zone_index), Vector3.LEFT, span)
	var first: Dictionary = _k.fill_of(0, zone_index, _settings.stopped_speed)
	await walls.restore_all(true)
	await walls.turrets_down()
	flags.wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await flags.take_flag(1, 0, Walls.GATE)
	await flags.back_out(1, 0, Walls.GATE)
	var delivered: bool = await flags.deliver(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by the delivery (taken %s, delivered %s)" % [taken, delivered])
	await flags.restart()
	_q.kit.need(problems, not _q.controller.is_round_over(), "R did not start a fresh Round")
	await _k.park(1)
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.record_after_move(0, _k.centre(zone_index), Vector3.LEFT, span)
	var again: Dictionary = _k.fill_of(0, zone_index, _settings.stopped_speed)
	_q.kit.need(problems, int(again["ticks"]) == int(first["ticks"]) and int(again["gift"]) == FIRST_GIFT_ROW and int(first["gift"]) == FIRST_GIFT_ROW, "the fill after R took %d ticks from row %d, before the Round it took %d from row %d" % [again["ticks"], again["gift"], first["ticks"], first["gift"]])
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "after R"))
	measured.append("after_r=fill_%d_ticks_before_%d" % [again["ticks"], first["ticks"]])
	_q.kit.verdict("zone_after_r_is_as_before", problems, "a Round ended by Player 2's delivery of Base A's Flag and R started the next: the west ammunition zone filled a new Truck in %d ticks, as it had before the Round (%d), from the same row" % [again["ticks"], first["ticks"]])
	await _k.park(0)
