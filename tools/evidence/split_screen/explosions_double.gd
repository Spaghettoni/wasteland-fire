extends RefCounted
## A Unit that a Mine and a Shot take on one tick plays one explosion (Story 016 AC-1), made as Story 014's doubles are:
## the latency of each destroyer is measured by a control first (a Unit put onto a live Mine: frames to the blast; one
## real Shot at a Unit of one hit point 10 m off: frames from the Shot's node to the kill), then the Unit is put onto the
## Mine on the frame that makes the Mine's blast and the Shot's arrival the same physics frame. Exactly one destruction
## comes, so exactly one Explosion, whichever destroyer acted first (the other finds a Unit that is not alive). Run by
## explosions.gd. Tooling only. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-1.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The frames the Unit's placing may be moved by, in the order tried, when the control's latency and the double's do not
## agree to the frame (the physics space's lag).
const ADJUSTS: Array[int] = [0, -1, 1, -2, 2]

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	var from_mine: int = await _mine_latency()
	var from_shot: int = await _shot_flight()
	await _double(from_mine, from_shot)


## Frames from putting Player 2's Motorbike onto a live Mine to its destruction.
func _mine_latency() -> int:
	await _k.fresh()
	await _k.t.clear(0)
	var centre: Vector3 = Vector3(Kit16.DUEL_X, 0.0, 0.0)
	await _k.live_mine(centre, 0)
	await _k.t.park(1)
	var before: int = _k.destroyed.size()
	var frame: int = Engine.get_physics_frames()
	_q.units.retype(1, Quick.MOTORBIKE, centre, Vector3.LEFT)
	await _k.wait_destroyed(before)
	await _k.clear_mines()
	return int(_k.destroyed[before]["frame"]) - frame if _k.destroyed.size() > before else -1


## Frames from a real Shot's node to the kill of a Motorbike of one hit point 10 m off.
func _shot_flight() -> int:
	await _k.duel(Quick.MOTORBIKE)
	var before: int = _k.destroyed.size()
	var frame: int = await _q.tokens.shoot(0)
	await _k.wait_destroyed(before)
	return int(_k.destroyed[before]["frame"]) - frame if _k.destroyed.size() > before else -1


func _double(from_mine: int, from_shot: int) -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, from_mine > 0 and from_shot > from_mine, "the controls gave %d frames for the Mine and %d for the Shot" % [from_mine, from_shot])
	var result: Dictionary = {}
	for adjust: int in ADJUSTS:
		result = await _attempt(from_mine, from_shot, adjust)
		if bool(result["aligned"]):
			break
	_q.kit.need(problems, bool(result["aligned"]), "no placing made the Mine's blast and the Shot's arrival one frame (last: %s)" % [result])
	_q.kit.need(problems, int(result["destructions"]) == 1 and int(result["explosions"]) == 1, "the Unit was destroyed %d times and %d Explosions came" % [int(result["destructions"]), int(result["explosions"])])
	measured.append("mine_and_shot=%s" % result["first"])
	_q.kit.verdict("mine_and_shot_one_tick_plays_one", problems, "a Mine (%d frames from the Unit put on it to its blast) and a Shot (%d frames from its node to the kill) aimed at the same frame, shifted by %s: Player 2's Motorbike was destroyed once, in frame %s, by the %s, and one Explosion came" % [from_mine, from_shot, result["adjust"], result["frame"], result["first"]])


## One try: the Shot is fired, the Unit is put on the Mine so that both are due in one frame (moved by `adjust`).
func _attempt(from_mine: int, from_shot: int, adjust: int) -> Dictionary:
	await _k.fresh()
	await _k.t.clear(0)
	var centre: Vector3 = Vector3(Kit16.DUEL_X, 0.0, 0.0)
	var mine: Mine = await _k.live_mine(centre, 0)
	await _k.t.park(1)
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	await _q.kit.advance(Kit16.SETTLE + 15)
	var mark: Vector2i = _k.mark()
	var shot: int = await _q.tokens.shoot(0)
	var place: int = shot + from_shot - from_mine + adjust
	while Engine.get_physics_frames() < place:
		await _q.kit.tick()
	_q.units.retype(1, Quick.MOTORBIKE, centre, Vector3.LEFT)
	_q.units.units[1].apply_damage(_q.units.units[1].hit_points - Kit16.ONE_SHOT)
	await _k.wait_destroyed(mark.y)
	await _q.kit.advance(Kit16.SETTLE)
	var frame: int = int(_k.destroyed[mark.y]["frame"]) if _k.destroyed.size() > mark.y else -1
	var due_mine: int = place + from_mine
	var due_shot: int = shot + from_shot
	var result: Dictionary = {"adjust": adjust, "frame": frame, "aligned": frame == due_mine and frame == due_shot, "destructions": _k.destroyed.size() - mark.y,
		"explosions": _k.blasts.size() - mark.x, "first": "Mine" if mine.state == Mine.State.SPENT else "Shot", "due": [due_mine, due_shot]}
	await _k.clear_mines()
	return result
