extends RefCounted
## What the token_choice scenario needs beyond token_kit.gd: an ordered trail of the Round's choice
## signals, each with the physics frame it arrived on and whether each choice panel was shown; an
## action run inside a unit_destroyed handler, in the destruction's own step (a key set there is
## first read in the next step, the choice input's first tick as a choosing Player); a direct
## choose() and a sweep of steer presses; and the model of a choice panel that its readings are
## judged against (a type with no Token is dim, the slot under the cursor is marked only while its
## type has Tokens). Make one with ChoiceKit.new(harness, kit, tokens) after the Tokens kit, so its
## handlers run after the panels' and the Tokens kit's own.
## Tooling only: nothing under src/ depends on this file; loaded with a preload constant.

## The shared helpers (check_kit.gd): ticks, key presses.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, keys, the signal record with state snapshots.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## Every destroyed, chosen, spawned, started, over and cursor signal in order: {kind, player, type,
## frame, shown}; player is the winner on `over` (-1 on started), shown is [panel 1 visible, panel 2
## visible] at the signal, and a choice also holds `left`, the Tokens of its type the chooser had.
var trail: Array[Dictionary] = []

## The check helpers, the Tokens kit, the controller, and the action armed for the next destruction
## of each Player.
var _kit: Kit
var _tk: Tokens
var _controller: MatchController
var _armed: Dictionary[int, Callable] = {}


## Connects the trail to the controller and to both choice inputs.
func _init(check_kit: Kit, token_kit: Tokens) -> void:
	_kit = check_kit
	_tk = token_kit
	_controller = token_kit.controller
	_controller.unit_destroyed.connect(_on_destroyed)
	_controller.unit_chosen.connect(_on_chosen)
	_controller.unit_spawned.connect(func(player: int) -> void: _note(&"spawned", player, -1))
	_controller.round_started.connect(func() -> void: _note(&"started", -1, -1))
	_controller.round_over.connect(func(winner: int) -> void: _note(&"over", winner, -1))
	for player: int in Kit.PLAYERS:
		_tk.units.panels[player].choice_input.cursor_moved.connect(
				func(type_index: int) -> void: _note(&"cursor", player, type_index))


## The position in the trail: pass it to since() to read what came after.
func mark() -> int:
	return trail.size()


## The trail entries of one kind from `from` on, for one Player (-1 for any).
func since(from: int, kind: StringName, player: int = -1) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index: int in range(from, trail.size()):
		if trail[index]["kind"] == kind and (player < 0 or trail[index]["player"] == player):
			found.append(trail[index])
	return found


## The physics frame of the first trail entry of a kind from `from` on, for one Player (-1 for
## any), or -1 when there is none.
func first_frame(from: int, kind: StringName, player: int = -1) -> int:
	var found: Array[Dictionary] = since(from, kind, player)
	return found[0]["frame"] if not found.is_empty() else -1


## Runs `action` (a Callable with no arguments) once, inside the next unit_destroyed of the Player,
## in the destruction's own step and after every panel has reacted to it.
func arm(player: int, action: Callable) -> void:
	_armed[player] = action


## Direct choose() calls for a Player on each type: the answers.
func try_choose(player: int, types: Array[int]) -> Array[bool]:
	var answers: Array[bool] = []
	for type_index: int in types:
		answers.append(_controller.choose(player, type_index))
	return answers


## The cursor the Player's choice input rests on after each of `presses` presses of one steer
## action (&"previous" or &"next"), two ticks apart. A coroutine: await it.
func sweep(player: int, action: StringName, presses: int) -> PackedInt32Array:
	var stops: PackedInt32Array = []
	for _press: int in presses:
		await _kit.press_settled(Tokens.keys(action, player))
		stops.append(_tk.units.panels[player].choice_input.cursor)
	return stops


## Where a cursor on `from` stops after each press when it steps round the types that have Tokens
## (the model of the steer keys: the ring of the open types, one step a press, direction -1 or 1).
static func ring_stops(row: Array, from: int, direction: int, presses: int) -> PackedInt32Array:
	var open: Array[int] = []
	for type_index: int in row.size():
		if row[type_index] > 0:
			open.append(type_index)
	var stops: PackedInt32Array = []
	var at: int = open.find(from)
	for _press: int in presses:
		at = posmod(at + direction, open.size()) if at >= 0 else at
		stops.append(open[at] if at >= 0 else from)
	return stops


## How the slots of a panel must be drawn for a row of Tokens: "dim" for a type with none, else
## "cursor" for the slot under the cursor while the Player is choosing, else "plain".
static func model_looks(row: Array, cursor: int, choosing: bool) -> PackedStringArray:
	var looks: PackedStringArray = []
	for type_index: int in row.size():
		looks.append("dim" if row[type_index] <= 0 else "cursor" if choosing and type_index == cursor else "plain")
	return looks


## How the text of the slots of a panel must be coloured for a row of Tokens: "dim" or "normal".
static func model_fonts(row: Array) -> PackedStringArray:
	var fonts: PackedStringArray = []
	for count: int in row:
		fonts.append("dim" if count <= 0 else "normal")
	return fonts


## One line on a Player's panel in a state() reading: cursor, count lines, styles, text colours.
func describe(seen: Dictionary, player: int) -> String:
	return "p%d cursor %d %s %s %s" % [player + 1, seen["cursor"][player], seen["panels"][player],
			seen["looks"][player], seen["fonts"][player]]


## Files the destruction, then runs the action armed for this Player, once.
func _on_destroyed(player: int) -> void:
	_note(&"destroyed", player, -1)
	if _armed.has(player):
		var action: Callable = _armed[player]
		_armed.erase(player)
		action.call()


## Files the choice with the Tokens the chooser had of that type.
func _on_chosen(player: int, type_index: int) -> void:
	_note(&"chosen", player, type_index)
	trail[-1]["left"] = _controller.tokens_left(player, type_index)


## Files one signal with the frame it arrived in and which choice panels are shown.
func _note(kind: StringName, player: int, type_index: int) -> void:
	trail.append({"kind": kind, "player": player, "type": type_index, "frame": Engine.get_physics_frames(),
			"shown": [_tk.units.panels[0].visible, _tk.units.panels[1].visible]})
