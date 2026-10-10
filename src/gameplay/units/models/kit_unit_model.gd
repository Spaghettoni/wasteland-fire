class_name KitUnitModel
extends UnitModel
## A Unit type's model built from one of the author's concept-kit models: the root of
## motorbike_kit_model.tscn, buggy_kit_model.tscn, truck_kit_model.tscn and
## gyrocopter_kit_model.tscn. Each type's UnitStats.model pointed at its kit scene from Story 007
## until 2026-10-10, when the models built in Blender (MeshUnitModel) replaced them; the kit scenes
## stay, and pointing a type's model back at its kit scene brings its kit model back.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-11 (a Unit wears its Team's
## colour and no other), AC-12 (each type reads by its silhouette; the Motorbike's cream heading
## cue) and AC-14 (one build per type, cached); design/rules.md "Teams and visual style" and
## "Units". The rise over cliffs and cover (Story 007 AC-13, Story 009 AC-2) is UnitModel's.
## Vocabulary: CONTEXT.md (Unit, Team, Motorbike, Gyrocopter).
##
## _build_meshes() takes the build of kit_scene from KitMerge (made the first time a model of that
## kit, seed and remaps enters the tree, then cached: SplitScreen builds the match's types once
## before the Round begins) and adds two MeshInstance3D children: Accent, in
## Unit.TEAM_COLOUR_GROUP, which Unit._swap_model() paints with the Unit's team_material, and
## Neutral, which keeps the kit's colours. Its hull is the build's (KitMerge.Built.hull: the kit's
## vertices up to KitMerge.HULL_TOP, without the Gyrocopter's rotor). model_scale is the kit's
## length fitted to the type's collider.

@export_group("Kit")
## The kit model this Unit model is built from: the author's
## res://assets/art/vehicles/wasteland_<type>/wasteland_<type>.tscn, loaded by path, never edited.
@export var kit_scene: PackedScene
## The kit's rust seed. The palette builds its paint textures once per seed, so all four models
## share one. Required, with no default: each model scene stores it.
@export var rust_seed: int = 0
## Kit key -> the kit key every part of it takes instead (the Buggy's pennant becomes the Team
## accent and the Truck's rust-orange drum dark steel: nothing neutral reads as a Team colour).
@export var material_remap: Dictionary[String, String] = {}
## Single parts that take another kit key: entries {"size": the part's BoxMesh size, "at": its
## centre in the kit's frame, "key": the key it takes} (KitMerge.get_or_build()); the Motorbike's
## tank-top patch takes the lamp's cream, its heading cue.
@export var part_remap: Array[Dictionary] = []

## The build this model shows; null before _ready() or when the build failed.
var _built: KitMerge.Built


## Adds the Accent and Neutral meshes of the kit's build and takes its hull; false, after an error
## (here or in KitMerge), when there is no kit_scene or the build fails.
func _build_meshes() -> bool:
	if kit_scene == null:
		push_error("KitUnitModel '%s': no kit_scene, so the model is empty." % name)
		return false
	_built = KitMerge.get_or_build(self, kit_scene, rust_seed, material_remap, part_remap)
	if _built == null:
		return false
	_add_mesh(ACCENT_NODE_NAME, _built.accent, true)
	_add_mesh(NEUTRAL_NODE_NAME, _built.neutral, false)
	_hull = _built.hull
	return true
