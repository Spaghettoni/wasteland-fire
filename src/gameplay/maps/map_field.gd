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
## The contract. A Map exposes its two Bases as player_1_base and player_2_base and its Token
## stock as token_stock, and each Base brings the rest itself (Base: the Flag and its seat, the
## zone, the pad and the beacon, and the SpawnPoint markers of its Garage). SplitScreen types its
## field as a MapField and reads only the two Bases, which it hands to the MatchController, so any
## Map scene whose root carries this script, or a script that extends it, plays with no change in
## code. GreyboxField, the flat field of Stories 001 to 006, extends it: the driving toy and the
## evidence scenarios written before Story 007 keep that field, and Map 01 is a scene of its own.
##
## The look (Story 007) asks two more things of a Map. Its player_1_base wears
## src/gameplay/split_screen/data/team_orange_material.tres as color_material and its
## player_2_base team_teal_material.tres, the Teams split_screen.tscn gives Player 1 and Player 2.
## And its cliffs on the cliffs_water layer are drawn colliders (CSG shapes with use_collision),
## while its water on that layer is a bare StaticBody3D under a drawn surface: KitUnitModel lifts
## the Gyrocopter's model only over a collider that is drawn geometry, so a cliff built as a
## StaticBody3D with a mesh child (as terrain_stand_ins.tscn's is) would hide the Gyrocopter
## inside it, and water built as a CSG shape would lift it over the water.
##
## Data, no behaviour: the Map's scene sets the three exports and nothing here checks them.
## SplitScreen refuses to begin a Round while either Base is missing, and the MatchController
## refuses it while a Base's SpawnPoint markers lie off its pad (Base.first_spawn_problem()).

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
## differ). Story 008 reads it; Story 007 only holds it, so nothing in the game reads it yet and a
## Map without one still plays. data/token_stock.tres holds the source's example.
@export var token_stock: TokenStock
