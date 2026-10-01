## Wasteland backdrop and camera rig for concept renders of the vehicle models.
##
## Builds a desert at runtime: a sand plane with tyre tracks, dunes and mesas on
## the horizon, scattered rocks, a wreck, a leaning pole and dust puffs, under a
## hazy sun-bleached sky. Launched with user args
## (`++ --model=buggy|buggy_armored|motorbike|gyrocopter|truck --out=<png path> --view=front|rear|side`) it
## spawns the chosen model, frames it from the chosen side, writes the frame to
## disk and quits, so every render is reproducible from the command line.
## Without `--out` the scene just opens for viewing.
extends Node3D

const ProceduralTextures := preload("res://assets/art/shared/procedural_textures.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Frames to let the renderer settle before the capture is taken.
const CAPTURE_FRAME := 40

## Per-model framing. `cameras` rows are [azimuth in degrees from +X toward +Z,
## horizontal distance, height]; `view_props` are export values set on the model
## for a view; `tracks` are [x offset, width] of the tyre tracks it leaves;
## `dust_scale` sizes the near dust puffs to the model and `prop_spread` pushes
## the mid-ground props out so a small model is not crowded by them.
const MODELS: Dictionary = {
	"buggy": {
		"scene": "res://assets/art/vehicles/wasteland_buggy/wasteland_buggy.tscn",
		"target": Vector3(0.0, 0.95, 0.1),
		"cameras": {"front": [223.0, 6.2, 2.0], "rear": [44.0, 6.4, 2.2], "side": [175.0, 7.2, 1.5]},
		"view_props": {},
		"tracks": [[-1.05, 0.4], [1.05, 0.4]],
		"dust_scale": 0.9,
		"prop_spread": 1.0,
	},
	"buggy_armored": {
		"scene": "res://assets/art/vehicles/wasteland_buggy/wasteland_buggy_armored.tscn",
		"target": Vector3(0.0, 1.25, 0.2),
		"cameras": {"front": [223.0, 7.6, 2.3], "rear": [44.0, 7.8, 2.6], "side": [175.0, 8.8, 1.8]},
		"view_props": {
			"front": {"pod_yaw_deg": 35.0},
			"rear": {"pod_yaw_deg": 215.0},
			"side": {"pod_yaw_deg": 60.0},
		},
		"tracks": [[-1.25, 0.42], [1.27, 0.42]],
		"dust_scale": 1.0,
		"prop_spread": 1.0,
	},
	"gyrocopter": {
		"scene": "res://assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.tscn",
		"target": Vector3(0.0, 1.15, 0.3),
		"cameras": {"front": [223.0, 7.2, 2.1], "rear": [44.0, 7.4, 2.3], "side": [175.0, 8.0, 1.5]},
		"view_props": {
			"front": {"rotor_yaw_deg": 25.0},
			"rear": {"rotor_yaw_deg": -25.0},
			"side": {"rotor_yaw_deg": 60.0},
		},
		"tracks": [[-0.95, 0.16], [0.95, 0.16], [0.0, 0.12]],
		"dust_scale": 0.8,
		"prop_spread": 1.2,
	},
	"truck": {
		"scene": "res://assets/art/vehicles/wasteland_truck/wasteland_truck.tscn",
		"target": Vector3(0.0, 1.5, 0.0),
		"cameras": {"front": [223.0, 8.6, 2.7], "rear": [44.0, 8.8, 2.9], "side": [175.0, 9.8, 2.0]},
		"view_props": {
			"front": {"pod_yaw_deg": 25.0},
			"rear": {"pod_yaw_deg": 215.0},
			"side": {"pod_yaw_deg": 60.0},
		},
		"tracks": [[-0.98, 0.45], [0.98, 0.45]],
		"dust_scale": 1.1,
		"prop_spread": 1.0,
	},
	"motorbike": {
		"scene": "res://assets/art/vehicles/wasteland_motorbike/wasteland_motorbike.tscn",
		"target": Vector3(0.0, 0.62, -0.05),
		"cameras": {"front": [223.0, 3.4, 1.15], "rear": [44.0, 3.7, 1.3], "side": [175.0, 4.2, 0.95]},
		"view_props": {},
		"tracks": [[0.0, 0.22]],
		"dust_scale": 0.55,
		"prop_spread": 1.4,
	},
}

const SAND := Color(0.80, 0.63, 0.40)
const SAND_DARK := Color(0.62, 0.47, 0.29)
const DUNE := Color(0.82, 0.66, 0.44)
const DUNE_LIGHT := Color(0.88, 0.74, 0.54)
const ROCK_FAR := Color(0.60, 0.44, 0.32)
const ROCK := Color(0.52, 0.40, 0.30)
const BONE_ROCK := Color(0.74, 0.66, 0.54)
const DUST := Color(0.86, 0.72, 0.52)

var _out_path := ""
var _view := "front"
var _model_key := "buggy"
var _model: Dictionary = {}
var _frame := 0
var _m: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _cam_pos := Vector3.ZERO


func _ready() -> void:
	_parse_args()
	if not MODELS.has(_model_key):
		push_error("Unknown model '%s'; expected one of %s" % [_model_key, MODELS.keys()])
		_model_key = "buggy"
	_model = MODELS[_model_key]
	_rng.seed = 1337
	_build_materials()
	_build_sky()
	_build_terrain()
	_build_props()
	_spawn_model()
	_place_camera()
	_build_dust()
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func _process(_delta: float) -> void:
	if _out_path.is_empty():
		return
	_frame += 1
	if _frame < CAPTURE_FRAME:
		return
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_out_path)
	if err != OK:
		push_error("Could not write render to %s (error %d)" % [_out_path, err])
	else:
		print("Render written: %s (%dx%d)" % [_out_path, img.get_width(), img.get_height()])
	_out_path = ""
	get_tree().quit()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--view="):
			_view = arg.trim_prefix("--view=")
		elif arg.begins_with("--model="):
			_model_key = arg.trim_prefix("--model=")


func _build_materials() -> void:
	var sand_tex := ProceduralTextures.mottle(3,
			Color(0.84, 0.82, 0.78), Color(1.0, 1.0, 1.0), Color(0.92, 0.86, 0.74), 0.35, 512)
	var rock_tex := ProceduralTextures.mottle(5,
			Color(0.55, 0.50, 0.46), Color(1.0, 0.98, 0.94), Color(0.9, 0.8, 0.65), 0.4)
	_m["sand"] = Kitbash.flat_material(SAND, 1.0, 0.0, sand_tex, 0.12)
	_m["track"] = Kitbash.flat_material(SAND_DARK, 1.0, 0.0, sand_tex, 0.3)
	_m["dune"] = Kitbash.flat_material(DUNE, 1.0, 0.0)
	_m["dune_light"] = Kitbash.flat_material(DUNE_LIGHT, 1.0, 0.0)
	_m["rock_far"] = Kitbash.flat_material(ROCK_FAR, 1.0, 0.0)
	_m["rock"] = Kitbash.flat_material(ROCK, 0.95, 0.0, rock_tex, 0.8)
	_m["bone_rock"] = Kitbash.flat_material(BONE_ROCK, 0.9, 0.0, rock_tex, 0.8)
	_m["barrel"] = Kitbash.flat_material(Color(0.55, 0.27, 0.12), 0.9, 0.1, rock_tex, 1.2)
	_m["barrel_dark"] = Kitbash.flat_material(Color(0.30, 0.20, 0.14), 0.9, 0.1, rock_tex, 1.2)
	_m["wood"] = Kitbash.flat_material(Color(0.42, 0.33, 0.24), 1.0, 0.0, rock_tex, 1.0)
	_m["wreck"] = Kitbash.flat_material(Color(0.26, 0.17, 0.12), 0.95, 0.05, rock_tex, 0.8)
	_m["rubber_old"] = Kitbash.flat_material(Color(0.12, 0.11, 0.10), 1.0, 0.0)
	_m["shrub"] = Kitbash.flat_material(Color(0.36, 0.30, 0.19), 1.0, 0.0)


func _build_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.50, 0.58, 0.68)
	sky_mat.sky_horizon_color = Color(0.92, 0.74, 0.52)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.55, 0.42, 0.28)
	sky_mat.ground_horizon_color = Color(0.90, 0.72, 0.50)
	sky_mat.sun_angle_max = 40.0
	sky_mat.sun_curve = 0.2
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.88, 0.74, 0.56)
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.4
	sun.light_angular_distance = 0.8
	sun.rotation_degrees = Vector3(-33, 246, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.0
	add_child(sun)


func _build_terrain() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	Kitbash.place(self, plane, Vector3.ZERO, _m["sand"], Vector3.ZERO)
	# tyre tracks running off behind the model
	var tracks := Kitbash.group(self, "Tracks")
	tracks.rotation_degrees = Vector3(0, -8, 0)
	for track: Array in _model["tracks"]:
		_box(tracks, Vector3(track[1], 0.012, 60.0), Vector3(track[0], 0.006, 31.0), "track")
	# dunes and mesas all round the horizon, so every view has a skyline
	var horizon := Kitbash.group(self, "Horizon")
	for i in 22:
		var ang := deg_to_rad(i * 16.4 + _rng.randf_range(-8.0, 8.0))
		var dist := _rng.randf_range(90.0, 220.0)
		var pos := Vector3(cos(ang) * dist, -2.0, sin(ang) * dist)
		var size := Vector3(_rng.randf_range(40.0, 110.0), _rng.randf_range(6.0, 16.0),
				_rng.randf_range(25.0, 60.0))
		var key := "dune_light" if i % 3 == 0 else "dune"
		var dune := _ball(horizon, 1.0, pos, key, size)
		dune.rotation_degrees = Vector3(0, _rng.randf_range(0.0, 180.0), 0)
	for i in 4:
		var ang := deg_to_rad(i * 90.0 + _rng.randf_range(10.0, 80.0))
		var dist := _rng.randf_range(180.0, 280.0)
		var size := Vector3(_rng.randf_range(50.0, 100.0), _rng.randf_range(12.0, 22.0),
				_rng.randf_range(40.0, 80.0))
		var mesa_pos := Vector3(cos(ang) * dist, size.y * 0.05, sin(ang) * dist)
		var mesa_yaw := _rng.randf_range(0.0, 90.0)
		_box(horizon, size, mesa_pos, "rock_far", Vector3(0, mesa_yaw, 0))
		# a dune skirt so the mesa rises out of the sand instead of floating
		var skirt := _ball(horizon, 1.0, Vector3(mesa_pos.x, -1.0, mesa_pos.z), "dune",
				Vector3(size.x * 1.3, size.y * 0.35, size.z * 1.3))
		skirt.rotation_degrees = Vector3(0, mesa_yaw, 0)
	# scattered rocks, half sunk. The near ones sit in the mid-ground behind
	# the model for each camera (front, rear and side) and never in a foreground.
	var rocks := Kitbash.group(self, "Rocks")
	var mid_bearings: Array = [45.0, 225.0, 0.0]
	for i in 22:
		var ang_deg: float
		var dist: float
		if i < 8:
			ang_deg = mid_bearings[i % 3] + _rng.randf_range(-25.0, 25.0)
			dist = _rng.randf_range(9.0, 16.0)
		else:
			ang_deg = _rng.randf_range(0.0, 360.0)
			dist = _rng.randf_range(16.0, 45.0)
		var ang := deg_to_rad(ang_deg)
		var s := _rng.randf_range(0.3, 1.4) * (0.6 + dist * 0.03)
		var size := Vector3(s * _rng.randf_range(0.8, 1.6), s * _rng.randf_range(0.5, 0.9),
				s * _rng.randf_range(0.8, 1.4))
		var key := "bone_rock" if i % 4 == 0 else "rock"
		_box(rocks, size, Vector3(cos(ang) * dist, size.y * 0.1, sin(ang) * dist), key,
				Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.0, 180.0),
						_rng.randf_range(-6.0, 6.0)))


func _build_props() -> void:
	var props := Kitbash.group(self, "Props")
	var spread: float = _model["prop_spread"]
	# barrels, one tipped over, off to the sides of the camera lines
	var barrels: Array = [
		[Vector3(7.0, 0.32, 1.5), Vector3(0, 30, 90), "barrel"],
		[Vector3(6.0, 0.45, -1.0), Vector3(4, 0, 0), "barrel_dark"],
	]
	for spec: Array in barrels:
		var drum := Kitbash.group(props, "Barrel")
		var at: Vector3 = spec[0]
		drum.position = Vector3(at.x * spread, at.y, at.z * spread)
		drum.rotation_degrees = spec[1]
		_cyl(drum, 0.3, 0.9, Vector3.ZERO, spec[2], Vector3.ZERO, 14)
		for y: float in [-0.28, 0.0, 0.28]:
			_cyl(drum, 0.33, 0.05, Vector3(0, y, 0), "rubber_old", Vector3.ZERO, 14)
	# leaning power pole with a crossbar
	var pole := Kitbash.group(props, "Pole")
	pole.position = Vector3(-7.0 * spread, 0.0, 9.0 * spread)
	pole.rotation_degrees = Vector3(0, 0, 11)
	_cyl(pole, 0.14, 7.0, Vector3(0, 3.4, 0), "wood", Vector3.ZERO, 8)
	_box(pole, Vector3(1.8, 0.14, 0.14), Vector3(0, 6.2, 0), "wood")
	# burnt-out wreck sinking into the sand
	var wreck := Kitbash.group(props, "Wreck")
	wreck.position = Vector3(11.0 * spread, 0.0, -4.0 * spread)
	wreck.rotation_degrees = Vector3(0, 35, -7)
	_box(wreck, Vector3(1.8, 0.55, 3.8), Vector3(0, 0.3, 0), "wreck")
	_box(wreck, Vector3(1.5, 0.45, 1.6), Vector3(0, 0.75, 0.2), "wreck", Vector3(0, 0, 4))
	_cyl(wreck, 0.42, 0.3, Vector3(-1.05, 0.42, 1.2), "rubber_old", Vector3(0, 0, 90), 12)
	_cyl(wreck, 0.42, 0.3, Vector3(1.05, 0.5, -1.3), "rubber_old", Vector3(15, 0, 90), 12)
	# dead shrubs
	for i in 6:
		var ang := deg_to_rad(_rng.randf_range(-50.0, 140.0))
		var dist := _rng.randf_range(5.0, 30.0) * spread
		_ball(props, 1.0, Vector3(cos(ang) * dist, 0.1, sin(ang) * dist), "shrub",
				Vector3(_rng.randf_range(0.5, 1.1), _rng.randf_range(0.3, 0.6),
						_rng.randf_range(0.5, 1.1)))


func _build_dust() -> void:
	var near_mat := _dust_material(0.30)
	var far_mat := _dust_material(0.16)
	# Puffs are laid out with +Z as "away from the camera", then the group is
	# turned so that direction points away from wherever the camera is, keeping
	# the haze behind the model in every view.
	var dust := Kitbash.group(self, "Dust")
	var away := atan2(-_cam_pos.z, -_cam_pos.x)
	dust.rotation.y = PI / 2.0 - away
	var k: float = _model["dust_scale"]
	var puffs: Array = [
		[Vector3(-1.6, 0.6, 2.8) * k, 3.0 * k, near_mat], [Vector3(1.8, 0.5, 3.0) * k, 2.6 * k, near_mat],
		[Vector3(0.2, 0.8, 4.0) * k, 3.4 * k, near_mat], [Vector3(-2.8, 0.4, 2.0) * k, 2.0 * k, near_mat],
		[Vector3(2.6, 0.4, 2.2) * k, 1.8 * k, near_mat], [Vector3(6.0, 1.5, 16.0), 9.0, far_mat],
		[Vector3(-9.0, 1.2, 14.0), 8.0, far_mat], [Vector3(14.0, 2.0, 10.0), 10.0, far_mat],
	]
	for puff: Array in puffs:
		var quad := QuadMesh.new()
		var width: float = puff[1]
		quad.size = Vector2(width, width * 0.7)
		var mi := Kitbash.place(dust, quad, puff[0], puff[2], Vector3.ZERO)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _dust_material(peak_alpha: float) -> StandardMaterial3D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(DUST, peak_alpha), Color(DUST, peak_alpha * 0.33), Color(DUST, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _spawn_model() -> void:
	var scene: PackedScene = load(_model["scene"])
	var model := scene.instantiate() as Node3D
	var props: Dictionary = _model["view_props"].get(_view, {})
	for key: String in props:
		model.set(key, props[key])
	add_child(model)


func _place_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	var cams: Dictionary = _model["cameras"]
	var row: Array = cams.get(_view, cams["front"])
	var az := deg_to_rad(float(row[0]))
	_cam_pos = Vector3(cos(az) * float(row[1]), float(row[2]), sin(az) * float(row[1]))
	cam.look_at_from_position(_cam_pos, _model["target"], Vector3.UP)
	cam.current = true


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _ball(parent: Node3D, radius: float, pos: Vector3, mat: String,
		scale_by: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return Kitbash.ball(parent, radius, pos, _m[mat], scale_by)
