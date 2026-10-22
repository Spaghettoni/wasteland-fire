extends RefCounted
## The silhouette moments of the light_showcase scenario (Story 027 AC-4): each Player's Unit staged behind a piece of cover as that Player's own camera sees it, in the chase
## view and in the view from above, the other Player's view at the same moment in the same frame. A moment names the piece (a Tall piece of the Map by its path, one for each
## Player's own Base or the same one for both) and the type of both Units; the metres behind the piece's far face are found by probe() (LIGHT_PROBE=1: for each moment and a
## range of distances, how many of the nine points of the Unit's box the cover hides from its Player's camera) and written into BEHIND. Run by light_showcase.gd. Tooling only.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## The layers a ray must meet to count as cover between a camera and a Unit: the map, the cliffs and water, and the cover (project.godot's physics layers 1, 6 and 7).
const COVER_MASK: int = 97
## The points of a Unit's box a ray is cast to: the centre and the eight corners, each raised off the ground by this much.
const LIFT: float = 0.15
## The distances (metres behind a piece's far face, the Unit's centre a half length further) the probe tries.
const PROBE_FROM: float = -1.0
const PROBE_TO: float = 10.0
const PROBE_STEP: float = 0.5
## The moments: {name, type of both Units, pieces: each Player's piece by its path from the Map, dirs: the way each Unit faces (the camera is behind it), laterals: metres each
## Unit stands to the side of the piece's centre line (the way UP x dir points)}.
const OUT: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT]
const MOMENTS: Array[Dictionary] = [
	{"name": "turret", "type": Quick.MOTORBIKE, "pieces": ["Base1/Turrets/TurretLeft", "Base2/Turrets/TurretLeft"], "dirs": OUT, "laterals": [0.0, 0.0]},
	{"name": "tower", "type": Quick.BUGGY, "pieces": ["Base1/Walls/TowerGateLeft", "Base2/Walls/TowerGateLeft"], "dirs": OUT, "laterals": [0.0, 0.0]},
	{"name": "leg", "type": Quick.TRUCK, "pieces": ["Base1/WaterTower/LegGateLeft", "Base2/WaterTower/LegGateLeft"], "dirs": OUT, "laterals": [0.0, 0.0]},
	{"name": "container", "type": Quick.TRUCK, "pieces": ["Cover/Containers/ContainerWest", "Cover/Containers/ContainerEast"], "dirs": OUT, "laterals": [0.0, 0.0]},
	{"name": "cliff", "type": Quick.BUGGY, "pieces": ["Cliffs/RockCanyonSouth", "Cliffs/RockCanyonSouth"], "dirs": [Vector3.FORWARD, Vector3.FORWARD], "laterals": [-30.0, 30.0]},
	{"name": "leak", "type": Quick.MOTORBIKE, "pieces": ["Depot/FuelTanks/FuelTankSouth/Collider", "Depot/FuelTanks/FuelTankSouth/Collider"], "dirs": [Vector3.FORWARD, Vector3.FORWARD], "laterals": [-1.3, 1.3]},
]
## Player 1's Motorbike with Player 2's Truck standing between it and its camera (the Truck is cover like any other piece, so Player 1's silhouette shows over it; unit_in_front): where
## the Motorbike stands, and the metres between the two Units' centres along the way both face.
const FRONT_SPOT: Vector3 = Vector3(-30.0, 0.0, -14.0)
const FRONT_GAP: float = 4.5
## Metres behind a piece's far face (found by the probe: some of the nine points of the Unit's box hidden from its own camera), by moment and pass.
const BEHIND: Dictionary = {
	"turret": {"chase": 3.0},
	"tower": {"above": 0.0, "chase": 9.0},
	"leg": {"above": 0.0, "chase": 2.5},
	"container": {"above": 0.0, "chase": 1.0},
	"cliff": {"above": 0.5, "chase": 0.5},
	"leak": {"chase": 3.0},
}
## Base-local: between the water tower's Gate-side legs (as in heights_showcase), where a Gyrocopter stands under the tank.
const BETWEEN_LEGS: Vector3 = Vector3(0.0, 0.0, -7.0)
## Ticks a moment holds before it is read, and the share of the Unit's box nobody may see through (the moment needs some of it hidden).
const HOLD: int = 30

var _s: Object
var _q: Quick


func _init(showcase: Object) -> void:
	_s = showcase
	_q = showcase.q


## The spot of a moment's Unit of a Player `behind` metres behind the far face of its piece along its way, the Unit's centre half its length further, to its side by its lateral.
func spot_of(moment: Dictionary, player: int, behind: float) -> Vector3:
	var box: AABB = _s.k.crash().box(String(moment["pieces"][player]))
	var dir: Vector3 = moment["dirs"][player]
	var half: float = _q.units.stats(int(moment["type"])).collision_size.z / 2.0
	var reach: float = (absf(dir.x) * box.size.x + absf(dir.z) * box.size.z) / 2.0
	var centre: Vector3 = Vector3(box.get_center().x, 0.0, box.get_center().z)
	return centre + dir * (reach + behind + half) + Vector3.UP.cross(dir) * float(moment["laterals"][player])


## How many of the nine points of a Player's Unit box the cover hides from that Player's camera, and how many are cast to.
func hidden_of(player: int) -> Vector2i:
	var unit: Unit = _q.units.units[player]
	var camera: Camera3D = _q.units.cameras[player]
	var box: AABB = Quick.model_box(unit)
	var points: Array[Vector3] = [box.get_center()]
	for corner: int in 8:
		points.append(box.get_endpoint(corner))
	var hidden: int = 0
	for point: Vector3 in points:
		var aimed: Vector3 = Vector3(point.x, maxf(point.y, box.position.y + LIFT), point.z)
		var hit: Vector3 = _q.map.ray(camera.global_position, aimed, COVER_MASK)
		hidden += 1 if hit != Vector3.INF else 0
		if OS.get_environment("LIGHT_DEBUG") == "1":
			print("DEBUG player=%d cam=%s box=%s point=%s hit=%s" % [player, camera.global_position, box, aimed, hit])
	return Vector2i(hidden, points.size())


## Lists the solid pieces of the Map (LIGHT_PROBE=list) or, for each moment, the hidden share of each Player's Unit box over a range of distances (LIGHT_PROBE=1), as PROBE lines.
func probe() -> void:
	if OS.get_environment("LIGHT_PROBE") == "list":
		for row: Dictionary in _s.k.crash().k.solid_rows(_s.k.crash().map()):
			if row["shape_box"] != null:
				var box: AABB = row["shape_box"]
				print("PROBE piece %s layer=%d top=%.2f centre=(%.1f, %.1f) size=(%.1f, %.1f, %.1f)" % [row["path"], row["layer"], box.end.y, box.get_center().x, box.get_center().z, box.size.x, box.size.y, box.size.z])
		return
	if OS.get_environment("LIGHT_PROBE") == "front":
		await probe_front()
		return
	for moment: Dictionary in MOMENTS:
		var type_index: int = moment["type"]
		var behind: float = PROBE_FROM
		while behind <= PROBE_TO:
			var spots: Array[Vector3] = []
			var faces: Array[Vector3] = []
			for player: int in 2:
				spots.append(spot_of(moment, player, behind))
				faces.append(moment["dirs"][player])
			await _q.map.stage([type_index, type_index], spots, faces, true)
			var one: Vector2i = hidden_of(0)
			var two: Vector2i = hidden_of(1)
			print("PROBE %s pass=%s behind=%.1f p1=%d/%d p2=%d/%d" % [moment["name"], _s.pass_name, behind, one.x, one.y, two.x, two.y])
			behind += PROBE_STEP


## The moments, in the pass's view. A coroutine: await it.
func play() -> void:
	for moment: Dictionary in MOMENTS:
		if BEHIND.has(moment["name"]) and BEHIND[moment["name"]].has(_s.pass_name):
			await _show(moment, float(BEHIND[moment["name"]][_s.pass_name]))
	await _under_the_tank()
	if _s.pass_name == "chase":
		await _unit_in_front()


## Player 2's Truck between Player 1's camera and Player 1's Motorbike, both facing east: the Truck hides part of the Motorbike from its own camera, and Player 1's view shows the Motorbike's
## silhouette over the Truck (the other Player's Unit is cover like a wall). The premise is geometric: the Truck's box lies across the line from the camera to the Motorbike's middle.
func _unit_in_front() -> void:
	var spots: Array[Vector3] = [FRONT_SPOT, FRONT_SPOT - Vector3.RIGHT * FRONT_GAP]
	await _q.map.stage([Quick.MOTORBIKE, Quick.TRUCK], spots, [Vector3.RIGHT, Vector3.RIGHT], true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	var hidden: Vector2i = _covered_by_unit(0, 1)
	_s.need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and _s.in_pass_view(), "sil_unit_in_front_%s: Units alive %s and %s, the cameras are on %s" % [_s.pass_name, _q.units.units[0].is_alive, _q.units.units[1].is_alive, _s.views()])
	_s.need(hidden.x > 0, "sil_unit_in_front_%s: none of the %d points of Player 1's Motorbike's box lies behind a mesh box of Player 2's Truck seen from Player 1's camera" % [_s.pass_name, hidden.y])
	_s.line("sil_unit_in_front_%s" % _s.pass_name, "Player 2's Truck between Player 1's camera and Player 1's Motorbike, %d of %d points of its box behind a mesh box of the Truck seen from the camera (the boxes are generous: the frame shows what is hidden), views=%s" % [hidden.x, hidden.y, ", ".join(_s.views())])
	await _q.kit.advance(Looks.HOLD_TICKS)


## How many of the nine points of a Unit's box lie behind a mesh box of another Unit seen from the first Unit's camera (a ray against the boxes of the meshes, which are generous), and how many were cast to.
func _covered_by_unit(player: int, cover: int) -> Vector2i:
	var camera: Camera3D = _q.units.cameras[player]
	var box: AABB = Quick.model_box(_q.units.units[player])
	var points: Array[Vector3] = [box.get_center()]
	for corner: int in 8:
		points.append(box.get_endpoint(corner))
	var meshes: Array[AABB] = []
	for mesh: MeshInstance3D in Quick.body_meshes(_q.units.units[cover].get_node("Model")):
		meshes.append(mesh.global_transform * mesh.get_aabb())
	var hidden: int = 0
	for point: Vector3 in points:
		var aimed: Vector3 = Vector3(point.x, maxf(point.y, box.position.y + LIFT), point.z)
		var covered: bool = false
		for part: AABB in meshes:
			covered = covered or part.intersects_segment(camera.global_position, aimed) != null
		hidden += 1 if covered else 0
	return Vector2i(hidden, points.size())


## Lists, for LIGHT_PROBE=front, how many points of Player 1's Motorbike's box Player 2's Truck hides from Player 1's camera at each gap between them, as PROBE lines.
func probe_front() -> void:
	var gap: float = 4.0
	while gap <= 10.0:
		await _q.map.stage([Quick.MOTORBIKE, Quick.TRUCK], [FRONT_SPOT, FRONT_SPOT - Vector3.RIGHT * gap], [Vector3.RIGHT, Vector3.RIGHT], true)
		var hidden: Vector2i = _covered_by_unit(0, 1)
		print("PROBE front gap=%.1f hidden=%d/%d" % [gap, hidden.x, hidden.y])
		gap += 0.5


## Both Units staged behind their pieces at `behind` metres: the moment is read when the cameras have settled.
func _show(moment: Dictionary, behind: float) -> void:
	var type_index: int = moment["type"]
	await _q.map.stage([type_index, type_index], [spot_of(moment, 0, behind), spot_of(moment, 1, behind)], [moment["dirs"][0], moment["dirs"][1]], true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	_finish("sil_%s" % moment["name"], "both Units behind %s" % moment["pieces"][0].get_file())
	await _q.kit.advance(Looks.HOLD_TICKS)


## The checks and the line of a moment whose pair is in place: both in play, the cameras on the pass's view, and cover hiding some of each Unit's box from its own camera.
func _finish(moment: String, reads: String) -> void:
	var one: Vector2i = hidden_of(0)
	var two: Vector2i = hidden_of(1)
	_s.need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and _s.in_pass_view(), "%s_%s: Units alive %s and %s, the cameras are on %s" % [moment, _s.pass_name, _q.units.units[0].is_alive, _q.units.units[1].is_alive, _s.views()])
	_s.need(one.x > 0 and two.x > 0, "%s_%s: cover hides %d and %d of the nine points of the two Units' boxes from their own cameras" % [moment, _s.pass_name, one.x, two.x])
	_s.line("%s_%s" % [moment, _s.pass_name], "%s, %d and %d of %d points of the boxes hidden from the own cameras, views=%s" % [reads, one.x, two.x, one.y, ", ".join(_s.views())])


## Both Gyrocopters between their water tower's Gate-side legs, under the tank.
func _under_the_tank() -> void:
	var flags: Object = _s.k.flags()
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [flags.point(0, BETWEEN_LEGS), flags.point(1, BETWEEN_LEGS)], [flags.way(0, Vector3.BACK), flags.way(1, Vector3.BACK)], true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	_finish("sil_tank", "both Gyrocopters between their water tower's legs, under the tank")
	await _q.kit.advance(Looks.HOLD_TICKS)
