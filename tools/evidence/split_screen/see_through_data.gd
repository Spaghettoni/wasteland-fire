extends RefCounted
## The data of the see_through scenario (Story 027 AC-1, AC-2, AC-3 and AC-5): settings_data (the shipped silhouette settings are usable and shared by both Units, with a mask
## pass, a sight pass and a fill pass that are each what SilhouetteSettings says, drawn in that order, and a strength from 0 to 1), project_layers (project.godot names the two
## silhouette render layers and the settings use exactly them), environment_data (Map 01's Environment, read back from map_01.tscn, uses a tone mapper other than Linear, a glow
## that only takes what is brighter than the brightest lit value measured at the start of the story, and the colour grade), greybox_untouched (the greybox field keeps its own
## Environment), grade_data (the grade's parameters, the lookup texture's size, and that the grade keeps the Team colours apart), lut_file (the lookup texture on disk holds, layer
## by layer and in order, the bytes the tool writes from the parameters) and settings_refused (SilhouetteSettings.first_problem() names each fault of the data with its own
## sentence and passes the shipped settings; a Unit given unusable settings logs one error, is drawn as before and is dressed again when it is given usable ones). Run by
## see_through.gd. Tooling only. Every number comes from the game's data and files; the scenario types only its test inputs.

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The colour grade's tool: its static functions are the grade the lookup texture is written from.
const Grade: GDScript = preload("res://tools/colour_grade/build_colour_grade_lut.gd")

## The brightest lit value of Map 01 measured at the start of the story with the tone mapper at Linear (the light probe: the salt flat 1.26, the ford's water
## glints about 1.6): the glow's threshold must lie above it, so that nothing the Map shows today blooms.
const BRIGHTEST_LIT: float = 1.6
## How far the grade may move a Team colour's hue as the lookup function alone gives it, in degrees (the frames, after the tone mapper, are measured separately: 0.4 at most), and
## the least the two Team colours' hues stay apart (about 160 are measured).
const HUE_MOVE_LIMIT: float = 4.0
const HUE_APART: float = 120.0
const FULL_TURN: float = 360.0
## Where Player 1's Unit is staged for the Unit's refusal: the open middle of the Map, 30 m west of its middle.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## The fill quad must reach this many camera distances across (the farthest a camera is from the Unit it follows, in either view), so that it covers the whole picture.
const FILL_COVERS_VIEW: float = 4.0
## The sentences SilhouetteSettings.first_problem() gives.
const STRENGTH_PROBLEM: String = "strength is not from 0 to 1"
const LAYER_PROBLEM: String = "a layer is not one render layer (a mask of one bit)"
const SAME_LAYER_PROBLEM: String = "both Players have one silhouette layer, so a camera would draw the other Player's silhouette"
const STENCIL_PROBLEM: String = "a stencil value is not from 1 to 255"
const SAME_STENCIL_PROBLEM: String = "the mask and the sight pass write one stencil value"
const NOT_ALPHA: String = " is not alpha-blended, so it is not sorted by render_priority (its transparency is not alpha)"
const FILL_FLAT_PROBLEM: String = "fill_material does not mix one flat colour (a blend mode other than mix, or a texture)"
const WRITE_ALONE: String = " does not write the stencil alone (stencil_mode custom with the write flag only: the engine lets a material read or write it, never both)"
const FILL_READ_PROBLEM: String = "fill_material does not read the stencil alone where it is equal (stencil_mode custom, the read flag only, compare equal)"
## The faults of the values of the settings: [property, bad value, the sentence].
const SETTINGS_FAULTS: Array = [
	["strength", -0.1, STRENGTH_PROBLEM], ["strength", 1.5, STRENGTH_PROBLEM], ["strength", NAN, STRENGTH_PROBLEM],
	["player_1_layer", 0, LAYER_PROBLEM], ["player_1_layer", 3, LAYER_PROBLEM], ["player_2_layer", 0, LAYER_PROBLEM], ["player_2_layer", 12, LAYER_PROBLEM],
	["fill_extent", 0.0, "fill_extent is not above zero"], ["fill_extent", -5.0, "fill_extent is not above zero"], ["fill_extent", NAN, "fill_extent is not above zero"]]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit27
var _q: Quick


func _init(kit: Kit27, _at_start: Dictionary) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_settings_data()
	_project_layers()
	_environment_data()
	_greybox_untouched()
	_grade_data()
	_lut_file()
	await _settings_refused()


## settings_data (AC-4, AC-5): see the class doc.
func _settings_data() -> void:
	var problems: PackedStringArray = []
	var settings: SilhouetteSettings = _k.settings()
	_q.kit.need(problems, settings != null and settings.first_problem().is_empty(), "the shipped settings read '%s'" % (settings.first_problem() if settings != null else "missing"))
	var above: ChaseCameraSettings = _k.camera(0).settings
	var chase: ChaseCameraSettings = load("res://src/gameplay/camera/data/chase_camera_settings.tres") as ChaseCameraSettings
	var farthest: float = maxf(above.distance, chase.offset.length())
	_q.kit.need(problems, settings.strength > 0.0 and settings.strength <= 1.0 and settings.fill_extent >= FILL_COVERS_VIEW * farthest, "the strength is %s and the fill's side %s, under %.0f camera distances of %.1f m" % [settings.strength, settings.fill_extent, FILL_COVERS_VIEW, farthest])
	var mask: StandardMaterial3D = settings.mask_material
	var sight: StandardMaterial3D = settings.sight_material
	var fill: StandardMaterial3D = settings.fill_material
	var write: int = BaseMaterial3D.STENCIL_FLAG_WRITE
	for writer: StandardMaterial3D in [mask, sight]:
		_q.kit.need(problems, writer.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and writer.albedo_color.a == 0.0 and writer.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and writer.stencil_flags == write and writer.stencil_compare == BaseMaterial3D.STENCIL_COMPARE_ALWAYS, "a writing pass is not alpha-blended or is visible or does not always write the stencil alone (transparency %d, alpha %s, mode %d, flags %d, compare %d)" % [writer.transparency, writer.albedo_color.a, writer.stencil_mode, writer.stencil_flags, writer.stencil_compare])
	_q.kit.need(problems, mask.no_depth_test and not sight.no_depth_test, "the mask pass ignores depth %s and the sight pass %s: the first must, the second must not" % [mask.no_depth_test, sight.no_depth_test])
	_q.kit.need(problems, fill.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and fill.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and fill.no_depth_test and fill.disable_fog and fill.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "the fill is shaded, not alpha-blended, depth tested, fogged or not a billboard (shading %d, transparency %d, no_depth_test %s, disable_fog %s, billboard %d)" % [fill.shading_mode, fill.transparency, fill.no_depth_test, fill.disable_fog, fill.billboard_mode])
	_q.kit.need(problems, fill.stencil_mode == BaseMaterial3D.STENCIL_MODE_CUSTOM and fill.stencil_flags == BaseMaterial3D.STENCIL_FLAG_READ and fill.stencil_compare == BaseMaterial3D.STENCIL_COMPARE_EQUAL and fill.stencil_reference == mask.stencil_reference and sight.stencil_reference != mask.stencil_reference, "the fill reads with mode %d flags %d compare %d reference %d, the mask writes %d and the sight %d" % [fill.stencil_mode, fill.stencil_flags, fill.stencil_compare, fill.stencil_reference, mask.stencil_reference, sight.stencil_reference])
	_q.kit.need(problems, mask.render_priority < sight.render_priority and sight.render_priority < fill.render_priority, "the passes' render priorities %d, %d and %d do not rise" % [mask.render_priority, sight.render_priority, fill.render_priority])
	_q.kit.need(problems, _k.unit(0).silhouette == settings and _k.unit(1).silhouette == settings and settings.resource_path == Kit27.SETTINGS_PATH, "the Units' settings are %s and %s, not the one resource %s" % [_k.unit(0).silhouette, _k.unit(1).silhouette, Kit27.SETTINGS_PATH])
	measured.append("strength=%.2f" % settings.strength)
	_q.kit.verdict("settings_data", problems, "silhouette_settings.tres is usable (first_problem() is empty) and both Units of the launch scene carry that one resource; the mask pass (priority %d, no depth test) and the sight pass (priority %d, depth tested) are invisible, transparent and write the stencil alone, always, the values %d and %d; the fill (priority %d) is an unshaded, see-through, fogless billboard with no depth test that reads the stencil alone where it equals the mask value %d; the strength %.2f, the fill's side %.0f m (over %.0f camera distances of %.1f m, so the quad covers the picture) and the layers %d and %d are data of the file" % [mask.render_priority, sight.render_priority, mask.stencil_reference, sight.stencil_reference, fill.render_priority, fill.stencil_reference, settings.strength, settings.fill_extent, FILL_COVERS_VIEW, farthest, settings.player_1_layer, settings.player_2_layer])


## The index (1 to 32) of the render layer a one-bit mask stands for, or 0 when it is not one bit.
func _layer_index(mask: int) -> int:
	for index: int in 32:
		if mask == 1 << index:
			return index + 1
	return 0


## project_layers (AC-4, AC-5): see the class doc.
func _project_layers() -> void:
	var problems: PackedStringArray = []
	var settings: SilhouetteSettings = _k.settings()
	var names: PackedStringArray = []
	for player: int in 2:
		var layer: int = settings.layer_of(player)
		var index: int = _layer_index(layer)
		var named: String = String(ProjectSettings.get_setting("layer_names/3d_render/layer_%d" % index, ""))
		_q.kit.need(problems, index > 0 and named == "silhouette_p%d" % (player + 1), "Player %d's silhouette layer %d is render layer %d, which project.godot names '%s'" % [player + 1, layer, index, named])
		_q.kit.need(problems, (layer & ChaseCamera.ALL_VISUAL_LAYERS) == layer, "the layer %d is not one of the engine's visual layers" % layer)
		names.append("%s=%d" % [named, index])
	_q.kit.need(problems, (settings.player_1_layer | settings.player_2_layer) & (1 | 2) == 0, "a silhouette layer is the default layer or the tower_top layer")
	_q.kit.verdict("project_layers", problems, "project.godot names the render layers of the two Players' silhouettes (%s) and the settings use exactly those layers (%d and %d), neither the default layer nor tower_top" % [", ".join(names), settings.player_1_layer, settings.player_2_layer])


## environment_data (AC-1, AC-2, AC-3, AC-5): see the class doc.
func _environment_data() -> void:
	var problems: PackedStringArray = []
	var env: Environment = Kit27.environment_of(Kit27.MAP_PATH)
	_q.kit.need(problems, env != null, "map_01.tscn has no WorldEnvironment with an Environment")
	if env == null:
		_q.kit.verdict("environment_data", problems, "no Environment")
		return
	_q.kit.need(problems, env.tonemap_mode != Environment.TONE_MAPPER_LINEAR, "the tone mapper is Linear")
	_q.kit.need(problems, env.tonemap_exposure > 0.0 and env.tonemap_agx_white > 0.0 and env.tonemap_agx_contrast > 0.0, "the exposure %s, the AgX white %s or contrast %s is not above zero" % [env.tonemap_exposure, env.tonemap_agx_white, env.tonemap_agx_contrast])
	_q.kit.need(problems, env.glow_enabled and env.glow_hdr_threshold > BRIGHTEST_LIT and env.glow_hdr_scale > 0.0 and env.glow_intensity > 0.0, "the glow is %s with a threshold of %s (the brightest lit value measured is %s), a scale of %s and an intensity of %s" % [env.glow_enabled, env.glow_hdr_threshold, BRIGHTEST_LIT, env.glow_hdr_scale, env.glow_intensity])
	var lookup: Texture3D = env.adjustment_color_correction as Texture3D
	_q.kit.need(problems, env.adjustment_enabled and lookup != null, "the adjustments are %s and the colour correction is %s" % [env.adjustment_enabled, env.adjustment_color_correction])
	var parameters: Dictionary = Grade.read_parameters(Kit27.GRADE_PARAMETERS_PATH)
	var size: int = int(parameters.get("size", 0))
	_q.kit.need(problems, lookup != null and size > 0 and lookup.get_width() == size and lookup.get_height() == size and lookup.get_depth() == size, "the lookup texture is %s, not %d texels a side" % [lookup, size])
	_q.kit.need(problems, lookup != null and lookup.resource_path == String(parameters.get("output", "")), "the Environment's lookup texture is %s, the tool writes %s" % [lookup.resource_path if lookup != null else "none", parameters.get("output", "")])
	measured.append("tonemap=%d exposure=%s white=%s contrast=%s" % [env.tonemap_mode, env.tonemap_exposure, env.tonemap_agx_white, env.tonemap_agx_contrast])
	measured.append("glow_threshold=%s" % env.glow_hdr_threshold)
	_q.kit.verdict("environment_data", problems, "map_01.tscn's Environment reads tone mapper %d (not Linear, %d) at exposure %s, AgX white %s and contrast %s; glow on for HDR above %s (the brightest lit value measured with Linear is %s) at scale %s and intensity %s; adjustments on (contrast %s, saturation %s) with a %d texel lookup texture, the file the tool writes" % [env.tonemap_mode, Environment.TONE_MAPPER_LINEAR, env.tonemap_exposure, env.tonemap_agx_white, env.tonemap_agx_contrast, env.glow_hdr_threshold, BRIGHTEST_LIT, env.glow_hdr_scale, env.glow_intensity, env.adjustment_contrast, env.adjustment_saturation, size])


## greybox_untouched (the story's Out of Scope): see the class doc.
func _greybox_untouched() -> void:
	var problems: PackedStringArray = []
	var env: Environment = Kit27.environment_of(Kit27.GREYBOX_PATH)
	_q.kit.need(problems, env != null, "greybox_field.tscn has no Environment")
	if env != null:
		_q.kit.need(problems, env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and not env.glow_enabled and not env.adjustment_enabled, "the greybox field's Environment reads tone mapper %d, glow %s, adjustments %s" % [env.tonemap_mode, env.glow_enabled, env.adjustment_enabled])
	_q.kit.verdict("greybox_untouched", problems, "the greybox field keeps its own Environment: Linear, no glow and no adjustments, as every older scenario measured it")


## The hue of a colour in degrees.
func _hue(colour: Color) -> float:
	return colour.h * FULL_TURN


## grade_data (AC-3, AC-5): see the class doc.
func _grade_data() -> void:
	var problems: PackedStringArray = []
	var parameters: Dictionary = Grade.read_parameters(Kit27.GRADE_PARAMETERS_PATH)
	_q.kit.need(problems, not parameters.is_empty(), "colour_grade.json could not be read")
	var moves: PackedStringArray = []
	var hues: Array[float] = []
	for player: int in 2:
		var team: Color = _k.team_colour(player)
		var graded: Color = Grade.grade(team, parameters)
		var moved: float = absf(fposmod(_hue(graded) - _hue(team) + FULL_TURN / 2.0, FULL_TURN) - FULL_TURN / 2.0)
		_q.kit.need(problems, moved <= HUE_MOVE_LIMIT, "the grade moves Player %d's Team colour %s to %s: %.2f degrees of hue" % [player + 1, team, graded, moved])
		moves.append("%.2f" % moved)
		hues.append(_hue(graded))
	var apart: float = absf(fposmod(hues[0] - hues[1] + FULL_TURN / 2.0, FULL_TURN) - FULL_TURN / 2.0)
	_q.kit.need(problems, apart >= HUE_APART, "the graded Team colours' hues are %.1f degrees apart" % apart)
	var white: Color = Grade.grade(Color.WHITE, parameters)
	var warm: Color = Grade.grade(Color(0.5, 0.5, 0.5), parameters)
	_q.kit.need(problems, white.r >= white.b and warm.r > warm.b, "the grade does not make white (%s) and a mid grey (%s) warmer" % [white, warm])
	measured.append("grade_hue_moves=%s apart=%.1f" % ["/".join(moves), apart])
	_q.kit.verdict("grade_data", problems, "the grade of colour_grade.json moves the Team colours' hue by %s degrees (at most %.0f) and leaves them %.1f degrees apart (at least %.0f), and makes a mid grey (%s) and white (%s) warmer: red over blue" % [", ".join(moves), HUE_MOVE_LIMIT, apart, HUE_APART, warm, white])


## lut_file (AC-3, AC-5): see the class doc.
func _lut_file() -> void:
	var problems: PackedStringArray = []
	var parameters: Dictionary = Grade.read_parameters(Kit27.GRADE_PARAMETERS_PATH)
	var path: String = String(parameters.get("output", ""))
	var file: String = FileAccess.get_file_as_bytes(path).hex_encode()
	_q.kit.need(problems, not file.is_empty(), "%s could not be read" % path)
	var layers: Array[Image] = Grade.build_layers(parameters)
	var at: int = 0
	var found_layers: int = 0
	for layer: Image in layers:
		var bytes: String = layer.get_data().hex_encode()
		var position: int = file.find(bytes, at)
		if position < at:
			problems.append("layer %d of the lookup texture is not in %s after layer %d" % [found_layers, path, found_layers - 1])
			continue
		found_layers += 1
		at = position + bytes.length()
	_q.kit.need(problems, found_layers == layers.size() and layers.size() == int(parameters.get("size", 0)), "%d of the %d layers are in the file" % [found_layers, layers.size()])
	measured.append("lut_layers=%d" % found_layers)
	_q.kit.verdict("lut_file", problems, "%s holds all %d layers of the lookup texture, in order, byte for byte what the tool writes from colour_grade.json (%d bytes in the file)" % [path.get_file(), found_layers, file.length() / 2])


## A copy of the shipped settings and of its material, changed by `change`, and what first_problem() says of it.
func _problem_after(shipped: SilhouetteSettings, change: Callable) -> String:
	var copy: SilhouetteSettings = shipped.duplicate() as SilhouetteSettings
	copy.mask_material = shipped.mask_material.duplicate() as StandardMaterial3D
	copy.sight_material = shipped.sight_material.duplicate() as StandardMaterial3D
	copy.fill_material = shipped.fill_material.duplicate() as StandardMaterial3D
	change.call(copy)
	return copy.first_problem()


## settings_refused (AC-4, AC-5): see the class doc. The unusable settings given to a Unit make it log one error, counted in expected_errors.
func _settings_refused() -> void:
	var problems: PackedStringArray = []
	var shipped: SilhouetteSettings = _k.settings()
	var cases: Array[Array] = [
		["no mask material", func(s: SilhouetteSettings) -> void: s.mask_material = null, "mask_material is not set"],
		["no sight material", func(s: SilhouetteSettings) -> void: s.sight_material = null, "sight_material is not set"],
		["no fill material", func(s: SilhouetteSettings) -> void: s.fill_material = null, "fill_material is not set"],
		["an opaque mask", func(s: SilhouetteSettings) -> void: s.mask_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED, "mask_material" + NOT_ALPHA],
		["a scissored mask", func(s: SilhouetteSettings) -> void: s.mask_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "mask_material" + NOT_ALPHA],
		["a hashed sight pass", func(s: SilhouetteSettings) -> void: s.sight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH, "sight_material" + NOT_ALPHA],
		["a mask with a next pass", func(s: SilhouetteSettings) -> void: s.mask_material.next_pass = StandardMaterial3D.new(), "mask_material has a next pass, which is drawn on its own and not in the order of the passes"],
		["a grown sight pass", func(s: SilhouetteSettings) -> void: s.sight_material.grow = true, "sight_material is grown, so it would not stand where its mesh is drawn"],
		["a mask that writes depth", func(s: SilhouetteSettings) -> void: s.mask_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS, "mask_material writes depth, which would hide what is drawn after it"],
		["a fill that adds", func(s: SilhouetteSettings) -> void: s.fill_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD, FILL_FLAT_PROBLEM],
		["a textured fill", func(s: SilhouetteSettings) -> void: s.fill_material.albedo_texture = GradientTexture1D.new(), FILL_FLAT_PROBLEM],
		["a visible sight pass", func(s: SilhouetteSettings) -> void: s.sight_material.albedo_color = Color(0.0, 0.0, 0.0, 0.5), "sight_material is visible: it only writes the stencil, so its alpha must be 0"],
		["a mask that reads", func(s: SilhouetteSettings) -> void: s.mask_material.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ, "mask_material" + WRITE_ALONE],
		["a sight pass that also writes on a depth fail", func(s: SilhouetteSettings) -> void: s.sight_material.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE | BaseMaterial3D.STENCIL_FLAG_WRITE_DEPTH_FAIL, "sight_material" + WRITE_ALONE],
		["no stencil on the mask", func(s: SilhouetteSettings) -> void: s.mask_material.stencil_mode = BaseMaterial3D.STENCIL_MODE_DISABLED, "mask_material" + WRITE_ALONE],
		["a mask that does not always write", func(s: SilhouetteSettings) -> void: s.mask_material.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_EQUAL, "mask_material does not always write (its stencil_compare is not always)"],
		["a depth-tested mask", func(s: SilhouetteSettings) -> void: s.mask_material.no_depth_test = false, "mask_material tests depth, so it would not mark everything the Unit covers"],
		["a sight pass with no depth test", func(s: SilhouetteSettings) -> void: s.sight_material.no_depth_test = true, "sight_material ignores depth, so it would mark the parts cover hides as in sight"],
		["an opaque fill", func(s: SilhouetteSettings) -> void: s.fill_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED, "fill_material" + NOT_ALPHA],
		["a shaded fill", func(s: SilhouetteSettings) -> void: s.fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL, "fill_material is shaded, so the silhouette would not be one flat colour"],
		["a depth-tested fill", func(s: SilhouetteSettings) -> void: s.fill_material.no_depth_test = false, "fill_material tests depth, so cover would hide the silhouette (no_depth_test is off)"],
		["a fill that is not a billboard", func(s: SilhouetteSettings) -> void: s.fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED, "fill_material is not a billboard, so the quad would not face each camera"],
		["a fill that writes", func(s: SilhouetteSettings) -> void: s.fill_material.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE, FILL_READ_PROBLEM],
		["a fill that reads not equal", func(s: SilhouetteSettings) -> void: s.fill_material.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL, FILL_READ_PROBLEM],
		["a fill that reads another value", func(s: SilhouetteSettings) -> void: s.fill_material.stencil_reference = s.sight_material.stencil_reference, "fill_material does not draw where the mask value is (its stencil_reference is not the mask pass's)"],
		["one stencil value for both writers", func(s: SilhouetteSettings) -> void: s.sight_material.stencil_reference = s.mask_material.stencil_reference, SAME_STENCIL_PROBLEM],
		["a mask value of 0", func(s: SilhouetteSettings) -> void: s.mask_material.stencil_reference = 0, STENCIL_PROBLEM],
		["a sight value of 0", func(s: SilhouetteSettings) -> void: s.sight_material.stencil_reference = 0, STENCIL_PROBLEM],
		["a sight pass drawn first", func(s: SilhouetteSettings) -> void: s.sight_material.render_priority = s.mask_material.render_priority, "the passes are not drawn in the order mask, sight, fill (render_priority must rise)"],
		["a fill drawn before the sight pass", func(s: SilhouetteSettings) -> void: s.fill_material.render_priority = s.sight_material.render_priority, "the passes are not drawn in the order mask, sight, fill (render_priority must rise)"],
		["one layer for both", func(s: SilhouetteSettings) -> void: s.player_2_layer = s.player_1_layer, SAME_LAYER_PROBLEM]]
	for fault: Array in SETTINGS_FAULTS:
		cases.append(["%s = %s" % [fault[0], fault[1]], func(s: SilhouetteSettings) -> void: s.set(fault[0], fault[1]), fault[2]])
	_q.kit.need(problems, shipped.first_problem().is_empty(), "the shipped settings read '%s'" % shipped.first_problem())
	for case: Array in cases:
		var said: String = _problem_after(shipped, case[1])
		_q.kit.need(problems, said == case[2], "%s reads '%s', expected '%s'" % [case[0], said, case[2]])
	# A Unit given unusable settings logs one error and is drawn as it was, and is dressed again when it is given usable ones.
	var unit: Unit = _k.unit(0)
	var broken: SilhouetteSettings = shipped.duplicate() as SilhouetteSettings
	broken.strength = 2.0
	unit.silhouette = broken
	var errors: int = _q.tokens.engine_log.errors.size()
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	expected_errors += 1
	var meshes: Array[MeshInstance3D] = _k.drawn_meshes(0)
	_q.kit.need(problems, _q.tokens.engine_log.errors.size() == errors + 1 and _k.copies_of(0).is_empty() and _k.fills_of(0) == 0 and not meshes.is_empty(), "a Unit given a strength of 2 logged %d errors (one expected), has %d copies and %d fill quads for its %d meshes" % [_q.tokens.engine_log.errors.size() - errors, _k.copies_of(0).size(), _k.fills_of(0), meshes.size()])
	unit.silhouette = shipped
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	_q.kit.need(problems, _q.tokens.engine_log.errors.size() == errors + 1 and _k.copies_of(0).size() == 2 * _k.drawn_meshes(0).size() and _k.fills_of(0) == 1 and not _k.copies_of(0).is_empty(), "given the shipped settings again the Unit has %d copies for %d meshes, %d fill quads and the log %d errors" % [_k.copies_of(0).size(), _k.drawn_meshes(0).size(), _k.fills_of(0), _q.tokens.engine_log.errors.size() - errors])
	measured.append("refusals=%d" % cases.size())
	_q.kit.verdict("settings_refused", problems, "first_problem() passes the shipped settings and names each of %d faults with its own sentence (a missing pass, a writer that is opaque, scissored, hashed, visible, reads, also writes on a depth fail, does not always write or has the wrong depth test, a pass with a next pass, a grow or a depth write, a fill that is opaque, shaded, added, textured, depth tested, not a billboard, that writes or reads another value or compare, stencil values of 0 or alike, passes not drawn in rising order, a strength under 0, over 1 or not a number, a layer that is not one bit or one for both Players, a fill quad with no size); a Unit given a strength of 2 logged one error and was drawn as before (no copy, no fill quad) and was dressed again when given the shipped settings" % cases.size())
