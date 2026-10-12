class_name BadlyDamagedSmoke
extends Node3D
## The smoke a badly damaged Unit gives off: small dark grey puffs that begin at the top of the
## Unit's drawn body, rise, grow a little and fade, and are left behind where they began, so a Unit
## that moves trails a short line of them and one that stands has a column.
##
## Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-4 (thin dark grey
## smoke from the drawn body, in both views, from the tick the state begins to the tick it ends,
## with no Team colour and no shadow) and AC-7 (its look is data of this scene); design/rules.md
## "Units" and "Teams and visual style". Vocabulary: CONTEXT.md (Unit).
##
## A picture only. Nothing under this node is a physics body or on a collision layer, so it damages,
## pushes and stops nothing. It is a child of the Unit's Model (UnitModel instances it on the first
## tick of a state, at the top centre of the Model's hull, and shows or hides it from the Unit's
## badly_damaged_changed), so its origin follows the drawn body, a Gyrocopter's hover and rise
## included, and a Unit that is out of play hides it with the Model.
##
## The scene (badly_damaged_smoke.tscn), built as the smoke of the Explosion (explosion.tscn) is, so
## the two read as one smoke:
##   BadlyDamagedSmoke (this Node3D): the look below, as exports
##     Puff (MeshInstance3D): a unit quad that always faces the camera (a billboard) in an unshaded
##       alpha grey material whose texture is a radial gradient, so a puff is a soft round blot
##       that reads the same from above and from behind; hidden, on render layer 1 (both views
##       draw it; the view from above hides layer 2 alone), with its shadow off, and top_level, so
##       that a puff stays where it was put in the world while its parent moves. _ready() makes one
##       copy per puff of the pool and frees this template.
## The colour is the material's, its alpha is how thick a puff is at its heart when it begins and it
## fades to nothing; none of it is a Team colour. A copy shares the template's mesh and material, so
## the pool shares one material (the renderer draws the puffs of one smoke in one call) and a puff
## fades with GeometryInstance3D.transparency (Forward+ and Mobile). The first look, a ball in the
## explosion's flat grey (explosion.tscn), drew a trail as a row of hard-edged discs; the soft quad
## was chosen from frames of both (the Story 017 evidence).
##
## Time is counted in this node's own physics ticks, never in Engine.get_physics_frames(), so the
## smoke stops with the scene when the tree pauses. A puff is born every interval ticks (the amount
## a second, rounded to ticks and never under one tick), lives for the lifetime in ticks and is then
## hidden; a pool of lifetime / interval puffs, rounded up, is enough because a puff is only reused
## after it has ended. Nothing is random: the same run draws the same smoke.
##
## Physics interpolation. A puff moves in this node's physics tick, so it is drawn between its last
## two poses; the one born this tick has its interpolation reset, so its first drawn frame is at the
## place it was born.

## The template of one puff (the Puff node of the scene): _ready() makes the copies, frees it and
## clears this reference. Required.
@export var puff_template: MeshInstance3D

@export_group("Look")
## Puffs born a second while the state lasts, rounded to a whole number of physics ticks apart. Zero
## by default, so every number lives in the scene; required above zero.
@export_range(0.0, 60.0, 0.5, "suffix:1/s") var puffs_per_second: float = 0.0
## Seconds a puff lives, from its birth to the tick it is hidden. Required above zero.
@export_range(0.0, 10.0, 0.05, "suffix:s") var puff_lifetime_seconds: float = 0.0
## Metres a second a puff rises. Not below zero.
@export_range(0.0, 10.0, 0.05, "suffix:m/s") var rise_speed: float = 0.0
## Radius of a puff when it is born, metres: the same for every Unit type. Required above zero.
@export_range(0.0, 2.0, 0.01, "suffix:m") var puff_radius: float = 0.0
## How many times larger a puff is when it ends than when it was born. Required above zero.
@export_range(0.0, 10.0, 0.05) var puff_growth: float = 0.0
## The share of its life a puff keeps its full opacity before it fades to nothing: 0 fades it from
## the first tick, 0.5 from the middle of its life. From 0 to under 1.
@export_range(0.0, 0.99, 0.01) var fade_start_fraction: float = 0.0

var _valid: bool = false
var _smoking: bool = false
## This node's own ticks since start().
var _ticks: int = 0
var _ticks_per_second: int = 1
var _life_ticks: int = 1
var _interval_ticks: int = 1
## The pool, the tick each puff was born in (-1 while it is not showing) and where it was born.
var _puffs: Array[MeshInstance3D] = []
var _born: PackedInt32Array = PackedInt32Array()
var _origins: PackedVector3Array = PackedVector3Array()
## The next puff of the pool to be born.
var _next: int = 0


func _ready() -> void:
	set_physics_process(false)
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("BadlyDamagedSmoke '%s': %s, so it shows no smoke." % [name, problem])
		return
	_ticks_per_second = Engine.physics_ticks_per_second
	_life_ticks = _in_ticks(puff_lifetime_seconds)
	_interval_ticks = _in_ticks(1.0 / puffs_per_second)
	var count: int = ceili(float(_life_ticks) / float(_interval_ticks))
	_puffs = _copies_of(puff_template, count)
	_born.resize(count)
	_born.fill(-1)
	_origins.resize(count)
	puff_template = null
	_valid = true


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if _ticks % _interval_ticks == 0:
		_emit()
	_pose_all()


## Starts the smoke in the tick the state begins: every puff is cleared, the first is born at once,
## at this node's place in the world, and the node ticks from now on. Does nothing while it is
## already smoking, or when the look failed in _ready(). Call it from a tick.
func start() -> void:
	if not _valid or _smoking:
		return
	_smoking = true
	_ticks = 0
	_next = 0
	_clear()
	set_physics_process(true)
	_emit()


## Ends the smoke in the tick the state ends: the node stops ticking and every puff is hidden at
## once, the ones left behind in the world included. Does nothing while it is not smoking.
func stop() -> void:
	if not _smoking:
		return
	_smoking = false
	set_physics_process(false)
	_clear()


## True from start() until stop().
func is_smoking() -> bool:
	return _smoking


## The puffs of the pool, in the order they are born in (empty when the look failed): for a reader
## of what is drawn.
func puffs() -> Array[MeshInstance3D]:
	return _puffs


## How many puffs show now.
func shown_count() -> int:
	var shown: int = 0
	for puff: MeshInstance3D in _puffs:
		shown += 1 if puff.visible else 0
	return shown


## The ticks a puff lives, and the ticks between two births, from the look (0 while it failed).
func life_ticks() -> int:
	return _life_ticks if _valid else 0


func interval_ticks() -> int:
	return _interval_ticks if _valid else 0


## Hides every puff and forgets its birth.
func _clear() -> void:
	for index: int in _puffs.size():
		_puffs[index].visible = false
		_born[index] = -1


## Births the next puff of the pool at this node's place in the world.
func _emit() -> void:
	var index: int = _next
	_next = (_next + 1) % _puffs.size()
	_born[index] = _ticks
	_origins[index] = global_position
	var puff: MeshInstance3D = _puffs[index]
	puff.global_position = global_position
	puff.scale = Vector3.ONE * puff_radius
	puff.transparency = 0.0
	puff.visible = true
	puff.reset_physics_interpolation()


## Poses every puff that shows: rising from where it was born, growing and fading, and hidden for
## good once its life is over.
func _pose_all() -> void:
	for index: int in _puffs.size():
		if _born[index] < 0:
			continue
		var age: int = _ticks - _born[index]
		var puff: MeshInstance3D = _puffs[index]
		if age >= _life_ticks:
			puff.visible = false
			_born[index] = -1
			continue
		var progress: float = float(age) / float(_life_ticks)
		var risen: float = rise_speed * float(age) / float(_ticks_per_second)
		var faded: float = (progress - fade_start_fraction) / (1.0 - fade_start_fraction)
		puff.global_position = _origins[index] + Vector3.UP * risen
		puff.scale = Vector3.ONE * puff_radius * lerpf(1.0, puff_growth, progress)
		puff.transparency = clampf(faded, 0.0, 1.0)


## Seconds as physics ticks, rounded and never under one.
func _in_ticks(seconds: float) -> int:
	return maxi(roundi(seconds * _ticks_per_second), 1)


## `count` copies of a template, added beside it; the template itself is then freed (a copy shares
## the template's mesh and material).
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


## What is wrong with the exports, as a sentence, or an empty string. Each test is written as "not
## above" so that a NaN, which is above nothing, is refused too.
func _first_problem() -> String:
	if puff_template == null or not (puff_template.get_parent() == self):
		return "puff_template is not assigned or is not a child"
	if not (puffs_per_second > 0.0) or not (puff_lifetime_seconds > 0.0):
		return "puffs_per_second and puff_lifetime_seconds must be above zero"
	if not (rise_speed >= 0.0):
		return "rise_speed must not be below zero"
	if not (puff_radius > 0.0) or not (puff_growth > 0.0):
		return "puff_radius and puff_growth must be above zero"
	if not (fade_start_fraction >= 0.0 and fade_start_fraction < 1.0):
		return "fade_start_fraction must be from 0 to under 1"
	return ""
