class_name SelfDestructHint
extends Label
## One Player's out-of-Fuel hint, "Out of Fuel! Press Tab to Self-destruct", in that Player's own
## view while that Player's ground Unit is stranded (its tank empty, so it cannot drive), and
## nothing otherwise. It names that Player's own Self-destruct key, read from the Input Map. While
## the Unit is stranded inside its own Base with the swap on, that key swaps the Unit instead
## ("Out of Fuel! Press Tab to swap your Unit"), and the hint says so.
##
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-5 (when a
## Player's ground Unit runs out of Fuel, that Player's view shows how to Self-destruct with that
## Player's own key; the hint goes when the Unit is refuelled, destroyed or benched and when the
## Round ends, never shows for a Gyrocopter or in the other view, and fits the 640 x 720 view) and
## AC-6 (its text is data in the scene);
## production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md AC-4 (a ground Unit out of Fuel
## inside its own Base shows the hint for the swap instead of the Self-destruct, because the key does
## something else there; the text is scene data, through tr()); design/rules.md "Destruction and
## respawn" (a ground Unit with no Fuel stops, and the Self-destruct lets a stranded Player get a new
## Unit). Vocabulary: CONTEXT.md (Player, Unit, Fuel, Self-destruct, Round, Gyrocopter).
##
## Display only (.claude/rules/ui-code.md). The Fuel belongs to the Unit and the Round to the
## MatchController. This label connects to the Unit's fuel_changed and to the controller's
## round_started and round_over, reads the Unit's is_stranded and the controller's is_round_over()
## and can_swap(), and that is all it asks of them: it owns no state another node reads, calls
## nothing that changes the Unit or the Round and reads no input (the key's name comes from the Input
## Map, not from a key press). Take it out of the scene and the Round plays on unchanged.
##
## One instance per Player, directly under that Player's SubViewport beside that Player's camera,
## countdown and HUD (split_screen.tscn: Player1SelfDestructHint, Player2SelfDestructHint). A
## Control in a SubViewport is laid out against the viewport, so it is drawn in that Player's view
## and in no other. It is not a child of the PlayerHud, which draws its Team edge round every
## Control child it has: the edge would stretch down the view to take the hint in. unit is that
## Player's Unit, player_index that Player's index in the MatchController and action_prefix that
## Player's Input Map prefix (p1_, p2_); the scene stores all three.
##
## States, two, read again from the Unit and the controller on each of the three signals and once
## in _ready(), and, while the hint is shown, on every frame (the text, below, follows the Unit
## across its Base's zone: a stranded Unit coasts for a few ticks after its tank runs dry, and the
## zone reports it a tick or two late). The table is complete; a pair it does not list cannot
## happen.
##   hidden -> shown   the Unit is stranded (Unit.is_stranded: alive, a ground type, its tank
##                     empty) while the Round runs: fuel_changed with zero, on the tick the tank
##                     runs dry
##   shown  -> hidden  the Unit is no longer stranded: refuelled (fuel_changed with Fuel, from a
##                     Fuel Can under it), destroyed by its Self-destruct or by a hit, or benched
##                     (each emits fuel_changed with zero once the Unit has left play)
##   shown  -> hidden  the controller emitted round_over: the Round-over screen takes the view
##   hidden -> hidden  everything else: a Unit with Fuel, a Gyrocopter (it crashes when it runs dry
##                     and is never stranded), a Unit out of play, a Round that is over, and
##                     round_started (the restart benches both Units, so nothing is stranded)
## The text is built each time the hint is read, so a binding changed at runtime is named the next
## time the hint shows. While the hint is hidden nothing is polled (no _process).
##
## Text. Two formats, both data in the scene, each with one %s placeholder for the key's name; no
## player-facing string is written in this script. format, "Out of Fuel! Press %s to Self-destruct",
## is shown everywhere the key destroys the Unit; swap_format, "Out of Fuel! Press %s to swap your
## Unit", while the controller's can_swap(player_index) is true (the swap is on and the Unit stands
## inside its own Base), because the key puts the Unit away there and the Round is not forfeited, not
## even on the last Motorbike. Each goes through tr(): no translation system exists yet, so tr()
## returns the format unchanged, and once one does the format is its key and this script needs no
## change. The key's name is built as the
## Unit choice panel builds its keys' names (UnitChoice._key_name(), duplicated here, TD-011): the
## physical key of the first key event of the action action_prefix + self_destruct (the action
## PlayerMatchInput reads), named by InputEventKey.as_text_physical_keycode() with the key's side in
## front when it has one (as_text_location()); "Tab" for Player 1 and "Enter" for Player 2 in
## project.godot. An action bound to no key names nothing. The keyboard is the only input so far.
##
## Look, stored in self_destruct_hint.tscn: a dark translucent panel with rounded corners in the
## lower part of the view, at x 40, 560 px wide like the Unit choice panel (the two never show
## together: a Player chooses only while their Unit is out of play), from 126 to 76 px above the
## bottom edge, growing upward if a translation wraps; the text centred at 24 px, white with a dark
## outline, word-smart autowrap so a longer translation wraps inside the panel. It covers no element
## of the HUD band (y 16 to 76). mouse_filter is ignore, so it never takes a click from what is
## under it. The scene stores visible = false: what the view shows until a Unit is stranded.

## The suffix of the Self-destruct action after the Player's prefix (PlayerMatchInput reads the
## same).
const _SUFFIX_SELF_DESTRUCT: String = "self_destruct"

## The MatchController this label reads: the node that emits round_started and round_over and
## answers is_round_over(). Required: without it the label pushes an error and stays hidden.
@export var match_controller: MatchController

## The Unit this label watches: the node that emits fuel_changed and answers is_stranded. Required:
## without it the label pushes an error and stays hidden. The scene stores this Player's Unit.
@export var unit: Unit

## Prefix of this Player's Input Map actions, for example p1_: the hint names the key of the action
## prefix + self_destruct. Required, with no default: the owning scene stores it, and an empty one
## pushes an error and keeps the label hidden instead of naming another Player's key.
@export var action_prefix: StringName = &""

## This Player's index in the MatchController (0 is Player 1): whose swap the hint asks about.
## Required, with no default: the scene stores it, and a forgotten one pushes an error and keeps the
## label hidden instead of reading the other Player's Base.
@export var player_index: int = -1

## The hint, with one %s placeholder for the key's name; "Out of Fuel! Press %s to Self-destruct" in
## self_destruct_hint.tscn. Looked up with tr(), so it is also the translation key. Required, with
## no default: the text is data in the scene and never a literal in this script.
@export var format: String = ""

## The hint while the key swaps the Unit (Story 011), with one %s placeholder for the key's name;
## "Out of Fuel! Press %s to swap your Unit" in self_destruct_hint.tscn. Looked up with tr(). Required,
## with no default, for the reason format gives.
@export var swap_format: String = ""

## The Self-destruct action whose key the hint names, action_prefix + self_destruct; set in
## _ready().
var _action: StringName = &""


func _ready() -> void:
	visible = false
	set_process(false)
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("SelfDestructHint '%s': %s, so it stays hidden." % [name, problem])
		return
	unit.fuel_changed.connect(_on_fuel_changed)
	match_controller.round_started.connect(_refresh)
	match_controller.round_over.connect(_on_round_over)
	_refresh()


## Shows the hint, with the key's name, while the Unit is stranded and the Round runs, in the swap
## text while the key swaps the Unit and in the Self-destruct text otherwise, and hides it otherwise
## (the class doc's states). Polls every frame while shown, and not at all while hidden.
func _refresh() -> void:
	if unit.is_stranded and not match_controller.is_round_over():
		var shown_format: String = swap_format if match_controller.can_swap(player_index) else format
		text = tr(shown_format) % _key_name()
		visible = true
	else:
		visible = false
	set_process(visible)


## The hint is shown: the Unit may have crossed its Base's zone since the last frame.
func _process(_delta: float) -> void:
	_refresh()


## What is wrong with the exports and the Input Map, as a sentence, or an empty string when nothing
## is. Sets the Self-destruct action's name on the way.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if unit == null:
		return "unit is not assigned"
	if action_prefix.is_empty():
		return "action_prefix is empty (store the Player's prefix, p1_ or p2_, in the scene)"
	if format.is_empty():
		return "format is not set (store the hint, with one %s placeholder for the key, in the scene)"
	if format.count("%s") != 1:
		return "format '%s' does not hold exactly one %%s placeholder for the key's name" % format
	if player_index < 0:
		return "player_index is not set (store the Player's index, 0 or 1, in the scene)"
	if swap_format.is_empty():
		return "swap_format is not set (store the hint for the swap, with one %s placeholder for the key, in the scene)"
	if swap_format.count("%s") != 1:
		return "swap_format '%s' does not hold exactly one %%s placeholder for the key's name" % swap_format
	_action = StringName(String(action_prefix) + _SUFFIX_SELF_DESTRUCT)
	if not InputMap.has_action(_action):
		return "Input Map action '%s' does not exist" % _action
	return ""


## The name of the key the Input Map binds to the Self-destruct action, from the physical key of the
## action's first key event: its engine name (as_text_physical_keycode()) with the key's side in
## front when it has one (as_text_location()); an empty string when the action has no key event.
func _key_name() -> String:
	for event: InputEvent in InputMap.action_get_events(_action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			var side: String = key_event.as_text_location()
			var key: String = key_event.as_text_physical_keycode()
			return key if side.is_empty() else "%s %s" % [side.capitalize(), key]
	return ""


## The Unit's Fuel changed: it ran dry, was refuelled, or left play. The hint follows.
func _on_fuel_changed(_fuel: float, _capacity: float) -> void:
	_refresh()


## The Round ended: the Round-over screen takes the view, so the hint goes.
func _on_round_over(_winner_index: int) -> void:
	visible = false
