extends RefCounted
## Scenario rotors_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 025 on Map 01
## with the shipped data, every key a real key event. Both Players choose the Gyrocopter with their own keys (Player 1 is Orange,
## Player 2 Teal), and each Gyrocopter is then shown in the view from above and in the chase view (the Q and Slash keys step both):
## standing in the open, flying at its full speed, four consecutive frames of one rotor standing (the turn, the smear, the two blades
## countable in each), the propeller standing and at full speed, and over the legs of its water tower with the blades turning through
## them. A SPLIT line per moment with frame=, the number of the PNG that shows it in a --write-movie recording (ROTORS_PASS=above or
## chase, and ROTORS_MOMENTS=stand,fast,turn,prop,legs (any of them), environment variables of a run by hand, play one pass only and
## the named groups of moments only). No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one
## failing CHECK named premise, so an empty or false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-025-gyrocopter-rotor.md, Test Evidence (retained frames). Tooling only. Run: godot --path .
## --windowed --resolution 1280x720 --write-movie shots/rotors.png res://tools/evidence/split_screen_harness.tscn --
## --scenario=rotors_showcase

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
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
const ROTORS: bool = true
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 1200.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The middle of the Map, clear of both Bases' Turrets, and how far each Player's start is from it along the Map's width (Player 2 at
## the mirror across x = 0, flying the other way).
const MIDDLE: Vector3 = Vector3(0.0, 0.0, -16.0)
const APART: float = 30.0
## A Base-local place between the water tower's Gate-side legs (as in heights_showcase).
const BETWEEN_LEGS: Vector3 = Vector3(0.0, 0.0, -7.0)
## Ticks a Gyrocopter stands before a standing moment (the rotor has turned a good many times), the ticks it is flown for at full
## throttle before the moment of its full speed (it reaches 16.4 m/s in about 70), the consecutive frames of the turn and the ticks
## between the frames of a turn.
const STAND_TICKS: int = 50
const FLY_TICKS: int = 100
const TURN_FRAMES: int = 4

var _k: Kit25
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _pass: String = "above"


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit25.new(harness)
	_q = _k.q()
	await _both_choose()
	_line("garage_spawn_above", "both Gyrocopters spawned in their Garages by the choice keys")
	await _q.kit.advance(Looks.HOLD_TICKS)
	var only: String = OS.get_environment("ROTORS_PASS")
	var moments: PackedStringArray = OS.get_environment("ROTORS_MOMENTS").split(",", false)
	for pass_index: int in 2:
		if only == "chase" and pass_index == 0:
			await _switch_views()
			continue
		if only == "above" and pass_index == 1:
			break
		_pass = "above" if pass_index == 0 else "chase"
		await _dress()
		if moments.is_empty() or moments.has("stand"):
			await _standing()
		if moments.is_empty() or moments.has("fast"):
			await _flying()
		if (moments.is_empty() or moments.has("turn")) and _pass == "above":
			await _turning()
		if moments.is_empty() or moments.has("legs"):
			await _over_legs()
		if pass_index == 0:
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


## Every piece and Turret back and both Players in play.
func _dress() -> void:
	for player: int in Kit.PLAYERS:
		await _k.k.mines().revive(player)
	await _k.k.walls().restore_all(true)


## The mirror across x = 0, Player 2's side of the Map.
static func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## What the pivots read for a Player: "rotor 123.4 deg at 4.00 turns/s, propeller 45.6 deg at 2.00 turns/s".
func _turned(player: int) -> String:
	var parts: PackedStringArray = []
	for pivot: RotorPivot in _k.pivots_of(player):
		parts.append("%s %.1f deg at %.2f turns/s" % [String(pivot.name).to_lower(), rad_to_deg(pivot.angle), pivot.current_turns_per_second])
	return ", ".join(parts)


## The checks and the line of a moment whose pair is in place and in the pass's view.
func _finish(moment: String, reads: String) -> void:
	var want: String = Looks.ABOVE_FILE if _pass == "above" else Looks.CHASE_FILE
	var in_play: bool = _q.units.units[0].is_alive and _q.units.units[1].is_alive
	_need(in_play and _views() == PackedStringArray([want, want]), "%s_%s: Units alive %s, the cameras are on %s" % [moment, _pass, in_play, _views()])
	for player: int in Kit.PLAYERS:
		_need(_k.pivots_of(player).size() == 2, "%s_%s: Player %d's Gyrocopter has %d turning parts" % [moment, _pass, player + 1, _k.pivots_of(player).size()])
	_line("%s_%s" % [moment, _pass], "%s | P1 %s | P2 %s views=%s" % [reads, _turned(0), _turned(1), ", ".join(_views())])


## Both Gyrocopters standing in the open, the rotors turning.
func _standing() -> void:
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [MIDDLE + Vector3.LEFT * APART, MIDDLE + Vector3.RIGHT * APART], [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.advance(STAND_TICKS)
	_finish("stand", "both Gyrocopters standing in the open, Player 1 Orange and Player 2 Teal, the rotor turning at a steady rate and the propeller at its idle rate")
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Gyrocopters flown at full throttle toward the middle until they are at their top speed.
func _flying() -> void:
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [MIDDLE + Vector3.LEFT * APART, MIDDLE + Vector3.RIGHT * APART], [Vector3.RIGHT, Vector3.LEFT], true)
	for _tick: int in FLY_TICKS:
		_q.harness.drive(0, 1, 0)
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
	_finish("fast", "both Gyrocopters flying at their top speed (%.1f and %.1f m/s), the propeller at its full rate" % [_k.watch.read(0)["along"], _k.watch.read(1)["along"]])
	_q.harness.release_all()
	await _q.kit.advance(Looks.HOLD_TICKS)


## Four consecutive frames of the rotors standing: one tick, one frame, the angle printed on each.
func _turning() -> void:
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [MIDDLE + Vector3.LEFT * APART, MIDDLE + Vector3.RIGHT * APART], [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.advance(STAND_TICKS)
	for index: int in TURN_FRAMES:
		await _q.kit.tick()
		_finish("turn_%d" % (index + 1), "frame %d of %d consecutive frames of the rotors standing" % [index + 1, TURN_FRAMES])
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Gyrocopters between their water tower's Gate-side legs, the blades turning through them.
func _over_legs() -> void:
	var flags: Object = _k.k.flags()
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [flags.point(0, BETWEEN_LEGS), flags.point(1, BETWEEN_LEGS)], [flags.way(0, Vector3.BACK), flags.way(1, Vector3.BACK)], true)
	await _q.kit.advance(STAND_TICKS)
	_finish("legs", "both Gyrocopters between their water tower's Gate-side legs, the blades turning through them")
	await _q.kit.advance(Looks.HOLD_TICKS)
