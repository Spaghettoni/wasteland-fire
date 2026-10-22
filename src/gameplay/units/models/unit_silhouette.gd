class_name UnitSilhouette
extends RefCounted
## Makes the see-through silhouette of one Player's Unit once its model is instanced
## (Unit._dress_silhouette()): two invisible copies of every mesh the model draws, one that marks
## everything the mesh covers and one that marks what of it is in sight, and one quad that draws the
## Team colour wherever the first marked and the second did not, as SilhouetteSettings says.
##
## Implements: production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md AC-4 (the
## hidden part of a Player's own Unit is drawn over the cover in its Team colour, in its own
## Player's views only; a Unit never shows its own hidden parts over itself; a Unit out of play, the
## rotor's smear, the smoke and the explosion get none) and AC-5 (every value is data);
## design/rules.md "Teams and visual style". Vocabulary: CONTEXT.md (Unit, Team colour, Silhouette).
##
## The meshes are the ones UnitModel._add_mesh() put in Unit.SILHOUETTE_GROUP: the body's Accent,
## Neutral and Lamp and the turning parts' own meshes, never the rotor's smear or the smoke, which
## are made elsewhere. The two copies of a mesh share its Mesh resource, have its transform and are
## its siblings, so a turning part's copies are under its pivot and turn with it, and a Unit that is
## out of play (hidden) hides them with it. Every copy takes the layer of its Player
## (SilhouetteSettings.layer_of()), casts no shadow, is never culled by occlusion (cover that hides
## a Unit must not hide its silhouette), holds no collider (a MeshInstance3D has none), is in
## COPY_GROUP and is drawn with the settings' own mask or sight material, shared by every copy
## of every Unit. The Unit's own meshes keep the materials they were painted with and write nothing.
## The quad is a child of the model, named FILL_NAME, in FILL_GROUP, on the same layer; its material
## is made once for this Player's Unit and kept for every model it is given after, so no spawn makes
## a new one.

## The node group the mask and the sight copies belong to.
const COPY_GROUP: StringName = &"silhouette_copy"
## The node group the fill quad belongs to.
const FILL_GROUP: StringName = &"silhouette_fill"
## What the copies' names add to their mesh's.
const MASK_SUFFIX: String = "SilhouetteMask"
const SIGHT_SUFFIX: String = "SilhouetteSight"
## The name of the fill quad.
const FILL_NAME: StringName = &"SilhouetteFill"

var _settings: SilhouetteSettings
var _player: int = -1
var _team_colour: Color = Color.BLACK
var _fill_material: StandardMaterial3D
var _fill_mesh: QuadMesh


## Makes the silhouette of Player `player` (0 for Player 1) for a Unit of Team colour `team_colour`:
## the quad's material is the settings' own with that colour at the strength. The settings must be
## usable (SilhouetteSettings.first_problem() empty): the Unit has asked.
func _init(settings: SilhouetteSettings, player: int, team_colour: Color) -> void:
	_settings = settings
	_player = player
	_team_colour = team_colour
	_fill_material = settings.fill_material.duplicate() as StandardMaterial3D
	_fill_material.albedo_color = Color(team_colour, settings.strength)
	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(settings.fill_extent, settings.fill_extent)


## Whether this silhouette was made from these settings, Player and Team colour: the Unit makes a
## new one when any of them has changed.
func is_for(settings: SilhouetteSettings, player: int, team_colour: Color) -> bool:
	return _settings == settings and _player == player and _team_colour == team_colour


## The material of the fill quad of this silhouette.
func fill_material() -> StandardMaterial3D:
	return _fill_material


## Dresses a model that has just entered the tree: every mesh of Unit.SILHOUETTE_GROUP under it gets
## its mask copy and its sight copy beside it, and the model gets its fill quad. Returns the copies,
## in the order of their meshes (the mask copy first). A model with no such mesh is left as it is:
## a quad with nothing to mark would draw nothing, so none is made.
func dress(model: Node3D) -> Array[MeshInstance3D]:
	var copies: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in _body_meshes(model):
		copies.append(_add_copy(mesh, MASK_SUFFIX, _settings.mask_material))
		copies.append(_add_copy(mesh, SIGHT_SUFFIX, _settings.sight_material))
	if not copies.is_empty():
		_add_fill(model)
	return copies


## Every MeshInstance3D under `node` in Unit.SILHOUETTE_GROUP, depth first, collected before any
## copy is added.
func _body_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.is_in_group(Unit.SILHOUETTE_GROUP):
			found.append(mesh)
		found.append_array(_body_meshes(child))
	return found


## The copy of a mesh: its Mesh, its transform, its parent, this Player's layer and the given
## material, with no shadow.
func _add_copy(mesh: MeshInstance3D, suffix: String, material: Material) -> MeshInstance3D:
	var copy: MeshInstance3D = MeshInstance3D.new()
	copy.name = StringName(String(mesh.name) + suffix)
	copy.mesh = mesh.mesh
	copy.material_override = material
	copy.layers = _settings.layer_of(_player)
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copy.ignore_occlusion_culling = true
	copy.transform = mesh.transform
	copy.add_to_group(COPY_GROUP)
	mesh.get_parent().add_child(copy)
	return copy


## The fill quad: a child of the model at its origin (the material turns it to each camera, so its
## own turn does not matter), on this Player's layer, with no shadow and never culled for its size.
func _add_fill(model: Node3D) -> void:
	var fill: MeshInstance3D = MeshInstance3D.new()
	fill.name = FILL_NAME
	fill.mesh = _fill_mesh
	fill.material_override = _fill_material
	fill.layers = _settings.layer_of(_player)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.ignore_occlusion_culling = true
	fill.extra_cull_margin = _settings.fill_extent
	fill.add_to_group(FILL_GROUP)
	model.add_child(fill)
