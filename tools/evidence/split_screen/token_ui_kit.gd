extends RefCounted
## What the Story 008 UI scenarios (token_ui, token_layout) share beyond token_kit.gd: the nodes of
## a Player's view the TokenKit does not hand out (the HUD's Tokens label, the Round-over screen,
## the key bound to the restart), the test of a label against its own width, the readings of the
## Round after a restart (the Flags home, the choice panel as at a start, the lines a Round-over
## screen must show, both fire keys pressed together) and the screens' own scenes built on a
## throwaway MatchController. Make one with UiKit.new(tk) from the scenario's TokenKit. Tooling
## only: nothing under src/ depends on this file.

## The shared Story 008 helpers (token_kit.gd): the record of the Units, cameras and screens.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The HUD scene the launch scene instances.
const HUD_SCENE: PackedScene = preload("res://src/ui/hud/player_hud.tscn")
## The choice panel scene the launch scene instances.
const CHOICE_SCENE: PackedScene = preload("res://src/ui/hud/unit_choice.tscn")
## A seated Flag stands within this of its seat, metres.
const PLACE_TOLERANCE: float = 0.05

## The TokenKit this kit reads the Units, cameras, HUDs, panels and countdowns through.
var tk: Tokens


## Keeps the TokenKit the readings go through.
func _init(token_kit: Tokens) -> void:
	tk = token_kit


## The Tokens label of a Player's HUD.
func tokens_label(player: int) -> Label:
	return tk.units.huds[player].find_child("TokensLabel", true, false) as Label


## The Round-over screen of a Player's view (a child of that Player's SubViewport), or null.
func over_screen(player: int) -> RoundOverScreen:
	for node: Node in (tk.units.cameras[player].get_viewport() as SubViewport).get_children():
		if node is RoundOverScreen:
			return node as RoundOverScreen
	return null


## The physical key the Input Map binds to round_restart (its first event, when that is a key),
## or KEY_NONE.
func bound_restart_key() -> Key:
	var events: Array[InputEvent] = InputMap.action_get_events(&"round_restart")
	return (events[0] as InputEventKey).physical_keycode if not events.is_empty() and events[0] is InputEventKey else KEY_NONE


## The rectangle of a Player's view: its SubViewport.
func view_of(player: int) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2((tk.units.cameras[player].get_viewport() as SubViewport).size))


## A rectangle as "(x,y wxh)", whole pixels.
static func rs(rect: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


## The width in pixels the label's font and size draw the text at, its outline not counted.
static func text_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font(&"font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x


## Writes the text into the label, adds a problem unless it stays on one line and its width plus
## its outline fits the label, and puts the label's own text back: the width it measured.
func fits(label: Label, text: String, where: String, out: PackedStringArray) -> float:
	var kept: String = label.text
	label.text = text
	var width: float = text_width(label, text) + float(label.get_theme_constant(&"outline_size"))
	if label.get_line_count() != 1 or width > label.size.x:
		out.append("%s '%s' is %.0f px wide on %d lines in a label %.0f px wide" % [where, text, width, label.get_line_count(), label.size.x])
	label.text = kept
	return width


## What is not as at a start in the Flags: "" when each Player's Flag is AT_HOME on its Base's seat
## and the controller says OWN_AT_HOME, else a sentence naming the first that is not.
func flags_home() -> String:
	for player: int in 2:
		var flag: Flag = tk.units.bases[player].flag
		var apart: float = flag.global_position.distance_to(tk.units.bases[player].flag_seat.global_position)
		if flag.state != Flag.State.AT_HOME or apart > PLACE_TOLERANCE or tk.controller.flag_status(player) != MatchController.FlagStatus.OWN_AT_HOME:
			return "player %d's Flag is %s, %.3f m from its seat, status %d" % [player + 1, Flag.State.keys()[flag.state], apart, tk.controller.flag_status(player)]
	return ""


## What is not as at a start in a Player's choice panel: "" when it is shown, the slot under the
## cursor is the one marked, no slot is dim or drawn in another style, every slot's text is the
## normal colour and the counts are `row`'s; else a sentence with what it shows.
func panel_clean(player: int, row: Array) -> String:
	var looks: PackedStringArray = tk.looks(player)
	var fonts: PackedStringArray = tk.fonts(player)
	var marked: int = looks.find("cursor")
	if (tk.units.panels[player].visible and marked == tk.units.panels[player].choice_input.cursor and looks.count("cursor") == 1
			and looks.count("dim") + looks.count("other") == 0 and fonts.count("normal") == fonts.size() and tk.panel_counts(player) == tk.count_texts(player, row)):
		return ""
	return "player %d's panel visible=%s cursor %d looks %s fonts %s counts %s" % [player + 1, tk.units.panels[player].visible, tk.units.panels[player].choice_input.cursor, looks, fonts, tk.panel_counts(player)]


## The two lines a Player's Round-over screen must show for the winner (0 or 1, or NO_WINNER): the
## winner line or nobody_text, and the restart line naming the key the Input Map binds to
## round_restart, both from the screen's own texts.
func expected_lines(player: int, winner: int) -> PackedStringArray:
	var screen: RoundOverScreen = over_screen(player)
	var first: String = screen.tr(screen.nobody_text) if winner == MatchController.NO_WINNER else screen.tr(screen.winner_format) % (winner + 1)
	return PackedStringArray([first, screen.tr(screen.restart_format) % OS.get_keycode_string(bound_restart_key())])


## Moves a Player's cursor to the type with the steer-right key (it skips a type with no Token, so
## it may never get there: at most one pass over the types). A coroutine: await it.
func steer_to(player: int, type_index: int) -> void:
	for _step: int in tk.controller.unit_types().size():
		if tk.units.panels[player].choice_input.cursor != type_index:
			await tk.kit.press_settled(Tokens.keys(&"next", player))


## Both Players press their fire key together: the ticks from the press to each Unit in play
## (-1 for one that did not appear within 60 ticks). A coroutine: await it.
func fire_both() -> Array[int]:
	var keys: Array[Key] = [Tokens.keys(&"fire", 0)[0], Tokens.keys(&"fire", 1)[0]]
	var at: int = tk.harness.ticks
	await tk.kit.press(keys)
	var alive: Array[int] = [-1, -1]
	for _wait: int in 60:
		for player: int in 2:
			if alive[player] < 0 and tk.controller.is_alive(player):
				alive[player] = tk.harness.ticks - at
		if not alive.has(-1):
			break
		await tk.kit.tick()
	return alive


## A HUD, a choice input and a choice panel for Player 1 (the screens' own scenes, the live Unit)
## on the given MatchController, in a SubViewport the size of a live view, under a host node in
## the runner: the host, to free() when done. Build them after any begin() the caller makes on
## the controller, and wait a few ticks for the screens to read it.
func idle_screens(controller: MatchController) -> Node:
	var host: Node = Node.new()
	tk.harness.add_child(host)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(view_of(0).size)
	host.add_child(view)
	var hud: PlayerHud = HUD_SCENE.instantiate() as PlayerHud
	hud.match_controller = controller
	hud.unit = tk.units.units[0]
	hud.player_index = 0
	view.add_child(hud)
	var input: PlayerChoiceInput = PlayerChoiceInput.new()
	input.match_controller = controller
	input.player_index = 0
	input.action_prefix = tk.units.panels[0].action_prefix
	host.add_child(input)
	var choice: UnitChoice = CHOICE_SCENE.instantiate() as UnitChoice
	choice.match_controller = controller
	choice.choice_input = input
	choice.player_index = 0
	choice.action_prefix = input.action_prefix
	view.add_child(choice)
	return host
