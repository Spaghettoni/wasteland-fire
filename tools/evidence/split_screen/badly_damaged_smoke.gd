extends RefCounted
## The smoke of a badly damaged Unit (Story 017 AC-4): none until the first state, born in the node of the Unit's Model on the tick the
## state begins (a real Shot brings each type to its edge), rising from the top centre of the drawn body (the world box of its meshes
## for the ground types, the hull up to the rotor for the Gyrocopter), thin and dark grey with no Team colour and no shadow, on the
## layer both views draw, in the one world both views share; a column over a standing Unit and a trail behind a moving one; and a
## Gyrocopter risen over a container and over the canyon rock smokes from its drawn model, above the piece, never from the floor. Run
## by badly_damaged.gd. Tooling only. Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-4.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## Hit points above its edge a victim is left with, so that one Motorbike Shot (5) lands exactly on the edge.
const ABOVE_EDGE: float = 5.0
## The pieces a Gyrocopter is put over (explosions_where.gd's), and the ticks its model takes to rise.
const COVER: String = "Cover/Containers/ContainerWest"
const RIDGE: String = "Cliffs/RockCanyonSouth"
const RISE_WAIT: int = 90
## Metres a point may be off by, and the share of a trail's length it may be off by.
const NEAR: float = 0.02
const TRAIL_TOLERANCE: float = 0.08
## Ticks a Unit drives for the trail, the largest error of a puff's fade and size (float32), and the fade the oldest puff must have reached.
const DRIVE_TICKS: int = 150
const SHAPE_TOLERANCE: float = 0.001
const OLDEST_FADE: float = 0.9

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _begins_and_looks()
	await _column_and_trail()
	await _over_the_pieces()


## The top centre of a Unit's drawn body in the world: the Model's hull (what the rise reads) at its top, in the Model's frame.
func _top_centre(unit: Unit) -> Vector3:
	var model: Node3D = unit.get_node(String(Unit.MODEL_NODE_NAME)) as Node3D
	var hull: AABB = model.get(&"_hull")
	return model.global_transform * Vector3(hull.get_center().x, hull.end.y, hull.get_center().z)


## A victim of a type is left five hit points above its edge with Player 1's Motorbike facing it, and one real Shot lands: the
## reading at the first tick after the hit, {smoking, shown, node, origin, hit_frame, now}.
func _shot_to_the_edge(type: int) -> Dictionary:
	await _k.face_off(Quick.MOTORBIKE, type)
	var victim: Unit = _k.unit(1)
	victim.apply_damage(victim.hit_points - (_k.edge_of(type) + ABOVE_EDGE))
	var before_node: bool = _k.smoke(1) != null
	var mark: int = _k.changes.size()
	await _q.tokens.shoot(0)
	for _wait: int in Units.HIT_LIMIT_TICKS:
		if _k.changes.size() > mark:
			break
		await _q.kit.tick()
	var smoke: BadlyDamagedSmoke = _k.smoke(1)
	var seen: Dictionary = {"node_before": before_node, "node": smoke != null, "frame": Engine.get_physics_frames(), "hit_frame": -1,
		"smoking": _k.smoking(1), "shown": smoke.shown_count() if smoke != null else -1, "hp": victim.hit_points,
		"origin": smoke.puffs()[0].global_position if smoke != null else Vector3.INF}
	if _k.changes.size() > mark:
		seen["hit_frame"] = _k.changes[mark]["frame"]
	return seen


## smoke_begins_at_the_hit and smoke_from_the_drawn_body, for each type.
func _begins_and_looks() -> void:
	var begin: PackedStringArray = []
	var body: PackedStringArray = []
	var problems: PackedStringArray = []
	var look: PackedStringArray = []
	var seen_material: Material
	for type: int in 4:
		var seen: Dictionary = await _shot_to_the_edge(type)
		var victim: Unit = _k.unit(1)
		var name: String = Units.TYPE_IDS[type]
		_q.kit.need(problems, not seen["node_before"] and seen["node"] and seen["smoking"] and seen["shown"] == 1, "%s: node before the state %s, after %s, smoking %s, %s puffs on the tick" % [name, seen["node_before"], seen["node"], seen["smoking"], seen["shown"]])
		_q.kit.need(problems, victim.hit_points == _k.edge_of(type) and seen["hit_frame"] >= 0 and seen["frame"] - seen["hit_frame"] == 1, "%s: the hit left %s hit points and the smoke was read %d frames after the change" % [name, victim.hit_points, seen["frame"] - seen["hit_frame"]])
		var smoke: BadlyDamagedSmoke = _k.smoke(1)
		_q.kit.need(problems, smoke != null and smoke.get_parent().name == Unit.MODEL_NODE_NAME and smoke.get_parent().get_parent() == victim, "%s: the smoke is not a child of the Unit's Model" % name)
		if smoke == null:
			continue
		var top: Vector3 = _top_centre(victim)
		var box: AABB = Quick.model_box(victim)
		var from_body: bool = seen["origin"].distance_to(top) <= NEAR and smoke.global_position.distance_to(top) <= NEAR
		_q.kit.need(problems, from_body, "%s: the first puff stands at %s, the top centre of the body is %s" % [name, seen["origin"], top])
		if type != Quick.GYROCOPTER:
			_q.kit.need(problems, absf(top.y - box.end.y) <= NEAR and absf(top.x - box.get_center().x) <= NEAR and absf(top.z - box.get_center().z) <= NEAR, "%s: the top centre %s is not the top of the world box of its meshes %s" % [name, top, box])
		else:
			_q.kit.need(problems, top.y < box.end.y and top.y - victim.global_position.y > victim.get_node(String(Unit.MODEL_NODE_NAME)).hover_height, "gyrocopter: the smoke's origin %s is not between its hover and the rotor's top %s" % [top, box.end.y])
		body.append("%s %.2f m up from the floor, the body's top centre" % [name, seen["origin"].y - victim.global_position.y])
		await _q.kit.advance(smoke.life_ticks() + smoke.interval_ticks())
		_q.kit.need(problems, smoke.shown_count() >= smoke.life_ticks() / smoke.interval_ticks() and smoke.shown_count() <= smoke.puffs().size(), "%s: %d puffs of %d show in the steady state" % [name, smoke.shown_count(), smoke.puffs().size()])
		for puff: MeshInstance3D in smoke.puffs():
			var material: StandardMaterial3D = puff.material_override as StandardMaterial3D
			seen_material = material if seen_material == null else seen_material
			_q.kit.need(problems, material != null and material == seen_material and material != victim.team_material, "%s: a puff wears %s (not the one shared neutral material, or the Team's)" % [name, material])
			_q.kit.need(problems, puff.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (puff.layers & 1) != 0 and (puff.layers & 2) == 0 and not puff.is_in_group(Unit.TEAM_COLOUR_GROUP), "%s: a puff casts a shadow (%s), or is off layer 1 (%s), or is in the Team colour group" % [name, puff.cast_shadow, puff.layers])
		begin.append("%s: no node before, on the tick of the hit %d puff in the Model's node (%d frame after the change)" % [name, seen["shown"], seen["frame"] - seen["hit_frame"]])
	var colour: Color = seen_material.albedo_color
	_q.kit.need(problems, absf(colour.r - colour.g) <= 0.001 and absf(colour.g - colour.b) <= 0.001 and colour.r < 0.5 and colour.a < 1.0, "the smoke's colour %s is not a dark, thin grey" % colour)
	look.append("colour %s, one material shared by every puff of every Unit, no shadow, layer 1 only" % colour)
	_q.kit.verdict("smoke_begins_at_the_hit_from_the_drawn_body", problems, " | ".join(begin) + " | " + " | ".join(body) + " | " + " | ".join(look))
	await _both_views()


## smoke_in_both_views: both Units smoking at once, in the one world both Players' cameras show, and under the cull mask of the
## view from above (the shipped) and of the chase view.
func _both_views() -> void:
	var problems: PackedStringArray = []
	await _k.e.fresh()
	await _k.t.clear(0)
	_q.units.retype(0, Quick.TRUCK, Vector3(-Kit17.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.GYROCOPTER, Vector3(Kit17.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit17.SETTLE)
	for player: int in Kit17.Kit.PLAYERS:
		_k.unit(player).apply_damage(_k.unit(player).hit_points - _k.edge_of(Quick.TRUCK if player == 0 else Quick.GYROCOPTER))
	await _q.kit.advance(2)
	var modes: PackedStringArray = []
	for player: int in Kit17.Kit.PLAYERS:
		_q.kit.need(problems, _k.smoking(player), "Player %d's Unit does not smoke" % (player + 1))
		for camera: ChaseCamera in _q.units.cameras:
			var settings: ChaseCameraSettings = camera.settings
			var masks: Array[int] = [camera.cull_mask]
			camera.settings = Kit17.Kit.Harness.CHASE_CAMERA_SETTINGS
			masks.append(camera.cull_mask)
			camera.settings = settings
			for puff: MeshInstance3D in _k.smoke(player).puffs():
				_q.kit.need(problems, puff.get_world_3d() == camera.get_world_3d() and (masks[0] & puff.layers) != 0 and (masks[1] & puff.layers) != 0, "Player %d's puff is not drawn by a camera (masks %s, layers %s)" % [player + 1, masks, puff.layers])
			modes.append("%d/%d" % masks)
	_q.kit.verdict("smoke_in_both_views_on_both_units", problems, "a badly damaged Truck (Player 1) and Gyrocopter (Player 2) smoke together; both cameras show the one world, and their cull masks (view from above / chase view: %s) both draw render layer 1" % ", ".join(modes))


## The node of a live puff of _live(): the pool's puff at the position the record was read from.
func _puff_of(smoke: BadlyDamagedSmoke, record: Dictionary) -> MeshInstance3D:
	for puff: MeshInstance3D in smoke.puffs():
		if puff.global_position.is_equal_approx(record["at"]):
			return puff
	return null


## The live puffs of a smoke in the order they were born: [{born, origin, at}].
func _live(smoke: BadlyDamagedSmoke) -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for index: int in smoke.puffs().size():
		if smoke.get(&"_born")[index] >= 0:
			live.append({"born": smoke.get(&"_born")[index], "origin": smoke.get(&"_origins")[index], "at": smoke.puffs()[index].global_position})
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["born"] < b["born"])
	return live


## smoke_is_a_column_standing_and_a_trail_moving: the puffs of a standing Unit begin over one place and rise at the scene's speed;
## those of a Unit driving at its steady speed are left behind where it was, one interval of its speed apart.
func _column_and_trail() -> void:
	var problems: PackedStringArray = []
	await _k.make_floor()
	await _k.on_floor(0, _q.small_tank(Quick.MOTORBIKE, 1.0))
	var unit: Unit = _k.unit(0)
	unit.apply_damage(unit.hit_points - _k.edge_of(Quick.MOTORBIKE))
	var smoke: BadlyDamagedSmoke = _k.smoke(0)
	await _q.kit.advance(smoke.life_ticks())
	var column: Array[Dictionary] = _live(smoke)
	var spread: float = 0.0
	var rise_error: float = 0.0
	for puff: Dictionary in column:
		spread = maxf(spread, (puff["origin"] as Vector3).distance_to(column[0]["origin"]))
		var age: int = int(smoke.get(&"_ticks")) - int(puff["born"])
		rise_error = maxf(rise_error, absf((puff["at"] as Vector3).y - (puff["origin"] as Vector3).y - smoke.rise_speed * float(age) / 60.0))
	_q.kit.need(problems, column.size() >= smoke.puffs().size() - 1 and spread <= NEAR and rise_error <= NEAR, "a standing Unit's %d puffs began %.3f m apart and are %.3f m off the scene's rise" % [column.size(), spread, rise_error])
	var shape_error: float = 0.0
	var oldest_fade: float = 0.0
	for puff: Dictionary in column:
		var node: MeshInstance3D = smoke.puffs()[smoke.puffs().find(_puff_of(smoke, puff))]
		var progress: float = float(int(smoke.get(&"_ticks")) - int(puff["born"])) / float(smoke.life_ticks())
		var fade: float = clampf((progress - smoke.fade_start_fraction) / (1.0 - smoke.fade_start_fraction), 0.0, 1.0)
		var size: float = smoke.puff_radius * lerpf(1.0, smoke.puff_growth, progress)
		shape_error = maxf(shape_error, maxf(absf(node.transparency - fade), absf(node.scale.x - size)))
		oldest_fade = maxf(oldest_fade, node.transparency)
	_q.kit.need(problems, shape_error <= SHAPE_TOLERANCE and oldest_fade > OLDEST_FADE, "the puffs are %.4f off the scene's fade and growth, the faintest at %.2f" % [shape_error, oldest_fade])
	await _k.series(0, 1, 0, DRIVE_TICKS)
	var trail: Array[Dictionary] = _live(smoke)
	var speed: float = unit.current_speed
	var gap: float = speed * float(smoke.interval_ticks()) / 60.0
	var worst_gap: float = 0.0
	var lateral: float = 0.0
	for index: int in range(1, trail.size()):
		worst_gap = maxf(worst_gap, absf((trail[index]["origin"] as Vector3).distance_to(trail[index - 1]["origin"]) - gap))
		lateral = maxf(lateral, absf((trail[index]["origin"] as Vector3).z - (trail[0]["origin"] as Vector3).z))
	var length: float = (trail[-1]["origin"] as Vector3).x - (trail[0]["origin"] as Vector3).x
	_q.kit.need(problems, absf(speed - _k.share_speed(Quick.MOTORBIKE, true)) <= Kit17.TOLERANCE and worst_gap <= gap * TRAIL_TOLERANCE and lateral <= NEAR, "the trail's puffs are up to %.3f m off %.3f m apart (lateral %.3f)" % [worst_gap, gap, lateral])
	_q.kit.need(problems, unit.global_position.x - (trail[0]["origin"] as Vector3).x >= length and length >= gap * (trail.size() - 2), "the trail %.2f m long does not lie behind the Unit" % length)
	_q.kit.verdict("smoke_is_a_column_standing_and_a_trail_moving", problems, "a standing Motorbike: %d puffs begin over one place (%.3f m) and rise %.2f m/s; at %.1f m/s it leaves puffs %.2f m apart (one every %d ticks), a trail %.1f m long behind it" % [column.size(), spread, smoke.rise_speed, speed, gap, smoke.interval_ticks(), length])
	_k.free_floor()


## gyrocopter_smoke_over_cliff_and_cover: risen over a container and over the canyon rock, the smoke starts at the drawn
## model's top, above the piece, and not at the floor under it.
func _over_the_pieces() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for path: String in [COVER, RIDGE]:
		await _k.e.fresh()
		await _k.t.clear(0)
		var piece: Node3D = _q.map.find(path) as Node3D
		var shape: GeometryInstance3D = piece as GeometryInstance3D
		if shape == null:
			shape = piece.get_node("Mesh") as GeometryInstance3D
		var box: AABB = shape.global_transform * shape.get_aabb()
		await _q.put(1, _q.units.stats(Quick.GYROCOPTER), Vector3(box.get_center().x, 0.0, box.get_center().z), Vector3.RIGHT)
		await _q.kit.advance(RISE_WAIT)
		var unit: Unit = _k.unit(1)
		unit.apply_damage(unit.hit_points - _k.edge_of(Quick.GYROCOPTER))
		var smoke: BadlyDamagedSmoke = _k.smoke(1)
		var top: Vector3 = _top_centre(unit)
		_q.kit.need(problems, smoke != null and smoke.is_smoking() and smoke.puffs()[0].global_position.distance_to(top) <= NEAR, "%s: the smoke's first puff is not at the drawn model's top %s" % [path, top])
		_q.kit.need(problems, top.y > box.end.y + 1.0 and Quick.model_bottom(unit) > box.end.y, "%s: the smoke begins %.2f m up, the piece's top is %.2f m and the model's lowest point %.2f m" % [path, top.y, box.end.y, Quick.model_bottom(unit)])
		notes.append("over %s (top %.2f m) the smoke begins %.2f m up, %.2f m above the piece, with the model's lowest point at %.2f m" % [path.get_file(), box.end.y, top.y, top.y - box.end.y, Quick.model_bottom(unit)])
	_q.kit.verdict("gyrocopter_smoke_over_cliff_and_cover", problems, " | ".join(notes))
