extends RefCounted
## What the Story 027 scenarios (see_through with its modules, light_showcase and light_fps) share on top of the Story 025 kit
## (rotors_kit.gd: the watch of the turning parts; and under it the Story 021 kit and the kits below it): the settings the build
## ships, and readers of a Unit's drawn meshes, of their silhouette copies, of a camera's culling mask and of Map 01's
## Environment. Tooling only: nothing under src/ depends on this file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md, Test Evidence.

## The Story 025 kit: k.k is the Story 021 kit.
const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, a model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The settings the build ships.
const SETTINGS_PATH: String = "res://src/gameplay/units/data/silhouette_settings.tres"
## The Map the build ships and the greybox field its older scenarios are measured on.
const MAP_PATH: String = "res://src/gameplay/maps/map_01/map_01.tscn"
const GREYBOX_PATH: String = "res://src/gameplay/maps/greybox_field.tscn"
## The colour grade's parameters and the tool that writes its lookup texture from them.
const GRADE_PARAMETERS_PATH: String = "res://tools/colour_grade/colour_grade.json"
const GRADE_TOOL_PATH: String = "res://tools/colour_grade/build_colour_grade_lut.gd"
## The Gyrocopter's index into the data (the type with turning parts).
const GYRO: int = Quick.GYROCOPTER

## The Story 025 kit.
var k: Kit25


## Makes the Story 025 kit.
func _init(harness_node: Node) -> void:
	k = Kit25.new(harness_node)


## Removes the watches and the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	k.close()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## The Story 021 kit (crash_kit.gd): the solid pieces' boxes by path, the drives and the explosions.
func crash() -> Object:
	return k.k


## The Story 014 kit (mines_kit.gd): revive().
func mines() -> Object:
	return k.k.mines()


## The Story 012 kit (flag_walls_kit.gd): Base-local places and ways.
func flags() -> Object:
	return k.k.flags()


## The Story 018 kit (base_walls_kit.gd): staging, restore_all(), turrets_down(), park().
func walls() -> Object:
	return k.k.walls()


## The Story 011 kit (unit_swap_kit.gd): play(), enter(), the controller.
func swap() -> Object:
	return k.k.swap()


## Puts a Player's Unit in play as a type at a place facing a way (the Story 021 kit's stage(): the other Player's Unit is parked in
## its Garage and both tanks are topped up). A coroutine: await it.
func stage(player: int, type_index: int, start: Vector3, dir: Vector3) -> void:
	await k.k.stage(player, type_index, start, dir)


## The settings the build ships.
func settings() -> SilhouetteSettings:
	return load(SETTINGS_PATH) as SilhouetteSettings


## A Player's Unit.
func unit(player: int) -> Unit:
	return q().units.units[player]


## A Player's camera.
func camera(player: int) -> ChaseCamera:
	return q().units.cameras[player] as ChaseCamera


## A Player's Unit's model node, or null.
func model_of(player: int) -> Node3D:
	return k.model_of(player)


## The Team colour a Player's Unit is painted with: the albedo of its team_material.
func team_colour(player: int) -> Color:
	return (unit(player).team_material as BaseMaterial3D).albedo_color


## The meshes a Player's Unit's model draws, as the model marks them itself (Unit.SILHOUETTE_GROUP), in tree order: the Accent, the
## Neutral and the Lamp and the turning parts' meshes, never a smear or the smoke's puffs.
func drawn_meshes(player: int) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var model: Node3D = model_of(player)
	if model == null:
		return found
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if node.is_in_group(Unit.SILHOUETTE_GROUP):
			found.append(node as MeshInstance3D)
	return found


## The silhouette copies under a Player's Unit (UnitSilhouette.COPY_GROUP: the mask and the sight copy of each mesh), in tree order, whatever hangs under it.
func copies_of(player: int) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in unit(player).find_children("*", "MeshInstance3D", true, false):
		if node.is_in_group(UnitSilhouette.COPY_GROUP):
			found.append(node as MeshInstance3D)
	return found


## The number of meshes a type's model draws, read from its mesh file and its rotor settings and not from the nodes: the Accent and the
## Neutral, the Lamp when the file has one, and the two meshes of each turning part.
func expected_meshes(stats: UnitStats) -> int:
	var model: MeshUnitModel = stats.model.instantiate() as MeshUnitModel
	var names: Array = MeshFile.meshes_of(model.mesh_scene).keys()
	var count: int = 0
	for mesh_name: StringName in [UnitModel.ACCENT_NODE_NAME, UnitModel.NEUTRAL_NODE_NAME, MeshUnitModel.LAMP_NODE_NAME]:
		count += 1 if names.has(mesh_name) else 0
	if model.rotor_settings != null:
		for part: RotorPart in model.rotor_settings.parts:
			count += (1 if names.has(part.accent_mesh) else 0) + (1 if names.has(part.neutral_mesh) else 0)
	model.free()
	return count


## How many copies of a Player's Unit are drawn now: in the tree and visible all the way up (a Unit out of play is hidden).
func drawn_copies(player: int) -> int:
	var count: int = 0
	for copy: MeshInstance3D in copies_of(player):
		count += 1 if copy.is_visible_in_tree() else 0
	return count


## How many nodes of a Player's silhouette are drawn now: its copies and its fill quad, each in the tree and visible all the way up.
func drawn_silhouette(player: int) -> int:
	var fill: MeshInstance3D = fill_of(player)
	return drawn_copies(player) + (1 if fill != null and fill.is_visible_in_tree() else 0)


## The copies of a mesh: the nodes beside it (same parent) that share its Mesh and are in the copy group, in tree order (the mask copy, then the sight copy).
func copies_beside(mesh: MeshInstance3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in mesh.get_parent().get_children():
		var copy: MeshInstance3D = node as MeshInstance3D
		if copy != null and copy != mesh and copy.is_in_group(UnitSilhouette.COPY_GROUP) and copy.mesh == mesh.mesh:
			found.append(copy)
	return found


## The fill quad of a Player's Unit (UnitSilhouette.FILL_GROUP), or null.
func fill_of(player: int) -> MeshInstance3D:
	for node: Node in unit(player).find_children("*", "MeshInstance3D", true, false):
		if node.is_in_group(UnitSilhouette.FILL_GROUP):
			return node as MeshInstance3D
	return null


## How many fill quads are under a Player's Unit.
func fills_of(player: int) -> int:
	var count: int = 0
	for node: Node in unit(player).find_children("*", "MeshInstance3D", true, false):
		count += 1 if node.is_in_group(UnitSilhouette.FILL_GROUP) else 0
	return count


## The blasts of the crash kit (explosions in the tree).
func blasts() -> Array[Node]:
	return k.k.blasts()


## The Environment of the Map the launch scene holds (the node WorldEnvironment under it), or null.
func environment() -> Environment:
	var node: WorldEnvironment = q().harness.split.field.get_node_or_null("WorldEnvironment") as WorldEnvironment
	return node.environment if node != null else null


## The Environment of a Map scene's WorldEnvironment, read from the packed scene (instanced and freed at once), or null.
static func environment_of(scene_path: String) -> Environment:
	var root: Node = (load(scene_path) as PackedScene).instantiate()
	var node: WorldEnvironment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var found: Environment = node.environment if node != null else null
	root.free()
	return found
