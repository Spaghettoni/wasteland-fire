extends RefCounted
## The arming of the Story 014 scenario mines: AC-3 (a new Mine blinks in its owner's Team colour for
## 3 s and is harmless: no Unit on it, its own Truck included, sets it off; then it shines steadily and
## is live; both Players see every Mine, their own and the other's, in the view from above and in the
## chase view) and the going-live half of AC-4 (a Unit still on a Mine when it goes live is destroyed on
## the tick it does, and the Mine is gone in a short flash), a Unit parked before the Mine was laid under it
## included (the engine review's open point: a sensor made over a body at rest). Real keys. Tooling only.
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## The data the checks are written against: arming 3 s, a blink of 0.5 s lit for half of it, a flash of
## 0.3 s, at 60 ticks a second.
const ARMING_TICKS: int = 180
const BLINK_TICKS: int = 30
const LIT_TICKS: int = 15
const FLASH_TICKS: int = 18
## The trigger's radius in the data (0.8 m).
const TRIGGER_RADIUS: float = 0.8
## How long a Unit stands with no key held before a Mine is laid under it: 2 s, four times the half second
## after which the physics may let a body at rest sleep.
const PARK_TICKS: int = 120
## Where, from the arena's centre, the parked Unit stands: clear of the Mines of the other checks.
const PARK_SPOT: Vector3 = Vector3(0.0, 0.0, -20.0)

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object
## The own tick a Mine went live on, measured by _arming().
var _live_after: int = -1


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	_k.make_arena()
	await _arming()
	await _harmless()
	await _seen_by_both()
	await _parked_under()
	_k.free_arena()


## The blink in ticks: lit 15, dark 15, six times over, then lit and steady from the 180th own tick. The
## samples are taken by the tick hook, which reads the tick before (the runner's continuation runs before
## the nodes' tick), so the sample taken on runner tick N + k + 1 is the Mine's own tick k, N being the tick
## it entered the tree on.
func _arming() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var before: int = _k.laid.size()
	var samples: Array = []
	var hook: Callable = func() -> void:
		if _k.laid.size() > before:
			var entry: Dictionary = _k.laid[before]
			var mine: Mine = entry["mine"] as Mine
			var own: int = _q.harness.ticks - int(entry["tick"]) - 1
			if own >= 1 and is_instance_valid(mine):
				samples.append([mine.body.visible, mine.state, own])
	_q.kit.on_tick = hook
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(120.0, 0.0, 120.0), Vector3.RIGHT)
	await _q.kit.advance(ARMING_TICKS + 70 - 6)
	_q.kit.on_tick = Callable()
	var runs: PackedStringArray = []
	var current: bool = bool(samples[0][0])
	var length: int = 0
	var live_after: int = -1
	var steady: bool = true
	for sample: Array in samples:
		if int(sample[1]) == Mine.State.LIVE:
			live_after = int(sample[2]) if live_after < 0 else live_after
			steady = steady and bool(sample[0])
			continue
		if bool(sample[0]) == current:
			length += 1
		else:
			runs.append("%s%d" % ["L" if current else "d", length])
			current = bool(sample[0])
			length = 1
	runs.append("%s%d" % ["L" if current else "d", length])
	_live_after = live_after
	_q.kit.need(problems, mine.state == Mine.State.LIVE and steady, "the Mine is state %d and its disc stayed lit while live: %s" % [mine.state, steady])
	_q.kit.need(problems, live_after == ARMING_TICKS, "it went live on its own tick %d" % live_after)
	var expected: PackedStringArray = []
	for _blink: int in ARMING_TICKS / BLINK_TICKS:
		expected.append("L%d" % LIT_TICKS)
		expected.append("d%d" % (BLINK_TICKS - LIT_TICKS))
	expected[-1] = "d%d" % (BLINK_TICKS - LIT_TICKS - 1)
	_q.kit.need(problems, runs == expected, "the blink reads %s" % [runs])
	measured.append("live_after=%d" % live_after)
	_q.kit.verdict("arming_and_blink", problems, "a new Mine blinked lit 15 ticks and dark 15 ticks, six times over (%s...), went live on its 180th own tick (3 s) and then shone steadily" % ", ".join(runs.slice(0, 4)))
	mine.queue_free()
	await _q.kit.advance(2)


## No Unit on an arming Mine sets it off: the owner's Truck and the other Player's Motorbike stand on it.
func _harmless() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.revive(1)
	await _k.put(0, Quick.TRUCK, Kit14.ARENA + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	var truck: Unit = _q.units.units[0]
	var bike: Unit = _q.units.units[1]
	await _q.kit.advance(30)
	_k.w.s.flags.teleport(0, Kit14.ARENA, Vector3.RIGHT)
	await _k.put(1, Quick.MOTORBIKE, Kit14.ARENA + Vector3(0.0, 0.0, 0.3), Vector3.RIGHT)
	var covered: float = _k.gap(truck, mine.global_position, 0.8)
	await _q.kit.advance(100)
	_q.kit.need(problems, covered < 0.0, "the Truck's box is %.2f m from the trigger, not on it" % covered)
	_q.kit.need(problems, truck.is_alive and bike.is_alive and mine.state == Mine.State.ARMING, "after 130 ticks: Truck alive=%s, Motorbike alive=%s, Mine state %d" % [truck.is_alive, bike.is_alive, mine.state])
	_q.kit.verdict("arming_mine_is_harmless", problems, "the owner's Truck (box %.2f m inside the trigger) and the other Player's Motorbike stood on an arming Mine for 100 ticks and both lived, the Mine still arming" % -covered)
	await _going_live(record)


## The Units still on the Mine when it goes live are destroyed on that tick; the flash shows, then the Mine is gone.
func _going_live(record: Dictionary) -> void:
	var problems: PackedStringArray = []
	var mine: Mine = record["mine"] as Mine
	var truck: Unit = _q.units.units[0]
	var bike: Unit = _q.units.units[1]
	var tokens: Array = _q.tokens.counts()
	var order: Array[int] = []
	var seen: Dictionary = {"spent": -1, "flash": false, "disc_hidden": false, "flash_ticks": 0}
	var hook: Callable = func() -> void:
		var node: Variant = record["mine"]
		if is_instance_valid(node) and (node as Mine).is_inside_tree() and (node as Mine).state == Mine.State.SPENT:
			var spent: Mine = node as Mine
			if seen["spent"] < 0:
				seen["spent"] = _q.harness.ticks
				seen["disc_hidden"] = not spent.body.visible
			seen["flash"] = seen["flash"] or spent.flash.visible
			seen["flash_ticks"] += 1 if spent.flash.visible else 0
	_q.kit.on_tick = hook
	var mark: int = _q.units.destroyed.size()
	for _wait: int in 200:
		if mine.state == Mine.State.SPENT or not mine.is_inside_tree():
			break
		await _q.kit.tick()
	await _q.kit.advance(2)
	var gone: int = await _k.wait_gone(record, 40)
	_q.kit.on_tick = Callable()
	for entry: Vector2i in _q.units.destroyed.slice(mark):
		order.append(entry.x)
	_q.kit.need(problems, not truck.is_alive and not bike.is_alive, "alive after the Mine went live: Truck %s, Motorbike %s" % [truck.is_alive, bike.is_alive])
	_q.kit.need(problems, order == [0, 1], "the Units were destroyed in the order %s (node-name order: Player 1's first)" % [order])
	var blast_after: int = int(seen["spent"]) - int(record["tick"]) - 1
	_q.kit.need(problems, blast_after == _live_after, "the Units were destroyed %d ticks after the Mine entered the tree; a Mine goes live on its own tick %d" % [blast_after, _live_after])
	_q.kit.need(problems, bool(seen["flash"]) and bool(seen["disc_hidden"]), "when spent the flash showed %s and the disc was hidden %s" % [seen["flash"], seen["disc_hidden"]])
	var after: Array = _q.tokens.counts()
	_q.kit.need(problems, after[0][Quick.TRUCK] == tokens[0][Quick.TRUCK] - 1 and after[1][Quick.MOTORBIKE] == tokens[1][Quick.MOTORBIKE] - 1, "Tokens before %s, after %s" % [tokens, after])
	_q.kit.need(problems, gone >= 0 and int(seen["flash_ticks"]) == FLASH_TICKS, "the flash showed for %d ticks and the Mine left the tree on tick %d" % [seen["flash_ticks"], gone])
	measured.append("flash_ticks=%d" % int(seen["flash_ticks"]))
	_q.kit.verdict("going_live_destroys", problems, "a Truck and a Motorbike still on a Mine when it went live were both destroyed on that very tick (its own tick 180), Player 1's first, a Token each; the disc went out and the flash showed for %d ticks (0.3 s), then the Mine left the tree" % int(seen["flash_ticks"]))


## Both Players' cameras draw every Mine, in the view from above and in the chase view.
func _seen_by_both() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.revive(1)
	var mines: Array[Mine] = []
	for player: int in [0, 1]:
		var record: Dictionary = await _k.live_mine(Kit14.ARENA + Vector3(0.0, 0.0, 4.0 * player), player)
		mines.append(record["mine"] as Mine)
	for view: int in 2:
		for player: int in [0, 1]:
			var camera: Camera3D = _q.units.cameras[player]
			for mine: Mine in mines:
				var layers: int = (mine.body as MeshInstance3D).layers
				_q.kit.need(problems, (camera.cull_mask & layers) != 0 and mine.body.visible, "Player %d's camera (view %d) does not draw Player %d's Mine" % [player + 1, view, mine.player_index + 1])
				_q.kit.need(problems, (camera.cull_mask & (mine.flash as MeshInstance3D).layers) != 0, "Player %d's camera (view %d) does not draw the flash of Player %d's Mine" % [player + 1, view, mine.player_index + 1])
		for player: int in [0, 1]:
			await _q.kit.press_settled([KEY_Q if player == 0 else KEY_SLASH] as Array[Key])
	for index: int in mines.size():
		var colour: Color = ((mines[index].body as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
		var truck_colour: Color = (_q.units.units[index].team_material as StandardMaterial3D).albedo_color
		_q.kit.need(problems, colour == truck_colour, "Player %d's Mine is %s, its Team colour is %s" % [index + 1, colour, truck_colour])
	_q.kit.verdict("both_players_see_every_mine", problems, "both Players' cameras draw both Players' live Mines and their flash (render layers) in the view from above and, after the camera key, in the chase view; each Mine wears its owner's Team colour (orange for Player 1, teal for Player 2)")


## A Motorbike parked with no key held for 2 s, then a Mine laid under it by the other Player's Truck (a Unit is no
## obstacle to the open-ground test): the Motorbike is destroyed on the Mine's going-live tick, though the zone was
## made over a body at rest. What the physics server reports of the body's sleep is recorded.
func _parked_under() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.revive(1)
	var spot: Vector3 = Kit14.ARENA + PARK_SPOT
	await _k.put(1, Quick.MOTORBIKE, spot, Vector3.FORWARD)
	var bike: Unit = _q.units.units[1]
	await _q.kit.advance(PARK_TICKS)
	await _k.put(0, Quick.TRUCK, spot + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var parked_at: Vector3 = bike.global_position
	var asleep_before: bool = PhysicsServer3D.body_get_state(bike.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING)
	var record: Dictionary = await _k.lay(0)
	if record.is_empty():
		_q.kit.need(problems, false, "the Truck laid no Mine under the parked Motorbike")
		_q.kit.verdict("parked_unit_under_a_new_mine", problems, "no Mine")
		return
	var mine: Mine = record["mine"] as Mine
	var under: float = _k.gap(bike, mine.global_position, TRIGGER_RADIUS)
	var seen: Dictionary = {"spent": -1, "moved": 0.0, "asleep": asleep_before}
	var hook: Callable = func() -> void:
		var node: Variant = record["mine"]
		if is_instance_valid(node) and (node as Mine).state == Mine.State.SPENT and int(seen["spent"]) < 0:
			seen["spent"] = _q.harness.ticks
		if bike.is_alive:
			seen["moved"] = maxf(float(seen["moved"]), bike.global_position.distance_to(parked_at))
			seen["asleep"] = PhysicsServer3D.body_get_state(bike.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING)
	_q.kit.on_tick = hook
	for _wait: int in ARMING_TICKS + 20:
		if not bike.is_alive:
			break
		await _q.kit.tick()
	await _q.kit.advance(2)
	_q.kit.on_tick = Callable()
	var blast_after: int = int(seen["spent"]) - int(record["tick"]) - 1
	_q.kit.need(problems, under < 0.0, "the Motorbike's box is %.2f m from the trigger, not on it" % under)
	_q.kit.need(problems, not bike.is_alive and blast_after == _live_after, "the parked Motorbike is alive %s; the Mine went off %d ticks after it entered the tree (live on its own tick %d)" % [bike.is_alive, blast_after, _live_after])
	_q.kit.need(problems, float(seen["moved"]) < 0.01, "the Motorbike moved %.3f m while it stood parked" % float(seen["moved"]))
	measured.append("parked_asleep=%s" % asleep_before)
	_q.kit.verdict("parked_unit_under_a_new_mine", problems, "a Motorbike parked with no key held for 2 s (the physics server reported it asleep: %s), then a Mine laid under it by the other Player's Truck (its box %.2f m inside the trigger), was destroyed on the Mine's going-live tick (its own tick %d), never having moved more than %.3f m" % [asleep_before, -under, _live_after, float(seen["moved"])])
