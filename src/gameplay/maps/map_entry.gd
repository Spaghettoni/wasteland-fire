class_name MapEntry
extends Resource
## One Map the map choice offers (Story 038): its name, its scene and its picture from above.
##
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-1 and AC-8 (the
## Maps on offer are data: one .tres per Map beside its scene, listed by map_choice.tscn).
## Vocabulary: CONTEXT.md (Map).

## The name the map choice shows, for example "Map 01".
@export var display_name: String = ""

## One line under the name: what the Map is like.
@export var blurb: String = ""

## The Map's scene, whose root is a MapField (SplitScreen.use_map() refuses any other).
@export var scene: PackedScene

## The Map seen from above, shown on its card. Optional: a card with none shows only the name.
@export var preview: Texture2D


## The reason the map choice cannot offer this entry, or an empty String when it can.
func first_problem() -> String:
	if display_name.is_empty():
		return "it has no display_name"
	if scene == null:
		return "'%s' has no scene" % display_name
	return ""
