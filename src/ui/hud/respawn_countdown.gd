class_name RespawnCountdown
extends Label
## One Player's respawn countdown: "Respawn in 3", then 2, then 1, in that Player's own view while
## that Player's Unit is destroyed and waits at its Base, and nothing while the Unit is alive.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-6 (while a
## Player is waiting to respawn, their viewport shows the seconds remaining); design/game-brief.md
## MVP feature 3 (Bases, destruction and respawn); story-004-water-canister-and-win.md AC-6 (the
## Round-over screen takes the view: the countdown hides when the Round is over). Vocabulary:
## CONTEXT.md (Player, Unit, Base, Round).
##
## Display only (.claude/rules/ui-code.md). The Round belongs to the MatchController. This label
## connects to its unit_destroyed, unit_spawned and round_over signals and reads
## seconds_until_respawn() and is_round_over(), and that is all it asks of it: it owns no state
## another node reads, calls nothing that changes the Round and reads no input. Take it out of the
## scene and the Round plays on unchanged.
##
## One instance per Player, directly under that Player's SubViewport beside that Player's camera
## (split_screen.tscn). A Control in a SubViewport is laid out against the viewport, so the
## full-rect anchors in respawn_countdown.tscn make the label exactly as big as that Player's view
## (640 x 720 in the 1280 x 720 window) and the text sits in its centre: it is drawn in that
## Player's view and in no other. player_index says whose countdown it is (0 is Player 1, the
## MatchController's numbering); the scene stores it on each instance.
##
## States, two: hidden (the Player's Unit is in play, no Round has begun, or the Round is over) and
## counting (the Player's Unit waits to respawn while the Round runs). Each label follows its own
## Player alone: a signal for another player_index is ignored. The table is complete; a pair it
## does not list cannot happen.
##   hidden   -> counting  the controller emitted unit_destroyed for this player_index while the
##                         Round runs
##   counting -> hidden    the controller emitted unit_spawned for this player_index (respawn)
##   counting -> hidden    the controller reports no wait for this player_index:
##                         seconds_until_respawn() is zero, so no respawn is coming (the Player was
##                         dropped out of the Round)
##   counting -> hidden    the controller emitted round_over: the Round ended (a delivery, a loss or
##                         a double loss: Story 004 AC-6, Story 008 AC-4), the Round-over screen
##                         takes the view, and no respawn comes until the restart, which emits
##                         round_started and no unit_spawned
##   hidden   -> hidden    the controller emitted unit_spawned for this player_index (the start
##                         of the Round, or the restart: the Player was never waiting)
##   hidden   -> hidden    the controller emitted round_over while this Player's Unit was in play;
##                         or unit_destroyed arrives while the Round is over (it cannot: the tree
##                         is paused then; refused all the same, so the label never shows during a
##                         Round that is over)
## _ready() starts in counting when the Round runs and the controller already reports a wait for
## this Player (a label added after the Round began) and in hidden otherwise.
##
## The digit. While counting, every rendered frame the text is rebuilt as
## tr(format) % ceili(seconds_until_respawn(player_index)); _process runs only then. The controller
## counts the wait in physics ticks and its seconds are exact, so the digit changes on whole
## seconds: with the 3 second delay of match_rules.tres it reads 3 for the first second, then 2,
## then 1, and the label is gone on the tick of the respawn. Read from _process, the seconds are
## those of the last completed physics tick (see MatchController.seconds_until_respawn()). The
## label keeps no clock of its own, so it cannot drift from the respawn it announces. When the
## respawn is due but another Unit stands on the Base's spawn point, the controller puts the Unit
## on a spare spawn point of the Base on that same tick, and the label goes as at any respawn;
## while every spot of the Base is taken, the controller answers one tick, so the label reads 1
## until a spot frees and the Unit is put there (there is no bounded wait to count down). When the
## controller reports no wait at all for this Player (it was dropped out of the Round, so no
## respawn is coming) the label leaves the counting state at once and never shows a countdown that
## has run out.
##
## Text. The format is data in the scene, "Respawn in %d" with one placeholder for the whole
## seconds left; no player-facing string is written in this script. It goes through tr(): no
## translation system exists yet, so tr() returns the format unchanged, and once one does the
## format is its key and this script needs no change.
##
## Look, stored in respawn_countdown.tscn: centred both ways, 64 px, white with a dark 8 px outline
## so it reads over the grey field and either Player's coloured Base. mouse_filter is the Label
## default, ignore, so the label never takes a click from what is under it. The scene stores
## visible = false: that is what a Round shows until the first destruction.

## The MatchController this label reads: the node that emits unit_destroyed and unit_spawned and
## answers seconds_until_respawn(). Required: without it the label pushes an error and stays hidden.
@export var match_controller: MatchController

## Whose countdown this is, in the MatchController's numbering: 0 is Player 1, 1 is Player 2.
## Required, with no default (-1 means not set): the owning scene stores it on each instance, and
## a forgotten one pushes an error and stays hidden instead of quietly showing Player 1's wait on
## Player 2's screen. The default is -1 and not 0 because the engine leaves an exported value that
## equals its script default out of a saved scene, which would drop a stored 0.
@export var player_index: int = -1

## The countdown text with one placeholder (%d) for the whole seconds left: "Respawn in %d" in
## respawn_countdown.tscn. Looked up with tr(), so it is also the translation key. Required, with
## no default: the text is data in the scene and never a literal in this script.
@export var format: String = ""


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("RespawnCountdown '%s': %s, so it shows nothing." % [name, problem])
		_set_counting(false)
		return
	match_controller.unit_destroyed.connect(_on_unit_destroyed)
	match_controller.unit_spawned.connect(_on_unit_spawned)
	match_controller.round_over.connect(_on_round_over)
	_set_counting(not match_controller.is_round_over()
		and match_controller.seconds_until_respawn(player_index) > 0.0)


## Keeps the text current while counting. Processing is switched off the rest of the time.
func _process(_delta: float) -> void:
	_show_seconds()


## Enters the counting state (shown, text kept current every frame) or the hidden one (not drawn,
## not processed). The text is set at once on entering, so the first frame shows the full delay.
func _set_counting(counting: bool) -> void:
	visible = counting
	set_process(counting)
	if counting:
		_show_seconds()


## Rebuilds the text from the whole seconds the controller says are left for this Player, and leaves
## the counting state when it says there are none: no respawn is coming.
func _show_seconds() -> void:
	if not is_instance_valid(match_controller):
		return
	var remaining: float = match_controller.seconds_until_respawn(player_index)
	if remaining <= 0.0:
		_set_counting(false)
		return
	text = tr(format) % ceili(remaining)


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if player_index < 0:
		return "player_index is not set (store 0 for Player 1 or 1 for Player 2 in the scene)"
	if format.is_empty():
		return "format is not set (store the countdown text, with a %d placeholder, in the scene)"
	if not format.contains("%"):
		return "format '%s' has no placeholder for the seconds" % format
	return ""


## This Player's Unit was destroyed: start counting, unless the Round is over (no respawn comes
## before the restart). Another Player's destruction is not ours.
func _on_unit_destroyed(destroyed_player_index: int) -> void:
	if destroyed_player_index == player_index and not match_controller.is_round_over():
		_set_counting(true)


## This Player's Unit was put on its Base, at the start of the Round, at the respawn or at the
## restart: hide. Another Player's spawn is not ours.
func _on_unit_spawned(spawned_player_index: int) -> void:
	if spawned_player_index == player_index:
		_set_counting(false)


## The Round ended, whoever won or nobody: hide. The Round-over screen takes the view, and the
## restart announces itself with round_started.
func _on_round_over(_winner_index: int) -> void:
	_set_counting(false)
