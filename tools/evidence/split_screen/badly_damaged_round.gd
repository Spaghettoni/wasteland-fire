extends RefCounted
## The state in the Round (Story 017 AC-5, AC-4): a badly damaged Carrier still drops the Flag at its wreck, pays its Token and explodes in the
## frame the state and the smoke end; a Carrier that limps home badly damaged ends the Round, the smoke stands frozen under the Round-over
## pause with the Units, and R benches both badly damaged Units: the state and the smoke end in the frame of the restart and the next Round's
## Units are whole. Run by badly_damaged.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-4 and AC-5.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## Ticks a staged badly damaged Unit smokes before its cause comes, and the ticks the Round-over pause is watched.
const SMOKE_TICKS: int = 20
const PAUSED_TICKS: int = 30
## Metres the Flag may lie from the wreck's Explosion.
const NEAR: float = 0.5

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick
## Every Flag drop of the Round: {tick, frame, flag, at}.
var _drops: Array[Dictionary] = []


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q
	_q.controller.flag_dropped.connect(func(index: int) -> void:
		_drops.append({"tick": _q.harness.ticks, "frame": Engine.get_physics_frames(), "flag": index, "at": _k.t.w.s.flags.flags[index].global_position}))


func run() -> void:
	await _carrier_wreck()
	await _limp_home_and_restart()


## Both Defences of Base A down and Player 2's Motorbike carrying Base A's Flag backed out of its box: the Carrier (true when it took the Flag).
func _make_carrier() -> bool:
	await _k.e.fresh()
	await _k.t.restore_all()
	for side: int in Kit13.NAMES.size():
		_k.t.turret(0, side).destroy()
	_k.t.w.wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Kit17.SETTLE)
	var taken: bool = await _k.t.w.take_flag(1, 0, Walls.GATE)
	await _k.t.w.back_out(1, 0, Walls.GATE)
	return taken


## badly_damaged_carrier_drops_the_flag: in one physics frame its state and smoke end, the Flag drops at the wreck, the Token is taken and the
## Explosion starts.
func _carrier_wreck() -> void:
	var problems: PackedStringArray = []
	var taken: bool = await _make_carrier()
	var victim: Unit = _k.unit(1)
	victim.apply_damage(victim.hit_points - _k.edge_of(Quick.MOTORBIKE))
	await _q.kit.advance(SMOKE_TICKS)
	var smoking: bool = _k.smoking(1)
	var counts: Array = _q.tokens.counts()
	var mark: int = _k.changes.size()
	var drops: int = _drops.size()
	var blasts: int = _k.e.blasts.size()
	await _q.tokens.destruct(1)
	await _q.kit.advance(2)
	var made: Array[Dictionary] = _k.changes_of(1, mark)
	_q.kit.need(problems, taken and smoking and victim.stats.can_carry, "the Carrier did not take the Flag (%s) or did not smoke (%s)" % [taken, smoking])
	_q.kit.need(problems, _drops.size() == drops + 1 and _k.e.blasts.size() == blasts + 1 and made.size() == 1 and not made[0]["state"], "%d Flag drops, %d Explosions, %d changes" % [_drops.size() - drops, _k.e.blasts.size() - blasts, made.size()])
	if _drops.size() == drops + 1 and _k.e.blasts.size() == blasts + 1 and made.size() == 1:
		var drop: Dictionary = _drops[-1]
		var wreck: Vector3 = (_k.e.blasts[-1]["node"] as Explosion).global_position
		_q.kit.need(problems, int(made[0]["frame"]) == int(drop["frame"]) and int(_k.e.blasts[-1]["frame"]) == int(drop["frame"]), "the state ended in frame %s, the Flag dropped in %s and the Explosion in %s" % [made[0]["frame"], drop["frame"], _k.e.blasts[-1]["frame"]])
		_q.kit.need(problems, Vector2(wreck.x - (drop["at"] as Vector3).x, wreck.z - (drop["at"] as Vector3).z).length() <= NEAR, "the Flag lies away from the wreck: %s %s" % [drop["at"], wreck])
	_q.kit.need(problems, _q.tokens.counts()[1][Quick.MOTORBIKE] == counts[1][Quick.MOTORBIKE] - 1 and not _k.smoking(1), "the Motorbike Tokens went %d -> %d, smoking %s" % [counts[1][Quick.MOTORBIKE], _q.tokens.counts()[1][Quick.MOTORBIKE], _k.smoking(1)])
	_q.kit.verdict("badly_damaged_carrier_drops_the_flag", problems, "Player 2's Carrier, badly damaged and smoking, Self-destructed outside Base A: in that one physics frame the state and the smoke ended, Base A's Flag dropped within %.1f m of the Explosion's centre, its Motorbike Token was taken and the Explosion started" % NEAR)


## limp_home_then_r: a badly damaged Carrier delivers the Flag at cruise speed, the Round is over and paused with both Units still smoking and
## the smoke frozen, and R ends both states in its frame; the next Round's Units are whole.
func _limp_home_and_restart() -> void:
	var problems: PackedStringArray = []
	var taken: bool = await _make_carrier()
	for player: int in Kit17.Kit.PLAYERS:
		_k.unit(player).apply_damage(_k.unit(player).hit_points - _k.edge_of(Quick.MOTORBIKE))
	await _q.kit.advance(SMOKE_TICKS)
	var delivered: bool = await _k.t.w.deliver(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by Player 2's delivery (taken %s, delivered %s)" % [taken, delivered])
	var on: Array[bool] = [_k.smoking(0), _k.smoking(1)]
	var shown: Array[int] = [_k.smoke(0).shown_count(), _k.smoke(1).shown_count()]
	var ticks: Array[int] = [_k.smoke(0).get(&"_ticks"), _k.smoke(1).get(&"_ticks")]
	await _q.kit.advance(PAUSED_TICKS)
	_q.kit.need(problems, on == [true, true] and _q.harness.get_tree().paused and shown == [_k.smoke(0).shown_count(), _k.smoke(1).shown_count()] and ticks == [_k.smoke(0).get(&"_ticks"), _k.smoke(1).get(&"_ticks")], "under the Round-over pause the smoke moved on (%s -> %s ticks) or ended" % [ticks, [_k.smoke(0).get(&"_ticks"), _k.smoke(1).get(&"_ticks")]])
	var mark: int = _k.changes.size()
	_q.kit.need(problems, await _q.tokens.restart(), "R brought no new Round")
	var started: int = _q.tokens.events_of(&"started").back()["now"]["frame"]
	var off: Array[Dictionary] = _k.changes.slice(mark)
	_q.kit.need(problems, off.size() == 2 and not off[0]["state"] and not off[1]["state"] and off[0]["frame"] == started and off[1]["frame"] == started, "R made the changes %s (the restart came in frame %s)" % [off, started])
	_q.kit.need(problems, not _k.smoking(0) and not _k.smoking(1) and _k.smoke(0).shown_count() == 0 and _k.smoke(1).shown_count() == 0, "smoke stands after R")
	await _k.t.w.s.both_play()
	for player: int in Kit17.Kit.PLAYERS:
		_q.kit.need(problems, _k.unit(player).hit_points == _k.unit(player).stats.max_hit_points and not _k.unit(player).is_badly_damaged, "Player %d's Unit of the next Round is not whole" % (player + 1))
	_q.kit.verdict("limp_home_then_r_ends_the_state", problems, "a badly damaged Carrier delivered the Flag and ended the Round; both Units stood smoking and the smoke frozen for %d ticks under the pause (%s puffs); R ended both states in its own frame and the next Round's Units are whole" % [PAUSED_TICKS, shown])
