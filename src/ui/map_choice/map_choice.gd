class_name MapChoice
extends Control
## The launch screen: the Maps side by side, each with its picture from above; either Player picks
## one and the match starts on it.
##
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-1 and AC-8
## (Martin, 2026-10-21: "Výber mapy pred zápasom", a map choice before the match, both Maps
## playable). Vocabulary: CONTEXT.md (Map, Player).
##
## Input. The screen reads three actions of its own, menu_left, menu_right and menu_confirm
## (project.godot): A / D and Left / Right, then Space, Period or Enter on the keyboard, and the
## D-pad or the left stick, then A, on every pad (their events have device -1, all devices). The
## Players' own actions (p1_, p2_) and the pads' assignment belong to the match (PadAssignment in
## split_screen.tscn), which does not exist yet here, so nothing here touches them.
##
## The start. Releasing menu_confirm (after it went down here) or clicking a card instances launch_scene (split_screen.tscn), calls its use_map() with the
## chosen Map's scene before it enters the tree, adds it to the root, makes it the current scene and
## frees this screen, so SplitScreen._ready() begins the Round on that Map and the restart (R / Menu)
## replays the same Map. The cards are built from maps when the screen is ready.

## Emitted when a Map is chosen, with its index in maps, just before the match is added.
signal map_chosen(index: int)

## The Maps on offer, in order, left to right (each a MapEntry .tres beside its Map's scene).
@export var maps: Array[MapEntry] = []

## The scene the chosen Map is played in: split_screen.tscn, whose root is a SplitScreen.
@export var launch_scene: PackedScene

## The row the cards are added to.
@export var cards_row: Container

## The line that says which keys choose and start.
@export var hint_label: Label

## The look of a card that is not chosen, and of the one under the cursor.
@export var card_style: StyleBox
@export var cursor_style: StyleBox

## The size of a card's picture, in pixels.
@export var preview_size: Vector2 = Vector2.ZERO

## The text of the hint line.
@export var hint_text: String = ""

## The index of the card under the cursor. Read-only.
var cursor: int:
	get:
		return _cursor
	set(_value):
		push_error("MapChoice '%s': cursor is read-only. Move it with step()." % name)

var _cursor: int = 0
var _cards: Array[PanelContainer] = []
var _started: bool = false
## Whether menu_confirm went down on this screen: the match starts when it comes up again, so the
## key that started it (Space and Period are also the Players' fire and confirm keys) is not held
## when the match reads its first tick.
var _confirm_held: bool = false


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("MapChoice '%s': %s, so no Map can be chosen." % [name, problem])
		return
	for entry: MapEntry in maps:
		_cards.append(_make_card(entry))
	if hint_label != null:
		hint_label.text = hint_text
	_show_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _started or _cards.is_empty():
		return
	if event.is_action_pressed(&"menu_left"):
		step(-1)
	elif event.is_action_pressed(&"menu_right"):
		step(1)
	elif event.is_action_pressed(&"menu_confirm"):
		_confirm_held = true
	elif event.is_action_released(&"menu_confirm") and _confirm_held:
		start()
	else:
		return
	get_viewport().set_input_as_handled()


## Moves the cursor by `delta` cards, wrapping round.
func step(delta: int) -> void:
	if _cards.is_empty():
		return
	_cursor = posmod(_cursor + delta, _cards.size())
	_show_cursor()


## Starts the match on the Map under the cursor: launch_scene with that Map in place, added to the
## root as the current scene; this screen is freed. Does nothing a second time.
func start() -> void:
	if _started or _cards.is_empty():
		return
	var instance: Node = launch_scene.instantiate()
	var split: SplitScreen = instance as SplitScreen
	if split == null:
		push_error("MapChoice '%s': the root of launch_scene is not a SplitScreen, so the match does not start." % name)
		instance.free()
		return
	if not split.use_map(maps[_cursor].scene):
		split.free()
		return
	_started = true
	map_chosen.emit(_cursor)
	var tree: SceneTree = get_tree()
	tree.root.add_child(split)
	tree.current_scene = split
	queue_free()


func _first_problem() -> String:
	if maps.is_empty():
		return "maps is empty"
	for index: int in maps.size():
		if maps[index] == null:
			return "maps entry %d is not assigned" % index
		var problem: String = maps[index].first_problem()
		if not problem.is_empty():
			return "maps entry %d: %s" % [index, problem]
	if launch_scene == null:
		return "launch_scene is not assigned"
	if cards_row == null:
		return "cards_row is not assigned"
	return ""


func _make_card(entry: MapEntry) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", card_style)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	var picture := TextureRect.new()
	picture.texture = entry.preview
	picture.custom_minimum_size = preview_size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	var title := Label.new()
	title.text = entry.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = &"HeaderMedium"
	column.add_child(title)
	var blurb := Label.new()
	blurb.text = entry.blurb
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.modulate = Color(1, 1, 1, 0.75)
	column.add_child(blurb)
	var card_index: int = _cards.size()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func() -> void:
		_cursor = card_index
		_show_cursor())
	card.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_cursor = card_index
			start())
	cards_row.add_child(card)
	return card


func _show_cursor() -> void:
	for index: int in _cards.size():
		_cards[index].add_theme_stylebox_override(&"panel", cursor_style if index == _cursor else card_style)
