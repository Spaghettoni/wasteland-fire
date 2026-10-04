extends RefCounted
## Scenario camera_smooth of the split screen evidence harness (split_screen_harness.gd): AC-2 of
## Story 010, that the camera follows without visible jitter at the display's real frame rate, in
## the view from above and, for comparison, in the chase view. Player 1's Motorbike drives straight
## at its top speed along the open flat while the scenario samples, once per rendered frame just
## before it is drawn (RenderingServer.frame_pre_draw, after every _process, so the Unit's drawn
## place and the camera are of the same frame), where the camera looks and where the Unit is drawn.
##
## What is measured, and why not the camera's place. The camera's place is smoothed
## (follow_sharpness, a lag of a tenth of a second), and that low-pass filter takes a 60 Hz
## staircase out of it: a camera that read the Unit's physics-tick transform instead of the drawn
## one would move only 4 mm off a straight line. The aim is not smoothed: the look point comes
## straight from the Unit's transform. A camera that read the tick transform would look at where the
## Unit was last ticked while the Unit is drawn up to a whole tick step (v / 60, 0.4 m at 24 m/s)
## away, so the whole picture would step at 60 Hz: 0.9 degrees at 26 m, about 7 px of the view from
## above (one pixel of its 720 px is about 5 cm of ground). So the verdict is the angle between the
## camera's forward direction and the direction from the camera to the look point of the Unit's
## drawn transform (get_global_transform_interpolated()), the largest over the run, against
## AIM_LIMIT (0.02 degrees, about 0.3 px). The frames have to fall on at least SPREAD_MINIMUM of a
## tick (at 120 Hz on two phases of each tick; frames all at the end of a tick would hide the
## difference, and a 60 Hz display could not show the staircase either), or nothing is measured and
## the check fails with that reason. The camera's place against the frame's time, and its lag
## behind the Unit, are printed for the record (lag_residual_*, the residual of a straight line
## fitted to the lag against the frame's timestamp, metres; the timestamp itself carries about 1 ms
## of noise, 2 cm at 24 m/s, so it is not a verdict).
##
## One CHECK, smooth, and a SPLIT line per run with the numbers; each view is measured RUNS times
## and every run has to pass. Needs a window and the real renderer: use neither --write-movie nor
## --headless (a headless run fails the CHECK with reason=headless, because it measures nothing).
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=camera_smooth
## Implements: production/epics/wasteland-fire/story-010-camera-from-above.md AC-2. Tooling only.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): staging.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario runs on the camera the build ships with, the view from above.
const SHIPPED_CAMERA: bool = true
## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The frames show Map 01's own Token stock: nothing here spends a Token.
const USE_MAP_STOCK: bool = true
## How many times each view is measured; every run has to pass.
const RUNS: int = 3
## Seconds the scene runs before anything is measured, so the renderer's start-up work (shader and
## pipeline compilation after an import) is over.
const PRE_ROLL_SECONDS: float = 3.0
## Seconds each view is sampled for, after the warm-up: the Unit is at its top speed and short of
## the ford, which slows it from x = -45 on (UnitStats: 20 m/s^2 to 24 m/s in 1.2 s, 14.4 m;
## measured: it is at x = -68 after the warm-up and in the ford 1.0 s later).
const SAMPLE_SECONDS: float = 0.8
## Seconds the Unit drives before sampling, so the camera has caught up with its speed (its lag
## settles by e^-8 per second).
const WARM_UP_SECONDS: float = 1.9
## The most the camera's aim may be off the Unit's drawn look point, degrees: about 0.3 px of the
## view from above. A camera on the physics-tick transform is off by up to 0.9.
const AIM_LIMIT: float = 0.02
## The least spread of interpolation fractions (largest less smallest) the samples must cover.
const SPREAD_MINIMUM: float = 0.2
## Where Player 1 starts its run, on the open flat just outside Base A's gate.
const START: Vector3 = Vector3(-100.0, 0.0, -12.0)

var _q: Quick
var _times: PackedFloat64Array = []
var _lag_at: PackedFloat64Array = []
var _fraction_at: PackedFloat64Array = []
var _aim_error: PackedFloat64Array = []
var _sampling: bool = false


## Measures the view from above, then the chase view; one CHECK and the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	if DisplayServer.get_name() == "headless":
		_q.kit.verdict("smooth", ["reason=headless"] as PackedStringArray, "a headless run measures nothing")
		_q.close()
		_q.harness.finish("display=headless")
		return
	await _q.harness.confirm_choices()
	await _q.kit.advance(_q.harness.ticks_in(PRE_ROLL_SECONDS))
	var camera: ChaseCamera = _q.units.cameras[0]
	var above: ChaseCameraSettings = camera.settings
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	for settings: ChaseCameraSettings in [above, Harness.CHASE_CAMERA_SETTINGS]:
		camera.settings = settings
		var label: String = "above" if settings == above else "chase"
		for run_index: int in RUNS:
			var m: Dictionary = await _run_view()
			var numbers: String = "samples=%d fraction_spread=%.2f aim_error_max=%.5fdeg lag_residual_rms=%.4f lag_residual_max=%.4f" % [m["samples"], m["spread"], m["aim_max"], m["lag_rms"], m["lag_max"]]
			print("SPLIT camera_smooth t=%.3f view=%s run=%d %s" % [_q.harness.time(), label, run_index + 1, numbers])
			reads.append("%s run %d: %s" % [label, run_index + 1, numbers])
			_q.kit.need(problems, m["samples"] > 60, "%s run %d: only %d samples" % [label, run_index + 1, m["samples"]])
			_q.kit.need(problems, m["spread"] >= SPREAD_MINIMUM, "%s run %d: the frames fall on a spread of only %.2f of a tick, so nothing is measured" % [label, run_index + 1, m["spread"]])
			_q.kit.need(problems, m["aim_max"] <= AIM_LIMIT, "%s run %d: the camera looks %.5f degrees off the drawn Unit (limit %.2f): it follows the tick" % [label, run_index + 1, m["aim_max"], AIM_LIMIT])
	camera.settings = above
	_q.kit.verdict("smooth", problems, " | ".join(reads) + " refresh_hz=%.1f" % DisplayServer.screen_get_refresh_rate())
	_q.close()
	_q.harness.finish("display=%s refresh_hz=%.1f %s" % [DisplayServer.get_name(), DisplayServer.screen_get_refresh_rate(), _q.engine_counts()])


## Drives Player 1's Motorbike along the flat at full throttle and returns the readings of one run:
## samples, the spread of the interpolation fractions, the largest aim error (degrees) and the
## residual of the lag against time (RMS and largest, metres). A coroutine.
func _run_view() -> Dictionary:
	await _q.map.stage([Quick.MOTORBIKE, -1] as Array[int], [START, Vector3.ZERO] as Array[Vector3], [Vector3.RIGHT, Vector3.RIGHT] as Array[Vector3], true)
	_times.clear()
	_lag_at.clear()
	_fraction_at.clear()
	_aim_error.clear()
	_q.harness.drive(Harness.PLAYER_1, 1, 0)
	await _q.kit.advance(_q.harness.ticks_in(WARM_UP_SECONDS))
	_sampling = true
	RenderingServer.frame_pre_draw.connect(_sample)
	await _q.kit.advance(_q.harness.ticks_in(SAMPLE_SECONDS))
	RenderingServer.frame_pre_draw.disconnect(_sample)
	_sampling = false
	_q.harness.release_all()
	var low: float = _fraction_at[0] if not _fraction_at.is_empty() else 0.0
	var high: float = low
	var aim_max: float = 0.0
	for index: int in _fraction_at.size():
		low = minf(low, _fraction_at[index])
		high = maxf(high, _fraction_at[index])
		aim_max = maxf(aim_max, _aim_error[index])
	var lag_fit: Array[float] = _residuals(_lag_at)
	return {"samples": _times.size(), "spread": high - low, "aim_max": aim_max, "lag_rms": lag_fit[0], "lag_max": lag_fit[1]}


## One sample per rendered frame, taken just before it is drawn: the time, the camera's lag behind
## the Unit's drawn place (x, metres), the physics interpolation fraction, and the angle between the
## camera's forward direction and the direction to the look point of the Unit's drawn transform.
func _sample() -> void:
	if not _sampling:
		return
	var unit: Unit = _q.units.units[0]
	var camera: ChaseCamera = _q.units.cameras[0]
	var drawn: Transform3D = unit.get_global_transform_interpolated()
	var settings: ChaseCameraSettings = camera.settings
	var frame: Basis = drawn.basis if settings.follow_rotation else Basis.IDENTITY
	var focus: Vector3 = drawn.origin + Vector3.UP * settings.look_height + frame * Vector3(0.0, 0.0, -settings.look_ahead)
	_times.append(float(Time.get_ticks_usec()) / 1000000.0)
	_lag_at.append(camera.global_position.x - drawn.origin.x)
	_fraction_at.append(Engine.get_physics_interpolation_fraction())
	_aim_error.append(rad_to_deg((-camera.global_basis.z).angle_to((focus - camera.global_position).normalized())))


## What a straight line fitted by least squares to place against time leaves over: [the RMS, the
## largest absolute residual], metres. Fewer than three samples give zeros.
func _residuals(places: PackedFloat64Array) -> Array[float]:
	var count: int = places.size()
	if count < 3:
		return [0.0, 0.0]
	var mean_t: float = 0.0
	var mean_p: float = 0.0
	for index: int in count:
		mean_t += _times[index]
		mean_p += places[index]
	mean_t /= count
	mean_p /= count
	var covariance: float = 0.0
	var variance: float = 0.0
	for index: int in count:
		covariance += (_times[index] - mean_t) * (places[index] - mean_p)
		variance += (_times[index] - mean_t) * (_times[index] - mean_t)
	var slope: float = covariance / variance if variance > 0.0 else 0.0
	var squares: float = 0.0
	var largest: float = 0.0
	for index: int in count:
		var residual: float = places[index] - (mean_p + slope * (_times[index] - mean_t))
		squares += residual * residual
		largest = maxf(largest, absf(residual))
	return [sqrt(squares / count), largest]
