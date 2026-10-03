class_name PlayerHud
extends Control
## One Player's HUD: that Player's hit points, as a bar with a "HP n / max" line on it, that
## Player's Fuel, as a second bar with a "Fuel n / max" line on it right of the first, where
## that Player stands with the Flags, as one line of text, and how many Motorbike Tokens that
## Player has left, as one more line of text at the right end of the Flag line's row; in the top
## band of that Player's own view and nowhere else.
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-7 (each
## viewport has a HUD showing that Player's hit points and Flag status: carrying the
## opponent's Flag / own Flag at home / own Flag away) and AC-8 (all text and elements
## fit inside a 640 x 720 viewport with no clipping or overflow);
## production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-7 (each Player's HUD shows a
## Fuel gauge beside the hit points in the band Story 004 built, right of the hit-point bar, at
## x 332 to 624; it visibly empties while the Unit moves, refills on a Fuel Can, and nothing
## clips or overflows); production/epics/wasteland-fire/story-007-the-map.md AC-11 (each Player's
## HUD carries that Player's Team colour, here as an edge round the band, and the hit-point green
## and the Fuel amber stay; open question 17);
## production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-6 (each Player's HUD
## shows that Player's remaining Motorbike Tokens, updated on the tick of every destruction and at
## a restart, inside the HUD band, with nothing clipped or overflowing in the 640 x 720 view);
## design/game-brief.md MVP features 4, 6 and 8; design/rules.md "Resources", "Tokens and the
## Garage" and "Teams and visual style".
## Vocabulary: CONTEXT.md (Player, Unit, Base, Round, Flag, Carrier, Fuel, Fuel Can, Token).
##
## Display only (.claude/rules/ui-code.md). The hit points and the Fuel belong to the Unit and the
## Flags and the Tokens to the MatchController. This HUD connects to the Unit's hit_points_changed
## and fuel_changed and to the controller's flag_picked_up, flag_dropped, flag_seated,
## round_started, unit_spawned and unit_destroyed, reads flag_status(), carrier_type_index(),
## unit_types() and tokens_left() and, once, the Unit's hit points and Fuel, and that is all it asks
## of them: it owns no state another node reads, calls nothing that changes the Unit or the Round
## and reads no input. Take it out of the scene and the Round plays on unchanged.
##
## One instance per Player, directly under that Player's SubViewport beside that Player's camera
## and respawn countdown (split_screen.tscn: Player1Hud, Player2Hud). A Control in a SubViewport
## is laid out against the viewport, so the full-rect anchors in player_hud.tscn make this HUD
## exactly as big as that Player's view (640 x 720 in the 1280 x 720 window): it is drawn in that
## Player's view and in no other. player_index says whose HUD it is (0 is Player 1, the
## MatchController's numbering) and unit is that Player's Unit; the scene stores both on each
## instance.
##
## Bindings, all by signal, none by polling. Hit points: the Unit's hit_points_changed(hit_points,
## max_hit_points) sets the hit-point bar (max_value before value, so the value is never clamped
## against a stale maximum) and rebuilds its line, tr(hit_points_format) with both numbers rounded
## up (ceili: a %d placeholder truncates, and a Unit alive with 0.4 hit points must never read 0);
## the first values are read once in _ready() from the Unit. The Unit emits once per change (a
## hit it survives, its destruction with zero, its spawn with the refill), so the bar shows the
## last completed change and nothing in between. Fuel (Story 006 AC-7): the Unit's
## fuel_changed(fuel, capacity) sets the Fuel bar the same way, maximum first and only while the
## capacity is above zero (a maximum of zero would draw a full bar), and rebuilds its line,
## tr(fuel_format) with both numbers rounded up (a tank with 0.4 Fuel left still drives and must
## never read 0; the Unit makes an approximately empty tank exactly zero, so the line reads 0 on
## the tick the tank runs dry); the first values are read once in _ready() from the Unit's fuel
## and fuel_capacity. The Unit emits on every physics tick it burns Fuel (while its drive speed
## is not approximately zero), so the gauge empties while the Unit moves and holds while it
## stands; once when a Fuel Can refuels it, so the gauge refills; with the starting tank at each
## spawn; and with zero when it is destroyed or benched, so the gauge reads zero while the Player
## waits to respawn or chooses its next Unit. Flag status: the one line is chosen again from
## match_controller.flag_status(player_index) whenever the controller emits
## flag_picked_up, flag_dropped, flag_seated, round_started or unit_spawned, the five
## signals after which its answer can differ, and once in _ready().
##
## The Tokens line (Story 008 AC-6): tr(tokens_format) with the name of the type that carries the
## Flag and the Player's Tokens of it, "Motorbike Tokens: 5". The type is the one the controller
## names, unit_types()[carrier_type_index()] (the Motorbike in the data, the type whose last Token
## loses the Round), never typed here, and the line shows it whatever type the Player drives or has
## chosen. The count INCLUDES the Unit in play, because a Token is taken at the destruction and
## never at the spawn: with five Motorbike Tokens it reads 5 while the first Motorbike drives, 4
## once that one is destroyed, and 1 on the last Motorbike. The controller takes the Token before
## it emits unit_destroyed and fills both stocks before it emits round_started, so the line is
## read again in _ready(), on round_started and on unit_destroyed for this Player's index, which
## are the moments the count changes, and on no other signal; another Player's destruction is not
## ours. While carrier_type_index() is negative (this HUD's _ready() runs before the composition
## root calls begin(), and a refused begin() leaves it negative) the line is hidden with an empty
## text: the index is checked before it is used, because GDScript reads a negative index from the
## end of an array.
##
## States of the status line, three, the MatchController.FlagStatus values, each shown as the
## text the scene stores for it:
##   CARRYING_ENEMY  carrying_text  this Player's Unit carries the other Player's Flag
##   OWN_AT_HOME     home_text      this Player's Flag stands on its Base's seat and the
##                                  Player carries nothing foreign; also before the Round begins,
##                                  which is what the controller answers then
##   OWN_AWAY        away_text      this Player's Flag is stolen, lies dropped or rides home
##                                  on its owner's Unit, and the Player carries nothing foreign
## Every change between them is the controller's and is announced by one of the five signals
## above, so the line follows it on the tick it happens. The Unit's destruction changes the hit
## points, the Fuel and the Tokens only: the status line names the Flags, not the Unit, and a
## Player waiting to respawn still reads where its Flag is.
##
## Text. The hit-point format ("HP %d / %d": the hit points left, then the maximum), the Fuel
## format ("Fuel %d / %d": the Fuel left, then the capacity), the Tokens format ("%s Tokens: %d":
## the carrier type's name, then its Tokens) and the three status texts are data in
## player_hud.tscn; no player-facing string is written in this script. Each goes through tr():
## no translation system exists yet, so tr() returns the text unchanged, and once one does each
## text is its key and this script needs no change. Every Label stores word-smart autowrap, so a
## longer translation wraps inside its band instead of growing past the view.
##
## Layout, stored in player_hud.tscn, by anchors in the top band of the view: the hit-point bar
## and its line at (16, 16), 300 x 24; the Fuel bar and its line on the same row at (332, 16),
## 292 x 24, 16 px clear of the hit-point bar and 16 px from the right edge (Story 006 AC-7); below
## them the status line at (16, 46), 300 x 30, under the hit-point bar, and the Tokens line at the
## right end of that row, 292 x 30 and 16 px from the right edge (Story 008 AC-6), right-aligned
## under the Fuel bar, so the two rectangles are 16 px apart; nothing lower than about 90 px, so
## the middle of the view stays clear for the Unit and the centred respawn countdown. A line's
## Label grows to the 26 px its 18 px text needs, which still leaves 4 px above the status line. It
## fits a 640 x 720 view with nothing clipped (Story 004 AC-8; the Story 004 evidence doc keeps the
## measured rectangles, the Story 006 evidence doc the run for the Fuel gauge and the Story 008
## evidence doc those of the narrower status line and the Tokens line). The two bars differ in
## colour, green for the hit points and amber for the Fuel, and never by colour alone: each line
## names what it counts. White text with a 6 px dark outline reads over the sky, the grey field and
## either Player's coloured Base. mouse_filter is ignore on every node, so the HUD never takes a
## click from what is under it.
##
## Team edge (Story 007 AC-11). When the scene sets edge_style, this HUD draws it in its own
## _draw(), under every element, round the band: the smallest rectangle that holds every element of
## the band (each Control child of this HUD), grown on each side by the style's margin
## (StyleBox.get_margin(), the content margin). split_screen.tscn stores each Player's Team edge on
## that Player's HUD and on its Unit choice panel, one file per Team:
## src/ui/hud/data/team_orange_edge.tres for Player 1 and team_teal_edge.tres for Player 2, a 3 px
## border in the Team colour (the albedo of the Team materials in src/gameplay/split_screen/data/)
## with no fill and 8 px of margin, so the edge runs from (8, 8) to (632, 84) in a 640 x 720 view,
## inside it. It is only an edge: the bars keep their green and amber, the text its white, and the
## view shows through the band as before. A band element that changes size (a longer translation
## that wraps) queues a redraw, so the edge follows the band. The edge is drawn and is not a node,
## so the HUD's children are the six elements of the band: the two bars, their lines, the status
## line and the Tokens line. A Control a later story adds under this HUD in player_hud.tscn joins
## the band, and the redraw when it changes size, with no change to this script. With edge_style
## null, the default, nothing is drawn: the look before Story 007.

## The MatchController this HUD reads for the Flag status and the Tokens: the node that emits
## flag_picked_up, flag_dropped, flag_seated, round_started, unit_spawned and unit_destroyed and
## answers flag_status(), carrier_type_index(), unit_types() and tokens_left(). Required: without
## it the HUD pushes an error and shows nothing.
@export var match_controller: MatchController

## The Unit whose hit points and Fuel this HUD shows: the node that emits hit_points_changed and
## fuel_changed. Required: without it the HUD pushes an error and shows nothing. The scene stores
## this Player's Unit on each instance, the Unit of player_index in the MatchController's arrays.
@export var unit: Unit

## Whose HUD this is, in the MatchController's numbering: 0 is Player 1, 1 is Player 2. Required,
## with no default (-1 means not set): the owning scene stores it on each instance, and a
## forgotten one pushes an error and shows nothing instead of quietly showing Player 1's
## Flags on Player 2's screen. The default is -1 and not 0 because the engine leaves an
## exported value that equals its script default out of a saved scene, which would drop a stored 0.
@export var player_index: int = -1

@export_group("Text")
## The hit-point line with two placeholders (%d): the hit points left, then the maximum;
## "HP %d / %d" in player_hud.tscn. Looked up with tr(), so it is also the translation key.
## Required, with no default: the text is data in the scene and never a literal in this script.
@export var hit_points_format: String = ""

## The Fuel line with two placeholders (%d): the Fuel left, then the capacity; "Fuel %d / %d" in
## player_hud.tscn (Story 006 AC-7). Looked up with tr(), so it is also the translation key.
## Required, with no default: the text is data in the scene and never a literal in this script.
@export var fuel_format: String = ""

## The Tokens line with two placeholders: the carrier type's name (%s), then its Tokens left (%d);
## "%s Tokens: %d" in player_hud.tscn (Story 008 AC-6). Looked up with tr(), so it is also the
## translation key. Required, with no default: the text is data in the scene and never a literal
## in this script.
@export var tokens_format: String = ""

## The status line while this Player's Unit carries the other Player's Flag
## (FlagStatus.CARRYING_ENEMY). Looked up with tr(). Required, with no default.
@export var carrying_text: String = ""

## The status line while this Player's own Flag stands on its Base's seat and the Player
## carries nothing foreign (FlagStatus.OWN_AT_HOME). Looked up with tr(). Required, with no
## default.
@export var home_text: String = ""

## The status line while this Player's own Flag is away, stolen, dropped or on its way home,
## and the Player carries nothing foreign (FlagStatus.OWN_AWAY). Looked up with tr().
## Required, with no default.
@export var away_text: String = ""

@export_group("Look")
## The Team edge this HUD draws round its band (Story 007 AC-11; the class doc's Team edge): a
## StyleBox, in split_screen.tscn the Player's Team edge, src/ui/hud/data/team_orange_edge.tres or
## team_teal_edge.tres. Optional: null, the default, draws nothing (the look before Story 007).
@export var edge_style: StyleBox

@onready var _bar: ProgressBar = %HitPointsBar
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _fuel_bar: ProgressBar = %FuelBar
@onready var _fuel_label: Label = %FuelLabel
@onready var _status_label: Label = %FlagStatusLabel
@onready var _tokens_label: Label = %TokensLabel


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PlayerHud '%s': %s, so it shows nothing." % [name, problem])
		visible = false
		return
	unit.hit_points_changed.connect(_on_hit_points_changed)
	unit.fuel_changed.connect(_on_fuel_changed)
	match_controller.flag_picked_up.connect(_on_flag_picked_up)
	match_controller.flag_dropped.connect(_on_flag_dropped)
	match_controller.flag_seated.connect(_on_flag_seated)
	match_controller.round_started.connect(_on_round_started)
	match_controller.unit_spawned.connect(_on_unit_spawned)
	match_controller.unit_destroyed.connect(_on_unit_destroyed)
	var max_hit_points: float = unit.stats.max_hit_points if unit.stats != null else 0.0
	_on_hit_points_changed(unit.hit_points, max_hit_points)
	_on_fuel_changed(unit.fuel, unit.fuel_capacity)
	_show_status()
	_show_tokens()
	if edge_style != null:
		for element: Control in _band_elements():
			element.resized.connect(queue_redraw)
		queue_redraw()


## Draws edge_style round the band, grown on each side by the style's margin (the class doc's Team
## edge); draws nothing while edge_style is null.
func _draw() -> void:
	if edge_style == null:
		return
	var edge: Rect2 = _band_rect().grow_individual(edge_style.get_margin(SIDE_LEFT),
			edge_style.get_margin(SIDE_TOP), edge_style.get_margin(SIDE_RIGHT),
			edge_style.get_margin(SIDE_BOTTOM))
	draw_style_box(edge_style, edge)


## The elements of the band, in tree order: every Control child of this HUD (the class doc's Team
## edge); today the hit-point bar and its line, the Fuel bar and its line, the status line and the
## Tokens line.
func _band_elements() -> Array[Control]:
	var elements: Array[Control] = []
	for child: Node in get_children():
		if child is Control:
			elements.append(child as Control)
	return elements


## The band in this HUD's own coordinates: the smallest rectangle that holds every element of the
## band. It starts from the hit-point bar, one of them, because merging an empty Rect2 would add
## the origin.
func _band_rect() -> Rect2:
	var band: Rect2 = _bar.get_rect()
	for element: Control in _band_elements():
		band = band.merge(element.get_rect())
	return band


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if unit == null:
		return "unit is not assigned"
	if player_index < 0:
		return "player_index is not set (store 0 for Player 1 or 1 for Player 2 in the scene)"
	var problem: String = _format_problem()
	if problem.is_empty():
		problem = _status_text_problem()
	return problem


## What is wrong with the three line formats, as a sentence, or an empty string when nothing is:
## each is required and needs two placeholders (the value, then the maximum; for the Tokens line,
## _tokens_format_problem(), the type's name, then the count).
func _format_problem() -> String:
	if hit_points_format.is_empty():
		return "hit_points_format is not set (store the hit-point line, with two %d placeholders, in the scene)"
	if hit_points_format.count("%") < 2:
		return "hit_points_format '%s' lacks the two placeholders for the hit points and the maximum" % hit_points_format
	if fuel_format.is_empty():
		return "fuel_format is not set (store the Fuel line, with two %d placeholders, in the scene)"
	if fuel_format.count("%") < 2:
		return "fuel_format '%s' lacks the two placeholders for the Fuel and the capacity" % fuel_format
	return _tokens_format_problem()


## What is wrong with the Tokens format, as a sentence, or an empty string when nothing is: it is
## required and needs two placeholders, the carrier type's name and the Tokens.
func _tokens_format_problem() -> String:
	if tokens_format.is_empty():
		return "tokens_format is not set (store the Tokens line, with a %s and a %d placeholder, in the scene)"
	if tokens_format.count("%") < 2:
		return "tokens_format '%s' lacks the two placeholders for the type's name and the Tokens" % tokens_format
	return ""


## What is wrong with the three status texts, as a sentence, or an empty string when nothing is:
## each is required.
func _status_text_problem() -> String:
	if carrying_text.is_empty():
		return "carrying_text is not set (store the status line for carrying the enemy Flag in the scene)"
	if home_text.is_empty():
		return "home_text is not set (store the status line for the own Flag at home in the scene)"
	if away_text.is_empty():
		return "away_text is not set (store the status line for the own Flag away in the scene)"
	return ""


## Shows the hit points: the bar (maximum first) and the line with both numbers rounded up. The
## maximum is left alone when it is not above zero (a Unit that refused to drive reports none).
func _on_hit_points_changed(hit_points: float, max_hit_points: float) -> void:
	if max_hit_points > 0.0:
		_bar.max_value = max_hit_points
	_bar.value = hit_points
	_hit_points_label.text = tr(hit_points_format) % [ceili(hit_points), ceili(max_hit_points)]


## Shows the Fuel (Story 006 AC-7): the gauge (maximum first) and its line with both numbers
## rounded up. The maximum is left alone when the capacity is not above zero (a maximum of zero
## draws a full bar).
func _on_fuel_changed(fuel: float, capacity: float) -> void:
	if capacity > 0.0:
		_fuel_bar.max_value = capacity
	_fuel_bar.value = fuel
	_fuel_label.text = tr(fuel_format) % [ceili(fuel), ceili(capacity)]


## Chooses the status line again from the controller's answer for this Player.
func _show_status() -> void:
	if not is_instance_valid(match_controller):
		return
	var status: int = match_controller.flag_status(player_index)
	if status == MatchController.FlagStatus.CARRYING_ENEMY:
		_status_label.text = tr(carrying_text)
	elif status == MatchController.FlagStatus.OWN_AWAY:
		_status_label.text = tr(away_text)
	else:
		_status_label.text = tr(home_text)


## Shows the Player's Tokens of the carrier type (the class doc's Tokens line), or hides the line
## with an empty text while the controller names no carrier type: before begin() and after a
## refused one. The index is checked before it is used.
func _show_tokens() -> void:
	var carrier: int = -1
	var types: Array[UnitStats] = []
	if is_instance_valid(match_controller):
		carrier = match_controller.carrier_type_index()
		types = match_controller.unit_types()
	if carrier < 0 or carrier >= types.size():
		_tokens_label.text = ""
		_tokens_label.visible = false
		return
	var tokens: int = match_controller.tokens_left(player_index, carrier)
	_tokens_label.text = tr(tokens_format) % [tr(types[carrier].display_name), tokens]
	_tokens_label.visible = true


## A Unit picked up a Flag: either Player's status can have changed (the Carrier's, or the
## owner's whose Flag is now away), so the line is chosen again.
func _on_flag_picked_up(_carrier_index: int, _flag_index: int) -> void:
	_show_status()


## A Flag dropped at its Carrier's wreck: the Carrier no longer carries, so the line is chosen
## again.
func _on_flag_dropped(_flag_index: int) -> void:
	_show_status()


## A Flag stands on its Base's seat again: its owner's line is chosen again.
func _on_flag_seated(_flag_index: int) -> void:
	_show_status()


## The Round began, or began again with every Flag home and both stocks full: the status line is
## chosen again and the Tokens line shown.
func _on_round_started() -> void:
	_show_status()
	_show_tokens()


## A Unit was put on its Base (Round start, respawn or restart): the line is chosen again; the
## hit points arrive through the Unit's own signal.
func _on_unit_spawned(_spawned_player_index: int) -> void:
	_show_status()


## A Unit was destroyed: when it is this Player's, its Token is already taken, so the Tokens line is
## read again. Another Player's destruction changes nothing here.
func _on_unit_destroyed(destroyed_player_index: int) -> void:
	if destroyed_player_index == player_index:
		_show_tokens()
