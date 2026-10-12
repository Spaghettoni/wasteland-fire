extends RefCounted
## Where an explosion stands (Story 016 AC-4): at the destroyed Unit as it was drawn, never at the body's origin on the
## floor. over_cover and over_cliff: a Gyrocopter risen over a container and over the canyon rock of Map 01 is destroyed and its
## Explosion stands in the air above the piece, at its model raised by the box's middle, inside the model's drawn box
## and above the piece's top, not inside it. hovering_is_drawn_height: the same for a Gyrocopter hovering on the open
## flat, higher than a Motorbike's. stays_where_it_began: an Explosion stays at the one place for its whole life while
## its Unit is put back at its Base (the respawn's teleport), both cameras step to the other view and the other
## Player's Unit is moved, and it is a child of World, never of a Unit or a camera. Run by explosions.gd. Tooling only.
## Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-4.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The container of the west and the canyon rock (the south one) of Map 01, by path from the Map.
const COVER: String = "Cover/Containers/ContainerWest"
const RIDGE: String = "Cliffs/RockCanyonSouth"
## Ticks a Gyrocopter stands over a piece before it is destroyed: its model has risen by then (the rise rate is data).
const RISE_WAIT: int = 90
## Ticks an Explosion is followed for in stays_where_it_began, and the tick the Unit is put back and the views step.
const FOLLOW_TICKS: int = 100
const PUT_BACK_TICK: int = 20
const VIEW_TICK: int = 40
const MOVE_TICK: int = 60
## The keys that step the view of each Player (Q for Player 1, Slash for Player 2): only tools name key codes.
const VIEW_KEYS: Array[Key] = [KEY_Q, KEY_SLASH]

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _over(RIDGE, "over_cliff")
	await _over(COVER, "over_cover")
	await _hovering()
	await _stays()


## The world box of a Map piece: a mesh's drawn box (a cover piece) or the CSG shape's (a rock).
func _box_of(piece: Node3D) -> AABB:
	var shape: GeometryInstance3D = piece as GeometryInstance3D
	if shape == null:
		shape = piece.get_node("Mesh") as GeometryInstance3D
	return shape.global_transform * shape.get_aabb()


## A Gyrocopter risen over a piece of the Map is destroyed by a tool's destroy(): its Explosion stands above the piece.
func _over(path: String, check_name: String) -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.clear(0)
	var piece: Node3D = _q.map.find(path) as Node3D
	var box: AABB = _box_of(piece)
	var at: Vector3 = Vector3(box.get_center().x, 0.0, box.get_center().z)
	await _q.put(1, _q.units.stats(Quick.GYROCOPTER), at, Vector3.RIGHT)
	await _q.kit.advance(RISE_WAIT)
	var unit: Unit = _q.units.units[1]
	var bottom: float = Quick.model_bottom(unit)
	var before: int = _k.destroyed.size()
	unit.destroy()
	await _q.kit.advance(2)
	var d: Dictionary = _k.destroyed[before] if _k.destroyed.size() > before else {}
	_q.kit.need(problems, not d.is_empty() and not d["blast"].is_empty(), "no destruction or no Explosion")
	if not d.is_empty() and not d["blast"].is_empty():
		var centre: Vector3 = d["centre"]
		var drawn: AABB = d["box"]
		_q.kit.need(problems, bottom > box.end.y, "the Gyrocopter's model (lowest point %.3f m) has not risen over the piece (top %.3f m)" % [bottom, box.end.y])
		_q.kit.need(problems, centre.y > box.end.y and drawn.grow(Kit16.TOLERANCE).has_point(centre), "the Explosion's centre %s is not above the piece's top %.3f m and inside the model's drawn box %s" % [centre, box.end.y, drawn])
		_q.kit.need(problems, centre.distance_to(d["expected"]) <= Kit16.TOLERANCE and centre.y - float(d["floor"]) > unit.stats.collision_center.y, "the centre %s is not the model raised by the box's middle %s, or is no higher than a ground Unit's" % [centre, d["expected"]])
		measured.append("%s_centre_above_top_m=%.2f" % [check_name, centre.y - box.end.y])
		_q.kit.verdict(check_name, problems, "a Gyrocopter risen over %s (top %.2f m, its model's lowest point %.2f m) was destroyed: its Explosion stands at %.2f m, %.2f m above the piece and %.2f m above the floor, inside the model's drawn box, where it was seen, not inside the piece" % [piece.name, box.end.y, bottom, centre.y, centre.y - box.end.y, centre.y - float(d["floor"])])
	else:
		_q.kit.verdict(check_name, problems, "no Explosion to read")


## hovering_is_drawn_height: a hovering Gyrocopter's Explosion is higher than a Motorbike's, by the model's hover.
func _hovering() -> void:
	var problems: PackedStringArray = []
	var gyro: Dictionary = await _k.direct_destroy(Quick.GYROCOPTER)
	var bike: Dictionary = await _k.direct_destroy(Quick.MOTORBIKE)
	var heights: Array[float] = []
	for d: Dictionary in [gyro, bike]:
		heights.append((d["centre"] as Vector3).y - float(d["floor"]) if not d.is_empty() and not d["blast"].is_empty() else -1.0)
	_q.kit.need(problems, heights[0] > heights[1] and heights[1] > 0.0, "the Gyrocopter's Explosion is %.3f m above the floor, the Motorbike's %.3f m" % [heights[0], heights[1]])
	measured.append("hover_centre_m=%.2f/%.2f" % [heights[0], heights[1]])
	_q.kit.verdict("hovering_is_drawn_height", problems, "a hovering Gyrocopter's Explosion stood %.2f m above the floor (its model's hover and the box's middle), a Motorbike's %.2f m (the box's middle)" % [heights[0], heights[1]])


## stays_where_it_began: see the class doc.
func _stays() -> void:
	var problems: PackedStringArray = []
	await _k.fresh()
	await _k.t.clear(0)
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.TRUCK, Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit16.SETTLE)
	var before: int = _k.blasts.size()
	_q.units.units[1].destroy()
	await _q.kit.advance(1)
	var blast: Explosion = _k.blasts[before]["node"] as Explosion
	var first: Vector3 = blast.global_position
	var worst: float = 0.0
	for tick: int in FOLLOW_TICKS:
		if tick == PUT_BACK_TICK:
			_q.units.retype(1, Quick.MOTORBIKE, _q.units.bases[1].spawn_point.global_position, Vector3.FORWARD)
		if tick == VIEW_TICK:
			await _q.kit.press_settled(VIEW_KEYS)
		if tick == MOVE_TICK:
			_q.units.retype(0, Quick.MOTORBIKE, Vector3(-30.0, 0.0, 12.0), Vector3.BACK)
		await _q.kit.tick()
		worst = maxf(worst, blast.global_position.distance_to(first))
	_q.kit.need(problems, worst == 0.0, "the Explosion moved %.4f m while its Unit was put back at its Base, both views stepped and the other Unit was moved" % worst)
	_q.kit.need(problems, blast.get_parent() == _q.units.units[1].get_parent() and not (blast.get_parent() is Unit) and not (blast.get_parent() is Camera3D), "the Explosion's parent is %s, not World" % blast.get_parent().name)
	_q.kit.need(problems, blast.is_inside_tree() and blast.ticks_played() >= PUT_BACK_TICK, "the Explosion was not playing (%d ticks)" % blast.ticks_played())
	await _q.kit.press_settled(VIEW_KEYS)
	await _q.kit.advance(Kit16.SETTLE)
	_q.kit.verdict("stays_where_it_began", problems, "an Explosion followed for %d ticks never moved (%.4f m) while its Unit was put back at its Base's spawn point at tick %d, both Players' views stepped at tick %d and the other Unit was moved at tick %d; it is a child of World, not of a Unit or a camera" % [FOLLOW_TICKS, worst, PUT_BACK_TICK, VIEW_TICK, MOVE_TICK])
