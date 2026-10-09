extends RefCounted
## Scenario turrets_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 013 on Map 01 with the shipped data and view from above, every key a real
## key event. Seven moments, each read where its premise holds: turrets_from_above (both Units just
## inside their Gates facing out: both Bases' Turrets ahead of them, orange at Base A and teal at Base
## B, their barrels at rest straight out of the Gates), crossing_lead
## (Player 2's Motorbike crosses in front of Base A at speed and a Turret's Shot is in flight toward
## the point ahead of it), own_unit_beside (Player 1's Motorbike stands beside its own Turret, which
## has turned and fired at Player 2's Motorbike on its other side: Player 1's Unit is unhurt and the
## barrel is not on it), rubble_driven_over (both of Base A's Turrets have fallen and Player 2's
## Motorbike drives over the rubble), line_in_one_view (Player 2's Motorbike touches Base A's locked
## Flag through the breach: the line shows in its view and in no other), off_screen_tracer (a
## Turret 20 m behind a Motorbike driving away fires: the Turret is beyond the view and the tracer
## comes in from behind) and flag_taken (both Turrets down, Player 2's Motorbike carries Base A's
## Flag out between the two heaps of rubble). A SPLIT line per moment with frame=, the number of the
## PNG that shows it in a --write-movie recording, and what the moment's premise reads. No CHECK in a
## normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK
## named premise, so an empty or false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-013-turrets.md, Test Evidence (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/turrets.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=turrets_showcase

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap, the camera, the Flag Walls and the Turrets the build ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
## Tokens enough that the destructions of the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 400.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 30
## Ticks a moment may take to arrive.
const LIMIT_TICKS: int = 600
## Where each Player's Unit stands for the first moment, Base-local: just inside the Gate wall.
const INSIDE_GATE: Vector3 = Vector3(0.0, 0.0, -11.5)
## The crossing: Base-local z of the line Player 2's Motorbike drives along (16 m outside the
## Turrets' line: nearer, a Turret cannot follow it and holds fire) and where it starts on that line,
## Base-local x, metres: beyond a Turret's reach, so it comes into reach at speed (a Turret fires as
## soon as it can, at a Motorbike still standing); the ticks after a Shot is fired at which the Shot is
## read (it is then in flight toward the lead point).
const CROSS_Z: float = -35.0
const CROSS_FROM: float = 45.0
const SHOT_READ_TICKS: int = 5
## The speed, m/s, a crossing or fleeing Motorbike must have when it is read.
const FAST: float = 15.0
## Where Player 2's Motorbike stands for the own-Unit moment (Base-local), and how far beside its
## Turret Player 1's stands, metres; the angle, degrees, the barrel must be from Player 1's Unit.
const TARGET_AT: Vector3 = Vector3(1.0, 0.0, -30.0)
const BESIDE: float = 3.5
const AWAY_DEGREES: float = 45.0
## The rubble drive: how far before the rubble's axis it starts (metres) and is read.
const DRIVE_OUT: float = 14.0
const OVER_AT: float = 1.0
## The fleeing Motorbike starts this far ahead of its Turret, metres, and is read when the Shot is
## between these distances behind it; the view shows this much behind the Unit (above_camera).
const FLEE_START: float = 18.0
const BEHIND_NEAR: float = 4.0
const BEHIND_FAR: float = 9.0
const VIEW_BEHIND: float = 13.5
## The Motorbike backs out to this Base-local z for the last moment.
const OUT_Z: float = -21.0

var _k: Kit13
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	await _k.w.s.both_play()
	await _k.w.s.q.kit.advance(HOLD_TICKS)
	await _turrets_from_above()
	await _crossing_lead()
	await _own_unit_beside()
	await _rubble_driven_over()
	await _line_in_one_view()
	await _off_screen_tracer()
	await _flag_taken()
	if not _problems.is_empty():
		_k.w.s.q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d shots=%d falls=%d %s" % [_moments.size(), _k.firing.size(), _k.w.falls.size(), _k.w.s.q.engine_counts()])


## Both Units just inside their own Gates facing out, so each view shows its Base's two Turrets ahead,
## their barrels at rest: read when all four stand idle. A coroutine.
func _turrets_from_above() -> void:
	var q: Quick = _k.w.s.q
	for player: int in Kit.PLAYERS:
		_k.w.s.flags.teleport(player, _k.w.point(player, INSIDE_GATE), _k.w.way(player, Vector3.FORWARD))
	await q.kit.advance(HOLD_TICKS)
	var idle: int = _k.all().filter(func(turret: Turret) -> bool: return turret.is_standing and turret.state == Turret.State.IDLE and turret.head.rotation == Vector3.ZERO).size()
	_need(idle == 4 and q.units.units[0].is_alive and q.units.units[1].is_alive, "turrets_from_above: %d Turrets standing, idle, barrel at rest" % idle)
	_line("turrets_from_above", "turrets_at_rest=%d p1_z=%.1f p2_z=%.1f" % [idle, _k.w.bases[0].to_local(q.units.units[0].global_position).z, _k.w.bases[1].to_local(q.units.units[1].global_position).z])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_k.w.s.q.harness.scenario, _k.w.s.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_k.w.s.q.kit.need(_problems, holds, problem)


## Takes both Units out of play, brings every Turret and Flag Wall back whole and puts both Units
## back in play on their Garages' spare spots, so a moment starts from the Round's own state and the
## view of the Player it is not about shows a Unit and its hit points. A coroutine.
func _reset() -> void:
	await _k.clear(0)
	await _k.clear(1)
	await _k.restore_all()
	for player: int in Kit.PLAYERS:
		var spot: Marker3D = _k.w.bases[player].spare_spawn_points[0]
		_k.w.s.q.units.retype(player, Quick.MOTORBIKE, spot.global_position, -spot.global_transform.basis.z)
	await _k.w.s.q.kit.advance(Kit13.SETTLE)


## Player 2's Motorbike crosses in front of Base A along a line 12 m outside its Turrets at full
## throttle: read SHOT_READ_TICKS after the first Shot of a Turret left, the Shot in flight and the
## barrel on the aim point ahead of the Motorbike. A coroutine.
func _crossing_lead() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	var side: Vector3 = _k.w.way(0, Vector3.RIGHT)
	await _k.stage(1, Quick.MOTORBIKE, _k.w.point(0, Vector3(CROSS_FROM, 0.0, CROSS_Z)), -side)
	var unit: Unit = q.units.units[1]
	var mark: int = _k.firing.size()
	q.harness.drive(1, 1, 0)
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await q.kit.tick()
		for index: int in range(mark, _k.firing.size()):
			var record: Dictionary = _k.firing[index]
			var live: bool = is_instance_valid(record["shot"]) and (record["shot"] as Shot).is_inside_tree()
			var speed: float = unit.get_real_velocity().length()
			if read or not live or Engine.get_physics_frames() - int(record["frame"]) != SHOT_READ_TICKS or speed < FAST:
				continue
			_need(float(record["error"]) <= (record["turret"] as Turret).stats.aim_tolerance and unit.is_alive, "crossing_lead: barrel %.2f m off, Motorbike alive %s" % [float(record["error"]), unit.is_alive])
			_line("crossing_lead", "turret=%s speed=%.1f error=%.2f shot_live=%s hp=%.0f" % [(record["turret"] as Turret).name, speed, float(record["error"]), live, unit.hit_points])
			read = true
		if read:
			break
	_need(read, "crossing_lead: no Turret Shot was in flight at a Motorbike crossing at speed")
	await q.kit.advance(HOLD_TICKS)
	q.harness.drive(1, 0, 0)


## Player 1's Motorbike stands beside its own right-hand Turret in front of Base A while Player 2's
## stands on the Gate's axis 11 m out: the Turret turns to Player 2's and fires; read once it has,
## with Player 1's Unit unhurt and the barrel well away from it. A coroutine.
func _own_unit_beside() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	var turret: Turret = _k.turret(0, Kit13.RIGHT)
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var beside: Vector3 = _k.w.point(0, Kit13.PLACES[Kit13.RIGHT] + Vector3(BESIDE, 0.0, 0.0))
	await _k.stage(1, Quick.MOTORBIKE, _k.w.point(0, TARGET_AT), -out)
	q.units.retype(0, Quick.MOTORBIKE, beside, out)
	await q.kit.advance(Kit13.SETTLE)
	var own: Unit = q.units.units[0]
	var mark: int = _k.firing.size()
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await q.kit.tick()
		if _k.fired_since(turret, mark) > 0 and turret.aim_error <= turret.stats.aim_tolerance:
			var facing: Vector3 = -turret.head.global_transform.basis.z
			var toward: Vector3 = (own.global_position - turret.global_position)
			var angle: float = rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(toward.x, toward.z)))
			_need(absf(angle) >= AWAY_DEGREES and own.hit_points == own.stats.max_hit_points and own.is_alive, "own_unit_beside: the barrel is %.0f degrees from Player 1's Motorbike, which has %.0f hit points" % [absf(angle), own.hit_points])
			_line("own_unit_beside", "barrel_from_own=%.0f aim_error=%.2f own_hp=%.0f" % [absf(angle), turret.aim_error, own.hit_points])
			read = true
			break
	_need(read, "own_unit_beside: the Turret never fired at Player 2's Motorbike")
	await q.kit.advance(HOLD_TICKS)


## Both of Base A's Turrets have fallen; Player 2's Motorbike drives along their line over the right
## one's rubble: read with its front over the heap. A coroutine.
func _rubble_driven_over() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	var turret: Turret = _k.turret(0, Kit13.RIGHT)
	_k.turret(0, Kit13.LEFT).destroy()
	turret.destroy()
	var side: Vector3 = _k.w.way(0, Vector3.RIGHT)
	await _k.stage(1, Quick.MOTORBIKE, turret.global_position - side * DRIVE_OUT, side)
	var unit: Unit = q.units.units[1]
	q.harness.drive(1, 1, 0)
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await q.kit.tick()
		var along: float = (unit.global_position - turret.global_position).dot(side)
		if along >= -OVER_AT:
			var speed: float = unit.get_real_velocity().length()
			var rubble: Node3D = turret.get_node("Rubble") as Node3D
			_need(rubble.visible and not turret.is_standing and speed >= FAST and not q.map.wall_contact(unit), "rubble_driven_over: rubble shown %s, Motorbike at %.1f m/s, %.2f m from the axis" % [rubble.visible, speed, absf(along)])
			_line("rubble_driven_over", "rubble=%s speed=%.1f along=%.2f" % [rubble.visible, speed, along])
			read = true
			break
	_need(read, "rubble_driven_over: the Motorbike never reached the rubble")
	await q.kit.advance(HOLD_TICKS)
	q.harness.drive(1, 0, 0)


## Player 2's Motorbike touches Base A's Flag through the breach with both Turrets standing: its
## view shows the line, Player 1's does not. A coroutine.
func _line_in_one_view() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	_k.w.wall(0, Walls.GATE).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var seat: Vector3 = _k.w.point(0, Walls.SEAT + Walls.OUT[Walls.GATE] * 1.0)
	await _k.stage(1, Quick.MOTORBIKE, seat, _k.w.way(0, -Walls.OUT[Walls.GATE]))
	await q.kit.advance(HOLD_TICKS)
	var raider_line: bool = _k.notice(1).visible
	var owner_line: bool = _k.notice(0).visible
	var touching: bool = _k.w.s.flags.touching(0, 1)
	_need(raider_line and not owner_line and touching and not _k.w.carrying(1) and q.units.units[1].is_alive, "line_in_one_view: line in Player 2's view %s, in Player 1's %s, touching %s, carrying %s" % [raider_line, owner_line, touching, _k.w.carrying(1)])
	_line("line_in_one_view", "p2_line=%s p1_line=%s touching=%s text=%s" % [raider_line, owner_line, touching, _k.notice(1).text])


## A Motorbike drives away from Base A's right-hand Turret along its rest heading: read when the
## Turret's Shot is a few metres behind it, the Turret itself beyond the view's reach behind. A
## coroutine.
func _off_screen_tracer() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	var turret: Turret = _k.turret(0, Kit13.RIGHT)
	_k.turret(0, Kit13.LEFT).destroy()
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(turret, 0, FLEE_START), out)
	var unit: Unit = q.units.units[1]
	q.harness.drive(1, 1, 0)
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await q.kit.tick()
		for index: int in range(mark, _k.firing.size()):
			var shot_value: Variant = _k.firing[index]["shot"]
			if read or not is_instance_valid(shot_value) or not (shot_value as Shot).is_inside_tree():
				continue
			var behind: float = (unit.global_position - (shot_value as Shot).global_position).dot(out)
			var far: float = (unit.global_position - turret.global_position).dot(out)
			var speed: float = unit.get_real_velocity().length()
			if behind > BEHIND_FAR or behind < BEHIND_NEAR or speed < FAST:
				continue
			_need(far > VIEW_BEHIND and unit.is_alive, "off_screen_tracer: the Turret is %.1f m behind (the view shows %.1f)" % [far, VIEW_BEHIND])
			_line("off_screen_tracer", "turret_behind=%.1f shot_behind=%.1f speed=%.1f" % [far, behind, speed])
			read = true
		if read:
			break
	_need(read, "off_screen_tracer: no Shot was between %.0f and %.0f m behind the Motorbike at speed" % [BEHIND_NEAR, BEHIND_FAR])
	await q.kit.advance(HOLD_TICKS)
	q.harness.drive(1, 0, 0)


## Both of Base A's Turrets are down and Player 2's Motorbike has taken the Flag through the breach:
## read with it backed out between the two heaps of rubble. A coroutine.
func _flag_taken() -> void:
	var q: Quick = _k.w.s.q
	await _reset()
	_k.w.wall(0, Walls.GATE).destroy()
	for side: int in Kit13.NAMES.size():
		_k.turret(0, side).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var taken: bool = await _k.w.take_flag(1, 0, Walls.GATE)
	var flags: Object = _k.w.s.flags
	var unit: Unit = q.units.units[1]
	await flags.drive_until(1, -1, Swap.CRUISE, func() -> bool: return _k.w.bases[0].to_local(unit.global_position).z <= OUT_Z)
	await q.kit.advance(HOLD_TICKS)
	var down: bool = not _k.turret(0, Kit13.LEFT).is_standing and not _k.turret(0, Kit13.RIGHT).is_standing
	_need(taken and down and _k.w.carrying(1) and unit.is_alive, "flag_taken: taken %s, both Turrets down %s, carrying %s" % [taken, down, _k.w.carrying(1)])
	_line("flag_taken", "carrying=%s status=%s local_z=%.1f" % [_k.w.carrying(1), _k.w.status_text(1), _k.w.bases[0].to_local(unit.global_position).z])
