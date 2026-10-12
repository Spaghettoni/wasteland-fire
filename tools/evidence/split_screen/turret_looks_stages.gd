extends RefCounted
## The stages and kept checks of the turret_looks scenario (Story 015 AC-1): what a standing Turret
## shows as it loses hit points, on the shipped Turrets and Map 01. stages: each Player's Unit of each
## type fires with its real fire key at the canyon-side Turret of the other Base from behind the rock
## (where no Turret sees it) until the Turret falls, and after every Shot the one look shown is the
## one the data's fractions predict from the hit points, the head and its steel and the band dressed
## to match, and the Shots that change the look are the story's (a Truck's 1st, 3rd and 4th, a
## Buggy's 2nd, 6th and 9th, a Gyrocopter's 2nd, 5th and 7th, a Motorbike's 5th, 14th and 20th: the
## Motorbike's 4th and 13th Shots leave exactly 80% and 35% and still show the look above); every
## hit_points_changed was emitted with the look its hit points call for; the edges again by
## apply_damage(), then restore() brings back the whole look and the head's own steel; a Player's
## own Shots end on that Player's Turret and change neither its hit points nor its look. kept: hurt
## Turrets keep their look and hit points through a Unit's destruction, its respawn and a Swap to each
## type and through the Round's end by a Flag delivery, fallen Turrets stay fallen, and R brings back
## every Turret whole, the head at its rest heading. Run by turret_looks.gd. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md AC-1. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, the mirror.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Walls' names.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd).
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## Ticks a Unit may fire at a Turret before it must have brought it down.
const FIRE_LIMIT_TICKS: int = 1500
## Metres in front of a Turret, along its rest heading, a Unit is put at for its own Shots, and the
## ticks it holds fire.
const AHEAD: float = 12.0
const WATCH: int = 120
## Hit points a hurt Turret is left with where a check needs it hurt: the second look; and the
## hit points taken off a Turret that a Player's own Shots then meet: it is left in the first look.
const HURT_TO: float = 30.0
const OWN_TAKEN: float = 30.0
## Where a Unit is put to be destroyed away from home: the open salt flat in front of its Base, Base-local.
const AWAY: Vector3 = Vector3(0.0, 0.0, -60.0)

var _k: Kit13
## What each check found, for the RESULT line.
var measured: PackedStringArray = []
## Every hit_points_changed of a Turret: {turret, hp, look, dressed, head}, in order, each read in the handler.
var _hits: Array[Dictionary] = []


func _init(kit: Kit13) -> void:
	_k = kit
	for who: Turret in _k.all():
		who.hit_points_changed.connect(func(hit_points: float, _most: float) -> void:
			var look: int = Looks.look_shown(who)
			_hits.append({"turret": who, "hp": hit_points, "look": look, "head": Looks.head_visible(who),
				"dressed": Looks.head_dressed(who, look, _k.w.bases[who.player_index].color_material)}))


## The checks, in order.
func run() -> void:
	await _stages()
	await _kept()


## The Turret a Player's Unit shoots at from behind the canyon's rock: its Base's canyon-side one.
func _target_of(shooter: int) -> Turret:
	return _k.turret(1 - shooter, Kit13.LEFT if shooter == 1 else Kit13.RIGHT)


## stages (AC-1): the runs to the fall, the edges, restore() and the Players' own Shots.
func _stages() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var rules: MatchRules = q.controller.rules
	var result: PackedStringArray = []
	var stats: TurretStats = _k.turret(0, Kit13.LEFT).stats as TurretStats
	for type_index: int in q.controller.unit_types().size():
		var unit_stats: UnitStats = q.units.stats(type_index)
		var each: float = unit_stats.damage * rules.damage_matrix.multiplier(unit_stats.type_id, stats.type_id)
		var wanted: Array[int] = Looks.changes_of(stats, each)
		q.kit.need(problems, wanted == Looks.CHANGES[unit_stats.type_id], "the data change a Turret's look after Shots %s of %.1f, the story's %s" % [wanted, each, Looks.CHANGES[unit_stats.type_id]])
		var seen: PackedStringArray = []
		for shooter: int in Kit.PLAYERS:
			var rows: Array[Dictionary] = await _run(shooter, type_index)
			var label: String = "Player %d's %s" % [shooter + 1, unit_stats.type_id]
			var changes: Array[int] = [-1, -1, -1]
			for index: int in rows.size():
				var row: Dictionary = rows[index]
				var look: int = int(row["look"])
				q.kit.need(problems, look == Looks.predicted(float(row["hp"]), stats) and bool(row["dressed"]) and bool(row["head"]) == (look != -1), "%s, Shot %d: %.1f hit points, look %d (the data predict %d), dressed %s, head shown %s" % [label, index + 1, row["hp"], look, Looks.predicted(float(row["hp"]), stats), row["dressed"], row["head"]])
				var slot: int = 2 if look == -1 else look - 1
				changes[slot] = index + 1 if look != 0 and changes[slot] < 0 else changes[slot]
			q.kit.need(problems, changes == wanted, "%s: the look first changed after Shots %s, expected %s" % [label, changes, wanted])
			seen.append("%d Shots" % rows.size())
			if unit_stats.type_id == &"motorbike" and rows.size() == 20:
				q.kit.need(problems, is_equal_approx(float(rows[3]["hp"]), 0.8 * stats.max_hit_points) and int(rows[3]["look"]) == 0 and is_equal_approx(float(rows[12]["hp"]), 0.35 * stats.max_hit_points) and int(rows[12]["look"]) == 1, "the Motorbike's 4th and 13th Shots leave %.1f and %.1f hit points showing looks %d and %d, not 0 and 1" % [rows[3]["hp"], rows[12]["hp"], rows[3]["look"], rows[12]["look"]])
		result.append("%s:%s" % [unit_stats.type_id, "/".join(wanted.map(func(n: int) -> String: return str(n)))])
		measured.append("stages_%s=%s" % [unit_stats.type_id, "/".join(seen)])
	for hit: Dictionary in _hits:
		q.kit.need(problems, int(hit["look"]) == Looks.predicted(float(hit["hp"]), stats), "a hit_points_changed at %.1f hit points was emitted while the Turret showed look %d" % [hit["hp"], hit["look"]])
	var edges: Array[int] = await _edges(problems)
	var own: PackedStringArray = await _own_shots(problems)
	q.kit.verdict("stages", problems, "from behind the rock, by the real fire keys, each Player's four types brought the other Base's canyon-side Turret down and after every Shot the look shown was the data's prediction with the head and its steel and the band dressed to match (Shots that change the look [first, second, fall]: %s); all %d hit_points_changed carried the look their hit points call for; at exactly 80%%, just below, at exactly 35%%, just below and restored by apply_damage(): looks %s; own Shots: %s" % [", ".join(result), _hits.size(), edges, "; ".join(own)])


## One run of a Player's type to the fall: the rows of _hits it caused, in order. A coroutine.
func _run(shooter: int, type_index: int) -> Array[Dictionary]:
	var q: Quick = _k.w.s.q
	var target: Turret = _target_of(shooter)
	await _k.restore_all()
	var spot: Vector3 = Looks.CANYON_CAN if shooter == 1 else Quick.mirrored(Looks.CANYON_CAN)
	await _k.stage(shooter, type_index, spot, (target.global_position - spot).normalized())
	await q.kit.advance(_k.w.longest_cadence())
	var mark: int = _hits.size()
	q.harness.set_key(q.harness.fire_key(shooter), true)
	var waited: int = 0
	while target.is_standing and waited < FIRE_LIMIT_TICKS:
		await q.kit.tick()
		waited += 1
	q.harness.set_key(q.harness.fire_key(shooter), false)
	var rows: Array[Dictionary] = []
	for index: int in range(mark, _hits.size()):
		if _hits[index]["turret"] == target:
			rows.append(_hits[index])
	return rows


## The edges, on a Turret by apply_damage(): exactly at the first fraction (the whole look), just
## below it (the first damaged look), exactly at the second (the first), just below it (the second),
## then restore() (whole, the head in its own steel). Returns the five looks seen.
func _edges(problems: PackedStringArray) -> Array[int]:
	var q: Quick = _k.w.s.q
	var who: Turret = _k.turret(0, Kit13.LEFT)
	var top: float = who.stats.max_hit_points
	var team: Material = _k.w.bases[0].color_material
	q.kit.need(problems, top - Looks.TO_FIRST == Looks.DAMAGED_BELOW[0] * top and top - Looks.TO_SECOND == Looks.DAMAGED_BELOW[1] * top, "the edge test's inputs do not land exactly on the fractions (%.17f, %.17f)" % [top - Looks.TO_FIRST, top - Looks.TO_SECOND])
	var seen: Array[int] = []
	await _k.restore_all()
	who.apply_damage(Looks.TO_FIRST)
	seen.append(Looks.look_shown(who))
	who.apply_damage(Looks.JUST_BELOW)
	seen.append(Looks.look_shown(who))
	await _k.restore_all()
	who.apply_damage(Looks.TO_SECOND)
	seen.append(Looks.look_shown(who))
	who.apply_damage(Looks.JUST_BELOW)
	seen.append(Looks.look_shown(who))
	q.kit.need(problems, Looks.head_dressed(who, 2, team) and Looks.head_visible(who), "just below the second fraction the head is not in the second look's steel (%s)" % Looks.steel_of(who, 0))
	await _k.restore_all()
	seen.append(Looks.look_shown(who))
	q.kit.need(problems, seen == [0, 1, 1, 2, 0], "at exactly 80%%, just below, at exactly 35%%, just below and restored the looks were %s, expected [0, 1, 1, 2, 0]" % [seen])
	for each: Turret in _k.all():
		q.kit.need(problems, Looks.look_shown(each) == 0 and Looks.head_dressed(each, 0, _k.w.bases[each.player_index].color_material) and each.is_standing and Looks.head_visible(each), "%s shows look %d after restore() (steel %s)" % [each.name, Looks.look_shown(each), Looks.steel_of(each, 0)])
	return seen


## A Player's own Shots, with a hurt Turret of its Base in front of them: every Shot ends on that
## Turret and changes neither its hit points nor its look. Returns the notes.
func _own_shots(problems: PackedStringArray) -> PackedStringArray:
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	for owner_player: int in Kit.PLAYERS:
		await _k.restore_all()
		var own: Turret = _k.turret(owner_player, Kit13.RIGHT)
		own.apply_damage(OWN_TAKEN)
		var out: Vector3 = _k.w.way(owner_player, Vector3.FORWARD)
		await _k.stage(owner_player, Quick.MOTORBIKE, own.global_position + out * AHEAD, -out)
		await q.kit.advance(_k.w.longest_cadence())
		var mark: int = q.units.shots.size()
		var before: float = own.hit_points
		await q.units.hold_fire(owner_player, WATCH / 2)
		await q.kit.advance(Kit13.IN_FLIGHT_TICKS)
		var count: int = q.units.shot_ends.size() - mark
		var all_on: bool = count > 0
		for index: int in range(mark, q.units.shot_ends.size()):
			var end: Vector3 = q.units.shot_ends[index]
			all_on = all_on and Vector2(end.x - own.global_position.x, end.z - own.global_position.z).length() <= Kit13.RADIUS + 0.05
		q.kit.need(problems, all_on and own.hit_points == before and Looks.look_shown(own) == 1, "Player %d's own Shots: %d Shots, all ended on its Turret %s, %.1f hit points of %.1f, look %d (the first)" % [owner_player + 1, count, all_on, own.hit_points, before, Looks.look_shown(own)])
		notes.append("Player %d's %d Motorbike Shots ended on its own hurt Turret, which kept %.0f hit points and its first look" % [owner_player + 1, count, own.hit_points])
	await _k.restore_all()
	return notes


## The state of the four Turrets worth keeping: hit points, standing, the look and the steel.
func _snapshot() -> Array:
	var rows: Array = []
	for who: Turret in _k.all():
		rows.append([who.hit_points, who.is_standing, Looks.look_shown(who), Looks.steel_of(who, 0), Looks.head_visible(who)])
	return rows


## kept (AC-1): Base A's two Turrets fallen and Base B's two hurt to the second look; then each
## Player's Unit destroyed away from home and respawned and swapped to every type at its own Base,
## and the Round ended by Player 2 carrying Base A's Flag home through its broken Gate: nothing about
## the Turrets changes; then R brings every Turret back whole with its head at the rest heading.
func _kept() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var swaps: int = 0
	await _k.restore_all()
	for who: Turret in _k.all():
		if who.player_index == 0:
			who.destroy()
		else:
			who.apply_damage(who.stats.max_hit_points - HURT_TO)
		who.head.rotation.y = 0.5
	var before: Array = _snapshot()
	for player: int in Kit.PLAYERS:
		_k.w.s.flags.teleport(player, _k.w.point(player, AWAY), _k.w.way(player, Vector3.FORWARD))
		await q.kit.advance(Kit13.SETTLE)
		await q.tokens.destruct(player)
		q.kit.need(problems, not q.controller.is_alive(player), "Player %d's Unit away from home was not destroyed by its Self-destruct" % [player + 1])
		q.kit.need(problems, await q.tokens.spawn(player, Quick.MOTORBIKE), "Player %d did not respawn" % [player + 1])
		for type_index: int in q.controller.unit_types().size():
			await _k.w.s.enter(player)
			if await _k.w.s.wait_swappable(player) < 0:
				q.kit.need(problems, false, "Player %d's Unit at its own Base was never reported swappable" % [player + 1])
				continue
			await q.tokens.destruct(player)
			q.kit.need(problems, await q.tokens.spawn(player, type_index), "Player %d did not come back as type %d" % [player + 1, type_index])
			swaps += 1
	q.kit.need(problems, _snapshot() == before, "the Turrets changed through the destructions, respawns and Swaps: %s, before %s" % [_snapshot(), before])
	_k.w.wall(0, Walls.GATE).destroy()
	var taken: bool = await _k.w.take_flag(1, 0, Walls.GATE)
	var delivered: bool = await _k.w.deliver(1)
	q.kit.need(problems, taken and delivered and q.controller.is_round_over(), "the Flag was taken %s and delivered %s, Round over %s" % [taken, delivered, q.controller.is_round_over()])
	q.kit.need(problems, _snapshot() == before, "the Turrets changed by the Round's end: %s, before %s" % [_snapshot(), before])
	q.kit.need(problems, await q.tokens.restart(), "the restart key brought no new Round")
	await _k.w.s.both_play()
	for who: Turret in _k.all():
		var team: Material = _k.w.bases[who.player_index].color_material
		q.kit.need(problems, who.is_standing and who.hit_points == who.stats.max_hit_points and Looks.look_shown(who) == 0 and Looks.head_dressed(who, 0, team) and Looks.head_visible(who) and who.head.rotation == Vector3.ZERO, "after R %s stands %s with %.1f hit points, look %d, head %s at yaw %.3f" % [who.name, who.is_standing, who.hit_points, Looks.look_shown(who), Looks.head_visible(who), who.head.rotation.y])
	q.kit.verdict("kept", problems, "Base A's Turrets fallen and Base B's at %.0f hit points (the second look) kept their hit points, look, steel and head through each Player's destruction away from home, its respawn and %d Swaps (a Swap to each type for each Player) and through the Round's end (Player 2 carried Base A's Flag home); R brought all four back whole, each head at its rest heading in its own steel" % [HURT_TO, swaps])
