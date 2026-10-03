class_name UnitChoice
extends Control
## One Player's Unit choice panel: while that Player is out of play and choosing the next Unit type,
## a panel in the lower middle of that Player's own view that names every type in a row, marks the
## one under the Player's cursor and names the keys that move it and confirm; once the Player has
## chosen, the chosen type as ready, until the Unit appears; and nothing while the Unit is in play.
##
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6 (at every
## spawn, the start of the Round, after a destruction and after a restart, the Player chooses the
## Unit type in their own viewport with their own keys before the Unit appears, with every type
## available: this panel is the picture of that choice) and AC-8 (which Unit a Player drives shows:
## the row names every type of the data and the ready line names the one about to appear); Story
## 004 AC-8 (all text and elements fit inside a 640 x 720 viewport with no clipping or overflow);
## production/epics/wasteland-fire/story-007-the-map.md AC-11 (each Player's choice panel carries
## that Player's Team colour, here as an edge; open question 17); design/game-brief.md MVP feature 5
## (the four Units); design/rules.md "Tokens and the Garage" and "Teams and visual style".
## Vocabulary: CONTEXT.md (Player, Unit, Garage, Round).
##
## Display only (.claude/rules/ui-code.md). The Round and the choice belong to the MatchController
## and the cursor to PlayerChoiceInput. This panel connects to the controller's round_started,
## unit_destroyed, unit_chosen, unit_spawned and round_over and to the choice input's cursor_moved,
## reads is_choosing(), chosen_type_index(), unit_types() and is_round_over() and the cursor, and
## that is all it asks of them: it owns no state another node reads, calls nothing that changes the
## Round or the cursor, reads no input and polls nothing (no _process: every change it shows is
## announced by one of the six signals, and the handler rereads the answers). Take it out of the
## scene and the choice is made unchanged; only the picture of it is gone.
##
## One instance per Player's view, directly under that Player's SubViewport after the HUD and before
## the Round-over screen, so it is drawn over the HUD and the countdown and under the Round-over
## screen (split_screen.tscn: Player1UnitChoice, Player2UnitChoice). A Control in a SubViewport is
## laid out against the viewport, so the full-rect anchors in unit_choice.tscn make this Control as
## big as that Player's view (640 x 720 in the 1280 x 720 window), and the panel in it sits in the
## lower middle by anchors: both horizontal anchors at 0.5 with offsets of 280 px either side (560
## px wide, 40 px of margin each side of a 640 px view), both vertical anchors at the bottom with an
## offset of 16 px, growing upward from there to the height of its lines. The top band, where the
## HUD is, and the centre, where the respawn countdown is, stay clear of it (the Story 005 evidence
## doc keeps the measured rectangles). player_index says whose panel it is (0 is Player 1, the
## MatchController's numbering), choice_input is that Player's PlayerChoiceInput and action_prefix
## that Player's; the scene stores all three on each instance.
##
## States, three: hidden (the Player's Unit is in play, no Round has begun, or the Round is over),
## choosing (the Player is out of play and has not chosen: the title, the row with the slot under
## the cursor marked, the hint that names the keys) and ready (the Player has chosen and its Unit
## has not appeared yet: the ready line with the chosen type's name in the title's place, the row
## with no slot marked, no hint). Each panel follows its own Player alone: a signal for another
## player_index is ignored. Every handler rereads the controller's answers, so the state is always
## what the controller says of this Player: choosing while is_choosing(), ready while
## chosen_type_index() is not NO_CHOICE, hidden otherwise and whenever the Round is over. The table
## of what moves it is complete; a pair it does not list cannot happen.
##   hidden   -> choosing  round_started: begin() or the restart benched every Unit with its Player
##                         choosing; or unit_destroyed for this player_index while the Round runs
##   choosing -> choosing  cursor_moved: the marked slot follows the cursor
##   choosing -> ready     unit_chosen for this player_index: the controller accepted the choice
##   ready    -> hidden    unit_spawned for this player_index: the Unit appeared (on the tick of
##                         the choice at the earliest, so at the start of a Round the ready state
##                         can last less than a frame)
##   choosing -> hidden    round_over: a delivery won while this Player was choosing, or while
##   ready    -> hidden    its choice stood; the Round-over screen takes the view until the restart
##   hidden   -> hidden    unit_spawned, unit_destroyed or unit_chosen for another player_index;
##                         round_over while this Player's Unit was in play
## _ready() starts in whatever state the controller reports: hidden before begin(), since nobody is
## choosing then; a panel added after the Round began shows at once.
##
## The row. One slot per entry of unit_types(), in the data's order (the order of the cursor), each
## a duplicate of the slot template the scene stores (so its font, size and style are scene data),
## named by the type's display_name through tr(). The slots are built in _ready() and rebuilt only
## when the count of types differs from the row (the rules are shared data and never change at
## runtime, so in practice once). The slot under the cursor wears cursor_style, every other
## slot_style, both sub-resources of the scene swapped in as the "panel" theme override, never a
## colour written here.
##
## Text. The title ("Choose your Unit"), the hint format ("%s / %s to choose, %s to confirm", three
## %s placeholders for the names of the previous-type key, the next-type key and the confirm key, in
## that order) and the ready format ("%s ready", one %s placeholder for the chosen type's name) are
## data in unit_choice.tscn, and the type names are the display_name of each UnitStats; no
## player-facing string is written in this script. Each goes through tr(): no translation system
## exists yet, so tr() returns the text unchanged, and once one does each text is its key and this
## script needs no change. Every Label stores word-smart autowrap, so a longer translation wraps
## inside the panel instead of growing past the view. The key names are read from the Input Map
## whenever the hint is shown: the physical key of the first key event of the actions
## PlayerChoiceInput reads (action_prefix + steer_left, steer_right and fire), named by
## InputEventKey.as_text_physical_keycode() with the key's side in front when it has one
## (as_text_location()), so a new binding in project.godot changes the hint with no edit here; an
## action bound to no key names nothing. The keyboard is the only input the game has so far, so no
## gamepad binding is named (none exists to read).
##
## Look, stored in unit_choice.tscn: a dark translucent panel with rounded corners, the title at 24
## px and the slot names and the hint at 18 px, white, so it reads over the grey field and either
## Player's coloured Base; the marked slot is brighter and wears a white 2 px border (brightness
## and a border, not hue alone). mouse_filter is ignore on the root, the panel and every container,
## so the panel never takes a click from what is under it. The scene stores visible = false: that
## is what the view shows before the Round begins.
##
## Team edge (Story 007 AC-11). When the scene sets edge_style, it is drawn over the panel across
## the panel's own rectangle, from the panel's draw signal: after the panel's own style and before
## its lines, and again on every redraw, so it follows the panel as it grows and shrinks between the
## choosing and the ready state. split_screen.tscn stores each Player's Team edge on that Player's
## panel and on its HUD, one file per Team: src/ui/hud/data/team_orange_edge.tres for Player 1 and
## team_teal_edge.tres for Player 2, a 3 px border in the Team colour with no fill and the panel's
## 8 px corners (its content margins frame the HUD's band and play no part here). The panel keeps
## its dark fill and its rectangle, and the marked slot its white 2 px border, so the Team colour
## never marks a slot. With edge_style null, the default, nothing is drawn: the look before
## Story 007.

const _SUFFIX_STEER_LEFT: String = "steer_left"
const _SUFFIX_STEER_RIGHT: String = "steer_right"
const _SUFFIX_FIRE: String = "fire"

## The MatchController this panel reads: the node that emits round_started, unit_destroyed,
## unit_chosen, unit_spawned and round_over and answers is_choosing(), chosen_type_index(),
## unit_types() and is_round_over(). Required: without it the panel pushes an error and shows
## nothing.
@export var match_controller: MatchController

## This Player's PlayerChoiceInput: the node whose cursor the marked slot follows and that emits
## cursor_moved. Required: without it the panel pushes an error and shows nothing. The scene stores
## this Player's choice input on each instance.
@export var choice_input: PlayerChoiceInput

## Whose panel this is, in the MatchController's numbering: 0 is Player 1, 1 is Player 2. Required,
## with no default (-1 means not set): the owning scene stores it on each instance, and a forgotten
## one pushes an error and shows nothing instead of quietly showing Player 1's choice on Player 2's
## screen. The default is -1 and not 0 because the engine leaves an exported value that equals its
## script default out of a saved scene, which would drop a stored 0.
@export var player_index: int = -1

## Prefix shared by this Player's Input Map actions, for example p1_: the hint names the keys bound
## to the prefix plus steer_left, steer_right and fire, the three actions PlayerChoiceInput reads.
## Required, with no default: the owning scene stores it.
@export var action_prefix: StringName = &""

@export_group("Text")
## The title while the Player is choosing: "Choose your Unit" in unit_choice.tscn. Looked up with
## tr(), so it is also the translation key. Required, with no default: the text is data in the
## scene and never a literal in this script.
@export var title_text: String = ""

## The hint line with three placeholders (%s): the names of the previous-type key, the next-type
## key and the confirm key, in that order; "%s / %s to choose, %s to confirm" in unit_choice.tscn.
## Looked up with tr(), so it is also the translation key. Required, with no default.
@export var hint_format: String = ""

## The line in the title's place once the Player has chosen, with one placeholder (%s) for the
## chosen type's name: "%s ready" in unit_choice.tscn. Looked up with tr(), so it is also the
## translation key. Required, with no default.
@export var ready_format: String = ""

@export_group("Look")
## The panel style of a slot the cursor is not on: a sub-resource of unit_choice.tscn, the one the
## slot template wears there. Required: without it the panel pushes an error and shows nothing.
@export var slot_style: StyleBox

## The panel style of the slot under the cursor: a sub-resource of unit_choice.tscn, brighter than
## slot_style and with a white 2 px border. Required: without it the panel pushes an error and
## shows nothing.
@export var cursor_style: StyleBox

## The Team edge drawn over the panel (Story 007 AC-11; the class doc's Team edge): a StyleBox, in
## split_screen.tscn the Player's Team edge, src/ui/hud/data/team_orange_edge.tres or
## team_teal_edge.tres. Optional: null, the default, draws nothing (the look before Story 007).
@export var edge_style: StyleBox

@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _slots: HBoxContainer = %Slots
@onready var _slot_template: PanelContainer = %SlotTemplate
@onready var _hint_label: Label = %HintLabel

var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _steer_left_action: StringName
var _steer_right_action: StringName
var _fire_action: StringName


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("UnitChoice '%s': %s, so it shows nothing." % [name, problem])
		visible = false
		return
	match_controller.round_started.connect(_on_round_started)
	match_controller.unit_destroyed.connect(_on_unit_destroyed)
	match_controller.unit_chosen.connect(_on_unit_chosen)
	match_controller.unit_spawned.connect(_on_unit_spawned)
	match_controller.round_over.connect(_on_round_over)
	choice_input.cursor_moved.connect(_on_cursor_moved)
	if edge_style != null:
		_panel.draw.connect(_draw_edge)
		_panel.queue_redraw()
	_rebuild_slots(match_controller.unit_types())
	_refresh()


## Draws edge_style over the panel across the panel's own rectangle (the class doc's Team edge).
## Connected to the panel's draw signal, so it runs after the panel's own style and before its
## lines, every time the panel redraws.
func _draw_edge() -> void:
	_panel.draw_style_box(edge_style, Rect2(Vector2.ZERO, _panel.size))


## What is wrong with the exports, the texts, the scene or the Input Map, as a sentence, or an empty
## string when nothing is. Caches the three action names on the way (_first_scene_problem()).
func _first_problem() -> String:
	var problem: String = _first_export_problem()
	if problem.is_empty():
		problem = _first_text_problem()
	if problem.is_empty():
		problem = _first_scene_problem()
	return problem


## The first export that is unassigned: the controller, the choice input and the Player's index and
## prefix.
func _first_export_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if choice_input == null:
		return "choice_input is not assigned"
	if player_index < 0:
		return "player_index is not set (store 0 for Player 1 or 1 for Player 2 in the scene)"
	if action_prefix.is_empty():
		return "action_prefix is empty (store the Player's prefix, p1_ or p2_, in the scene)"
	return ""


## The first text that is missing or malformed: the title, the hint format and the ready format.
func _first_text_problem() -> String:
	if title_text.is_empty():
		return "title_text is not set (store the title in the scene)"
	if hint_format.is_empty():
		return "hint_format is not set (store the hint line, with three %s placeholders, in the scene)"
	if hint_format.count("%") < 3:
		return "hint_format '%s' lacks the three placeholders for the key names" % hint_format
	if ready_format.is_empty():
		return "ready_format is not set (store the ready line, with a %s placeholder, in the scene)"
	if not ready_format.contains("%"):
		return "ready_format '%s' has no placeholder for the chosen type's name" % ready_format
	return ""


## The first problem with the styles, the scene nodes or the Input Map. Caches the three action
## names on the way.
func _first_scene_problem() -> String:
	if slot_style == null:
		return "slot_style is not assigned (store the slot style of the scene)"
	if cursor_style == null:
		return "cursor_style is not assigned (store the cursor style of the scene)"
	if _scene_lacks_nodes():
		return "the scene lacks the panel, the title, the slot row, the slot template or the hint label"
	_steer_left_action = _action_name(_SUFFIX_STEER_LEFT)
	_steer_right_action = _action_name(_SUFFIX_STEER_RIGHT)
	_fire_action = _action_name(_SUFFIX_FIRE)
	for action: StringName in [_steer_left_action, _steer_right_action, _fire_action]:
		if not InputMap.has_action(action):
			return "Input Map action '%s' does not exist, so no key can be named" % action
	return ""


## Whether the scene lacks a node this panel uses: the panel, the title, the slot row, the slot
## template or the hint label.
func _scene_lacks_nodes() -> bool:
	return (_panel == null or _title_label == null or _slots == null or _slot_template == null
			or _hint_label == null)


func _action_name(suffix: String) -> StringName:
	return StringName(String(action_prefix) + suffix)


## Shows what the controller answers for this Player now: hidden (nothing to choose, or the Round
## is over), choosing (the title, the marked slot under the cursor, the hint) or ready (the chosen
## type's name, no mark, no hint); the class doc's states.
func _refresh() -> void:
	if not is_instance_valid(match_controller) or not is_instance_valid(choice_input):
		visible = false
		return
	var choosing: bool = match_controller.is_choosing(player_index)
	var chosen: int = match_controller.chosen_type_index(player_index)
	if match_controller.is_round_over() or not (choosing or chosen >= 0):
		visible = false
		return
	var types: Array[UnitStats] = match_controller.unit_types()
	_rebuild_slots(types)
	if choosing:
		_title_label.text = tr(title_text)
		_hint_label.text = _hint_text()
		_hint_label.visible = true
		_mark_slot(choice_input.cursor)
	else:
		var chosen_name: String = tr(types[chosen].display_name) if chosen < types.size() else ""
		_title_label.text = tr(ready_format) % chosen_name
		_hint_label.visible = false
		_mark_slot(-1)
	visible = true


## Builds one slot per type from the template the scene stores, named by the type's display_name
## through tr(). The slots are rebuilt only when the count of types differs from the row; the names
## are set again every time.
func _rebuild_slots(types: Array[UnitStats]) -> void:
	if _slot_panels.size() != types.size():
		for panel: PanelContainer in _slot_panels:
			_slots.remove_child(panel)
			panel.queue_free()
		_slot_panels.clear()
		_slot_labels.clear()
		for _type: UnitStats in types:
			var panel: PanelContainer = _slot_template.duplicate() as PanelContainer
			panel.unique_name_in_owner = false
			panel.visible = true
			_slots.add_child(panel)
			_slot_panels.append(panel)
			_slot_labels.append(panel.get_node(^"NameLabel") as Label)
	for type_index: int in types.size():
		_slot_labels[type_index].text = tr(types[type_index].display_name)


## Marks the slot at cursor with cursor_style and every other slot with slot_style; -1 marks none.
func _mark_slot(cursor: int) -> void:
	for type_index: int in _slot_panels.size():
		var style: StyleBox = cursor_style if type_index == cursor else slot_style
		_slot_panels[type_index].add_theme_stylebox_override(&"panel", style)


## The hint line: the format with the names of the previous-type, next-type and confirm keys.
func _hint_text() -> String:
	return tr(hint_format) % [
		_key_name(_steer_left_action), _key_name(_steer_right_action), _key_name(_fire_action)]


## The name of the key the Input Map binds to the action, from the physical key of the action's
## first key event: its engine name (as_text_physical_keycode()) with the key's side in front when
## it has one (as_text_location()); an empty string when the action has no key event.
func _key_name(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			var side: String = key_event.as_text_location()
			var key: String = key_event.as_text_physical_keycode()
			return key if side.is_empty() else "%s %s" % [side.capitalize(), key]
	return ""


## The Round began, or began again: every Player is choosing, so show the choice.
func _on_round_started() -> void:
	_refresh()


## This Player's Unit left play: the Player chooses again, so show the choice. Another Player's
## destruction is not ours.
func _on_unit_destroyed(destroyed_player_index: int) -> void:
	if destroyed_player_index == player_index:
		_refresh()


## This Player chose: show the chosen type as ready. Another Player's choice is not ours.
func _on_unit_chosen(chosen_player_index: int, _type_index: int) -> void:
	if chosen_player_index == player_index:
		_refresh()


## This Player's Unit appeared: nothing to choose, hide. Another Player's spawn is not ours.
func _on_unit_spawned(spawned_player_index: int) -> void:
	if spawned_player_index == player_index:
		_refresh()


## A delivery won the Round, whoever won: hide. The Round-over screen takes the view, and the
## restart announces itself with round_started.
func _on_round_over(_winner_index: int) -> void:
	visible = false


## The cursor moved: the marked slot follows it. Emitted only while this Player is choosing.
func _on_cursor_moved(_type_index: int) -> void:
	_refresh()
