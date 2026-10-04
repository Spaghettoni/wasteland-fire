extends RefCounted
## Scenario unit_swap_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 011 on Map 01 with the shipped data, Map stock and view from above, every
## key a real key event. Four moments, each held, then read: in_the_garage (Player 1's Truck and
## Player 2's Motorbike in their Garages), after_the_swap (Player 1 pressed Self-destruct at home: its
## choice panel is open with the counts as they were, Player 2's view has no panel and its Motorbike
## drives on), new_unit (Player 1 chose the Buggy: it stands in the Garage) and stranded (Player 1's
## Buggy dry in its own Base, whose hint says swap; Player 2's Motorbike dry outside its Base, whose hint
## says Self-destruct). A SPLIT line per moment with frame=, the number of the PNG that shows it in a
## --write-movie recording, and what the moment's premise reads. No CHECK in a normal run: it ends with
## RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty
## or false recording cannot pass as evidence.
## Implements: production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md, Test Evidence (the
## choice panel opened by a swap with the counts unchanged, the new Unit in the Garage, the swap hint
## of a Unit stranded at home). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/swap.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=unit_swap_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, put(), small_tank().
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 008 helpers (token_kit.gd): the real keys.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd).
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap the shipped rules turn on, and on the camera the build ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
## The frames show Map 01's own Token stock: nothing here spends a Token.
const USE_MAP_STOCK: bool = true
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 30
## The share of its tank a dry run's copy of a type spawns with.
const SMALL_TANK: float = 0.005

var _s: Swap
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the four moments, then the premise CHECK (only when one failed) and the RESULT line. The
## runner awaits this coroutine.
func run(harness: Node) -> void:
	_s = Swap.new(harness)
	await _s.play(0, Quick.TRUCK)
	await _s.play(1, Quick.MOTORBIKE)
	await _s.q.kit.advance(HOLD_TICKS)
	_line("in_the_garage", "p1=%s p2=%s" % [_s.q.units.units[0].type_id, _s.q.units.units[1].type_id])
	await _after_the_swap()
	await _new_unit()
	await _stranded()
	if not _problems.is_empty():
		_s.q.kit.verdict("premise", _problems, " | ".join(_moments))
	_s.close()
	harness.finish("moments=%d swaps=%d %s" % [_moments.size(), _s.swaps.size(), _s.q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(name: String, reads: String) -> void:
	_moments.append(name)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_s.q.harness.scenario, _s.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, name, reads])


## Player 1 presses Self-destruct in its Garage while Player 2's Motorbike drives on: read once the
## panel has been open for the hold. A coroutine.
func _after_the_swap() -> void:
	var tokens: Tokens = _s.q.tokens
	var before: Array = tokens.counts()
	_s.q.harness.drive(1, 1, 0)
	await _s.q.kit.advance(Kit.START_TICKS)
	await tokens.destruct(0)
	await _s.q.kit.advance(HOLD_TICKS)
	var panels: Array[bool] = [_s.q.units.panels[0].visible, _s.q.units.panels[1].visible]
	_s.q.kit.need(_problems, panels == [true, false], "after_the_swap: panels %s" % [panels])
	_s.q.kit.need(_problems, tokens.counts() == before and not _s.q.units.countdowns[0].visible, "after_the_swap: counts %s, countdown shown %s" % [tokens.counts(), _s.q.units.countdowns[0].visible])
	_s.q.kit.need(_problems, _s.q.units.units[1].current_speed > 0.0, "after_the_swap: Player 2 is not driving on")
	_line("after_the_swap", "p1_panel=%s p2_panel=%s counts_unchanged=%s p2_speed=%.2f %s" % [panels[0], panels[1], tokens.counts() == before, _s.q.units.units[1].current_speed, tokens.panel_counts(0)])
	_s.q.harness.release_all()


## Player 1 chooses the Buggy; read once it stands in the Garage. A coroutine.
func _new_unit() -> void:
	await _s.play(0, Quick.BUGGY)
	await _s.q.kit.advance(HOLD_TICKS)
	var unit: Unit = _s.q.units.units[0]
	_s.q.kit.need(_problems, unit.is_alive and unit.type_id == &"buggy" and _s.on_a_spawn_point(0), "new_unit: %s alive %s on a spawn point %s" % [unit.type_id, unit.is_alive, _s.on_a_spawn_point(0)])
	_line("new_unit", "p1=%s hp=%.0f fuel=%.1f at_spawn_point=%s" % [unit.type_id, unit.hit_points, unit.fuel, _s.on_a_spawn_point(0)])


## Player 1's Buggy runs dry in its own Base and Player 2's Motorbike outside its own; read once both
## hints show. A coroutine.
func _stranded() -> void:
	var pose: Array[Vector3] = _s.spawn_pose(0)
	await _s.q.put(0, _s.q.small_tank(Quick.BUGGY, SMALL_TANK), pose[0], pose[1])
	await _s.q.put(1, _s.q.small_tank(Quick.MOTORBIKE, SMALL_TANK), Quick.mirrored(Quick.LANE_SPOT), Vector3.LEFT)
	await _s.wait_until(func() -> bool: return _s.q.units.units[0].is_stranded and _s.q.units.units[1].is_stranded)
	await _s.q.kit.advance(HOLD_TICKS)
	var shown: Array[bool] = [_s.q.hints[0].visible, _s.q.hints[1].visible]
	var expected: Array[String] = [_s.q.hints[0].tr(_s.q.hints[0].swap_format), _s.q.hints[1].tr(_s.q.hints[1].format)]
	for player: int in Kit.PLAYERS:
		var key: String = OS.get_keycode_string(Tokens.keys(&"destruct", player)[0])
		_s.q.kit.need(_problems, shown[player] and _s.q.hints[player].text == expected[player] % key, "stranded: p%d hint shown %s '%s'" % [player + 1, shown[player], _s.q.hints[player].text])
	_line("stranded", "p1_hint='%s' p2_hint='%s'" % [_s.q.hints[0].text, _s.q.hints[1].text])
