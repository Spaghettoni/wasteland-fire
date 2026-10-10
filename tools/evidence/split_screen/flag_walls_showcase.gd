extends RefCounted
## Scenario flag_walls_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 012 on Map 01 with the shipped data, Map stock and view from above,
## every key a real key event. Nine moments, each held, then read: in_the_garages (Player 1's Truck
## and Player 2's Motorbike on their Garages' first spots, both boxes closed), motorbike_shot
## (Player 2's Motorbike's Shot, a tracer in flight 2.5 m from a standing Flag Wall, then ending on
## it and taking nothing), first_damaged_look (Player 1's Truck's first Shot has left Base B's
## Gate-side Flag Wall at 15 of 40 hit points, in its first damaged look), truck_breaks (the second
## Shot has broken it: rubble in the gap), takes_flag (Player 1's Motorbike carries Player 2's Flag
## out through the gap: "You carry the enemy Flag"), round_won (it has delivered it),
## boxes_back_after_r (R: both boxes closed and whole again, both Players choosing),
## second_damaged_look (Player 1's Gyrocopter's two Shots have left the same Flag Wall at 10 of 40,
## in its second damaged look) and gyro_over (the Gyrocopter over that Flag Wall at full speed). A
## SPLIT line per moment with frame=, the number of the PNG that shows it in a --write-movie
## recording, and what the moment's premise reads. No CHECK in a normal run: it ends with RESULT
## ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty or
## false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-012-flag-walls.md, Test Evidence (retained frames; the two
## damaged looks of AC-9 joined on 2026-10-08). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/walls.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=flag_walls_showcase

## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, the model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap and the camera the build ships with, and the Flag Walls and spots the Map
## ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
## The frames show Map 01's own Token stock: nothing here spends a Token.
const USE_MAP_STOCK: bool = true
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 30
## Metres out of the seat, along the Gate axis, where a shooter stands, and how far a tracer is from
## the face when its moment is read.
const SHOT_FROM: float = 10.0
const TRACER_FROM: float = 2.5
## Ticks a crossing Gyrocopter may take to be over a Flag Wall.
const CROSS_LIMIT_TICKS: int = 300

var _w: Walls
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_w = Walls.new(harness)
	await _w.s.play(0, Quick.TRUCK)
	await _w.s.play(1, Quick.MOTORBIKE)
	await _w.s.q.kit.advance(HOLD_TICKS)
	var closed: int = _w.all().filter(func(wall: Structure) -> bool: return wall.is_standing).size()
	_need(closed == 8 and _w.on_first_spot(0) and _w.on_first_spot(1), "in_the_garages: %d Flag Walls standing, first spots %s %s" % [closed, _w.on_first_spot(0), _w.on_first_spot(1)])
	_line("in_the_garages", "p1=%s p2=%s walls_standing=%d" % [_w.s.q.units.units[0].type_id, _w.s.q.units.units[1].type_id, closed])
	await _motorbike_shot()
	await _truck_breaks()
	await _takes_flag()
	await _boxes_back_after_r()
	await _second_damaged_look()
	await _gyro_over()
	if not _problems.is_empty():
		_w.s.q.kit.verdict("premise", _problems, " | ".join(_moments))
	_w.close()
	harness.finish("moments=%d falls=%d %s" % [_moments.size(), _w.falls.size(), _w.s.q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_w.s.q.harness.scenario, _w.s.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_w.s.q.kit.need(_problems, holds, problem)


## Player 2's Motorbike fires at Base A's standing Gate-side Flag Wall: read with the tracer 2.5 m
## from the face, then held until the Shot has ended on it, taking nothing and changing no look. A
## coroutine.
func _motorbike_shot() -> void:
	var q: Quick = _w.s.q
	await _w.face(1, Quick.MOTORBIKE, 0, Walls.GATE, SHOT_FROM)
	await q.kit.advance(_w.longest_cadence())
	var wall: Structure = _w.wall(0, Walls.GATE)
	var hits_before: int = _w.hits.size()
	var shots_before: int = q.units.shots.size()
	var face: Vector3 = _w.point(0, Vector3(0.0, q.controller.rules.shooting_height, Walls.SEAT.z - Walls.FACE))
	await q.units.hold_fire(1, 1)
	var seen: bool = await _w.s.wait_until(func() -> bool: return q.units.shots.size() > shots_before and is_instance_valid(q.units.shots[-1]) and q.units.shots[-1].global_position.distance_to(face) <= TRACER_FROM)
	_need(seen, "motorbike_shot: the tracer never came within %.1f m of the face" % TRACER_FROM)
	_line("motorbike_shot", "tracer_to_face=%.2f wall_hp=%.0f" % [q.units.shots[-1].global_position.distance_to(face) if seen and is_instance_valid(q.units.shots[-1]) else -1.0, wall.hit_points])
	await q.kit.advance(HOLD_TICKS)
	_need(wall.is_standing and wall.hit_points == Walls.HIT_POINTS and _w.hits.size() == hits_before and q.units.shot_ends[shots_before] != Vector3.INF and _w.look_shown(wall) == 0, "motorbike_shot: the Shot took %.0f off the Flag Wall, never ended or changed its look (%d)" % [Walls.HIT_POINTS - wall.hit_points, _w.look_shown(wall)])


## Player 1's Truck fires twice at Base B's Gate-side Flag Wall from outside the Gate: after the
## first Shot the Flag Wall shows its first damaged look (15 of 40 hit points), after the second
## the rubble is in the gap.
func _truck_breaks() -> void:
	var q: Quick = _w.s.q
	await _w.face(0, Quick.TRUCK, 1, Walls.GATE, SHOT_FROM + 2.0)
	await q.kit.advance(_w.longest_cadence())
	var wall: Structure = _w.wall(1, Walls.GATE)
	await q.units.hold_fire(0, 1)
	await q.kit.advance(_w.cadence(Quick.TRUCK))
	await q.kit.advance(HOLD_TICKS)
	_need(wall.is_standing and _w.look_shown(wall) == 1, "first_damaged_look: the Gate-side Flag Wall shows look %d at %.0f hit points" % [_w.look_shown(wall), wall.hit_points])
	_line("first_damaged_look", "wall_hp=%.0f look=%d" % [wall.hit_points, _w.look_shown(wall)])
	await q.units.hold_fire(0, 1)
	await q.kit.advance(_w.cadence(Quick.TRUCK))
	await q.kit.advance(HOLD_TICKS)
	_need(not wall.is_standing and _w.look_shown(wall) == -1, "truck_breaks: the Gate-side Flag Wall is standing %s, look %d" % [wall.is_standing, _w.look_shown(wall)])
	_line("truck_breaks", "wall_standing=%s rubble=%s others_standing=%d" % [wall.is_standing, _w.look_shown(wall) == -1, [Walls.GARAGE, Walls.LEFT, Walls.RIGHT].filter(func(side: int) -> bool: return _w.wall(1, side).is_standing).size()])


## Player 1's Motorbike drives in through the gap and is handed the Flag, then backs out and
## delivers it.
func _takes_flag() -> void:
	var q: Quick = _w.s.q
	_need(await _w.take_flag(0, 1, Walls.GATE), "takes_flag: the Motorbike never took the Flag")
	await q.kit.advance(HOLD_TICKS)
	_need(_w.status_text(0) == q.units.huds[0].carrying_text, "takes_flag: the HUD reads '%s'" % _w.status_text(0))
	_line("takes_flag", "hud='%s' along=%.2f" % [_w.status_text(0), _w.along(0, 1, Walls.GATE)])
	await _w.back_out(0, 1, Walls.GATE)
	_need(await _w.deliver(0), "round_won: the delivery did not end the Round")
	await q.kit.advance(HOLD_TICKS)
	_line("round_won", "lines=%s" % [q.tokens.over_lines(0)])


## R: both boxes are back, closed and in the whole look, with both Players choosing; read before the
## choices are made.
func _boxes_back_after_r() -> void:
	var q: Quick = _w.s.q
	await q.tokens.restart()
	await q.kit.advance(HOLD_TICKS)
	var whole: int = _w.all().filter(func(wall: Structure) -> bool: return wall.is_standing and wall.hit_points == Walls.HIT_POINTS and _w.look_shown(wall) == 0).size()
	var panels: Array[bool] = [q.units.panels[0].visible, q.units.panels[1].visible]
	_need(whole == 8 and panels == [true, true], "boxes_back_after_r: %d of 8 whole, panels %s" % [whole, panels])
	_line("boxes_back_after_r", "walls_whole=%d panels=%s" % [whole, panels])
	await _w.s.both_play()


## Player 1's Gyrocopter fires twice at Base B's Gate-side Flag Wall from outside the Gate: the Flag
## Wall shows its second damaged look (10 of 40 hit points).
func _second_damaged_look() -> void:
	var q: Quick = _w.s.q
	await _w.face(0, Quick.GYROCOPTER, 1, Walls.GATE, SHOT_FROM)
	await q.kit.advance(_w.longest_cadence())
	var wall: Structure = _w.wall(1, Walls.GATE)
	for _shot: int in 2:
		await q.units.hold_fire(0, 1)
		await q.kit.advance(_w.cadence(Quick.GYROCOPTER))
	await q.kit.advance(HOLD_TICKS)
	_need(wall.is_standing and _w.look_shown(wall) == 2, "second_damaged_look: the Gate-side Flag Wall shows look %d at %.0f hit points" % [_w.look_shown(wall), wall.hit_points])
	_line("second_damaged_look", "wall_hp=%.0f look=%d" % [wall.hit_points, _w.look_shown(wall)])


## Player 1's Gyrocopter flies at full speed across Base B's Gate-side Flag Wall, in its second
## damaged look: read while its model is over it.
func _gyro_over() -> void:
	var q: Quick = _w.s.q
	var half: float = q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	await _w.face(0, Quick.GYROCOPTER, 1, Walls.GATE, Walls.FACE + 14.0 + half)
	var wall: Structure = _w.wall(1, Walls.GATE)
	var mesh: MeshInstance3D = wall.get_node("Mesh") as MeshInstance3D
	var top: AABB = mesh.global_transform * mesh.get_aabb()
	var clearance: float = (q.units.units[0].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel).rise_clearance
	var over: bool = false
	for _tick: int in CROSS_LIMIT_TICKS:
		q.harness.drive(0, 1, 0)
		await q.kit.tick()
		var box: AABB = Quick.model_box(q.units.units[0])
		over = box.position.x < top.end.x and box.end.x > top.position.x and box.position.z < top.end.z and box.end.z > top.position.z and box.position.y >= top.end.y + clearance - 0.02
		if over:
			break
	_need(over, "gyro_over: the model was never over the Flag Wall with its clearance")
	_line("gyro_over", "over=%s model_bottom=%.2f wall_top=%.2f look=%d" % [over, Quick.model_box(q.units.units[0]).position.y, top.end.y, _w.look_shown(wall)])
	await q.kit.advance(Walls.SETTLE)
	q.harness.release_all()
