extends RefCounted
## Two places a Mine meets another rule of the Map (Story 014 AC-5 and the implementation notes' order questions),
## pinned as measured: a Mine under a dropped Flag (the lay is allowed; a Motorbike of its owner's driving over
## both picks the Flag up, is destroyed by the Mine, and the Flag drops again at the wreck) and a Mine on a Fuel
## Can's spot (the lay is allowed; a Truck driven over both is refuelled by the Can before the Mine destroys it).
## Real keys. Tooling only. Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-5, AC-6.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## Open flat ground (the lay module's), and the Fuel Can the second check uses: the flat's west one on Map 01.
const FLAT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const FUEL_CAN: String = "FuelCanFlatWest"
const FUEL_CAN_AT: Vector3 = Vector3(-62.0, 0.0, 14.0)
## A Truck's tank for the Can: it starts a fifth full, so the Can has room to give (the laying Truck, which touches the
## Can and burns a little Fuel while it stands, takes it, and the check brings the Can back before the drive).
const SMALL_TANK: float = 0.2

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	await _flag_under_a_mine()
	await _fuel_can_under_a_mine()


## A Truck lays a Mine on the spot a dropped Flag of Player 1's lies on; Player 1's Motorbike drives over both.
func _flag_under_a_mine() -> void:
	var problems: PackedStringArray = []
	var flags: Object = _k.w.s.flags
	var flag: Flag = flags.flags[0]
	await _k.revive(0)
	await _k.revive(1)
	flag.drop_at(FLAT)
	await _q.kit.advance(Kit14.SETTLE)
	await _k.put(1, Quick.TRUCK, FLAT + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var before: int = _k.laid.size()
	var record: Dictionary = await _k.lay(1)
	_q.kit.need(problems, _k.laid.size() == before + 1 and _k.place_of(record).distance_to(FLAT) < 0.01 and flag.state == Flag.State.DROPPED, "the lay under the dropped Flag: %d Mines, Flag %s" % [_k.laid.size() - before, flags.state_name(0)])
	await _q.kit.advance(Kit14.LIVE_WAIT)
	await _k.put(1, Quick.TRUCK, FLAT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
	var picks: int = flags.pick_ups.size()
	var drops: int = flags.drops.size()
	var mark: int = _q.tokens.events.size()
	await _k.put(0, Quick.MOTORBIKE, FLAT + Vector3(-20.0, 0.0, 0.0), Vector3.RIGHT)
	_q.harness.drive(0, 1, 0)
	var picked_at: int = -1
	var died_at: int = -1
	for _tick: int in 300:
		await _q.kit.tick()
		picked_at = _q.harness.ticks if picked_at < 0 and flags.pick_ups.size() > picks else picked_at
		if not _q.units.units[0].is_alive:
			died_at = _q.harness.ticks
			break
	_q.harness.drive(0, 0, 0)
	await _q.kit.advance(4)
	var wreck: Vector3 = flags.wrecks[-1] if not flags.wrecks.is_empty() else Vector3.INF
	var apart: float = Vector2(flag.global_position.x - wreck.x, flag.global_position.z - wreck.z).length()
	_q.kit.need(problems, picked_at >= 0 and died_at >= picked_at, "the Flag was picked up on tick %d and the Motorbike destroyed on tick %d" % [picked_at, died_at])
	_q.kit.need(problems, flags.pick_ups.size() == picks + 1 and flags.drops.size() == drops + 1 and flag.state == Flag.State.DROPPED and apart <= 0.5, "pick-ups %d, drops %d, the Flag %s, %.2f m from the wreck" % [flags.pick_ups.size() - picks, flags.drops.size() - drops, flags.state_name(0), apart])
	measured.append("flag_under_mine=pickup_then_blast_%d" % (died_at - picked_at))
	_q.kit.verdict("mine_under_a_dropped_flag", problems, "a Truck laid a Mine on the spot a dropped Flag lay on (a Flag is no body: the ground stays open); Player 1's Motorbike driving over both picked the Flag up and, %d ticks later, was destroyed by the Mine, and the Flag dropped again at the wreck, %.2f m from it" % [died_at - picked_at, apart])
	flag.seat_at(_k.w.bases[0].flag_seat.global_transform)


## A Mine on a Fuel Can's spot: the lay is allowed and a Truck driven over both is refuelled before it is destroyed.
func _fuel_can_under_a_mine() -> void:
	var problems: PackedStringArray = []
	var can: FuelCan = _q.harness.split.field.get_node(FUEL_CAN) as FuelCan
	await _k.revive(0)
	await _k.revive(1)
	await _k.put_stats(0, _q.small_tank(Quick.TRUCK, 1.0), FUEL_CAN_AT + Vector3(0.0, 0.0, -3.4), Vector3.FORWARD)
	var before: int = _k.laid.size()
	var record: Dictionary = await _k.lay(0)
	_q.kit.need(problems, _k.laid.size() == before + 1 and _k.place_of(record).distance_to(FUEL_CAN_AT) < 0.01, "the lay on the Fuel Can's spot: %d Mines at %s" % [_k.laid.size() - before, _k.place_of(record)])
	await _q.kit.advance(Kit14.LIVE_WAIT)
	can.restock()
	await _k.put(0, Quick.TRUCK, FUEL_CAN_AT + Vector3(40.0, 0.0, 30.0), Vector3.RIGHT)
	await _k.put_stats(1, _q.small_tank(Quick.TRUCK, SMALL_TANK), FUEL_CAN_AT + Vector3(-20.0, 0.0, 0.0), Vector3.RIGHT)
	var truck: Unit = _q.units.units[1]
	var fuel_before: float = truck.fuel
	var taken_at: int = -1
	var died_at: int = -1
	_q.harness.drive(1, 1, 0)
	for _tick: int in 400:
		await _q.kit.tick()
		taken_at = _q.harness.ticks if taken_at < 0 and not can.is_available else taken_at
		if not truck.is_alive:
			died_at = _q.harness.ticks
			break
	_q.harness.drive(1, 0, 0)
	await _q.kit.advance(2)
	_q.kit.need(problems, taken_at >= 0 and died_at >= taken_at, "the Can was taken on tick %d, the Truck destroyed on tick %d" % [taken_at, died_at])
	_q.kit.need(problems, fuel_before < truck.stats.fuel_capacity * 0.5 and died_at >= 0, "the Truck started with %.1f Fuel and was destroyed at tick %d" % [fuel_before, died_at])
	measured.append("fuel_can_under_mine=refuelled_%d_ticks_before_the_blast" % (died_at - taken_at))
	_q.kit.verdict("mine_on_a_fuel_can_spot", problems, "a Truck laid a Mine on a Fuel Can's spot (the Can has no body: the ground stays open); a Truck with %.0f Fuel driven over both was refuelled by the Can %d ticks before the Mine destroyed it" % [fuel_before, died_at - taken_at])
