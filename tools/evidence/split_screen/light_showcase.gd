extends RefCounted
## Scenario light_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 027 on Map 01 with the shipped data, every key a real
## key event, in two halves. The silhouette moments (LIGHT_MOMENTS=sil, light_showcase_sil.gd) stage each Player's Unit behind a piece of cover as that Player's own camera sees it
## (a Turret, a corner tower, a water tower's leg, a container, a cliff, and a Gyrocopter under the tank), in the chase view and in the view from above, with the other Player's
## view at the same moment; the light moments (LIGHT_MOMENTS=light, light_showcase_light.gd) show the salt flat from above in full sun, a Base in shade and both Teams' Units
## under the Linear, AgX, Filmic and ACES tone mappers, the glow on a probe brighter than the threshold, and the grade on and off. A SPLIT line per moment with frame=, the number
## of the PNG that shows it in a --write-movie recording (LIGHT_PASS=above or chase, LIGHT_MOMENTS=sil,light, environment variables of a run by hand, play one pass only and the
## named halves only). LIGHT_PROBE=1 runs the search of the places (headless, quick): for each silhouette moment, the metres behind a piece at which cover hides some of the
## Unit's box from its own camera, printed as PROBE lines. LIGHT_NO_SIL=1 takes both Units' silhouette away before the choice (the runner's strip: no copy, no fill quad, the cameras'
## masks as before the story), so that a recording of the same moments without the silhouettes can be compared pixel for pixel with the one with them. No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named
## premise, so an empty or false recording cannot pass as evidence. Implements: production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md, Test Evidence (retained
## frames). Tooling only. Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/light.png res://tools/evidence/split_screen_harness.tscn --
## --scenario=light_showcase

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd): the views' settings files and the ticks a moment holds.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
const Sil: GDScript = preload("res://tools/evidence/split_screen/light_showcase_sil.gd")
const Light: GDScript = preload("res://tools/evidence/split_screen/light_showcase_light.gd")

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
const AMMO: bool = true
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const SEE_THROUGH: bool = true
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 1800.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1

var k: Kit27
var q: Quick
var problems: PackedStringArray = []
var moments: PackedStringArray = []
## The pass the moments are in: "above" (the Round's start) then "chase" (after the keys step both views).
var pass_name: String = "above"
var _harness: Node


## Plays the halves the environment names, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_harness = harness
	k = Kit27.new(harness)
	q = k.q()
	if not OS.get_environment("LIGHT_NO_SIL").is_empty():
		for unit: Unit in [harness.split.player_1_unit, harness.split.player_2_unit]:
			unit.silhouette = null
		for camera: ChaseCamera in [harness.split.player_1_camera, harness.split.player_2_camera]:
			camera.never_drawn_layers = 0
	await both_choose(Quick.MOTORBIKE)
	line("garage_spawn_above", "both Motorbikes spawned in their Garages by the choice keys")
	await q.kit.advance(Looks.HOLD_TICKS)
	var only: String = OS.get_environment("LIGHT_PASS")
	var halves: PackedStringArray = OS.get_environment("LIGHT_MOMENTS").split(",", false)
	var probe: bool = not OS.get_environment("LIGHT_PROBE").is_empty()
	var silhouettes: Sil = Sil.new(self)
	var light: Light = Light.new(self)
	for pass_index: int in 2:
		if only == "chase" and pass_index == 0:
			await switch_views()
			continue
		if only == "above" and pass_index == 1:
			break
		pass_name = "above" if pass_index == 0 else "chase"
		await dress()
		if probe:
			if OS.get_environment("LIGHT_PROBE") == "shade":
				if pass_name == "above":
					light.probe_shade()
			else:
				await silhouettes.probe()
		else:
			if halves.is_empty() or halves.has("sil"):
				await silhouettes.play()
			if halves.is_empty() or halves.has("light"):
				await light.play()
			if halves.has("explore"):
				await light.explore()
		if pass_index == 0:
			await switch_views()
	if not problems.is_empty():
		q.kit.verdict("premise", problems, " | ".join(moments))
	k.close()
	harness.finish("moments=%d" % moments.size())


## Prints a moment's line with its frame and what it reads, and files the moment.
func line(moment: String, reads: String) -> void:
	moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [q.harness.scenario, q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func need(holds: bool, problem: String) -> void:
	q.kit.need(problems, holds, problem)


## Which view each Player's camera is on, by the settings file it carries.
func views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		found.append(q.units.cameras[player].settings.resource_path.get_file())
	return found


## Whether both cameras are on the pass's view.
func in_pass_view() -> bool:
	var want: String = Looks.ABOVE_FILE if pass_name == "above" else Looks.CHASE_FILE
	return views() == PackedStringArray([want, want])


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func switch_views() -> void:
	await q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await q.kit.advance(Looks.VIEW_TICKS)


## Both Players choose a type with their own keys at once: the next-type key for whichever cursor is not on it, then both fire keys.
func both_choose(type_index: int) -> void:
	for _step: int in 8:
		var keys: Array[Key] = []
		for player: int in Kit.PLAYERS:
			if q.units.panels[player].choice_input.cursor != type_index:
				keys.append_array(Tokens.keys(&"next", player))
		if keys.is_empty():
			break
		await q.kit.press_settled(keys)
	await q.kit.press_settled(Tokens.keys(&"fire", 0) + Tokens.keys(&"fire", 1))
	for _wait: int in 400:
		if q.controller.is_alive(0) and q.controller.is_alive(1):
			break
		await q.kit.tick()
	await q.kit.advance(3)


## Every piece and Turret back and both Players in play.
func dress() -> void:
	for player: int in Kit.PLAYERS:
		await k.mines().revive(player)
	await k.walls().restore_all(true)
