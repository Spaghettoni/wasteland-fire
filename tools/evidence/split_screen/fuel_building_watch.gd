extends Node
## The watch of the Story 023 scenarios: a node under the scene that ticks after every Unit (physics priority 100) and files, for
## each Player's Unit, one row per physics tick while `logging` is on: the physics frame, whether the Unit is alive, its Fuel, the
## horizontal length of its real velocity, its drive speed and its place, the nodes it slid against in its move, and whether each Fuel zone lists it (read after the zone's own tick of the
## same frame, so the list is the one the zone acted on). It also files every fuel_changed the Units emit, with the frame, so a
## refill is told from a burn by its sign and the exact value of a full tank is seen. Tooling only: nothing under src/ depends on
## this file. Implements: production/epics/wasteland-fire/story-023-fuel-building.md, Test Evidence.

## Whether rows are filed.
var logging: bool = false
## Per Player, the rows in order: {frame, alive, fuel, speed (real), drive (the drive speed), at (Vector3), slides (the paths of
## the colliders it slid against), hint (whether the Player's out-of-Fuel hint is shown), listed (Array[bool] per zone, west then east)}.
var rows: Array = [[], []]
## Per Player, every fuel_changed in order: {frame, fuel, capacity}.
var changes: Array = [[], []]

var _units: Array[Unit] = []
var _zones: Array[SupplyZone] = []
var _hints: Array[SelfDestructHint] = []


## Wires the watch to the two Units and the zones, and makes it tick after every Unit.
func setup(units: Array[Unit], zones: Array[SupplyZone], hints: Array[SelfDestructHint]) -> void:
	_units = units
	_zones = zones
	_hints = hints
	process_physics_priority = 100
	for player: int in _units.size():
		_units[player].fuel_changed.connect(func(fuel: float, capacity: float) -> void:
			changes[player].append({"frame": Engine.get_physics_frames(), "fuel": fuel, "capacity": capacity}))


## Forgets the rows and the changes filed so far.
func clear() -> void:
	rows = [[], []]
	changes = [[], []]


func _physics_process(_delta: float) -> void:
	if not logging:
		return
	for player: int in _units.size():
		var unit: Unit = _units[player]
		var velocity: Vector3 = unit.get_real_velocity()
		var listed: Array[bool] = []
		for zone: SupplyZone in _zones:
			listed.append(zone.get_overlapping_bodies().has(unit))
		var slides: PackedStringArray = []
		for index: int in unit.get_slide_collision_count():
			var collider: Node = unit.get_slide_collision(index).get_collider() as Node
			slides.append(String(collider.get_path()) if collider != null else "")
		rows[player].append({"frame": Engine.get_physics_frames(), "alive": unit.is_alive, "fuel": unit.fuel,
			"speed": Vector2(velocity.x, velocity.z).length(), "drive": unit.current_speed, "at": unit.global_position,
			"slides": slides, "hint": _hints[player] != null and _hints[player].visible, "listed": listed})
