extends RefCounted
## The Round with explosions playing (Story 016 AC-2's second half, AC-7): an explosion changes nothing the Round does,
## and the one that ends a Round plays on under the Round-over screen. carrier_wreck: a Carrier's real Self-destruct
## outside its Base takes its Token and drops the Flag at the wreck on the destroying tick, and its Player's Unit
## respawns on the tick the Round's delay gives. loss_under_the_pause: Player 2's last Motorbike's Self-destruct ends
## the Round on its tick, "Player 1 wins!" in both views, the tree paused, and the Explosion counts a tick on every
## physics frame of the pause, changes its pieces and frees itself 120 ticks after it was added, still paused.
## double_loss_under_the_pause: both last Motorbikes' Self-destruct in one frame is "Nobody wins!", once, with two
## Explosions playing under the pause. r_removes_them: R while those two still play frees both at once and the new Round
## starts clean. Run by explosions.gd. Tooling only. Implements: production/epics/wasteland-fire/story-016-unit-
## explosions.md AC-2 and AC-7.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")
## The text of the Round-over screen's first line for a win and for the double loss.
const WIN_TEXT: String = "Player %d wins!"
const NOBODY_TEXT: String = "Nobody wins!"
## The Motorbikes each Player has in the loss Rounds.
const LAST_MOTORBIKE: int = 1
## Ticks the Explosion under the pause is followed for: its life and a few more.
const FOLLOW_TICKS: int = 130
## Ticks the two Explosions of the double loss play before R is pressed.
const R_AFTER_TICKS: int = 20
## The ticks a Round may take to end after the key.
const WAIT_TICKS: int = 60

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick
var _ui: UiKit
var _stock_before: int = 0
## Every Flag drop of the Round: {tick, frame, flag, at}.
var _drops: Array[Dictionary] = []


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q
	_ui = UiKit.new(kit.q.tokens)
	_stock_before = int(kit.q.harness.split.field.token_stock.counts.get(&"motorbike", 0))
	_q.controller.flag_dropped.connect(func(index: int) -> void:
		_drops.append({"tick": _q.harness.ticks, "frame": Engine.get_physics_frames(), "flag": index, "at": _k.t.w.s.flags.flags[index].global_position}))


func run() -> void:
	await _carrier_wreck()
	await _end_the_round()
	await _restart_with(LAST_MOTORBIKE)
	await _loss_under_the_pause()
	await _restart_with(LAST_MOTORBIKE)
	await _double_loss_under_the_pause()
	await _r_removes_them()


## Sets the Motorbikes each Player starts the next Round with (the field's own stock, never the shared file) and presses R.
func _restart_with(count: int) -> void:
	_q.harness.split.field.token_stock.counts[&"motorbike"] = count
	await _k.t.w.restart()


## Both Defences of Base A down and Player 2's Motorbike carrying Base A's Flag backed out of its box: the Carrier.
func _make_carrier() -> bool:
	await _k.fresh()
	await _k.t.restore_all()
	for side: int in Kit13.NAMES.size():
		_k.t.turret(0, side).destroy()
	_k.t.w.wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Kit16.SETTLE)
	var taken: bool = await _k.t.w.take_flag(1, 0, Walls.GATE)
	await _k.t.w.back_out(1, 0, Walls.GATE)
	return taken


## carrier_wreck: see the class doc.
func _carrier_wreck() -> void:
	var problems: PackedStringArray = []
	var taken: bool = await _make_carrier()
	var s: Swap = _k.t.w.s
	var counts: Array = _q.tokens.counts()
	var mark: int = _q.tokens.events.size()
	var drops: int = _drops.size()
	var blasts: int = _k.blasts.size()
	await _q.tokens.destruct(1)
	await _q.kit.advance(2)
	var killed: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	_q.kit.need(problems, taken and killed.size() == 1 and _drops.size() == drops + 1 and _k.blasts.size() == blasts + 1, "the Carrier's destruction: taken %s, %d destructions, %d Flag drops, %d Explosions" % [taken, killed.size(), _drops.size() - drops, _k.blasts.size() - blasts])
	if killed.size() == 1 and _drops.size() == drops + 1 and _k.blasts.size() == blasts + 1:
		var event: Dictionary = killed[0]
		var drop: Dictionary = _drops[-1]
		var blast: Dictionary = _k.blasts[-1]
		_q.kit.need(problems, int(event["now"]["frame"]) == int(drop["frame"]) and int(blast["frame"]) == int(drop["frame"]), "the destruction came in frame %d, the Flag dropped in frame %d and the Explosion in frame %d" % [int(event["now"]["frame"]), int(drop["frame"]), int(blast["frame"])])
		_q.kit.need(problems, event["now"]["counts"][1][Quick.MOTORBIKE] == counts[1][Quick.MOTORBIKE] - 1, "the Motorbike Tokens of Player 2 went %d -> %d in the destroying tick" % [counts[1][Quick.MOTORBIKE], event["now"]["counts"][1][Quick.MOTORBIKE]])
		var wreck: Vector3 = (blast["node"] as Explosion).global_position
		var apart: float = Vector2(wreck.x - (drop["at"] as Vector3).x, wreck.z - (drop["at"] as Vector3).z).length()
		_q.kit.need(problems, apart <= 0.5, "the Flag lies %.2f m from the Explosion's centre" % apart)
	var spawns: int = _q.units.spawns.size()
	var destroyed_tick: int = _k.destroyed[-1]["tick"]
	_q.kit.need(problems, await _q.tokens.spawn(1, Quick.MOTORBIKE), "Player 2's Unit did not come back")
	var after: Array[Vector2i] = []
	for index: int in range(spawns, _q.units.spawns.size()):
		after.append(_q.units.spawns[index])
	var delay: int = _q.harness.ticks_in(_q.controller.rules.respawn_delay_seconds)
	_q.kit.need(problems, after.size() == 1 and after[0].x == 1 and after[0].y - destroyed_tick == delay, "Player 2 respawned %s ticks after its destruction, the Round's delay is %d" % [after[0].y - destroyed_tick if after.size() == 1 else after, delay])
	measured.append("respawn_ticks=%d" % delay)
	_q.kit.verdict("carrier_wreck", problems, "Player 2's Carrier Self-destructed outside Base A: in that one physics frame its Motorbike Token was taken, Base A's Flag dropped at the wreck (within 0.5 m of the Explosion's centre) and one Explosion came; Player 2 chose at once and its Unit respawned exactly %d ticks after the destruction, the Round's delay" % delay)


## A delivery ends the Round, so that R can start the next one with the stock the loss Rounds need.
func _end_the_round() -> void:
	var problems: PackedStringArray = []
	var taken: bool = await _make_carrier()
	var delivered: bool = await _k.t.w.deliver(1)
	_q.kit.need(problems, taken and delivered and _q.controller.is_round_over(), "the Round did not end by Player 2's delivery (taken %s, delivered %s)" % [taken, delivered])
	_q.kit.verdict("round_ended_for_the_loss_rounds", problems, "Player 2 carried Base A's Flag home: the Round was over, so that R could start the loss Rounds")


## The Round-over screens' first line in both views.
func _lines() -> PackedStringArray:
	return PackedStringArray([_ui.over_screen(0).find_child("WinnerLabel", true, false).text, _ui.over_screen(1).find_child("WinnerLabel", true, false).text])


## Player 2 Self-destructs (the real key) with one Motorbike, outside its Base: the number of the destructions and of the
## Round ends after the key, in order to be read by the caller.
func _wait_over() -> void:
	for _tick: int in WAIT_TICKS:
		if _q.controller.is_round_over():
			return
		await _q.kit.tick()


## The Explosion of the record at `index` followed for FOLLOW_TICKS ticks under the pause: how many ticks it counted, whether
## its fireball changed, and whether the tree stayed paused. {counted, moved, paused, every_tick}.
func _follow(index: int) -> Dictionary:
	var blast: Explosion = _k.blasts[index]["node"] as Explosion
	var seen: Dictionary = {"counted": 0, "moved": false, "paused": true, "every_tick": true}
	var last: int = blast.ticks_played()
	var first: float = (blast.get_node(Kit16.FIREBALL) as Node3D).scale.x
	for _tick: int in FOLLOW_TICKS:
		await _q.kit.tick()
		seen["paused"] = bool(seen["paused"]) and _q.harness.get_tree().paused
		if not is_instance_valid(blast) or not blast.is_inside_tree():
			break
		seen["every_tick"] = bool(seen["every_tick"]) and blast.ticks_played() == last + 1
		last = blast.ticks_played()
		seen["counted"] = last
		seen["moved"] = bool(seen["moved"]) or absf((blast.get_node(Kit16.FIREBALL) as Node3D).scale.x - first) > 0.0
	return seen


func _loss_under_the_pause() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.clear(0)
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.MOTORBIKE, Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit16.SETTLE + 15)
	var mark: int = _q.tokens.events.size()
	var before: int = _k.blasts.size()
	await _q.tokens.destruct(1)
	await _wait_over()
	var killed: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	var overs: Array[Dictionary] = _q.tokens.events_of(&"over", mark)
	_q.kit.need(problems, killed.size() == 1 and overs.size() == 1 and int(killed[0]["now"]["frame"]) == int(overs[0]["now"]["frame"]) and _q.controller.winner_index() == 0, "the last Motorbike's destruction: %d destructions, %d Round ends, winner %d" % [killed.size(), overs.size(), _q.controller.winner_index()])
	_q.kit.need(problems, _lines() == PackedStringArray([WIN_TEXT % 1, WIN_TEXT % 1]) and _q.harness.get_tree().paused, "the Round-over screens read %s, the tree is paused %s" % [_lines(), _q.harness.get_tree().paused])
	_q.kit.need(problems, _k.blasts.size() == before + 1 and int(_k.blasts[before]["frame"]) == int(overs[0]["now"]["frame"]), "the deciding destruction made %d Explosions" % (_k.blasts.size() - before))
	var seen: Dictionary = await _follow(before)
	var record: Dictionary = _k.blasts[before]
	_q.kit.need(problems, bool(seen["paused"]) and bool(seen["every_tick"]) and bool(seen["moved"]) and int(seen["counted"]) > Kit16.LIFETIME_TICKS - 40, "under the pause the Explosion counted %s ticks, one on every frame %s, moved its fireball %s, the tree stayed paused %s" % [seen["counted"], seen["every_tick"], seen["moved"], seen["paused"]])
	_q.kit.need(problems, int(record["gone_frame"]) - int(record["frame"]) == Kit16.LIFETIME_TICKS and bool(record["paused"]), "it left %d frames after it was added, the tree paused then: %s" % [int(record["gone_frame"]) - int(record["frame"]), record["paused"]])
	_q.kit.need(problems, _q.controller.is_round_over() and _q.controller.winner_index() == 0, "the Round is no longer over with Player 1 the winner")
	measured.append("paused_ticks=%d" % int(seen["counted"]))
	_q.kit.verdict("loss_under_the_pause", problems, "Player 2's last Motorbike's real Self-destruct ended the Round in its own frame (%d) with '%s' in both views and the tree paused; its Explosion then counted a tick on every physics frame of the pause, changed its fireball, and freed itself %d frames after it was added, still paused" % [int(killed[0]["now"]["frame"]) if not killed.is_empty() else -1, WIN_TEXT % 1, Kit16.LIFETIME_TICKS])


func _double_loss_under_the_pause() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.clear(0)
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.MOTORBIKE, Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit16.SETTLE + 15)
	var mark: int = _q.tokens.events.size()
	var before: int = _k.blasts.size()
	await _q.kit.press_settled(Kit.KEYS_DESTRUCT_BOTH)
	await _wait_over()
	var killed: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	var overs: Array[Dictionary] = _q.tokens.events_of(&"over", mark)
	var frames: Array = killed.map(func(event: Dictionary) -> int: return event["now"]["frame"])
	_q.kit.need(problems, killed.size() == 2 and frames[0] == frames[1] and overs.size() == 1 and _q.controller.winner_index() == MatchController.NO_WINNER, "the two destructions: frames %s, %d Round ends, winner %d" % [frames, overs.size(), _q.controller.winner_index()])
	_q.kit.need(problems, _lines() == PackedStringArray([NOBODY_TEXT, NOBODY_TEXT]), "the Round-over screens read %s, not '%s' in both" % [_lines(), NOBODY_TEXT])
	_q.kit.need(problems, _k.blasts.size() == before + 2 and _k.playing().size() == 2, "%d Explosions came and %d play under the pause" % [_k.blasts.size() - before, _k.playing().size()])
	var at: Array[int] = [_k.blasts[before]["node"].ticks_played(), _k.blasts[before + 1]["node"].ticks_played()]
	await _q.kit.advance(R_AFTER_TICKS)
	var now: Array[int] = [_k.blasts[before]["node"].ticks_played(), _k.blasts[before + 1]["node"].ticks_played()]
	_q.kit.need(problems, now[0] == at[0] + R_AFTER_TICKS and now[1] == at[1] + R_AFTER_TICKS and _q.harness.get_tree().paused, "the two Explosions counted %s then %s ticks over %d paused frames" % [at, now, R_AFTER_TICKS])
	_q.kit.verdict("double_loss_under_the_pause", problems, "both last Motorbikes' Self-destruct in frame %s: one Round end, '%s' in both views, the two Explosions (one per Unit) counted every one of the next %d paused frames" % [str(frames), NOBODY_TEXT, R_AFTER_TICKS])


func _r_removes_them() -> void:
	var problems: PackedStringArray = []
	var playing: int = _k.playing().size()
	var before: int = _k.blasts.size()
	_q.harness.split.field.token_stock.counts[&"motorbike"] = _stock_before
	_q.kit.need(problems, await _q.tokens.restart(), "the restart key brought no new Round")
	var gone: bool = true
	for record: Dictionary in _k.blasts.slice(before - 2):
		gone = gone and int(record["gone_frame"]) >= 0 and int(record["played"]) < Kit16.LIFETIME_TICKS
	_q.kit.need(problems, playing == 2 and _k.playing().is_empty() and gone, "%d played, %d play after R, all gone early: %s" % [playing, _k.playing().size(), gone])
	_q.kit.need(problems, not _q.harness.get_tree().paused and not _q.controller.is_round_over(), "the new Round is paused or over")
	await _q.kit.advance(Kit16.SETTLE)
	await _k.t.w.s.both_play()
	_q.kit.verdict("r_removes_them", problems, "R pressed %d paused frames after the double loss freed both playing Explosions at once (they had counted %d ticks of %d) and no Explosion played in the new Round" % [R_AFTER_TICKS, int(_k.blasts[before - 1]["played"]), Kit16.LIFETIME_TICKS])
