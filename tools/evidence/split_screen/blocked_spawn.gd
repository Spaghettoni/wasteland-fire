extends RefCounted
## The two checks of the destruction scenario (destruction.gd) about a respawn that falls due while another
## Unit stands on the spawn point: blocked_spawn (the respawn comes on the due tick all the same, on the first
## free spare spawn point of the Base and never inside the blocker; see Unit.is_spot_taken()) and
## blocked_waits (the spawn point and every spare are taken: the Player stays waiting, the controller reads
## one tick and the countdown 1, and the Unit lands on the spawn point the tick it is free).
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3, AC-4,
## AC-6 and AC-7. Made by destruction.gd with the shared kit and record. Tooling only: nothing under src/
## depends on this file.

## The runner, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## One destruction (wait.gd).
const Wait: GDScript = preload("res://tools/evidence/split_screen/wait.gd")
## The record of the scenario (wait_log.gd).
const Log: GDScript = preload("res://tools/evidence/split_screen/wait_log.gd")

## Where the other Player's Unit is parked on Player 1's spawn point, one case each, metres in the spawn
## point's own frame: exactly on it, a metre ahead of it and a few decimetres beside it, the offsets at which a
## Unit put down on a live one went wrong in a preflight probe (no numbers kept).
const BLOCKER_OFFSETS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.3, 0.0, 0.0)]
## How long the blocker holds every spot of the Base after the respawn fell due, as a fraction of the delay.
const BLOCKED_HOLD_FRACTION: float = 0.5
## How long the Unit is watched after it landed, seconds: it must stay where it landed.
const SETTLE_SECONDS: float = 1.0

var _kit: Kit
var _log: Log
var _harness: Harness


func _init(check_kit: Kit, record: Log) -> void:
	_kit = check_kit
	_log = record
	_harness = record.harness


## A respawn onto a Unit standing on the spawn point: for each of BLOCKER_OFFSETS Player 1 destroys itself and
## Player 2's Unit is teleported onto Player 1's spawn point at the offset, where it stays past the due tick.
## The respawn must come on the due tick all the same (the wait as long as the first, within Kit.TICK_SLACK),
## on the first spare spawn point of the Base (slot 0), at least the Unit's own length from the blocker, in
## full working order facing its Base's way with the camera snapped there, and SETTLE_SECONDS later the Unit
## must still stand on the spare on the floor; the blocker is neither moved nor destroyed, then sent home.
func check_blocked_spawn() -> void:
	var problems: PackedStringArray = []
	var cases: PackedStringArray = []
	for offset: Vector3 in BLOCKER_OFFSETS:
		cases.append(await _blocked_case(offset, problems))
	_kit.verdict("blocked_spawn", problems, " || ".join(cases))


## Every spot of the Base taken: Player 1's Base is left without spare spawn points (its exported array is
## set to an empty one and put back before the verdict), Player 2's Unit is parked exactly on Player 1's
## spawn point and Player 1 destroys itself. From the due tick and for BLOCKED_HOLD_FRACTION of the delay
## after it Player 1 must stay waiting: not alive, nothing spawned, seconds_until_respawn() reading exactly
## one tick on every sampled tick and its countdown label reading tr(format) % 1 (the countdown scenario's
## formula, for one tick). Once the blocker has gone home the Unit must land on the spawn point within
## Kit.TICK_SLACK ticks, in full working order with the camera snapped, and stay there on the floor.
func check_blocked_waits() -> void:
	var problems: PackedStringArray = []
	var tag: String = "every spot taken"
	var base: Base = _log.bases[Harness.PLAYER_1]
	var blocker: Unit = _log.units[Harness.PLAYER_2]
	var spawn: Transform3D = base.spawn_point.global_transform
	var saved: Array[Marker3D] = base.spare_spawn_points
	var none: Array[Marker3D] = []
	base.spare_spawn_points = none
	var hold: int = maxi(roundi(BLOCKED_HOLD_FRACTION * float(_log.reference_ticks)), 1)
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	_harness.place(blocker, spawn, _log.cameras[Harness.PLAYER_2])
	var due: int = wait.destroyed_tick + _log.reference_ticks
	await _kit.advance(maxi(due - _harness.ticks, 0))
	var held: String = await _hold_blocked(wait, hold, problems)
	var moved: float = blocker.global_position.distance_to(spawn.origin)
	_kit.need(problems, blocker.is_alive and moved <= Kit.SPAWN_TOLERANCE,
		"%s: the blocker was moved (%.3f m) or destroyed" % [tag, moved])
	var left: int = _harness.ticks
	_send_blocker_home()
	await _log.wait_respawn(wait, hold)
	var landed: String = _land(wait, left, tag, problems)
	var settled: String = await _settle(spawn, tag, problems)
	base.spare_spawn_points = saved
	_kit.need(problems, base.spare_spawn_points == saved and base.spare_spawn_points.size() == saved.size(),
		"the spare spawn points were not put back (%d of %d)" % [base.spare_spawn_points.size(), saved.size()])
	_kit.verdict("blocked_waits", problems, ("%d spare spawn points taken away and the blocker on the spawn point: destroyed at "
		+ "tick %d, due at tick %d; %s; blocker moved %.4f m alive=%s | blocker home at tick %d: %s | %s | spare spawn points "
		+ "put back: %d") % [
			saved.size(), wait.destroyed_tick, due, held, moved, blocker.is_alive, left, landed, settled,
			base.spare_spawn_points.size()])


## The index of the spare spawn point of the Base the Unit stands on, or -1 when it stands on none.
func _slot_index(base: Base, unit: Unit) -> int:
	for index: int in base.spare_spawn_points.size():
		if unit.global_position.distance_to(base.spare_spawn_points[index].global_position) <= Kit.SPAWN_TOLERANCE:
			return index
	return -1


## One blocked respawn: Player 1 destroys itself, the blocker is parked at the offset until the Unit has
## landed and settled, then sent home. Adds to problems and returns the numbers.
func _blocked_case(offset: Vector3, problems: PackedStringArray) -> String:
	var victim: Unit = _log.units[Harness.PLAYER_1]
	var blocker: Unit = _log.units[Harness.PLAYER_2]
	var base: Base = _log.bases[Harness.PLAYER_1]
	var spawn: Transform3D = base.spawn_point.global_transform
	var parked: Transform3D = Transform3D(spawn.basis, spawn.origin + spawn.basis * offset)
	var tag: String = "offset (%.1f, %.1f, %.1f)" % [offset.x, offset.y, offset.z]
	var length: float = _unit_length(victim)
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	_harness.place(blocker, parked, _log.cameras[Harness.PLAYER_2])
	await _log.wait_respawn(wait)
	var late: int = wait.length() - _log.reference_ticks
	_kit.need(problems, wait.spawned_tick >= 0 and absi(late) <= Kit.TICK_SLACK,
		"%s: the wait was %d ticks, expected the first wait's %d (allowed +-%d)" % [
			tag, wait.length(), _log.reference_ticks, Kit.TICK_SLACK])
	var slot: int = _slot_index(base, victim)
	_kit.need(problems, slot == 0, "%s: the Unit stands on spare spawn point %d, expected the first one (0)" % [tag, slot])
	var pose: Transform3D = base.spare_spawn_points[slot].global_transform if slot >= 0 else spawn
	var apart: float = victim.global_position.distance_to(blocker.global_position)
	_kit.need(problems, length > 0.0 and apart >= length,
		"%s: the Unit landed %.2f m from the blocker, within the Unit's own length of %.2f m" % [tag, apart, length])
	var state: PackedStringArray = []
	var landed: String = _log.read_spawn_at(Harness.PLAYER_1, pose, state)
	_kit.need(problems, state.is_empty(), "%s: after the respawn %s" % [tag, "; ".join(state)])
	var settled: String = await _settle(pose, tag, problems)
	var moved: float = blocker.global_position.distance_to(parked.origin)
	_kit.need(problems, blocker.is_alive and moved <= Kit.SPAWN_TOLERANCE,
		"%s: the blocker was moved (%.3f m) or destroyed" % [tag, moved])
	_send_blocker_home()
	return ("%s: respawn %d ticks after the destruction (the first wait's %d, off by %d) on spare spawn point %d, %.2f m from "
		+ "the blocker (at least the Unit's %.2f m) | %s | %s, blocker moved %.4f m alive=%s") % [
			tag, wait.length(), _log.reference_ticks, late, slot, apart, length, landed, settled, moved, blocker.is_alive]


## The hold of blocked_waits: hold ticks on from the due tick with every spot taken, reading after each one
## whether Player 1 is alive or spawned, what the controller's seconds_until_respawn() says (one tick:
## 1 / Engine.physics_ticks_per_second) and what Player 1's countdown label shows (tr(format) % ceili of that
## tick, the countdown scenario's formula). The first reading comes after the due tick's physics step, the one
## that found every spot taken. Adds to problems and returns the numbers.
func _hold_blocked(wait: Wait, hold: int, problems: PackedStringArray) -> String:
	var victim: Unit = _log.units[Harness.PLAYER_1]
	var label: RespawnCountdown = _countdown_of(Harness.PLAYER_1)
	var one_tick: float = float(1) / float(Engine.physics_ticks_per_second)
	var expected_text: String = label.tr(label.format) % ceili(one_tick) if label != null else ""
	var in_play: int = 0
	var seconds_off: int = 0
	var label_off: int = 0
	var seconds_min: float = INF
	var seconds_max: float = -INF
	var texts: PackedStringArray = []
	for _i: int in hold:
		await _kit.tick()
		var seconds: float = _log.controller.seconds_until_respawn(Harness.PLAYER_1)
		seconds_min = minf(seconds_min, seconds)
		seconds_max = maxf(seconds_max, seconds)
		in_play += 1 if victim.is_alive or _log.controller.is_alive(Harness.PLAYER_1) or wait.spawned_tick >= 0 else 0
		seconds_off += 0 if is_equal_approx(seconds, one_tick) else 1
		var text: String = label.text if label != null and label.visible else ""
		label_off += 0 if text == expected_text else 1
		if texts.is_empty() or texts[texts.size() - 1] != text:
			texts.append(text)
	_kit.need(problems, label != null, "no RespawnCountdown carries Player 1's player_index")
	_kit.need(problems, in_play == 0, "the Unit was alive or spawned on %d of the %d held ticks" % [in_play, hold])
	_kit.need(problems, seconds_off == 0,
		"seconds_until_respawn was not one tick (%.6f s) on %d of %d held ticks (it read %.6f to %.6f)" % [
			one_tick, seconds_off, hold, seconds_min, seconds_max])
	_kit.need(problems, label_off == 0, "the countdown did not read '%s' on %d of %d held ticks (it showed [%s])" % [
		expected_text, label_off, hold, ", ".join(texts)])
	return ("held %d ticks from the due tick (%.2f of the delay): alive or spawned on %d, seconds_until_respawn %.6f to %.6f "
		+ "(one tick is %.6f, off on %d), the countdown read '%s' on %d of %d (shown in turn: [%s])") % [
			hold, BLOCKED_HOLD_FRACTION, in_play, seconds_min, seconds_max, one_tick, seconds_off, expected_text,
			hold - label_off, hold, ", ".join(texts)]


## After the blocker left: the respawn came within Kit.TICK_SLACK ticks of its leaving and Player 1's Unit is
## on its spawn point in full working order (read_spawn). Adds to problems and returns the numbers.
func _land(wait: Wait, left: int, tag: String, problems: PackedStringArray) -> String:
	var late: int = wait.spawned_tick - left
	_kit.need(problems, wait.spawned_tick >= 0 and late <= Kit.TICK_SLACK,
		"%s: respawned %d ticks after the blocker left (allowed %d)" % [tag, late, Kit.TICK_SLACK])
	var state: PackedStringArray = []
	var landed: String = _log.read_spawn(Harness.PLAYER_1, state)
	_kit.need(problems, state.is_empty(), "%s: after the respawn %s" % [tag, "; ".join(state)])
	return "respawned %d tick(s) after the blocker left; %s" % [late, landed]


## SETTLE_SECONDS after a respawn: Player 1's Unit must still stand within Kit.SPAWN_TOLERANCE of the pose it
## landed on and on the floor, the height of its Base's spawn point. Adds to problems and returns the numbers.
func _settle(pose: Transform3D, tag: String, problems: PackedStringArray) -> String:
	var victim: Unit = _log.units[Harness.PLAYER_1]
	var floor_y: float = _log.bases[Harness.PLAYER_1].spawn_point.global_position.y
	await _kit.advance(_harness.ticks_in(SETTLE_SECONDS))
	var height: float = victim.global_position.y - floor_y
	var error: float = victim.global_position.distance_to(pose.origin)
	_kit.need(problems, absf(height) <= Kit.SPAWN_TOLERANCE and error <= Kit.SPAWN_TOLERANCE,
		"%s: %.1f s after the respawn the Unit is %.3f m off the floor and %.3f m from where it landed" % [
			tag, SETTLE_SECONDS, height, error])
	return "%.1f s later height=%.4f m error=%.4f m (max %.2f)" % [SETTLE_SECONDS, height, error, Kit.SPAWN_TOLERANCE]


## The Unit's length: the longest horizontal side of the box of its first CollisionShape3D child, metres
## (the shape is_spot_taken() moves to the spawn point), or 0 when it has no box collider.
func _unit_length(unit: Unit) -> float:
	for child: Node in unit.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			return maxf(size.x, size.z)
	return 0.0


## The RespawnCountdown that carries a Player's player_index, found in the whole tree the way the countdown
## scenario finds the labels, or null when none does.
func _countdown_of(player: int) -> RespawnCountdown:
	for node: Node in _harness.get_tree().root.find_children("*", "", true, false):
		if node is RespawnCountdown and (node as RespawnCountdown).player_index == player:
			return node as RespawnCountdown
	return null


## Puts Player 2's Unit back on its own Base's spawn point, camera snapped.
func _send_blocker_home() -> void:
	_harness.place(_log.units[Harness.PLAYER_2], _log.bases[Harness.PLAYER_2].spawn_point.global_transform,
		_log.cameras[Harness.PLAYER_2])
