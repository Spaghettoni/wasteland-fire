extends RefCounted
## Scenario teams_last_carrier of the split screen evidence harness (split_screen_harness.gd): Story 052 on Map 01, two Teams of
## two. A Token is taken when a Unit is destroyed, so a Teammate's Motorbike in play holds one of the Team's Motorbike Tokens.
## CHECK lines:
##  R1 the first of two falls: Orange is brought down to 2 Motorbike Tokens with both its Players on Motorbikes; one of them
##     is destroyed: 1 Token left, the Round runs on (before Story 052 the same happened with 1 Token and two Motorbikes,
##     and the Team lost while one still drove).
##  R2 the Teammate's Token is held: the fallen Player may not take a Motorbike (tokens_free 0, can_choose false) while its
##     Teammate's Motorbike is in play, and may take a Buggy; the Teal Players, with all 5, may.
##  R3 the last one falls: the second Motorbike is destroyed, Orange has none left, the Round is over and Teal wins.
## Implements: production/epics/wasteland-fire/story-052-last-carrier-of-a-team.md AC-1 to AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=teams_last_carrier

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const OWN_CHOICE: bool = true
const TEAMS: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const MAP_CHOICE: bool = true
const MINES: bool = true
const TURRETS: bool = true
const BASE_DEFENCES: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const USE_MAP_STOCK: bool = true
const TURRET_LOOKS: bool = true
const LINEUP_DEVICES: Array[int] = [-2, 0, -3, 1]
const LINEUP_TEAMS: Array[int] = [0, 0, 1, 1]
const WATCHDOG_SECONDS: float = 900.0

const MOTORBIKE: int = 0
const BUGGY: int = 1
const ORANGE_A: int = 0
const ORANGE_B: int = 1
const TEAL_A: int = 2
const SETTLE: int = 10
## Motorbike Tokens Orange is brought down to before the check, with both its Players on Motorbikes.
const LEFT_BEFORE: int = 2

var _h: Harness
var _kit: Kit
var _controller: MatchController
var _units: Array[Unit] = []


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_controller = _h.split.match_controller
	_units = _h.split.all_units()
	for player: int in _units.size():
		_controller.choose(player, MOTORBIKE)
	await _kit.advance(SETTLE)
	while _controller.tokens_left(ORANGE_A, MOTORBIKE) > LEFT_BEFORE:
		await _lose(ORANGE_A)
		_controller.choose(ORANGE_A, MOTORBIKE)
		await _kit.advance(_respawn_ticks())
	var problems: PackedStringArray = PackedStringArray()
	var before: int = _controller.tokens_left(ORANGE_A, MOTORBIKE)
	var both: bool = _controller.is_alive(ORANGE_A) and _controller.is_alive(ORANGE_B)
	await _lose(ORANGE_A)
	var after: int = _controller.tokens_left(ORANGE_A, MOTORBIKE)
	var running: bool = not _controller.is_round_over()
	_kit.need(problems, before == LEFT_BEFORE and both, "before: %d Tokens, both on Motorbikes %s" % [before, both])
	_kit.need(problems, after == LEFT_BEFORE - 1 and running and _controller.is_alive(ORANGE_B), "after: %d Tokens, running %s, Teammate alive %s" % [after, running, _controller.is_alive(ORANGE_B)])
	_kit.verdict("R1_first_of_two_falls", problems, "Orange at %d Motorbike Tokens, both on Motorbikes %s; one destroyed: %d left, the Round runs %s, the Teammate drives %s" % [before, both, after, running, _controller.is_alive(ORANGE_B)])
	problems = PackedStringArray()
	var free_moto: int = _controller.tokens_free(ORANGE_A, MOTORBIKE)
	var may_moto: bool = _controller.can_choose(ORANGE_A, MOTORBIKE)
	var may_buggy: bool = _controller.can_choose(ORANGE_A, BUGGY)
	var refused: bool = not _controller.choose(ORANGE_A, MOTORBIKE)
	var teal_free: int = _controller.tokens_free(TEAL_A, MOTORBIKE)
	_kit.need(problems, free_moto == 0 and not may_moto and refused, "the fallen Player: tokens_free %d, can_choose %s, choose refused %s" % [free_moto, may_moto, refused])
	_kit.need(problems, may_buggy, "the fallen Player may not take a Buggy")
	_kit.need(problems, teal_free == _controller.tokens_left(TEAL_A, MOTORBIKE) - 1, "Teal: tokens_free %d of %d" % [teal_free, _controller.tokens_left(TEAL_A, MOTORBIKE)])
	_kit.verdict("R2_teammates_token_held", problems, "the fallen Orange Player: Motorbike tokens_free %d, can_choose %s, choose refused %s, Buggy %s; a Teal Player: Motorbike tokens_free %d of %d (its Teammate's held)" % [free_moto, may_moto, refused, may_buggy, teal_free, _controller.tokens_left(TEAL_A, MOTORBIKE)])
	problems = PackedStringArray()
	await _lose(ORANGE_B)
	var over: bool = _controller.is_round_over()
	var winner: int = _controller.winner_index()
	_kit.need(problems, over and winner == Lineup.TEAL and _controller.tokens_left(ORANGE_B, MOTORBIKE) == 0, "over %s, winner %d, Orange Tokens %d" % [over, winner, _controller.tokens_left(ORANGE_B, MOTORBIKE)])
	_kit.verdict("R3_last_one_falls", problems, "the second Orange Motorbike destroyed: Orange Tokens %d, over %s, winner %d (Teal %d)" % [_controller.tokens_left(ORANGE_B, MOTORBIKE), over, winner, Lineup.TEAL])
	_h.finish("players=%d" % _units.size())


func _lose(player: int) -> void:
	_units[player].destroy()
	await _kit.advance(SETTLE)


func _respawn_ticks() -> int:
	return int(_controller.rules.respawn_delay_seconds * Engine.physics_ticks_per_second) + 20
