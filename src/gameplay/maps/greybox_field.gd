class_name GreyboxField
extends Node3D
## The flat greybox playfield of Story 001: an 80 x 80 m floor with a wall on each side, a sun, an
## environment and, since Story 003, the two Bases. The stand-in for the Map of Story 007.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md AC-1 (a flat greybox
## plane) and AC-6 (a five-minute drive cannot leave the playfield or fall through it: walls 3 m
## high and 2 m thick, a 1 m thick floor). Vocabulary: CONTEXT.md (Map, Base).
##
## Story 002 (production/epics/wasteland-fire/story-002-split-screen.md AC-2: one Motorbike per
## Player, at distinct start positions) gave the field one start marker per Player, on opposite
## sides of the field and turned to face each other, as stand-ins for the Bases. Story 003
## (production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1: two greybox
## Bases, one per Player, visually distinct, each with a spawn point) makes them real. Base1 is
## Player 1's, blue, at (0, 0, 20) facing -Z, where the first marker stood; Base2 is Player 2's,
## red, at (0, 0, -20) turned to face it, where the second stood. player_1_base and player_2_base
## hand them to whoever needs them (SplitScreen gives them to the MatchController). The field is
## still only the stand-in for the Map: Story 007 brings the real one.
##
## The start markers stay, as the Bases' spawn points. PlayerStart and Player2Start are still
## loose children of the field, and greybox_field.tscn points each Base's spawn_point at its
## marker. player_start and player_2_start are read-only views of those spawn points, so
## DrivingToy, SplitScreen and the Story 001 and 002 evidence harnesses, which all ask the field for
## them, need no change. The markers are not inside the Bases because the Story 001 drive harness
## moves the start by writing the marker's transform, which it means as a position in the field:
## inside a Base that transform would be relative to the Base, so off by the Base's own position,
## and the Unit would start outside the field. So each Base's own SpawnPoint child is unused here
## and each Base's place is stated twice, once for the Base and once for its marker. The
## MatchController refuses to begin a Round while a Base's spawn point is off its pad
## (Base.first_spawn_problem()), so a Base moved without its marker is an error at launch and never
## a silent drift. Debt, to pay when the Story 001 harness may change (Story 007, the Map): delete
## PlayerStart and Player2Start and point each Base at its own SpawnPoint child.
##
## Data, no behaviour: the script exists so the scenes that use the field ask it for its Bases
## and start markers instead of reaching into its node tree by path, which a rename inside this
## scene would break without a word.

## The Base of Player 1, where that Player's Units start the Round and respawn: blue, on the near
## side of the field. Its spawn_point is player_start.
@export var player_1_base: Base

## The Base of Player 2: red, 40 m from player_1_base on the far side of the field and turned to
## face it. Its spawn_point is player_2_start.
@export var player_2_base: Base

## Where Player 1's Unit starts: its position, and its heading from the marker's facing. It is
## player_1_base's spawn_point, and null while player_1_base is not assigned. Read-only:
## assigning to it pushes an error and changes nothing.
var player_start: Marker3D:
	get:
		return player_1_base.spawn_point if player_1_base != null else null
	set(_value):
		push_error("GreyboxField '%s': player_start is read-only. It is player_1_base's spawn_point." % name)

## Where Player 2's Unit starts: its position, and its heading from the marker's facing. It is
## player_2_base's spawn_point, 40 m from player_start on the far side of the field and turned to
## face it, and null while player_2_base is not assigned. Read-only: assigning to it pushes an
## error and changes nothing.
var player_2_start: Marker3D:
	get:
		return player_2_base.spawn_point if player_2_base != null else null
	set(_value):
		push_error("GreyboxField '%s': player_2_start is read-only. It is player_2_base's spawn_point." % name)
