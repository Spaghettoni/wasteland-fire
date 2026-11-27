class_name UnitEngineSound
extends AudioStreamPlayer3D
## The engine of a Unit, heard in the world (first sound pass, 2026-11): a looping recording from
## the Unit's type (UnitStats.engine_sound) whose pitch climbs with the speed, from
## engine_pitch_idle at a standstill to engine_pitch_top at max_speed, smoothed by
## engine_pitch_follow. It plays while the Unit is in play and stops when the Unit is destroyed,
## benched or out of Fuel; a type change (a new spawn) swaps the recording.
##
## A child of the Unit scene (motorbike.tscn, whose Unit takes every type), so it rides with the
## Unit. Volume and pitch come from the type's UnitStats, never from here.

## The Unit whose engine this is. Defaults to the parent when left empty.
@export var unit: Unit

var _pitch: float = 1.0


func _ready() -> void:
	if unit == null:
		unit = get_parent() as Unit
	if unit == null:
		push_error("UnitEngineSound '%s': no Unit to listen to, so it stays silent." % name)
		set_process(false)


func _process(delta: float) -> void:
	var stats: UnitStats = unit.stats
	var running: bool = unit.is_alive and stats != null and stats.engine_sound != null and not unit.is_fuel_empty
	if not running:
		if playing:
			stop()
		return
	if stream != stats.engine_sound:
		stream = stats.engine_sound
		_pitch = stats.engine_pitch_idle
		if playing:
			stop()
	volume_db = stats.engine_volume_db
	_pitch = lerpf(_pitch, target_pitch(stats, unit.current_speed), clampf(stats.engine_pitch_follow * delta, 0.0, 1.0))
	pitch_scale = maxf(_pitch, 0.01)
	if not playing:
		# A start point from the node id, not the global random numbers (the game logic draws from those).
		play(float(hash(get_instance_id()) % 1000) / 1000.0 * maxf(stream.get_length() - 0.1, 0.0))


## The pitch the engine heads for at `speed` (m/s, either direction) for `stats`: engine_pitch_idle
## at zero, engine_pitch_top at max_speed and above, in a straight line between.
static func target_pitch(stats: UnitStats, speed: float) -> float:
	if stats.max_speed <= 0.0:
		return stats.engine_pitch_idle
	var share: float = clampf(absf(speed) / stats.max_speed, 0.0, 1.0)
	return lerpf(stats.engine_pitch_idle, stats.engine_pitch_top, share)
