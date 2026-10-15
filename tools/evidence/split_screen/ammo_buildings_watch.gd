extends Node
## The watch of the Story 024 scenarios: a node under the scene that ticks after every Unit and every Weapon (physics priority 100) and
## files, for each Player's Unit, one row per physics tick while `logging` is on: the physics frame, whether the Unit is alive, its Weapon's
## Shots and capacity, its Fuel, hit points and Mines, the horizontal length of its real velocity, its drive speed and its place, the
## nodes it slid against in its move, and whether each of the Map's four supply zones lists it (read after the zone's own tick of the same
## frame, so the list is the one the zone acted on). Tooling only: nothing under src/ depends on this file. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md, Test Evidence.

## The Story 009 helpers (quick_fix_kit.gd): the lowest point of a drawn model.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Whether rows are filed.
var logging: bool = false
## Per Player, the rows in order: {frame, alive, left, capacity, fuel, hp, mines, speed (real), drive (the drive speed), at (Vector3),
## bottom (the lowest point of a flying Unit's drawn model, 0.0 for a ground Unit), slides (the paths of the colliders it slid
## against), listed (Array[bool] per zone, in the kit's order)}.
var rows: Array = [[], []]

var _units: Array[Unit] = []
var _weapons: Array[Weapon] = []
var _layers: Array[MineLayer] = []
var _zones: Array[SupplyZone] = []


## Wires the watch to the two Units, their Weapons and MineLayers and the zones, and makes it tick after every Unit and Weapon.
func setup(units: Array[Unit], weapons: Array[Weapon], layers: Array[MineLayer], zones: Array[SupplyZone]) -> void:
	_units = units
	_weapons = weapons
	_layers = layers
	_zones = zones
	process_physics_priority = 100


## Forgets the rows filed so far.
func clear() -> void:
	rows = [[], []]


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
		rows[player].append({"frame": Engine.get_physics_frames(), "alive": unit.is_alive, "left": _weapons[player].shots_left,
			"capacity": _weapons[player].capacity, "fuel": unit.fuel, "hp": unit.hit_points, "mines": _layers[player].mines_left,
			"speed": Vector2(velocity.x, velocity.z).length(), "drive": unit.current_speed, "at": unit.global_position,
			"bottom": Quick.model_bottom(unit) if unit.is_alive and unit.stats.can_fly else 0.0,
			"slides": slides, "listed": listed})
