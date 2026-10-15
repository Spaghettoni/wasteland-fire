extends RefCounted
## The Fuel zones through the Round in the Story 023 scenario fuel_building, AC-3 and the story's edge cases: a Unit destroyed in a zone and
## put on its Base later is given nothing there (the new Unit starts with 30% of a tank here, so a gift would show; the zone does list it once,
## stale, on the tick after the respawn, and the two-tick rule keeps it out); a zone stops with the paused tree and gives no more and no less
## for the pause; R after a Round that ended by a delivery leaves a zone that fills a new Unit in the ticks it took before; and a Mine can be
## laid inside a zone until the next story refuses it. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-023-fuel-building.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## The share of a tank a new Truck starts with in the first check: less than whole, so that a gift to it would show.
const SPAWN_SHARE: float = 0.3
## Ticks the Truck fills before the Self-destruct, ticks it lies dead in the zone, and ticks watched after the new Truck appears.
const FILL_TICKS: int = 60
const DEAD_TICKS: int = 30
const AFTER_TICKS: int = 120
## The row a Unit spawned in a zone is first given Fuel on (the rate module measures it).
const FIRST_GIFT_ROW: int = 3
## Ticks of a fill before the tree is paused, and ticks it stays paused.
const BEFORE_PAUSE: int = 100
const PAUSED_TICKS: int = 60
## A Unit is "at its Base" when it is this far from the zone, metres.
const FAR_FROM_ZONE: float = 20.0
## Where the Truck stands to lay a Mine inside the west zone: its drop point lies behind it, metres from the zone's middle.
const LAY_AT: float = 3.0
## The longest a Mine's blast may be waited for, ticks.
const MINE_TICKS: int = 12

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	await _destroyed_in_a_zone()
	await _paused_mid_fill()
	await _after_r()
	await _a_mine_in_a_zone()


## The first row a Player's Unit was alive again in after row `from`, or -1.
func _alive_again(player: int, from: int) -> int:
	for index: int in range(from, _k.rows(player).size()):
		if bool(_k.rows(player)[index]["alive"]):
			return index
	return -1


## A Truck filling in the west zone is Self-destructed there, lies dead in it, and a new Truck is chosen: dead, it gets no Fuel; new, at its Base
## with 30% of a tank, it never holds more than it started with, though the zone lists it once on the tick after it appears.
func _destroyed_in_a_zone() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var saved: float = stats.spawn_fuel_fraction
	stats.spawn_fuel_fraction = SPAWN_SHARE
	await _k.park(1)
	await _k.put(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(FILL_TICKS)
	await _q.tokens.destruct(0)
	await _q.kit.advance(DEAD_TICKS)
	var spawned: bool = await _q.tokens.spawn(0, Quick.TRUCK)
	await _q.kit.advance(AFTER_TICKS)
	_k.watch.logging = false
	stats.spawn_fuel_fraction = saved
	var list: Array = _k.rows(0)
	var dead: int = -1
	for index: int in list.size():
		if not bool(list[index]["alive"]):
			dead = index
			break
	var back: int = _alive_again(0, maxi(dead, 0))
	_q.kit.need(problems, spawned and dead > 0 and back > dead, "the Truck died in row %d and was back in row %d (spawned %s)" % [dead, back, spawned])
	var gifts_to_the_dead: int = 0
	for index: int in range(maxi(dead, 0), maxi(back, 0)):
		gifts_to_the_dead += 1 if float(list[index]["fuel"]) != 0.0 else 0
	_q.kit.need(problems, gifts_to_the_dead == 0, "the dead Truck held Fuel on %d rows" % gifts_to_the_dead)
	var start: float = float(list[back]["fuel"])
	var highest: float = 0.0
	var stale: int = 0
	for index: int in range(back, list.size()):
		highest = maxf(highest, float(list[index]["fuel"]))
		stale += 1 if bool(list[index]["listed"][0]) and (list[index]["at"] as Vector3).distance_to(_k.centre(0)) > FAR_FROM_ZONE else 0
	_q.kit.need(problems, absf(start - stats.fuel_capacity * SPAWN_SHARE) < 0.1, "the new Truck started with %.3f Fuel, not about %.1f" % [start, stats.fuel_capacity * SPAWN_SHARE])
	_q.kit.need(problems, highest <= start + 1.0e-9, "the new Truck at its Base held up to %.6f Fuel against its %.6f at the start" % [highest, start])
	_q.kit.need(problems, stale >= 1, "the zone never listed the new Truck at its Base: the stale entry the two-tick rule guards against did not arise")
	measured.append("destroyed_in_zone=stale_listed_rows_%d_start_%.2f_highest_%.2f" % [stale, start, highest])
	_q.kit.verdict("destroyed_in_a_zone_gets_nothing_at_its_base", problems, "a Truck Self-destructed in the west zone lay dead there for %d rows holding no Fuel; the new Truck (30%% of a tank, %.2f Fuel) was listed by the zone on %d row(s) while it stood at its Base and never held more than %.2f" % [back - dead, start, stale, highest])
	await _k.park(0)


## The tree paused in the middle of a fill (the pause the Round's end makes): nothing is given while it is paused and the fill takes the ticks it
## would have, to the tick.
func _paused_mid_fill() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	await _k.park(0)
	await _k.a.mines().revive(0)
	_k.unit(0).leave_play()
	await _q.kit.advance(_k.a.mines().OUT_TICKS)
	_k.watch.clear()
	_k.watch.logging = true
	_k.unit(0).spawn(_q.units.pose(_k.centre(0), Vector3.RIGHT), _q.small_tank(Quick.TRUCK, 0.0))
	_q.units.cameras[0].snap_to_target()
	await _q.kit.advance(BEFORE_PAUSE)
	var before: float = _k.unit(0).fuel
	var tree: SceneTree = _q.harness.get_tree()
	tree.paused = true
	await _q.kit.advance(PAUSED_TICKS)
	var during: float = _k.unit(0).fuel
	tree.paused = false
	await _q.kit.advance(_k.fill_ticks(stats, _settings.fuel_seconds_to_full) + 30)
	_k.watch.logging = false
	var fill: Dictionary = _k.fill_of(0)
	_q.kit.need(problems, before == during and before > 0.0, "the Truck held %.4f Fuel when the tree was paused and %.4f after %d paused ticks" % [before, during, PAUSED_TICKS])
	_q.kit.need(problems, int(fill["ticks"]) == _k.fill_ticks(stats, _settings.fuel_seconds_to_full, float(fill["start"])), "the fill took %d ticks with a pause in the middle, the rule says %d" % [fill["ticks"], _k.fill_ticks(stats, _settings.fuel_seconds_to_full, float(fill["start"]))])
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "paused fill"))
	measured.append("paused_mid_fill=held_%.3f_for_%d_ticks" % [before, PAUSED_TICKS])
	_q.kit.verdict("zone_stops_with_the_paused_tree", problems, "the tree was paused for %d ticks %d ticks into a Truck's fill (%.3f Fuel): it held %.3f throughout, and the fill took %d ticks, what the rule gives" % [PAUSED_TICKS, BEFORE_PAUSE, before, during, fill["ticks"]])
	await _k.park(0)


## A Round that ends by a real delivery, then R: the zone fills a new Truck in the ticks it took before the Round.
func _after_r() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var walls: Object = _k.a.k.walls()
	var flags: Object = _k.a.k.flags()
	await _k.put_recorded(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.0, _k.fill_ticks(stats, _settings.fuel_seconds_to_full) + 30)
	var first: int = int(_k.fill_of(0)["ticks"])
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
	await _k.put_recorded(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.0, _k.fill_ticks(stats, _settings.fuel_seconds_to_full) + 30)
	var again: Dictionary = _k.fill_of(0)
	_q.kit.need(problems, int(again["ticks"]) == first and int(again["first"]) == FIRST_GIFT_ROW, "the fill after R took %d ticks from row %d, before the Round it took %d" % [again["ticks"], again["first"], first])
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "after R"))
	measured.append("after_r=fill_%d_ticks_before_%d" % [again["ticks"], first])
	_q.kit.verdict("zone_after_r_is_as_before", problems, "a Round ended by Player 2's delivery of Base A's Flag and R started the next: the west zone filled a new Truck in %d ticks, as it had before the Round (%d), from the same row" % [again["ticks"], first])
	await _k.park(0)


## A Truck standing in the west zone lays a Mine with the real key: the Mine is laid inside the zone (allowed until the next story); it is
## cleared at once, and the zone goes on filling the Truck by the rule.
func _a_mine_in_a_zone() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	await _k.put(0, Quick.TRUCK, _k.centre(0) + Vector3(LAY_AT, 0.0, 0.0), Vector3.RIGHT, 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	var laid: Dictionary = await _k.a.mines().lay(0)
	var place: Vector3 = _k.a.mines().place_of(laid) if not laid.is_empty() else Vector3.INF
	var inside: bool = absf(place.x - _k.centre(0).x) <= _k.zone(0).size.x / 2.0 and absf(place.z - _k.centre(0).z) <= _k.zone(0).size.z / 2.0
	_q.kit.need(problems, not laid.is_empty() and inside, "the lay returned %s, the Mine at %s (the zone's middle is %s)" % [laid, place, _k.centre(0)])
	await _k.a.mines().clear_mines()
	await _q.kit.advance(2 * MINE_TICKS)
	_k.watch.logging = false
	_q.kit.need(problems, _k.first_gain(0) >= 0, "the Truck gained no Fuel beside its Mine")
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "mine in the zone"))
	measured.append("mine_in_zone=laid_at_%s" % place)
	_q.kit.verdict("a_mine_can_be_laid_in_a_zone", problems, "a Truck standing in the west zone laid a Mine at %s, %.1f m from the zone's middle, inside its box: no rule refuses it yet (story 024 adds one), and the zone went on filling the Truck" % [place, Vector2(place.x - _k.centre(0).x, place.z - _k.centre(0).z).length()])
	await _k.park(0)
