extends RefCounted
## The Fuel Cans are gone in the Story 023 scenario fuel_building, AC-1: none of the nine stands on Map 01 (no node in the group, no node of the
## class, none of the nine paths, no mention of the Can's scene in the Map's two scenes); an empty Truck left for 150 ticks on each of the nine
## old spots still holds exactly zero Fuel, stranded; and the only code under src/ that adds Fuel to a Unit is the supply zone's and the
## evidence-only Can's (R19: the class stays for the older scenarios, with no instance on the shipped Map). Real keys.
## Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-1.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

## The nine old Cans' paths from the Map, in the order of the kit's spots.
const OLD_PATHS: Array[String] = ["FuelCanCanyonWest", "FuelCanCanyonEast", "FuelCanFlatWest", "FuelCanFlatEast",
	"Depot/FuelCanDepot1", "Depot/FuelCanDepot2", "Depot/FuelCanDepot3", "Depot/FuelCanDepot4", "Depot/FuelCanDepot5"]
const MAP_SCENES: Array[String] = ["res://src/gameplay/maps/map_01/map_01.tscn", "res://src/gameplay/maps/map_01/map_01_depot.tscn"]
const CAN_SCENE_NAME: String = "fuel_can.tscn"
const CAN_GROUP: StringName = &"fuel_cans"
## Ticks an empty Truck is left on an old spot.
const WATCH_TICKS: int = 150
## The folder whose scripts are scanned for a call that adds Fuel, and the scripts that may hold it (besides Unit's own definition): the
## zone's, and the Can's, which only the older scenarios put on the Map.
const SOURCE_ROOT: String = "res://src"
const GIVERS: PackedStringArray = ["fuel_can.gd", "supply_zone.gd"]
const DEFINITION: String = "unit.gd"

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	_no_cans_on_the_map()
	await _old_spots_give_nothing()
	_only_the_zones_refuel()


func _no_cans_on_the_map() -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, _q.harness.get_tree().get_nodes_in_group(CAN_GROUP).is_empty(), "%d nodes are in the group" % _q.harness.get_tree().get_nodes_in_group(CAN_GROUP).size())
	_q.kit.need(problems, _q.map.map.find_children("*", "FuelCan", true, false).is_empty(), "the Map holds a FuelCan")
	for path: String in OLD_PATHS:
		_q.kit.need(problems, _q.map.map.get_node_or_null(NodePath(path)) == null, "%s is still on the Map" % path)
	for scene: String in MAP_SCENES:
		_q.kit.need(problems, not FileAccess.get_file_as_string(scene).contains(CAN_SCENE_NAME), "%s still names %s" % [scene.get_file(), CAN_SCENE_NAME])
	_q.kit.verdict("no_fuel_can_on_the_map", problems, "no node of the group %s, no FuelCan under the Map, none of the nine old paths, and neither the Map's scene nor the depot's names %s" % [CAN_GROUP, CAN_SCENE_NAME])


## An empty Truck on each old spot holds exactly zero Fuel after WATCH_TICKS ticks and is still stranded.
func _old_spots_give_nothing() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	var most: float = 0.0
	for spot: Vector2 in Kit23.OLD_SPOTS:
		await _k.put(0, Quick.TRUCK, Vector3(spot.x, 0.0, spot.y), Vector3.RIGHT, 0.0)
		_k.watch.clear()
		_k.watch.logging = true
		await _q.kit.advance(WATCH_TICKS)
		_k.watch.logging = false
		var highest: float = 0.0
		for row: Dictionary in _k.rows(0):
			highest = maxf(highest, float(row["fuel"]))
		most = maxf(most, highest)
		_q.kit.need(problems, highest == 0.0 and _k.unit(0).is_stranded and _k.unit(0).is_alive, "the Truck on %s held up to %.4f Fuel (alive %s, stranded %s)" % [spot, highest, _k.unit(0).is_alive, _k.unit(0).is_stranded])
	measured.append("old_spots=%d_most_fuel_%.1f" % [Kit23.OLD_SPOTS.size(), most])
	_q.kit.verdict("old_spots_give_nothing", problems, "an empty Truck stood %d ticks on each of the nine places the Fuel Cans were (%s) and held exactly %.1f Fuel on every one, still stranded" % [WATCH_TICKS, ", ".join(Array(Kit23.OLD_SPOTS).map(func(spot: Vector2) -> String: return str(spot))), most])
	await _k.park(0)


## Every script under src/ that calls refuel() on a Unit: only the zone's and the evidence-only Can's (and Unit's own definition).
func _only_the_zones_refuel() -> void:
	var problems: PackedStringArray = []
	var callers: PackedStringArray = []
	var stack: PackedStringArray = [SOURCE_ROOT]
	var scanned: int = 0
	while not stack.is_empty():
		var folder: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		for sub: String in DirAccess.get_directories_at(folder):
			stack.append(folder.path_join(sub))
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				scanned += 1
				var code: String = ""
				for line: String in FileAccess.get_file_as_string(folder.path_join(file)).split("\n"):
					code += line.split("#")[0] + "\n"
				if code.contains(".refuel(") and file != DEFINITION and not callers.has(file):
					callers.append(file)
	callers.sort()
	_q.kit.need(problems, callers == GIVERS, "the scripts that call refuel(): %s" % [callers])
	_q.kit.verdict("only_the_zones_add_fuel", problems, "of %d scripts under %s only %s call Unit.refuel() (code lines, comments left out), and no Can stands on the Map" % [scanned, SOURCE_ROOT, " and ".join(callers)])
