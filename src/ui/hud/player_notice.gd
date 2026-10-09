class_name PlayerNotice
extends Label
## One Player's one-line notice, in that Player's own view: "Destroy the turrets first" while that
## Player's Unit touches the other Player's Flag and only the other Base's Turrets keep it from
## taking it, and, for about a second and a half, the reason a Mine was not laid ("No Mines left",
## "No Mines in or near a Base", "No room for a Mine here"). Nothing otherwise. It is a plain
## one-line notice.
##
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-5 (the line shows in the view
## of the Player whose Motorbike touches a locked Flag and in no other, is gone when the lock lifts
## or the Round ends, sits clear of the HUD band, the Unit choice panel, the out-of-Fuel hint and
## the Round-over screen and fits the 640 x 720 view) and AC-9 (the text is data in the scene, read
## through tr()); production/epics/wasteland-fire/story-014-truck-mines.md AC-2 and AC-5 (a press
## that lays nothing shows that Player alone, for about 1.5 s on this line, why it was refused; the
## three texts and the time are data in the scene, read through tr(); the line is hidden when the
## Round ends and when it starts again); design/rules.md "Turrets, Flag Walls and Mines".
## Vocabulary: CONTEXT.md (Player, Flag, Turret, Mine, Round).
##
## Display only (.claude/rules/ui-code.md). The lock belongs to the Flag rules, the Round to the
## MatchController and the refusal to the MineLayer: this label asks the controller
## is_flag_locked_for(player_index) every frame, connects to its round_started and round_over and,
## when it has one, to its Player's MineLayer.lay_refused, and that is all it asks of them. It owns
## no state another node reads, calls nothing that changes the Round and reads no input. Take it out
## of the scene and the Round plays on unchanged. Unlike SelfDestructHint it keeps _process on
## whether it is shown or hidden, because nothing signals a touch of a Flag: a notice shown only
## through signals would never appear.
##
## One instance per Player, directly under that Player's SubViewport after the out-of-Fuel hint
## (split_screen.tscn: Player1Notice, Player2Notice), so it is drawn in that Player's view and in no
## other, and not under the PlayerHud, which draws its Team edge round every Control child.
##
## States, three, the table complete:
##   hidden  -> lock     the controller says the Player's Unit is kept from the Flag by the lock
##   lock    -> hidden   it no longer says so (the last Turret fell, the Unit left the Flag, it took
##                       another Flag)
##   hidden  -> refusal  the MineLayer emitted lay_refused: the reason's text shows for
##                       refusal_seconds, a new refusal replacing the one showing and restarting
##                       the time
##   refusal -> hidden   the time ran out and the lock does not hold (a Truck lays Mines and never
##                       takes a Flag, so the two never meet; the lock text shows again if it did)
##   any     -> hidden   the controller emitted round_over (a paused tree stops _process, so the
##                       Round-over screen would otherwise sit under a stale line)
## It polls again, with no refusal, from round_started. The refusal's time is counted in frames'
## delta, so the Round-over pause freezes it, and it is cleared at the Round's end and start.
##
## Look, stored in player_notice.tscn: the hint's: a dark translucent panel with rounded corners,
## the text centred at 24 px, white with a dark outline, mouse_filter ignore. It sits at x 40 to 600
## and y 128 to 178, under the Team edge (y 8 to 84) and the Mines line (y 92 to 120) and above the
## Round-over panel (y 296 to 424), far from the Unit choice panel and the hint at the bottom of the
## view.

## The MatchController this label asks. Required: without it the label pushes an error and stays
## hidden.
@export var match_controller: MatchController

## This Player's index in the MatchController (0 is Player 1): whose Unit the notice is about.
## Required, with no default: the scene stores it, and a forgotten one pushes an error and keeps the
## label hidden instead of showing the other Player's notice.
@export var player_index: int = -1

## The notice, "Destroy the turrets first" in player_notice.tscn. Looked up with tr(), so it is also
## the translation key. Required, with no default: the text is data in the scene and never a literal
## in this script.
@export var message: String = ""

## This Player's MineLayer, whose refusals the line shows (Story 014). Optional: a scene with none
## shows no refusal, and then the three texts and the time below are not read.
@export var mine_layer: MineLayer

## The refusal for a press with no Mine left, "No Mines left" in player_notice.tscn. Looked up with
## tr(). Required while mine_layer is assigned, with no default.
@export var none_left_text: String = ""

## The refusal for a drop point in or near a Base, "No Mines in or near a Base" in
## player_notice.tscn. Looked up with tr(). Required while mine_layer is assigned.
@export var near_base_text: String = ""

## The refusal for a drop point that is not open ground, "No room for a Mine here" in
## player_notice.tscn. Looked up with tr(). Required while mine_layer is assigned.
@export var no_room_text: String = ""

## Seconds a refusal stays (about 1.5 in player_notice.tscn). Required, above zero, while mine_layer
## is assigned.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:s") var refusal_seconds: float = 0.0

## Seconds of the refusal still to show; zero while none shows.
var _refusal_left: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PlayerNotice '%s': %s, so it stays hidden." % [name, problem])
		return
	text = tr(message)
	match_controller.round_started.connect(_on_round_started)
	match_controller.round_over.connect(_on_round_over)
	if mine_layer != null:
		mine_layer.lay_refused.connect(_on_lay_refused)
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if _refusal_left > 0.0:
		_refusal_left -= delta
		if _refusal_left > 0.0:
			return
		_refusal_left = 0.0
		text = tr(message)
	_refresh()


## Shows the notice while the controller says the lock alone stops this Player's pick-up, hides it
## otherwise; leaves a refusal that is showing alone.
func _refresh() -> void:
	if _refusal_left > 0.0:
		return
	visible = match_controller.is_flag_locked_for(player_index)


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if player_index < 0:
		return "player_index is not set (store the Player's index, 0 or 1, in the scene)"
	if message.is_empty():
		return "message is not set (store the notice in the scene)"
	if mine_layer != null:
		if none_left_text.is_empty() or near_base_text.is_empty() or no_room_text.is_empty():
			return "a refusal text is not set (store the three texts in the scene)"
		if refusal_seconds <= 0.0:
			return "refusal_seconds is not above zero (store the time in the scene)"
	return ""


## The text of a refusal's reason.
func _refusal_text(reason: MineLayer.Refusal) -> String:
	match reason:
		MineLayer.Refusal.NONE_LEFT:
			return none_left_text
		MineLayer.Refusal.NEAR_BASE:
			return near_base_text
	return no_room_text


## A press laid nothing: show why, in place of whatever the line shows, for refusal_seconds.
func _on_lay_refused(reason: MineLayer.Refusal) -> void:
	text = tr(_refusal_text(reason))
	_refusal_left = refusal_seconds
	visible = true


## A Round starts or starts again: no refusal is left over, and the lock is read afresh.
func _on_round_started() -> void:
	_refusal_left = 0.0
	text = tr(message)
	_refresh()


## The Round ended: the Round-over screen takes the view, so the notice goes.
func _on_round_over(_winner_index: int) -> void:
	_refusal_left = 0.0
	text = tr(message)
	visible = false
