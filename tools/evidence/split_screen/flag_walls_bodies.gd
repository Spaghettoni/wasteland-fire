extends RefCounted
## The two bodies of the flag_walls scenario's damage check that are not Units (Story 012 AC-3): a
## body with apply_damage() and no type_id, which a Shot must stop on and never ask to take damage,
## and a Flag Wall with no stats, which logs one error as it enters the tree and nothing for a Shot.
## Run by flag_walls.gd.
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-3.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Flag Wall's scene.
const SCENE_PATH: String = "res://src/gameplay/defences/flag_wall.tscn"
## Metres out of the seat, along the Gate axis, where the shooter stands.
const SHOT_FROM: float = 15.0

## The engine errors this check causes on purpose (the Flag Wall with no stats).
var expected_errors: int = 0

var _w: Walls


func _init(kit: Walls) -> void:
	_w = kit


## A body with apply_damage() and no type_id, and a Flag Wall with no stats, each in the line of
## fire of Player 1's Buggy outside Base B's Gate: the Shot ends on it, nothing is asked of the
## first and the second logs one error as it enters the tree and nothing for the Shot. Adds the
## problems.
func run(problems: PackedStringArray, notes: PackedStringArray) -> void:
	var q: Quick = _w.s.q
	var world: Node = q.harness.split.get_node("World")
	var script: GDScript = GDScript.new()
	script.source_code = "extends StaticBody3D\nvar calls: int = 0\n\nfunc apply_damage(_amount: float) -> void:\n\tcalls += 1\n"
	script.reload()
	var body: StaticBody3D = StaticBody3D.new()
	body.set_script(script)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cube: BoxShape3D = BoxShape3D.new()
	cube.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = cube
	body.add_child(shape)
	world.add_child(body)
	body.global_position = _w.point(1, Vector3(0.0, 1.0, -16.0))
	await _w.face(0, Quick.BUGGY, 1, Walls.GATE, SHOT_FROM)
	await q.kit.advance(_w.longest_cadence())
	var errors_before: int = q.tokens.engine_log.errors.size()
	var end: Vector3 = await _w.shoot(0)
	q.kit.need(problems, end != Vector3.INF and int(body.get("calls")) == 0 and absf(_w.bases[1].to_local(end).z + 17.0) <= 0.05, "the stand-in with no type_id: shot ended %s, apply_damage called %s times" % [end, body.get("calls")])
	q.kit.need(problems, q.tokens.engine_log.errors.size() == errors_before and _w.wall(1, Walls.GATE).hit_points == Walls.HIT_POINTS, "the stand-in's Shot logged %d errors, the Gate-side Flag Wall has %.0f hit points" % [q.tokens.engine_log.errors.size() - errors_before, _w.wall(1, Walls.GATE).hit_points])
	world.remove_child(body)
	body.free()
	var bare: Structure = (load(SCENE_PATH) as PackedScene).instantiate() as Structure
	bare.stats = null
	world.add_child(bare)
	bare.global_transform = Transform3D(_w.bases[1].global_transform.basis, _w.point(1, Vector3(0.0, 0.0, -16.0)))
	expected_errors += 1
	q.kit.need(problems, q.tokens.engine_log.errors.size() == errors_before + 1, "a Flag Wall with no stats logged %d errors entering the tree" % (q.tokens.engine_log.errors.size() - errors_before))
	await q.kit.advance(_w.longest_cadence())
	end = await _w.shoot(0)
	bare.apply_damage(100.0)
	bare.restore()
	q.kit.need(problems, end != Vector3.INF and absf(_w.bases[1].to_local(end).z + 16.5) <= 0.05 and bare.type_id == &"" and not bare.is_standing and _w.look_shown(bare) == 0, "the Flag Wall with no stats: shot ended %s, type '%s', standing %s, look %d" % [end, bare.type_id, bare.is_standing, _w.look_shown(bare)])
	q.kit.need(problems, q.tokens.engine_log.errors.size() == errors_before + 1, "a Shot or a call on a Flag Wall with no stats logged %d more errors" % (q.tokens.engine_log.errors.size() - errors_before - 1))
	world.remove_child(bare)
	bare.free()
	notes.append("a body with no type_id and a Flag Wall with no stats stop a Shot silently (one error at the bare scene's _ready())")
