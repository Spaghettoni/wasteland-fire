extends RefCounted
## Scenario turret_reach_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frame of Story 049 AC-3 on Map 01 with the shipped data. Player 2's Truck stands straight
## ahead of Base A's right Turret, as far out as its own Shots reach the Turret's drum, facing it, and
## fires; the Turret answers. One moment, reach_answered, read when a Turret Shot is in flight toward
## the Truck. A SPLIT line with frame=, the number of the PNG that shows it in a --write-movie
## recording. A moment whose premise does not hold prints one failing CHECK named premise.
## Implements: production/epics/wasteland-fire/story-049-full-throttle-spin-turret-reach.md, Test
## Evidence. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     --write-movie shots/reach.png res://tools/evidence/split_screen_harness.tscn -- --scenario=turret_reach_showcase

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const FULL_THROTTLE: bool = true
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
const WATCHDOG_SECONDS: float = 120.0
const MOMENT_FRAME_LAG: int = 1
const HOLD_TICKS: int = 30
const LIMIT_TICKS: int = 300
## How far inside its own reach to the drum the Truck stands, metres (as turrets_fall.gd's check).
const MARGIN: float = 0.5
## A Turret Shot is read once it is this far from the Truck or nearer, metres: in the Truck's view.
const SHOT_NEAR: float = 14.0

var _k: Kit13
var _problems: PackedStringArray = []


func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	var q: Quick = _k.w.s.q
	await _k.w.s.both_play()
	await q.kit.advance(HOLD_TICKS)
	var turret: Turret = _k.turret(0, Kit13.RIGHT)
	var truck: UnitStats = q.units.stats(Quick.TRUCK)
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var apart: float = truck.weapon_range + truck.muzzle_forward + Kit13.RADIUS - MARGIN
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.TRUCK, _k.ahead(turret, 0, apart), -out)
	var unit: Unit = q.units.units[1]
	q.harness.set_key(q.harness.fire_key(1), true)
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await q.kit.tick()
		for index: int in range(mark, _k.firing.size()):
			var shot_value: Variant = _k.firing[index]["shot"]
			if read or not is_instance_valid(shot_value) or not (shot_value as Shot).is_inside_tree():
				continue
			var gap: float = (shot_value as Shot).global_position.distance_to(unit.global_position)
			if gap > SHOT_NEAR:
				continue
			var centre: float = turret.global_position.distance_to(unit.global_position)
			print("SPLIT %s t=%.3f frame=%d moment=reach_answered truck_from_turret=%.1f turret_reach=%.1f truck_reach=%.1f shot_from_truck=%.1f turret_hp=%.0f" % [
				q.harness.scenario, q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, centre,
				turret.stats.weapon_range + turret.stats.muzzle_forward, truck.weapon_range + truck.muzzle_forward + Kit13.RADIUS, gap, turret.hit_points])
			read = true
		if read:
			break
	q.harness.set_key(q.harness.fire_key(1), false)
	q.kit.need(_problems, read, "reach_answered: no Turret Shot came within %.0f m of the Truck" % SHOT_NEAR)
	await q.kit.advance(HOLD_TICKS)
	if not _problems.is_empty():
		q.kit.verdict("premise", _problems, "reach_answered")
	_k.close()
	harness.finish("shots=%d" % (_k.firing.size() - mark))
