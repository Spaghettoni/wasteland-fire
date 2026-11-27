class_name Burning
extends Node3D
## The fire the Flame Tank's flames leave on what they hit (Story 063; Martin, 2026-11-22: "bude
## ostavat na veziach, budovach, muroch, nepriatelskych vozoch. 5s a bude davat polovicny dmg over
## time"): a child of the burning Unit or Structure that, for `seconds` after the last puff that hit,
## gives it `dps` damage per second, a lump every tick_seconds, and draws flames and smoke on it.
##
## ignite() puts one on a target or, when it burns already, sets its fire to the new numbers and
## starts its seconds again: fires never stack. The fire goes out early when its target is out of play
## (a Unit destroyed or benched, a Structure fallen); a Unit coming back into play does not burn.
##
## Damage comes from this node's own physics tick, never from a signal handler, as a Shot's does
## (Unit.apply_damage() may destroy the Unit, and the Round's handler of that reparents the Flag).
## The process_mode stays INHERIT, so the Round-over pause freezes it.

## Damage each lump is given every this many seconds.
@export_range(0.05, 2.0, 0.05, "suffix:s") var tick_seconds: float = 0.25
## The flames and the smoke drawn on the target, each FxParticles (no rate of their own: this node emits).
@export var flames: FxParticles
@export var smoke: FxParticles
## Particles a second of each, and how fast they rise.
@export var flame_rate: float = 60.0
@export var flame_rise: float = 2.2
@export var smoke_rate: float = 8.0
@export var smoke_rise: float = 1.2
## The share of the target's own move each drawn frame that the living flames and smoke are moved by too, so the fire rides
## on a driving Unit instead of being left behind it (Martin, 2026-11-22: "chcel by som vidiet, ze vozidla horia ... hp klesa
## ale vozidla nehoria"); a little under 1 so the flames stream back a little off a fast one. The move is the target's drawn
## (interpolated) position from frame to frame, so it holds at any frame rate and while the Unit speeds up or turns.
@export_range(0.0, 1.0, 0.01) var ride_share: float = 0.0
## The flickering glow the fire throws on the target and the ground around it: an OmniLight3D child, its energy
## glow_energy times a random factor between 1 - glow_flicker and 1, drawn anew glow_flicker_hz times a second.
@export var glow: OmniLight3D
@export var glow_energy: float = 0.0
@export_range(0.0, 1.0, 0.01) var glow_flicker: float = 0.0
@export var glow_flicker_hz: float = 0.0
## The flames rise from the top of the target's drawn box (its meshes' box, read once when it catches fire), this much
## below and above it, metres, and stay this far inside its sides.
@export var below_top: float = 0.5
@export var above_top: float = 0.15
@export var inset: float = 0.2

## Damage per second the fire gives (the matrix already applied).
## The fire's looping crackle (first sound pass, 2026-11), heard from the burning target while it
## burns. Null: a silent fire.
@export var sound: AudioStream
## The crackle's loudness against the file, in dB.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var sound_volume_db: float = 0.0

var dps: float = 0.0
## Seconds the fire has left.
var seconds_left: float = 0.0

var _target: Node3D
## The target's drawn box in its own frame.
var _box: AABB = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
var _lump_clock: float = 0.0
var _out: bool = false
## The target's drawn position at the last drawn frame.
var _last_at: Vector3 = Vector3.ZERO
var _has_last: bool = false
var _flicker_clock: float = 0.0


## Sets `target` on fire for `seconds` at `dps`, or rekindles its fire. Returns the Burning node, or
## null for a target that cannot burn (null, out of the tree, or the scene's root is no Burning).
static func ignite(target: Node3D, scene: PackedScene, burn_dps: float, burn_seconds: float) -> Burning:
	if target == null or not target.is_inside_tree() or scene == null:
		return null
	var fire: Burning = of(target)
	if fire == null:
		fire = scene.instantiate() as Burning
		if fire == null:
			push_error("Burning: the scene '%s' is not a Burning, so nothing burns." % scene.resource_path)
			return null
		fire._target = target
		target.add_child(fire)
	fire.dps = burn_dps
	fire.seconds_left = burn_seconds
	return fire


## The Burning on `target`, or null.
static func of(target: Node) -> Burning:
	if target == null:
		return null
	for child: Node in target.get_children():
		if child is Burning and not (child as Burning)._out:
			return child as Burning
	return null


## True while the fire burns.
func is_burning() -> bool:
	return not _out and seconds_left > 0.0


func _ready() -> void:
	if _target == null:
		_target = get_parent() as Node3D
	position = Vector3.ZERO
	_box = _drawn_box()
	# The particles are top_level and drawn about their node's own transform, so it stays the world's.
	for fx: FxParticles in [flames, smoke]:
		if fx != null:
			fx.global_transform = Transform3D.IDENTITY
	if glow != null:
		glow.position = Vector3(_box.get_center().x, _box.end.y + above_top, _box.get_center().z)
		glow.light_energy = glow_energy
	var crackle: AudioStreamPlayer3D = SoundPlay.make_loop(self, sound, sound_volume_db)
	if crackle != null:
		# A start point from the node id, not the global random numbers (the game logic draws from those).
		crackle.play(float(hash(get_instance_id()) % 1000) / 1000.0 * maxf(sound.get_length() - 0.1, 0.0))


func _process(delta: float) -> void:
	if _out or delta <= 0.0:
		return
	_flicker(delta)
	var at: Vector3 = get_global_transform_interpolated().origin
	if _has_last:
		var moved: Vector3 = (at - _last_at) * ride_share
		for fx: FxParticles in [flames, smoke]:
			if fx != null:
				fx.shift(moved)
	_last_at = at
	_has_last = true
	_emit(flames, flame_rate * delta, flame_rise)
	_emit(smoke, smoke_rate * delta, smoke_rise)


## Emits about `amount` particles (the fraction carried) at random points over the target's
## footprint, rising at `rise` m/s.
func _emit(fx: FxParticles, amount: float, rise: float) -> void:
	if fx == null:
		return
	var carry: float = float(fx.get_meta(&"carry", 0.0)) + amount
	var r: RandomNumberGenerator = fx.rng()
	while carry >= 1.0:
		carry -= 1.0
		var lo: Vector3 = _box.position + Vector3(inset, 0.0, inset)
		var hi: Vector3 = _box.end - Vector3(inset, 0.0, inset)
		var top: float = _box.end.y
		var local: Vector3 = Vector3(r.randf_range(lo.x, maxf(hi.x, lo.x)),
				r.randf_range(top - below_top, top + above_top), r.randf_range(lo.z, maxf(hi.z, lo.z)))
		# Where the target is drawn this frame (physics interpolation), so the fire sits on the model.
		var at: Vector3 = get_global_transform_interpolated() * local
		fx.emit(at, Vector3(r.randf_range(-0.3, 0.3), rise * r.randf_range(0.7, 1.3), r.randf_range(-0.3, 0.3)))
	fx.set_meta(&"carry", carry)


## Draws the glow's energy anew glow_flicker_hz times a second.
func _flicker(delta: float) -> void:
	if glow == null or glow_flicker_hz <= 0.0:
		return
	_flicker_clock += delta
	if _flicker_clock < 1.0 / glow_flicker_hz:
		return
	_flicker_clock = 0.0
	var r: RandomNumberGenerator = flames.rng() if flames != null else RandomNumberGenerator.new()
	glow.light_energy = glow_energy * r.randf_range(1.0 - glow_flicker, 1.0)


## The box of every mesh drawn under the target, in the target's frame (this node's, which sits at its origin), the
## particles' own meshes left out, and so is a Unit's see-through silhouette (its mesh copies and its fill quad, which is
## many metres wide: counted in, it spread the fire over a box so big that a burning vehicle showed none; Martin,
## 2026-11-22: "veza hori, mury horia, budovy horia, vozidla nehoria"); a 1 m box when there is none.
func _drawn_box() -> AABB:
	var box: AABB = AABB()
	var found: bool = false
	var inverse: Transform3D = global_transform.affine_inverse()
	for node: Node in _target.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null or not mesh.visible or is_ancestor_of(mesh):
			continue
		if mesh.is_in_group(UnitSilhouette.COPY_GROUP) or mesh.is_in_group(UnitSilhouette.FILL_GROUP):
			continue
		var part: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		box = part if not found else box.merge(part)
		found = true
	return box if found else AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))


func _physics_process(delta: float) -> void:
	if _out:
		return
	if not _in_play():
		_go_out()
		return
	var step: float = minf(delta, seconds_left)
	seconds_left -= delta
	_lump_clock += step
	if _lump_clock >= tick_seconds or seconds_left <= 0.0:
		var lump: float = dps * _lump_clock
		_lump_clock = 0.0
		if lump > 0.0 and _target.has_method(&"apply_damage"):
			_target.call(&"apply_damage", lump)
	if seconds_left <= 0.0:
		_go_out()


func _in_play() -> bool:
	if not is_instance_valid(_target):
		return false
	if _target is Unit:
		return (_target as Unit).is_alive
	var standing: Variant = _target.get(&"is_standing")
	return typeof(standing) != TYPE_BOOL or standing


## Puts the fire out: the flames stop, the smoke drifts off, and the node frees itself.
func _go_out() -> void:
	_out = true
	seconds_left = 0.0
	var keep: Node = get_tree().current_scene if is_inside_tree() else null
	for fx: FxParticles in [flames, smoke]:
		if fx != null:
			fx.finish(keep)
	flames = null
	smoke = null
	if glow != null:
		glow.visible = false
	queue_free()
