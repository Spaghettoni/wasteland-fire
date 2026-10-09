extends RefCounted
## What a Turret's Shot does to the Round and what the Round does to the Turrets (Story 013 AC-5,
## AC-6 and AC-7), in real Rounds on the shipped Turrets and Map 01. carrier: Player 2's Motorbike
## takes Base A's Flag with both Turrets down, the Turrets stand again, and the Carrier reverses out
## under their fire: its destruction takes one Token (the HUD line and the panel), the Flag drops at
## the wreck on the ground and in sight, the Round runs on; Player 2's next Motorbike on the dropped
## Flag is locked (the line shows), while Player 1's Motorbike, the owner, takes its own Flag back
## with both Turrets standing and its view never shows the line, and carrying it touches Base B's Flag
## with Base B's Turrets standing without the line. loss, with one Motorbike a Player: a Turret's kill
## of the last Motorbike ends the Round in that physics tick with "Player 1 wins!", and the restart
## (R) brings every Turret back whatever the Round left of it. double: the same kill in the very frame
## the other Player's last Motorbike Self-destructs outside its Base is "Nobody wins!", announced once.
## Run by turrets.gd. Implements: production/epics/wasteland-fire/story-013-turrets.md AC-5, AC-6 and
## AC-7. Tooling only. Every number comes from the game's data; the scenario types only its test
## inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 008 helpers (token_kit.gd): the keys, the counts, the HUD lines, the Round's events.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Walls' names and sizes.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The Story 008 UI helpers (token_ui_kit.gd): the Round-over screen.
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## Ticks a reading is taken over after a settle, and the ticks a tank of waiting may take.
const SAMPLE_TICKS: int = 30
const SETTLE_TICKS: int = 10
const WAIT_TICKS: int = 300
## Metres in front of a Turret, along its rest heading, a victim is put at.
const AHEAD: float = 15.0
## The bearing off the rest heading a Truck is shown to a Turret at to turn its head, degrees, and the
## ticks it is shown for.
const SHOW_DEGREES: float = 60.0
const SHOW_TICKS: int = 60
## The Motorbikes a Player has in the loss Rounds (the runner's stock for the others stays).
const LAST_MOTORBIKE: int = 1
## Ticks Player 1's Motorbike fires before the victim appears, so Shots of its own are in the air when
## the Round ends.
const AIR_TICKS: int = 30
## The most ticks after the Round starts again that a Turret may take to fire at a target dead ahead
## (a stale cooldown would be more than twenty).
const READY_TICKS: int = 8
## The text of the Round-over screen's first line for a win and for the double loss.
const WIN_TEXT: String = "Player %d wins!"
const NOBODY_TEXT: String = "Nobody wins!"
## A Motorbike left with this much hit points dies of any Shot.
const ONE_SHOT_HIT_POINTS: float = 1.0
## How near the wreck, metres, the dropped Flag must lie, and how high at most its origin.
const WRECK_TOLERANCE: float = 0.5
const FLAG_HEIGHT_MAX: float = 0.6

var _k: Kit13
var _ui: UiKit
## What each check found, for the RESULT line.
var measured: PackedStringArray = []
## The frames from a Turret's Shot to the destruction it brings in loss()'s control Round, which
## double() times the Self-destruct by; the Motorbikes a Player started the scenario with.
var _lethal: int = -1
var _stock_before: int = 0


func _init(kit: Kit13) -> void:
	_k = kit
	_ui = UiKit.new(kit.w.s.q.tokens)


## The checks, in order. The last of carrier() leaves a Round over for the loss Rounds' stock.
func run() -> void:
	await _carrier()
	await _loss()
	await _double()


## How often, over `ticks` ticks, the Player's view showed the line, the Player carried a Flag and
## the controller said the lock alone stops the Player: {ticks, line, carry, locked}. A coroutine.
func _sample(player: int, ticks: int) -> Dictionary:
	var q: Quick = _k.w.s.q
	var seen: Dictionary = {"ticks": 0, "line": 0, "carry": 0, "locked": 0}
	q.kit.on_tick = func() -> void:
		seen["ticks"] += 1
		seen["line"] += 1 if _k.notice(player).visible else 0
		seen["carry"] += 1 if _k.w.carrying(player) else 0
		seen["locked"] += 1 if q.controller.is_flag_locked_for(player) else 0
	await q.kit.advance(ticks)
	q.kit.on_tick = Callable()
	return seen


## carrier (AC-5, AC-6): see the class doc.
func _carrier() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var flags: Object = _k.w.s.flags
	var notes: PackedStringArray = []
	var raider: int = 1
	var owner_player: int = 0
	var flag: Flag = flags.flags[0]
	await _k.restore_all()
	_k.w.wall(0, Walls.GATE).destroy()
	_k.turret(0, Kit13.LEFT).destroy()
	_k.turret(0, Kit13.RIGHT).destroy()
	await q.kit.advance(Kit13.SETTLE)
	q.kit.need(problems, await _k.w.take_flag(raider, 0, Walls.GATE), "Player 2's Motorbike did not take Base A's Flag through the breach with both Turrets down")
	for side: int in Kit13.NAMES.size():
		_k.turret(0, side).restore()
	await q.kit.advance(Kit13.SETTLE)
	# the Carrier reverses out under their fire and is destroyed
	var mark: int = q.tokens.events.size()
	var before: Array = q.tokens.counts()
	var drops: int = flags.drops.size()
	var fired: int = _k.firing.size()
	var shot_mark: int = _k.hp_mark()
	await flags.drive_until(raider, -1, Swap.CRUISE, func() -> bool: return not q.units.units[raider].is_alive)
	await q.tokens.wait_for(&"destroyed", mark)
	var found: Array[Dictionary] = q.tokens.events_of(&"destroyed", mark)
	var event: Dictionary = found[0] if found.size() == 1 else {"arg": -1, "type": &"", "now": {}, "later": {}}
	var wanted: Array = Tokens.charged(before, raider, Quick.MOTORBIKE)
	q.kit.need(problems, found.size() == 1 and event["arg"] == raider and event["type"] == &"motorbike", "the Carrier's destruction: %d events, Player %d, %s" % [found.size(), int(event["arg"]) + 1, event["type"]])
	q.kit.need(problems, [event["now"].get("counts"), event["later"].get("counts"), q.tokens.counts()] == [wanted, wanted, wanted], "the Tokens after the Turret's kill were %s, not %s" % [q.tokens.counts(), wanted])
	var carrier_slot: int = q.tokens.carrier_index()
	q.kit.need(problems, q.tokens.hud_line(raider) == q.tokens.hud_text(raider, wanted[raider][carrier_slot]) and q.tokens.hud_line(owner_player) == q.tokens.hud_text(owner_player, wanted[owner_player][carrier_slot]), "the HUD lines read '%s' and '%s'" % [q.tokens.hud_line(owner_player), q.tokens.hud_line(raider)])
	var killed_by_turret: bool = false
	for index: int in range(fired, _k.firing.size()):
		killed_by_turret = killed_by_turret or _k.hit(_k.firing[index], raider)
	q.kit.need(problems, killed_by_turret and _k.fired_since(_k.turret(0, Kit13.LEFT), fired) + _k.fired_since(_k.turret(0, Kit13.RIGHT), fired) >= 1, "no Turret Shot ended on the Carrier in the frame its hit points changed")
	var wreck: Vector3 = flags.wrecks[-1] if not flags.wrecks.is_empty() else Vector3.INF
	var apart: float = Vector2(flag.global_position.x - wreck.x, flag.global_position.z - wreck.z).length()
	q.kit.need(problems, flags.drops.size() == drops + 1 and flag.state == Flag.State.DROPPED and apart <= WRECK_TOLERANCE and flag.global_position.y <= FLAG_HEIGHT_MAX and flag.is_visible_in_tree() and not q.controller.is_round_over(), "the Flag after the kill: %d drops, %s, %.2f m from the wreck, %.2f m high, visible %s, Round over %s" % [flags.drops.size() - drops, flags.state_name(0), apart, flag.global_position.y, flag.is_visible_in_tree(), q.controller.is_round_over()])
	notes.append("a Turret's Shot destroyed the Carrier: Player 2's Motorbike Tokens %d -> %d (HUD '%s'), the Flag dropped %.2f m from the wreck on the ground, the Round ran on" % [before[raider][carrier_slot], wanted[raider][carrier_slot], q.tokens.hud_line(raider), apart])
	measured.append("carrier=%d>%d" % [before[raider][carrier_slot], wanted[raider][carrier_slot]])
	# the other Player's next Motorbike on the dropped Flag is locked
	await _k.w.s.play(raider, Quick.MOTORBIKE)
	flags.teleport(raider, flag.global_position, _k.w.way(0, Vector3.FORWARD))
	await q.kit.advance(SETTLE_TICKS)
	var locked: Dictionary = await _sample(raider, SAMPLE_TICKS)
	q.kit.need(problems, int(locked["carry"]) == 0 and int(locked["line"]) == int(locked["ticks"]) and int(locked["locked"]) == int(locked["ticks"]) and flag.state == Flag.State.DROPPED and q.units.units[raider].is_alive, "Player 2's next Motorbike on the dropped Flag: %s, Flag %s" % [locked, flags.state_name(0)])
	notes.append("Player 2's next Motorbike on the dropped Flag picked nothing up for %d ticks and its view showed the line" % SAMPLE_TICKS)
	q.units.units[raider].leave_play()
	await q.kit.advance(Kit13.SETTLE)
	# the owner takes its own Flag back with both Turrets standing and never sees the line
	var picks: int = flags.pick_ups.size()
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	flags.teleport(owner_player, flag.global_position + out * 8.0, -out)
	await q.kit.advance(Kit13.SETTLE)
	var seen_line: Array[int] = [0]
	q.kit.on_tick = func() -> void: seen_line[0] += 1 if _k.notice(owner_player).visible else 0
	var own: bool = await flags.drive_until(owner_player, 1, Swap.CRUISE, func() -> bool: return flags.pick_ups.size() > picks) > 0
	q.kit.on_tick = Callable()
	var standing: bool = _k.turret(0, Kit13.LEFT).is_standing and _k.turret(0, Kit13.RIGHT).is_standing
	var pick: Vector3i = flags.pick_ups[picks] if flags.pick_ups.size() > picks else Vector3i(-1, -1, -1)
	q.kit.need(problems, own and standing and pick.x == owner_player and pick.y == 0 and seen_line[0] == 0, "the owner's Motorbike on its dropped Flag: picked up %s by %d, Turrets standing %s, the line shown on %d ticks" % [pick, pick.x, standing, seen_line[0]])
	notes.append("Player 1's Motorbike took its own dropped Flag back with both Turrets standing and its view never showed the line")
	# carrying it, the owner touches the other Base's Flag
	_k.w.wall(1, Walls.GATE).destroy()
	var seat: Vector3 = _k.w.point(1, Walls.SEAT + Walls.OUT[Walls.GATE] * 1.0)
	var picks_b: int = flags.pick_ups.size()
	flags.teleport(owner_player, seat, _k.w.way(1, -Walls.OUT[Walls.GATE]))
	await q.kit.advance(SETTLE_TICKS)
	var carrying: Dictionary = await _sample(owner_player, SAMPLE_TICKS)
	q.kit.need(problems, flags.touching(1, owner_player) and int(carrying["line"]) == 0 and int(carrying["locked"]) == 0 and flags.pick_ups.size() == picks_b and flags.flags[0].state == Flag.State.CARRIED, "the owner carrying its own Flag at Base B's Flag: touching %s, %s, pick-ups %d" % [flags.touching(1, owner_player), carrying, flags.pick_ups.size() - picks_b])
	notes.append("carrying it at Base B's Flag (its Turrets standing) it was shown no line and picked up nothing")
	# home with it, then the win that ends the Round
	var seats: int = flags.seats.size()
	flags.teleport(owner_player, _k.w.s.outside_point(owner_player), _k.w.s.into_base(owner_player))
	await q.kit.advance(Kit13.SETTLE)
	var home: bool = await flags.drive_until(owner_player, 1, Swap.CRUISE, func() -> bool: return flags.seats.size() > seats) > 0
	q.kit.need(problems, home and flag.state == Flag.State.AT_HOME, "the owner did not bring its Flag home (%s)" % flags.state_name(0))
	for side: int in Kit13.NAMES.size():
		_k.turret(1, side).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var raid: bool = await _k.w.take_flag(owner_player, 1, Walls.GATE)
	await _k.w.back_out(owner_player, 1, Walls.GATE)
	var won: bool = raid and await _k.w.deliver(owner_player)
	q.kit.need(problems, won and q.controller.winner_index() == owner_player, "Player 1 did not win with Base B's Flag (taken %s)" % raid)
	notes.append("home with it, then Player 1 took Base B's Flag and won")
	q.kit.verdict("carrier", problems, " | ".join(notes))


## Sets the Motorbikes each Player starts a Round with, on the field's own stock (the runner's copy,
## never the shared file); the next restart reads it.
func _set_motorbikes(count: int) -> void:
	_k.w.s.q.harness.split.field.token_stock.counts[&"motorbike"] = count


## Both Players choose the Motorbike after the restart key: the Round starts again with `count`
## Motorbikes each.
func _restart_with(count: int) -> void:
	_set_motorbikes(count)
	await _k.w.restart()


## loss (AC-6, AC-7): see the class doc. Returns nothing; leaves the Round that follows running.
func _loss() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var flags: Object = _k.w.s.flags
	var notes: PackedStringArray = []
	_stock_before = int(q.harness.split.field.token_stock.counts.get(&"motorbike", 0))
	await _restart_with(LAST_MOTORBIKE)
	q.kit.need(problems, q.tokens.counts()[0][Quick.MOTORBIKE] == LAST_MOTORBIKE and q.tokens.counts()[1][Quick.MOTORBIKE] == LAST_MOTORBIKE, "each Player has %s Motorbikes, not %d" % [q.tokens.counts(), LAST_MOTORBIKE])
	# what the Round leaves the Turrets in: one fallen, one hurt with its head turned, one fallen
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var b_forward: Vector3 = _k.w.way(1, Vector3.FORWARD)
	var a_left: Turret = _k.turret(0, Kit13.LEFT)
	var a_right: Turret = _k.turret(0, Kit13.RIGHT)
	var b_left: Turret = _k.turret(1, Kit13.LEFT)
	var b_right: Turret = _k.turret(1, Kit13.RIGHT)
	b_left.destroy()
	b_right.apply_damage(b_right.stats.max_hit_points - 40.0)
	var bearing: Vector3 = b_forward.rotated(Vector3.UP, deg_to_rad(SHOW_DEGREES))
	await _k.stage(0, Quick.TRUCK, b_right.global_position + bearing * AHEAD, -bearing)
	await _k.watch(SHOW_TICKS)
	var turned: float = b_right.head.rotation.y
	q.kit.need(problems, absf(turned) >= 0.3 and b_right.hit_points == 40.0 and not b_left.is_standing, "the Turrets were not left turned, hurt and fallen before the Round ended (yaw %.3f, %.0f hit points)" % [turned, b_right.hit_points])
	a_left.destroy()
	# the control Round: a Turret kills Player 2's last Motorbike
	await _k.clear(0)
	await _k.w.park(0)
	q.units.retype(0, Quick.MOTORBIKE, Quick.LANE_SPOT, Vector3.RIGHT)
	await q.kit.advance(Kit13.SETTLE)
	await q.kit.advance(_k.w.longest_cadence())
	await _k.clear(1)
	q.harness.set_key(q.harness.fire_key(0), true)
	await q.kit.advance(AIR_TICKS)
	var victim_at: Vector3 = _k.ahead(a_right, 0, AHEAD)
	var over_mark: int = q.tokens.events.size()
	var fired: int = _k.firing.size()
	await q.put(1, q.units.stats(Quick.MOTORBIKE), victim_at, -forward)
	q.units.units[1].apply_damage(q.units.units[1].hit_points - ONE_SHOT_HIT_POINTS)
	await _wait_over()
	var in_flight: int = q.units.units[0].get_tree().get_nodes_in_group(&"shots").size()
	q.harness.set_key(q.harness.fire_key(0), false)
	await q.kit.advance(Kit13.SETTLE)
	var killed: Array[Dictionary] = q.tokens.events_of(&"destroyed", over_mark)
	var overs: Array[Dictionary] = q.tokens.events_of(&"over", over_mark)
	var first: Dictionary = _k.shots_of(a_right)[-1] if not _k.shots_of(a_right).is_empty() else {}
	q.kit.need(problems, killed.size() == 1 and overs.size() == 1 and killed[0]["now"]["frame"] == overs[0]["now"]["frame"] and q.controller.winner_index() == 0, "the Turret's kill of the last Motorbike: %d destructions, %d Round ends, frames %s and %s, winner %d" % [killed.size(), overs.size(), killed[0]["now"]["frame"] if not killed.is_empty() else -1, overs[0]["now"]["frame"] if not overs.is_empty() else -1, q.controller.winner_index()])
	q.kit.need(problems, not first.is_empty() and _k.hit(first, 1) and _k.fired_since(a_right, fired) >= 1, "the last Shot of the Turret did not end on Player 2's Motorbike")
	var lines: PackedStringArray = [_ui.over_screen(0).find_child("WinnerLabel", true, false).text, _ui.over_screen(1).find_child("WinnerLabel", true, false).text]
	q.kit.need(problems, lines == PackedStringArray([WIN_TEXT % 1, WIN_TEXT % 1]), "the Round-over screens read %s, not '%s'" % [lines, WIN_TEXT % 1])
	notes.append("a Turret's Shot killed Player 2's last Motorbike and the Round ended in that physics frame (%d) with '%s' in both views, %d Shots still in the air" % [int(killed[0]["now"]["frame"]) if not killed.is_empty() else -1, WIN_TEXT % 1, in_flight])
	q.kit.need(problems, in_flight > 0, "no Shot was in the air when the Round ended, so the restart had none to free")
	var lethal: int = int(killed[0]["now"]["frame"]) - int(first["frame"]) if not killed.is_empty() and not first.is_empty() else -1
	_lethal = lethal
	measured.append("lethal=%d" % lethal)
	# the restart brings everything back (that the heads are not drawn swinging across the tick it is
	# handled in, the head's interpolation being reset, shows only on a window that renders between two
	# physics ticks: measurements/turrets_swing_probe.gd.txt)
	await _k.w.restart()
	var restored: PackedStringArray = []
	for turret: Turret in _k.all():
		var rubble: Node3D = turret.get_node("Rubble") as Node3D
		var look: Node3D = turret.get_node("Look") as Node3D
		var whole: bool = turret.is_standing and is_equal_approx(turret.hit_points, turret.stats.max_hit_points) and turret.collision_layer == 1 and turret.collision_mask == 0 \
				and not rubble.visible and look.visible and turret.head.rotation == Vector3.ZERO and turret.state == Turret.State.IDLE and turret.aim_point == Vector3.INF
		q.kit.need(problems, whole, "%s after the restart: standing %s, %.0f hit points, layer %d mask %d, rubble %s, look %s, yaw %.4f, %s" % [turret.get_path(), turret.is_standing, turret.hit_points, turret.collision_layer, turret.collision_mask, rubble.visible, look.visible, turret.head.rotation.y, Turret.State.keys()[turret.state]])
		restored.append("%s" % turret.name)
	var air: int = q.units.units[0].get_tree().get_nodes_in_group(&"shots").size()
	q.kit.need(problems, air == 0, "%d Shots of the Round before were still in the air after the restart" % air)
	notes.append("after R all four Turrets were whole again (one fallen, one at 40 hit points with its head turned %.2f rad, one that fired the last Shot of the Round): standing, 100 hit points, solid, rubble gone, head at rest, idle; %d Shots in the air" % [turned, air])
	# the cadence is ready: a target dead ahead is fired on at once
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(a_right, 0, AHEAD), -forward)
	var ready: Dictionary = await _k.watch(SHOW_TICKS)
	var first_shot: Dictionary = _first_after(a_right, fired, _k.staged_frame)
	var delay: int = int(first_shot["frame"]) - _k.staged_frame if not first_shot.is_empty() else -1
	q.kit.need(problems, delay >= 0 and delay <= READY_TICKS and int(ready[a_right]["shots"]) >= 1, "the first Shot after the restart came %d ticks after the target appeared, not within %d" % [delay, READY_TICKS])
	notes.append("a target dead ahead was fired on %d ticks after it appeared" % delay)
	# the Flag is locked again
	await _k.restore_all()
	_k.w.wall(0, Walls.GATE).destroy()
	var seat: Vector3 = _k.w.point(0, Walls.SEAT + Walls.OUT[Walls.GATE] * 1.0)
	await _k.w.park(0)
	flags.teleport(1, seat, _k.w.way(0, -Walls.OUT[Walls.GATE]))
	await q.kit.advance(SETTLE_TICKS)
	var again: Dictionary = await _sample(1, SAMPLE_TICKS)
	q.kit.need(problems, int(again["carry"]) == 0 and int(again["line"]) == int(again["ticks"]) and int(again["locked"]) == int(again["ticks"]), "Base A's Flag after the restart: %s" % again)
	notes.append("Base A's Flag was locked again (Player 2's Motorbike on it carried nothing for %d ticks, the line shown)" % SAMPLE_TICKS)
	q.kit.verdict("loss", problems, " | ".join(notes))


## The first Shot of a Turret in the record from index `since` on whose frame is at or after `frame`.
func _first_after(who: Turret, since: int, frame: int) -> Dictionary:
	for index: int in range(since, _k.firing.size()):
		var record: Dictionary = _k.firing[index]
		if record["turret"] == who and int(record["frame"]) >= frame:
			return record
	return {}


## Waits at most WAIT_TICKS for the Round to be over.
func _wait_over() -> void:
	for _tick: int in WAIT_TICKS:
		if _k.w.s.q.controller.is_round_over():
			return
		await _k.w.s.q.kit.tick()


## double (AC-6): see the class doc. The control of loss() gave the Shot's flight in frames; this
## Round presses Player 1's Self-destruct so that it acts in the frame the Turret's Shot lands.
func _double() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var a_right: Turret = _k.turret(0, Kit13.RIGHT)
	var lethal: int = _lethal
	q.kit.need(problems, lethal > 0, "the control Round gave no flight to time the Self-destruct by (%d)" % lethal)
	await _k.clear(1)
	await _k.w.park(0)
	await _k.restore_all()
	_k.turret(0, Kit13.LEFT).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var mark: int = q.tokens.events.size()
	var press: Callable = func(_shot: Shot) -> void:
		q.tokens.press_on(Engine.get_physics_frames() + lethal - 1, Tokens.keys(&"destruct", 0))
	a_right.fired.connect(press, CONNECT_ONE_SHOT)
	await q.put(1, q.units.stats(Quick.MOTORBIKE), _k.ahead(a_right, 0, AHEAD), -forward)
	q.units.units[1].apply_damage(q.units.units[1].hit_points - ONE_SHOT_HIT_POINTS)
	await _wait_over()
	await q.kit.advance(Kit13.SETTLE)
	if a_right.fired.is_connected(press):
		a_right.fired.disconnect(press)
	var killed: Array[Dictionary] = q.tokens.events_of(&"destroyed", mark)
	var overs: Array[Dictionary] = q.tokens.events_of(&"over", mark)
	var frames: Array = killed.map(func(event: Dictionary) -> int: return event["now"]["frame"])
	var players: Array = killed.map(func(event: Dictionary) -> int: return event["arg"])
	q.kit.need(problems, killed.size() == 2 and frames[0] == frames[1] and players.has(0) and players.has(1), "the two destructions: players %s in frames %s" % [players, frames])
	q.kit.need(problems, overs.size() == 1 and q.controller.is_round_over() and q.controller.winner_index() == MatchController.NO_WINNER, "the Round ended %d times, over %s, winner %d" % [overs.size(), q.controller.is_round_over(), q.controller.winner_index()])
	var lines: PackedStringArray = [_ui.over_screen(0).find_child("WinnerLabel", true, false).text, _ui.over_screen(1).find_child("WinnerLabel", true, false).text]
	q.kit.need(problems, lines == PackedStringArray([NOBODY_TEXT, NOBODY_TEXT]), "the Round-over screens read %s, not '%s' in both" % [lines, NOBODY_TEXT])
	await _restart_with(_stock_before)
	q.kit.verdict("double", problems, "a Turret's kill of Player 2's last Motorbike and Player 1's Self-destruct (Tab) of its last, outside its Base, in the same physics frame (%s): one Round end, '%s' in both views" % [str(frames), NOBODY_TEXT])
