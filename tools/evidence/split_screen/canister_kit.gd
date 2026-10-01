extends RefCounted
## What the Story 004 scenarios share: the record of the MatchController's Round and Water Canister
## signals with the runner's tick each arrived on, the Units, Bases, canisters and cameras of the
## launch scene, the moves (teleport, approach, a feathered drive until a reading holds, a rest),
## and the geometric test of a Unit's box against a Base zone's box: "entered" on the tick the Unit
## got there, while the physics server reports it about two ticks later (the Story 004 evidence
## doc). The one shared helper TD-006 allows, on check_kit.gd (ticks, verdicts); tooling only.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Player body materials each Base paints its canister with, in Player order (Story 002 data).
const PLAYER_MATERIALS: Array[String] = [
	"res://src/gameplay/split_screen/data/player_1_body_material.tres",
	"res://src/gameplay/split_screen/data/player_2_body_material.tres",
]
## Metres between a Unit's origin and the thing approach() puts it down to drive into.
const APPROACH_DISTANCE: float = 6.0
## Drive speed a feathered approach stays under, m/s: slow enough to come to rest on the thing.
const APPROACH_SPEED: float = 4.0
## Ticks drive_until() gives a drive before it gives up.
const DRIVE_LIMIT_TICKS: int = 900

## The runner.
var harness: Harness
## The shared check helpers.
var kit: Kit
## The controller under test.
var controller: MatchController
## The Units of the launch scene, by Player.
var units: Array[Unit] = []
## The Bases of the launch scene, by Player.
var bases: Array[Base] = []
## The canisters by owner: canister N is bases[N].canister (CONTEXT.md: the canister of Player N).
var canisters: Array[WaterCanister] = []
## The cameras of the launch scene, by Player.
var cameras: Array[ChaseCamera] = []
## Every canister_picked_up since the scenario connected: (carrier_index, canister_index, tick).
var pick_ups: Array[Vector3i] = []
## Every canister_dropped: (canister_index, tick).
var drops: Array[Vector2i] = []
## Every canister_seated: (canister_index, tick).
var seats: Array[Vector2i] = []
## Every round_over: (winner_index, tick).
var round_overs: Array[Vector2i] = []
## Every unit_spawned: (player_index, tick).
var spawns: Array[Vector2i] = []
## The Unit's global position at each unit_destroyed, in order: where the wreck lay.
var wrecks: Array[Vector3] = []
## round_started signals since the scenario connected; begin()'s came inside add_child(), earlier.
var round_started: int = 0
## get_tree().paused read inside the last round_over handler: the freeze comes before the signal.
var paused_at_signal: bool = false


func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	var split: SplitScreen = harness.split
	controller = split.match_controller
	units.assign([split.player_1_unit, split.player_2_unit])
	bases.assign([split.field.player_1_base, split.field.player_2_base])
	canisters.assign([bases[0].canister, bases[1].canister])
	cameras.assign([split.player_1_camera, split.player_2_camera])
	controller.canister_picked_up.connect(func(carrier: int, index: int) -> void: pick_ups.append(Vector3i(carrier, index, harness.ticks)))
	controller.canister_dropped.connect(func(index: int) -> void: drops.append(Vector2i(index, harness.ticks)))
	controller.canister_seated.connect(func(index: int) -> void: seats.append(Vector2i(index, harness.ticks)))
	controller.round_over.connect(_on_round_over)
	controller.round_started.connect(func() -> void: round_started += 1)
	controller.unit_spawned.connect(func(player: int) -> void: spawns.append(Vector2i(player, harness.ticks)))
	controller.unit_destroyed.connect(func(player: int) -> void: wrecks.append(units[player].global_position))


## Records a round_over with the runner's tick, and whether the tree was already paused.
func _on_round_over(winner: int) -> void:
	round_overs.append(Vector2i(winner, harness.ticks))
	paused_at_signal = harness.get_tree().paused


## The name of a canister's state (WaterCanister.State), for a detail line.
func state_name(canister_index: int) -> String:
	return String(WaterCanister.State.keys()[canisters[canister_index].state])


## The name of a Player's canister status (MatchController.CanisterStatus), for a detail line.
func status_name(player: int) -> String:
	return String(MatchController.CanisterStatus.keys()[controller.canister_status(player)])


## Whether the canister's zone reports the Player's Unit touching it, as the rules will read it.
func touching(canister_index: int, player: int) -> bool:
	return canisters[canister_index].is_touching(units[player])


## Puts a Unit down on the ground at a place facing a direction (runner place()); cargo rides along.
func teleport(player: int, at: Vector3, facing: Vector3) -> void:
	var heading: Basis = Basis(Vector3.UP, atan2(-facing.x, -facing.z))
	harness.place(units[player], Transform3D(heading, Vector3(at.x, 0.0, at.z)), cameras[player])


## Puts a Unit down APPROACH_DISTANCE from a thing, on the side `from` names, facing it.
func approach(player: int, thing: Vector3, from: Vector3) -> void:
	var away: Vector3 = Vector3(from.x, 0.0, from.z).normalized()
	teleport(player, thing + away * APPROACH_DISTANCE, -away)


## Drives a Unit forward (gear 1) or in reverse (gear -1; 0 holds no key, a wait) until done() holds
## after a tick, or DRIVE_LIMIT_TICKS passed; the key is feathered (pressed under cruise, let go at
## or above it, a real event per change). Every key is up when it returns; the ticks driven, or -1.
func drive_until(player: int, gear: int, cruise: float, done: Callable) -> int:
	for count: int in range(1, DRIVE_LIMIT_TICKS + 1):
		harness.drive(player, gear if absf(units[player].current_speed) < cruise else 0, 0)
		await kit.tick()
		if done.call():
			harness.drive(player, 0, 0)
			return count
	harness.drive(player, 0, 0)
	return -1


## Waits, keys up, until the Unit's drive speed is zero.
func rest(player: int) -> void:
	await drive_until(player, 0, 0.0, func() -> bool: return is_zero_approx(units[player].current_speed))


## Whether the Player's Unit box, where it stands now, meets the box of the given Base's zone:
## geometry from the two BoxShape3Ds and nothing from the physics server, so it says "entered" on
## the tick the Unit got there. The Unit's box is taken as the box around its corners in the zone's
## frame, so a turned Unit counts a hair early and never late. False when either shape is not a box.
func in_zone_box(player: int, base_index: int) -> bool:
	var unit_shape: CollisionShape3D = _shape_of(units[player])
	var zone_shape: CollisionShape3D = _shape_of(bases[base_index].zone)
	var unit_box: BoxShape3D = (unit_shape.shape as BoxShape3D) if unit_shape != null else null
	var zone_box: BoxShape3D = (zone_shape.shape as BoxShape3D) if zone_shape != null else null
	if unit_box == null or zone_box == null:
		return false
	var into_zone: Transform3D = zone_shape.global_transform.affine_inverse() * unit_shape.global_transform
	var half: Vector3 = unit_box.size / 2.0
	var bounds: AABB = AABB(into_zone * half, Vector3.ZERO)
	for corner: int in 8:
		var corner_sign: Vector3 = Vector3(1.0 if corner & 1 else -1.0, 1.0 if corner & 2 else -1.0, 1.0 if corner & 4 else -1.0)
		bounds = bounds.expand(into_zone * (half * corner_sign))
	return AABB(-zone_box.size / 2.0, zone_box.size).intersects(bounds)


func _shape_of(node: Node) -> CollisionShape3D:
	var shapes: Array[Node] = node.find_children("*", "CollisionShape3D", true, false)
	return (shapes[0] as CollisionShape3D) if not shapes.is_empty() else null
