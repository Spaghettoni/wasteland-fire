extends RefCounted
## Scenario mines_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of
## Story 014 on Map 01 with the shipped data and view from above, every key a real key event. Ten moments, each read
## where its premise holds: just_laid (Player 1's Truck has just laid a Mine: "Mines 4 / 5" in its view and not in
## the other's), arming_lit and arming_dark (the same arming Mine a blink apart, in both views), live (the same Mine
## steady and live), salt_flat, canyon_road and ford (live Mines drawn over their ground in both views), flash (a
## Motorbike destroyed on a live Mine, the flash showing), gyro_over (a Gyrocopter hovering over a live Mine, nothing
## happens), refused_at_gate (a press in front of the own Gate: the notice line "No Mines in or near a Base") and
## none_left ("Mines 0 / 5" and "No Mines left"). A SPLIT line per moment with frame=, the number of the PNG that
## shows it in a --write-movie recording, and what the moment's premise reads. No CHECK in a normal run: it ends with
## RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty or false
## recording cannot pass as evidence. Implements: production/epics/wasteland-fire/story-014-truck-mines.md, Test Evidence
## (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/mines.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=mines_showcase

const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
## It declares MINES and not TURRETS: the Turrets are not in its frames, and the notice line its refusals use stays all the
## same, which is the runner's rule for a scenario that declares MINES alone.
const MINES: bool = true
## Tokens enough that the destructions of the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 600.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 20
## The flat of the Map where the first moments lie, Player 1's Truck facing east, and where Player 2's Motorbike stands.
const FLAT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const NEIGHBOUR: Vector3 = Vector3(-24.0, 0.0, -2.0)
## The own tick of the Mine at which each blink phase is read: lit in the first blink, dark in the second half of it.
const LIT_TICK: int = 38
const DARK_TICK: int = 52
## The three grounds: the salt flat in front of the canyon's south wall, the canyon road and a ford.
const GROUNDS: Dictionary = {"salt_flat": Vector3(-70.0, 0.0, -14.0), "canyon_road": Vector3(-55.0, 0.0, -36.0), "ford": Vector3(-40.0, 0.0, 0.0)}
## Where the Truck stands before the Gate (the drop point lies 0.3 m inside the approach's edge) and how far Player 2's
## Motorbike starts west of the Mine it drives over.
const GATE_TRUCK: Vector3 = Vector3(-98.0, 0.0, 0.0)
const RUN_UP: float = 18.0

var _k: Kit14
var _q: Object
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit14.new(harness)
	_q = _k.w.s.q
	await _k.w.s.both_play()
	await _q.kit.advance(HOLD_TICKS)
	await _lay_moments()
	await _grounds()
	await _flash()
	await _gyro_over()
	await _refused_at_gate()
	await _none_left()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d mines=%d %s" % [_moments.size(), _k.laid.size(), _q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Starts a moment from the Round's own state: every Mine cleared, both Players' notices quiet, both Units in play.
func _reset() -> void:
	await _k.clear_mines()
	for player: int in Kit.PLAYERS:
		for _tick: int in 200:
			if _k.note(player) == "hidden":
				break
			await _q.kit.tick()
		await _k.revive(player)


## Waits until the physics frame that is the Mine's own tick `tick` (the first own tick is the frame after it entered).
func _until_own_tick(record: Dictionary, tick: int) -> void:
	while Engine.get_physics_frames() < int(record["frame"]) + tick:
		await _q.kit.tick()


## just_laid, arming_lit, arming_dark and live: one Mine, Player 1's Truck on the flat, Player 2's Motorbike beside it.
func _lay_moments() -> void:
	await _reset()
	await _k.put(1, Quick.MOTORBIKE, NEIGHBOUR, Vector3.RIGHT)
	await _k.put(0, Quick.TRUCK, FLAT, Vector3.RIGHT)
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	await _q.kit.advance(2)
	_need(_k.line(0) == "Mines 4 / 5" and _k.line(1) == "hidden" and mine.state == Mine.State.ARMING, "just_laid: the lines read '%s' and '%s', the Mine is %d" % [_k.line(0), _k.line(1), mine.state])
	_line("just_laid", "line_p1='%s' line_p2='%s' mine_lit=%s" % [_k.line(0), _k.line(1), mine.body.visible])
	await _until_own_tick(record, LIT_TICK)
	_need(mine.body.visible and mine.state == Mine.State.ARMING, "arming_lit: lit %s, state %d" % [mine.body.visible, mine.state])
	_line("arming_lit", "own_tick=%d lit=%s state=%d" % [LIT_TICK, mine.body.visible, mine.state])
	await _until_own_tick(record, DARK_TICK)
	_need(not mine.body.visible and mine.state == Mine.State.ARMING, "arming_dark: lit %s, state %d" % [mine.body.visible, mine.state])
	_line("arming_dark", "own_tick=%d lit=%s state=%d" % [DARK_TICK, mine.body.visible, mine.state])
	await _q.kit.advance(Kit14.LIVE_WAIT)
	_need(mine.body.visible and mine.state == Mine.State.LIVE, "live: lit %s, state %d" % [mine.body.visible, mine.state])
	_line("live", "lit=%s state=%d" % [mine.body.visible, mine.state])


## salt_flat, canyon_road and ford: a live Mine on each ground (placed by the tool, live together), each with both Players' Units beside it.
func _grounds() -> void:
	await _reset()
	var placed: Dictionary = {}
	for ground: String in GROUNDS:
		placed[ground] = await _k.place_mine(GROUNDS[ground], 0, false)
	await _q.kit.advance(Kit14.LIVE_WAIT)
	for ground: String in GROUNDS:
		var at: Vector3 = GROUNDS[ground]
		await _k.put(0, Quick.TRUCK, at + Vector3(-7.0, 0.0, 3.0), Vector3.RIGHT)
		await _k.put(1, Quick.MOTORBIKE, at + Vector3(-5.0, 0.0, -4.0), Vector3.RIGHT)
		await _q.kit.advance(HOLD_TICKS)
		var mine: Mine = placed[ground]["mine"] as Mine
		_need(mine.state == Mine.State.LIVE and mine.body.visible and _k.layers[0].is_open_ground(at), "%s: Mine %d, lit %s" % [ground, mine.state, mine.body.visible])
		_line(ground, "state=%d at=(%.0f, %.0f)" % [mine.state, at.x, at.z])


## flash: Player 2's Motorbike, driven over a live Mine, is destroyed; read in the first frames of the flash.
func _flash() -> void:
	await _reset()
	var record: Dictionary = await _k.place_mine(FLAT, 0)
	var mine: Mine = record["mine"] as Mine
	await _k.put(0, Quick.MOTORBIKE, FLAT + Vector3(0.0, 0.0, 12.0), Vector3.RIGHT)
	await _k.put(1, Quick.MOTORBIKE, FLAT + Vector3(-RUN_UP, 0.0, 0.0), Vector3.RIGHT)
	_q.harness.drive(1, 1, 0)
	for _tick: int in 300:
		await _q.kit.tick()
		if mine.state == Mine.State.SPENT:
			break
	_q.harness.drive(1, 0, 0)
	await _q.kit.advance(3)
	_need(mine.state == Mine.State.SPENT and mine.flash.visible and not _q.units.units[1].is_alive, "flash: Mine %d, flash %s, Unit alive %s" % [mine.state, mine.flash.visible, _q.units.units[1].is_alive])
	_line("flash", "state=%d flash=%s victim_alive=%s" % [mine.state, mine.flash.visible, _q.units.units[1].is_alive])
	await _q.kit.advance(HOLD_TICKS)


## gyro_over: Player 2's Gyrocopter hovers over a live Mine, its tank full enough for the moment: nothing happens.
func _gyro_over() -> void:
	await _reset()
	var record: Dictionary = await _k.place_mine(FLAT, 0)
	var mine: Mine = record["mine"] as Mine
	await _k.put(0, Quick.MOTORBIKE, FLAT + Vector3(-9.0, 0.0, 4.0), Vector3.RIGHT)
	await _k.put(1, Quick.GYROCOPTER, FLAT, Vector3.RIGHT)
	await _q.kit.advance(HOLD_TICKS * 2)
	_need(mine.state == Mine.State.LIVE and _q.units.units[1].is_alive and _q.units.units[1].global_position.distance_to(FLAT) < 1.0, "gyro_over: Mine %d, Gyrocopter alive %s" % [mine.state, _q.units.units[1].is_alive])
	_line("gyro_over", "state=%d gyro_alive=%s gap=%.2f" % [mine.state, _q.units.units[1].is_alive, _q.units.units[1].global_position.distance_to(FLAT)])


## refused_at_gate: Player 1's Truck in front of its own Gate presses E: nothing is laid and its view says why.
func _refused_at_gate() -> void:
	await _reset()
	await _k.put(1, Quick.MOTORBIKE, FLAT + Vector3(0.0, 0.0, 12.0), Vector3.RIGHT)
	await _k.put(0, Quick.TRUCK, GATE_TRUCK, Vector3.LEFT)
	var laid: int = _k.laid.size()
	await _k.lay(0)
	await _q.kit.advance(10)
	_need(_k.laid.size() == laid and _k.note(0) == "No Mines in or near a Base" and _k.note(1) == "hidden" and _k.line(0) == "Mines 5 / 5", "refused_at_gate: laid %d, notices '%s' and '%s', line '%s'" % [_k.laid.size() - laid, _k.note(0), _k.note(1), _k.line(0)])
	_line("refused_at_gate", "notice_p1='%s' notice_p2='%s' line_p1='%s'" % [_k.note(0), _k.note(1), _k.line(0)])


## none_left: five Mines laid in a row on the flat, then a sixth press.
func _none_left() -> void:
	await _reset()
	await _k.put(1, Quick.MOTORBIKE, FLAT + Vector3(-10.0, 0.0, 12.0), Vector3.RIGHT)
	await _k.put(0, Quick.TRUCK, FLAT + Vector3(-14.0, 0.0, 0.0), Vector3.RIGHT)
	for index: int in 5:
		_k.w.s.flags.teleport(0, FLAT + Vector3(-14.0 + 3.0 * index, 0.0, 0.0), Vector3.RIGHT)
		await _q.kit.advance(Kit14.SETTLE)
		await _k.lay(0)
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	await _q.kit.advance(10)
	_need(_k.line(0) == "Mines 0 / 5" and _k.note(0) == "No Mines left" and _k.note(1) == "hidden", "none_left: line '%s', notices '%s' and '%s'" % [_k.line(0), _k.note(0), _k.note(1)])
	_line("none_left", "line_p1='%s' notice_p1='%s'" % [_k.line(0), _k.note(0)])
