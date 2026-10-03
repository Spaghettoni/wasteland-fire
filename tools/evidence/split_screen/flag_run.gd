extends RefCounted
## Scenario flag_run of the split screen evidence harness (split_screen_harness.gd): one full
## Flag run of Story 004, played with real key events (W A S D and the arrows to drive,
## the debug key 1 to destroy) and judged from the MatchController's signals and the Flags' own
## state. Player 1 steals Player 2's Flag, is destroyed with it, Player 2 recovers it and brings
## it home, Player 1 steals it again and delivers it: the win. Five CHECK lines, one per acceptance
## criterion (AC-1 to AC-5), every number measured; every touch is driven, the runner's teleport
## only shortens the lanes. Tooling only: nothing under src/ depends on this file.
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-1 to AC-5;
## design/rules.md "Resources" and "Handling the Flag".
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=flag_run

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 004 helpers (flag_kit.gd): the signal record, the moves and the zone geometry.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")

## Player 1: the thief, who steals Flag 2 and delivers it.
const THIEF: int = Harness.PLAYER_1
## Player 2: the owner of Flag 2 (a Flag's index is its owner's), who recovers it.
const OWNER: int = Harness.PLAYER_2
## Ticks a Unit is held touching a Flag it must not pick up.
const HOLD_TICKS: int = 30
## Ticks the thief rides with the Flag before it is destroyed.
const RIDE_TICKS: int = 60
## Simulated seconds the dropped Flag is watched (across the thief's respawn).
const DROPPED_SECONDS: float = 30.0
## Ticks a rule may take to act after the Carrier's box entered its Base zone (the physics server
## reports an overlap about two ticks late).
const ZONE_SLACK_TICKS: int = 4
## Placement error allowed at a seat or at the wreck, metres.
const PLACE_TOLERANCE: float = 0.05
## Drift allowed while carried or lying, metres.
const STILL_TOLERANCE: float = 0.001
## Toward Base 1 (+Z): the side every approach comes from and the thief's way.
const TO_BASE_1: Vector3 = Vector3(0.0, 0.0, 1.0)
## Toward Base 2 (-Z).
const TO_BASE_2: Vector3 = Vector3(0.0, 0.0, -1.0)
## Where Player 2 waits out of the lane.
const PARK_SPOT: Vector3 = Vector3(-12.0, 0.0, -8.0)
## Where the thief rides and is destroyed (outside both zones).
const RIDE_START: Vector3 = Vector3(12.0, 0.0, 0.0)
## Where a run into Base 1's zone starts, 8 m short of its edge.
const BASE_1_RUN_START: Vector3 = Vector3(0.0, 0.0, 6.0)
## The mirror of BASE_1_RUN_START for Base 2.
const BASE_2_RUN_START: Vector3 = Vector3(0.0, 0.0, -6.0)

var _harness: Harness
var _kit: Kit
var _flag_kit: Flags
## The runner's tick the Unit's box of the last _run_into_zone() met the zone; -1 until then.
var _entered_tick: int = -1


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_flag_kit = Flags.new(harness, _kit)
	await _kit.advance(Kit.START_TICKS)
	_check_flags_at_home()
	await _check_pickup()
	await _check_drop()
	await _check_recover()
	await _check_delivery()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("picked_up=%d dropped=%d seated=%d round_over=%d winner=%d" % [_flag_kit.pick_ups.size(), _flag_kit.drops.size(),
		_flag_kit.seats.size(), _flag_kit.round_overs.size(), _flag_kit.controller.winner_index()])


## AC-1: each Flag AT_HOME on its Base's seat, no carrier, visible, its Body painted with a
## material whose albedo is its Player's body material's.
func _check_flags_at_home() -> void:
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	for index: int in _flag_kit.flags.size():
		var flag: Flag = _flag_kit.flags[index]
		var expected: StandardMaterial3D = load(Flags.PLAYER_MATERIALS[index]) as StandardMaterial3D
		var body: StandardMaterial3D = flag.body_mesh.material_override as StandardMaterial3D
		var painted: bool = expected != null and body != null and body.albedo_color == expected.albedo_color
		var error: float = flag.global_position.distance_to(_flag_kit.bases[index].flag_seat.global_position)
		_kit.need(problems, flag.state == Flag.State.AT_HOME and flag.carrier == null and error <= PLACE_TOLERANCE
			and flag.is_visible_in_tree() and painted, "flag %d is not at home in its colour" % (index + 1))
		detail.append("flag_%d=%s seat_error=%.4f (max %.2f) visible=%s painted=%s" % [index + 1, _flag_kit.state_name(index),
			error, PLACE_TOLERANCE, flag.is_visible_in_tree(), painted])
	_kit.verdict("flags_at_home", problems, " | ".join(detail))


## AC-2: the owner reversing onto its own seated Flag and the thief under scratch stats with
## can_carry false pick nothing up; with its stats back the thief picks up on the tick the touch is
## reported, the Flag its child at carry_offset, where it stays through RIDE_TICKS of driving.
func _check_pickup() -> void:
	_harness.phase = &"pickup"
	var problems: PackedStringArray = []
	var thief: Unit = _flag_kit.units[THIEF]
	var flag: Flag = _flag_kit.flags[OWNER]
	var original: UnitStats = thief.stats
	_kit.need(problems, thief.can_carry and original.can_carry, "the thief's data does not say can_carry")
	var owner: String = await _hold_without_pick_up(OWNER, -1, OWNER, problems, "owner reversed onto its own seated flag")
	_flag_kit.teleport(OWNER, PARK_SPOT, TO_BASE_1)
	var scratch: UnitStats = original.duplicate() as UnitStats
	scratch.can_carry = false
	thief.stats = scratch
	_flag_kit.approach(THIEF, flag.global_position, TO_BASE_1)
	var gate: String = await _hold_without_pick_up(THIEF, 1, OWNER, problems, "thief under scratch stats with can_carry=false")
	_kit.need(problems, not thief.can_carry, "the scratch stats did not take")
	var backed: int = await _flag_kit.drive_until(THIEF, -1, Flags.APPROACH_SPEED, func() -> bool: return not _flag_kit.touching(OWNER, THIEF))
	await _flag_kit.rest(THIEF)
	thief.stats = original
	_kit.need(problems, thief.stats == original and thief.can_carry and backed > 0, "the stats were not restored, or the thief never left")
	var steal: String = await _pick_up_on_touch(THIEF, OWNER, problems, "stats restored, drove in")
	var offset: float = flag.position.distance_to(thief.carry_offset)
	_kit.need(problems, flag.get_parent() == thief and offset <= STILL_TOLERANCE, "the flag is not a child of the thief at its carry_offset")
	await _flag_kit.rest(THIEF)
	_flag_kit.teleport(THIEF, RIDE_START, TO_BASE_2)
	var ride_max: float = 0.0
	for _tick: int in RIDE_TICKS:
		_harness.drive(THIEF, 1 if thief.current_speed < Flags.APPROACH_SPEED else 0, 1)
		await _kit.tick()
		ride_max = maxf(ride_max, thief.to_local(flag.global_position).distance_to(thief.carry_offset))
	_harness.release_all()
	await _flag_kit.rest(THIEF)
	_kit.need(problems, ride_max <= STILL_TOLERANCE and flag.state == Flag.State.CARRIED, "the flag left its offset on the ride")
	_harness.print_progress()
	_kit.verdict("pickup", problems, ("thief=player_%d can_carry=%s | %s | %s | %s; parent=%s offset_error=%.4f m | ride of %d ticks: "
		+ "offset error max %.4f m (max %.3f) flag_2=%s") % [THIEF + 1, thief.can_carry, owner, gate, steal, flag.get_parent().name,
			offset, RIDE_TICKS, ride_max, STILL_TOLERANCE, _flag_kit.state_name(OWNER)])


## AC-3: the thief, destroyed by the debug key with the Flag on it, drops it DROPPED at the
## wreck, visible; through DROPPED_SECONDS, across the respawn, it stays DROPPED there, unpicked.
func _check_drop() -> void:
	_harness.phase = &"drop"
	var problems: PackedStringArray = []
	var thief: Unit = _flag_kit.units[THIEF]
	var flag: Flag = _flag_kit.flags[OWNER]
	var damage: float = _flag_kit.controller.rules.debug_damage
	var presses: int = ceili(thief.stats.max_hit_points / damage) if damage > 0.0 else 0
	for _press: int in presses:
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
	var spawns_before: int = _flag_kit.spawns.size()
	var wreck: Vector3 = _flag_kit.wrecks[0] if not _flag_kit.wrecks.is_empty() else Vector3.INF
	var drop_spot: Vector3 = flag.global_position
	var at_wreck: float = drop_spot.distance_to(wreck)
	var drop: Vector2i = _flag_kit.drops[0] if not _flag_kit.drops.is_empty() else Vector2i(-1, -1)
	var dropped: bool = (not thief.is_alive and _flag_kit.drops.size() == 1 and drop.x == OWNER
		and flag.state == Flag.State.DROPPED and flag.is_visible_in_tree())
	_kit.need(problems, dropped and at_wreck <= PLACE_TOLERANCE, "the flag did not drop at the wreck")
	var watch: String = await _watch_dropped(flag, drop_spot, spawns_before, drop.y, problems)
	_harness.print_progress()
	_kit.verdict("drop", problems, ("%d presses of the debug key: dropped=%s flag_dropped(%d) at tick %d, wreck=(%.2f, %.2f) "
		+ "drop=(%.2f, %.2f) apart=%.4f m (max %.2f) | %s") % [presses, dropped, drop.x, drop.y, wreck.x, wreck.z, drop_spot.x, drop_spot.z,
			at_wreck, PLACE_TOLERANCE, watch])


## Watches the dropped Flag through DROPPED_SECONDS: a problem when it was ever not DROPPED or
## over STILL_TOLERANCE from drop_spot, when no unit_spawned came after the spawns_before recorded
## (the thief's respawn), or when anything was picked up. The numbers, the respawn tick also
## relative to drop_tick.
func _watch_dropped(flag: Flag, drop_spot: Vector3, spawns_before: int, drop_tick: int, problems: PackedStringArray) -> String:
	var violations: int = 0
	var spawn_tick: int = -1
	for _tick: int in _harness.ticks_in(DROPPED_SECONDS):
		await _kit.tick()
		if flag.state != Flag.State.DROPPED or flag.global_position.distance_to(drop_spot) > STILL_TOLERANCE:
			violations += 1
		if spawn_tick < 0 and _flag_kit.spawns.size() > spawns_before:
			spawn_tick = _flag_kit.spawns[-1].y
	_kit.need(problems, violations == 0 and spawn_tick > 0 and _flag_kit.pick_ups.size() == 1, "the dropped flag moved, was picked up, or no respawn")
	return "watched %.0f s: ticks not DROPPED or moved over %.3f m=%d; the thief respawned at tick %d (%d after the drop); pick_ups=%d" % [
		DROPPED_SECONDS, STILL_TOLERANCE, violations, spawn_tick, spawn_tick - drop_tick, _flag_kit.pick_ups.size()]


## AC-4: the owner picks up its own dropped Flag on the tick the touch is reported (status
## OWN_AWAY) and runs home: flag_seated within ZONE_SLACK_TICKS of the entry, the Flag
## AT_HOME on its seat, status OWN_AT_HOME, the Round still running.
func _check_recover() -> void:
	_harness.phase = &"recover"
	var problems: PackedStringArray = []
	var flag: Flag = _flag_kit.flags[OWNER]
	var controller: MatchController = _flag_kit.controller
	_flag_kit.approach(OWNER, flag.global_position, TO_BASE_1)
	var recovery: String = await _pick_up_on_touch(OWNER, OWNER, problems, "owner drove into its dropped flag")
	var carrying: String = _flag_kit.status_name(OWNER)
	_kit.need(problems, controller.flag_status(OWNER) == MatchController.FlagStatus.OWN_AWAY,
		"the owner's status is not OWN_AWAY while carrying")
	await _flag_kit.rest(OWNER)
	_flag_kit.teleport(OWNER, BASE_2_RUN_START, TO_BASE_2)
	var run_ticks: int = await _run_into_zone(OWNER, func() -> bool: return not _flag_kit.seats.is_empty())
	var seat: Vector2i = _flag_kit.seats[0] if not _flag_kit.seats.is_empty() else Vector2i(-1, -1)
	var error: float = flag.global_position.distance_to(_flag_kit.bases[OWNER].flag_seat.global_position)
	var seated: bool = (run_ticks > 0 and _entered_tick > 0 and _flag_kit.seats.size() == 1 and seat.x == OWNER
		and seat.y - _entered_tick <= ZONE_SLACK_TICKS and flag.state == Flag.State.AT_HOME)
	_kit.need(problems, seated and error <= PLACE_TOLERANCE and not controller.is_round_over()
		and controller.flag_status(OWNER) == MatchController.FlagStatus.OWN_AT_HOME, "the flag was not re-seated on the run home")
	await _flag_kit.rest(OWNER)
	_flag_kit.teleport(OWNER, PARK_SPOT, TO_BASE_1)
	_harness.print_progress()
	_kit.verdict("recover", problems, ("%s status=%s | ran home: box met Base 2's zone at tick %d, flag_seated(%d) at tick %d (%d after "
		+ "the entry, max %d); flag_2=%s seat_error=%.4f (max %.2f) status=%s is_round_over=%s") % [recovery, carrying, _entered_tick, seat.x,
			seat.y, seat.y - _entered_tick, ZONE_SLACK_TICKS, _flag_kit.state_name(OWNER), error, PLACE_TOLERANCE, _flag_kit.status_name(OWNER),
			controller.is_round_over()])


## AC-5: the respawned thief steals Flag 2 again and runs it into its own Base zone:
## round_over(THIEF) within ZONE_SLACK_TICKS of the entry, once, the tree paused inside the handler
## and after; no round_over came before, through the whole run.
func _check_delivery() -> void:
	_harness.phase = &"delivery"
	var problems: PackedStringArray = []
	var flag: Flag = _flag_kit.flags[OWNER]
	var controller: MatchController = _flag_kit.controller
	var overs_before: int = _flag_kit.round_overs.size()
	_kit.need(problems, overs_before == 0 and not controller.is_round_over(), "the Round ended before the delivery")
	_flag_kit.approach(THIEF, flag.global_position, TO_BASE_1)
	var steal: String = await _pick_up_on_touch(THIEF, OWNER, problems, "second steal")
	await _flag_kit.rest(THIEF)
	_flag_kit.teleport(THIEF, BASE_1_RUN_START, TO_BASE_1)
	var run_ticks: int = await _run_into_zone(THIEF, func() -> bool: return not _flag_kit.round_overs.is_empty())
	var over: Vector2i = _flag_kit.round_overs[0] if not _flag_kit.round_overs.is_empty() else Vector2i(-1, -1)
	var gap: int = over.y - _entered_tick
	_kit.need(problems, _entered_tick > 0 and gap >= 0 and gap <= ZONE_SLACK_TICKS, "round_over did not come within the slack of the entry")
	_kit.need(problems, _flag_kit.round_overs.size() == 1 and over.x == THIEF and _flag_kit.paused_at_signal and controller.is_round_over()
		and controller.winner_index() == THIEF and _harness.get_tree().paused, "the delivery did not end the Round for the thief, paused")
	_harness.print_progress()
	_kit.verdict("delivery", problems, ("round_over before=%d | %s | ran %d ticks into Base 1's zone with it: box met the zone at tick %d, "
		+ "round_over(%d) at tick %d (%d after the entry, max %d) paused_in_handler=%s; now round_over=%d is_round_over=%s winner_index=%d "
		+ "paused=%s") % [overs_before, steal, run_ticks, _entered_tick, over.x, over.y, gap, ZONE_SLACK_TICKS, _flag_kit.paused_at_signal,
			_flag_kit.round_overs.size(), controller.is_round_over(), controller.winner_index(), _harness.get_tree().paused])


## Drives a Unit (gear 1 forward, -1 reverse) until the Flag reports it and holds it there for
## HOLD_TICKS: a problem unless touched the whole hold with no flag_picked_up. The numbers.
func _hold_without_pick_up(player: int, gear: int, flag_index: int, problems: PackedStringArray, label: String) -> String:
	var picks: int = _flag_kit.pick_ups.size()
	var ticks: int = await _flag_kit.drive_until(player, gear, Flags.APPROACH_SPEED, _flag_kit.touching.bind(flag_index, player))
	var held: int = 0
	for _tick: int in HOLD_TICKS:
		await _kit.tick()
		held += 1 if _flag_kit.touching(flag_index, player) else 0
	_kit.need(problems, ticks > 0 and held == HOLD_TICKS and _flag_kit.pick_ups.size() == picks, label + ": no touch, or a pick-up")
	return "%s: touched after %d ticks, touching %d/%d ticks held, pick_ups=%d (before %d) flag_%d=%s" % [label, ticks, held,
		HOLD_TICKS, _flag_kit.pick_ups.size(), picks, flag_index + 1, _flag_kit.state_name(flag_index)]


## Drives a Unit forward until the Flag reports it and waits Kit.TICK_SLACK + 1 ticks: a problem
## unless flag_picked_up(player, flag_index) came within the slack, CARRIED. The numbers.
func _pick_up_on_touch(player: int, flag_index: int, problems: PackedStringArray, label: String) -> String:
	var picks: int = _flag_kit.pick_ups.size()
	var ticks: int = await _flag_kit.drive_until(player, 1, Flags.APPROACH_SPEED, _flag_kit.touching.bind(flag_index, player))
	var touch_tick: int = _harness.ticks
	await _kit.advance(Kit.TICK_SLACK + 1)
	var pick: Vector3i = _flag_kit.pick_ups[-1] if not _flag_kit.pick_ups.is_empty() else Vector3i(-1, -1, -1)
	var flag: Flag = _flag_kit.flags[flag_index]
	_kit.need(problems, ticks > 0 and _flag_kit.pick_ups.size() == picks + 1 and pick.x == player and pick.y == flag_index
		and pick.z - touch_tick <= Kit.TICK_SLACK and flag.state == Flag.State.CARRIED
		and flag.carrier == _flag_kit.units[player], label + ": no touch, or no pick-up on the touch")
	return "%s: touched after %d ticks, touch reported at tick %d, flag_picked_up(%d, %d) at tick %d (at most %d later) flag_%d=%s" % [
		label, ticks, touch_tick, pick.x, pick.y, pick.z, Kit.TICK_SLACK, flag_index + 1, _flag_kit.state_name(flag_index)]


## Drives a Player's Unit forward at the approach speed into its own Base zone until done() holds,
## noting the first tick its box met the zone (_entered_tick, the kit's geometry); ticks, or -1.
func _run_into_zone(player: int, done: Callable) -> int:
	_entered_tick = -1
	var watch: Callable = func() -> bool:
		if _entered_tick < 0 and _flag_kit.in_zone_box(player, player):
			_entered_tick = _harness.ticks
		return done.call()
	return await _flag_kit.drive_until(player, 1, Flags.APPROACH_SPEED, watch)
