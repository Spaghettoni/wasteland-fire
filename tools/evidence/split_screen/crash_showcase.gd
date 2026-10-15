extends RefCounted
## Scenario crash_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 021 on Map 01
## with the shipped data, every key a real key event. Both Players' Gyrocopters appear in their Garages (a real choice) and are
## then flown at full throttle, each Player at its own side of the Map (the mirror across x = 0), in the view from above and in the
## chase view (the Q and Slash keys step both): into a corner tower, a water tower leg, a depot tank and a Turret, shown one tick
## before the contact and six ticks after it, when the fireball shows, with the Gyrocopters gone; along a tower's face at 13
## degrees, sliding on alive; pinned against a leg with the throttle held; and head-on into the sea edge, stopped alive. A SPLIT line
## per moment with frame=, the number of the PNG that shows it in a --write-movie recording (CRASH_PASS=above or chase, and
## CRASH_MOMENTS=tower,leg,tank,turret,graze,pinned,shore (any of them), environment variables of a run by hand, play one pass only and the
## named groups of moments only). No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one
## failing CHECK named premise, so an empty or false recording cannot pass as evidence. Every outcome is a CHECK of the crash
## scenario. Implements: production/epics/wasteland-fire/story-021-gyrocopter-crash.md, Test Evidence (retained frames). Tooling
## only. Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/crash.png
## res://tools/evidence/split_screen_harness.tscn -- --scenario=crash_showcase

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd): the views' settings files and the ticks a moment holds.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 40}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 1800.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The ticks after the crash tick at which its moments are taken: the flash that shows at once (the tower's, the crash's own tick
## and one more) and the fireball and its chunks (every kind's).
const FLASH_TICKS: int = 2
const FIREBALL_TICKS: int = 20
## The angle of the graze to the tower's face (degrees: under the crash angle), and the ticks after its first touch the moment is taken.
const GRAZE_ANGLE: float = 13.0
const GRAZE_AFTER: int = 3
## The ticks a Gyrocopter is held pinned with the throttle before its moment, and after its touch at the sea edge.
const PIN_TICKS: int = 90
const SHORE_AFTER: int = 20
## The ticks a flight may take.
const DRIVE_LIMIT: int = 420

var _k: Kit21
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _pass: String = "above"
## The row of the first wall contact of a flight with the crash off, by the piece's path: the crash comes on that row.
var _contacts: Dictionary = {}


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit21.new(harness)
	_q = _k.q()
	await _both_choose()
	_line("launch_%s" % _pass, "both Gyrocopters spawned in their Garages by the choice keys, the models' lowest points %.3f and %.3f m" % [Quick.model_bottom(_q.units.units[0]), Quick.model_bottom(_q.units.units[1])])
	await _q.kit.advance(Looks.HOLD_TICKS)
	var only: String = OS.get_environment("CRASH_PASS")
	var moments: PackedStringArray = OS.get_environment("CRASH_MOMENTS").split(",", false)
	for pass_index: int in 2:
		if only == "chase" and pass_index == 0:
			await _switch_views()
			_pass = "chase"
			continue
		if only == "above" and pass_index == 1:
			break
		_pass = "above" if pass_index == 0 else "chase"
		for kind: String in ["tower", "leg", "tank", "turret"]:
			if moments.is_empty() or moments.has(kind):
				await _crash_pair(kind)
		if moments.is_empty() or moments.has("graze"):
			await _graze()
		if moments.is_empty() or moments.has("pinned"):
			await _pinned()
		if moments.is_empty() or moments.has("shore"):
			await _shore()
		if pass_index == 0 and only.is_empty():
			await _switch_views()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d" % _moments.size())


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		found.append(_q.units.cameras[player].settings.resource_path.get_file())
	return found


## The reading every moment's line carries: the views, and a premise check that both cameras are on the pass's view.
func _in_view(moment: String) -> String:
	var want: String = Looks.ABOVE_FILE if _pass == "above" else Looks.CHASE_FILE
	_need(_views() == PackedStringArray([want, want]), "%s_%s: the cameras are on %s" % [moment, _pass, _views()])
	return "views=%s" % ", ".join(_views())


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	await _q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await _q.kit.advance(Looks.VIEW_TICKS)


## Both Players choose the Gyrocopter with their own keys at once: the next-type key for whichever cursor is not on it, then both fire keys.
func _both_choose() -> void:
	for _step: int in 8:
		var keys: Array[Key] = []
		for player: int in Kit.PLAYERS:
			if _q.units.panels[player].choice_input.cursor != Quick.GYROCOPTER:
				keys.append_array(Tokens.keys(&"next", player))
		if keys.is_empty():
			break
		await _q.kit.press_settled(keys)
	await _q.kit.press_settled(Tokens.keys(&"fire", 0) + Tokens.keys(&"fire", 1))
	for _wait: int in 400:
		if _q.controller.is_alive(0) and _q.controller.is_alive(1):
			break
		await _q.kit.tick()
	await _q.kit.advance(3)


## Every piece and Turret back and both Players in play (after a crash a Player chooses again with its keys).
func _dress() -> void:
	for player: int in Kit.PLAYERS:
		await _k.mines().revive(player)
	await _k.walls().restore_all(true)


## The mirror across x = 0, Player 2's side of the Map.
static func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## The two lines of a crash at a kind: Player 1's, and Player 2's at the mirror piece (the tanks: the north-west one and the north-east one).
func _lines(kind: String) -> Array[Dictionary]:
	if kind == "tank":
		return [_k.line(Kit21.path_of(Kit21.TANKS[0]), Vector3.RIGHT, 0.0, 12.0), _k.line(Kit21.path_of(Kit21.TANKS[1]), Vector3.LEFT, 0.0, 12.0)]
	return [_k.line(Kit21.path_of(kind, 0), Kit21.toward(0)), _k.line(Kit21.path_of(kind, 1), Kit21.toward(1))]


## Both Gyrocopters staged at their lines (full tanks) and flown at full throttle for `ticks` ticks, the watch filing both.
func _fly_pair(starts: Array[Vector3], dirs: Array[Vector3], ticks: int, stop: Callable = Callable()) -> int:
	await _q.map.stage([Kit21.GYRO, Kit21.GYRO], starts, dirs, true)
	_k.watch.clear()
	_k.watch.logging = true
	var held: int = 0
	for _tick: int in ticks:
		_q.harness.drive(0, 1, 0)
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
		held += 1
		if stop.is_valid() and stop.call():
			break
	_k.watch.logging = false
	return held


## A crash at a kind, shown one tick before the contact and AFTER_CRASH ticks after it: the contact row is that of the flight with the crash off.
func _crash_pair(kind: String) -> void:
	await _dress()
	var lines: Array[Dictionary] = _lines(kind)
	if not _contacts.has(kind):
		var control: Dictionary = await _k.control(0, lines[0]["start"], lines[0]["dir"])
		_contacts[kind] = int(control["hit"])
		await _dress()
	var row: int = int(_contacts[kind])
	_need(row > 1, "crash_%s_%s: the control's contact row is %d" % [kind, _pass, row])
	await _fly_pair([lines[0]["start"], lines[1]["start"]], [lines[0]["dir"], lines[1]["dir"]], row)
	var gaps: Array[float] = [_k.nose_gap(_q.units.units[0].global_position, lines[0]), _k.nose_gap(_q.units.units[1].global_position, lines[1])]
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and gaps[0] > 0.0 and gaps[1] > 0.0, "before_%s_%s: alive %s and %s, noses %.3f and %.3f m from the face" % [kind, _pass, _q.units.units[0].is_alive, _q.units.units[1].is_alive, gaps[0], gaps[1]])
	_line("before_%s_%s" % [kind, _pass], "both Gyrocopters one tick before they meet the %s at %.1f m/s, their noses %.2f and %.2f m from it %s" % [kind, _q.units.units[0].get_real_velocity().length(), gaps[0], gaps[1], _in_view("before_" + kind)])
	var shown: int = 0
	if kind == "tower":
		await _q.kit.advance(FLASH_TICKS)
		shown = FLASH_TICKS
		_crash_line("crash", kind, "the flash of")
	await _q.kit.advance(FIREBALL_TICKS - shown)
	_q.harness.release_all()
	_crash_line("blast" if kind == "tower" else "crash", kind, "the fireball of")
	await _q.kit.advance(Looks.HOLD_TICKS)


## A moment after a crash: both Gyrocopters gone, both Explosions playing where the models were drawn.
func _crash_line(moment: String, kind: String, what: String) -> void:
	var blasts: int = _k.blasts().size()
	_need(not _q.units.units[0].is_alive and not _q.units.units[1].is_alive and blasts >= 2, "%s_%s_%s: alive %s and %s, %d Explosions" % [moment, kind, _pass, _q.units.units[0].is_alive, _q.units.units[1].is_alive, blasts])
	_line("%s_%s_%s" % [moment, kind, _pass], "both Gyrocopters destroyed on the tick of their contact with the %s, %s the %d Explosions where the models were drawn, in the air (the centres %.2f and %.2f m up) %s" % [kind, what, blasts, _k.destroyed[-1]["expected"].y, _k.destroyed[-2]["expected"].y, _in_view(moment + "_" + kind)])


## A graze of a tower's north face at GRAZE_ANGLE degrees and full throttle: Player 1's, and Player 2's at the mirror face; the moment is
## GRAZE_AFTER ticks after the first touch, both Gyrocopters sliding on along the face, alive.
func _graze() -> void:
	await _dress()
	var first: Dictionary = _k.graze_line(Kit21.path_of("tower", 0), GRAZE_ANGLE)
	var second_start: Vector3 = _mirror(first["start"])
	var second_dir: Vector3 = _mirror(first["dir"])
	var both_touched: Callable = func() -> bool:
		var rows: Array = _k.watch.rows[0]
		var other: Array = _k.watch.rows[1]
		return _k.watch.first_wall(0) >= 0 and _k.watch.first_wall(1) >= 0 and rows.size() > _k.watch.first_wall(0) + GRAZE_AFTER and other.size() > _k.watch.first_wall(1) + GRAZE_AFTER
	await _fly_pair([first["start"], second_start], [first["dir"], second_dir], DRIVE_LIMIT, both_touched)
	var speeds: Array[float] = [_q.units.units[0].get_real_velocity().length(), _q.units.units[1].get_real_velocity().length()]
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and speeds[0] > 10.0 and speeds[1] > 10.0, "graze_%s: alive %s and %s at %.2f and %.2f m/s" % [_pass, _q.units.units[0].is_alive, _q.units.units[1].is_alive, speeds[0], speeds[1]])
	_line("graze_%s" % _pass, "both Gyrocopters %d ticks after they touched a corner tower's face at %.0f degrees to it (arrival %.2f m/s, under the crash speed %.1f), sliding on along it at %.1f and %.1f m/s, alive %s" % [GRAZE_AFTER, GRAZE_ANGLE, Kit21.Watch.walls(_k.watch.rows[0][_k.watch.first_wall(0)])[0]["arrival"], _k.crash_speed(), speeds[0], speeds[1], _in_view("graze")])
	_q.harness.release_all()
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Gyrocopters pinned against a leg with the throttle held for PIN_TICKS ticks: their command at the top speed, their motion zero.
func _pinned() -> void:
	await _dress()
	var lines: Array[Dictionary] = [_k.line(Kit21.path_of("leg", 0), Kit21.toward(0), 0.0, 0.02), _k.line(Kit21.path_of("leg", 1), Kit21.toward(1), 0.0, 0.02)]
	await _fly_pair([lines[0]["start"], lines[1]["start"]], [lines[0]["dir"], lines[1]["dir"]], PIN_TICKS)
	_q.harness.release_all()
	var cmds: Array[float] = [_q.units.units[0].current_speed, _q.units.units[1].current_speed]
	var reals: Array[float] = [_q.units.units[0].get_real_velocity().length(), _q.units.units[1].get_real_velocity().length()]
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and cmds[0] >= 0.99 * _k.gyro_stats().max_speed and reals[0] <= 0.01 and reals[1] <= 0.01, "pinned_%s: alive %s and %s, commands %.2f and %.2f, real %.4f and %.4f" % [_pass, _q.units.units[0].is_alive, _q.units.units[1].is_alive, cmds[0], cmds[1], reals[0], reals[1]])
	_line("pinned_%s" % _pass, "both Gyrocopters pinned against a water tower leg for %d ticks with the throttle held, commanding %.1f and %.1f m/s of a top %.1f while their real motion is %.4f and %.4f m/s, alive %s" % [PIN_TICKS, cmds[0], cmds[1], _k.gyro_stats().max_speed, reals[0], reals[1], _in_view("pinned")])
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Gyrocopters head-on into the sea edge at the top speed (the west shore, and the east one), stopped there and alive.
func _shore() -> void:
	await _dress()
	var west: Dictionary = _k.shore_run(Kit21.SHORE_AIMS["west"])
	var east: Dictionary = _k.shore_run(Kit21.SHORE_AIMS["east"])
	var both_touched: Callable = func() -> bool:
		var rows: Array = _k.watch.rows[0]
		var other: Array = _k.watch.rows[1]
		return _k.watch.first_wall(0) >= 0 and _k.watch.first_wall(1) >= 0 and rows.size() > _k.watch.first_wall(0) + SHORE_AFTER and other.size() > _k.watch.first_wall(1) + SHORE_AFTER
	await _fly_pair([west["start"], east["start"]], [west["dir"], east["dir"]], DRIVE_LIMIT, both_touched)
	_q.harness.release_all()
	var hit: Dictionary = Kit21.Watch.walls(_k.watch.rows[0][_k.watch.first_wall(0)])[0]
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and float(hit["arrival"]) >= _k.crash_speed(), "shore_%s: alive %s and %s, arrival %.2f" % [_pass, _q.units.units[0].is_alive, _q.units.units[1].is_alive, hit["arrival"]])
	_line("shore_%s" % _pass, "both Gyrocopters stopped alive by the sea edge %d ticks after they hit it head-on at %.1f m/s, over the crash speed %.1f, because its bodies are in the group map_edge %s" % [SHORE_AFTER, float(hit["arrival"]), _k.crash_speed(), _in_view("shore")])
	await _q.kit.advance(Looks.HOLD_TICKS)
