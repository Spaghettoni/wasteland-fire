extends RefCounted
## Scenario camera_views of the split screen evidence harness (split_screen_harness.gd): the view
## from above and the key that switches it (Story 010 AC-1 to AC-5), on Map 01 with the build's
## own cameras (SHIPPED_CAMERA), every key a real event. Eight CHECK lines, every number measured:
##  T1 the pose: at the Round's start each camera stands where its settings put it, looks 75 degrees
##     below the horizon at a point 26 m away and 4 m ahead of its Unit, the numbers of AC-1.
##  T2 the view: the Unit's whole footprint is inside its 640 x 720 view and the view shows more
##     ground ahead of the Unit than behind it; the camera's heading is the Unit's heading.
##  T3 the turn: after the Unit turns on the spot the camera's heading follows it (AC-1).
##  T4 the snap: at the Round's start, after a respawn and after a restart (a loss, then R) the
##     camera is at its place with no lag (AC-2).
##  T5 the guard: a view straight down (pitch 90) raises no engine error and is oriented by the
##     followed frame, the Unit's with follow_rotation and the world's without it (AC-2).
##  T6 the switch: Q switches Player 1, / Player 2, one press one step, a held key one step, the
##     other Player unchanged, the camera glides (no snap), a Player's choice stays through a
##     restart, and a Round starts in the view from above (AC-4).
##  T7 the data: the settings are the .tres values, the lists are in the scene, the keys are in the
##     Input Map, the driving toy keeps the chase camera (AC-5).
##  T8 the towers: the tower top is on its own render layer, the view from above does not draw it
##     and the chase view does, and from every heading a Unit has at the Flag seat nothing drawn
##     stands between the camera and the Flag or the Unit; with the layer drawn (a copy of the
##     settings that hides nothing) the tank does stand there, so the check can fail (AC-3).
##  T9 the screen: every Control of both views is where it was, whichever view the camera is in.
## Implements: production/epics/wasteland-fire/story-010-camera-from-above.md AC-1 to AC-5, AC-3.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=camera_views

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): choices, Self-destructs, the restart, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## This scenario runs on the camera the build ships with, the view from above.
const SHIPPED_CAMERA: bool = true
## The Motorbike Tokens each Player starts with: two, so the second Self-destruct is the loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 2, &"buggy": 3, &"truck": 2, &"gyrocopter": 2}

## AC-1's starting values: the angle below the horizon, degrees.
const AC_PITCH: float = 75.0
## AC-1's starting distance from the look point, metres.
const AC_DISTANCE: float = 26.0
## AC-1's starting look point ahead of the Unit, metres.
const AC_LOOK_AHEAD: float = 4.0
## Player 1's camera key and Player 2's (project.godot: p1_camera, p2_camera).
const KEYS_CAMERA: Array[Key] = [KEY_Q, KEY_SLASH]
## Player 1's steer-left key: turns a standing Unit.
const KEY_STEER_LEFT_1: Key = KEY_A
## Where a camera is at its place, metres.
const PLACE_TOLERANCE: float = 0.05
## An angle measured from a camera, degrees.
const ANGLE_TOLERANCE: float = 0.1
## How far a camera's aim may be from its look point, degrees (a centimetre in 15 m is 0.04).
const AIM_TOLERANCE: float = 0.01
## A camera's heading against its Unit's, degrees.
const HEADING_TOLERANCE: float = 1.0
## Ticks a camera needs to settle at its place (its sharpness 8 per second leaves e^-8 of a gap
## after one second).
const SETTLE_TICKS: int = 90
## Ticks the steer key is held for the turn on the spot (about 1.4 rad/s for the Motorbike).
const TURN_TICKS: int = 60
## The most of its gap a camera may have crossed two ticks after the key: a glide, not a snap.
const GLIDE_MAX_FRACTION: float = 0.6
## Ticks a key is held down to see that it steps once.
const HOLD_TICKS: int = 45
## The headings tried at each Flag seat: this many, a whole turn apart in equal steps.
const HEADINGS: int = 4
## The view from above, as the shipped scene names it.
const ABOVE_PATH: String = "res://src/gameplay/camera/data/above_camera_settings.tres"

var _h: Harness
var _kit: Kit
var _tk: Tokens
var _cameras: Array[ChaseCamera] = []
var _units: Array[Unit] = []
var _above: ChaseCameraSettings
var _chase: ChaseCameraSettings


## Runs the nine checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_cameras = _tk.units.cameras
	_units = _tk.units.units
	_above = _cameras[0].settings
	_chase = Harness.CHASE_CAMERA_SETTINGS
	await _kit.advance(Kit.START_TICKS)
	_t1_pose()
	_t2_view()
	await _t3_turn()
	await _t5_guard()
	await _t6_switch()
	await _t8_towers()
	_t9_screen()
	_t7_data()
	await _t4_snap()
	var errors: int = _tk.engine_log.errors.size()
	var warnings: int = _tk.engine_log.warnings.size()
	_tk.close()
	_h.finish("errors=%d warnings=%d" % [errors, warnings])


## T1: where each camera stands and looks at the Round's start (AC-1).
func _t1_pose() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var camera: ChaseCamera = _cameras[player]
		var unit: Unit = _units[player]
		var settings: ChaseCameraSettings = camera.settings
		var forward: Vector3 = -camera.global_basis.z
		var pitch: float = rad_to_deg(asin(-forward.y))
		var ahead: Vector3 = _heading(unit.global_basis) * AC_LOOK_AHEAD
		var focus: Vector3 = unit.global_position + Vector3.UP * settings.look_height + ahead
		var distance: float = camera.global_position.distance_to(focus)
		var aim: float = rad_to_deg(forward.angle_to((focus - camera.global_position).normalized()))
		var error: float = camera.global_position.distance_to(_place(unit, settings))
		var local: Vector3 = unit.global_transform.affine_inverse() * camera.global_position
		reads.append("p%d pitch=%.3f distance=%.3f aim_error=%.5fdeg error=%.4f local=(%.2f, %.2f, %.2f)" % [player + 1, pitch, distance, aim, error, local.x, local.y, local.z])
		_kit.need(problems, settings.resource_path == ABOVE_PATH, "p%d does not start in the view from above" % [player + 1])
		_kit.need(problems, absf(pitch - AC_PITCH) <= ANGLE_TOLERANCE, "p%d looks %.3f degrees below the horizon, not %.1f" % [player + 1, pitch, AC_PITCH])
		_kit.need(problems, absf(distance - AC_DISTANCE) <= PLACE_TOLERANCE, "p%d stands %.3f m from the look point, not %.1f" % [player + 1, distance, AC_DISTANCE])
		_kit.need(problems, aim <= AIM_TOLERANCE, "p%d does not look at the look point (%.5f degrees off)" % [player + 1, aim])
		_kit.need(problems, error <= PLACE_TOLERANCE, "p%d is %.3f m from the place its settings give" % [player + 1, error])
	_kit.verdict("T1_above_pose", problems, " | ".join(reads))


## T2: the Unit's footprint is in its view, more ground shows ahead than behind (AC-1).
func _t2_view() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var camera: ChaseCamera = _cameras[player]
		var unit: Unit = _units[player]
		var rect: Rect2 = camera.get_viewport().get_visible_rect()
		var size: Vector3 = unit.stats.collision_size
		var worst_margin: float = INF
		for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
			var point: Vector3 = unit.global_transform * (corner * size * 0.5)
			var on_screen: Vector2 = camera.unproject_position(point)
			worst_margin = minf(worst_margin, minf(minf(on_screen.x - rect.position.x, rect.end.x - on_screen.x), minf(on_screen.y - rect.position.y, rect.end.y - on_screen.y)))
			_kit.need(problems, not camera.is_position_behind(point), "p%d: a corner of the Unit is behind the camera" % [player + 1])
		var heading: Vector3 = _heading(unit.global_basis)
		var plane: Plane = Plane(Vector3.UP, 0.0)
		var top: Variant = plane.intersects_ray(camera.project_ray_origin(Vector2(rect.size.x * 0.5, 0.0)), camera.project_ray_normal(Vector2(rect.size.x * 0.5, 0.0)))
		var bottom: Variant = plane.intersects_ray(camera.project_ray_origin(Vector2(rect.size.x * 0.5, rect.size.y)), camera.project_ray_normal(Vector2(rect.size.x * 0.5, rect.size.y)))
		var ahead: float = (top - unit.global_position).dot(heading) if top != null else INF
		var behind: float = -(bottom - unit.global_position).dot(heading) if bottom != null else INF
		var camera_heading: Vector3 = _heading(camera.global_basis)
		var turned: float = rad_to_deg(camera_heading.angle_to(heading))
		reads.append("p%d view=%dx%d footprint_margin=%.1fpx ground_ahead=%.1fm ground_behind=%.1fm heading_error=%.3fdeg" % [player + 1, rect.size.x, rect.size.y, worst_margin, ahead, behind, turned])
		_kit.need(problems, rect.size == Vector2(640.0, 720.0), "p%d's view is %s, not 640 x 720" % [player + 1, rect.size])
		_kit.need(problems, worst_margin > 0.0, "p%d: the Unit's footprint leaves the view (margin %.1f px)" % [player + 1, worst_margin])
		_kit.need(problems, ahead > behind, "p%d sees %.1f m ahead and %.1f m behind" % [player + 1, ahead, behind])
		_kit.need(problems, turned <= HEADING_TOLERANCE, "p%d's camera heading is %.2f degrees off its Unit's" % [player + 1, turned])
	_kit.verdict("T2_unit_in_view", problems, " | ".join(reads))


## T3: Player 1's Unit turns on the spot, and the camera's heading turns with it (AC-1).
func _t3_turn() -> void:
	var before: float = _yaw_of(_units[0])
	_h.set_key(KEY_STEER_LEFT_1, true)
	await _kit.advance(TURN_TICKS)
	_h.set_key(KEY_STEER_LEFT_1, false)
	await _kit.advance(SETTLE_TICKS)
	var turned: float = rad_to_deg(angle_difference(before, _yaw_of(_units[0])))
	var error: float = rad_to_deg(_heading(_cameras[0].global_basis).angle_to(_heading(_units[0].global_basis)))
	var error_2: float = rad_to_deg(_heading(_cameras[1].global_basis).angle_to(_heading(_units[1].global_basis)))
	var problems: PackedStringArray = []
	_kit.need(problems, absf(turned) > 30.0, "the Unit turned only %.1f degrees" % turned)
	_kit.need(problems, error <= HEADING_TOLERANCE, "p1's camera heading is %.2f degrees off after the turn" % error)
	_kit.need(problems, error_2 <= HEADING_TOLERANCE, "p2's camera heading moved %.2f degrees while p2 stood still" % error_2)
	_kit.verdict("T3_turns_with_unit", problems, "p1 turned %.1f degrees, camera heading error %.3f degrees; p2 stood: %.3f degrees" % [turned, error, error_2])


## T5: a view straight down raises no engine error and is oriented by the followed frame (AC-2).
func _t5_guard() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var camera: ChaseCamera = _cameras[0]
	var unit: Unit = _units[0]
	var errors: int = _tk.engine_log.errors.size()
	for follows: bool in [true, false]:
		var straight: ChaseCameraSettings = _above.duplicate() as ChaseCameraSettings
		straight.pitch_degrees = 90.0
		straight.follow_rotation = follows
		camera.settings = straight
		camera.snap_to_target()
		await _kit.advance(3)
		var basis: Basis = camera.global_basis
		var screen_up: Vector3 = basis.y
		var want: Vector3 = -unit.global_basis.z if follows else Vector3(0.0, 0.0, -1.0)
		reads.append("follow_rotation=%s down=%.5f up_vs_frame=%.5f det=%.5f" % [follows, -(-basis.z).y, screen_up.dot(want), basis.determinant()])
		_kit.need(problems, basis.is_finite() and absf(basis.determinant() - 1.0) < 0.0001, "follow_rotation %s: the basis is not a rotation" % follows)
		_kit.need(problems, (-basis.z).y < -0.9999, "follow_rotation %s: the camera does not look straight down" % follows)
		_kit.need(problems, screen_up.dot(want) > 0.9999, "follow_rotation %s: the top of the screen is not the followed frame's forward" % follows)
	camera.settings = _above
	camera.snap_to_target()
	await _kit.advance(3)
	_kit.need(problems, _tk.engine_log.errors.size() == errors, "the straight-down views raised %d engine errors" % (_tk.engine_log.errors.size() - errors))
	_kit.verdict("T5_straight_down_guard", problems, " | ".join(reads))


## T6: the keys, one step each, a glide, the other Player unchanged (AC-4).
func _t6_switch() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var before_1: ChaseCameraSettings = _cameras[0].settings
	var before_2: ChaseCameraSettings = _cameras[1].settings
	_kit.need(problems, before_1 == _above and before_2 == _above, "the Round does not start in the view from above")
	var gap: float = _cameras[0].global_position.distance_to(_place(_units[0], _chase))
	await _kit.press_settled([KEYS_CAMERA[0]] as Array[Key])
	var crossed: float = 1.0 - _cameras[0].global_position.distance_to(_place(_units[0], _chase)) / gap
	reads.append("q: p1 %s p2 %s, two ticks later p1 had crossed %.2f of a %.1f m gap" % [_name_of(_cameras[0].settings), _name_of(_cameras[1].settings), crossed, gap])
	_kit.need(problems, _cameras[0].settings == _chase, "Q did not switch Player 1 to the chase view")
	_kit.need(problems, _cameras[1].settings == before_2, "Q changed Player 2's view")
	_kit.need(problems, crossed > 0.0 and crossed < GLIDE_MAX_FRACTION, "the camera crossed %.2f of the gap in two ticks: a snap or no move" % crossed)
	await _kit.advance(SETTLE_TICKS)
	var settled: float = _cameras[0].global_position.distance_to(_place(_units[0], _chase))
	reads.append("settled %.4f m from the chase place" % settled)
	_kit.need(problems, settled <= PLACE_TOLERANCE, "the camera settled %.3f m from the chase place" % settled)
	var chase_focus: Vector3 = _units[0].global_position + Vector3.UP * _chase.look_height
	var chase_aim: float = rad_to_deg((-_cameras[0].global_basis.z).angle_to((chase_focus - _cameras[0].global_position).normalized()))
	reads.append("chase aim error %.5f degrees at the point %.1f m over the Unit" % [chase_aim, _chase.look_height])
	_kit.need(problems, chase_aim <= AIM_TOLERANCE, "the chase camera does not look at the point look_height over the Unit (%.5f degrees off)" % chase_aim)
	_kit.need(problems, _cameras[0].cull_mask == ChaseCamera.ALL_VISUAL_LAYERS, "the chase view hides a layer")
	var steps: int = 0
	var last: ChaseCameraSettings = _cameras[0].settings
	_h.set_key(KEYS_CAMERA[0], true)
	for _tick: int in HOLD_TICKS:
		await _kit.tick()
		if _cameras[0].settings != last:
			steps += 1
			last = _cameras[0].settings
	_h.set_key(KEYS_CAMERA[0], false)
	await _kit.tick()
	reads.append("held %d ticks: %d step, now %s" % [HOLD_TICKS, steps, _name_of(_cameras[0].settings)])
	_kit.need(problems, steps == 1 and _cameras[0].settings == _above, "a held Q made %d steps and ended on %s" % [steps, _name_of(_cameras[0].settings)])
	await _kit.advance(SETTLE_TICKS)
	await _kit.press_settled([KEYS_CAMERA[1]] as Array[Key])
	reads.append("slash: p1 %s p2 %s" % [_name_of(_cameras[0].settings), _name_of(_cameras[1].settings)])
	_kit.need(problems, _cameras[1].settings == _chase and _cameras[0].settings == _above, "/ did not switch only Player 2 to the chase view")
	await _kit.advance(SETTLE_TICKS)
	_kit.verdict("T6_switch", problems, " | ".join(reads))


## T4: the camera is at its place at the Round's start, after a respawn and after a restart
## (AC-2). It ends the run: Player 1 spends both Motorbikes, the second ends the Round, R restarts
## it. Player 2
## stays in the chase view, and it is still in it after the restart (the choice stays).
func _t4_snap() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var start: float = _error_of(0)
	reads.append("start p1 %.4f m" % start)
	await _tk.destruct(0)
	var spawned: bool = await _tk.spawn(0, 0)
	await _kit.advance(2)
	var respawn: float = _error_of(0)
	reads.append("respawn %s p1 %.4f m" % [spawned, respawn])
	await _tk.destruct(0)
	var restarted: bool = await _tk.restart()
	var chosen: bool = await _tk.spawn(0, 0) and await _tk.spawn(1, 0)
	await _kit.advance(2)
	var restart: Array[float] = [_error_of(0), _error_of(1)]
	reads.append("restart %s %s p1 %.4f m p2 %.4f m, p1 %s p2 %s" % [restarted, chosen, restart[0], restart[1], _name_of(_cameras[0].settings), _name_of(_cameras[1].settings)])
	_kit.need(problems, spawned and restarted and chosen, "the respawn or the restart did not run")
	_kit.need(problems, start <= PLACE_TOLERANCE and respawn <= PLACE_TOLERANCE, "start %.3f or respawn %.3f m from the place" % [start, respawn])
	_kit.need(problems, restart[0] <= PLACE_TOLERANCE and restart[1] <= PLACE_TOLERANCE, "after the restart %.3f and %.3f m from the place" % [restart[0], restart[1]])
	_kit.need(problems, _cameras[0].settings == _above and _cameras[1].settings == _chase, "a Player's view did not stay through the restart")
	_kit.verdict("T4_snaps", problems, " | ".join(reads))


## T7: the numbers are data, in the files, in the scene and in the Input Map (AC-5).
func _t7_data() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var above: ChaseCameraSettings = load("res://src/gameplay/camera/data/above_camera_settings.tres") as ChaseCameraSettings
	var chase: ChaseCameraSettings = load("res://src/gameplay/camera/data/chase_camera_settings.tres") as ChaseCameraSettings
	reads.append("above pitch=%.1f distance=%.1f look_ahead=%.1f look_height=%.1f sharpness=%.1f follow_rotation=%s hidden_layers=%d" % [above.pitch_degrees, above.distance, above.look_ahead, above.look_height, above.follow_sharpness, above.follow_rotation, above.hidden_layers])
	reads.append("chase offset=%s pitch=%.1f distance=%.1f look_ahead=%.1f hidden_layers=%d" % [chase.offset, chase.pitch_degrees, chase.distance, chase.look_ahead, chase.hidden_layers])
	_kit.need(problems, above.pitch_degrees == AC_PITCH and above.distance == AC_DISTANCE and above.look_ahead == AC_LOOK_AHEAD, "the view from above is not AC-1's starting values")
	_kit.need(problems, chase.offset == Vector3(0.0, 7.0, 13.0) and chase.distance == 0.0 and chase.pitch_degrees == 0.0 and chase.look_ahead == 0.0 and chase.hidden_layers == 0, "the chase settings are not Stories 001 to 009's")
	for player: int in Kit.PLAYERS:
		var input: PlayerCameraInput = _h.split.find_child("Player%dCameraInput" % (player + 1), true, false) as PlayerCameraInput
		var listed: bool = input != null and input.views.size() == 2 and input.views[0].resource_path == above.resource_path and input.views[1].resource_path == chase.resource_path
		var action: StringName = &"p%d_camera" % (player + 1)
		var bound: bool = InputMap.has_action(action) and InputMap.action_get_events(action).size() == 1 \
			and (InputMap.action_get_events(action)[0] as InputEventKey).physical_keycode == KEYS_CAMERA[player]
		reads.append("p%d list=%s action=%s key_bound=%s" % [player + 1, listed, action, bound])
		_kit.need(problems, listed, "p%d's list of views in the scene is not [above, chase]" % [player + 1])
		_kit.need(problems, bound, "%s is not bound to its one key" % action)
		_kit.need(problems, input != null and input.camera == _cameras[player], "p%d's input node steers another camera" % [player + 1])
	var toy: DrivingToy = (load("res://src/gameplay/driving_toy.tscn") as PackedScene).instantiate() as DrivingToy
	var toy_camera: ChaseCamera = toy.chase_camera
	var toy_path: String = toy_camera.settings.resource_path if toy_camera != null and toy_camera.settings != null else ""
	toy.free()
	reads.append("driving toy camera settings: %s" % toy_path.get_file())
	_kit.need(problems, toy_path == chase.resource_path, "the driving toy does not keep the chase camera")
	_kit.verdict("T7_data", problems, " | ".join(reads))


## T8: the tower top is out of the view from above and in the chase view, and nothing drawn hides
## the Flag or the Unit at the seat from any heading (AC-3). Player 1's Unit is placed at each seat
## and its camera snapped with no physics tick in between, so no Flag is taken and no Round ends; it
## is put back where it was.
func _t8_towers() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var camera: ChaseCamera = _cameras[0]
	var unit: Unit = _units[0]
	var home: Transform3D = unit.global_transform
	var opened: ChaseCameraSettings = _above.duplicate() as ChaseCameraSettings
	opened.hidden_layers = 0
	var hidden_when_open: int = 0
	var blocked: int = 0
	var probes: int = 0
	for base: Base in [_h.split.field.player_1_base, _h.split.field.player_2_base]:
		var top: Array[MeshInstance3D] = _tower_top(base)
		_kit.need(problems, top.size() == 4, "%s: %d tower-top pieces on the layer, not 4" % [base.name, top.size()])
		for piece: MeshInstance3D in top:
			_kit.need(problems, piece.layers == 2, "%s/%s is on layers %d, not only layer 2" % [base.name, piece.name, piece.layers])
		var seat: Vector3 = base.flag_seat.global_position
		for heading: int in HEADINGS:
			var facing: Transform3D = Transform3D(Basis(Vector3.UP, TAU * heading / HEADINGS), seat)
			for settings: ChaseCameraSettings in [_above, opened]:
				camera.settings = settings
				_h.place(unit, facing, camera)
				for height: float in [0.5, 1.5]:
					var target: Vector3 = seat + Vector3.UP * height
					var in_the_way: int = 0
					for piece: MeshInstance3D in top:
						if (camera.cull_mask & piece.layers) != 0 and (piece.global_transform * piece.get_aabb()).intersects_segment(camera.global_position, target) != null:
							in_the_way += 1
					if settings == _above:
						probes += 1
						blocked += in_the_way
					else:
						hidden_when_open += 1 if in_the_way > 0 else 0
	camera.settings = _above
	_h.place(unit, home, camera)
	await _kit.advance(2)
	reads.append("from above: %d sight lines to a Flag or a Unit at a seat, %d tower pieces in the way; with the layer drawn: %d of %d lines blocked" % [probes, blocked, hidden_when_open, probes])
	reads.append("cull masks: above %d, chase %d" % [ChaseCamera.ALL_VISUAL_LAYERS & ~_above.hidden_layers, ChaseCamera.ALL_VISUAL_LAYERS & ~_chase.hidden_layers])
	_kit.need(problems, blocked == 0, "%d tower pieces stand between the camera and a Flag or a Unit at a seat" % blocked)
	_kit.need(problems, hidden_when_open == probes, "with the layer drawn only %d of %d lines are blocked, so the check cannot tell" % [hidden_when_open, probes])
	_kit.verdict("T8_towers", problems, " | ".join(reads))


## T9: every Control of both views is where it was whichever view the camera is in (AC-3). Player
## 2's camera is in the chase view (T6, T4) and Player 1's in the view from above, so the two views
## are compared across the cameras, then Player 1 is switched and compared with itself.
func _t9_screen() -> void:
	var problems: PackedStringArray = []
	var before: PackedStringArray = _control_rects(0)
	var other: PackedStringArray = _control_rects(1)
	_cameras[0].settings = _chase
	var after: PackedStringArray = _control_rects(0)
	_cameras[0].settings = _above
	_kit.need(problems, before == after, "a Control of Player 1's view moved with the camera")
	_kit.need(problems, before.size() == other.size() and not before.is_empty(), "the two views hold %d and %d Controls" % [before.size(), other.size()])
	_kit.verdict("T9_screen_unchanged", problems, "%d Controls in each view, the same rectangles in both camera views" % before.size())


## The rectangles of every Control in a Player's view, as text, in tree order.
func _control_rects(player: int) -> PackedStringArray:
	var rects: PackedStringArray = []
	for node: Node in _cameras[player].get_viewport().find_children("*", "Control", true, false):
		var control: Control = node as Control
		rects.append("%s %s" % [control.get_path(), control.get_global_rect()])
	return rects


## The four pieces of a Base's water tower that are on render layer 2 (Tank, Roof, Platform, Band).
func _tower_top(base: Base) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in base.get_node("WaterTower").find_children("*", "MeshInstance3D", true, false):
		var piece: MeshInstance3D = node as MeshInstance3D
		if (piece.layers & 2) != 0:
			found.append(piece)
	return found


## Metres between a camera and the place its settings give it for its Unit.
func _error_of(player: int) -> float:
	return _cameras[player].global_position.distance_to(_place(_units[player], _cameras[player].settings))


## Where settings put a camera for a Unit: the Unit's frame (or the world's) times the offset.
func _place(unit: Unit, settings: ChaseCameraSettings) -> Vector3:
	var frame: Basis = unit.global_basis if settings.follow_rotation else Basis.IDENTITY
	return unit.global_position + frame * settings.local_offset()


## A basis's forward direction on the ground, a unit vector.
func _heading(basis: Basis) -> Vector3:
	return Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()


## A Unit's heading as an angle about the up axis, radians.
func _yaw_of(unit: Unit) -> float:
	return atan2(-unit.global_basis.z.x, -unit.global_basis.z.z)


## The short name of a settings resource for the log.
func _name_of(settings: ChaseCameraSettings) -> String:
	return settings.resource_path.get_file().get_basename() if settings != null else "none"
