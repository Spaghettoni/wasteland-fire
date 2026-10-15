extends RefCounted
## What Map 01 holds and what the flying height is, for the heights scenario (Story 020 AC-1 and AC-3): scan (every
## solid collider of the Map, found by walking the running Map, sorted into its Height by its physics layer alone and
## listed with its layer, its top and its drawn top), masks (no layer added and no mask changed) and tops (the drawn
## top of every ground Unit's body, with the thin parts listed apart, and of every low piece, the flying height the
## rule gives, the Gyrocopter's drawn band, the dressing above 2 m, and the kit fallback). Run by heights.gd. Tooling
## only. Every number comes from the game's data and the meshes; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The masks the story keeps (AC-1): the ground types' 99, the Gyrocopter's 1, the Shots' 83, the Turret's sight extra 32 and
## the Mines' open-ground probe 97; the seven named physics layers.
const GROUND_MASK: int = 99
const GYRO_MASK: int = 1
const SHOT_MASK: int = 83
const SIGHT_EXTRA: int = 32
const PROBE_MASK: int = 97
const NAMED_LAYERS: int = 7
## Story 015's figure for the flying height before rounding (the Truck's pod 2.2045 + the clearance), metres.
const RECORD_015: float = 2.454
const MAP_PATH: String = "res://src/gameplay/maps/map_01/map_01.tscn"
const KIT_MODEL: String = "res://src/gameplay/units/models/gyrocopter_kit_model.tscn"

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick
## One entry per solid collider: {path, layer, top, drawn, kind, height, tall}.
var rows: Array[Dictionary] = []
## The tallest drawn top of a low piece, and of a ground Unit's body, and the Truck's antenna, metres.
var low_top: float = 0.0
var body_top: float = 0.0
var antenna_top: float = 0.0


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_scan()
	_masks()
	_tops()
	await _kit_fallback()


## scan (AC-1): every solid collider of Map 01 sits in one Height by its physics layer alone, no Base wall, Garage wall or scrap
## wall is on the map layer, no low piece is taller than 2 m, every Tall piece is, and the Floor and the sea edge are
## high and no Tall piece. Prints one SCAN line a collider: its layer, top, drawn top and Height.
func _scan() -> void:
	var problems: PackedStringArray = []
	rows = _k.solid_rows(_k.map())
	var counts: Array[int] = []
	var tops: Array = []
	for family: Array in Kit20.FAMILIES:
		counts.append(0)
		tops.append([INF, -INF])
	for row: Dictionary in rows:
		var found: int = _k.family_of(row["path"])
		_q.kit.need(problems, found >= 0, "%s matches %s family" % [row["path"], "no" if found == -1 else "more than one"])
		if found < 0:
			continue
		var family: Array = Kit20.FAMILIES[found]
		row["kind"] = family[0]
		row["height"] = Kit20.height_of(int(row["layer"]))
		row["tall"] = family[4]
		counts[found] += 1
		tops[found] = [minf(tops[found][0], row["top"]), maxf(tops[found][1], row["top"])]
		_q.kit.need(problems, row["height"] == family[3], "%s (layer %d) is %s, the story puts a %s in the %s Height" % [row["path"], row["layer"], row["height"] if row["height"] != "" else "in no Height or in both", family[0], family[3]])
		if family[3] == "low":
			_q.kit.need(problems, row["top"] <= Kit20.LOW_TOP_MAX + Kit20.TOLERANCE and row["drawn_top"] <= Kit20.LOW_TOP_MAX + Kit20.TOLERANCE, "%s is %.3f m tall (drawn %.3f), over the 2 m of a low piece" % [row["path"], row["top"], row["drawn_top"]])
			low_top = maxf(low_top, row["drawn_top"])
		elif family[4]:
			_q.kit.need(problems, row["top"] > Kit20.LOW_TOP_MAX, "%s is %.3f m tall, no taller than a low piece" % [row["path"], row["top"]])
		print("SCAN %s layer=%d top=%.3f drawn=%s height=%s%s" % [row["path"], row["layer"], row["top"], "none" if row["drawn_top"] == -INF else "%.3f" % row["drawn_top"], row["height"], " tall" if row["tall"] else ""])
	var listed: PackedStringArray = []
	var total: int = 0
	var tall_count: int = 0
	for index: int in Kit20.FAMILIES.size():
		_q.kit.need(problems, counts[index] == Kit20.FAMILIES[index][2], "%d %s colliders, the Map has %d" % [counts[index], Kit20.FAMILIES[index][0], Kit20.FAMILIES[index][2]])
		total += counts[index]
		tall_count += counts[index] if Kit20.FAMILIES[index][4] else 0
		listed.append("%d %s (%s, %.2f to %.2f m)" % [counts[index], Kit20.FAMILIES[index][0], "Tall piece" if Kit20.FAMILIES[index][4] else Kit20.FAMILIES[index][3], tops[index][0], tops[index][1]])
	_q.kit.need(problems, total == rows.size(), "%d solid colliders found, %d sorted" % [rows.size(), total])
	measured.append("scan=%d low_top=%.3f tall=%d" % [rows.size(), low_top, tall_count])
	_q.kit.verdict("scan", problems, "%d solid colliders on Map 01, each in exactly one Height by its physics layer alone (low: cliffs_water 32 and cover 64; high: the map layer 1) and none in both: %s; no Base wall, Garage wall or scrap wall is on the map layer (all 88 panels are low, on 64); the tallest low piece is %.3f m, and the %d Tall pieces (towers, legs, tanks, Turrets) are all taller than 2 m; the Floor and the sea edge are high and no Tall piece" % [rows.size(), "; ".join(listed), low_top, tall_count])


## masks (AC-1): no layer is added and no mask changes: the seven named physics layers, the ground types' 99, the Gyrocopter's
## 1 on layer 16, the Shots' 83, the Turret's sight extra 32 and the Mines' probe 97.
func _masks() -> void:
	var problems: PackedStringArray = []
	var named: int = 0
	for number: int in range(1, 33):
		named += 1 if not String(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % number, "")).is_empty() else 0
	_q.kit.need(problems, named == NAMED_LAYERS, "%d named 3D physics layers, not %d" % [named, NAMED_LAYERS])
	var reads: PackedStringArray = []
	for stats: UnitStats in _q.controller.rules.unit_types:
		var want: int = GYRO_MASK if stats.can_fly else GROUND_MASK
		_q.kit.need(problems, stats.collision_mask == want, "%s's mask is %d, not %d" % [stats.type_id, stats.collision_mask, want])
		reads.append("%s %d" % [stats.type_id, stats.collision_mask])
	_q.kit.need(problems, _q.controller.rules.shot_collision_mask == SHOT_MASK, "the Shot mask is %d, not %d" % [_q.controller.rules.shot_collision_mask, SHOT_MASK])
	var turret: TurretStats = load("res://src/gameplay/defences/data/turret_stats.tres") as TurretStats
	var mines: MineSettings = load("res://src/gameplay/mines/data/mine_settings.tres") as MineSettings
	_q.kit.need(problems, turret.sight_extra_mask == SIGHT_EXTRA, "the Turret's sight adds %d, not %d" % [turret.sight_extra_mask, SIGHT_EXTRA])
	_q.kit.need(problems, mines.open_ground_mask == PROBE_MASK, "the Mines' probe reads %d, not %d" % [mines.open_ground_mask, PROBE_MASK])
	_q.kit.verdict("masks", problems, "%d named 3D physics layers (map, units, zones, flags, gyrocopters, cliffs_water, cover), none added; masks (%s), the Shot mask %d, the Turret's sight adds %d and the Mines' probe reads %d: no mask changed" % [named, ", ".join(reads), _q.controller.rules.shot_collision_mask, turret.sight_extra_mask, mines.open_ground_mask])


## tops (AC-3): the drawn top of each ground Unit's body (the Truck's pod the tallest) with the thin parts listed apart,
## the flying height the rule gives (the highest of those and of the low pieces, the antenna not counted, plus the
## clearance, rounded up to 0.05 m) against the one the model's scene gives, and the Gyrocopter's drawn band at it.
func _tops() -> void:
	var problems: PackedStringArray = []
	var reads: PackedStringArray = []
	var thin_reads: PackedStringArray = []
	for type_index: int in _q.controller.rules.unit_types.size():
		var stats: UnitStats = _q.units.stats(type_index)
		if stats.can_fly:
			continue
		var tops: Dictionary = _k.ground_tops(type_index)
		body_top = maxf(body_top, tops["body"])
		reads.append("%s %.4f" % [stats.type_id, tops["body"]])
		for thin_name: String in tops["thin"]:
			thin_reads.append("%s's %s %.4f" % [stats.type_id, thin_name, tops["thin"][thin_name]])
			antenna_top = maxf(antenna_top, tops["thin"][thin_name]) if stats.type_id == &"truck" else antenna_top
	var tallest: float = maxf(body_top, low_top)
	var rule_height: float = ceilf((tallest + Kit20.CLEARANCE) / Kit20.ROUND_STEP - 1e-9) * Kit20.ROUND_STEP
	var with_antenna: float = ceilf((antenna_top + Kit20.CLEARANCE) / Kit20.ROUND_STEP - 1e-9) * Kit20.ROUND_STEP
	_q.kit.need(problems, absf(rule_height - _k.height) <= Kit20.TOLERANCE, "the rule gives %.3f m and the model's scene %.4f m" % [rule_height, _k.height])
	_q.kit.need(problems, absf(tallest + Kit20.CLEARANCE - RECORD_015) <= Kit20.TOLERANCE, "the tallest top %.4f plus the clearance is %.4f, story 015 measured %.3f" % [tallest, tallest + Kit20.CLEARANCE, RECORD_015])
	_q.kit.need(problems, body_top > low_top, "the tallest ground Unit's body (%.4f) is not above the low pieces (%.3f): the Unit would not set the height" % [body_top, low_top])
	var scene: PackedScene = _q.units.stats(Kit20.GYRO).model
	var gyro: MeshUnitModel = scene.instantiate() as MeshUnitModel
	var file: AABB = MeshUnitModel.hull_of(gyro.mesh_scene, INF)
	var rotor: float = gyro.hover_height + gyro.offset.y + gyro.model_scale * file.end.y
	var lowest_platform: float = INF
	for base_index: int in Kit20.Kit.PLAYERS:
		var platform: MeshInstance3D = _k.k.k.m.w.bases[base_index].get_node("WaterTower/Platform") as MeshInstance3D
		lowest_platform = minf(lowest_platform, (platform.global_transform * platform.get_aabb()).position.y)
	_q.kit.need(problems, rotor < lowest_platform, "the rotor's top %.3f m is not under the water towers' platforms (%.3f)" % [rotor, lowest_platform])
	var shipped: bool = not gyro.rise_over_cliffs and gyro.rise_mask == 0 and gyro.rise_body_mask == 0 and gyro.rise_rate == 0.0 and gyro.settle_rate == 0.0
	_q.kit.need(problems, shipped, "the shipped Gyrocopter scene still has rise values (rise_over_cliffs %s, rise_mask %d, rise_rate %.1f)" % [gyro.rise_over_cliffs, gyro.rise_mask, gyro.rise_rate])
	gyro.free()
	var dressing: PackedStringArray = []
	var over_dressing: float = INF
	var parts: Array[Node] = []
	var dressing_node: Node = _k.map().get_node_or_null("Dressing")
	if dressing_node != null:
		parts.append_array(dressing_node.find_children("*", "GeometryInstance3D", true, false))
	for part: Node in parts:
		var top: float = Kit20.drawn_top(part)
		if top > Kit20.LOW_TOP_MAX and not (part.get_parent() is CollisionObject3D):
			dressing.append("%s %.3f" % [_k.map().get_path_to(part), top])
			over_dressing = minf(over_dressing, snappedf(_k.height - top, 0.0001))
	_q.kit.need(problems, over_dressing >= -Kit20.TOLERANCE, "the Gyrocopter's model is drawn %.4f m into a prop of the dressing" % -over_dressing)
	measured.append("flying_height=%.4f rule=%.2f body_top=%.4f rotor=%.4f" % [_k.height, rule_height, body_top, rotor])
	_q.kit.verdict("tops", problems, "drawn tops from the mesh files and the Map: ground Units' bodies (%s; thin parts apart: %s), the tallest low piece %.3f m; the tallest of them (the Truck's pod %.4f m, the antenna not counted) plus the %.2f m clearance is %.4f m (story 015 measured %.3f), rounded up to %.2f m is %.3f m, the lowest drawn point of the Gyrocopter's model in its scene (%.4f m); with the antenna (%.4f m) it would be %.4f m, %.3f m rounded up; the Gyrocopter's drawn band at it is %.4f to %.4f m, its rotor %.4f m under the water towers' platforms (%.3f m); the scene has no rise values; drawn above 2 m with no collider: %s (the model's lowest point stands %.3f m over the top of each: it touches, it is not drawn through them)" % [
		", ".join(reads), ", ".join(thin_reads), low_top, body_top, Kit20.CLEARANCE, tallest + Kit20.CLEARANCE, RECORD_015, Kit20.ROUND_STEP, rule_height, _k.height, antenna_top, antenna_top + Kit20.CLEARANCE, with_antenna, _k.height, rotor, lowest_platform - rotor, lowest_platform, ", ".join(dressing) if not dressing.is_empty() else "nothing", over_dressing])


## kit_fallback (AC-9): the kit Gyrocopter scene, which a type's model can be pointed back at, stands at the same flying
## height with no rise: instanced under a Unit-like node in the tree, its lowest drawn point is within 1 mm of the shipped
## model's and its model does no physics tick.
func _kit_fallback() -> void:
	var problems: PackedStringArray = []
	var holder: Node3D = Node3D.new()
	_k.map().add_child(holder)
	var model: UnitModel = (load(KIT_MODEL) as PackedScene).instantiate() as UnitModel
	holder.add_child(model)
	await _q.kit.advance(2)
	var low: float = INF
	for mesh: MeshInstance3D in Quick.body_meshes(model):
		low = minf(low, (mesh.global_transform * mesh.get_aabb()).position.y)
	_q.kit.need(problems, absf(low - _k.height) <= Kit20.TOLERANCE, "the kit Gyrocopter's lowest point is %.4f m, the flying height %.4f" % [low, _k.height])
	_q.kit.need(problems, not model.rise_over_cliffs and not model.is_physics_processing(), "the kit Gyrocopter rises (%s) or does a physics tick (%s)" % [model.rise_over_cliffs, model.is_physics_processing()])
	holder.queue_free()
	_q.kit.verdict("kit_fallback", problems, "the kit fallback scene (gyrocopter_kit_model.tscn) draws the Gyrocopter with its lowest point at %.4f m (the flying height %.4f), rise_over_cliffs off and no physics tick" % [low, _k.height])
