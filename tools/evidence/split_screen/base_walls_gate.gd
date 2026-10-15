extends RefCounted
## breach_is_not_a_gate, for the base_walls scenario (Story 018 AC-4, R11): a fallen panel changes nothing about
## the Base. With panels down a Unit that comes in through a breach is reported by the Base zone and swapped at
## home by Self-destruct like one that came through the Gate (swap); a Carrier with the other Player's Flag that
## drives into its own yard through a breach delivers the moment its zone reports it, as it does through the Gate
## (delivery); and the Turrets' lock on the Flag holds with a breach in the Base's walls until the last Turret
## falls (lock). Run by base_walls.gd. Tooling only. Every number comes from the game's data; the scenario types
## only its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the sides of a Flag Wall box.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## The Turrets' notice, as Story 013 decided it.
const NOTICE_TEXT: String = "Destroy the turrets first"
## Ticks the lock is sampled for after a settle, the ticks the Flag may take to be handed over once the last
## Turret is down, the ticks a swap may take and the ticks the zone's report may differ between the Gate and a
## breach.
const SETTLE_TICKS: int = 10
const SAMPLE_TICKS: int = 50
const TAKEN_WITHIN_TICKS: int = 2
const SWAP_WAIT_TICKS: int = 30
const LATENCY_SLACK: int = 1

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _swap()
	await _delivery()
	await _lock()


## swap (AC-4): with the lane panel of Base A's back wall and of its left wall down, Player 1's Buggy drives in
## through each breach until the zone reports it, presses Self-destruct and is swapped at home: a new Unit at a
## spawn spot with all its hit points, the zone's box unchanged.
func _swap() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var s: Object = _k.m.w.s
	var half: float = _q.units.stats(Quick.BUGGY).collision_size.z / 2.0
	for run: int in [Kit18.BACK, Kit18.LEFT]:
		await _k.restore_all()
		var lane: int = Kit18.LANE[run]
		_k.panel(0, run, lane).destroy()
		await _k.stage(0, Quick.BUGGY, _k.spot(0, run, lane, _k.start_out(run, half, true)), -_k.outward(0, run))
		var flags: Object = s.flags
		var reported: bool = await flags.drive_until(0, 1, Swap.CRUISE, func() -> bool: return s.controller.can_swap(0)) > 0
		_q.harness.release_all()
		var unit: Unit = _q.units.units[0]
		var inside: bool = _k.m.w.bases[0].zone.overlaps_body(unit)
		_q.kit.need(problems, reported and inside, "%s breach: the zone reported the Buggy after it drove in: %s, overlapping %s" % [Kit18.RUN_NAMES[run], reported, inside])
		var swaps: int = s.swaps.size()
		await _q.kit.press_settled(Kit.KEYS_DESTRUCT_1)
		await s.wait_until(func() -> bool: return s.swaps.size() > swaps)
		var swapped: bool = s.swaps.size() == swaps + 1 and bool(s.swaps[swaps]["choosing"])
		await s.play(0, Quick.MOTORBIKE)
		var fresh: Unit = _q.units.units[0]
		_q.kit.need(problems, swapped and s.on_a_spawn_point(0) and fresh.is_alive and is_equal_approx(fresh.hit_points, fresh.stats.max_hit_points), "%s breach: %d swaps after Self-destruct (choosing %s), then on a spawn spot %s, alive %s, %.0f hit points" % [Kit18.RUN_NAMES[run], s.swaps.size() - swaps, swapped, s.on_a_spawn_point(0), fresh.is_alive, fresh.hit_points])
		notes.append("%s: reported, swapped, the new Unit at a spawn spot" % Kit18.RUN_NAMES[run])
	var zone_box: BoxShape3D = (_k.m.w.bases[0].zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_q.kit.need(problems, zone_box.size == Vector3(29.4, 4.0, 27.5), "the zone's box is %s with panels down" % zone_box.size)
	_q.kit.verdict("breach_swap", problems, "with the lane panel of Base A's back wall and then of its left wall down, Player 1's Buggy drove in through the breach until the Base zone reported it, pressed Self-destruct and was swapped at home like a Unit that came by the Gate (%s); the zone's box stayed 29.4 x 4 x 27.5 m" % "; ".join(notes))
	await _k.restore_all()
	await _k.m.w.restart()


## delivery (AC-4): Player 1 takes Base B's Flag on a Motorbike (B's Turrets down, its Gate-side Flag Wall down) and
## drives it into Base A through the Gate and, in a second Round, through the breach of A's back wall: each wins the
## Round for Player 1, and the ticks from the Carrier's centre entering the zone's box to the Round being over agree
## to within a tick.
func _delivery() -> void:
	var problems: PackedStringArray = []
	var latencies: Array[int] = []
	var s: Object = _k.m.w.s
	var half: float = _q.units.stats(Quick.MOTORBIKE).collision_size.z / 2.0
	for via: String in ["the Gate", "a breach"]:
		await _k.restore_all()
		await _k.turrets_down()
		_k.m.w.wall(1, Walls.GATE).destroy()
		if via == "a breach":
			_k.panel(0, Kit18.BACK, Kit18.LANE[Kit18.BACK]).destroy()
		var carries: bool = await _k.m.w.take_flag(0, 1, Walls.GATE)
		_q.kit.need(problems, carries, "the Motorbike did not take Base B's Flag")
		var start: Vector3 = s.outside_point(0) if via == "the Gate" else _k.spot(0, Kit18.BACK, Kit18.LANE[Kit18.BACK], _k.start_out(Kit18.BACK, half, true))
		var facing: Vector3 = s.into_base(0) if via == "the Gate" else -_k.outward(0, Kit18.BACK)
		s.flags.teleport(0, start, facing)
		await _q.kit.advance(Kit18.SETTLE)
		var entered: Array[int] = [-1]
		var flags: Object = s.flags
		var over: bool = await flags.drive_until(0, 1, Swap.CRUISE, func() -> bool:
			if entered[0] < 0 and flags.in_zone_box(0, 0):
				entered[0] = _q.harness.ticks
			return s.controller.is_round_over()) > 0
		_q.harness.release_all()
		var latency: int = _q.harness.ticks - entered[0] if entered[0] >= 0 else -1
		latencies.append(latency)
		_q.kit.need(problems, over and entered[0] >= 0 and s.controller.winner_index() == 0, "through %s: the Round over %s, the Carrier entered the zone's box %s, winner %s" % [via, over, entered[0] >= 0, s.controller.winner_index()])
		await _k.m.w.restart()
	_q.kit.need(problems, latencies.size() == 2 and latencies[0] > 0 and absi(latencies[0] - latencies[1]) <= LATENCY_SLACK, "the zone reported the Carrier %s ticks after it entered the box (Gate, breach)" % [latencies])
	measured.append("delivery_ticks=%s" % "/".join(PackedStringArray(latencies.map(func(n: int) -> String: return str(n)))))
	_q.kit.verdict("breach_delivery", problems, "Player 1's Carrier, the other Player's Flag on a Motorbike, drove into Base A through the Gate and, a Round later, through the breach of A's back-wall lane panel: both won the Round for Player 1, %s ticks from the Carrier's centre entering the zone's box to the Round being over (Gate, breach: the zone's own lag, the same through a breach)" % [latencies])


## lock (AC-4): with a breach in Base B's back wall and in a Gate wall and its Gate-side Flag Wall down, Player 1's
## Motorbike reaches the Flag with both of B's Turrets standing: it is not handed over for SAMPLE_TICKS ticks, the
## notice says what to do and shows in that Player's view alone; with the last Turret down it is handed over within
## TAKEN_WITHIN_TICKS ticks.
func _lock() -> void:
	var problems: PackedStringArray = []
	var flags: Object = _k.m.w.s.flags
	var raider: int = 0
	var base_index: int = 1
	await _k.restore_all(true)
	_k.panel(base_index, Kit18.BACK, Kit18.LANE[Kit18.BACK]).destroy()
	_k.panel(base_index, Kit18.GATE_LEFT, 1).destroy()
	_k.m.w.wall(base_index, Walls.GATE).destroy()
	await _q.kit.advance(Kit18.SETTLE)
	var picks: int = flags.pick_ups.size()
	await _k.m.w.face(raider, Quick.MOTORBIKE, base_index, Walls.GATE, Walls.FACE + Walls.RUN_UP)
	var reached: bool = await flags.drive_until(raider, 1, Swap.CRUISE, func() -> bool: return flags.touching(base_index, raider)) > 0
	_q.kit.need(problems, reached and _q.units.units[raider].is_alive, "the Motorbike did not reach the Flag alive")
	await _q.kit.advance(SETTLE_TICKS)
	var held: int = 0
	for _tick: int in SAMPLE_TICKS:
		await _q.kit.tick()
		held += 1 if flags.touching(base_index, raider) and flags.pick_ups.size() == picks and flags.flags[base_index].state == Flag.State.AT_HOME else 0
	var notice: PlayerNotice = _k.m.notice(raider)
	_q.kit.need(problems, held == SAMPLE_TICKS and notice.visible and notice.text == NOTICE_TEXT and not _k.m.notice(base_index).visible, "with both Turrets standing the Flag was held back on %d of %d ticks, the line reads '%s' (shown %s), the owner's view shows it %s" % [held, SAMPLE_TICKS, notice.text, notice.visible, _k.m.notice(base_index).visible])
	_k.turret(base_index, 0).destroy()
	_k.turret(base_index, 1).destroy()
	var down_tick: int = _q.harness.ticks
	await _q.kit.advance(TAKEN_WITHIN_TICKS)
	var taken_at: int = flags.pick_ups[picks].z if flags.pick_ups.size() > picks else -1
	_q.kit.need(problems, flags.pick_ups.size() == picks + 1 and taken_at - down_tick <= TAKEN_WITHIN_TICKS and _k.m.w.carrying(raider) and not _k.m.notice(raider).visible, "with both Turrets down the Flag was handed over at tick %d (down at %d), carrying %s, the line shown %s" % [taken_at, down_tick, _k.m.w.carrying(raider), _k.m.notice(raider).visible])
	_q.kit.verdict("breach_lock", problems, "with a breach in Base B's back wall and in its Gate wall and its Gate-side Flag Wall down, Player 1's Motorbike touched the Flag with both Turrets standing: it was held back for %d ticks and the line \"%s\" showed in that Player's view alone; the Flag was handed over %d tick(s) after the last Turret fell" % [SAMPLE_TICKS, NOTICE_TEXT, taken_at - down_tick])
	await _k.m.w.deliver(raider)
	await _k.restore_all()
	await _k.m.w.restart()
