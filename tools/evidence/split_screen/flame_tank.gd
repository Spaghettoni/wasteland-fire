extends RefCounted
## Scenario flame_tank of the split screen evidence harness (split_screen_harness.gd): Story 063, the Flame Tank (the Truck
## type), with the shipped data, in the turrets kit's arena (a flat floor far from the Map, its fixture Turret Player 2's).
##  F1 the reach: Player 1's Flame Tank flames for half a second at Player 2's Buggy standing with its back 1.5 m beyond
##     the flame's reach (muzzle_forward + flame_range ahead of the Tank's middle): the Buggy loses nothing; with its back 1 m
##     inside it, it loses hit points. The Tank never loses any of its own.
##  F2 the burn: a second of flame on the Buggy 8 m ahead, then the trigger let go: the Buggy keeps losing hit points for
##     burn_seconds, about burn_share of the flame's damage a second (times the matrix), then stops, and it has no fire left.
##  F3 a Structure burns: a second of flame on the fixture Turret 9 m ahead: it keeps losing hit points after the trigger
##     is let go, until it falls or its fire goes out.
##  F5 a Teammate burns (Martin, 2026-11-22): Player 2's Buggy made Player 1's Teammate (its player_index set to Player 1's Team
##     for the check) loses hit points to the flame and keeps burning after it.
##  F6 flat damage (Story 067; Martin, 2026-11-22: "nechcem aby niektore vozdidla uberali niektorym viac a niektorym menej ...
##     stale by mal byt rozny pocet hp"): every Unit type takes every other's damage at 1.0; the types' hit points still differ.
##  F7 the fire rides (Story 069; Martin, 2026-11-22: "chcel by som vidiet, ze vozidla horia, nevidno to teraz"): Player 2's
##     Buggy set on fire drives off at full throttle; after BURN_DRIVE ticks its flames are in the air around it (their middle
##     within RIDE_METRES of its drawn box's middle, across the ground), not strung out behind it, and its glow is lit.
##  F4 the load: a new Flame Tank (its Unit out of play and back) holds 250; a flame puff spends 1 and a rocket (high fire) high_ammo_cost.
## SPLIT moments for the frames in a windowed --write-movie run: flames (F3, the stream on the Turret), afterburn (F3,
## the Turret burning after the trigger is let go) and burn_rides (F7, the burning Buggy driving).
## Implements: production/epics/wasteland-fire/story-063-flame-tank.md AC-2 to AC-5. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=flame_tank

const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const CHASE_FIRST: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const FULL_THROTTLE: bool = true
const AMMO: bool = true
const HEIGHTS: bool = true
const FIRE_HEIGHTS: bool = true
const FLAME_TANK: bool = true
const FLAT_DAMAGE: bool = true
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
const WATCHDOG_SECONDS: float = 240.0
const MOMENT_FRAME_LAG: int = 1
## Where the Tank stands for F1 and F2, from the arena's centre: out of the fixture Turret's reach.
const FAR: Vector3 = Vector3(0.0, 0.0, 120.0)
const HALF_SECOND: int = 30
const SECOND: int = 60
const SETTLE: int = 10
const F2_GAP: float = 8.0
const F3_GAP: float = 9.0
## F2: how close the burn's damage after the trigger must come to burn_seconds * burn dps * matrix, hit points.
const BURN_TOLERANCE: float = 4.0
const BURNING_SCENE: String = "res://src/gameplay/combat/burning.tscn"
const BURN_DRIVE: int = 75
const RIDE_METRES: float = 1.5

var _k: Kit13
var _q: Quick


func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	_q = _k.w.s.q
	await _k.w.s.both_play()
	var turret: Turret = _k.make_arena(1)
	var tank: UnitStats = _q.units.stats(Quick.TRUCK)
	var buggy: UnitStats = _q.units.stats(Quick.BUGGY)
	var units: Array[Unit] = _q.units.units
	var facing: Vector3 = Vector3.FORWARD
	var base: Vector3 = Kit13.ARENA_CENTRE + FAR
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix

	# F1
	var problems: PackedStringArray = PackedStringArray()
	var reach: float = tank.muzzle_forward + tank.flame_range
	var half_buggy: float = buggy.collision_size.z / 2.0
	var lost: Array[float] = []
	for back: float in [reach + 1.5, reach - 1.0]:
		_q.units.retype(0, Quick.TRUCK, base, facing)
		_q.units.retype(1, Quick.BUGGY, base + facing * (back + half_buggy), facing)
		await _q.kit.advance(SETTLE)
		var before: float = units[1].hit_points
		var own: float = units[0].hit_points
		await _q.units.hold_fire(0, HALF_SECOND)
		await _q.kit.advance(SECOND)
		lost.append(before - units[1].hit_points)
		_q.kit.need(problems, is_equal_approx(units[0].hit_points, own), "the Tank lost %.1f of its own" % (own - units[0].hit_points))
	_q.kit.need(problems, lost[1] > 0.0, "the Buggy 1 m inside the reach lost nothing")
	_q.kit.need(problems, is_zero_approx(lost[0]), "the Buggy 1.5 m beyond the reach lost %.1f" % lost[0])
	_q.kit.verdict("F1_the_reach", problems, "reach %.1f m from the Tank's middle; the Buggy's back 1.5 m beyond it lost %.1f, 1 m inside it %.1f" % [reach, lost[0], lost[1]])
	await _q.kit.advance(int(tank.burn_seconds * 60.0) + SECOND)

	# F2
	problems = PackedStringArray()
	_q.units.retype(0, Quick.TRUCK, base, facing)
	_q.units.retype(1, Quick.BUGGY, base + facing * (tank.muzzle_forward + F2_GAP + half_buggy), facing)
	await _q.kit.advance(SETTLE)
	var start: float = units[1].hit_points
	await _q.units.hold_fire(0, SECOND)
	var at_release: float = units[1].hit_points
	var burning: bool = Burning.of(units[1]) != null
	await _q.kit.advance(int(tank.burn_seconds * 60.0) + HALF_SECOND)
	var after_burn: float = units[1].hit_points
	var gone: bool = Burning.of(units[1]) == null
	await _q.kit.advance(SECOND)
	var later: float = units[1].hit_points
	var multiplier: float = matrix.multiplier(tank.type_id, buggy.type_id)
	var burn_dps: float = tank.flame_damage / tank.flame_interval_seconds * tank.burn_share * multiplier
	var expected: float = burn_dps * tank.burn_seconds
	var burned: float = at_release - after_burn
	_q.kit.need(problems, burning, "the Buggy did not catch fire")
	_q.kit.need(problems, absf(burned - expected) <= BURN_TOLERANCE, "it burned %.1f after the trigger, %.1f expected" % [burned, expected])
	_q.kit.need(problems, gone and is_equal_approx(later, after_burn), "the fire did not go out (burning %s, lost %.1f more)" % [not gone, after_burn - later])
	_q.kit.verdict("F2_the_burn", problems, "a second of flame: %.1f lost; then %.1f in the %.0f s of fire (%.1f expected, %.2f a second times %.2f); out after it %s" % [
		start - at_release, burned, tank.burn_seconds, expected, burn_dps / multiplier, multiplier, gone])

	# F3
	problems = PackedStringArray()
	_q.units.retype(1, Quick.BUGGY, base + Vector3(30.0, 0.0, 0.0), facing)
	_q.units.retype(0, Quick.TRUCK, Kit13.ARENA_CENTRE + Vector3(0.0, 0.0, tank.muzzle_forward + F3_GAP + Kit13.RADIUS), facing)
	await _q.kit.advance(SETTLE)
	var turret_start: float = turret.hit_points
	_q.harness.set_key(_q.harness.fire_key(0), true)
	await _q.kit.advance(HALF_SECOND)
	print("SPLIT %s t=%.3f frame=%d moment=flames turret_hp=%.1f" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, turret.hit_points])
	await _q.kit.advance(HALF_SECOND)
	_q.harness.set_key(_q.harness.fire_key(0), false)
	var turret_release: float = turret.hit_points
	var turret_burning: bool = Burning.of(turret) != null
	await _q.kit.advance(SECOND)
	print("SPLIT %s t=%.3f frame=%d moment=afterburn turret_hp=%.1f" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, turret.hit_points])
	await _q.kit.advance(int(tank.burn_seconds * 60.0))
	var turret_end: float = turret.hit_points
	_q.kit.need(problems, turret_burning, "the Turret did not catch fire")
	_q.kit.need(problems, turret_end < turret_release, "the Turret lost nothing after the trigger")
	_q.kit.need(problems, Burning.of(turret) == null, "the Turret still burns")
	_q.kit.verdict("F3_a_structure_burns", problems, "the Turret %.1f at the start, %.1f when the trigger was let go, %.1f after its fire (standing %s)" % [
		turret_start, turret_release, turret_end, turret.is_standing])
	# F5
	problems = PackedStringArray()
	var team: int = units[1].player_index
	units[1].player_index = units[0].player_index
	_q.units.retype(0, Quick.TRUCK, base, facing)
	_q.units.retype(1, Quick.BUGGY, base + facing * (tank.muzzle_forward + F2_GAP + half_buggy), facing)
	await _q.kit.advance(SETTLE)
	var mate_start: float = units[1].hit_points
	await _q.units.hold_fire(0, HALF_SECOND)
	var mate_release: float = units[1].hit_points
	var mate_burning: bool = Burning.of(units[1]) != null
	await _q.kit.advance(SECOND)
	var mate_after: float = units[1].hit_points
	units[1].player_index = team
	_q.kit.need(problems, mate_start > mate_release, "the Teammate's Buggy lost nothing to the flame")
	_q.kit.need(problems, mate_burning and mate_after < mate_release, "the Teammate's Buggy did not keep burning (on fire %s, lost %.1f after)" % [mate_burning, mate_release - mate_after])
	_q.kit.verdict("F5_a_teammate_burns", problems, "Player 2's Buggy on Player 1's Team: %.1f -> %.1f under half a second of flame, on fire %s, %.1f a second later" % [mate_start, mate_release, mate_burning, mate_after])
	await _q.kit.advance(int(tank.burn_seconds * 60.0))

	# F7
	problems = PackedStringArray()
	_q.units.retype(0, Quick.TRUCK, base + Vector3(-30.0, 0.0, 0.0), facing)
	_q.units.retype(1, Quick.BUGGY, base, facing)
	await _q.kit.advance(SETTLE)
	var fire: Burning = Burning.ignite(units[1], load(BURNING_SCENE) as PackedScene, 0.1, tank.burn_seconds)
	var throttle: Key = _key_of(&"p2_throttle")
	_q.harness.set_key(throttle, true)
	await _q.kit.advance(BURN_DRIVE)
	var middle: Vector3 = _flames_middle(fire)
	var buggy_at: Vector3 = fire.global_transform * fire._box.get_center()
	var off_ground: float = Vector2(middle.x - buggy_at.x, middle.z - buggy_at.z).length()
	var speed: float = units[1].current_speed
	print("SPLIT %s t=%.3f frame=%d moment=burn_rides speed=%.1f" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, speed])
	await _q.kit.advance(HALF_SECOND)
	_q.harness.set_key(throttle, false)
	var lit: bool = fire != null and fire.glow != null and fire.glow.visible and fire.glow.light_energy > 0.0
	_q.kit.need(problems, speed > 5.0, "the Buggy drove at only %.1f m/s" % speed)
	_q.kit.need(problems, off_ground <= RIDE_METRES, "the flames' middle %.2f m from the Buggy across the ground" % off_ground)
	_q.kit.need(problems, lit, "the glow is not lit")
	_q.kit.verdict("F7_the_fire_rides", problems, "the burning Buggy at %.1f m/s: its flames' middle %.2f m from its middle across the ground, %.2f m above it; glow lit %s" % [
		speed, off_ground, middle.y - buggy_at.y, lit])
	await _q.kit.advance(int(tank.burn_seconds * 60.0))

	_k.free_arena()

	# F4
	problems = PackedStringArray()
	var weapon: Weapon = _q.harness.split.all_weapons()[0]
	units[0].leave_play()
	await _q.kit.advance(2)
	_q.units.retype(0, Quick.TRUCK, base, facing)
	_q.units.retype(1, Quick.BUGGY, base + Vector3(30.0, 0.0, 0.0), facing)
	await _q.kit.advance(SETTLE)
	var full: int = weapon.shots_left
	await _q.units.hold_fire(0, 1)
	await _q.kit.advance(SECOND)
	var after_puff: int = weapon.shots_left
	_shift(true)
	await _q.kit.advance(2)
	_shift(false)
	await _q.kit.advance(SECOND)
	var after_rocket: int = weapon.shots_left
	_q.kit.need(problems, full == tank.ammo_capacity and weapon.capacity == tank.ammo_capacity, "the load %d of %d" % [full, weapon.capacity])
	_q.kit.need(problems, full - after_puff == 1, "a puff spent %d" % (full - after_puff))
	_q.kit.need(problems, after_puff - after_rocket == tank.high_ammo_cost, "a rocket spent %d" % (after_puff - after_rocket))
	_q.kit.verdict("F4_the_load", problems, "a new Flame Tank %d of %d; after a puff %d; after a rocket %d (cost %d)" % [full, weapon.capacity, after_puff, after_rocket, tank.high_ammo_cost])


	# F6
	problems = PackedStringArray()
	var types: Array[StringName] = []
	var points: Array[float] = []
	for kind: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK, Quick.GYROCOPTER]:
		types.append(_q.units.stats(kind).type_id)
		points.append(_q.units.stats(kind).max_hit_points)
	var off: PackedStringArray = PackedStringArray()
	for shooter: StringName in types:
		for target: StringName in types:
			if not is_equal_approx(matrix.multiplier(shooter, target), 1.0):
				off.append("%s>%s %.2f" % [shooter, target, matrix.multiplier(shooter, target)])
	var distinct: Dictionary = {}
	for value: float in points:
		distinct[value] = true
	_q.kit.need(problems, off.is_empty(), "multipliers between Unit types not 1: %s" % [off])
	_q.kit.need(problems, distinct.size() > 1, "every type has the same hit points %s" % [points])
	_q.kit.verdict("F6_flat_damage", problems, "every Unit type against every Unit type 1.0 (the matrix's other entries %s); hit points still differ by type %s" % [matrix.multipliers.keys(), points])
	_k.close()
	harness.finish("flame=%.1fm burn=%.0fs" % [tank.flame_range, tank.burn_seconds])


## The middle of the fire's living flames (world), or the Burning's own position when none lives.
func _flames_middle(fire: Burning) -> Vector3:
	if fire == null or fire.flames == null:
		return Vector3.INF
	var fx: FxParticles = fire.flames
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for i: int in fx.max_particles:
		if fx._age[i] < fx._life[i]:
			sum += fx._pos[i]
			count += 1
	return sum / float(count) if count > 0 else fire.global_position


func _key_of(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode
	return KEY_NONE


## A real Left Shift key event: Player 1's high fire.
func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
