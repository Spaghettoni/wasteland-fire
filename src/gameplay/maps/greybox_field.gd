class_name GreyboxField
extends Node3D
## The flat greybox playfield of Story 001: an 80 x 80 m floor with a wall on each side, a sun, an
## environment and the Player 1 start marker. The stand-in for the Map of Story 007.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md AC-1 (a flat greybox
## plane) and AC-6 (a five-minute drive cannot leave the playfield or fall through it: walls 3 m
## high and 2 m thick, a 1 m thick floor). Vocabulary: CONTEXT.md (Map).
##
## Story 002 (production/epics/wasteland-fire/story-002-split-screen.md AC-2: one Motorbike per
## Player, at distinct start positions) adds a second marker, so the field now has one start
## marker per Player: player_start is Player 1's and player_2_start is Player 2's, on opposite
## sides of the field and turned to face each other. Both stand in for the Bases of Story 003,
## where a Player's Units start and respawn. Vocabulary: CONTEXT.md (Player, Base).
##
## Data, no behaviour: the script exists so the scenes that use the field ask it for its markers
## instead of reaching into its node tree by path, which a rename inside this scene would break
## without a word.

## Where Player 1's Unit starts: its position, and its heading from the marker's facing.
@export var player_start: Marker3D

## Where Player 2's Unit starts: its position, and its heading from the marker's facing. 40 m from
## player_start on the far side of the field, turned to face it.
@export var player_2_start: Marker3D
