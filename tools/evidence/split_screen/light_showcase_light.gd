extends RefCounted
## The light moments of the light_showcase scenario (Story 027 AC-1, AC-2, AC-3): the same moments under each look of Map 01's Environment, so that the frames can be put side
## by side and measured: the salt flat from above in full sun (flat), a Base in the shade of its water tower from above (base), both Teams' Units close up in the sun
## (sun_close) and in the shade (shade_close), each under the looks of LOOKS: the look before the story (Linear, no glow, no grade), the look as the build ships it (AgX with the
## glow and the grade), the shipped look without the grade, and Filmic and ACES under the shipped glow and grade; the ford from above (ford); then the glow (glow: three probes whose
## emission is under, over and far over the threshold in front of each Player's Unit, with the glow on and off) and the HUD, which is in every frame. The measuring looks dark_a to
## dark_d (Linear at a quarter of the exposure, no glow, no grade) put no lit surface into the clipped range, so that a pixel's linear value divided by the exposure is the HDR
## value that was lit: the brightest of them over the flat and the ford is the brightest lit value of the Map, which the glow's threshold must lie above (AC-2). The Environment is changed here and nowhere else, for the
## moments only, and put back as the build ships it at the end. Units are topped up before each frame so that the HUD's numbers are the same in every frame of a moment. Run by
## light_showcase.gd, in the view from above only. Tooling only.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## The looks of the Environment, in the order they are shown: {name, mode (-1: as shipped), exposure (-1: as shipped), glow (true: as shipped), grade (true: as shipped)}.
const LOOKS: Array[Dictionary] = [
	{"name": "linear", "mode": Environment.TONE_MAPPER_LINEAR, "exposure": 1.0, "glow": false, "grade": false},
	{"name": "agx", "mode": -1, "exposure": -1.0, "glow": true, "grade": true},
	{"name": "agx_no_grade", "mode": -1, "exposure": -1.0, "glow": true, "grade": false},
	{"name": "filmic", "mode": Environment.TONE_MAPPER_FILMIC, "exposure": 1.0, "glow": true, "grade": true},
	{"name": "aces", "mode": Environment.TONE_MAPPER_ACES, "exposure": 1.0, "glow": true, "grade": true},
	{"name": "dark_a", "mode": Environment.TONE_MAPPER_LINEAR, "exposure": 0.25, "glow": false, "grade": false},
	{"name": "dark_b", "mode": Environment.TONE_MAPPER_LINEAR, "exposure": 0.25, "glow": false, "grade": false},
	{"name": "dark_c", "mode": Environment.TONE_MAPPER_LINEAR, "exposure": 0.25, "glow": false, "grade": false},
	{"name": "dark_d", "mode": Environment.TONE_MAPPER_LINEAR, "exposure": 0.25, "glow": false, "grade": false},
]
## The looks each moment shows.
const COMPARED: Array[String] = ["linear", "agx", "agx_no_grade", "filmic", "aces"]
const ON_THE_FLAT: Array[String] = ["linear", "agx", "agx_no_grade", "filmic", "aces", "dark_a"]
const AT_THE_FORD: Array[String] = ["dark_a", "dark_b", "dark_c", "dark_d", "linear", "agx"]
## The AgX settings tried on the flat to choose the data (explore(), LIGHT_MOMENTS=explore): [exposure, contrast, white].
const AGX_LADDER: Array[Array] = [[1.3, 1.5, 10.0], [1.3, 1.8, 10.0], [1.3, 2.1, 10.0], [1.3, 2.4, 10.0], [1.2, 2.1, 10.0], [1.4, 2.1, 10.0], [1.3, 2.1, 6.0], [1.3, 2.1, 16.29]]
## The ford from above: both Units on their own bank (the ford is 12 m wide at x = -40 and 40), the view's look-ahead putting the water in the picture.
const FORD_SPOTS: Array[Vector3] = [Vector3(-52.0, 0.0, -8.0), Vector3(52.0, 0.0, -8.0)]
## The type both Players' Units are in the light moments: the Truck, whose Team-painted cab and box fill much of a close-up.
const TYPE: int = Quick.TRUCK
## Where the Units stand in the sun: the salt flat west of the ford (Quick.LANE_SPOT), Player 2 at the mirror; and where in the shade of their water tower, open ground inside each
## Base that the tank shades from the Sun (found by LIGHT_PROBE=shade: the Sun comes from the west and the south, so Player 2's spot is not the mirror of Player 1's).
const SHADE_SPOTS: Array[Vector3] = [Vector3(-109.0, 0.0, -5.0), Vector3(117.0, 0.0, -5.0)]
## The close-up view: the offset of the camera from the Unit (right, up, behind) and what it looks at.
const CLOSE_OFFSET: Vector3 = Vector3(2.4, 1.7, 5.0)
const CLOSE_LOOK_HEIGHT: float = 1.0
## The probes of the glow moment: emission energies (the threshold of the data is 2: one under it, one over and one far over), the metres between them, how far ahead of the Unit
## the middle one is and how high.
const PROBE_ENERGIES: Array[float] = [1.2, 4.0, 8.0]
const PROBE_GAP: float = 3.0
const PROBE_AHEAD: float = 9.0
const PROBE_HEIGHT: float = 1.6
const PROBE_RADIUS: float = 0.5
## Ticks the Environment is given to show a new look, and the ticks a moment holds.
const LOOK_TICKS: int = 4
const HOLD_TICKS: int = 6

var _s: Object
var _q: Quick
var _env: Environment
var _shipped: Dictionary = {}
var _probes: Array[MeshInstance3D] = []
## The probes of each Player, in the order of PROBE_ENERGIES.
var _probes_of: Array[Array] = [[], []]


func _init(showcase: Object) -> void:
	_s = showcase
	_q = showcase.q


## The Sun of Map 01.
func _sun() -> DirectionalLight3D:
	return _q.harness.split.field.get_node("Sun") as DirectionalLight3D


## Lists, for LIGHT_PROBE=shade, the points around Base 1's water tower that the water tower or a wall shades from the Sun and where nothing stands, as PROBE lines.
func probe_shade() -> void:
	var towards: Vector3 = _sun().global_basis.z
	print("PROBE sun towards=%s" % towards)
	for x: int in range(94, 131):
		for z: int in range(-20, 21):
			var point: Vector3 = Vector3(float(x), 0.0, float(z))
			var lit: bool = _q.map.ray(point + Vector3.UP * 0.9, point + Vector3.UP * 0.9 + towards * 80.0, 97) == Vector3.INF
			var free: bool = _q.map.ray(point + Vector3.UP * 3.0, point + Vector3.UP * 0.2, 97) == Vector3.INF and _q.map.ray(point + Vector3.UP * 0.9 + Vector3.LEFT * 2.5, point + Vector3.UP * 0.9 + Vector3.RIGHT * 2.5, 97) == Vector3.INF and _q.map.ray(point + Vector3.UP * 0.9 + Vector3.FORWARD * 2.5, point + Vector3.UP * 0.9 + Vector3.BACK * 2.5, 97) == Vector3.INF
			if not lit and free:
				print("PROBE shade x=%d z=%d" % [x, z])


## The Environment's values as the build ships them, taken once.
func _snapshot() -> void:
	_env = _s.k.environment()
	_shipped = {"mode": _env.tonemap_mode, "exposure": _env.tonemap_exposure, "white": _env.tonemap_white, "glow": _env.glow_enabled, "grade": _env.adjustment_enabled}


## Puts the Environment in a look: the tone mapper and exposure it names (or the shipped ones), the glow and the grade on as shipped or off.
func _apply(look: Dictionary) -> void:
	_env.tonemap_mode = int(look["mode"]) if int(look["mode"]) >= 0 else _shipped["mode"]
	_env.tonemap_exposure = float(look["exposure"]) if float(look["exposure"]) >= 0.0 else _shipped["exposure"]
	_env.glow_enabled = bool(look["glow"]) and bool(_shipped["glow"])
	_env.adjustment_enabled = bool(look["grade"]) and bool(_shipped["grade"])


## Puts the Environment back as the build ships it.
func _restore() -> void:
	_env.tonemap_mode = _shipped["mode"]
	_env.tonemap_exposure = _shipped["exposure"]
	_env.glow_enabled = _shipped["glow"]
	_env.adjustment_enabled = _shipped["grade"]


## Tops both tanks up: the Fuel line of the HUD reads the same in every frame of a moment.
func _top_up() -> void:
	for unit: Unit in _q.units.units:
		unit.refuel(unit.fuel_capacity)


## A copy of the chase view's settings looking at a Unit from close by.
func _close_settings() -> ChaseCameraSettings:
	var close: ChaseCameraSettings = load("res://src/gameplay/camera/data/chase_camera_settings.tres").duplicate() as ChaseCameraSettings
	close.offset = CLOSE_OFFSET
	close.look_height = CLOSE_LOOK_HEIGHT
	return close


## The AgX settings of AGX_LADDER on the flat from above, one frame each, for choosing the exposure and contrast of the data: the shipped ones are put back afterwards.
func explore() -> void:
	if _s.pass_name != "above":
		return
	_snapshot()
	var spots: Array[Vector3] = [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)]
	await _q.map.stage([TYPE, TYPE], spots, [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	var saved: Dictionary = {"contrast": _env.tonemap_agx_contrast, "white": _env.tonemap_agx_white}
	for row: Array in AGX_LADDER:
		_env.tonemap_exposure = row[0]
		_env.tonemap_agx_contrast = row[1]
		_env.tonemap_agx_white = row[2]
		_top_up()
		await _q.kit.advance(LOOK_TICKS)
		_s.line("explore_e%s_c%s_w%s" % [row[0], row[1], row[2]], "AgX at exposure %s, contrast %s, white %s on the flat" % [row[0], row[1], row[2]])
		await _q.kit.advance(HOLD_TICKS)
	_env.tonemap_agx_contrast = saved["contrast"]
	_env.tonemap_agx_white = saved["white"]
	_restore()


## The moments. A coroutine: await it.
func play() -> void:
	if _s.pass_name != "above":
		return
	_snapshot()
	var spots: Array[Vector3] = [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)]
	var shaded: Array[Vector3] = SHADE_SPOTS
	var ways: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT]
	await _moment("flat", spots, ways, false, ON_THE_FLAT)
	await _moment("base", shaded, ways, false, COMPARED)
	await _moment("sun_close", spots, ways, true, COMPARED)
	await _moment("shade_close", shaded, ways, true, COMPARED)
	await _moment("ford", FORD_SPOTS, ways, false, AT_THE_FORD)
	await _glow(spots, ways)
	_restore()


## One place under every look: both Units staged (the close-up views on them when `close`), then each look shown and held for a frame.
func _moment(moment: String, spots: Array[Vector3], ways: Array[Vector3], close: bool, shown: Array[String]) -> void:
	await _q.map.stage([TYPE, TYPE], spots, ways, true)
	var saved: Array[ChaseCameraSettings] = []
	if close:
		for player: int in Kit.PLAYERS:
			saved.append(_q.units.cameras[player].settings)
			_q.units.cameras[player].settings = _close_settings()
			_q.units.cameras[player].snap_to_target()
	await _q.kit.advance(Looks.HOLD_TICKS)
	for look: Dictionary in LOOKS:
		if not shown.has(String(look["name"])):
			continue
		_apply(look)
		_top_up()
		await _q.kit.advance(LOOK_TICKS)
		_s.need(_s.in_pass_view() or close, "light_%s_%s: the cameras are on %s" % [moment, look["name"], _s.views()])
		_s.line("light_%s_%s" % [moment, look["name"]], "both Trucks %s under the %s look (mode %d, exposure %s, glow %s, grade %s)" % ["close up" if close else "from above", look["name"], _env.tonemap_mode, _env.tonemap_exposure, _env.glow_enabled, _env.adjustment_enabled])
		await _q.kit.advance(HOLD_TICKS)
	_restore()
	if close:
		for player: int in Kit.PLAYERS:
			_q.units.cameras[player].settings = saved[player]
			_q.units.cameras[player].snap_to_target()
		await _q.kit.advance(Looks.HOLD_TICKS)


## The probes in front of each Unit: three emissive spheres in a row across its view, a little way ahead and above the ground.
func _make_probes() -> void:
	for player: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[player]
		var ahead: Vector3 = -unit.global_basis.z
		var across: Vector3 = unit.global_basis.x
		for index: int in PROBE_ENERGIES.size():
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color.BLACK
			material.emission_enabled = true
			material.emission = Color.WHITE
			material.emission_energy_multiplier = PROBE_ENERGIES[index]
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = PROBE_RADIUS
			sphere.height = PROBE_RADIUS * 2.0
			var probe: MeshInstance3D = MeshInstance3D.new()
			probe.mesh = sphere
			probe.material_override = material
			probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_q.harness.split.field.add_child(probe)
			probe.global_position = unit.global_position + ahead * PROBE_AHEAD + across * (float(index) - 1.0) * PROBE_GAP + Vector3.UP * PROBE_HEIGHT
			_probes.append(probe)
			_probes_of[player].append(probe)


## Where the probes are in each Player's view, in the view's own pixels, for the measuring of the frames: "p1=(x,y),(x,y),(x,y) p2=..." and the views' sizes.
func _probe_pixels() -> String:
	var parts: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var camera: Camera3D = _q.units.cameras[player]
		var points: PackedStringArray = []
		for probe: MeshInstance3D in _probes_of[player]:
			var at: Vector2 = camera.unproject_position(probe.global_position)
			points.append("(%.1f,%.1f)" % [at.x, at.y])
		parts.append("p%d=%s view=%s" % [player + 1, ",".join(points), camera.get_viewport().get_visible_rect().size])
	return " ".join(parts)


## The glow: the probes in front of each Unit with the glow on as shipped and off, and the same without any probe, so that the frames show what blooms and what does not.
func _glow(spots: Array[Vector3], ways: Array[Vector3]) -> void:
	await _q.map.stage([TYPE, TYPE], spots, ways, true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	_apply(LOOKS[1])
	_top_up()
	await _q.kit.advance(LOOK_TICKS)
	_s.line("glow_none_on", "both Units from above on the flat, no probe, the glow on as shipped (threshold %s)" % _env.glow_hdr_threshold)
	await _q.kit.advance(HOLD_TICKS)
	_env.glow_enabled = false
	await _q.kit.advance(LOOK_TICKS)
	_s.line("glow_none_off", "the same moment with the glow off: nothing blooms, so this frame is the one before it, pixel for pixel")
	await _q.kit.advance(HOLD_TICKS)
	_env.glow_enabled = true
	_make_probes()
	await _q.kit.advance(LOOK_TICKS)
	_s.line("glow_probes_on", "three probes of emission %s in front of each Unit, the glow on as shipped (threshold %s) %s" % [PROBE_ENERGIES, _env.glow_hdr_threshold, _probe_pixels()])
	await _q.kit.advance(HOLD_TICKS)
	_env.glow_enabled = false
	await _q.kit.advance(LOOK_TICKS)
	_s.line("glow_probes_off", "the same probes, the glow off")
	await _q.kit.advance(HOLD_TICKS)
	for probe: MeshInstance3D in _probes:
		probe.queue_free()
	_probes.clear()
	_probes_of = [[], []]
	_restore()
	await _q.kit.advance(LOOK_TICKS)
