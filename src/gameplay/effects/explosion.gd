class_name Explosion
extends Node3D
## The picture a destroyed Unit leaves behind it: a short flash, a fireball that swells and then shrinks
## and darkens, a few dark chunks thrown up and out that fall back, and some grey smoke that rises, grows
## and fades, for about two seconds, and then the node frees itself.
##
## Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-3 (a picture only, frees
## itself about 2 s after it began), AC-4 (centred on the Unit as it was drawn and staying there), AC-5
## (the look, drawn in both views), AC-7 (it keeps playing under the Round-over screen) and AC-9 (every
## value is data: ExplosionSettings); design/rules.md "Destruction and respawn" and "Teams and visual
## style". Vocabulary: CONTEXT.md (Unit, Round).
##
## A picture only. Nothing under this node is a physics body, an Area3D or on a collision layer, so it
## damages, pushes and stops nothing: a Unit drives through it, a Shot flies through it and a Flag
## dropped in it can be picked up. It owns nothing of the Round and never calls it: SplitScreen
## instances it when the MatchController announces a destruction it counted (unit_destroyed), adds it
## under World, where the Units are, and calls blast() in that same call, from inside another node's
## tick. It belongs to the node group "explosions" (the scene stores it), which SplitScreen frees at
## every restart.
##
## The scene (explosion.tscn), the origin at the centre of the blast, no node above it moves it:
##   Explosion (this Node3D): process mode ALWAYS, settings data/explosion_settings.tres
##     Flash (MeshInstance3D): an unshaded ball of unit radius, scaled to flash_radius_factor
##     Fireball (MeshInstance3D): an unshaded ball of unit radius, scaled and coloured every tick
##     Debris/Chunk (MeshInstance3D): a unit cube; _ready() makes one copy per chunk_directions entry
##       and frees this template
##     Smoke/Puff (MeshInstance3D): a unit ball in an alpha material; _ready() makes one copy per
##       smoke_offsets entry and frees this template
## Every piece has its shadow off and sits on render layer 1, which both cameras draw (the view from
## above hides layer 2 alone). The meshes are built-in shapes shared by every explosion, and so are the
## materials of the flash, the chunks and the puffs, whose colour never changes after _ready() writes
## the data's into them (the same value every time); the fireball's material is local to the scene, so
## each explosion has its own and its colour can change every tick without touching another
## explosion's. A shared material lives as long as the PackedScene that holds it, so its shader is never
## freed and made again between two explosions: with all four local to the scene the first explosion
## after a gap took 4 to 10 ms to instantiate against 0.3 to 1 ms for the next, and sharing three took
## about 1 ms more off the frame in which three are made at once (measured windowed on 4.7.2; the Story
## 016 evidence doc keeps the runs). The smoke fades with GeometryInstance3D.transparency, which
## multiplies the material's alpha and needs the Forward+ or Mobile renderer (the project's is
## Forward+). Every colour is a setting. None of them is a Team colour: an explosion looks the same
## whoever's Unit it was.
##
## Time is counted in this node's own physics ticks, a counter its _physics_process raises, never in
## Engine.get_physics_frames(), which keeps counting under the Round-over pause. Each duration is a
## setting in seconds rounded to ticks, never under one tick. blast() poses the pieces as they are at
## tick 0 and the first _physics_process is the one after the node entered the tree (measured on 4.7.2;
## the Story 016 evidence doc keeps the run), so the node frees itself lifetime ticks after the tick it
## was added in.
##
## The Round-over pause (AC-7). The tree pauses at the end of the tick that ends the Round, in the
## frame of the deciding destruction, and a pausable node stops with it. This node's process mode is
## ALWAYS, as RoundRestartInput's is, so its ticks go on and the explosion plays out under the screen
## (measured on 4.7.2: an ALWAYS node's _physics_process runs on every physics frame of the pause and its
## pieces are drawn interpolated at 120 fps; the Story 016 evidence doc keeps the run). It destroys
## nothing, so the order the loss relies on stands (MatchController). The same process mode keeps it
## playing under any other pause too: a pause menu added later has to decide whether explosions stop.
##
## Physics interpolation. World draws its children interpolated, and the pieces move in this node's own
## tick, so a piece is drawn between its last two poses. blast() poses every piece and resets the
## interpolation in the tick the node enters the tree, so the first drawn frame is at the place of the
## blast; a puff that begins later is reset in the tick it begins. The chunks fly on fixed arcs, the
## fireball and the puffs change their scale every tick, and none of it draws a streak (measured
## windowed at 120 fps).
##
## Determinism. Nothing is random: the directions, speeds and sizes of the chunks, the offsets of the
## puffs, every duration and every colour come from ExplosionSettings, so every run is the same.

## The shared tuning values (ExplosionSettings): explosion.tscn sets data/explosion_settings.tres, which
## every Explosion shares, so it is read-only at runtime. An Explosion whose settings fail
## first_problem() pushes one error in _ready() and frees itself when blast() is called.
@export var settings: ExplosionSettings

## The flash, hidden until blast().
@export var flash: MeshInstance3D

## The fireball, hidden until blast().
@export var fireball: MeshInstance3D

## The template of one chunk of debris: _ready() makes the copies, frees it and clears this reference.
@export var chunk_template: MeshInstance3D

## The template of one puff of smoke: _ready() makes the copies, frees it and clears this reference.
@export var puff_template: MeshInstance3D

var _valid: bool = false
## True after blast(): an Explosion nobody blasted does nothing.
var _live: bool = false
## This node's own ticks since blast().
var _ticks: int = 0
var _ticks_per_second: int = 1
var _life_ticks: int = 1
var _flash_ticks: int = 1
var _fireball_ticks: int = 1
var _smoke_start_ticks: int = 0
var _smoke_end_ticks: int = 0
var _stagger_ticks: int = 0
## The size of the destroyed type and the height of the floor it stood on, from blast().
var _size: float = 0.0
var _floor_y: float = 0.0
var _chunks: Array[MeshInstance3D] = []
var _puffs: Array[MeshInstance3D] = []
var _fireball_material: StandardMaterial3D


func _ready() -> void:
	set_physics_process(false)
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("Explosion '%s': %s, so it plays nothing." % [name, problem])
		return
	_ticks_per_second = Engine.physics_ticks_per_second
	_life_ticks = _in_ticks(settings.lifetime_seconds)
	_flash_ticks = _in_ticks(settings.flash_seconds)
	_fireball_ticks = _in_ticks(settings.fireball_seconds)
	_smoke_start_ticks = _in_ticks(settings.smoke_start_seconds) if settings.smoke_start_seconds > 0.0 else 0
	_smoke_end_ticks = _smoke_start_ticks + _in_ticks(settings.smoke_seconds) if settings.smoke_seconds > 0.0 else 0
	_stagger_ticks = _in_ticks(settings.smoke_stagger_seconds) if settings.smoke_stagger_seconds > 0.0 else 0
	_fireball_material = fireball.material_override as StandardMaterial3D
	(flash.material_override as StandardMaterial3D).albedo_color = settings.flash_colour
	(chunk_template.material_override as StandardMaterial3D).albedo_color = settings.chunk_colour
	(puff_template.material_override as StandardMaterial3D).albedo_color = settings.smoke_colour
	_chunks = _copies_of(chunk_template, settings.chunk_directions.size())
	_puffs = _copies_of(puff_template, settings.smoke_offsets.size())
	chunk_template = null
	puff_template = null
	_valid = true


func _physics_process(_delta: float) -> void:
	if not _live:
		return
	_ticks += 1
	if _ticks >= _life_ticks:
		queue_free()
		return
	_pose(_ticks)


## Puts the explosion at a place and starts it, in the tick it entered the tree: `at` is the centre of
## the blast in world space, `size` the length every piece is a share of (the larger horizontal side of
## the destroyed type's box) and `floor_y` the world height of the floor the Unit stood on, where the
## chunks stop (the Unit's own origin: a Gyrocopter shot down over cover has its chunks fall past the
## piece to the ground). Poses every piece at tick 0 and resets the physics interpolation, so the first drawn
## frame is at `at`. A size not above zero, or settings that failed in _ready(), play nothing: the
## node frees itself.
func blast(at: Vector3, size: float, floor_y: float) -> void:
	if not _valid or not (size > 0.0):
		if _valid:
			push_error("Explosion '%s': blast() was given a size that is not above zero, so it plays nothing." % name)
		queue_free()
		return
	_size = size
	_floor_y = floor_y
	global_position = at
	_ticks = 0
	_live = true
	_pose(0)
	reset_physics_interpolation()
	set_physics_process(true)


## The ticks this explosion has counted since blast(): 0 until the first of its own ticks. They go on
## under the Round-over pause (process mode ALWAYS).
func ticks_played() -> int:
	return _ticks


## The ticks from the tick it was added in to the tick it frees itself in, from the settings (0 when the
## settings failed).
func lifetime_ticks() -> int:
	return _life_ticks if _valid else 0


## Poses every piece as it is `tick` ticks after the blast.
func _pose(tick: int) -> void:
	_pose_flash(tick)
	_pose_fireball(tick)
	_pose_chunks(float(tick) / float(_ticks_per_second))
	_pose_smoke(tick)


func _pose_flash(tick: int) -> void:
	flash.visible = tick < _flash_ticks
	flash.scale = Vector3.ONE * settings.flash_radius_factor * _size


## The fireball swells from its start scale to its full radius over the swell share of its time, then
## shrinks to its end scale and darkens from the start colour to the end colour over the rest.
func _pose_fireball(tick: int) -> void:
	fireball.visible = tick < _fireball_ticks
	if not fireball.visible:
		return
	var progress: float = float(tick) / float(_fireball_ticks)
	var swell: float = settings.fireball_swell_fraction
	var share: float = lerpf(settings.fireball_start_scale, 1.0, progress / swell)
	var shrink: float = 0.0
	if progress >= swell:
		shrink = (progress - swell) / (1.0 - swell)
		share = lerpf(1.0, settings.fireball_end_scale, shrink)
	fireball.scale = Vector3.ONE * share * settings.fireball_radius_factor * _size
	_fireball_material.albedo_color = settings.fireball_colour_start.lerp(settings.fireball_colour_end, shrink)


## Each chunk on its fixed arc: thrown along its direction at its speed, falling under the gravity, and
## hidden for good once its middle is down to the floor the Unit stood on.
func _pose_chunks(age: float) -> void:
	for index: int in _chunks.size():
		var chunk: MeshInstance3D = _chunks[index]
		var thrown: Vector3 = settings.chunk_directions[index].normalized() * settings.chunk_speeds[index] * age
		var offset: Vector3 = thrown + Vector3.DOWN * settings.chunk_gravity * age * age / 2.0
		var edge: float = settings.chunk_size_factors[index] * _size
		chunk.scale = Vector3.ONE * edge
		chunk.visible = not (age > 0.0 and global_position.y + offset.y - edge / 2.0 <= _floor_y)
		chunk.position = offset


## Each puff from the tick it begins: rising, growing and fading until the smoke ends. A puff that
## has not begun is hidden; one that begins this tick has its interpolation reset.
func _pose_smoke(tick: int) -> void:
	for index: int in _puffs.size():
		var puff: MeshInstance3D = _puffs[index]
		var begin: int = _smoke_start_ticks + index * _stagger_ticks
		if tick < begin:
			puff.visible = false
			continue
		var span: int = maxi(_smoke_end_ticks - begin, 1)
		var progress: float = clampf(float(tick - begin) / float(span), 0.0, 1.0)
		var age: float = float(tick - begin) / float(_ticks_per_second)
		puff.position = settings.smoke_offsets[index] * _size + Vector3.UP * settings.smoke_rise_speed * age
		puff.scale = Vector3.ONE * settings.smoke_radius_factor * _size * lerpf(1.0, settings.smoke_growth, progress)
		puff.transparency = progress
		puff.visible = true
		if tick == begin:
			puff.reset_physics_interpolation()


## Seconds as physics ticks, rounded and never under one.
func _in_ticks(seconds: float) -> int:
	return maxi(roundi(seconds * _ticks_per_second), 1)


## `count` copies of a template, added beside it; the template itself is then freed (a copy shares the
## template's mesh and material, so every chunk of this explosion shares one material).
func _copies_of(template: MeshInstance3D, count: int) -> Array[MeshInstance3D]:
	var copies: Array[MeshInstance3D] = []
	var holder: Node = template.get_parent()
	for index: int in count:
		var copy: MeshInstance3D = template.duplicate() as MeshInstance3D
		copy.name = "%s%d" % [template.name, index]
		holder.add_child(copy)
		copies.append(copy)
	holder.remove_child(template)
	template.free()
	return copies


## What is wrong with the exports and the settings, as a sentence, or an empty string.
func _first_problem() -> String:
	if settings == null:
		return "settings is not assigned"
	if flash == null or fireball == null or chunk_template == null or puff_template == null:
		return "flash, fireball, chunk_template and puff_template must all be assigned"
	if not (flash.material_override is StandardMaterial3D) or not (fireball.material_override is StandardMaterial3D):
		return "flash and fireball need a StandardMaterial3D as their material_override"
	if not (chunk_template.material_override is StandardMaterial3D) or not (puff_template.material_override is StandardMaterial3D):
		return "the chunk and puff templates need a StandardMaterial3D as their material_override"
	return settings.first_problem()
