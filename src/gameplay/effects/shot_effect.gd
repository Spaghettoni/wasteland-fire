class_name ShotEffect
extends Node3D
## The picture of a Shot leaving a muzzle or ending on something: a flash, sparks or chunks, a puff
## of smoke or dust, and on a wall or a piece of cover a dark scorch that fades. One scene of this
## script is the muzzle flash (muzzle_flash.tscn), another the impact (impact.tscn); Shot instances
## them (Shot.muzzle_scene, Shot.impact_scene), adds them to its own parent, where the Units are, and
## calls play() in that same call.
##
## A picture only: nothing here is a body or on a collision layer, so it damages, pushes and stops
## nothing. It belongs to the node group "explosions", which SplitScreen frees at every restart, and
## frees itself once every particle has died and the scorch has faded.
##
## The scene's children are FxParticles pools, each named for its role, and an optional Decal named
## Scorch; which of them play depends on what was hit (play()'s `metal`). Every look is data of the
## scene: the pools' exports and the amounts and speeds below.

## Pools that play on every hit: the flash and the smoke or dust.
@export var flash: FxParticles
@export var smoke: FxParticles
## Played when the Shot ended on a Unit or a Structure (metal): bright sparks.
@export var sparks: FxParticles
## Played when the Shot ended on anything else (rock, sand, a wall of the Map): chunks of it.
@export var chunks: FxParticles
## A dark mark left on what was hit when it was not a Unit; null for none.
@export var scorch: Decal

@export_group("Amounts")
## Flash puffs and how far apart along the direction, metres (a muzzle's flame is a short row).
@export var flash_count: int = 1
@export var flash_step: float = 0.0
@export var smoke_count: int = 6
@export var smoke_speed_min: float = 0.5
@export var smoke_speed_max: float = 2.0
@export var smoke_spread: float = 60.0
@export var spark_count: int = 10
@export var spark_speed_min: float = 4.0
@export var spark_speed_max: float = 10.0
@export var spark_spread: float = 70.0
@export var chunk_count: int = 6
@export var chunk_speed_min: float = 2.0
@export var chunk_speed_max: float = 5.0
@export var chunk_spread: float = 50.0
## Seconds the scorch stays fully dark, then fades over scorch_fade.
@export var scorch_hold: float = 8.0
@export var scorch_fade: float = 4.0

var _scorch_age: float = 0.0
var _scorch_alpha: float = 1.0
var _playing: bool = false


func _ready() -> void:
	if scorch != null:
		scorch.visible = false


## Plays the effect at `at` (world) facing `direction`: for a muzzle the direction of fire, for an
## impact the surface's normal (or back along the flight where there is none). `metal` picks sparks
## (a Unit or a Structure) or chunks and a scorch (anything else). `size` scales every distance and
## amount (a rocket's impact is bigger than a bullet's).
func play(at: Vector3, direction: Vector3, metal: bool, size: float = 1.0) -> void:
	var dir: Vector3 = direction.normalized() if direction.length_squared() > 0.0 else Vector3.UP
	global_position = at
	# Each place draws its own pattern, the same every run (the seed comes from where it is).
	var place: int = hash(Vector3i(roundi(at.x * 10.0), roundi(at.y * 10.0), roundi(at.z * 10.0)))
	for pool: FxParticles in [flash, smoke, sparks, chunks]:
		if pool != null:
			pool.rng().seed = place ^ pool.seed_value
	if flash != null:
		for k: int in flash_count:
			flash.emit(at + dir * flash_step * size * float(k), dir * 0.5)
	if smoke != null:
		smoke.burst(at, roundi(smoke_count * size), dir, smoke_spread, smoke_speed_min * size,
				smoke_speed_max * size, 0.1 * size)
	if metal and sparks != null:
		sparks.burst(at, roundi(spark_count * size), dir, spark_spread, spark_speed_min,
				spark_speed_max * size)
	if not metal and chunks != null:
		chunks.burst(at, roundi(chunk_count * size), dir, chunk_spread, chunk_speed_min,
				chunk_speed_max * size)
	if not metal and scorch != null:
		scorch.visible = true
		scorch.size = Vector3(scorch.size.x * size, scorch.size.y, scorch.size.z * size)
		# A Decal projects along its own -Y: lay +Y along the surface's normal.
		var up: Vector3 = dir
		var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		scorch.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(),
				at + up * 0.05)
	elif scorch != null:
		scorch.queue_free()
		scorch = null
	for pool: FxParticles in [flash, smoke, sparks, chunks]:
		if pool != null:
			pool.finish()
	_playing = true


func _process(delta: float) -> void:
	if not _playing:
		return
	if scorch != null:
		_scorch_age += delta
		var fade: float = clampf((_scorch_age - scorch_hold) / maxf(scorch_fade, 0.01), 0.0, 1.0)
		scorch.modulate.a = 1.0 - fade
		if fade >= 1.0:
			scorch.queue_free()
			scorch = null
	var left: int = 0
	for child: Node in get_children():
		if not child.is_queued_for_deletion():
			left += 1
	if left == 0:
		queue_free()
