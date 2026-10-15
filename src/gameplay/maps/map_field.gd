class_name MapField
extends Node3D
## A Map as the scenes that play on it see it: the root script of every Map scene. It hands out
## the Map's two Bases and its Token stock, so whoever needs them asks the Map and never reaches
## into its node tree by path.
##
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-9 (Map 01 is a scene: its
## Bases, its Garages and its Token stock are data in it, not constants in code, and replacing the
## Map scene needs no script change) and the story's Map contract (its Implementation Notes),
## which completes the one Story 004 set out in its Completion Notes
## (production/epics/wasteland-fire/story-004-water-canister-and-win.md: a Map exposes its two
## Bases, and SplitScreen.field, typed GreyboxField until Story 007, is retyped to a class every
## Map shares). Vocabulary: CONTEXT.md (Map, Base, Garage, Token, Player, Flag).
##
## The contract. A Map exposes its two Bases as player_1_base and player_2_base and its Token stock
## as token_stock, and each Base brings the rest itself (Base: the Flag and its seat, the zone, the
## pad and the beacon, and the SpawnPoint markers of its Garage). SplitScreen types its field as a
## MapField and reads only the two Bases and the Token stock, which it hands to the MatchController,
## so any Map scene whose root carries this script, or a script that extends it, plays with no
## change in code. GreyboxField, the flat field of Stories 001 to 006, extends it: the driving toy
## and the evidence scenarios written before Story 007 keep that field, and Map 01 is a scene of its
## own.
##
## The look (Story 007) asks two more things of a Map. Its player_1_base wears
## src/gameplay/split_screen/data/team_orange_material.tres as color_material and its
## player_2_base team_teal_material.tres, the Teams split_screen.tscn gives Player 1 and Player 2.
## And its cliffs on the cliffs_water layer are drawn colliders (CSG shapes with use_collision),
## while its water on that layer is a bare StaticBody3D under a drawn surface: UnitModel lifts
## the Gyrocopter's model only over a collider that is drawn geometry, so a cliff built as a
## StaticBody3D with a mesh child (as terrain_stand_ins.tscn's is) would hide the Gyrocopter
## inside it, and water built as a CSG shape would lift it over the water.
##
## The pieces of no Base (Story 019 AC-5). A Map may hold damageable pieces that belong to no Base
## and so to no Player: Map 01's four Wall Panels in each of its two scrap walls, which the Bases'
## own walls cannot list. It lists them in neutral_structures, and SplitScreen restores them at
## every restart beside the Bases' pieces, from that list and with no search of the tree.
##
## The supply zones (Story 024). A Map lists its SupplyZones in supply_zones, so whoever needs
## them asks the Map and never searches the tree: Map 01 lists the two Fuel zones under its depot
## and the two ammunition zones of its ammunition buildings. SplitScreen reads the list once,
## before the Round begins, and hands every ammunition zone the Players' Weapons and both
## MineLayers every zone, which they keep clear of Mines
## (production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2, AC-4).
##
## Data, almost no behaviour: the Map's scene sets the exports and nothing here checks them but
## the warnings for an unassigned entry of neutral_structures and of supply_zones. SplitScreen
## refuses to begin a Round while either Base is missing, and the MatchController refuses it
## while a Base's SpawnPoint markers lie off its pad (Base.first_spawn_problem()) and while the
## Token stock is missing or cannot be used (TokenLedger.first_problem(); Story 008).

## The Base of Player 1 (Base A in design/rules.md): where that Player's Units appear, in its
## Garage, at the start of the Round and after every destruction, and where that Player's Flag
## stands at home. SplitScreen hands it to the MatchController as the first Player's Base and
## refuses to begin the Round while it is not assigned.
@export var player_1_base: Base

## The Base of Player 2 (Base B in design/rules.md): the same for the second Player. SplitScreen
## hands it to the MatchController as the second Player's Base and refuses to begin the Round
## while it is not assigned.
@export var player_2_base: Base

## The Token stock this Map sets: how many Tokens of each Unit type each Player starts the Round
## with (design/rules.md "Tokens and the Garage": the counts are set by the Map, and each Map may
## differ). SplitScreen hands it to the MatchController (Story 008), whose begin() copies it for
## each Player and refuses to begin the Round on a Map without a usable one: none, a negative
## count, a key no Unit type has, or no Token for the type that can carry the Flag.
## data/token_stock.tres holds the source's example.
@export var token_stock: TokenStock

## The damageable pieces of this Map that belong to no Base (Story 019): Map 01 lists the 8 Wall
## Panels of its two scrap walls, 4 each. SplitScreen leaves each one's player_index at -1, so a
## Shot of either Player damages it by the matrix, and restores each one when a Round starts again,
## as it restores a Base's own pieces (Base.structures). It does not arm them: a Turret is a Base's.
## A piece listed here is a Structure like the Base's, so a fallen one stays down until the restart.
## Optional and empty by default: a Map with no such piece, the greybox field among them, lists
## none. An entry that is not assigned is skipped with a warning.
@export var neutral_structures: Array[Structure] = []

## The supply zones of this Map (Story 024): Map 01 lists its two Fuel zones, then its two
## ammunition zones, west before east. SplitScreen hands every one of kind AMMO both Weapons and
## hands both MineLayers the whole list. A zone is polled by its own tick, so it gives its supplies
## whether or not it is listed here; the list is only who is handed what. Optional and empty by
## default: a Map with no supply building, the greybox field among them, lists none. An entry that
## is not assigned is skipped with a warning.
@export var supply_zones: Array[SupplyZone] = []


func _ready() -> void:
	for index: int in neutral_structures.size():
		if neutral_structures[index] == null:
			push_warning("MapField '%s': neutral_structures entry %d is not assigned, so that piece is skipped." % [name, index])
	for index: int in supply_zones.size():
		if supply_zones[index] == null:
			push_warning("MapField '%s': supply_zones entry %d is not assigned, so that zone is skipped." % [name, index])
