class_name AmmoCount
extends Label
## One Player's Ammo line, "Ammo 100 / 100", in that Player's own view while that Player's Unit is
## in play with a load of ammunition, and nothing otherwise.
##
## Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-4 (while a
## Player's Unit is in play, that Player's view, and only that one, shows its Shots left, updated on
## the tick of every Shot and every refill; the line is hidden while the Player chooses or waits to
## respawn and not hidden under the Round-over screen, where it keeps the count the Round ended
## with; it sits under the HUD band on the left, on the row of the Mines line, fits the 640 x 720
## view and covers no element of the HUD band, the Mines line, the notice line, the choice panel,
## the respawn countdown or the out-of-Fuel hint) and AC-7 (its text is data in the scene, read
## through tr()); design/rules.md "Resources" (the Ammo bullet). Vocabulary: CONTEXT.md (Player,
## Unit, Ammo).
##
## Display only (.claude/rules/ui-code.md). The count belongs to the Weapon. This label connects to
## its ammo_changed, reads its count and capacity once in _ready(), and that is all it asks of it:
## it owns no state another node reads, calls nothing that changes the Round and reads no input.
## Take it out of the scene and the Round plays on unchanged. The Weapon reports (0, 0) while its
## Unit is out of play and for every type with no count, so one rule covers every case, the Mines
## line's: the line is shown while the capacity is above zero. Like the Mines line it hears no
## MatchController, so under the Round-over screen it keeps the count the Round ended with (the tree
## is paused, so the Weapon says nothing more).
##
## One instance per Player, directly under that Player's SubViewport after the Mines line
## (split_screen.tscn: Player1AmmoCount, Player2AmmoCount), so it is drawn in that Player's view and
## in no other, and not under the PlayerHud, whose Team edge takes in every Control child, shown or
## hidden.
##
## States, two, the table complete:
##   hidden -> shown   the Weapon reports a capacity above zero (a Unit with a load came into play)
##   shown  -> hidden  it reports a capacity of zero (the Unit was destroyed or put away)
## While it is shown its text follows every change of the count.
##
## Look, stored in ammo_count.tscn: the Mines line's: 20 px white text with a dark outline, left
## aligned, under the Team edge (y 8 to 84) at x 16 to 316 and y 92 to 120, so a Truck's row reads
## "Ammo 25 / 25" on the left and "Mines 5 / 5" on the right (x 332 to 624), above the notice line
## (y 128 to 178) and far from the Unit choice panel, the countdown and the hint at the bottom.
## mouse_filter is ignore, so it never takes a click from what is under it.

## The Weapon whose count this line shows. Required: without it the label pushes an error and stays
## hidden.
@export var weapon: Weapon

## The line, with one %d placeholder for each number, the Shots left and then the capacity;
## "Ammo %d / %d" in ammo_count.tscn. Looked up with tr(), so it is also the translation key.
## Required, with no default: the text is data in the scene and never a literal in this script. It
## names no key.
@export var format: String = ""


func _ready() -> void:
	visible = false
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("AmmoCount '%s': %s, so it stays hidden." % [name, problem])
		return
	weapon.ammo_changed.connect(_on_ammo_changed)
	_on_ammo_changed(weapon.shots_left, weapon.capacity)


## The numbers the line shows, in the order of its placeholders: the Shots left, then the capacity.
func _numbers(shots_left: int, capacity: int) -> Array[int]:
	return [shots_left, capacity]


## What is wrong with the exports, as a sentence, or an empty string when nothing is.
func _first_problem() -> String:
	if weapon == null:
		return "weapon is not assigned"
	if format.is_empty():
		return "format is not set (store the line, with two %d placeholders, in the scene)"
	if format.count("%d") != _numbers(0, 0).size():
		return "format '%s' does not hold one %%d placeholder for each number it shows" % format
	return ""


## The Weapon's count or capacity changed (and once from _ready()): shows the line with the numbers
## while the capacity is above zero, hides it otherwise.
func _on_ammo_changed(shots_left: int, capacity: int) -> void:
	visible = capacity > 0
	if visible:
		text = tr(format) % _numbers(shots_left, capacity)
