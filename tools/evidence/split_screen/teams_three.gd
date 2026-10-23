extends RefCounted
## Scenario teams_three of the split screen evidence harness (split_screen_harness.gd): three Players, two Orange against
## one Teal (Story 048), on Map 01: pad 0 and Keyboard 1 Orange, Keyboard 2 Teal. CHECK lines:
##  E1 the views: Orange's two views in the left column, Teal's one in the right with a dark panel under it.
##  E2 the Turrets: Orange's armed with the one Teal Unit, Teal's with both Orange Units.
##  E3 the loss of a Team: Teal's last Motorbike Token gone, the Round is over and Orange (Team 0) wins.
## Implements: production/epics/wasteland-fire/story-048-four-players.md AC-4, AC-6, AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=teams_three

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const OWN_CHOICE: bool = true
const TEAMS: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const MAP_CHOICE: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const BASE_DEFENCES: bool = true
const USE_MAP_STOCK: bool = true
const RESOURCE_BARS: bool = true
const AMMO: bool = true
const MINES: bool = true
const LINEUP_DEVICES: Array[int] = [0, -2, -3]
const LINEUP_TEAMS: Array[int] = [0, 0, 1]
const MOTORBIKE: int = 0

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var split: SplitScreen = _h.split
	var controller: MatchController = split.match_controller
	var problems: PackedStringArray = PackedStringArray()
	var orange: Node = split.get_node_or_null("Views/OrangeColumn")
	var teal: Node = split.get_node_or_null("Views/TealColumn")
	var left: Array = orange.get_children().map(func(n: Node) -> String: return String(n.name)) if orange != null else []
	var right: Array = teal.get_children().map(func(n: Node) -> String: return String(n.name)) if teal != null else []
	_kit.need(problems, left == ["Player1View", "Player2View"] and right == ["Player3View", "EmptyView"], "columns %s | %s" % [left, right])
	_kit.verdict("E1_views", problems, "left %s, right %s" % [left, right])
	problems = PackedStringArray()
	var armed: Array[int] = []
	for base: Base in [split.field.player_1_base, split.field.player_2_base]:
		for structure: Structure in base.structures:
			if structure is Turret:
				var targets: Array = structure.get("_targets")
				armed.append(targets.size())
				break
	_kit.need(problems, armed == [1, 2], "Turrets armed with %s" % [armed])
	_kit.verdict("E2_turrets", problems, "a Turret of Orange's Base armed with %d Unit(s), one of Teal's with %d" % [armed[0] if armed.size() > 0 else -1, armed[1] if armed.size() > 1 else -1])
	problems = PackedStringArray()
	var units: Array[Unit] = split.all_units()
	var tokens: int = controller.tokens_left(2, MOTORBIKE)
	for _life: int in tokens:
		controller.choose(2, MOTORBIKE)
		await _kit.advance(controller.rules.respawn_delay_seconds * 60 + 10)
		if controller.is_round_over():
			break
		units[2].destroy()
		await _kit.advance(3)
	var over: bool = controller.is_round_over()
	var winner: int = controller.winner_index()
	_kit.need(problems, tokens == 5 and over and winner == Lineup.ORANGE, "Teal had %d Motorbike Tokens; over %s, winner %d" % [tokens, over, winner])
	_kit.verdict("E3_team_loss", problems, "Teal's %d Motorbikes destroyed one by one: the Round over %s, winner Team %d (Orange)" % [tokens, over, winner])
	_h.finish("players=%d" % units.size())
