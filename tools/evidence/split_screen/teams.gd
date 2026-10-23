extends RefCounted
## Scenario teams of the split screen evidence harness (split_screen_harness.gd): four Players in two Teams (Story 048), on
## Map 01, the lineup Keyboard 1 and pad 0 for Orange, Keyboard 2 and pad 1 for Teal. CHECK lines:
##  T1 the lineup: four Units, Teams [0, 0, 1, 1], all four in play after choosing, Teammates apart in their shared Garage, each Unit in its Team's colour, four views in two columns (Orange left),
##     actions p3_ and p4_ made, Keyboard 2's keys on Player 3 (Up drives p3_throttle) and none on Player 2 or 4.
##  T2 driving: Up moves Player 3's Unit and nobody else's; pad 0's stick moves Player 2's; pad 1's A fires Player 4's Weapon.
##  T3 one Token stock per Team: Player 1's Motorbike destroyed, both Orange Players read 4 Motorbike Tokens, Teal 5.
##  T4 friendly fire: Player 2's Shots leave Player 1 whole, Player 3's (the other Team) hurt it.
##  T5 Mines: a live Mine of Orange leaves an Orange Unit alone and destroys a Teal one.
##  T6 Turrets: each Teal Base Turret is armed with both Orange Units; a Turret armed with two fires at the one in reach.
##  T7 a Teammate's delivery: Player 2 (pad 0) carries Teal's Flag into the Orange Base, Orange wins, and every Round-over
##     screen reads "Orange wins!".
## Implements: production/epics/wasteland-fire/story-048-four-players.md AC-3 to AC-8.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=teams

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const OWN_CHOICE: bool = true
const TEAMS: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const MAP_CHOICE: bool = true
const MINES: bool = true
const TURRETS: bool = true
const BASE_DEFENCES: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const USE_MAP_STOCK: bool = true
const TURRET_LOOKS: bool = true
const LINEUP_DEVICES: Array[int] = [-2, 0, -3, 1]
const LINEUP_TEAMS: Array[int] = [0, 0, 1, 1]
const WATCHDOG_SECONDS: float = 900.0

const ARENA: Vector3 = Vector3(0.0, 0.0, 400.0)
const ARENA_SIZE: float = 400.0
const PAD_1: int = 0
const PAD_2: int = 1
const MOTORBIKE: int = 0
const DRIVE_TICKS: int = 40
const FIRE_TICKS: int = 60
const GAP: float = 6.0
const STILL: float = 0.05
const MINE_SCENE: PackedScene = preload("res://src/gameplay/mines/mine.tscn")
const TURRET_SCENE: PackedScene = preload("res://src/gameplay/defences/turret.tscn")
const MINE_LIVE_TICKS: int = 200
const STURDY_HIT_POINTS: float = 10000.0

var _h: Harness
var _kit: Kit
var _split: SplitScreen
var _controller: MatchController
var _units: Array[Unit] = []
var _pads: PadAssignment


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_split = _h.split
	_controller = _split.match_controller
	_units = _split.all_units()
	_pads = _split.get_node("PadAssignment") as PadAssignment
	_pads.connect_pad(PAD_1)
	_pads.connect_pad(PAD_2)
	_make_floor()
	for player: int in _units.size():
		_controller.choose(player, MOTORBIKE)
	await _kit.advance(10)
	_check_lineup()
	await _check_driving()
	await _check_tokens()
	await _check_friendly_fire()
	await _check_mines()
	await _check_turrets()
	await _check_delivery()
	_h.finish("players=%d" % _units.size())


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	body.add_child(shape)
	_split.get_node("World").add_child(body)
	body.global_position = ARENA + Vector3.DOWN * 0.5


func _put(player: int, at: Vector3, facing: Vector3, sturdy: bool = true) -> void:
	var stats: UnitStats = _controller.unit_types()[MOTORBIKE]
	if sturdy:
		stats = stats.duplicate() as UnitStats
		stats.max_hit_points = STURDY_HIT_POINTS
	_units[player].spawn(Transform3D(Basis(Vector3.UP, atan2(-facing.x, -facing.z)), Vector3(at.x, 0.0, at.z)), stats)
	await _kit.advance(3)


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false


func _key_count(action: StringName) -> int:
	return InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventKey).size()


func _check_lineup() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var teams: Array[int] = []
	var colours: Array[String] = []
	for player: int in _units.size():
		teams.append(_controller.team_of(player))
		colours.append(_units[player].team_material.resource_path.get_file())
	var orange: Node = _split.get_node_or_null("Views/OrangeColumn")
	var teal: Node = _split.get_node_or_null("Views/TealColumn")
	var columns: String = "%s | %s" % [orange.get_children().map(func(n: Node) -> String: return String(n.name)) if orange != null else [], teal.get_children().map(func(n: Node) -> String: return String(n.name)) if teal != null else []]
	var alive: Array[bool] = []
	for player: int in 4:
		alive.append(_controller.is_alive(player))
	var mates_apart: float = minf(_units[0].global_position.distance_to(_units[1].global_position), _units[2].global_position.distance_to(_units[3].global_position))
	_kit.need(problems, alive == [true, true, true, true] and mates_apart > 1.0, "after the four choices alive %s, Teammates %.2f m apart" % [alive, mates_apart])
	var keys: String = "p1_throttle W %s, p3_throttle Up %s, p2 keys %d, p4 keys %d" % [_has_key(&"p1_throttle", KEY_W), _has_key(&"p3_throttle", KEY_UP), _key_count(&"p2_throttle"), _key_count(&"p4_throttle")]
	_kit.need(problems, _units.size() == 4 and teams == [0, 0, 1, 1], "Units %d, Teams %s" % [_units.size(), teams])
	_kit.need(problems, colours[0] == colours[1] and colours[2] == colours[3] and colours[0] != colours[2], "colours %s" % [colours])
	_kit.need(problems, columns == "[\"Player1View\", \"Player2View\"] | [\"Player3View\", \"Player4View\"]", "columns %s" % columns)
	_kit.need(problems, InputMap.has_action(&"p4_fire") and _has_key(&"p1_throttle", KEY_W) and _has_key(&"p3_throttle", KEY_UP) and _key_count(&"p2_throttle") == 0 and _key_count(&"p4_throttle") == 0, keys)
	_kit.verdict("T1_lineup", problems, "Teams %s; all four in play after their choices %s, Teammates at least %.2f m apart in their Garages; colours %s; views %s; %s" % [teams, alive, mates_apart, colours, columns, keys])


func _check_driving() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for player: int in 4:
		await _put(player, ARENA + Vector3(-30.0 + player * 20.0, 0.0, 0.0), Vector3.FORWARD)
	var before: Array[Vector3] = []
	for unit: Unit in _units:
		before.append(unit.global_position)
	_h.set_key(KEY_UP, true)
	await _kit.advance(DRIVE_TICKS)
	_h.set_key(KEY_UP, false)
	var moved: Array[float] = []
	for player: int in 4:
		moved.append(snappedf(_units[player].global_position.distance_to(before[player]), 0.01))
	var start_2: Vector3 = _units[1].global_position
	_axis(PAD_1, JOY_AXIS_LEFT_Y, -1.0)
	await _kit.advance(DRIVE_TICKS)
	_axis(PAD_1, JOY_AXIS_LEFT_Y, 0.0)
	var moved_2: float = _units[1].global_position.distance_to(start_2)
	var weapon_4: Weapon = _split.all_weapons()[3]
	var shots_4: int = weapon_4.shots_left
	_button(PAD_2, JOY_BUTTON_A, true)
	await _kit.advance(20)
	_button(PAD_2, JOY_BUTTON_A, false)
	var fired_4: int = shots_4 - weapon_4.shots_left
	await _kit.advance(30)
	_kit.need(problems, moved[2] > 1.0 and moved[0] < STILL and moved[1] < STILL and moved[3] < STILL, "Up moved %s" % [moved])
	_kit.need(problems, moved_2 > 1.0, "pad 0 moved Player 2 by %.2f m" % moved_2)
	_kit.need(problems, fired_4 > 0, "pad 1's A fired %d Shots" % fired_4)
	_kit.verdict("T2_driving", problems, "Up %d ticks moved the Units %s m; pad 0's stick moved Player 2 %.2f m; pad 1's A fired %d of Player 4's Shots" % [DRIVE_TICKS, moved, moved_2, fired_4])


func _check_tokens() -> void:
	var problems: PackedStringArray = PackedStringArray()
	_units[0].destroy()
	await _kit.advance(5)
	var tokens: Array[int] = []
	for player: int in 4:
		tokens.append(_controller.tokens_left(player, MOTORBIKE))
	_controller.choose(0, MOTORBIKE)
	await _kit.advance(_controller.rules.respawn_delay_seconds * 60 + 20)
	_kit.need(problems, tokens == [4, 4, 5, 5], "Motorbike Tokens %s" % [tokens])
	_kit.verdict("T3_tokens", problems, "after Player 1's Motorbike was destroyed: Motorbike Tokens by Player %s" % [tokens])


func _check_friendly_fire() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var target: Vector3 = ARENA + Vector3(0.0, 0.0, 60.0)
	await _put(0, target, Vector3.FORWARD)
	await _put(1, target + Vector3.BACK * GAP, Vector3.FORWARD)
	await _put(2, target + Vector3(40.0, 0.0, 0.0), Vector3.FORWARD)
	var before: float = _units[0].hit_points
	_button(PAD_1, JOY_BUTTON_A, true)
	await _kit.advance(FIRE_TICKS)
	_button(PAD_1, JOY_BUTTON_A, false)
	await _kit.advance(20)
	var after_mate: float = _units[0].hit_points
	await _put(1, target + Vector3(-40.0, 0.0, 0.0), Vector3.FORWARD)
	await _put(2, target + Vector3.BACK * GAP, Vector3.FORWARD)
	_h.set_key(KEY_PERIOD, true)
	await _kit.advance(FIRE_TICKS)
	_h.set_key(KEY_PERIOD, false)
	await _kit.advance(20)
	var after_enemy: float = _units[0].hit_points
	_kit.need(problems, is_equal_approx(after_mate, before) and after_enemy < before, "Player 1: %.0f, %.0f after its Teammate, %.0f after Player 3" % [before, after_mate, after_enemy])
	_kit.verdict("T4_friendly_fire", problems, "Player 1 at %.0f HP: %.0f after Player 2's Shots (its Team), %.0f after Player 3's (the other Team)" % [before, after_mate, after_enemy])


func _check_mines() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var spot: Vector3 = ARENA + Vector3(0.0, 0.0, -60.0)
	var mine: Mine = MINE_SCENE.instantiate() as Mine
	_split.get_node("World").add_child(mine)
	mine.lay(spot, Lineup.ORANGE, _units[0].team_material)
	await _kit.advance(MINE_LIVE_TICKS)
	await _put(1, spot, Vector3.FORWARD, false)
	await _kit.advance(20)
	var orange_alive: bool = _units[1].is_alive
	await _put(1, spot + Vector3(30.0, 0.0, 0.0), Vector3.FORWARD)
	await _put(3, spot, Vector3.FORWARD, false)
	await _kit.advance(20)
	var teal_alive: bool = _units[3].is_alive
	_kit.need(problems, orange_alive and not teal_alive, "an Orange Mine: Orange Unit alive %s, Teal Unit alive %s" % [orange_alive, teal_alive])
	_kit.verdict("T5_mines", problems, "a live Orange Mine: the Orange Unit on it alive %s, the Teal Unit on it alive %s" % [orange_alive, teal_alive])
	_controller.choose(3, MOTORBIKE)
	await _kit.advance(_controller.rules.respawn_delay_seconds * 60 + 20)


func _check_turrets() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var armed: Array[int] = []
	for structure: Structure in _split.field.player_2_base.structures:
		if structure is Turret:
			armed.append((structure.get("_targets") as Array).size())
	var spot: Vector3 = ARENA + Vector3(80.0, 0.0, 0.0)
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	_split.get_node("World").add_child(turret)
	turret.global_position = spot
	turret.player_index = Lineup.TEAL
	var targets: Array[Unit] = [_units[0], _units[1]]
	turret.arm_targets(targets, _units[0].get_parent(), _controller.rules)
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	await _put(0, spot + Vector3(150.0, 0.0, 0.0), Vector3.FORWARD)
	await _put(1, spot + Vector3.FORWARD * 15.0, Vector3.FORWARD)
	var hp_before: float = _units[1].hit_points
	await _kit.advance(240)
	var hp_after: float = _units[1].hit_points
	turret.queue_free()
	_kit.need(problems, not armed.is_empty() and armed.all(func(n: int) -> bool: return n == 2), "Teal Turrets armed with %s targets" % [armed])
	_kit.need(problems, fired[0] > 0 and hp_after < hp_before, "the Turret fired %d Shots, Player 2 %.0f -> %.0f" % [fired[0], hp_before, hp_after])
	_kit.verdict("T6_turrets", problems, "Teal Base Turrets armed with %s Units each; a Turret armed with Players 1 and 2 (one far, one 15 m off) fired %d Shots, Player 2 %.0f -> %.0f" % [armed, fired[0], hp_before, hp_after])


func _check_delivery() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var flag: Flag = _split.field.player_2_base.flag
	await _put(1, flag.global_position, Vector3.FORWARD)
	await _kit.advance(10)
	var carrying: bool = flag.carrier == _units[1]
	await _put(1, _split.field.player_1_base.zone.global_position, Vector3.FORWARD)
	await _kit.advance(10)
	var over: bool = _controller.is_round_over()
	var winner: int = _controller.winner_index()
	var lines: Array[String] = []
	for node: Node in _split.find_children("*", "", true, false):
		if node is RoundOverScreen:
			lines.append((node.get_node("%WinnerLabel") as Label).text)
	_kit.need(problems, carrying and over and winner == Lineup.ORANGE, "carrying %s, over %s, winner %d" % [carrying, over, winner])
	_kit.need(problems, lines.size() == 4 and lines.all(func(t: String) -> bool: return t == "Orange wins!"), "lines %s" % [lines])
	_kit.verdict("T7_team_delivery", problems, "Player 2 carried Teal's Flag %s; Round over %s, winner Team %d; the four Round-over screens read %s" % [carrying, over, winner, lines])


func _axis(device: int, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _button(device: int, button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
