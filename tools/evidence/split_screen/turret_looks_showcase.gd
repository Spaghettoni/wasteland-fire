extends RefCounted
## Scenario turret_looks_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 015 on Map 01 with the shipped data, every key a real key event. Each
## Player stands in front of its own Base's Turrets facing them, so its view shows the two Turrets
## ahead (orange at Base A, teal at Base B) and a Turret never fires at it: looks_whole, looks_first and
## looks_second show all four Turrets whole, in their first and in their second look, and looks_rubble
## after they fell, each in the view from above and in the chase view (the Q and Slash keys step each
## view), so both Teams appear in both Views in every look. head_turning_start and head_turning_end
## are two frames a quarter turn apart of a Base B Turret in its second look turning toward Player 1's
## Truck. The moments that need a fight or a drive are turret_looks_moments.gd's: firing_above and
## firing_chase (the four whole Turrets firing at both Players' Trucks, a Shot in flight in each view,
## the gap between the barrel's tip and where the Shot leaves measured through each view's camera: R17,
## the Shot is drawn at the one shooting height), unit_past (each Player's Motorbike past its own
## Turret in the chase view, Player 1's so close behind it that the Turret hides it and Player 2's
## beyond that: the chase camera's line to the Unit, computed against the Turret's drum, says where)
## and gyro_at_face (a Gyrocopter stopped at a grown Turret's face under its head). after_r shows
## both Bases' Turrets whole again after a Round ended by Player 2 carrying Base A's Flag home and the
## restart key (round_over_looks_kept is the moment before it). A SPLIT line
## per moment with frame=, the number of the PNG that shows it in a --write-movie recording, and what
## the moment's premise reads. No CHECK in a normal run: it ends with RESULT ok; a moment whose
## premise does not hold prints one failing CHECK named premise, so an empty or false recording
## cannot pass as evidence. Implements: production/epics/wasteland-fire/story-015-turret-damage-looks.md,
## Test Evidence (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/looks.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=turret_looks_showcase

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Gate wall's index.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd) and the moments of the fight and the drives
## (turret_looks_moments.gd).
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
const Moments: GDScript = preload("res://tools/evidence/split_screen/turret_looks_moments.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap, the camera, the Flag Walls and the Turrets and their looks the build ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
## Tokens enough that the destructions of the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 600.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Where each Player's Unit stands for the looks, Base-local: on the Gate's axis 8 m in front of the
## Turrets' line, facing into its Base, so both Turrets stand ahead of it, one on each side.
const FRONT: Vector3 = Vector3(0.0, 0.0, -27.0)
## The head's turn: the bearing off its Base's rest heading a Truck is put at, how far out, and the
## yaw (radians) that counts as a quarter turn nearly done.
const BEARING_DEGREES: float = 80.0
const TURN_AT: float = 12.0
const QUARTER: float = 1.3
var _k: Kit13
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	await _k.w.s.both_play()
	await _in_front()
	await _looks_in_both_views()
	await _head_turning()
	var moments: Object = Moments.new(self, _k)
	await moments.run()
	await _after_r()
	if not _problems.is_empty():
		_k.w.s.q.kit.verdict("premise", _problems, " | ".join(_moments))
	var shots: int = _k.firing.size()
	_k.close()
	harness.finish("moments=%d shots=%d" % [_moments.size(), shots])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_k.w.s.q.harness.scenario, _k.w.s.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_k.w.s.q.kit.need(_problems, holds, problem)


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		found.append(_k.w.s.q.units.cameras[player].settings.resource_path.get_file())
	return found


## The four Turrets' looks, Base A's two first, as the nodes show them.
func _looks() -> Array[int]:
	var found: Array[int] = []
	for who: Turret in _k.all():
		found.append(Looks.look_shown(who))
	return found


## Both Units in front of their own Base's Turrets facing them, so each view shows the Turrets ahead,
## the Unit's Base never firing at it. A coroutine.
func _in_front() -> void:
	for player: int in Kit.PLAYERS:
		_in_front_of(player)
	await _k.w.s.q.kit.advance(Looks.HOLD_TICKS)


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	var keys: Array[Key] = [KEY_Q, KEY_SLASH]
	await _k.w.s.q.kit.press_settled(keys)
	await _k.w.s.q.kit.advance(Looks.VIEW_TICKS)


## All four Turrets in a look (0 whole, 1 first, 2 second, 3 fallen) and the moment held. A coroutine.
func _set_looks(look: int) -> void:
	await _k.restore_all()
	for who: Turret in _k.all():
		if look == 1:
			who.apply_damage(Looks.TO_FIRST + Looks.JUST_BELOW)
		elif look == 2:
			who.apply_damage(Looks.TO_SECOND + Looks.JUST_BELOW)
		elif look == 3:
			who.destroy()
	await _k.w.s.q.kit.advance(Looks.HOLD_TICKS)


## One look read in the view the cameras are on.
func _read_look(look: int, name: String) -> void:
	var seen: Array[int] = _looks()
	var want: int = -1 if look == 3 else look
	var q: Quick = _k.w.s.q
	_need(seen == [want, want, want, want] and q.units.units[0].is_alive and q.units.units[1].is_alive, "%s: the Turrets show %s, expected %d, Units alive %s %s" % [name, seen, want, q.units.units[0].is_alive, q.units.units[1].is_alive])
	_line(name, "looks=%s views=%s p1_hp=%.0f p2_hp=%.0f" % [seen, ", ".join(_views()), q.units.units[0].hit_points, q.units.units[1].hit_points])


## Whole, first, second and rubble, each in both views: the order keeps the view switches to three.
func _looks_in_both_views() -> void:
	await _set_looks(0)
	_need(_views() == PackedStringArray([Looks.ABOVE_FILE, Looks.ABOVE_FILE]), "looks_whole_above: the cameras are on %s" % [_views()])
	_read_look(0, "looks_whole_above")
	await _switch_views()
	_read_look(0, "looks_whole_chase")
	await _set_looks(1)
	_read_look(1, "looks_first_chase")
	await _switch_views()
	_read_look(1, "looks_first_above")
	await _set_looks(2)
	_read_look(2, "looks_second_above")
	await _switch_views()
	_read_look(2, "looks_second_chase")
	await _set_looks(3)
	_read_look(3, "looks_rubble_chase")
	await _switch_views()
	_read_look(3, "looks_rubble_above")


## Base B's Turrets in their second look and Player 1's Truck at a bearing off their rest heading:
## the head is read at rest (a Shot's worth of turn not yet made) and again nearly a quarter turn
## round, in Player 1's chase view; Player 2's view above shows the same Turrets from its Base. A
## coroutine.
func _head_turning() -> void:
	var q: Quick = _k.w.s.q
	await _set_looks(2)
	await _switch_views()
	var turret: Turret = _k.turret(1, Kit13.RIGHT)
	var bearing: Vector3 = _k.w.way(1, Vector3.FORWARD).rotated(Vector3.UP, deg_to_rad(BEARING_DEGREES))
	turret.head.rotation = Vector3.ZERO
	await _k.stage(0, Quick.TRUCK, turret.global_position + bearing * TURN_AT, -bearing)
	_in_front_of(1)
	var started: bool = false
	for _tick: int in Looks.LIMIT_TICKS:
		await q.kit.tick()
		var yaw: float = absf(turret.head.rotation.y)
		if not started and turret.state == Turret.State.AIMING and yaw > 0.05:
			started = true
			_need(Looks.look_shown(turret) == 2 and Looks.head_dressed(turret, 2, _k.w.bases[1].color_material), "head_turning_start: the head is not in its second look's steel")
			_line("head_turning_start", "yaw=%.3f look=%d views=%s" % [turret.head.rotation.y, Looks.look_shown(turret), ", ".join(_views())])
		if started and yaw >= QUARTER:
			_line("head_turning_end", "yaw=%.3f look=%d state=%s" % [turret.head.rotation.y, Looks.look_shown(turret), Turret.State.keys()[turret.state]])
			break
	_need(started and absf(turret.head.rotation.y) >= QUARTER, "head_turning: the head turned %.3f rad, started %s" % [turret.head.rotation.y, started])
	await q.kit.advance(Looks.HOLD_TICKS)


## Player `player`'s Unit in front of its own Turrets, facing into its Base.
func _in_front_of(player: int) -> void:
	_k.w.s.flags.teleport(player, _k.w.point(player, FRONT), _k.w.way(player, Vector3.BACK))


## Base A's Turrets have fallen and Base B's are in their second look when Player 2 carries Base A's
## Flag home through the broken Gate and the Round ends; then R, both Players choose again and stand
## just inside their Gates: the four Turrets are whole. A coroutine.
func _after_r() -> void:
	var q: Quick = _k.w.s.q
	await _set_looks(2)
	for side: int in Kit13.NAMES.size():
		_k.turret(0, side).destroy()
	_k.w.wall(0, Walls.GATE).destroy()
	await q.kit.advance(Kit13.SETTLE)
	var taken: bool = await _k.w.take_flag(1, 0, Walls.GATE)
	var delivered: bool = await _k.w.deliver(1)
	var kept: Array[int] = _looks()
	_need(taken and delivered and q.controller.is_round_over() and kept == [-1, -1, 2, 2], "after_r: the Round ended by a delivery (taken %s, delivered %s) with the Turrets showing %s" % [taken, delivered, kept])
	await q.kit.advance(Looks.HOLD_TICKS)
	_line("round_over_looks_kept", "looks=%s" % [kept])
	_need(await q.tokens.restart(), "after_r: the restart key brought no new Round")
	await _k.w.s.both_play()
	await _in_front()
	var seen: Array[int] = _looks()
	_need(seen == [0, 0, 0, 0] and _k.all().all(func(who: Turret) -> bool: return who.is_standing and who.head.rotation == Vector3.ZERO), "after_r: the Turrets show %s after R" % [seen])
	_line("after_r", "looks=%s views=%s" % [seen, ", ".join(_views())])
