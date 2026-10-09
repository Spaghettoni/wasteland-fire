class_name MineCount
extends Label
## One Player's Mines line, "Mines 3 / 5", in that Player's own view while that Player's Unit is a
## Truck in play, and nothing otherwise.
##
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-2 (while a Player's Unit
## is a Truck in play that Player's view, and only that one, shows the Mines left, updated on the
## tick of every lay and of every new Truck; the line is hidden for every other type and while the
## Player chooses or waits to respawn, fits the 640 x 720 view with nothing clipped and covers no
## element of the HUD band, the choice panel, the respawn countdown, the out-of-Fuel hint or the
## notice line) and AC-9 (its text is data in the scene, read through tr()); design/rules.md
## "Turrets, Flag Walls and Mines" (the HUD shows the Truck's Mines left). Vocabulary: CONTEXT.md
## (Player, Mine, Truck, Unit).
##
## Display only (.claude/rules/ui-code.md). The count belongs to the MineLayer. This label connects
## to its mines_changed, reads its count and capacity once in _ready(), and that is all it asks of
## it: it owns no state another node reads, calls nothing that changes the Round and reads no input.
## Take it out of the scene and the Round plays on unchanged. The MineLayer reports (0, 0) while
## its Unit is out of play and for every type that carries no Mine, so one rule covers every case:
## the line is shown while the capacity is above zero.
##
## One instance per Player, directly under that Player's SubViewport (split_screen.tscn:
## Player1MineCount, Player2MineCount), so it is drawn in that Player's view and in no other, and
## not under the PlayerHud, whose Team edge takes in every Control child, shown or hidden.
##
## States, two, the table complete:
##   hidden -> shown   the MineLayer reports a capacity above zero (a Truck came into play)
##   shown  -> hidden  it reports a capacity of zero (the Truck was destroyed or put away)
## While it is shown its text follows every change of the count.
##
## Look, stored in mine_count.tscn: the Tokens line's: 20 px white text with a dark outline, right
## aligned, under the Team edge (y 8 to 84) at x 332 to 624 and y 92 to 120, above the notice line
## (y 128 to 178) and far from the Unit choice panel, the countdown and the hint at the bottom.
## mouse_filter is ignore, so it never takes a click from what is under it.

## The MineLayer whose count this line shows. Required: without it the label pushes an error and
## stays hidden.
@export var mine_layer: MineLayer

## The line, with one %d placeholder for each number, the Mines left and then the capacity;
## "Mines %d / %d" in mine_count.tscn. Looked up with tr(), so it is also the translation key.
## Required, with no default: the text is data in the scene and never a literal in this script. It
## names no key.
@export var format: String = ""


func _ready() -> void:
	visible = false
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("MineCount '%s': %s, so it stays hidden." % [name, problem])
		return
	mine_layer.mines_changed.connect(_on_mines_changed)
	_on_mines_changed(mine_layer.mines_left, mine_layer.capacity)


## The numbers the line shows, in the order of its placeholders: the Mines left, then the capacity.
func _numbers(mines_left: int, capacity: int) -> Array[int]:
	return [mines_left, capacity]


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if mine_layer == null:
		return "mine_layer is not assigned"
	if format.is_empty():
		return "format is not set (store the line, with two %d placeholders, in the scene)"
	if format.count("%d") != _numbers(0, 0).size():
		return "format '%s' does not hold one %%d placeholder for each number it shows" % format
	return ""


## The MineLayer's count or capacity changed (and once from _ready()): shows the line with the
## numbers while the capacity is above zero, hides it otherwise.
func _on_mines_changed(mines_left: int, capacity: int) -> void:
	visible = capacity > 0
	if visible:
		text = tr(format) % _numbers(mines_left, capacity)
