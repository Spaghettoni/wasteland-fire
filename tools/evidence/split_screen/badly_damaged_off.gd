extends RefCounted
## Scenario badly_damaged_off of the split screen evidence harness (split_screen_harness.gd): the proof of the runner's strip (Story 017 AC-7). It
## declares no BADLY_DAMAGED, as every scenario written before Story 017 declares none, so the runner has set the fraction of every type to 0 on the
## shared stats before the scene was instanced. A Motorbike is brought to 5 hit points, under the 8 where the state would begin, and driven at full
## throttle on the flat arena: it reaches its full speed, badly_damaged_changed is never emitted, the Unit is never badly damaged, no smoke node is
## ever added and the data say fraction 0 for every type and are still usable. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-7. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=badly_damaged_off

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes every choice itself, with its own keys. It declares nothing else: above all not BADLY_DAMAGED.
const OWN_CHOICE: bool = true
## Tokens enough that nothing ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 10, &"buggy": 10, &"truck": 10, &"gyrocopter": 10}
## Where the flat floor lies, how big it is, and where the Motorbike starts on it, metres.
const FLOOR_CENTRE: Vector3 = Vector3(0.0, 0.0, 800.0)
const FLOOR_SIZE: float = 400.0
const START: float = -100.0
## The hit points the Motorbike is left with: under the 8 where the state would begin with the starting data.
const LEFT: float = 5.0
## Ticks the throttle is held (the Motorbike needs 72 to reach its full speed).
const DRIVE_TICKS: int = 120

var _q: Quick
var _added: int = 0
var _changes: int = 0


## Plays the drive and the checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	harness.get_tree().node_added.connect(func(node: Node) -> void: _added += 1 if node is BadlyDamagedSmoke else 0)
	for player: int in Kit.PLAYERS:
		await _q.tokens.spawn(player, Quick.MOTORBIKE)
		_q.units.units[player].badly_damaged_changed.connect(func(_state: bool) -> void: _changes += 1)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE)
	shape.shape = box
	floor_body.add_child(shape)
	_q.units.units[0].get_parent().add_child(floor_body)
	floor_body.global_position = FLOOR_CENTRE + Vector3.DOWN * 0.5
	var unit: Unit = _q.units.units[0]
	unit.spawn(_q.units.pose(FLOOR_CENTRE + Vector3(START, 0.0, 0.0), Vector3.RIGHT), _q.units.stats(Quick.MOTORBIKE))
	await _q.kit.advance(Quick.Units.SETTLE_TICKS)
	unit.apply_damage(unit.hit_points - LEFT)
	harness.drive(0, 1, 0)
	await _q.kit.advance(DRIVE_TICKS)
	var speed: float = unit.current_speed
	harness.drive(0, 0, 0)
	_checks(harness, unit, speed)
	_q.close()
	harness.finish("changes=%d smoke_nodes=%d speed=%s %s" % [_changes, _added, speed, _q.engine_counts()])


## badly_damaged_stripped: nothing of the state happened at 5 of 40 hit points.
func _checks(harness: Node, unit: Unit, speed: float) -> void:
	var problems: PackedStringArray = []
	var fractions: Array[float] = []
	for stats: UnitStats in _q.controller.unit_types():
		fractions.append(stats.badly_damaged_fraction)
		_q.kit.need(problems, stats.first_problem().is_empty(), "%s: not usable: %s" % [stats.type_id, stats.first_problem()])
	_q.kit.need(problems, fractions.count(0.0) == fractions.size(), "the fractions are %s, not all 0" % [fractions])
	_q.kit.need(problems, unit.hit_points == LEFT and not unit.is_badly_damaged, "the Motorbike has %s hit points and badly damaged %s" % [unit.hit_points, unit.is_badly_damaged])
	_q.kit.need(problems, absf(speed - _q.units.stats(Quick.MOTORBIKE).max_speed) <= 0.001, "the Motorbike drove at %s m/s, not its full %s" % [speed, _q.units.stats(Quick.MOTORBIKE).max_speed])
	_q.kit.need(problems, _changes == 0 and _added == 0 and unit.get_node(String(Unit.MODEL_NODE_NAME)).get_node_or_null(String(UnitModel.SMOKE_NODE_NAME)) == null, "%d changes, %d smoke nodes added" % [_changes, _added])
	_q.kit.need(problems, _q.tokens.engine_log.errors.is_empty() and _q.tokens.engine_log.warnings.is_empty(), "the engine logged %s %s" % [_q.tokens.engine_log.errors, _q.tokens.engine_log.warnings])
	_q.kit.verdict("badly_damaged_stripped", problems, "a Motorbike left at %s of 40 hit points (the state would begin at 8) drove at its full %s m/s: every type's fraction is %s, badly_damaged_changed was never emitted, no smoke node was ever added" % [unit.hit_points, speed, fractions])
