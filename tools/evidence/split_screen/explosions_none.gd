extends RefCounted
## What plays no explosion (Story 016 AC-2): the Round's start, a Swap at the own Base (the Self-destruct key inside
## the Base), a respawn, a second hit on a Unit already destroyed, a Turret or a Flag Wall that falls, a Unit a tool
## spawns while its Player is choosing and then destroys (the controller refuses the note, with its one warning)
## and the benches of the restart (R). Each is made on the shipped data and Map 01 with real keys where a Player
## acts, and the record of Explosions and of destructions is read before and after. Run by explosions.gd. Tooling
## only. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-2.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The text of the controller's refusal of a destruction of a Player who is not alive.
const REFUSED: String = "was destroyed while that Player was not ALIVE"
## Ticks a check lets pass after what it did, to see that nothing comes.
const QUIET_TICKS: int = 30

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	_at_the_start()
	await _swap()
	await _second_hit_and_respawn()
	await _structures()
	await _refused_note()
	await _restart()


## True when nothing was destroyed and no Explosion came since a mark, and none plays now.
func _nothing_since(mark: Vector2i) -> bool:
	return _k.blasts.size() == mark.x and _k.destroyed.size() == mark.y and _k.playing().is_empty()


## none_at_the_start: both Players chose and spawned at the start of the Round, and nothing was destroyed.
func _at_the_start() -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, _k.blasts.is_empty() and _k.destroyed.is_empty() and _k.playing().is_empty(), "%d Explosions came and %d destructions at the start of the Round" % [_k.blasts.size(), _k.destroyed.size()])
	_q.kit.verdict("none_at_the_start", problems, "the Round began, both Players chose and their Units spawned (%d spawns): no destruction, no Explosion, none in the tree" % _q.units.spawns.size())


## swap_plays_none: a Self-destruct inside the own Base is a Swap, not a destruction.
func _swap() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	var s: Swap = _k.t.w.s
	var mark: Vector2i = _k.mark()
	var swaps: int = s.swaps.size()
	await s.enter(1)
	var latency: int = await s.wait_swappable(1)
	await _q.tokens.destruct(1)
	await _q.kit.advance(QUIET_TICKS)
	_q.kit.need(problems, latency >= 0, "the zone never reported the Unit inside its Base")
	_q.kit.need(problems, s.swaps.size() == swaps + 1, "the Self-destruct key inside the Base made %d swaps" % (s.swaps.size() - swaps))
	_q.kit.need(problems, _nothing_since(mark), "a Swap at the own Base: %d Explosions and %d destructions came" % [_k.blasts.size() - mark.x, _k.destroyed.size() - mark.y])
	_q.kit.verdict("swap_plays_none", problems, "Player 2's Self-destruct key inside its own Base (the zone reported the Unit %d ticks after it was put there) made one Swap and no destruction: no Explosion came, none plays" % latency)


## second_hit_and_respawn_play_none: a Unit destroyed by a tool explodes once; a second destroy() and a hit on it do
## nothing; and its respawn, a real choice and the Round's own delay later, plays none.
func _second_hit_and_respawn() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	var unit: Unit = _q.units.units[1]
	var mark: Vector2i = _k.mark()
	unit.destroy()
	await _q.kit.advance(2)
	_q.kit.need(problems, _k.blasts.size() == mark.x + 1 and _k.destroyed.size() == mark.y + 1, "the first destruction made %d Explosions and %d destructions" % [_k.blasts.size() - mark.x, _k.destroyed.size() - mark.y])
	unit.destroy()
	unit.apply_damage(unit.stats.max_hit_points)
	await _q.kit.advance(QUIET_TICKS)
	_q.kit.need(problems, _k.blasts.size() == mark.x + 1 and _k.destroyed.size() == mark.y + 1, "a second destroy() and a lethal hit on the destroyed Unit made %d Explosions and %d destructions in all" % [_k.blasts.size() - mark.x, _k.destroyed.size() - mark.y])
	await _k.fresh()
	_q.kit.need(problems, _q.controller.is_alive(1) and _k.blasts.size() == mark.x + 1, "after the respawn %d Explosions came in all and the Unit is alive %s" % [_k.blasts.size() - mark.x, _q.controller.is_alive(1)])
	_q.kit.verdict("second_hit_and_respawn_play_none", problems, "a destroyed Unit exploded once; a second destroy() and a lethal hit on it were ignored, and its respawn through a real choice (%d spawns so far) played no second one" % _q.units.spawns.size())


## structures_play_none: a Turret and a Flag Wall that fall, by destroy() and by a lethal hit, play none.
func _structures() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	var mark: Vector2i = _k.mark()
	_k.t.turret(0, Kit13.LEFT).destroy()
	_k.t.turret(1, Kit13.RIGHT).apply_damage(_k.t.turret(1, Kit13.RIGHT).stats.max_hit_points)
	_k.t.w.wall(0, Walls.GATE).destroy()
	_k.t.w.wall(1, Walls.LEFT).apply_damage(_k.t.w.wall(1, Walls.LEFT).stats.max_hit_points)
	await _q.kit.advance(QUIET_TICKS)
	var fallen: int = 0
	for piece: Structure in [_k.t.turret(0, Kit13.LEFT), _k.t.turret(1, Kit13.RIGHT), _k.t.w.wall(0, Walls.GATE), _k.t.w.wall(1, Walls.LEFT)]:
		fallen += 0 if piece.is_standing else 1
	_q.kit.need(problems, fallen == 4, "only %d of the four pieces fell" % fallen)
	_q.kit.need(problems, _nothing_since(mark), "falling Structures made %d Explosions" % (_k.blasts.size() - mark.x))
	await _k.t.restore_all()
	_q.kit.verdict("structures_play_none", problems, "two Turrets and two Flag Walls fell (by destroy() and by a lethal hit) and no Explosion came")


## refused_note_plays_none: a Unit a tool spawns while its Player is waiting to respawn and then destroys is a
## destruction the controller refuses with one warning: no unit_destroyed goes out, so no Explosion comes.
func _refused_note() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	var unit: Unit = _q.units.units[1]
	unit.destroy()
	await _q.kit.advance(2)
	var mark: Vector2i = _k.mark()
	_k.expected_warnings.append(REFUSED)
	unit.spawn(_q.units.pose(Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT), _q.units.stats(Quick.MOTORBIKE))
	await _q.kit.advance(2)
	unit.destroy()
	await _q.kit.advance(QUIET_TICKS)
	_q.kit.need(problems, not unit.is_alive and _k.blasts.size() == mark.x and _k.destroyed.size() == mark.y, "the refused destruction made %d Explosions and %d destructions" % [_k.blasts.size() - mark.x, _k.destroyed.size() - mark.y])
	_q.kit.verdict("refused_note_plays_none", problems, "a Unit spawned by a tool while its Player waited to respawn and destroyed again was a destruction the controller refused (one warning, expected): no unit_destroyed, no Explosion")


## restart_benches_play_none: the Round ends by Player 2's Motorbike carrying Base A's Flag home, and R benches both
## Units: no Explosion comes, no destruction is counted.
func _restart() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.restore_all()
	for side: int in Kit13.NAMES.size():
		_k.t.turret(0, side).destroy()
	_k.t.w.wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Kit16.SETTLE)
	var taken: bool = await _k.t.w.take_flag(1, 0, Walls.GATE)
	var delivered: bool = await _k.t.w.deliver(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by a delivery (taken %s, delivered %s)" % [taken, delivered])
	var mark: Vector2i = _k.mark()
	_q.kit.need(problems, await _q.tokens.restart(), "the restart key brought no new Round")
	await _q.kit.advance(QUIET_TICKS)
	_q.kit.need(problems, _nothing_since(mark), "R made %d Explosions and %d destructions" % [_k.blasts.size() - mark.x, _k.destroyed.size() - mark.y])
	await _k.t.w.s.both_play()
	_q.kit.verdict("restart_benches_play_none", problems, "a Round ended by a delivery, R benched both Units and brought every Structure back: no destruction counted, no Explosion came")
