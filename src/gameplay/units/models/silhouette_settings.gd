class_name SilhouetteSettings
extends Resource
## The see-through silhouette of a Player's own Unit
## (src/gameplay/units/data/silhouette_settings.tres): what is drawn of the Unit where cover hides
## it, in that Player's view only.
##
## Implements: production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md AC-4 (the
## hidden part of a Player's own Unit is drawn over the cover as a flat see-through silhouette in
## its Team colour, in its own Player's views only) and AC-5 (every value is data: the strength, the
## render layer of each Player's silhouettes and the materials); design/rules.md "Teams and visual
## style". Vocabulary: CONTEXT.md (Unit, Team colour, Silhouette).
##
## How it works (UnitSilhouette makes it, once a Unit's model is instanced): three passes, drawn
## after everything opaque, in the order of their render priorities, and only by the camera of the
## Unit's Player (everything of the silhouette is on that Player's render layer).
##   1. mask: an invisible copy of every mesh the model draws, drawn with no depth test, writes the
##      mask value into the stencil buffer wherever the Unit covers the screen;
##   2. sight: a second invisible copy of every mesh, drawn with the depth test, writes the sight
##      value over it wherever the mesh passes the depth test, that is wherever the part is in
##      sight: not hidden by cover and not by another part of the same Unit;
##   3. fill: one big quad turned to the camera, in the Team colour at the strength, drawn only
##      where the stencil still holds the mask value: where the Unit covers the screen and no part
##      of it is in sight.
## Why the fill is one quad and not a coloured copy of each mesh: the silhouette is flat. A coloured
## copy of every mesh would blend once for every mesh and every fold that overlaps another in the
## picture, so the hidden parts that overlap would read stronger than the rest (measured on 4.7.2,
## 2026-10-22: a pixel behind two copies read (72, 148, 146) where one read (94, 142, 144)). One
## quad draws each pixel once.
## Why the passes are three materials and not one that reads and writes: the engine lets a material
## read the stencil or write it and never both (stencil_flags 3 reads back 1 on 4.7.2, and then 2),
## so a copy that tests the stencil cannot also mark a pixel as done. The Unit's own meshes are
## drawn as they always were and write nothing.
##
## Data only. Every Unit shares one resource, so treat it as read-only at runtime. Every default
## below is zero or empty on purpose, for the reason UnitStats gives: the engine leaves a property
## that equals its script default out of a saved .tres, so a tuned number would vanish from the data
## file. Write every number into the .tres. first_problem() says whether the values can draw a
## silhouette at all; Unit asks it before it dresses a model, and a bad .tres is one named error and
## a Unit with none.

## The mask pass (1), a StandardMaterial3D: invisible (alpha 0), transparent so that it is sorted
## by render_priority, drawn with no depth test, and writing its stencil_reference alone
## (stencil_mode custom, the write flag only). Shared by every copy of every Unit. Required.
@export var mask_material: StandardMaterial3D

## The sight pass (2): the same as the mask pass but with the depth test on, a render_priority
## above the mask's and a stencil_reference of its own. Shared by every copy of every Unit. Required.
@export var sight_material: StandardMaterial3D

## The fill pass (3): the template of the quad's material, unshaded and see-through, a billboard
## drawn with no depth test and no fog after the other two (render_priority above the sight's),
## reading the stencil alone and drawing only where it equals the mask value (stencil_mode custom,
## the read flag only, compare equal, stencil_reference the mask pass's). Its colour is made for
## each Unit: the Team colour at strength. Required.
@export var fill_material: StandardMaterial3D

## How solid the silhouette is, as the alpha of the Team colour, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var strength: float = 0.0

## The side of the fill quad, metres: more than the screen shows at the Unit's distance in every
## view, with room for the camera's look-ahead (the quad turns to the camera and sits at the Unit,
## and a larger one costs nothing: only the pixels the mask marks are drawn; but one far beyond the
## picture is clipped by the guard band into more triangles than it needs, so it is not made huge).
@export_range(0.0, 16384.0, 1.0, "or_greater", "suffix:m") var fill_extent: float = 0.0

## The render layer (a one-bit mask: layer 3 is 4) everything of Player 1's silhouette is on, which
## only Player 1's camera draws (project.godot names it silhouette_p1).
@export_flags_3d_render var player_1_layer: int = 0

## The render layer of Player 2's silhouette, which only Player 2's camera draws (silhouette_p2). It
## is not Player 1's.
@export_flags_3d_render var player_2_layer: int = 0


## The reason these settings cannot draw a silhouette, or an empty String when they can: a pass with
## no material or one that cannot do its part (a writer that is not alpha-blended, visible, reads the
## stencil or writes it only some of the time, or has the wrong depth test; a fill that is not
## alpha-blended, shaded, depth tested, not a billboard or not reading the mask value alone; any of
## the three with a next pass, a grow or a depth write), stencil values that are not
## from 1 to the engine's largest, the mask and the sight value being one, passes that are not drawn
## in the order mask, sight, fill, a strength outside 0 to 1 (a NaN is refused too), a layer that is
## not one bit, one layer for both Players, or a fill quad with no size.
func first_problem() -> String:
	var problem: String = _writer_problem(mask_material, "mask_material", true)
	if problem.is_empty():
		problem = _writer_problem(sight_material, "sight_material", false)
	if problem.is_empty():
		problem = _fill_problem()
	if not problem.is_empty():
		return problem
	var limit: int = _stencil_limit()
	for value: int in [mask_material.stencil_reference, sight_material.stencil_reference]:
		if value < 1 or value > limit:
			return "a stencil value is not from 1 to %d" % limit
	if mask_material.stencil_reference == sight_material.stencil_reference:
		return "the mask and the sight pass write one stencil value"
	if fill_material.stencil_reference != mask_material.stencil_reference:
		return "fill_material does not draw where the mask value is (its stencil_reference is not the mask pass's)"
	if not (mask_material.render_priority < sight_material.render_priority \
			and sight_material.render_priority < fill_material.render_priority):
		return "the passes are not drawn in the order mask, sight, fill (render_priority must rise)"
	if not (strength >= 0.0 and strength <= 1.0):
		return "strength is not from 0 to 1"
	for layer: int in [player_1_layer, player_2_layer]:
		if layer <= 0 or (layer & (layer - 1)) != 0:
			return "a layer is not one render layer (a mask of one bit)"
	if player_1_layer == player_2_layer:
		return "both Players have one silhouette layer, so a camera would draw the other Player's" \
			+ " silhouette"
	if not (fill_extent > 0.0 and is_finite(fill_extent)):
		return "fill_extent is not above zero"
	return ""


## The reason a writer material (the mask or the sight pass) cannot do its part, or an empty String:
## it must be missing no part of it, alpha-blended (so that render_priority sorts it: the engine
## sorts only those, and a scissored or hashed surface is drawn with the opaque ones and discards
## the pixels that write nothing), plain (_plain_problem()), invisible, a writer of the stencil
## alone that always writes, and ignore the depth test exactly when `ignores_depth`.
func _writer_problem(writer: StandardMaterial3D, label: String, ignores_depth: bool) -> String:
	if writer == null:
		return "%s is not set" % label
	var plain: String = _plain_problem(writer, label)
	if not plain.is_empty():
		return plain
	if writer.albedo_color.a != 0.0:
		return "%s is visible: it only writes the stencil, so its alpha must be 0" % label
	if writer.stencil_mode != BaseMaterial3D.STENCIL_MODE_CUSTOM \
			or writer.stencil_flags != BaseMaterial3D.STENCIL_FLAG_WRITE:
		return ("%s does not write the stencil alone (stencil_mode custom with the write flag only:"
				+ " the engine lets a material read or write it, never both)") % label
	if writer.stencil_compare != BaseMaterial3D.STENCIL_COMPARE_ALWAYS:
		return "%s does not always write (its stencil_compare is not always)" % label
	if writer.no_depth_test != ignores_depth:
		return ("%s tests depth, so it would not mark everything the Unit covers" if ignores_depth
				else "%s ignores depth, so it would mark the parts cover hides as in sight") % label
	return ""


## The reason a material of the silhouette is not plain enough to be drawn in its pass, or an empty
## String: it must be alpha-blended, have no next pass, no grow and no depth write.
func _plain_problem(material: StandardMaterial3D, label: String) -> String:
	if material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		return "%s is not alpha-blended, so it is not sorted by render_priority (its transparency is not alpha)" % label
	if material.next_pass != null:
		return "%s has a next pass, which is drawn on its own and not in the order of the passes" % label
	if material.grow:
		return "%s is grown, so it would not stand where its mesh is drawn" % label
	if material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_ALWAYS:
		return "%s writes depth, which would hide what is drawn after it" % label
	return ""


## The reason fill_material cannot draw the silhouette, or an empty String: it must be plain
## (_plain_problem()), unshaded, mixed, without a texture, drawn with no depth test, a billboard and
## a reader of the stencil alone that draws where the value is equal.
func _fill_problem() -> String:
	if fill_material == null:
		return "fill_material is not set"
	var plain: String = _plain_problem(fill_material, "fill_material")
	if not plain.is_empty():
		return plain
	if fill_material.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or fill_material.albedo_texture != null:
		return "fill_material does not mix one flat colour (a blend mode other than mix, or a texture)"
	if fill_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		return "fill_material is shaded, so the silhouette would not be one flat colour"
	if not fill_material.no_depth_test:
		return "fill_material tests depth, so cover would hide the silhouette (no_depth_test is off)"
	if fill_material.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED:
		return "fill_material is not a billboard, so the quad would not face each camera"
	if fill_material.stencil_mode != BaseMaterial3D.STENCIL_MODE_CUSTOM \
			or fill_material.stencil_flags != BaseMaterial3D.STENCIL_FLAG_READ \
			or fill_material.stencil_compare != BaseMaterial3D.STENCIL_COMPARE_EQUAL:
		return ("fill_material does not read the stencil alone where it is equal (stencil_mode custom,"
				+ " the read flag only, compare equal)")
	return ""


## The largest stencil value the engine takes: the upper end of the range of
## BaseMaterial3D.stencil_reference, read from the property itself (measured on 4.7.2: a value over
## it reads back as it was set, so nothing else stops one), or 0 when the property is not found,
## which refuses every value.
func _stencil_limit() -> int:
	for property: Dictionary in mask_material.get_property_list():
		if property["name"] == "stencil_reference":
			return int(String(property["hint_string"]).get_slice(",", 1))
	return 0


## The render layer of a Player's silhouette: Player 1's for index 0, Player 2's for any other.
func layer_of(player: int) -> int:
	return player_1_layer if player == 0 else player_2_layer
