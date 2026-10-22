extends RefCounted
## Scenario secondary of the split screen evidence harness (split_screen_harness.gd): the secondary weapons on the secondary key
## (Story 042), each recharging in 15 s with its bar, the Motorbike's Flag drop and the bigger Bushes (Story 044). On an
## arena of its own 400 m south of Map 01 (the Flag checks at Map 01's Base 2), with the shipped data. CHECK lines:
##  X1 the Truck: E lays a Mine; E again at once lays none; after the recharge a pad's LT lays one; LT fires no Shot; the
##     count stays full and its line hidden; the bar reads "Mine", empty after a lay, about half way at half the time, full
##     and ready after it.
##  X2 the Buggy's nitro: at top speed, E lifts it to about nitro_speed_share times that and it falls back after; a press while
##     it recharges does nothing; ready again after 15 s; the bar "Boost" full, draining while the nitro runs, filling after.
##  X3 the Gyrocopter's smoke: E drops a cloud about 10 m ahead of it; a Turret 20 m ahead fires at it in the open, not while
##     the cloud hangs between them, and again after the 3 s cloud is gone; a press while it recharges drops nothing; ready
##     after 15 s; a restart frees every cloud; the bar "Smoke".
##  X4 the Motorbike: E with no Flag does nothing and shows no bar; carrying Player 2's Flag the bar reads "Drop flag"; E drops
##     the Flag at its tail (flag_dropped, DROPPED), the Motorbike standing on it does not take it again; once it has been
##     away from it and comes back it does.
##  X5 the Bushes: every Bush of Map 02 is 1.4 times its scene's size (sight radius 2.66 m); a Motorbike inside a Bush draws
##     no Shot from a Turret 15 m off, which fires at it once it drives out.
##     Since Story 045 "Drop flag" is a name with no bar.
##  X6 the data, and the HUD (Story 045): no Tokens line, the bar on the band's second row; Map 01's Fuel zone drawn unshaded in
##     the fuel bar's amber and its ammunition zone in the ammo bar's blue; LT is the secondary key and fires nothing, X is free; nitro 2 s x 1.6 and 15 s; smoke 15 s, 12 m, 3 s, 10 m
##     ahead; Mines 15 s; the Turret's sight holds the smoke layer (416, 256).
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-1 to AC-6,
## story-044-secondaries-recharge.md AC-1 to AC-6, story-045-hud-and-zone-colours.md AC-1 and AC-2.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=secondary

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const MINES: bool = true
const TURRET_LOOKS: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const USE_MAP_STOCK: bool = true
const BUSHES: bool = true
const MAP_CHOICE: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const WATCHDOG_SECONDS: float = 900.0

const ARENA: Vector3 = Vector3(0.0, 0.0, 400.0)
const ARENA_SIZE: float = 400.0
const PAD_1: int = 0
const KEY_SECONDARY_1: Key = KEY_E
const TICKS: int = 60
const RECHARGE_TICKS: int = 15 * TICKS
const RUN_UP_TICKS: int = 150
const NITRO_SAMPLE_TICKS: int = 90
const TURRET_GAP: float = 20.0
const WATCH_TICKS: int = 120
const CLOUD_TICKS: int = 3 * TICKS
const SPEED_SHARE_LOW: float = 1.4
const TOLERANCE: float = 0.05
const TURRET_SCENE: PackedScene = preload("res://src/gameplay/defences/turret.tscn")
const BUSH_SCENE: PackedScene = preload("res://src/gameplay/cover/bush.tscn")
const MAP_02_SCENE: PackedScene = preload("res://src/gameplay/maps/map_02/map_02.tscn")
const NAMES: Array[String] = ["Mine", "Boost", "Smoke", "Drop flag"]
## Where each check runs, apart, so a Mine of X1 lies under nobody else.
const NITRO_SPOT: Vector3 = ARENA + Vector3(60.0, 0.0, 0.0)
const SMOKE_SPOT: Vector3 = ARENA + Vector3(-60.0, 0.0, 0.0)
const BUSH_SPOT: Vector3 = ARENA + Vector3(0.0, 0.0, 80.0)
const BUSH_GAP: float = 15.0
const OUT_OF_BUSH: float = 8.0
const STURDY_HIT_POINTS: float = 10000.0
const BUSH_SIZE: float = 1.4
const BUSH_SIGHT_RADIUS: float = 1.9
const CLOUD_AHEAD: float = 10.0
const FLAG_AWAY: float = 12.0
## Where the bar stands since Story 045: the HUD band's second row, the Tokens line's place.
const STATUS_TOP: float = 47.0

var _m: M2
var _status: SecondaryStatus


func run(harness: Node) -> void:
	_m = M2.new(harness)
	_status = _m.split.get_node("Views/Player1View/SubViewport/Player1SecondaryStatus") as SecondaryStatus
	_make_floor()
	await _m.park(1)
	await _check_truck()
	await _check_nitro()
	await _check_smoke()
	await _check_flag_drop()
	await _check_bushes()
	_check_data()
	_m.h.finish("arena=1")


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	body.add_child(shape)
	_m.split.get_node("World").add_child(body)
	body.global_position = ARENA + Vector3.DOWN * 0.5


func _press(key: Key) -> void:
	_m.h.set_key(key, true)
	await _m.kit.advance(2)
	_m.h.set_key(key, false)
	await _m.kit.advance(2)


## The bar's name and value now, as "Name 0.50" (empty when hidden).
func _bar() -> String:
	await _m.h.get_tree().process_frame
	return "" if _status.shown_name().is_empty() else "%s %.2f" % [_status.shown_name(), _status.shown_charge()]


func _mines_on_field() -> int:
	var count: int = 0
	for node: Node in _m.split.get_node("World").find_children("*", "", true, false):
		if node is Mine and not node.is_queued_for_deletion():
			count += 1
	return count


func _sturdy(type_index: int) -> UnitStats:
	var copy: UnitStats = _m.stats(type_index).duplicate() as UnitStats
	copy.max_hit_points = STURDY_HIT_POINTS
	return copy


func _check_truck() -> void:
	var problems: PackedStringArray = PackedStringArray()
	_m.units[0].leave_play()
	await _m.kit.advance(2)
	await _m.put(0, M2.TRUCK, ARENA, Vector3.FORWARD)
	var layer: MineLayer = _m.split.player_1_mine_layer
	var bars: PackedStringArray = PackedStringArray([await _bar()])
	var laid: Array[int] = [_mines_on_field()]
	await _press(KEY_SECONDARY_1)
	laid.append(_mines_on_field())
	bars.append(await _bar())
	await _m.drive_for(0, 1, 0, 30)
	await _press(KEY_SECONDARY_1)
	laid.append(_mines_on_field())
	await _m.kit.advance(RECHARGE_TICKS / 2 - 40)
	bars.append(await _bar())
	await _m.kit.advance(RECHARGE_TICKS / 2)
	bars.append(await _bar())
	# Away from the first Mines, so the next lands on open ground.
	await _m.drive_for(0, 1, 0, 90)
	var pads: PadAssignment = _m.split.get_node("PadAssignment") as PadAssignment
	pads.connect_pad(PAD_1)
	var shots_before: int = _m.split.player_1_weapon.shots_left
	for value: float in [1.0, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.device = PAD_1
		motion.axis = JOY_AXIS_TRIGGER_LEFT
		motion.axis_value = value
		Input.parse_input_event(motion)
		await _m.kit.advance(3)
	laid.append(_mines_on_field())
	var lt_shots: int = shots_before - _m.split.player_1_weapon.shots_left
	pads.disconnect_pad(PAD_1)
	var line_shown: bool = false
	for node: Node in _m.split.get_node("Views/Player1View/SubViewport").find_children("*", "", true, false):
		if node is MineCount and (node as MineCount).visible:
			line_shown = true
	_m.kit.need(problems, laid == [0, 1, 1, 2], "Mines on the field %s" % [laid])
	_m.kit.need(problems, layer.mines_left == layer.capacity and layer.recharges(), "mines_left %d of %d, recharges %s" % [layer.mines_left, layer.capacity, layer.recharges()])
	_m.kit.need(problems, lt_shots == 0 and not line_shown, "LT fired %d Shots; the Mines line shows %s" % [lt_shots, line_shown])
	_m.kit.need(problems, bars[0] == "Mine 1.00" and bars[1] == "Mine 0.00" and absf(float(bars[2].get_slice(" ", 1)) - 0.5) < 0.1 and bars[3] == "Mine 1.00", "bars %s" % [bars])
	_m.kit.verdict("X1_truck", problems, "Mines on the field %s (E, E at once, LT after the recharge); count %d of %d; LT fired %d Shots; Mines line shown %s; bars %s" % [
		laid, layer.mines_left, layer.capacity, lt_shots, line_shown, bars])


func _speed() -> float:
	var unit: Unit = _m.units[0]
	return Vector2(unit.velocity.x, unit.velocity.z).length()


func _check_nitro() -> void:
	var problems: PackedStringArray = PackedStringArray()
	await _m.put(0, M2.BUGGY, NITRO_SPOT, Vector3.FORWARD)
	var bars: PackedStringArray = PackedStringArray([await _bar()])
	_m.h.drive(0, 1, 0)
	await _m.kit.advance(RUN_UP_TICKS)
	var top: float = _speed()
	_m.h.set_key(KEY_SECONDARY_1, true)
	await _m.kit.advance(2)
	_m.h.set_key(KEY_SECONDARY_1, false)
	var fastest: float = 0.0
	for tick: int in NITRO_SAMPLE_TICKS:
		await _m.kit.tick()
		fastest = maxf(fastest, _speed())
		if tick == TICKS / 2:
			bars.append(await _bar())
	await _m.kit.advance(RUN_UP_TICKS)
	var after: float = _speed()
	bars.append(await _bar())
	await _press(KEY_SECONDARY_1)
	var cooling_press: float = 0.0
	for _tick: int in NITRO_SAMPLE_TICKS:
		await _m.kit.tick()
		cooling_press = maxf(cooling_press, _speed())
	# The recharge starts when the nitro ends, 2 s after the press.
	await _m.kit.advance(RECHARGE_TICKS - RUN_UP_TICKS - NITRO_SAMPLE_TICKS + 2 * TICKS)
	var booster: NitroBooster = _m.split.get_node("World/Player1NitroBooster") as NitroBooster
	var ready_again: bool = booster.state() == NitroBooster.State.READY
	bars.append(await _bar())
	_m.h.drive(0, 0, 0)
	var share: float = _m.stats(M2.BUGGY).nitro_speed_share
	_m.kit.need(problems, fastest > top * SPEED_SHARE_LOW and fastest <= top * share + 0.01, "nitro: top %.2f m/s, fastest %.2f m/s (share %.2f)" % [top, fastest, share])
	_m.kit.need(problems, absf(after - top) < TOLERANCE and cooling_press <= top + TOLERANCE, "after %.2f, a press while recharging %.2f, before %.2f" % [after, cooling_press, top])
	_m.kit.need(problems, ready_again, "the nitro is not ready 15 s on")
	var draining: float = float(bars[1].get_slice(" ", 1)) if bars.size() > 1 else -1.0
	var filling: float = float(bars[2].get_slice(" ", 1)) if bars.size() > 2 else -1.0
	_m.kit.need(problems, bars[0] == "Boost 1.00" and bars[1].begins_with("Boost") and draining > 0.6 and draining < 0.9 and filling > 0.0 and filling < 0.3 and bars[3] == "Boost 1.00", "bars %s" % [bars])
	_m.kit.verdict("X2_nitro", problems, "Buggy top %.2f m/s, with nitro %.2f, after %.2f, a press while recharging %.2f, ready 15 s on %s; bars %s" % [
		top, fastest, after, cooling_press, ready_again, bars])


func _clouds() -> Array[Node]:
	return _m.h.get_tree().get_nodes_in_group(&"smokes")


func _check_smoke() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	_m.split.get_node("World").add_child(turret)
	turret.global_position = SMOKE_SPOT + Vector3.FORWARD * TURRET_GAP
	turret.player_index = 1
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	await _m.put(0, M2.GYROCOPTER, SMOKE_SPOT, Vector3.FORWARD, _sturdy(M2.GYROCOPTER))
	var bars: PackedStringArray = PackedStringArray([await _bar()])
	turret.arm(_m.units[0], _m.units[0].get_parent(), _m.controller.rules)
	await _m.kit.advance(2 * WATCH_TICKS)
	var open_shots: int = fired[0]
	await _press(KEY_SECONDARY_1)
	var dropped: Array[Node] = _clouds()
	var ahead: float = -1.0
	if dropped.size() == 1:
		var cloud: Node3D = dropped[0] as Node3D
		ahead = (cloud.global_position - _m.units[0].global_position).dot(-_m.units[0].global_transform.basis.z)
	bars.append(await _bar())
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var smoked_shots: int = fired[0]
	await _m.kit.advance(CLOUD_TICKS)
	var gone: int = _clouds().size()
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var after_shots: int = fired[0]
	turret.queue_free()
	await _press(KEY_SECONDARY_1)
	var while_recharging: int = _clouds().size()
	await _m.kit.advance(RECHARGE_TICKS - 2 * WATCH_TICKS - CLOUD_TICKS)
	bars.append(await _bar())
	await _press(KEY_SECONDARY_1)
	var again: int = _clouds().size()
	_m.controller.round_started.emit()
	await _m.kit.advance(2)
	var after_restart: int = _clouds().size()
	await _m.park(0)
	_m.kit.need(problems, dropped.size() == 1 and absf(ahead - CLOUD_AHEAD) < 0.5, "%d clouds, %.2f m ahead" % [dropped.size(), ahead])
	_m.kit.need(problems, open_shots > 0 and smoked_shots == 0 and gone == 0 and after_shots > 0, "Shots %d open, %d smoked, %d after (%d clouds left)" % [open_shots, smoked_shots, after_shots, gone])
	_m.kit.need(problems, while_recharging == 0 and again == 1 and after_restart == 0, "%d clouds from a press while recharging, %d when ready again, %d after the restart" % [while_recharging, again, after_restart])
	_m.kit.need(problems, bars[0] == "Smoke 1.00" and bars[1] == "Smoke 0.00" and bars[2] == "Smoke 1.00", "bars %s" % [bars])
	_m.kit.verdict("X3_smoke", problems, "cloud %.2f m ahead; Turret 20 m ahead: %d Shots in the open, %d while the cloud hung, %d after it was gone; clouds: %d from a press while recharging, %d when ready, %d after the restart; bars %s" % [
		ahead, open_shots, smoked_shots, after_shots, while_recharging, again, after_restart, bars])


func _check_flag_drop() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var flag: Flag = _m.field.player_2_base.flag
	var dropped: Array[int] = []
	_m.controller.flag_dropped.connect(func(index: int) -> void: dropped.append(index))
	await _m.put(0, M2.MOTORBIKE, ARENA + Vector3(-20.0, 0.0, 40.0), Vector3.FORWARD, _sturdy(M2.MOTORBIKE))
	var empty_bar: String = await _bar()
	await _press(KEY_SECONDARY_1)
	var empty_drops: int = dropped.size()
	# The Flag stands boxed in by its Flag Walls: the Motorbike is put down on it.
	var home: Vector3 = flag.global_position
	await _m.put(0, M2.MOTORBIKE, home, Vector3.FORWARD, _sturdy(M2.MOTORBIKE))
	var picked: int = await _wait_until(func() -> bool: return flag.state == Flag.State.CARRIED)
	await _m.kit.advance(30)
	var carry_bar: String = await _bar()
	var drop_has_bar: bool = _status.bar.visible
	await _press(KEY_SECONDARY_1)
	var state_after: String = String(Flag.State.keys()[flag.state])
	var drop_gap: float = flag.global_position.distance_to(_m.units[0].global_position)
	await _m.kit.advance(30)
	var still_dropped: bool = flag.state == Flag.State.DROPPED
	var after_bar: String = await _bar()
	# Away from it for a moment, then back on it.
	var lying: Vector3 = flag.global_position
	await _m.put(0, M2.MOTORBIKE, home + Vector3.RIGHT * FLAG_AWAY, Vector3.FORWARD, _sturdy(M2.MOTORBIKE))
	await _m.kit.advance(10)
	await _m.put(0, M2.MOTORBIKE, lying, Vector3.FORWARD, _sturdy(M2.MOTORBIKE))
	var repicked: int = await _wait_until(func() -> bool: return flag.state == Flag.State.CARRIED)
	await _m.park(0)
	_m.kit.need(problems, empty_bar.is_empty() and empty_drops == 0, "no Flag: bar '%s', %d drops" % [empty_bar, empty_drops])
	_m.kit.need(problems, picked > 0 and carry_bar == "Drop flag 1.00" and not drop_has_bar, "picked up after %d ticks, bar '%s', a bar drawn %s" % [picked, carry_bar, drop_has_bar])
	_m.kit.need(problems, dropped == [1] and state_after == "DROPPED" and still_dropped and after_bar.is_empty(), "drops %s, state %s, still dropped %s, bar '%s'" % [dropped, state_after, still_dropped, after_bar])
	_m.kit.need(problems, repicked > 0, "not picked up again after being away (%d)" % repicked)
	_m.kit.verdict("X4_flag_drop", problems, "no Flag: bar '%s', %d drops; picked up after %d ticks, name '%s' (a bar drawn %s); E: flag_dropped %s, %s %.2f m from the Motorbike, still dropped 0.5 s on %s, bar '%s'; picked up again after being away: %d ticks" % [
		empty_bar, empty_drops, picked, carry_bar, drop_has_bar, dropped, state_after, drop_gap, still_dropped, after_bar, repicked])


func _wait_until(done: Callable) -> int:
	for count: int in range(1, 121):
		await _m.kit.tick()
		if done.call():
			return count
	return -1


func _check_bushes() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var map_02: Node = MAP_02_SCENE.instantiate()
	var sizes: Array[float] = []
	for node: Node in map_02.find_children("*", "", true, false):
		if node is Bush and not sizes.has((node as Bush).size):
			sizes.append((node as Bush).size)
	map_02.free()
	var bush: Bush = BUSH_SCENE.instantiate() as Bush
	_m.split.get_node("World").add_child(bush)
	bush.global_position = BUSH_SPOT
	var radius: float = ((bush.sight_body.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius
	var turret: Turret = TURRET_SCENE.instantiate() as Turret
	_m.split.get_node("World").add_child(turret)
	turret.global_position = BUSH_SPOT + Vector3.FORWARD * BUSH_GAP
	turret.player_index = 1
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	await _m.put(0, M2.MOTORBIKE, BUSH_SPOT + Vector3.BACK * 0.5, Vector3.RIGHT, _sturdy(M2.MOTORBIKE))
	turret.arm(_m.units[0], _m.units[0].get_parent(), _m.controller.rules)
	await _m.kit.advance(WATCH_TICKS)
	var hidden_shots: int = fired[0]
	var standing: bool = bush.is_standing
	await _m.put(0, M2.MOTORBIKE, BUSH_SPOT + Vector3.RIGHT * OUT_OF_BUSH, Vector3.RIGHT, _sturdy(M2.MOTORBIKE))
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var open_shots: int = fired[0]
	turret.queue_free()
	bush.queue_free()
	await _m.park(0)
	_m.kit.need(problems, sizes == [BUSH_SIZE] and is_equal_approx(radius, BUSH_SIGHT_RADIUS * BUSH_SIZE), "Map 02's Bush sizes %s, a sight radius of %.2f m" % [sizes, radius])
	_m.kit.need(problems, standing and hidden_shots == 0 and open_shots > 0, "in the Bush %d Shots (standing %s), out of it %d" % [hidden_shots, standing, open_shots])
	_m.kit.verdict("X5_bushes", problems, "Map 02's Bushes all %s times their scene, sight radius %.2f m; a Motorbike in a Bush 15 m from a Turret: %d Shots, the Bush standing %s; 8 m out of it: %d Shots" % [
		sizes, radius, hidden_shots, standing, open_shots])


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var layout: PadLayout = load("res://src/gameplay/input/data/pad_layout.tres") as PadLayout
	var lt: Array[String] = []
	var x_bound: bool = false
	for binding: PadBinding in layout.bindings:
		if binding.kind == PadBinding.Kind.AXIS and binding.axis == JOY_AXIS_TRIGGER_LEFT:
			lt.append(String(binding.action_suffix))
		if binding.kind == PadBinding.Kind.BUTTON and binding.button == JOY_BUTTON_X:
			x_bound = true
	var buggy: UnitStats = _m.stats(M2.BUGGY)
	var gyro: UnitStats = _m.stats(M2.GYROCOPTER)
	var truck: UnitStats = _m.stats(M2.TRUCK)
	var smoke: SmokeSettings = load("res://src/gameplay/secondary/data/smoke_settings.tres") as SmokeSettings
	var turret: TurretStats = load("res://src/gameplay/defences/data/turret_stats.tres") as TurretStats
	_m.kit.need(problems, lt == ["lay_mine"] and not x_bound, "LT is bound to %s, X bound %s" % [lt, x_bound])
	_m.kit.need(problems, is_equal_approx(buggy.nitro_seconds, 2.0) and is_equal_approx(buggy.nitro_speed_share, 1.6) and is_equal_approx(buggy.nitro_cooldown_seconds, 15.0), "nitro %.1f s x %.2f, %.1f s" % [buggy.nitro_seconds, buggy.nitro_speed_share, buggy.nitro_cooldown_seconds])
	_m.kit.need(problems, is_equal_approx(gyro.smoke_cooldown_seconds, 15.0) and is_equal_approx(smoke.radius, 12.0) and is_equal_approx(smoke.seconds, 3.0) and is_equal_approx(smoke.ahead, CLOUD_AHEAD), "smoke %.1f s, %.1f m, %.1f s, %.1f m ahead" % [gyro.smoke_cooldown_seconds, smoke.radius, smoke.seconds, smoke.ahead])
	_m.kit.need(problems, is_equal_approx(truck.mine_cooldown_seconds, 15.0), "Mines %.1f s" % truck.mine_cooldown_seconds)
	var huds: Array[PlayerHud] = [_m.split.get_node("Views/Player1View/SubViewport/Player1Hud") as PlayerHud, _m.split.get_node("Views/Player2View/SubViewport/Player2Hud") as PlayerHud]
	var tokens_shown: bool = false
	for hud: PlayerHud in huds:
		tokens_shown = tokens_shown or (hud.get_node("%TokensLabel") as Label).visible or hud.show_tokens_line
	var status_top: float = _status.position.y
	var colours: Array[String] = []
	var zone_ok: bool = true
	for pair: Array in [["Depot/FuelZoneWest", "%FuelBar"], ["AmmoBuildingWest/AmmoZone", "%AmmoBar"]]:
		var zone: SupplyZone = _m.split.field.get_node(String(pair[0])) as SupplyZone
		var material: StandardMaterial3D = (zone.slab as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		var bar_colour: Color = (huds[0].get_node(String(pair[1])).get_theme_stylebox("fill") as StyleBoxFlat).bg_color
		zone_ok = zone_ok and material.albedo_color.is_equal_approx(bar_colour) and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		colours.append("%s %s (bar %s)" % [pair[0], material.albedo_color.to_html(false), bar_colour.to_html(false)])
	_m.kit.need(problems, zone_ok, "zones %s" % [colours])
	_m.kit.need(problems, not tokens_shown and is_equal_approx(status_top, STATUS_TOP), "the Tokens line shows %s; the bar at y %.0f" % [tokens_shown, status_top])
	_m.kit.need(problems, turret.sight_extra_mask == 416 and turret.flying_sight_extra_mask == 256, "Turret sight %d / %d" % [turret.sight_extra_mask, turret.flying_sight_extra_mask])
	_m.kit.verdict("X6_data", problems, "the Tokens line shown %s, the bar at y %.0f (its row); zones unshaded in their bars' colours: %s; LT %s, X bound %s; nitro %.1f s x %.2f, %.1f s; smoke %.1f s, %.0f m, %.1f s, %.0f m ahead; Mines %.1f s; Turret sight %d / %d" % [
		tokens_shown, status_top, ", ".join(colours), lt, x_bound, buggy.nitro_seconds, buggy.nitro_speed_share, buggy.nitro_cooldown_seconds, gyro.smoke_cooldown_seconds, smoke.radius, smoke.seconds, smoke.ahead,
		truck.mine_cooldown_seconds, turret.sight_extra_mask, turret.flying_sight_extra_mask])
