class_name RoundOverScreen
extends Control
## The Round-over screen of one view: nothing while the Round runs; when the Round ends, a centred
## dark panel that names the winning Player, or says that nobody won, and the key that starts the
## next Round; nothing again when that Round starts. The Round ends in one of three ways: a
## delivery (a Player carried the other Player's Flag into their own Base), a loss (a Player's last
## Motorbike was destroyed, so the other Player wins) or a double loss (both Players lost their
## last Motorbike on the same tick, so nobody wins).
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-6 (a
## Round-over screen names the winning Player and offers restart on a key) and AC-8 (all text and
## elements fit inside a 640 x 720 viewport with no clipping or overflow);
## production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-7 (the screen names the
## winner in both views whichever way the Round ended, and says that nobody won after the double
## loss); design/game-brief.md MVP features 4 and 8; design/rules.md "Destruction and respawn".
## Vocabulary: CONTEXT.md (Player, Round, Motorbike).
##
## Display only (.claude/rules/ui-code.md). The Round belongs to the MatchController and the
## restart key to RoundRestartInput. This screen connects to the controller's round_over and
## round_started signals and compares the winner that round_over carries with the controller's
## NO_WINNER constant, and that is all it asks of it: it owns no state another node reads, calls
## nothing that changes the Round and reads no input.
## The key it names is read from the Input Map, the key bound to the action RoundRestartInput
## reads, never typed here, so a new binding in project.godot changes the line with no edit to
## this script. Take it out of the scene and the Round ends and restarts unchanged; only the
## message is gone.
##
## One instance per Player's view, directly under that Player's SubViewport and last among its
## children, after the camera, the countdown and the HUD, so it is drawn over them
## (split_screen.tscn: Player1RoundOver, Player2RoundOver). Both show the same message: the Round
## is over for both Players. A Control in a SubViewport is laid out against the viewport, so the
## full-rect anchors in round_over_screen.tscn make this screen as big as that Player's view
## (640 x 720 in the 1280 x 720 window), and the panel in it is centred by anchors at 0.5 on all
## four sides with offsets of 260 px either side: 520 px wide, 60 px of margin each side of a 640
## px view (AC-8; the Story 004 evidence doc keeps the measured rectangles), and as tall as its two
## lines, which wrap inside it (word-smart autowrap) when a translation is longer.
##
## States, two: hidden (the Round runs, or no Round has begun) and shown (the Round is over).
## The table is complete; a pair it does not list cannot happen.
##   hidden -> shown   the controller emitted round_over(winner_index), whichever way the Round
##                     ended: both lines are rebuilt from it (the winner line for the Player
##                     winner_index + 1, or the nobody line when winner_index is NO_WINNER, the
##                     double loss) and the screen is made visible
##   shown  -> hidden  the controller emitted round_started: the restart
##   hidden -> hidden  the controller emitted round_started at the start of the first Round
## _ready() starts in hidden.
##
## Whichever way the Round ends pauses the tree (MatchController, at the end of the tick that
## decided it) and round_over arrives after that pause; a Control made visible from a signal
## handler while the tree is paused is drawn all the same. The owning scene stores process_mode
## ALWAYS on this screen: it is the one Control that lives in the freeze, and whatever it ever does
## per frame (nothing today; this script has no _process) runs while the game stands still.
##
## Who won. round_over carries a winner_index: 0 or 1 when a delivery or a loss decided the Round,
## and NO_WINNER (-1) when both Players lost their last Motorbike on the same tick. Inside a
## round_over handler the Round is over, so -1 can only mean that nobody won, and the screen shows
## the nobody line instead of the winner line. The winner may be a Player whose own Unit is
## destroyed at that moment (a loss is decided by Tokens, not by who is still driving), so this
## screen says only what the controller announced.
##
## Text. The winner line format ("Player %d wins!", one %d placeholder for the Player's number,
## winner_index + 1), the nobody line ("Nobody wins!", no placeholder) and the restart line
## format ("Press %s to play again", one %s placeholder for the key's name) are data in
## round_over_screen.tscn; no player-facing string is written in this script. Each goes through
## tr(): no translation system exists yet, so tr() returns the text unchanged, and once one does
## each text is its key. The key's name is OS.get_keycode_string() of the physical key the Input
## Map binds to the round_restart action (the name of the bound key, read when the screen is shown,
## so a binding changed at runtime is named when the Round next ends; an action with no key bound
## names nothing). The keyboard is the only input the game has so far, so no gamepad binding is
## named (none exists to read).

## The MatchController this screen listens to: the node that emits round_over and round_started.
## Required: without it the screen pushes an error and shows nothing.
@export var match_controller: MatchController

@export_group("Text")
## The winner line with one placeholder (%d) for the winning Player's number, 1 for Player 1:
## "Player %d wins!" in round_over_screen.tscn. Looked up with tr(), so it is also the
## translation key. Required, with no default: the text is data in the scene and never a literal
## in this script.
@export var winner_format: String = ""

## The line for a Round nobody won, after the double loss (round_over carries NO_WINNER): "Nobody
## wins!" in round_over_screen.tscn (Story 008 AC-7). It has no placeholder. Looked up with tr(),
## so it is also the translation key. Required, with no default: the text is data in the scene and
## never a literal in this script.
@export var nobody_text: String = ""

## The restart line with one placeholder (%s) for the name of the key bound to the restart
## action: "Press %s to play again" in round_over_screen.tscn. Looked up with tr(), so it is also
## the translation key. Required, with no default.
@export var restart_format: String = ""

@onready var _winner_label: Label = %WinnerLabel
@onready var _restart_label: Label = %RestartLabel


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("RoundOverScreen '%s': %s, so it shows nothing." % [name, problem])
		visible = false
		return
	match_controller.round_over.connect(_on_round_over)
	match_controller.round_started.connect(_on_round_started)
	visible = false


## What is wrong with the exports or the Input Map, as a sentence, or an empty string when
## nothing is.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	var problem: String = _first_text_problem()
	if not problem.is_empty():
		return problem
	if not InputMap.has_action(RoundRestartInput.ACTION_RESTART):
		return "Input Map action '%s' does not exist, so no restart key can be named" % RoundRestartInput.ACTION_RESTART
	return ""


## What is wrong with the three texts, as a sentence, or an empty string when nothing is: the
## winner format (one placeholder), the nobody line and the restart format (one placeholder).
func _first_text_problem() -> String:
	if winner_format.is_empty():
		return "winner_format is not set (store the winner line, with a %d placeholder, in the scene)"
	if not winner_format.contains("%"):
		return "winner_format '%s' has no placeholder for the winning Player's number" % winner_format
	if nobody_text.is_empty():
		return "nobody_text is not set (store the line for a Round nobody won in the scene)"
	if restart_format.is_empty():
		return "restart_format is not set (store the restart line, with a %s placeholder, in the scene)"
	if not restart_format.contains("%"):
		return "restart_format '%s' has no placeholder for the key's name" % restart_format
	return ""


## Enters the shown state: the first line rebuilt for the winner (Player winner_index + 1), or the
## nobody line for NO_WINNER, the second for the key the Input Map binds to the restart action now,
## then visible.
func _show_result(winner_index: int) -> void:
	if winner_index == MatchController.NO_WINNER:
		_winner_label.text = tr(nobody_text)
	else:
		_winner_label.text = tr(winner_format) % (winner_index + 1)
	_restart_label.text = tr(restart_format) % _restart_key_name()
	visible = true


## The name of the key the Input Map binds to the Round-restart action: OS.get_keycode_string()
## of the physical keycode of the action's first key event, or an empty string when the action
## has no key event.
func _restart_key_name() -> String:
	for event: InputEvent in InputMap.action_get_events(RoundRestartInput.ACTION_RESTART):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			return OS.get_keycode_string(key_event.physical_keycode)
	return ""


## The Round ended, by a delivery, a loss or a double loss: show the winner, or that nobody won,
## and the restart key.
func _on_round_over(winner_index: int) -> void:
	_show_result(winner_index)


## The Round began, or began again after the restart: hide.
func _on_round_started() -> void:
	visible = false
