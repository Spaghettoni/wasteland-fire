extends RefCounted
## The double losses of the Story 014 scenario mines (AC-6): Player 2's last Motorbike is destroyed by a Mine in the very
## physics frame the other Player's last Motorbike is destroyed by a Self-destruct, by a second Mine and by a Unit's
## Shot, and a Turret's Shot and a Mine take one Unit in one frame (destroyed once, one Token). Each Round is timed from
## frames its control Round measured: the Round ends once, with "Nobody wins!". A lay key read in the frame a Round ends
## lays nothing (AC-1). Real keys; the Mines are placed by the tool, as it may. Tooling only. Implements:
## production/epics/wasteland-fire/story-014-truck-mines.md AC-1 and AC-6.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Round14: GDScript = preload("res://tools/evidence/split_screen/mines_round_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## Where a Mine lies for the doubles: open flat ground, a run-up of 20 m to the west.
const KILL_SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
## Where the control and the Shot double stand: a Motorbike here, the other 4.2 m east of the first.
const SHOT_SPOT: Vector3 = Vector3(-30.0, 0.0, 12.0)
const SHOT_GAP: float = 4.2
## Where Player 1's Truck stands while it presses the lay key in the loss frame: its drop point on SHOT_SPOT.
const TRUCK_SPOT: Vector3 = Vector3(-26.6, 0.0, 12.0)
## How far in front of a Turret, along its rest heading, the victim stands.
const AHEAD: float = 15.0

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object
var _r: Round14
## Frames: from a Unit's spawn on a live Mine to its destruction; from the tick a tool placed a Mine to the one it takes
## a Unit standing on it; from a fire key set to the Shot's kill four metres ahead; from a Unit's spawn in a Turret's
## view to the Turret's first Shot's kill. Each is measured by a control Round before the Round that uses it.
var _spawn_to_blast: int = -1
var _arming_to_blast: int = -1
var _key_to_kill: int = -1
var _turret_to_kill: int = -1


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q
	_r = Round14.new(kit)


func run() -> void:
	await _doubles()
	await _lay_on_the_loss_frame()
	await _turret_double()
	await _r.restart_with(_r.stock_before)


## A new Round with `count` Motorbikes a Player and both Players' Motorbikes in play at their Bases.
func _new_round() -> void:
	await _r.restart_with(Round14.LAST_MOTORBIKE)


## double (AC-6): the control Round measures how many frames a Unit spawned on a live Mine lives, then each
## double Round times the other Player's last Motorbike to be destroyed in that very frame: by a Self-destruct,
## by a second Mine and by a Shot.
func _doubles() -> void:
	var problems: PackedStringArray = []
	await _new_round()
	await _k.put(0, Quick.MOTORBIKE, KILL_SPOT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
	await _k.place_mine(KILL_SPOT, 0)
	var mark: int = _q.tokens.events.size()
	var spawned: int = _r.spawn_now(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	await _r.wait_over()
	await _q.kit.advance(2)
	_spawn_to_blast = _r.frame_of(1, mark) - spawned
	_q.kit.need(problems, _spawn_to_blast > 0 and _q.controller.winner_index() == 0, "the control: a Motorbike spawned on a live Mine lived %d frames, winner %d" % [_spawn_to_blast, _q.controller.winner_index()])
	measured.append("spawn_to_blast=%d" % _spawn_to_blast)
	# a Self-destruct
	await _new_round()
	await _k.put(0, Quick.MOTORBIKE, KILL_SPOT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
	await _k.place_mine(KILL_SPOT, 0)
	mark = _q.tokens.events.size()
	spawned = _r.spawn_now(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	await _q.tokens.press_on(spawned + _spawn_to_blast - 1, Tokens.keys(&"destruct", 0))
	await _r.wait_over()
	await _q.kit.advance(2)
	var outcome: Dictionary = _r.outcome(mark)
	_q.kit.need(problems, _r.is_double(outcome), "Mine and Self-destruct: %s" % [outcome])
	var notes: PackedStringArray = ["a Self-destruct (frame %s)" % [outcome["frames"]]]
	# a second Mine
	await _new_round()
	await _k.place_mine(KILL_SPOT, 0, false)
	await _k.place_mine(KILL_SPOT + Vector3(0.0, 0.0, 14.0), 1)
	mark = _q.tokens.events.size()
	_r.spawn_now(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	_r.spawn_now(0, Quick.MOTORBIKE, KILL_SPOT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
	await _r.wait_over()
	await _q.kit.advance(2)
	outcome = _r.outcome(mark)
	_q.kit.need(problems, _r.is_double(outcome), "two Mines: %s" % [outcome])
	notes.append("a second Mine (frame %s)" % [outcome["frames"]])
	var shot: PackedStringArray = await _shot_double()
	_q.kit.need(problems, shot[0] == "true", "Mine and Shot: %s" % shot[2])
	notes.append(shot[1])
	_q.kit.verdict("double_loss_with_a_mine", problems, "Player 2's last Motorbike destroyed by a Mine in the same physics frame as Player 1's last Motorbike was destroyed by %s: one Round end, '%s' in both views; a Unit spawned on a live Mine lives %d frames" % [" and by ".join(notes), Round14.NOBODY_TEXT, _spawn_to_blast])
	

## The frame a fire key set now brings a Motorbike's Shot's kill of a 1 hit point Motorbike 4.2 m ahead: the control.
func _measure_shot() -> void:
	await _new_round()
	await _k.put(1, Quick.MOTORBIKE, SHOT_SPOT, Vector3.RIGHT)
	await _k.put(0, Quick.MOTORBIKE, SHOT_SPOT + Vector3(SHOT_GAP, 0.0, 0.0), Vector3.LEFT)
	_q.units.units[0].apply_damage(_q.units.units[0].hit_points - 1.0)
	var mark: int = _q.tokens.events.size()
	var pressed: int = Engine.get_physics_frames()
	await _q.tokens.press_on(pressed, Tokens.keys(&"fire", 1))
	await _r.wait_over()
	await _q.kit.advance(2)
	_key_to_kill = _r.frame_of(0, mark) - pressed
	measured.append("key_to_kill=%d" % _key_to_kill)


## The frames a Unit standing on an arming Mine placed by the tool lives: the control.
func _measure_arming() -> void:
	await _new_round()
	await _k.put(0, Quick.MOTORBIKE, KILL_SPOT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
	var record: Dictionary = await _k.place_mine(KILL_SPOT, 0, false)
	await _k.put(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	var mark: int = _q.tokens.events.size()
	await _r.wait_over()
	await _q.kit.advance(2)
	_arming_to_blast = _r.frame_of(1, mark) - int(record["frame"])
	measured.append("arming_to_blast=%d" % _arming_to_blast)


## The double loss by a Unit's Shot: Player 2's Motorbike stands on an arming Mine and fires so that its Shot's kill of
## Player 1's last Motorbike lands in the frame the Mine takes Player 2's.
func _shot_double() -> PackedStringArray:
	await _measure_shot()
	await _measure_arming()
	await _new_round()
	await _k.put(0, Quick.MOTORBIKE, KILL_SPOT + Vector3(SHOT_GAP, 0.0, 0.0), Vector3.LEFT)
	_q.units.units[0].apply_damage(_q.units.units[0].hit_points - 1.0)
	var record: Dictionary = await _k.place_mine(KILL_SPOT, 0, false)
	await _k.put(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	var mark: int = _q.tokens.events.size()
	await _r.press_on(int(record["frame"]) + _arming_to_blast - _key_to_kill, Tokens.keys(&"fire", 1))
	await _r.wait_over()
	await _q.kit.advance(2)
	var outcome: Dictionary = _r.outcome(mark)
	return PackedStringArray([str(_r.is_double(outcome)), "a Unit's Shot (frames %s)" % [outcome["frames"]], str(outcome)])


## A Turret's Shot and a Mine take one Unit in one frame: the Unit is destroyed once and costs one Token. The control
## Round measures the frames from the victim's spawn in the Turret's view to the Shot's kill; the double Round lays the
## Mine first, so that it goes live in that very frame under the victim.
func _turret_double() -> void:
	var problems: PackedStringArray = []
	var right: Turret = _k.w.bases[0].get_node("Turrets/TurretRight") as Turret
	var left: Turret = _k.w.bases[0].get_node("Turrets/TurretLeft") as Turret
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD).normalized()
	var victim_at: Vector3 = right.global_position + forward * AHEAD
	await _new_round()
	left.destroy()
	await _k.w.park(0)
	var mark: int = _q.tokens.events.size()
	var spawned: int = _r.spawn_now(1, Quick.MOTORBIKE, victim_at, -forward)
	_q.units.units[1].apply_damage(_q.units.units[1].hit_points - 1.0)
	await _r.wait_over()
	await _q.kit.advance(2)
	_turret_to_kill = _r.frame_of(1, mark) - spawned
	_q.kit.need(problems, _turret_to_kill > 0 and _turret_to_kill < _arming_to_blast - Kit14.SETTLE, "the control: the Turret's Shot killed the victim %d frames after it appeared" % _turret_to_kill)
	await _new_round()
	left.destroy()
	await _k.w.park(0)
	var record: Dictionary = await _k.place_mine(victim_at, 0, false)
	var target: int = int(record["frame"]) + _arming_to_blast - _turret_to_kill
	while Engine.get_physics_frames() < target:
		await _q.kit.tick()
	mark = _q.tokens.events.size()
	var tokens: Array = _q.tokens.counts()
	var fired: int = right.fired.get_connections().size()
	spawned = _r.spawn_now(1, Quick.MOTORBIKE, victim_at, -forward)
	_q.units.units[1].apply_damage(_q.units.units[1].hit_points - 1.0)
	await _r.wait_over()
	await _q.kit.advance(2)
	var outcome: Dictionary = _r.outcome(mark)
	var mine: Mine = record["mine"] as Mine
	_q.kit.need(problems, spawned == target and outcome["frames"].size() == 1 and outcome["players"] == [1] and outcome["overs"] == 1, "one destruction wanted: %s" % [outcome])
	_q.kit.need(problems, outcome["frames"].size() == 1 and outcome["frames"][0] == int(record["frame"]) + _arming_to_blast and outcome["frames"][0] == spawned + _turret_to_kill, "the destruction came in frame %s, the Mine's blast frame is %d and the Shot's %d" % [outcome["frames"], int(record["frame"]) + _arming_to_blast, spawned + _turret_to_kill])
	_q.kit.need(problems, _q.tokens.counts()[1][Quick.MOTORBIKE] == tokens[1][Quick.MOTORBIKE] - 1, "the Motorbike Tokens went %d -> %d" % [tokens[1][Quick.MOTORBIKE], _q.tokens.counts()[1][Quick.MOTORBIKE]])
	var first: String = "the Mine first (it was spent)" if mine.state == Mine.State.SPENT else "the Shot first (the Mine stayed live)"
	measured.append("turret_and_mine=%s" % ("mine_first" if mine.state == Mine.State.SPENT else "shot_first"))
	_q.kit.verdict("turret_shot_and_mine_on_one_unit", problems, "a Turret's Shot and a Mine that went live in the same physics frame (%s) took Player 2's last Motorbike once: one destruction, one Token, one Round end, %s" % [str(outcome["frames"]), first])


## lay_on_the_loss_frame (AC-1, AC-6): Player 1's Truck presses E so that the press is read in the very frame a Mine
## takes Player 2's last Motorbike (timed by the control of _doubles()). The MatchController ends the Round and pauses
## the tree in that frame before the MineLayer's tick, so nothing is laid or refused; the request the MineLayer holds is
## dropped after R, when the Units are out of play.
func _lay_on_the_loss_frame() -> void:
	var problems: PackedStringArray = []
	await _new_round()
	await _k.put(0, Quick.TRUCK, TRUCK_SPOT, Vector3.RIGHT)
	await _k.place_mine(KILL_SPOT, 0)
	var layer: MineLayer = _k.layers[0]
	var laid: int = _k.laid.size()
	var refused: int = _k.refused[0].size()
	var changes: int = _k.changes[0].size()
	var mark: int = _q.tokens.events.size()
	var spawned: int = _r.spawn_now(1, Quick.MOTORBIKE, KILL_SPOT, Vector3.RIGHT)
	await _q.tokens.press_on(spawned + _spawn_to_blast - 1, [Kit14.LAY_KEYS[0]] as Array[Key])
	await _r.wait_over()
	await _q.kit.advance(2)
	var outcome: Dictionary = _r.outcome(mark)
	var held: bool = bool(layer.get("_lay_requested"))
	_q.kit.need(problems, outcome["overs"] == 1 and outcome["winner"] == 0 and outcome["frames"].size() == 1, "the Round: %s" % [outcome])
	_q.kit.need(problems, held, "the press was not read in the loss frame: the MineLayer holds no request")
	_q.kit.need(problems, _k.laid.size() == laid and _k.refused[0].size() == refused and _k.changes[0].size() == changes, "after the loss frame: %d Mines laid, %d refusals, %d count reports" % [_k.laid.size() - laid, _k.refused[0].size() - refused, _k.changes[0].size() - changes])
	_q.kit.need(problems, _k.note(0) == "hidden" and layer.mines_left == 5, "Player 1's notice reads '%s' and its count %d" % [_k.note(0), layer.mines_left])
	await _new_round()
	await _q.kit.advance(Kit14.SETTLE)
	_q.kit.need(problems, _k.laid.size() == laid and _k.refused[0].size() == refused and not bool(layer.get("_lay_requested")), "after R: %d Mines laid, %d refusals, a request held: %s" % [_k.laid.size() - laid, _k.refused[0].size() - refused, layer.get("_lay_requested")])
	_q.kit.verdict("lay_on_the_loss_frame", problems, "Player 1's Truck pressed E so that the press was read in the physics frame a Mine took Player 2's last Motorbike (frame %s): the Round ended and the tree paused before the MineLayer's tick, so nothing was laid and nothing refused, the count stayed 5 and the notice hidden; the request the MineLayer held was dropped after R, with the Units out of play" % [outcome["frames"]])
