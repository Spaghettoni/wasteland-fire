extends RefCounted
## What the Story 021 scenarios (crash with its modules, and crash_showcase) share on top of the Story 020 kit
## (heights_kit.gd: the flying height, the solid colliders of the Map by family, the lanes, the staging; and under it the
## Story 019, 018, 014, 012, 011 and 009 kits): the watch node that files every Gyrocopter's slide collisions and velocities
## on each tick (crash_watch.gd), a record of every destruction the Round announced, the flights the modules make (a flight
## with the crash and its control with the crash switched off, so that "the tick of the first contact" is measured and not
## assumed), the lines a Gyrocopter is flown along to a Tall piece, and the readings of an Explosion and of the Structures.
## Tooling only: nothing under src/ depends on this file; loaded with a preload constant.
## Implements: production/epics/wasteland-fire/story-021-gyrocopter-crash.md, Test Evidence.

## The Story 020 kit: k.k is the Story 019 kit, k.k.k the Story 018 kit, k.k.k.m the Story 014 kit, k.k.k.m.w the Story 012 kit.
const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, a model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The watch node (crash_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")

## The Gyrocopter's index into the data.
const GYRO: int = Quick.GYROCOPTER
## Metres a Gyrocopter's nose runs before it meets a piece when a flight does not say (the heights kit's).
const RUN_UP: float = Kit20.RUN_UP
## The action of each Player's throttle, for a throttle that is a share of full (a stick's, which no key gives).
const THROTTLE_ACTIONS: Array[StringName] = [&"p1_throttle", &"p2_throttle"]
## The ticks a flight may take, and the ticks it is followed for after its first wall contact when it does not crash.
const FLIGHT_LIMIT: int = 400
const AFTER_CONTACT: int = 12
## How far from flush against a face the nose of a Unit that stopped may stand, metres (the contact margin and a tick's slack).
const FLUSH_SLACK: float = 0.06
## What an Explosion's centre may differ from the place the story puts it at, metres (a single-precision float's worth).
const PLACE_TOLERANCE: float = 0.001
## The Tall pieces by kind: [label, the Map's path with a Base number in it ("" for a tank by its own name)].
const KIND_PATHS: Dictionary = {"tower": "Base%d/Walls/TowerGateLeft", "leg": "Base%d/WaterTower/LegGateLeft", "turret": "Base%d/Turrets/TurretLeft"}
## The aims of the four shore runs (map_edges.gd's): the west shore, the north and the south, and the east one by the mirror.
const SHORE_AIMS: Dictionary = {"west": Vector2(-141.55, -26.6), "north": Vector2(-105, -44.2), "south": Vector2(-105, 43.86), "east": Vector2(141.55, -26.6)}
## The metres from the shore a shore run starts.
const SHORE_RUN_UP: float = 18.0
## The depot's three tanks, by name: the two reached from outside the depot (the north ones) and the one reached from its middle.
const TANKS: Array[String] = ["FuelTankNorthWest", "FuelTankNorthEast", "FuelTankSouth"]

## The Story 020 kit.
var k: Kit20
## The watch node under the launch scene.
var watch: Watch
## Every destruction the Round announced since the kit was made, in order: {player, frame, type, at, box, expected (where
## the story puts the Explosion's centre: the Unit's model, raised by its type's collision_center), in_handler (the
## Explosions in the tree inside the handler), counts (the Player's Token counts per type right then)}.
var destroyed: Array[Dictionary] = []
var _rows: Array[Dictionary] = []


## Makes the Story 020 kit, the watch and the record of the destructions.
func _init(harness_node: Node) -> void:
	k = Kit20.new(harness_node)
	watch = Watch.new()
	watch.watch([q().units.units[0], q().units.units[1]])
	harness_node.split.add_child(watch)
	q().controller.unit_destroyed.connect(_on_destroyed)


## Removes the watch and the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	watch.queue_free()
	k.close()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## The Story 018 kit (base_walls_kit.gd): staging, restore_all(), turrets_down(), park().
func walls() -> Object:
	return k.k.k


## The Story 014 kit (mines_kit.gd): revive(), put(), clear_mines().
func mines() -> Object:
	return k.k.k.m


## The Story 012 kit (flag_walls_kit.gd): the Bases, the Flags, look_shown(), the restart.
func flags() -> Object:
	return k.k.k.m.w


## The Story 011 kit (unit_swap_kit.gd): play(), the controller.
func swap() -> Object:
	return k.k.k.m.w.s


## The Map 01 root of the launch scene.
func map() -> MapField:
	return k.map()


## The Gyrocopter's stats: the controller's own resource, the one every Unit of the type shares.
func gyro_stats() -> UnitStats:
	return q().units.stats(GYRO)


## The Gyrocopter's crash speed, from the data.
func crash_speed() -> float:
	return gyro_stats().crash_speed


## The path from the Map of a Tall piece: a kind ("tower", "leg", "turret") at a Base (0 or 1), or a depot tank by its name.
static func path_of(kind: String, base_index: int = 0) -> String:
	if KIND_PATHS.has(kind):
		return String(KIND_PATHS[kind]) % (base_index + 1)
	return "Depot/FuelTanks/%s/Collider" % kind


## The way a Player flies from the open Map toward a Base (0 or 1) in the world: Base 1 stands on the west, Base 2 on the east.
static func toward(base_index: int) -> Vector3:
	return Vector3.LEFT if base_index == 0 else Vector3.RIGHT


## The collision box of a piece in the world, by its path from the Map.
func box(path: String) -> AABB:
	if _rows.is_empty():
		_rows = k.solid_rows(map())
	for row: Dictionary in _rows:
		if row["path"] == path:
			return row["shape_box"]
	push_error("crash_kit: no solid piece at '%s'" % path)
	return AABB()


## A line to a piece: the start of a flight whose nose is `gap` metres from the piece's near face when the Unit stands at
## the start, flown along `dir` (the world way, turned `turn` degrees about up), aimed at the piece's centre shifted by
## `lateral` metres to the side. {start, dir (the heading, turned), face (the distance of the near face along the unturned
## dir), box, half (the Gyrocopter's half length)}.
func line(path: String, dir: Vector3, lateral: float = 0.0, gap: float = RUN_UP, turn: float = 0.0) -> Dictionary:
	var piece_box: AABB = box(path)
	var half: float = gyro_stats().collision_size.z / 2.0
	var reach: float = (absf(dir.x) * piece_box.size.x + absf(dir.z) * piece_box.size.z) / 2.0
	var centre: Vector3 = Vector3(piece_box.get_center().x, 0.0, piece_box.get_center().z)
	var perp: Vector3 = Vector3.UP.cross(dir)
	var heading: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(turn))
	var aim: Vector3 = centre + perp * lateral
	return {"start": aim - heading * (reach + gap + half), "dir": heading, "face": dir.dot(centre) - reach, "box": piece_box, "half": half}


## The Gyrocopter Tokens (or any type's) a Player has left.
func tokens(player: int, type_index: int = GYRO) -> int:
	return q().controller.tokens_left(player, type_index)


## The Explosions in the tree now.
func blasts() -> Array[Node]:
	return q().harness.split.find_children("*", "Explosion", true, false)


## The index of a type in the controller's list, by the type_id of its stats; -1 for none.
func type_index_of(unit: Unit) -> int:
	var list: Array[UnitStats] = q().controller.unit_types()
	for index: int in list.size():
		if list[index].type_id == unit.type_id:
			return index
	return -1


## Files the destruction the Round announced, inside the controller's handler: the Token and the Explosion are already made.
func _on_destroyed(player: int) -> void:
	var unit: Unit = q().units.units[player]
	var counts: Array[int] = []
	for index: int in q().controller.unit_types().size():
		counts.append(q().controller.tokens_left(player, index))
	var model: Node3D = unit.get_node_or_null(String(Unit.MODEL_NODE_NAME)) as Node3D
	var origin: Vector3 = model.global_position if model != null else unit.global_position
	destroyed.append({"player": player, "frame": Engine.get_physics_frames(), "type": unit.type_id, "at": unit.global_position, "box": Quick.model_box(unit),
		"expected": origin + Vector3.UP * unit.stats.collision_center.y, "in_handler": blasts().size(), "counts": counts})


## The state of every Structure of the Map (the Turrets, the Wall Panels, the Flag Walls): hit points, standing, place and the
## damaged look it shows, by path from the Map; a crash must leave every entry as it was.
func structures_state() -> Dictionary:
	var state: Dictionary = {}
	for node: Node in map().find_children("*", "Structure", true, false):
		var piece: Structure = node as Structure
		state[str(map().get_path_to(piece))] = [piece.hit_points, piece.is_standing, piece.global_transform, flags().look_shown(piece)]
	return state


## Holds a Player's controls for up to `ticks` ticks (the rows go on being filed when the watch is logging): `throttle` 1.0 is the
## real key, -1.0 the real reverse key, a share between 0 and 1 a stick pressed that far (Input.action_press with that strength),
## 0 releases it; `steer` 1 left, -1 right, 0 none by the real keys; `stop`, called after each tick, ends the hold when it returns
## true. Returns the ticks held.
func drive(player: int, ticks: int, throttle: float = 1.0, steer: int = 0, stop: Callable = Callable()) -> int:
	var share: bool = throttle > 0.0 and throttle < 1.0
	if share:
		Input.action_press(THROTTLE_ACTIONS[player], throttle)
	var held: int = 0
	for _tick: int in ticks:
		q().harness.drive(player, 1 if throttle >= 1.0 else (-1 if throttle <= -1.0 else 0), steer)
		await q().kit.tick()
		held += 1
		if stop.is_valid() and stop.call():
			break
	if share:
		Input.action_release(THROTTLE_ACTIONS[player])
	q().harness.drive(player, 0, 0)
	return held


## Puts a Player's Unit in play as a type at a place facing a way (the Story 018 kit's stage(): the other Player's Unit is
## parked in its Garage), then tops up both tanks: a parked Gyrocopter burns 1.25 Fuel a second and its 50 would run out
## within a long run, which would be a Fuel crash in the middle of a check (the map kit's staging fills the tanks the same way).
func stage(player: int, type_index: int, start: Vector3, dir: Vector3) -> void:
	await walls().stage(player, type_index, start, dir)
	for unit: Unit in q().units.units:
		unit.refuel(unit.fuel_capacity)


## One flight of a Player's Unit as a type: staged at `start` facing `dir` (the other Player's Unit parked), then driven by
## drive() and filed by the watch from the first held tick. Returns {rows (the Player's rows), held, begin (the physics frame
## the first tick was held in), unit, hit (the index of the first wall's collision in the rows, -1 for none), dead (the index
## of the first row the Unit was not alive in, -1 for none)}.
func fly(player: int, type_index: int, start: Vector3, dir: Vector3, ticks: int = FLIGHT_LIMIT, throttle: float = 1.0, steer: int = 0, stop: Callable = Callable()) -> Dictionary:
	await stage(player, type_index, start, dir)
	watch.clear()
	watch.phase = "fly"
	watch.logging = true
	var begin: int = Engine.get_physics_frames() + 1
	var held: int = await drive(player, ticks, throttle, steer, stop)
	watch.logging = false
	return flight_of(player, held, begin)


## The record of what the watch filed for a Player: see fly().
func flight_of(player: int, held: int, begin: int) -> Dictionary:
	var rows: Array = watch.rows[player]
	var dead: int = -1
	for index: int in rows.size():
		if not bool(rows[index]["alive"]):
			dead = index
			break
	return {"rows": rows, "held": held, "begin": begin, "unit": q().units.units[player], "hit": watch.first_wall(player), "dead": dead}


## The same flight as fly() with the Gyrocopter's crash switched off (its crash speed 0 on the shared data for the flight, put
## back after it): it stops at the first contact, and the tick of that contact is the tick the crash is judged against. It is
## followed AFTER_CONTACT ticks past its first wall contact. Returns the flight.
func control(player: int, start: Vector3, dir: Vector3, throttle: float = 1.0, ticks: int = FLIGHT_LIMIT) -> Dictionary:
	var stats: UnitStats = gyro_stats()
	var saved: float = stats.crash_speed
	stats.crash_speed = 0.0
	var seen: Callable = func() -> bool: return watch.first_wall(player) >= 0 and (watch.rows[player] as Array).size() > watch.first_wall(player) + AFTER_CONTACT
	var flight: Dictionary = await fly(player, GYRO, start, dir, ticks, throttle, 0, seen)
	stats.crash_speed = saved
	return flight


## A flight with the crash on, until the Unit is destroyed or `ticks` ticks have passed (and AFTER_CONTACT ticks past a
## first wall contact it survived).
func crashing(player: int, start: Vector3, dir: Vector3, throttle: float = 1.0, ticks: int = FLIGHT_LIMIT) -> Dictionary:
	var unit: Unit = q().units.units[player]
	var over: Callable = func() -> bool: return not unit.is_alive or (watch.first_wall(player) >= 0 and (watch.rows[player] as Array).size() > watch.first_wall(player) + AFTER_CONTACT)
	return await fly(player, GYRO, start, dir, ticks, throttle, 0, over)


## The start and the heading of a head-on run into the shore nearest an aim: out along the outline's normal, SHORE_RUN_UP from it.
func shore_run(aim: Vector2) -> Dictionary:
	var outline: PackedVector2Array = q().map.outline()
	var nearest: float = INF
	var found: Dictionary = {}
	for index: int in outline.size():
		var start: Vector2 = outline[index]
		var end: Vector2 = outline[(index + 1) % outline.size()]
		var foot: Vector2 = Geometry2D.get_closest_point_to_segment(aim, start, end)
		if foot.distance_to(aim) < nearest:
			nearest = foot.distance_to(aim)
			var normal: Vector2 = (end - start).orthogonal().normalized()
			var facing: Vector3 = Vector3(normal.x, 0.0, normal.y) * signf(normal.dot(foot))
			found = {"start": Vector3(foot.x, 0.0, foot.y) - facing * SHORE_RUN_UP, "dir": facing}
	return found


## A graze of the north face (normal -Z) of an axis-aligned box piece: the heading leans `alpha` degrees off the face's plane
## toward it, flown from the face's east end at full throttle from `run` metres of heading before the first touch (enough for the
## top speed). {start, dir, face_z, alpha}; the Unit's lead corner on the face's side is the first thing that touches.
func graze_line(path: String, alpha: float, run: float = 14.0) -> Dictionary:
	var piece_box: AABB = box(path)
	var lean: float = deg_to_rad(alpha)
	var size: Vector3 = gyro_stats().collision_size
	var lead: float = size.x / 2.0 * cos(lean) + size.z / 2.0 * sin(lean)
	return {"start": Vector3(piece_box.end.x - 0.35 + run * cos(lean), 0.0, piece_box.position.z - lead - run * sin(lean)), "dir": Vector3(-cos(lean), 0.0, sin(lean)), "face_z": piece_box.position.z, "alpha": alpha}


## The rows of an Explosion's pieces a camera draws: the visible GeometryInstance3D below it whose render layers meet the
## camera's cull mask; {drawn, total}.
func pieces_seen_by(blast: Node, camera: Camera3D) -> Dictionary:
	var drawn: int = 0
	var total: int = 0
	for node: Node in blast.find_children("*", "GeometryInstance3D", true, false):
		var piece: GeometryInstance3D = node as GeometryInstance3D
		if piece.is_visible_in_tree():
			total += 1
			drawn += 1 if (camera.cull_mask & piece.layers) != 0 else 0
	return {"drawn": drawn, "total": total}


## The distance of a Unit's nose from a face the Unit was flown at: negative when the nose is past it.
func nose_gap(unit_at: Vector3, flight_line: Dictionary) -> float:
	var dir: Vector3 = flight_line["dir"]
	return float(flight_line["face"]) - (dir.dot(unit_at) + float(flight_line["half"]))
