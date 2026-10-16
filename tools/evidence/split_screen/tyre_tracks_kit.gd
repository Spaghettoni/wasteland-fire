extends RefCounted
## What the Story 026 scenarios (tyre_tracks with its modules, tyre_tracks_showcase and tyre_tracks_fps) share on top of the
## Story 025 kit (rotors_kit.gd, which wraps the Story 021 kit, and so on down to the Story 009 helpers in quick_fix_kit.gd):
## the Players' choice with real keys for any pair of types, drive plans (what a Player holds for how many ticks) run for both
## Players at once, the Map's TyreTracks node, and the type indices. Tooling only: nothing under src/ depends on this file;
## loaded with a preload constant. Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md, Test Evidence.

## The Story 025 kit: k.k is the Story 021 kit.
const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, a model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Token kit (token_kit.gd): the keys of the choice.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The watch node (tyre_tracks_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_watch.gd")
## How close a stroke's end is to the place the data puts the tyre, metres (float32 positions of a few tens of metres).
const POSITION_TOLERANCE: float = 0.0001
## How many rows back a stroke of a slow roll may start (a tyre that moved less than the minimum step keeps its old place until it has moved enough).
const SLOW_ROLL_ROWS: int = 60
## The first rows of a window, whose strokes may start from a place before the window: judged for the audit's rule and the jump step, not for their ends.
const EDGE_ROWS: int = 4

## The Story 025 kit.
var k: Kit25
## The watch node under the launch scene, or null when the runner took the Map's TyreTracks away.
var watch: Watch


## Makes the Story 025 kit and, when the Map has its TyreTracks, starts the watch.
func _init(harness_node: Node) -> void:
	k = Kit25.new(harness_node)
	if tracks() != null:
		watch = Watch.new()
		watch.harness = harness_node
		watch.tracks = tracks()
		watch.units = [q().units.units[0], q().units.units[1]]
		watch.map_kit = q().map
		harness_node.split.add_child(watch)


## Removes the watch and what the Story 025 kit added: call it before the scenario's finish().
func close() -> void:
	if watch != null:
		watch.queue_free()
	k.close()


## The Story 021 kit's pieces, one level down: the Wall Panels and Turrets, the Mines, the Flags and the Swap.
func walls() -> Object:
	return k.k.walls()


func mines() -> Object:
	return k.k.mines()


func flags() -> Object:
	return k.k.flags()


func swap() -> Object:
	return k.k.swap()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## The Map's TyreTracks node, or null when the runner took it away.
func tracks() -> TyreTracks:
	return q().harness.split.field.tyre_tracks


## Both Players choose a type with their own keys at once (types: an index of the unit types for each Player), the next-type key
## for whichever cursor is not on it, then both fire keys, and wait until both Units are in play. A coroutine: await it.
func choose(types: Array[int]) -> void:
	for _step: int in 8:
		var keys: Array[Key] = []
		for player: int in Kit.PLAYERS:
			if q().units.panels[player].choice_input.cursor != types[player]:
				keys.append_array(Tokens.keys(&"next", player))
		if keys.is_empty():
			break
		await q().kit.press_settled(keys)
	await q().kit.press_settled(Tokens.keys(&"fire", 0) + Tokens.keys(&"fire", 1))
	for _wait: int in 400:
		if q().controller.is_alive(0) and q().controller.is_alive(1):
			break
		await q().kit.tick()
	await q().kit.advance(3)


## The ticks of a drive plan: segments is an Array of [ticks, throttle, steer] (throttle and steer -1, 0 or 1; steer 1 turns
## left), each held for its ticks. Returns one Vector2i(throttle, steer) per tick.
static func plan(segments: Array) -> Array[Vector2i]:
	var ticks: Array[Vector2i] = []
	for segment: Array in segments:
		for _tick: int in int(segment[0]):
			ticks.append(Vector2i(int(segment[1]), int(segment[2])))
	return ticks


## The ticks a Unit of a type takes to go once round at full lock and top speed: a circle of radius max_speed / turn_rate, at the
## yaw rate turn_rate, so 2 pi over it, whatever the speed.
func circle_ticks(stats: UnitStats) -> int:
	return int(ceil(TAU / stats.turn_rate * float(Engine.physics_ticks_per_second)))


## Both Players' Units staged as one type at the given spots and facings, at rest, with a full tank. A coroutine: await it.
func stage(type_index: int, spots: Array[Vector3], facings: Array[Vector3]) -> void:
	await q().map.stage([type_index, type_index], spots, facings, true)


## Runs the plans (run()) with the watch on, and returns its rows: one per tick the plans took, in order. A coroutine: await it.
func record(plans: Array) -> Array[Dictionary]:
	begin_rows()
	await run(plans)
	return end_rows()


## Starts filing the watch's rows from the next tick, from an empty list.
func begin_rows() -> void:
	watch.clear()
	watch.logging = true


## Stops filing and returns the rows filed since begin_rows(), one per tick, in order.
func end_rows() -> Array[Dictionary]:
	watch.logging = false
	var rows: Array[Dictionary] = watch.rows.duplicate()
	watch.clear()
	return rows


## How many of the rows' ticks each Player's Unit touched anything but the ground on (the watch's `walls`), by Player: a drive the
## checks measure must touch nothing, or a bounce off a wreck reads as the tracks' doing.
static func touches(rows: Array[Dictionary]) -> Array[int]:
	var found: Array[int] = [0, 0]
	for row: Dictionary in rows:
		for player: int in found.size():
			found[player] += 1 if bool((row["walls"] as Array)[player]) else 0
	return found


## True when neither Player's Unit touched anything but the ground on any of the rows' ticks (touches()).
static func touched_nothing(rows: Array[Dictionary]) -> bool:
	var found: Array[int] = touches(rows)
	return found[0] == 0 and found[1] == 0


## Where tyre `tyre` of Player `player`'s Unit touched the ground after the tick a row is of, as (X, Z).
static func contact(row: Dictionary, player: int, tyre: int) -> Vector2:
	var stats: UnitStats = (row["stats"] as Array)[player]
	return (stats.tyres[tyre] as TyreContact).world_point((row["poses"] as Array)[player])


## Whether the tracks may stroke the tyres of a Player's Unit in row `index`: it was alive and on the floor after the tick of the row before, alive after the
## one before that, and the same type in both (the node's own rule, written from the rows).
static func explained(rows: Array[Dictionary], index: int, player: int) -> bool:
	var before: Dictionary = rows[index - 1]
	var then: Dictionary = rows[index - 2]
	var alive: bool = (before["alive"] as Array)[player] and (then["alive"] as Array)[player] and (before["on_floor"] as Array)[player]
	return alive and (before["stats"] as Array)[player] == (then["stats"] as Array)[player]


## One stroke against the rows around it: from the place its tyre touched the ground two rows back, to the place one row back, as wide as the
## tyre, stamped with the clock of its row. A tyre that moved less than the minimum step keeps its old place, so with `slack` rows above zero the
## stroke may start from the place the tyre touched the ground that many rows further back or fewer (a slow roll accumulates). Returns a problem or
## an empty String.
static func stroke_problem(rows: Array[Dictionary], index: int, player: int, stroke: Dictionary, slack: int = 0) -> String:
	var tyre: int = int(stroke["tyre"])
	var data: TyreContact = (((rows[index]["stats"]) as Array)[player] as UnitStats).tyres[tyre]
	var to: Vector2 = contact(rows[index - 1], player, tyre)
	var started: bool = false
	var from: Vector2 = contact(rows[index - 2], player, tyre)
	for back: int in range(index - 2, maxi(index - 2 - slack, 0) - 1, -1):
		started = started or (stroke["from"] as Vector2).distance_to(contact(rows[back], player, tyre)) <= POSITION_TOLERANCE
	if not started or (stroke["to"] as Vector2).distance_to(to) > POSITION_TOLERANCE:
		return "row %d Player %d tyre %d: the stroke runs %s to %s, the tyre touched %s then %s" % [index, player + 1, tyre, stroke["from"], stroke["to"], from, to]
	if not is_equal_approx(float(stroke["width"]), data.width) or not is_equal_approx(float(stroke["time"]), float(rows[index]["now"])):
		return "row %d Player %d tyre %d: width %s (data %s) time %s (clock %s)" % [index, player + 1, tyre, stroke["width"], data.width, stroke["time"], rows[index]["now"]]
	return ""


## The audit of a window (tyre_tracks_lifecycle.gd's class doc): the problems found, and how many strokes and how many Unit-ticks it held, for the verdict's text. The ends of
## the strokes are judged from row `judge_ends_from` on.
static func audit(rows: Array[Dictionary], jump_step: float, judge_ends_from: int = EDGE_ROWS) -> Dictionary:
	var problems: PackedStringArray = []
	var strokes: int = 0
	var benched: int = 0
	var airborne: int = 0
	for index: int in range(2, rows.size()):
		for player: int in Kit.PLAYERS:
			benched += 0 if (rows[index]["alive"] as Array)[player] else 1
			airborne += 1 if (rows[index]["alive"] as Array)[player] and not (rows[index]["on_floor"] as Array)[player] else 0
			var made: Array[Dictionary] = strokes_of(rows[index], player)
			need(problems, made.is_empty() or explained(rows, index, player), "row %d Player %d: %d strokes with the Unit not alive and on the floor as one type in the two rows before" % [index, player + 1, made.size()])
			for stroke: Dictionary in made:
				strokes += 1
				need(problems, (stroke["from"] as Vector2).distance_to(stroke["to"] as Vector2) <= jump_step, "row %d Player %d: a stroke %.2f m long, over the jump step %.2f m" % [index, player + 1, (stroke["from"] as Vector2).distance_to(stroke["to"] as Vector2), jump_step])
				if explained(rows, index, player) and index >= judge_ends_from:
					var problem: String = stroke_problem(rows, index, player, stroke, SLOW_ROLL_ROWS)
					need(problems, problem.is_empty(), problem)
	return {"problems": problems, "strokes": strokes, "benched": benched, "airborne": airborne}


## Adds a problem unless the condition holds (check_kit.gd's need() without the instance).
static func need(problems: PackedStringArray, holds: bool, problem: String) -> void:
	if not holds:
		problems.append(problem)


## The strokes of one Player's Unit in a row, in the order the node made them.
static func strokes_of(row: Dictionary, player: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for stroke: Dictionary in row["strokes"]:
		if int(stroke["unit"]) == player:
			found.append(stroke)
	return found


## How many values stand apart by more than `tolerance` once sorted: the number of lines a list of lateral places makes.
static func distinct(values: PackedFloat64Array, tolerance: float) -> int:
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var count: int = 0
	for index: int in sorted.size():
		if index == 0 or sorted[index] - sorted[index - 1] > tolerance:
			count += 1
	return count


## Holds each Player's plan (one entry of drive plans for each Player, from plan()) tick by tick, both at once, a Player whose plan
## is over holding nothing, until the longer plan is done; then releases every key. A coroutine: await it.
func run(plans: Array) -> void:
	var longest: int = 0
	for one: Array in plans:
		longest = maxi(longest, one.size())
	for index: int in longest:
		for player: int in Kit.PLAYERS:
			var held: Vector2i = plans[player][index] if index < (plans[player] as Array).size() else Vector2i.ZERO
			q().harness.drive(player, held.x, held.y)
		await q().kit.tick()
	q().harness.release_all()
