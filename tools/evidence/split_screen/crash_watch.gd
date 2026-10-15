extends Node
## The watch of the Story 021 scenarios (crash, crash_showcase): a node that ticks after every Unit (physics priority 100) and,
## while logging, files one row a tick for each Player's Unit: its tick, place, drive speed, real velocity (this tick's and the
## previous tick's), whether it touched a wall or the floor, whether it was alive, and every slide collision of the move it
## just made (the collider's path, the normal, the angle to up). It reads what the Unit's own tick left, so a row is the
## Unit's tick of that frame, and it reads the Unit and nothing else: it changes nothing. A collision counts as a wall's when
## its normal is more than FLOOR_DEGREES from up (the Unit's floor_max_angle); the arrival along it is the previous tick's real
## velocity into it, the number the crash is measured with. Tooling only; nothing under src/ depends on it.
## Implements: production/epics/wasteland-fire/story-021-gyrocopter-crash.md, Test Evidence.

## The angle from up, in degrees, past which a collision is a wall's: the Unit's floor_max_angle (CharacterBody3D's 45
## degrees, left at its default by every UnitStats).
const FLOOR_DEGREES: float = 45.0

## The two Players' Units, Player 1's first.
var units: Array[Unit] = []
## Whether rows are filed now.
var logging: bool = false
## A name the rows carry, set by the scenario at each stretch of a run.
var phase: String = ""
## The rows of each Player since clear(): Array[Dictionary], one per tick logged.
var rows: Array = [[], []]
var _previous: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


func _init() -> void:
	process_physics_priority = 100


## Starts reading the Units: from now on the previous velocity of a Player is zeroed whenever its Unit starts a life or ends one
## (hit_points_changed with zero or the full maximum, which spawn(), destroy() and leave_play() emit and a hit does not), as
## Unit.reset_motion() zeroes the velocity a crash is measured from. A bench and a spawn by a tool in one frame never show a dead
## tick to this node, so without it the velocity of the last life would be read as the new one's arrival.
func watch(player_units: Array[Unit]) -> void:
	units = player_units
	for player: int in units.size():
		units[player].hit_points_changed.connect(func(hit_points: float, max_hit_points: float) -> void:
			if hit_points <= 0.0 or hit_points >= max_hit_points:
				_previous[player] = Vector3.ZERO)


func _physics_process(_delta: float) -> void:
	for player: int in units.size():
		var unit: Unit = units[player]
		var real: Vector3 = unit.get_real_velocity()
		var hits: Array[Dictionary] = []
		if unit.is_alive:
			for index: int in unit.get_slide_collision_count():
				var hit: KinematicCollision3D = unit.get_slide_collision(index)
				var who: Object = hit.get_collider()
				hits.append({"who": str(who.get_path()) if who is Node else str(who), "normal": hit.get_normal(), "deg": rad_to_deg(hit.get_angle())})
		if logging:
			(rows[player] as Array).append({"tick": Engine.get_physics_frames(), "at": unit.global_position, "cmd": unit.current_speed, "real": real, "prev": _previous[player],
				"wall": unit.is_on_wall(), "floor": unit.is_on_floor(), "alive": unit.is_alive, "hits": hits, "phase": phase, "yaw": rad_to_deg(unit.rotation.y), "fuel": unit.fuel})
		_previous[player] = real if unit.is_alive else Vector3.ZERO


## Forgets the rows (the previous velocity is kept: it is the Unit's own).
func clear() -> void:
	rows = [[], []]


## The metres a second a vector moves on the ground.
static func flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## The slide collisions of a row that are a wall's, as dictionaries with the arrival along the normal added.
static func walls(row: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for hit: Dictionary in row["hits"]:
		if float(hit["deg"]) > FLOOR_DEGREES:
			var copy: Dictionary = hit.duplicate()
			copy["arrival"] = -(row["prev"] as Vector3).dot(hit["normal"])
			found.append(copy)
	return found


## The index of the first row of a Player's, from `from` on, with a wall's collision; -1 when none.
func first_wall(player: int, from: int = 0) -> int:
	for index: int in range(from, (rows[player] as Array).size()):
		if not walls(rows[player][index]).is_empty():
			return index
	return -1


## What a stretch of a Player's rows (from index `from` to `to`, exclusive, -1 for the end; `only` names a phase, "" for any)
## holds: {ticks, floor_ticks (rows with a floor's collision), wall_ticks (rows with a wall's), max_arrival (the largest
## arrival along any wall's normal), max_real (the fastest real speed), max_cmd, alive (alive on every row), last (the
## last row), floors (the paths of the colliders the floor's collisions named), walls (the paths of the wall's)}.
func summary(player: int, from: int = 0, to: int = -1, only: String = "") -> Dictionary:
	var out: Dictionary = {"ticks": 0, "floor_ticks": 0, "wall_ticks": 0, "max_arrival": 0.0, "max_real": 0.0, "max_cmd": 0.0, "alive": true, "last": {}, "floors": {}, "walls": {}}
	var list: Array = rows[player]
	var end: int = list.size() if to < 0 else mini(to, list.size())
	for index: int in range(maxi(from, 0), end):
		var row: Dictionary = list[index]
		if only != "" and row["phase"] != only:
			continue
		out["ticks"] += 1
		out["alive"] = bool(out["alive"]) and bool(row["alive"])
		out["max_real"] = maxf(out["max_real"], flat(row["real"]))
		out["max_cmd"] = maxf(out["max_cmd"], absf(row["cmd"]))
		out["last"] = row
		var any_floor: bool = false
		for hit: Dictionary in row["hits"]:
			if float(hit["deg"]) <= FLOOR_DEGREES:
				any_floor = true
				out["floors"][hit["who"]] = true
		out["floor_ticks"] += 1 if any_floor else 0
		var wall_hits: Array[Dictionary] = walls(row)
		out["wall_ticks"] += 1 if not wall_hits.is_empty() else 0
		for hit: Dictionary in wall_hits:
			out["max_arrival"] = maxf(out["max_arrival"], hit["arrival"])
			out["walls"][hit["who"]] = true
	return out
