extends RefCounted
## What an explosion does not do (Story 016 AC-3): it is a picture, so it damages, pushes and stops nothing. drives_through:
## Player 1's Motorbike put down inside a Truck's playing Explosion and driven at full throttle for DRIVE_TICKS goes the
## very path (every tick, to the last bit) it goes with no Explosion there, and loses no hit point. shot_flies_through: a
## real Shot of Player 1 fired through the playing Explosion ends on the target behind it (a body of the Turret's
## type, a stand-in the tool puts on the Map: a Motorbike's Shots do nothing to a Flag Wall), which takes its damage once. flag_picked_up_in_it: a Carrier destroyed
## outside its Base drops the Flag at the wreck, and the Flag's owner's Motorbike takes it back through the playing
## Explosion. Run by explosions.gd. Tooling only. Implements: production/epics/wasteland-fire/story-016-unit-
## explosions.md AC-3.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## Ticks the Motorbike is driven for: inside the fireball at first (it lasts 36 ticks), then through the chunks and smoke.
const DRIVE_TICKS: int = 40
## Where the stand-in target stands (its centre, 8 m past the Explosion's), its size and the x of its near face.
const TARGET_AT: Vector3 = Vector3(13.0, 1.0, 0.0)
const TARGET_SIZE: Vector3 = Vector3(2.0, 2.0, 2.0)
const TARGET_FACE_X: float = 12.0
## Metres off the face the Shot may end, and the ticks a Shot is waited for.
const FACE_TOLERANCE: float = 0.3
const SHOT_WAIT: int = 40
## Metres out of the wreck, along the Gate's way out, the Flag's owner starts its drive to the Flag from.
const RETURN_REACH: float = 5.0


## A stand-in for a Structure: a body on the Map's layer with the contract a Shot damages (an apply_damage(), a type_id
## of the matrix and a Player other than the shooter's), that records the damage it takes.
class Target extends StaticBody3D:
	var type_id: StringName = &"turret"
	var player_index: int = 1
	var hits: PackedFloat64Array = PackedFloat64Array()

	func apply_damage(amount: float) -> void:
		hits.append(amount)


var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _drives_through()
	await _shot_flies_through()
	await _flag_picked_up_in_it()


## Player 1's Motorbike driven DRIVE_TICKS ticks from rest at a place, with or without a Truck's Explosion there: its
## position after each tick, and in how many of them an Explosion played.
func _drive(with_explosion: bool) -> Dictionary:
	await _k.fresh()
	await _k.t.clear(0)
	var start: Vector3 = Vector3(Kit16.DUEL_X, 0.0, 0.0)
	if with_explosion:
		_q.units.retype(1, Quick.TRUCK, start, Vector3.LEFT)
		await _q.kit.advance(Kit16.SETTLE)
		_q.units.units[1].destroy()
		await _q.kit.advance(1)
	else:
		await _k.t.park(1)
	_q.units.retype(0, Quick.MOTORBIKE, start, Vector3.RIGHT)
	await _q.kit.advance(Kit16.SETTLE)
	var hit_points: float = _q.units.units[0].hit_points
	_q.harness.drive(0, 1, 0)
	var path: Array[Vector3] = []
	var playing: int = 0
	for _tick: int in DRIVE_TICKS:
		await _q.kit.tick()
		path.append(_q.units.units[0].global_position)
		playing += 0 if _k.playing().is_empty() else 1
	_q.harness.drive(0, 0, 0)
	return {"path": path, "playing": playing, "hit_points": hit_points, "after": _q.units.units[0].hit_points}


func _drives_through() -> void:
	var problems: PackedStringArray = []
	var control: Dictionary = await _drive(false)
	var played: Dictionary = await _drive(true)
	var worst: float = 0.0
	for index: int in mini(control["path"].size(), played["path"].size()):
		worst = maxf(worst, (control["path"][index] as Vector3).distance_to(played["path"][index]))
	_q.kit.need(problems, worst == 0.0, "the Motorbike's path differed by up to %.6f m with the Explosion there" % worst)
	_q.kit.need(problems, int(played["playing"]) == DRIVE_TICKS and int(control["playing"]) == 0, "an Explosion played in %d of the %d ticks with it and in %d without" % [int(played["playing"]), DRIVE_TICKS, int(control["playing"])])
	_q.kit.need(problems, is_equal_approx(float(played["after"]), float(played["hit_points"])), "the Motorbike's hit points went %.1f -> %.1f inside the Explosion" % [float(played["hit_points"]), float(played["after"])])
	var travelled: float = ((played["path"][-1] as Vector3) - (played["path"][0] as Vector3)).length()
	_q.kit.need(problems, travelled > 3.0, "the Motorbike went only %.2f m" % travelled)
	measured.append("drive_m=%.2f" % travelled)
	_q.kit.verdict("drives_through", problems, "Player 1's Motorbike put down inside a playing Truck's Explosion and driven at full throttle for %d ticks (%.2f m, through the fireball, the chunks and the smoke) went exactly the path it goes with none there (largest difference %.6f m) and lost no hit point" % [DRIVE_TICKS, travelled, worst])


func _shot_flies_through() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.clear(0)
	var world: Node = _q.units.units[0].get_parent()
	var target: Target = Target.new()
	target.collision_layer = 1
	target.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = TARGET_SIZE
	shape.shape = box
	target.add_child(shape)
	world.add_child(target)
	target.global_position = TARGET_AT
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.TRUCK, Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit16.SETTLE + 15)
	_q.units.units[1].destroy()
	await _q.kit.advance(1)
	var index: int = _q.units.shots.size()
	await _q.tokens.shoot(0)
	for _wait: int in SHOT_WAIT:
		if index < _q.units.shot_ends.size() and _q.units.shot_ends[index] != Vector3.INF:
			break
		await _q.kit.tick()
	var end: Vector3 = _q.units.shot_ends[index] if index < _q.units.shot_ends.size() else Vector3.INF
	_q.kit.need(problems, target.hits.size() == 1 and target.hits[0] > 0.0, "the target took %s hits" % [target.hits])
	_q.kit.need(problems, end != Vector3.INF and absf(end.x - TARGET_FACE_X) <= FACE_TOLERANCE, "the Shot ended at %s, the target's near face is at x = %.1f" % [end, TARGET_FACE_X])
	_q.kit.need(problems, not _k.playing().is_empty(), "the Explosion was gone when the Shot ended")
	_q.kit.verdict("shot_flies_through", problems, "a real Shot of Player 1 fired through a playing Truck's Explosion (centre x = 5, its centre was %.1f m from the muzzle) ended on the target 8 m behind it at x = %.2f and the target took %s damage once" % [2.0 * Kit16.DUEL_X - _q.units.stats(Quick.MOTORBIKE).muzzle_forward, end.x, target.hits])
	target.queue_free()
	await _q.kit.advance(Kit16.SETTLE)


func _flag_picked_up_in_it() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.restore_all()
	for side: int in Kit13.NAMES.size():
		_k.t.turret(0, side).destroy()
	_k.t.w.wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Kit16.SETTLE)
	var s: Swap = _k.t.w.s
	var taken: bool = await _k.t.w.take_flag(1, 0, Walls.GATE)
	await _k.t.w.back_out(1, 0, Walls.GATE)
	var wreck: Vector3 = _q.units.units[1].global_position
	var since: int = s.order.size()
	_q.units.units[1].destroy()
	await _q.kit.advance(2)
	var dropped: int = s.count("destroyed", since)
	var out: Vector3 = _k.t.w.way(0, Walls.OUT[Walls.GATE]).normalized()
	s.flags.teleport(0, wreck + out * RETURN_REACH, -out)
	var ticks: int = await s.flags.drive_until(0, 1, Swap.CRUISE, func() -> bool: return s.count("seated", since) > 0)
	var playing: int = _k.playing().size()
	_q.kit.need(problems, taken and dropped == 1, "Player 2 took the Flag %s and %d destructions were logged" % [taken, dropped])
	_q.kit.need(problems, ticks > 0 and s.count("seated", since) == 1, "the Flag's owner took no Flag back (%d ticks, %d seated)" % [ticks, s.count("seated", since)])
	_q.kit.need(problems, playing >= 1 and _k.blasts[-1]["gone_frame"] < 0, "the Explosion was gone when the Flag was seated (%d playing)" % playing)
	measured.append("flag_back_ticks=%d" % ticks)
	_q.kit.verdict("flag_picked_up_in_it", problems, "Player 2's Carrier was destroyed %.1f m out of Base A's Gate and the Flag dropped at the wreck; Player 1's Motorbike drove %.1f m through the playing Explosion and took it back in %d ticks (the Flag seated)" % [wreck.distance_to(_k.t.w.point(0, Walls.SEAT)), RETURN_REACH, ticks])
