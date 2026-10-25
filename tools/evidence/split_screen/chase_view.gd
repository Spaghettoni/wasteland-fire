extends RefCounted
## Scenario chase_view of the split screen evidence harness (split_screen_harness.gd): Story 050 headless. Four Players in two
## Teams on Map 01, every camera on the chase view. CHECK lines:
##  V1 tokens: the shipped stock is 7 Motorbikes, 4 Buggies, 3 Trucks, 3 Gyrocopters, at least 1.3 times the 12 of before in
##     all and more of every type, and each Team starts the Round with it.
##  V2 the field of view: every camera on the chase settings keeps its width at width_fov_degrees (68.6), so a Unit in a
##     quarter view (640 x 360) is drawn as wide as it was in a half view (640 x 720, 75 degrees across the height): the
##     measured width of each Player's Unit on screen matches the half view's within 2 percent.
##  V3 the Unit low in the view: standing, each Player's Unit is drawn below the middle of its view, in its lower third
##     or lower; the camera sits behind and above it and looks look_ahead metres ahead of it.
## Implements: production/epics/wasteland-fire/story-050-tokens-and-chase-view.md AC-1 to AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=chase_view

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_01/map_01.tscn"
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const MORE_TOKENS: bool = true
const CHASE_SETTINGS: String = "res://src/gameplay/camera/data/chase_camera_settings.tres"
const OWN_CHOICE: bool = true
const TEAMS: bool = true
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
const SHIPPED_CAMERA: bool = true
const LINEUP_DEVICES: Array[int] = [-2, 0, -3, 1]
const LINEUP_TEAMS: Array[int] = [0, 0, 1, 1]
const WATCHDOG_SECONDS: float = 1800.0
const TYPES: Array[int] = [0, 1, 2, 3]

const OLD_TOTAL: int = 12
const OLD_COUNTS: Dictionary = {&"motorbike": 5, &"buggy": 3, &"truck": 2, &"gyrocopter": 2}
const GROWTH: float = 1.3
## The half view of a two-Player Round, pixels, and the camera's own vertical field of view in it.
const HALF_VIEW: Vector2 = Vector2(640.0, 720.0)
const OWN_FOV: float = 75.0
const WIDTH_TOLERANCE: float = 0.02
const LOWER_THIRD: float = 2.0 / 3.0

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var split: SplitScreen = _h.split
	var chase: ChaseCameraSettings = load(CHASE_SETTINGS) as ChaseCameraSettings
	for camera: ChaseCamera in split.all_cameras():
		camera.settings = chase
	for player: int in LINEUP_DEVICES.size():
		split.match_controller.choose(player, TYPES[player])
	await _kit.advance(60)
	_check_tokens(split)
	_check_views(split, chase)
	_h.finish("players=%d" % LINEUP_DEVICES.size())


func _check_tokens(split: SplitScreen) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var stock: TokenStock = load("res://src/gameplay/maps/data/token_stock.tres") as TokenStock
	var total: int = 0
	var lines: PackedStringArray = PackedStringArray()
	for type_id: StringName in OLD_COUNTS:
		var now: int = stock.count_of(type_id)
		total += now
		_kit.need(problems, now > int(OLD_COUNTS[type_id]), "%s: %d, was %d" % [type_id, now, OLD_COUNTS[type_id]])
		lines.append("%s %d (was %d)" % [type_id, now, OLD_COUNTS[type_id]])
	_kit.need(problems, float(total) >= GROWTH * OLD_TOTAL, "%d in all, under %.1f" % [total, GROWTH * OLD_TOTAL])
	var types: Array[UnitStats] = split.match_controller.unit_types()
	var starts: PackedStringArray = PackedStringArray()
	for player: int in split.match_controller.team_count():
		var row: PackedStringArray = PackedStringArray()
		for type_index: int in types.size():
			var left: int = split.match_controller.tokens_left(player, type_index)
			row.append(str(left))
			_kit.need(problems, left == stock.count_of(types[type_index].type_id), "Team %d starts with %d %s" % [player, left, types[type_index].type_id])
		starts.append("Team %d: %s" % [player, "/".join(row)])
	_kit.verdict("V1_tokens", problems, "%s; %d in all (%.2f times %d); %s" % [", ".join(lines), total, float(total) / OLD_TOTAL, OLD_TOTAL, "; ".join(starts)])


func _check_views(split: SplitScreen, chase: ChaseCameraSettings) -> void:
	var fov_problems: PackedStringArray = PackedStringArray()
	var low_problems: PackedStringArray = PackedStringArray()
	var fov_lines: PackedStringArray = PackedStringArray()
	var low_lines: PackedStringArray = PackedStringArray()
	var units: Array[Unit] = split.all_units()
	var cameras: Array[ChaseCamera] = split.all_cameras()
	for player: int in cameras.size():
		var camera: ChaseCamera = cameras[player]
		var unit: Unit = units[player]
		var size: Vector2 = Vector2(camera.get_viewport().get_visible_rect().size)
		var right: Vector3 = camera.global_basis.x
		var half: float = unit.stats.collision_size.x * 0.5
		var a: Vector2 = camera.unproject_position(unit.global_position - right * half)
		var b: Vector2 = camera.unproject_position(unit.global_position + right * half)
		var drawn: float = a.distance_to(b)
		var depth: float = -(camera.global_transform.affine_inverse() * unit.global_position).z
		# The same Unit at the same depth in a half view at the camera's own 75 degrees across the height.
		var half_view: float = (HALF_VIEW.y * 0.5 / tan(deg_to_rad(OWN_FOV) * 0.5)) * (2.0 * half) / depth
		var share: float = drawn / half_view
		_kit.need(fov_problems, camera.keep_aspect == Camera3D.KEEP_WIDTH and is_equal_approx(camera.fov, chase.width_fov_degrees), "Player %d: keep %d, fov %.1f" % [player + 1, camera.keep_aspect, camera.fov])
		_kit.need(fov_problems, absf(share - 1.0) <= WIDTH_TOLERANCE, "Player %d: drawn %.1f px wide in a %.0f x %.0f view, %.1f in a half view" % [player + 1, drawn, size.x, size.y, half_view])
		fov_lines.append("P%d %s %.0fx%.0f %.1f px (half view %.1f)" % [player + 1, unit.stats.type_id, size.x, size.y, drawn, half_view])
		var at: Vector2 = camera.unproject_position(unit.global_position)
		var down: float = at.y / size.y
		_kit.need(low_problems, down >= LOWER_THIRD and down < 1.0, "Player %d: the Unit at %.2f of the view's height" % [player + 1, down])
		low_lines.append("P%d %.2f" % [player + 1, down])
	_kit.verdict("V2_field_of_view", fov_problems, "keep width at %.1f degrees: %s" % [chase.width_fov_degrees, ", ".join(fov_lines)])
	_kit.verdict("V3_unit_low", low_problems, "standing, each Unit drawn at this share of its view's height from the top: %s (offset %s, look_ahead %.1f m)" % [", ".join(low_lines), chase.offset, chase.look_ahead])
