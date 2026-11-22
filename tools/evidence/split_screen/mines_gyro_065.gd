extends RefCounted
## Scenario mines_gyro_065 of the split screen evidence harness (split_screen_harness.gd): Stories 065 and 066 on Map 02's open
## middle with the shipped data.
##  M1 the look: a Mine laid for Player 1 is drawn as its casing (look_radius) with the Team light on top (look_radius *
##     light_share), smaller than its trigger; once live the light blinks (it is shown and hidden in turn over a second).
##  M2 its own Team: Player 1's own Buggy driven over Player 1's live Mine is destroyed (spares_own_team false).
##  G1 the Gyrocopter banks: a Gyrocopter at full throttle steering left for a second rolls its drawn body into the turn by more
##     than 5 degrees, and its model's origin stays at the hover height.
## SPLIT moments mine_live and gyro_bank for the frames of a windowed --write-movie run. Tooling only.
## Implements: production/epics/wasteland-fire/story-065-mines.md, story-066-gyro-banks.md.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=mines_gyro_065

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const HEIGHTS: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const ROTORS: bool = true
const BUSHES: bool = true
const FIRE_HEIGHTS: bool = true
const SHIPPED_CAMERA: bool = true
const CHASE_FIRST: bool = true
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const FLAME_TANK: bool = true
const FLAT_DAMAGE: bool = true
const MINES: bool = true
const TEAMS: bool = true
const MINE_LOOKS: bool = true
const GYRO_BANKS: bool = true
const WATCHDOG_SECONDS: float = 120.0
const MOMENT_FRAME_LAG: int = 1
const AHEAD: float = 7.0
const SECOND: int = 60
const LIMIT_TICKS: int = 180
const BANK_LEAST: float = 5.0

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var spot: Vector3 = M2.at(M2.CENTRE.x, M2.CENTRE.y)
	var split: SplitScreen = _m.split
	var settings: MineSettings = (split.player_1_mine_layer.mine_scene.instantiate() as Mine).settings

	# M1
	var problems: PackedStringArray = PackedStringArray()
	await _m.put(1, M2.BUGGY, spot + Vector3(30.0, 0.0, 0.0), Vector3.FORWARD)
	await _m.put(0, M2.BUGGY, spot, Vector3.FORWARD)
	var mine: Mine = split.player_1_mine_layer.mine_scene.instantiate() as Mine
	_m.units[0].get_parent().add_child(mine)
	mine.lay(spot + Vector3.FORWARD * AHEAD, 0, _m.units[0].team_material)
	await _m.kit.advance(int(settings.arming_seconds * 60.0) + 5)
	var shown: Array[bool] = []
	for _tick: int in SECOND:
		await _m.kit.tick()
		if shown.is_empty() or shown[-1] != mine.body.visible:
			shown.append(mine.body.visible)
	print("SPLIT %s t=%.3f frame=%d moment=mine_live" % [_m.h.scenario, _m.h.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG])
	var light: float = mine.body.scale.x
	_m.kit.need(problems, mine.casing != null and mine.casing.visible and is_equal_approx(mine.casing.scale.x, settings.look_radius), "the casing is not drawn at look_radius")
	_m.kit.need(problems, is_equal_approx(light, settings.look_radius * settings.light_share) and settings.look_radius < settings.trigger_radius, "the light's radius %.2f, the look %.2f, the trigger %.2f" % [light, settings.look_radius, settings.trigger_radius])
	_m.kit.need(problems, shown.size() >= 3, "the live light did not blink (%s)" % [shown])
	_m.kit.verdict("M1_the_look", problems, "casing radius %.2f (the trigger %.2f), Team light %.3f; over a live second the light went %s" % [settings.look_radius, settings.trigger_radius, light, shown])

	# M2
	problems = PackedStringArray()
	_m.h.drive(0, 1, 0)
	var destroyed: bool = false
	for _tick: int in LIMIT_TICKS:
		await _m.kit.tick()
		if not _m.units[0].is_alive:
			destroyed = true
			break
	_m.h.drive(0, 0, 0)
	_m.kit.need(problems, not settings.spares_own_team, "spares_own_team is true")
	_m.kit.need(problems, destroyed, "Player 1's Buggy drove over Player 1's live Mine and lived")
	_m.kit.verdict("M2_its_own_team", problems, "Player 1's Buggy over Player 1's live Mine: destroyed %s (spares_own_team %s)" % [destroyed, settings.spares_own_team])
	await _m.kit.advance(SECOND)

	# G1
	problems = PackedStringArray()
	await _m.put(1, M2.GYROCOPTER, spot + Vector3(0.0, 0.0, 20.0), Vector3.FORWARD)
	var model: UnitModel = _m.units[1].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel
	var rest_y: float = model.position.y
	_m.h.drive(1, 1, -1)
	var most_roll: float = 0.0
	var worst_y: float = 0.0
	for _tick: int in SECOND:
		await _m.kit.tick()
		most_roll = maxf(most_roll, absf(rad_to_deg(model.rotation.z)))
		worst_y = maxf(worst_y, absf(model.position.y - rest_y))
	print("SPLIT %s t=%.3f frame=%d moment=gyro_bank roll=%.1f" % [_m.h.scenario, _m.h.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, rad_to_deg(model.rotation.z)])
	_m.h.drive(1, 0, 0)
	_m.kit.need(problems, most_roll > BANK_LEAST, "the Gyrocopter rolled at most %.1f degrees" % most_roll)
	_m.kit.need(problems, worst_y < 0.001, "the model's origin moved %.4f m off its hover height" % worst_y)
	_m.kit.verdict("G1_the_gyrocopter_banks", problems, "a Gyrocopter at full throttle steering left for a second: its body rolled up to %.1f degrees; its model's origin stayed at %.2f m (off by at most %.4f m)" % [most_roll, rest_y, worst_y])
	_m.h.finish("map=map_02")
