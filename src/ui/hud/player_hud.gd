class_name PlayerHud
extends Control
## One Player's HUD: that Player's hit points, as a bar with a "HP n / max" line on it, and where
## that Player stands with the Water Canisters, as one line of text; in the top band of that
## Player's own view and nowhere else.
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-7 (each
## viewport has a HUD showing that Player's hit points and canister status: carrying the
## opponent's canister / own canister at home / own canister away) and AC-8 (all text and elements
## fit inside a 640 x 720 viewport with no clipping or overflow); design/game-brief.md MVP feature
## 4. Vocabulary: CONTEXT.md (Player, Unit, Base, Round, Water Canister, Carrier).
##
## Display only (.claude/rules/ui-code.md). The hit points belong to the Unit and the canisters to
## the MatchController. This HUD connects to the Unit's hit_points_changed and to the controller's
## canister_picked_up, canister_dropped, canister_seated, round_started and unit_spawned, reads
## canister_status() and, once, the Unit's hit points, and that is all it asks of them: it owns no
## state another node reads, calls nothing that changes the Unit or the Round and reads no input.
## Take it out of the scene and the Round plays on unchanged.
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
## max_hit_points) sets the bar (max_value before value, so the value is never clamped against a
## stale maximum) and rebuilds the line, tr(hit_points_format) with both numbers rounded up
## (ceili: a %d placeholder truncates, and a Unit alive with 0.4 hit points must never read 0);
## the first values are read once in _ready() from the Unit. The Unit emits once per change (a
## hit it survives, its destruction with zero, its spawn with the refill), so the bar shows the
## last completed change and nothing in between. Canister status: the one line is chosen again
## from match_controller.canister_status(player_index) whenever the controller emits
## canister_picked_up, canister_dropped, canister_seated, round_started or unit_spawned, the five
## signals after which its answer can differ, and once in _ready().
##
## States of the status line, three, the MatchController.CanisterStatus values, each shown as the
## text the scene stores for it:
##   CARRYING_ENEMY  carrying_text  this Player's Unit carries the other Player's canister
##   OWN_AT_HOME     home_text      this Player's canister stands on its Base's seat and the
##                                  Player carries nothing foreign; also before the Round begins,
##                                  which is what the controller answers then
##   OWN_AWAY        away_text      this Player's canister is stolen, lies dropped or rides home
##                                  on its owner's Unit, and the Player carries nothing foreign
## Every change between them is the controller's and is announced by one of the five signals
## above, so the line follows it on the tick it happens. The Unit's destruction changes the hit
## points only: the status line names the canisters, not the Unit, and a Player waiting to
## respawn still reads where its canister is.
##
## Text. The hit-point format ("HP %d / %d": the hit points left, then the maximum) and the three
## status texts are data in player_hud.tscn; no player-facing string is written in this script.
## Each goes through tr(): no translation system exists yet, so tr() returns the text unchanged,
## and once one does each text is its key and this script needs no change. Every Label stores
## word-smart autowrap, so a longer translation wraps inside its band instead of growing past
## the view.
##
## Layout, stored in player_hud.tscn, by anchors in the top band of the view: the bar and its line
## at (16, 16), 300 x 24; the status line below it at y 46, from 16 px to 16 px from the edges;
## nothing lower than about 90 px, so the middle of the view stays clear for the Unit and the
## centred respawn countdown. It fits a 640 x 720 view with nothing clipped (AC-8; the Story 004
## evidence doc keeps the measured rectangles). White text with a 6 px dark outline reads over
## the sky, the grey field and either Player's coloured Base. mouse_filter is ignore on every
## node, so the HUD never takes a click from what is under it.

## The MatchController this HUD reads for the canister status: the node that emits
## canister_picked_up, canister_dropped, canister_seated, round_started and unit_spawned and
## answers canister_status(). Required: without it the HUD pushes an error and shows nothing.
@export var match_controller: MatchController

## The Unit whose hit points this HUD shows: the node that emits hit_points_changed. Required:
## without it the HUD pushes an error and shows nothing. The scene stores this Player's Unit on
## each instance, the Unit of player_index in the MatchController's arrays.
@export var unit: Unit

## Whose HUD this is, in the MatchController's numbering: 0 is Player 1, 1 is Player 2. Required,
## with no default (-1 means not set): the owning scene stores it on each instance, and a
## forgotten one pushes an error and shows nothing instead of quietly showing Player 1's
## canisters on Player 2's screen. The default is -1 and not 0 because the engine leaves an
## exported value that equals its script default out of a saved scene, which would drop a stored 0.
@export var player_index: int = -1

@export_group("Text")
## The hit-point line with two placeholders (%d): the hit points left, then the maximum;
## "HP %d / %d" in player_hud.tscn. Looked up with tr(), so it is also the translation key.
## Required, with no default: the text is data in the scene and never a literal in this script.
@export var hit_points_format: String = ""

## The status line while this Player's Unit carries the other Player's canister
## (CanisterStatus.CARRYING_ENEMY). Looked up with tr(). Required, with no default.
@export var carrying_text: String = ""

## The status line while this Player's own canister stands on its Base's seat and the Player
## carries nothing foreign (CanisterStatus.OWN_AT_HOME). Looked up with tr(). Required, with no
## default.
@export var home_text: String = ""

## The status line while this Player's own canister is away, stolen, dropped or on its way home,
## and the Player carries nothing foreign (CanisterStatus.OWN_AWAY). Looked up with tr().
## Required, with no default.
@export var away_text: String = ""

@onready var _bar: ProgressBar = %HitPointsBar
@onready var _hit_points_label: Label = %HitPointsLabel
@onready var _status_label: Label = %CanisterStatusLabel


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PlayerHud '%s': %s, so it shows nothing." % [name, problem])
		visible = false
		return
	unit.hit_points_changed.connect(_on_hit_points_changed)
	match_controller.canister_picked_up.connect(_on_canister_picked_up)
	match_controller.canister_dropped.connect(_on_canister_dropped)
	match_controller.canister_seated.connect(_on_canister_seated)
	match_controller.round_started.connect(_on_round_started)
	match_controller.unit_spawned.connect(_on_unit_spawned)
	var max_hit_points: float = unit.stats.max_hit_points if unit.stats != null else 0.0
	_on_hit_points_changed(unit.hit_points, max_hit_points)
	_show_status()


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if unit == null:
		return "unit is not assigned"
	if player_index < 0:
		return "player_index is not set (store 0 for Player 1 or 1 for Player 2 in the scene)"
	if hit_points_format.is_empty():
		return "hit_points_format is not set (store the hit-point line, with two %d placeholders, in the scene)"
	if hit_points_format.count("%") < 2:
		return "hit_points_format '%s' lacks the two placeholders for the hit points and the maximum" % hit_points_format
	if carrying_text.is_empty():
		return "carrying_text is not set (store the status line for carrying the enemy canister in the scene)"
	if home_text.is_empty():
		return "home_text is not set (store the status line for the own canister at home in the scene)"
	if away_text.is_empty():
		return "away_text is not set (store the status line for the own canister away in the scene)"
	return ""


## Shows the hit points: the bar (maximum first) and the line with both numbers rounded up. The
## maximum is left alone when it is not above zero (a Unit that refused to drive reports none).
func _on_hit_points_changed(hit_points: float, max_hit_points: float) -> void:
	if max_hit_points > 0.0:
		_bar.max_value = max_hit_points
	_bar.value = hit_points
	_hit_points_label.text = tr(hit_points_format) % [ceili(hit_points), ceili(max_hit_points)]


## Chooses the status line again from the controller's answer for this Player.
func _show_status() -> void:
	if not is_instance_valid(match_controller):
		return
	var status: int = match_controller.canister_status(player_index)
	if status == MatchController.CanisterStatus.CARRYING_ENEMY:
		_status_label.text = tr(carrying_text)
	elif status == MatchController.CanisterStatus.OWN_AWAY:
		_status_label.text = tr(away_text)
	else:
		_status_label.text = tr(home_text)


## A Unit picked up a canister: either Player's status can have changed (the Carrier's, or the
## owner's whose canister is now away), so the line is chosen again.
func _on_canister_picked_up(_carrier_index: int, _canister_index: int) -> void:
	_show_status()


## A canister dropped at its Carrier's wreck: the Carrier no longer carries, so the line is chosen
## again.
func _on_canister_dropped(_canister_index: int) -> void:
	_show_status()


## A canister stands on its Base's seat again: its owner's line is chosen again.
func _on_canister_seated(_canister_index: int) -> void:
	_show_status()


## The Round began, or began again with every canister home: the line is chosen again.
func _on_round_started() -> void:
	_show_status()


## A Unit was put on its Base (Round start, respawn or restart): the line is chosen again; the
## hit points arrive through the Unit's own signal.
func _on_unit_spawned(_spawned_player_index: int) -> void:
	_show_status()
