extends RefCounted
## Scenario explosions_off of the split screen evidence harness (split_screen_harness.gd): the proof of the runner's strip
## (Story 016 AC-9). It declares no EXPLOSIONS, as every scenario written before Story 016 declares none, so the runner has
## taken the explosion off the launch scene before it entered the tree. Two Units are destroyed with real keys (Player 2's
## Motorbike by a Shot of Player 1, then by its own Self-destruct) and the Round counts both, yet no Explosion is ever added,
## none stands in the node group, SplitScreen has no scene and no link on the Round's signals for it, and no engine error
## comes. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-9. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=explosions_off

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes every choice itself, with its own keys. It declares nothing else: above all not EXPLOSIONS.
const OWN_CHOICE: bool = true
## Tokens enough that the destructions never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 10, &"buggy": 10, &"truck": 10, &"gyrocopter": 10}
## Metres either side of the middle of the Map the Units stand, and the hit points the victim is left with.
const DUEL_X: float = 5.0
const ONE_SHOT: float = 1.0
## Ticks the Round plays on after each destruction.
const AFTER_TICKS: int = 150

var _q: Quick
var _added: int = 0


## Plays the two destructions and the checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	harness.get_tree().node_added.connect(func(node: Node) -> void: _added += 1 if node is Explosion else 0)
	for player: int in Kit.PLAYERS:
		await _q.tokens.spawn(player, Quick.MOTORBIKE)
	await _shot_down()
	await _self_destruct()
	_checks(harness)
	_q.close()
	harness.finish("destroyed=%d explosions=%d %s" % [_q.units.destroyed.size(), _added, _q.engine_counts()])


## Player 1's real Shot kills Player 2's Motorbike (one hit point) 10 m off.
func _shot_down() -> void:
	_stage()
	await _q.kit.advance(Quick.Units.SETTLE_TICKS + 15)
	_q.units.units[1].apply_damage(_q.units.units[1].hit_points - ONE_SHOT)
	await _q.tokens.shoot(0)
	await _q.kit.advance(AFTER_TICKS)
	await _q.tokens.spawn(1, Quick.MOTORBIKE)


## Player 2's own Self-destruct key, outside its Base.
func _self_destruct() -> void:
	_stage()
	await _q.kit.advance(Quick.Units.SETTLE_TICKS + 15)
	await _q.tokens.destruct(1)
	await _q.kit.advance(AFTER_TICKS)


func _stage() -> void:
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.MOTORBIKE, Vector3(DUEL_X, 0.0, 0.0), Vector3.LEFT)


## explosions_stripped: the Round counted both destructions and nothing exploded.
func _checks(harness: Node) -> void:
	var problems: PackedStringArray = []
	var split: SplitScreen = harness.split
	_q.kit.need(problems, _q.units.destroyed.size() == 2, "%d destructions were counted, not 2" % _q.units.destroyed.size())
	_q.kit.need(problems, split.explosion_scene == null, "the launch scene still has explosion_scene %s" % split.explosion_scene)
	_q.kit.need(problems, _added == 0 and harness.get_tree().get_nodes_in_group(&"explosions").is_empty(), "%d Explosions were added, %d stand in the group" % [_added, harness.get_tree().get_nodes_in_group(&"explosions").size()])
	var for_explosions: int = 0
	for link: Dictionary in _q.controller.get_signal_connection_list(&"unit_destroyed"):
		for_explosions += 1 if (link["callable"] as Callable).get_method() == &"_explode" else 0
	for link: Dictionary in _q.controller.get_signal_connection_list(&"round_started"):
		for_explosions += 1 if (link["callable"] as Callable).get_method() == &"_free_explosions" else 0
	_q.kit.need(problems, for_explosions == 0, "SplitScreen has %d links on the Round's signals for the explosions" % for_explosions)
	_q.kit.need(problems, _q.tokens.engine_log.errors.is_empty() and _q.tokens.engine_log.warnings.is_empty(), "the engine logged %s %s" % [_q.tokens.engine_log.errors, _q.tokens.engine_log.warnings])
	_q.kit.verdict("explosions_stripped", problems, "a Shot and a Self-destruct destroyed Player 2's Motorbike twice (the Round counted %d destructions): explosion_scene is null, no Explosion was ever added, none stands in the node group, SplitScreen has no link on unit_destroyed or round_started for the explosions, no engine error" % _q.units.destroyed.size())
