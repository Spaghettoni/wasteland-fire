extends RefCounted
## Scenario fuel_cans of the split screen evidence harness (split_screen_harness.gd): Story 006's
## Fuel Cans and Fuel gauge on the shipped data, every key a real event (W, Up, Space, Period,
## Enter, R). Two CHECK lines, each detail carrying the measured numbers: can_cycle (AC-6: the five
## Cans stand at their greybox spots; a Motorbike driven onto one gains min(refill_amount, its
## room), the Can vanishes and says taken once, and the Motorbike standing in its zone takes
## nothing more; the Can is back at its spot respawn_delay_seconds after the take with restocked
## once; a Unit kept full drives onto a Can and rests in its zone, and the Can stays; destroyed
## there by Self-destruct, it comes back on its Base and the zone's one stale entry of it takes
## nothing; a Gyrocopter takes one; a Round restart after a real delivery and the R key brings a
## taken Can back) and fuel_hud (AC-7: each Player's gauge reads the Unit's Fuel and capacity at
## spawn, falls while the Unit drives and rises by the refill, reads zero while the Player chooses,
## shows the scene's format with ceili values on every tick, fits "Fuel 100 / 100" on one line and
## sits inside the 640 x 720 view between x 332 and 624, clear of the hit points and the status
## line). The harness teleports no Unit into a Can's zone or out of one: a zone lists a teleported
## Unit at its old place a tick more (the Story 006 evidence doc keeps the run), which only the
## Round's own respawn shows here. OWN_CHOICE. Tooling only. Implements: production/epics/
## wasteland-fire/story-006-fuel-and-fuel-cans.md AC-6, AC-7; design/rules.md "Resources".
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=fuel_cans

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the Units, cameras and HUDs, the typed spawn, the poses.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 004 helpers (flag_kit.gd): the Flags, the delivery's moves, the Round's signals.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")
## The Story 006 helpers (fuel_kit.gd): the Cans, the fuel_changed record, the drive onto a point.
const Fuel: GDScript = preload("res://tools/evidence/split_screen/fuel_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## The restart key (round_restart). Tools are the only place key codes appear.
const KEYS_RESTART: Array[Key] = [KEY_R]
## The Cans' spots in node-name order, FuelCan1 to FuelCan5 (greybox_fuel_cans.tscn, Story 006).
const CAN_SPOTS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-16.0, 0.0, -8.0),
	Vector3(16.0, 0.0, 8.0), Vector3(-16.0, 0.0, 8.0), Vector3(16.0, 0.0, -8.0)]
## The Can each step uses, by index into CAN_SPOTS: take (FuelCan4: the Motorbike's take and the
## restock after the delay), pass (FuelCan5: the full tank and the respawn out of its zone) and
## gyro (FuelCan3: the Gyrocopter's take and the Round restart).
const CAN_OF: Dictionary[StringName, int] = {&"take": 3, &"pass": 4, &"gyro": 2}
## Where a step puts a Unit down, 6 m or more from every Can's centre: take (8 m short of FuelCan4),
## pass (6 m short of FuelCan5), gyro (8 m short of FuelCan3) and run (the run home with the Flag,
## 6 m from FuelCan1, toward Base 1).
const SPOTS: Dictionary[StringName, Vector3] = {&"take": Vector3(-16.0, 0.0, 16.0),
	&"pass": Vector3(16.0, 0.0, -14.0), &"gyro": Vector3(16.0, 0.0, 0.0), &"run": Vector3(0.0, 0.0, 6.0)}
## Moves, m/s and metres: cruise (the drives onto and through a Can), radius (how near a Can's
## centre the drive onto it gets) and beyond (how far past a Can's centre a drive goes on).
const MOVE: Dictionary[StringName, float] = {&"cruise": 4.0, &"radius": 0.5, &"beyond": 5.0}
## Tick counts: stand (the Motorbike stands in the taken Can's zone), pass (the full-tank drive and
## its rest in the zone), confirm (into the countdown before the choice), watch (the Can after the
## respawn), slack (past a restock's due tick), layout (before a gauge is read), report (SPLIT).
const TICKS: Dictionary[StringName, int] = {&"stand": 60, &"pass": 240, &"confirm": 30, &"watch": 10,
	&"slack": 5, &"layout": 2, &"report": 60}
## Fuel refuel() adds to the Gyrocopter after its spawn, so that its room is under refill_amount.
const GYRO_TOP_UP: float = 30.0
## The left and right edge the Fuel gauge keeps to in its view, pixels (Story 006: right of the
## hit-point bar, on its row).
const GAUGE_X: Vector2 = Vector2(332.0, 624.0)
## Two Fuel values that ought to be equal differ by less than this.
const FUEL_EPSILON: float = 1e-9

var _harness: Harness
var _kit: Kit
var _units: Units
var _flags: Flags
var _fuel: Fuel
var _fuel_cans: Array[FuelCan] = []
var _bars: Array[ProgressBar] = []
var _labels: Array[Label] = []
var _cycle: PackedStringArray = []
var _hud: PackedStringArray = []
var _cycle_notes: PackedStringArray = []
var _hud_notes: PackedStringArray = []
var _takes: Array[Vector3i] = []
var _stamps: Array[Vector2i] = []
var _gains: Array[float] = []
var _rooms: Array[float] = []
var _restocks: Array[Vector2i] = []
var _trace: Array[float] = []
var _tracing: bool = false
var _misreads: Array[int] = [0, 0]
var _reads: int = 0


## Runs both checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_flags = Flags.new(harness, _kit)
	_fuel = Fuel.new(harness, _kit)
	_harness.report_ticks = TICKS[&"report"]
	await _harness.confirm_choices()
	await _kit.advance(Kit.START_TICKS)
	if not _find_parts():
		_kit.verdict("can_cycle", PackedStringArray(["premise: not five Fuel Cans, or a gauge is missing"]), "cans=%d" % _fuel_cans.size())
		return _harness.finish("premise=failed")
	_kit.on_tick = _sample
	_start()
	await _take()
	await _full_pass()
	await _stale_respawn()
	await _restock()
	await _gyro_take()
	await _restart()
	_kit.verdict("can_cycle", _cycle, " | ".join(_cycle_notes))
	_kit.need(_hud, _reads > 0 and _misreads[0] + _misreads[1] == 0, "a gauge did not show its Unit's Fuel")
	_hud_notes.append("every tick: reads=%d misreads p1=%d p2=%d" % [_reads, _misreads[0], _misreads[1]])
	_kit.verdict("fuel_hud", _hud, " | ".join(_hud_notes))
	_harness.finish("takes=%d restocks=%d round_started=%d p1=%s p1_fuel=%.2f p2=%s p2_fuel=%.2f" % [_takes.size(),
		_restocks.size(), _flags.round_started, _units.units[0].type_id, _fuel.fuel(0), _units.units[1].type_id, _fuel.fuel(1)])


## Finds the five Cans (by group, in name order) and each HUD's FuelBar and FuelLabel, and files
## every Can's taken and restocked. False when one is missing.
func _find_parts() -> bool:
	_fuel_cans = _fuel.cans()
	for player: int in Kit.PLAYERS:
		var hud: PlayerHud = _units.huds[player]
		_bars.append(hud.find_child("FuelBar", true, false) as ProgressBar if hud != null else null)
		_labels.append(hud.find_child("FuelLabel", true, false) as Label if hud != null else null)
	for index: int in _fuel_cans.size():
		_fuel_cans[index].taken.connect(_on_taken.bind(index))
		_fuel_cans[index].restocked.connect(func() -> void: _restocks.append(Vector2i(index, _harness.ticks)))
	return _fuel_cans.size() == CAN_SPOTS.size() and not _bars.has(null) and not _labels.has(null)


## Files a take as it happens: the Can, the Player and the tick, the physics frame and the Can's
## restock_frame, and the taker's gain and room from its last two fuel_changed (the refill last).
func _on_taken(unit: Unit, can_index: int) -> void:
	var player: int = _units.units.find(unit)
	var said: Array[float] = [-1.0]
	for index: int in _fuel.changes.size():
		said.append(_fuel.fuels[index] if _fuel.changes[index].x == player else said[-1])
	_takes.append(Vector3i(can_index, player, _harness.ticks))
	_stamps.append(Vector2i(Engine.get_physics_frames(), _fuel_cans[can_index].restock_frame))
	_gains.append(said[-1] - said[-2])
	_rooms.append(unit.stats.fuel_capacity - said[-2])


## AC-6, AC-7 at the Round's first spawn: the five Cans at their spots, available and shown; each
## gauge shows its Unit's starting tank and capacity, inside its view beside the hit points.
func _start() -> void:
	_harness.phase = &"start"
	var seen: PackedStringArray = []
	for index: int in _fuel_cans.size():
		var can: FuelCan = _fuel_cans[index]
		_kit.need(_cycle, _at_spot(index), "%s is not available at its spot" % can.name)
		seen.append("%s=(%.0f,%.0f) %s" % [can.name, can.global_position.x, can.global_position.z, FuelCan.State.keys()[can.state]])
	_cycle_notes.append("start: " + " ".join(seen))
	_hud_notes.append("spawn: " + _read_gauges(false))
	_hud_notes.append("layout: " + _layout())


## AC-6, AC-7: Player 1's Motorbike, put down 8 m short of FuelCan4 facing it, is driven onto it
## with W while its gauge is traced: the Can is taken on touch for min(refill_amount, room) and
## hidden; the Motorbike stands in the zone with room and takes nothing more, then leaves it.
func _take() -> void:
	_harness.phase = &"take"
	var index: int = CAN_OF[&"take"]
	var can: FuelCan = _fuel_cans[index]
	var unit: Unit = _units.units[Harness.PLAYER_1]
	_harness.place(unit, _units.pose(SPOTS[&"take"], Vector3.FORWARD), _units.cameras[0])
	await _kit.advance(Harness.SETTLE_TICKS)
	_tracing = true
	var drove: int = await _fuel.drive_to(Harness.PLAYER_1, can.global_position, MOVE[&"cruise"], MOVE[&"radius"])
	await _flags.rest(Harness.PLAYER_1)
	var hidden: bool = not (can.is_available or can.can_body.visible)
	var listed: int = await _count_listed(can, unit, TICKS[&"stand"])
	await _flags.drive_until(Harness.PLAYER_1, 1, MOVE[&"cruise"], func() -> bool:
		return can.global_position.z - unit.global_position.z > MOVE[&"beyond"])
	await _flags.rest(Harness.PLAYER_1)
	_tracing = false
	var take: int = _first_take(index)
	var steps: Vector3 = _trace_steps()
	var gain: float = _gains[take] if take >= 0 else -1.0
	var takes: int = _takes.filter(func(record: Vector3i) -> bool: return record.x == index).size()
	var slack: float = unit.stats.fuel_use / _harness.ticks_in(1.0) + _bars[0].step
	_kit.need(_cycle, drove > 0 and hidden and _take_ok(take, Harness.PLAYER_1), "the Motorbike's take")
	_kit.need(_cycle, listed == TICKS[&"stand"] and takes == 1, "a second take, or the Motorbike left the zone")
	_kit.need(_hud, steps.x > 0 and steps.y == 1 and absf(steps.z - gain) <= slack, "the gauge on the way")
	_cycle_notes.append("take: %s by p1 %s after %d ticks: %s, hidden=%s; stood %d ticks, listed %d, takes=%d" % [
		can.name, unit.type_id, drove, _take_note(take), hidden, TICKS[&"stand"], listed, takes])
	_hud_notes.append("p1 driving, %d ticks traced: falls=%d rises=%d, the rise +%.2f (gain %.4f, bar step %.2f)" % [
		_trace.size(), steps.x, steps.y, steps.z, gain, _bars[0].step])


## AC-6: Player 2's Motorbike, put down 6 m short of FuelCan5 facing it, drives onto it with Up
## and rests in its zone while refuel() fills its tank at the start of every tick, before the
## Can's tick and its own burn: a full tank leaves the Can available. AC-7: its line,
## "Fuel 100 / 100", then fits.
func _full_pass() -> void:
	_harness.phase = &"full_pass"
	var index: int = CAN_OF[&"pass"]
	var can: FuelCan = _fuel_cans[index]
	var unit: Unit = _units.units[Harness.PLAYER_2]
	_harness.place(unit, _units.pose(SPOTS[&"pass"], Vector3.BACK), _units.cameras[1])
	await _kit.advance(Harness.SETTLE_TICKS)
	var listed: int = 0
	for _tick: int in TICKS[&"pass"]:
		unit.refuel(unit.stats.fuel_capacity)
		var short: bool = can.global_position.z - unit.global_position.z > MOVE[&"radius"]
		_harness.drive(Harness.PLAYER_2, 1 if short and absf(unit.current_speed) < MOVE[&"cruise"] else 0, 0)
		await _kit.tick()
		listed += 1 if can.pickup_zone.overlaps_body(unit) else 0
	var off: float = _fuel.ground_distance(unit.global_position, can.global_position)
	var inside: bool = can.pickup_zone.overlaps_body(unit)
	var takes: int = _takes.filter(func(record: Vector3i) -> bool: return record.x == index).size()
	_kit.need(_cycle, listed > 1 and inside and can.is_available and takes == 0, "a full tank took %s" % can.name)
	var label: Label = _labels[Harness.PLAYER_2]
	var fits: bool = _text_width(label) <= label.size.x and label.get_line_count() == 1
	_kit.need(_hud, fits and label.text == _line(Harness.PLAYER_2, unit.stats.fuel_capacity), "the full line does not fit")
	_cycle_notes.append("full pass: p2 %s kept full onto %s: listed %d ticks, in the zone=%s %.2f m from its centre at %.2f m/s, available=%s, takes=%d (Fuel %.2f)" % [
		unit.type_id, can.name, listed, inside, off, unit.current_speed, can.is_available, takes, unit.fuel])
	_hud_notes.append("p2 full: line=\"%s\" %.0f of %.0f px, lines=%d" % [label.text, _text_width(label), label.size.x, label.get_line_count()])


## AC-6: Enter destroys Player 2's full Motorbike at rest in FuelCan5's zone, and its choice in the
## countdown brings it back on its Base, alive with room in its tank. The zone lists it once more,
## at its old place, on the first tick after the respawn (the stale entry the Can's two-tick touch
## rule ignores): the Can stays available and untaken on each of the watch ticks.
func _stale_respawn() -> void:
	_harness.phase = &"stale_entry"
	var index: int = CAN_OF[&"pass"]
	var can: FuelCan = _fuel_cans[index]
	var unit: Unit = _units.units[Harness.PLAYER_2]
	await _kit.press_settled(Kit.KEYS_DESTRUCT_2)
	var gone: bool = not unit.is_alive
	await _kit.advance(TICKS[&"confirm"])
	await _kit.press_settled(Kit.KEYS_FIRE_2)
	var delay: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	var waited: int = await _units.wait_alive(Harness.PLAYER_2, delay + Kit.RESPAWN_SLACK_TICKS)
	var seen: Vector2i = Vector2i.ZERO
	for _tick: int in TICKS[&"watch"]:
		seen.x += 1 if can.pickup_zone.overlaps_body(unit) else 0
		await _kit.tick()
		seen.y += 1 if can.is_available else 0
	var takes: int = _takes.filter(func(record: Vector3i) -> bool: return record.x == index).size()
	var away: float = _fuel.ground_distance(unit.global_position, can.global_position)
	_kit.need(_cycle, gone and waited >= 0 and seen.x > 0 and seen.y == TICKS[&"watch"] and takes == 0, "the respawn out of %s's zone" % can.name)
	_cycle_notes.append("respawn out of the zone: Enter destroyed p2 in %s's zone (gone=%s); back as %s %.2f m away with Fuel %.1f: listed on %d, available on %d of the %d ticks after, takes=%d" % [
		can.name, gone, unit.type_id, away, unit.fuel, seen.x, seen.y, TICKS[&"watch"], takes])


## AC-6: with nobody near, FuelCan4 comes back at its spot, shown and available, with restocked
## once, respawn_delay_seconds after its take: the restock_frame it stamped at the take and the tick
## it came back on both say so, within a tick.
func _restock() -> void:
	_harness.phase = &"restock"
	var index: int = CAN_OF[&"take"]
	var can: FuelCan = _fuel_cans[index]
	var take: int = _first_take(index)
	var delay: int = _harness.ticks_in(can.settings.respawn_delay_seconds)
	var taken_at: int = _takes[take].z if take >= 0 else _harness.ticks
	await _kit.advance(maxi(taken_at + delay + TICKS[&"slack"] - _harness.ticks, 0))
	var back: Array[Vector2i] = _restocks.filter(func(record: Vector2i) -> bool: return record.x == index)
	var gap: int = back[0].y - taken_at if back.size() == 1 else -1
	var stamped: int = _stamps[take].y - _stamps[take].x if take >= 0 else -1
	_kit.need(_cycle, absi(gap - delay) <= Kit.TICK_SLACK and absi(stamped - delay) <= Kit.TICK_SLACK, "%s's delay" % can.name)
	_kit.need(_cycle, back.size() == 1 and _at_spot(index), "%s's restock" % can.name)
	_cycle_notes.append("restock: %s back %d ticks after its take (restock_frame - take frame = %d; %.1f s = %d+-%d), restocked=%d, at (%.0f,%.0f) shown=%s available=%s restock_frame=%d" % [
		can.name, gap, stamped, can.settings.respawn_delay_seconds, delay, Kit.TICK_SLACK, back.size(), can.global_position.x,
		can.global_position.z, can.can_body.visible, can.is_available, can.restock_frame])


## AC-6: Player 2 retyped a Gyrocopter 8 m short of FuelCan3 (its Unit is in play, so the Round
## counts it), topped up so that its room is under refill_amount, flown onto the Can with Up: it
## takes the Can, filled by its room, and the Can is hidden.
func _gyro_take() -> void:
	_harness.phase = &"gyro_take"
	var index: int = CAN_OF[&"gyro"]
	var can: FuelCan = _fuel_cans[index]
	var unit: Unit = _units.units[Harness.PLAYER_2]
	_units.retype(Harness.PLAYER_2, GYROCOPTER, SPOTS[&"gyro"], Vector3.BACK)
	await _kit.advance(Harness.SETTLE_TICKS)
	var added: float = unit.refuel(GYRO_TOP_UP)
	var flew: int = await _fuel.drive_to(Harness.PLAYER_2, can.global_position, MOVE[&"cruise"], MOVE[&"radius"])
	await _flags.rest(Harness.PLAYER_2)
	var take: int = _first_take(index)
	var taken: bool = flew > 0 and unit.stats.can_fly and _take_ok(take, Harness.PLAYER_2)
	var hidden: bool = not (can.is_available or can.can_body.visible)
	_kit.need(_cycle, taken and hidden and _rooms[take] < can.settings.refill_amount, "the Gyrocopter's take")
	_cycle_notes.append("gyro: p2 %s (+%.1f by refuel()) took %s after %d ticks: %s, hidden=%s" % [
		unit.type_id, added, can.name, flew, _take_note(take), hidden])


## AC-6, AC-7: Player 1 steals Player 2's Flag and runs it home (flag_kit.gd's moves, the choice
## scenario's delivery) and R restarts the Round: the Cans are checked, both gauges read zero while
## the Players choose, then each Unit's starting tank once both chose again.
func _restart() -> void:
	_harness.phase = &"delivery"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var flag: Flag = _flags.flags[Harness.PLAYER_2]
	_flags.approach(Harness.PLAYER_1, flag.global_position, Vector3.BACK)
	var steal: int = await _flags.drive_until(Harness.PLAYER_1, 1, Flags.APPROACH_SPEED, func() -> bool: return flag.carrier == unit)
	await _flags.rest(Harness.PLAYER_1)
	_flags.teleport(Harness.PLAYER_1, SPOTS[&"run"], Vector3.BACK)
	var home_run: int = await _flags.drive_until(Harness.PLAYER_1, 1, Flags.APPROACH_SPEED, func() -> bool:
		return not _flags.round_overs.is_empty())
	_harness.phase = &"restart"
	var ended: bool = steal > 0 and home_run > 0 and _flags.round_overs.size() == 1
	var before: Vector2i = Vector2i(_restocks.size(), _flags.round_started)
	await _kit.press_settled(KEYS_RESTART)
	_check_restocked(Vector2i(steal, home_run), ended, before)
	await _kit.advance(TICKS[&"layout"])
	_hud_notes.append("choosing: " + _read_gauges(true))
	await _harness.confirm_choices()
	await _kit.advance(TICKS[&"layout"])
	_hud_notes.append("chosen again: " + _read_gauges(false))


## The restart's effect on the Cans, after a delivery that ended the Round (ended; moves: the steal
## and the run home, ticks): one round_started and one restocked, FuelCan3's, before its own delay
## ran out; FuelCan3 shown and available at its spot with restock_frame zero.
func _check_restocked(moves: Vector2i, ended: bool, before: Vector2i) -> void:
	var index: int = CAN_OF[&"gyro"]
	var can: FuelCan = _fuel_cans[index]
	var take: int = _first_take(index)
	var news: Array[Vector2i] = _restocks.slice(before.x)
	var due: int = _takes[take].z + _harness.ticks_in(can.settings.respawn_delay_seconds) if take >= 0 else -1
	var early: bool = news.size() == 1 and news[0].x == index and news[0].y < due
	var started: int = _flags.round_started - before.y
	_kit.need(_cycle, ended and started == 1 and early and _at_spot(index), "the Round restart did not bring %s back" % can.name)
	_cycle_notes.append("restart: steal %d ticks, run home %d ticks, round_over=%d; R: round_started +%d, restocked %s at tick %d (due by delay %d), %s at (%.0f,%.0f) shown=%s available=%s restock_frame=%d" % [
		moves.x, moves.y, _flags.round_overs.size(), started, ",".join(news.map(func(record: Vector2i) -> String: return String(_fuel_cans[record.x].name))),
		news[0].y if not news.is_empty() else -1, due, can.name, can.global_position.x, can.global_position.z, can.can_body.visible, can.is_available, can.restock_frame])


## Both gauges against their Units, and each Unit's Fuel against the starting tank of its type, or
## zero while its Player chooses: the bar, its maximum and the line.
func _read_gauges(choosing: bool) -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units.units[player]
		var expected: float = 0.0 if choosing else _fuel.start_tank(player)
		var shown: bool = _gauge_matches(player) and unit.fuel == expected and unit.is_alive != choosing
		_kit.need(_hud, shown and _labels[player].text == _line(player, expected), "p%d's gauge does not read %.1f" % [player + 1, expected])
		parts.append("p%d %s alive=%s bar=%.2f/%.0f line=\"%s\"" % [player + 1, unit.type_id, unit.is_alive, _bars[player].value,
			_bars[player].max_value, _labels[player].text])
	return " ".join(parts)


## AC-7: each gauge (bar and line) inside its view and between GAUGE_X, clear of the hit-point bar
## and line and of the status line: the rectangles, view pixels.
func _layout() -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var hud: PlayerHud = _units.huds[player]
		var view: Rect2 = Rect2(Vector2.ZERO, Vector2((hud.get_viewport() as SubViewport).size))
		var gauge: Rect2 = _bars[player].get_global_rect().merge(_labels[player].get_global_rect())
		var rect_of: Callable = func(node_name: String) -> Rect2: return (hud.find_child(node_name, true, false) as Control).get_global_rect()
		var hit_points: Rect2 = (rect_of.call("HitPointsBar") as Rect2).merge(rect_of.call("HitPointsLabel"))
		var status: Rect2 = rect_of.call("FlagStatusLabel")
		var inside: bool = view.encloses(gauge) and gauge.position.x >= GAUGE_X.x and gauge.end.x <= GAUGE_X.y
		_kit.need(_hud, inside and not gauge.intersects(hit_points) and not gauge.intersects(status), "p%d's gauge rectangle" % (player + 1))
		parts.append("p%d view=%s gauge=%s hit_points=%s status=%s" % [player + 1, _corners(view), _corners(gauge),
			_corners(hit_points), _corners(status)])
	return " ".join(parts)


## After every tick of the kit: both gauges against their Units, and Player 1's bar while traced.
func _sample() -> void:
	_reads += 1
	for player: int in Kit.PLAYERS:
		_misreads[player] += 0 if _gauge_matches(player) else 1
	if _tracing:
		_trace.append(_bars[Harness.PLAYER_1].value)


## Whether a Player's gauge shows its Unit: the bar within half a step of the Fuel (a ProgressBar
## rounds to its step), its maximum the type's capacity, and the line _line() of the Fuel.
func _gauge_matches(player: int) -> bool:
	var unit: Unit = _units.units[player]
	var bar: ProgressBar = _bars[player]
	var near: bool = absf(bar.value - unit.fuel) <= bar.step / 2.0 + FUEL_EPSILON
	return near and bar.max_value == unit.stats.fuel_capacity and _labels[player].text == _line(player, unit.fuel)


## The line a Player's gauge owes an amount of Fuel: the scene's fuel_format through tr() with the
## ceili amount and the ceili capacity of the Unit's type.
func _line(player: int, amount: float) -> String:
	var hud: PlayerHud = _units.huds[player]
	return hud.tr(hud.fuel_format) % [ceili(amount), ceili(_units.units[player].stats.fuel_capacity)]


## The width a label's line takes, pixels: its text at its font size, plus its outline both sides.
func _text_width(label: Label) -> float:
	var font_size: int = label.get_theme_font_size(&"font_size")
	var text: Vector2 = label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return text.x + 2.0 * label.get_theme_constant(&"outline_size")


## A rectangle as "left,top-right,bottom", whole pixels.
func _corners(rect: Rect2) -> String:
	return "%.0f,%.0f-%.0f,%.0f" % [rect.position.x, rect.position.y, rect.end.x, rect.end.y]


## The index into the take record of a Can's first take, or -1.
func _first_take(can_index: int) -> int:
	for index: int in _takes.size():
		if _takes[index].x == can_index:
			return index
	return -1


## Whether a take (an index into the record, -1 for none) was by the Player and for
## min(refill_amount, the taker's room): the Can's rule.
func _take_ok(take: int, player: int) -> bool:
	if take < 0 or _takes[take].y != player:
		return false
	var refill: float = _fuel_cans[_takes[take].x].settings.refill_amount
	return absf(_gains[take] - minf(refill, _rooms[take])) <= FUEL_EPSILON


## A take (an index into the record, -1 for none) as "+gain (room, refill)" for a detail.
func _take_note(take: int) -> String:
	if take < 0:
		return "no take"
	return "+%.4f (room %.4f, refill %.1f)" % [_gains[take], _rooms[take], _fuel_cans[_takes[take].x].settings.refill_amount]


## Whether a Can stands available at its spot: shown, AVAILABLE, no restock due (restock_frame 0).
func _at_spot(can_index: int) -> bool:
	var can: FuelCan = _fuel_cans[can_index]
	var shown: bool = can.can_body.is_visible_in_tree() and can.is_available and can.restock_frame == 0
	return shown and can.global_position.is_equal_approx(CAN_SPOTS[can_index])


## Waits the ticks with every key up: on how many of them the Can's zone listed the Unit.
func _count_listed(can: FuelCan, unit: Unit, ticks: int) -> int:
	var listed: int = 0
	for _tick: int in ticks:
		await _kit.tick()
		listed += 1 if can.pickup_zone.overlaps_body(unit) else 0
	return listed


## The traced bar's steps from tick to tick: Vector3(falls, rises, the largest rise).
func _trace_steps() -> Vector3:
	var steps: Vector3 = Vector3.ZERO
	for index: int in range(1, _trace.size()):
		var change: float = _trace[index] - _trace[index - 1]
		steps += Vector3(1.0 if change < 0.0 else 0.0, 1.0 if change > 0.0 else 0.0, 0.0)
		steps.z = maxf(steps.z, change)
	return steps
