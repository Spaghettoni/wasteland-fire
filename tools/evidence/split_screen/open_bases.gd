extends RefCounted
## Scenario open_bases of the split screen evidence harness (split_screen_harness.gd): Story 058 on the shipped Map 01. CHECK
## lines:
##  O1 no towers: neither Base has a corner tower (no StaticBody3D under its Walls); each has four corner Wall Panels, in its
##     structures, on its Team's colour, standing.
##  O2 breakable cover: Map 01's eight wrecks and two containers are Structures listed in the Map's neutral_structures; each
##     falls to enough damage and stands again after a restart.
##  O3 round water: each ford's own rectangular water is hidden and a pool in the ford's material is drawn in its place.
## Implements: production/epics/wasteland-fire/story-058-maps-cleanup.md AC-1, AC-4, AC-5. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=open_bases

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const OWN_CHOICE: bool = true
const OPEN_BASES: bool = true
const BASE_DEFENCES: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const TURRETS: bool = true
const FLAG_OPEN: bool = true
const CORNERS: int = 4
const COVER_PIECES: int = 10
const SETTLE: int = 10
const LETHAL: float = 100000.0

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var field: MapField = _h.split.field
	_check_bases(field)
	await _check_cover(field)
	_check_water(field)
	_h.finish("map=%s" % field.scene_file_path.get_file())


func _check_bases(field: MapField) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for base: Base in [field.player_1_base, field.player_2_base]:
		var towers: int = base.get_node("Walls").find_children("*", "StaticBody3D", false, false).size()
		var corners: Array[Node] = base.get_node("Walls/Corners").get_children()
		var listed: int = 0
		var painted: int = 0
		for corner: Node in corners:
			var piece: Structure = corner as Structure
			if piece != null and base.structures.has(piece) and piece.is_standing:
				listed += 1
			var mesh: MeshInstance3D = corner.get_node_or_null("Mesh") as MeshInstance3D
			if mesh != null and mesh.material_override == base.color_material:
				painted += 1
		_kit.need(problems, towers == 0, "%s still has %d towers" % [base.name, towers])
		_kit.need(problems, corners.size() == CORNERS and listed == CORNERS and painted == CORNERS, "%s: %d corners, %d listed standing, %d painted" % [base.name, corners.size(), listed, painted])
		lines.append("%s: towers %d, corner panels %d (listed %d, painted %d)" % [base.name, towers, corners.size(), listed, painted])
	_kit.verdict("O1_no_towers", problems, "; ".join(lines))


func _check_cover(field: MapField) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var pieces: Array[Structure] = []
	for node: Node in field.get_node("Cover").find_children("*", "", true, false):
		var piece: Structure = node as Structure
		if piece != null:
			pieces.append(piece)
	var listed: int = pieces.filter(func(p: Structure) -> bool: return field.neutral_structures.has(p)).size()
	for piece: Structure in pieces:
		piece.apply_damage(LETHAL)
	await _kit.advance(SETTLE)
	var fallen: int = pieces.filter(func(p: Structure) -> bool: return not p.is_standing).size()
	await _end_round(field)
	var over: bool = _h.split.match_controller.is_round_over()
	_kit.need(problems, over, "the Round did not end, so it could not be restarted")
	_h.split.match_controller.restart()
	await _kit.advance(SETTLE)
	var back: int = pieces.filter(func(p: Structure) -> bool: return p.is_standing).size()
	_kit.need(problems, pieces.size() == COVER_PIECES and listed == COVER_PIECES, "%d cover Structures, %d listed" % [pieces.size(), listed])
	_kit.need(problems, fallen == COVER_PIECES and back == COVER_PIECES, "%d fell, %d stood again after the restart" % [fallen, back])
	_kit.verdict("O2_breakable_cover", problems, "%d wrecks and containers are Structures, %d in neutral_structures; %d fell to %.0f damage; %d stood again after R" % [pieces.size(), listed, fallen, LETHAL, back])


## Ends the Round the quick way: Player 1's Motorbike is put on Player 2's Flag, then in its own Base.
func _end_round(field: MapField) -> void:
	var controller: MatchController = _h.split.match_controller
	controller.choose(0, 0)
	controller.choose(1, 0)
	await _kit.advance(SETTLE * 3)
	var unit: Unit = _h.split.all_units()[0]
	var camera: ChaseCamera = _h.split.all_cameras()[0]
	_h.place(unit, Transform3D(Basis.IDENTITY, field.player_2_base.flag_seat.global_position), camera)
	await _kit.advance(SETTLE * 2)
	_h.place(unit, Transform3D(Basis.IDENTITY, field.player_1_base.zone.global_position), camera)
	await _kit.advance(SETTLE * 2)


func _check_water(field: MapField) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for ford_name: String in ["FordWest", "FordEast"]:
		var water: MeshInstance3D = field.get_node("%s/Water" % ford_name) as MeshInstance3D
		var pool: CSGPolygon3D = field.get_node_or_null("Pool%s" % ford_name) as CSGPolygon3D
		var points: int = pool.polygon.size() if pool != null else 0
		_kit.need(problems, not water.visible and pool != null and points > 8, "%s: water shown %s, pool %s with %d points" % [ford_name, water.visible, pool != null, points])
		lines.append("%s: rectangle hidden %s, pool of %d points" % [ford_name, not water.visible, points])
	_kit.verdict("O3_round_water", problems, "; ".join(lines))
