extends RefCounted
## What each Player sees of the flying Gyrocopter, for the heights scenario (Story 020 AC-4): views (in the view from above and in
## the chase view, each Player's whole Gyrocopter model, measured on its drawn box as camera_views measures a Unit's footprint, is
## inside that Player's own view at four headings; the shift of the drawn model's lowest point and top from the Unit's place on
## the ground, in each view, is recorded; and each Player sees the other Player's Gyrocopter at the same height, in one shared
## world). Run by heights.gd. Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

const ABOVE_SETTINGS: String = "res://src/gameplay/camera/data/above_camera_settings.tres"
const CHASE_SETTINGS: String = "res://src/gameplay/camera/data/chase_camera_settings.tres"
## Where the two Gyrocopters stand on the flat west of the ford, 12 m apart on one row, so that each is in the other's view too.
const ROW_Z: float = -12.0
const FIRST_X: float = -82.0
const SECOND_X: float = -70.0
## The ticks a camera needs after it is given a view: a second leaves e^-8 of the gap at its sharpness of 8 a second.
const SETTLE_TICKS: int = 150
## How far a camera's pitch may be from the one its settings give once it has settled, degrees.
const PITCH_TOLERANCE: float = 0.5
## The headings the pair is turned to.
const HEADINGS: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks. A coroutine: await it.
func run() -> void:
	await _k.k.k.turrets_down()
	await _views()


## The corners of a box.
static func _corners(box: AABB) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for index: int in 8:
		found.append(box.get_endpoint(index))
	return found


## The ground point (y = 0) a camera's ray through a world point's pixel meets, and from it how far the point appears shifted from
## the ground place under it, along the camera's own view direction on the ground (positive: farther from the camera, up the screen).
static func _shift(camera: Camera3D, point: Vector3) -> float:
	var pixel: Vector2 = camera.unproject_position(point)
	var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	var forward: Vector3 = Vector3(-camera.global_basis.z.x, 0.0, -camera.global_basis.z.z).normalized()
	var apart: Vector3 = (ground as Vector3) - Vector3(point.x, 0.0, point.z)
	return apart.dot(forward)


## views (AC-4).
func _views() -> void:
	var problems: PackedStringArray = []
	var views: Array[ChaseCameraSettings] = [load(ABOVE_SETTINGS) as ChaseCameraSettings, load(CHASE_SETTINGS) as ChaseCameraSettings]
	var names: Array[String] = ["above", "chase"]
	var originals: Array[ChaseCameraSettings] = [_q.units.cameras[0].settings, _q.units.cameras[1].settings]
	var worst_margin: Array[float] = [INF, INF]
	var other_margin: Array[float] = [INF, INF]
	var low_shift: Array[float] = [0.0, 0.0]
	var top_shift: Array[float] = [0.0, 0.0]
	var ray_angle: Array[float] = [INF, INF]
	var raised_px: Array[float] = [0.0, 0.0]
	var seen_other: Array[int] = [0, 0]
	var measures: int = 0
	_q.kit.need(problems, _q.units.cameras[0].get_world_3d() == _q.units.cameras[1].get_world_3d(), "the two Players' cameras look at different worlds")
	for heading: Vector3 in HEADINGS:
		await _q.map.stage([Kit20.GYRO, Kit20.GYRO], [Vector3(FIRST_X, 0.0, ROW_Z), Vector3(SECOND_X, 0.0, ROW_Z)], [heading, -heading], true)
		for view: int in 2:
			for player: int in Kit20.Kit.PLAYERS:
				_q.units.cameras[player].settings = views[view]
				_q.units.cameras[player].snap_to_target()
			await _q.kit.advance(SETTLE_TICKS)
			for player: int in Kit20.Kit.PLAYERS:
				var camera: ChaseCamera = _q.units.cameras[player]
				var pitch: float = -rad_to_deg(asin(clampf(-camera.global_basis.z.y, -1.0, 1.0)))
				var offset: Vector3 = camera.global_position - _q.units.units[player].global_position
				var want: float = views[view].pitch_degrees if view == 0 else rad_to_deg(atan2(views[view].offset.y - views[view].look_height, views[view].offset.z))
				_q.kit.need(problems, absf(pitch - want) <= PITCH_TOLERANCE, "p%d's %s camera looks %.2f degrees below the horizon, its settings give %.2f (it is %s from the Unit)" % [player + 1, names[view], pitch, want, offset])
			var lows: Array[float] = [Quick.model_bottom(_q.units.units[0]), Quick.model_bottom(_q.units.units[1])]
			_q.kit.need(problems, absf(lows[0] - lows[1]) <= Kit20.TOLERANCE and absf(lows[0] - _k.height) <= Kit20.TOLERANCE + Kit20.FLOAT_SLACK, "%s view: the two Gyrocopters' lowest points are %.4f and %.4f m, the flying height is %.4f" % [names[view], lows[0], lows[1], _k.height])
			for player: int in Kit20.Kit.PLAYERS:
				var camera: ChaseCamera = _q.units.cameras[player]
				var rect: Rect2 = camera.get_viewport().get_visible_rect()
				for owner_index: int in Kit20.Kit.PLAYERS:
					var box: AABB = Quick.model_box(_q.units.units[owner_index])
					var margin: float = INF
					for corner: Vector3 in _corners(box):
						_q.kit.need(problems, not camera.is_position_behind(corner), "p%d's %s view: a corner of p%d's Gyrocopter is behind the camera" % [player + 1, names[view], owner_index + 1])
						var pixel: Vector2 = camera.unproject_position(corner)
						margin = minf(margin, minf(minf(pixel.x - rect.position.x, rect.end.x - pixel.x), minf(pixel.y - rect.position.y, rect.end.y - pixel.y)))
					if owner_index == player:
						worst_margin[view] = minf(worst_margin[view], margin)
						_q.kit.need(problems, margin > 0.0, "p%d's %s view at heading %s: its own Gyrocopter's drawn box leaves the view (margin %.1f px)" % [player + 1, names[view], heading, margin])
						var unit: Unit = _q.units.units[player]
						low_shift[view] = maxf(low_shift[view], absf(_shift(camera, Vector3(unit.global_position.x, lows[player], unit.global_position.z))))
						top_shift[view] = maxf(top_shift[view], absf(_shift(camera, Vector3(unit.global_position.x, box.end.y, unit.global_position.z))))
						var to_low: Vector3 = Vector3(unit.global_position.x, lows[player], unit.global_position.z) - camera.global_position
						ray_angle[view] = minf(ray_angle[view], rad_to_deg(atan2(-to_low.y, Vector2(to_low.x, to_low.z).length())))
						raised_px[view] = maxf(raised_px[view], camera.unproject_position(Vector3(unit.global_position.x, 0.0, unit.global_position.z)).y - camera.unproject_position(Vector3(unit.global_position.x, lows[player], unit.global_position.z)).y)
						measures += 1
					else:
						other_margin[view] = minf(other_margin[view], margin)
						seen_other[view] += 1 if margin > 0.0 else 0
	for player: int in Kit20.Kit.PLAYERS:
		_q.units.cameras[player].settings = originals[player]
		_q.units.cameras[player].snap_to_target()
	await _q.kit.advance(SETTLE_TICKS)
	measured.append("views=%d above_shift=%.3f chase_shift=%.3f" % [measures, low_shift[0], low_shift[1]])
	_q.kit.verdict("views", problems, "in both views, at %d headings and for both Players, the whole drawn box of the Player's own Gyrocopter (lowest point %.3f m, rotor top %.3f m) is inside its view (least margin: %.1f px in the view from above, %.1f px in the chase view, of 640 x 720); the drawn model stands off the Unit's place on the ground along the view direction (farther from the camera, up the screen) by %.3f m at its lowest point and %.3f m at its rotor top in the view from above, where the ray through the Unit's pixel is %.1f degrees below the horizon (at the view's centre, %.0f degrees, 1 m of height would be %.3f m), and by %.3f m and %.3f m in the chase view (a ray %.1f degrees below the horizon), the lowest point drawn %.0f px above the Unit's place in the view from above and %.0f px in the chase view; each Player sees the other's Gyrocopter at the same height (both lowest points %.4f m in one shared world), %d of %d of the other's drawn boxes wholly in view in the view from above and %d in the chase view" % [
		HEADINGS.size(), _k.height, _k.band().y, worst_margin[0], worst_margin[1], low_shift[0], top_shift[0], ray_angle[0], views[0].pitch_degrees, 1.0 / tan(deg_to_rad(views[0].pitch_degrees)), low_shift[1], top_shift[1], ray_angle[1], raised_px[0], raised_px[1], _k.height, seen_other[0], measures / 2, seen_other[1]])
