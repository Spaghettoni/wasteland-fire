class_name FlameShot
extends Shot
## One puff of the Flame Tank's flamethrower (Story 063; Martin, 2026-11-22: "plamene ale musi palit
## dostatocne pred seba", 20 m; "pali vsetkych ale Teba nie"; the fire "bude ostavat na veziach,
## budovach, muroch, nepriatelskych vozoch. 5s a bude davat polovicny dmg over time"). A Shot in
## every way (flight, hit test, the matrix) but two:
##
## - Who it burns. It never touches the shooter (the Shot's RID exclusion), and it damages every Unit
##   it meets, the shooter's Teammates too; a Structure as a Shot does (one of the shooter's own Team
##   is spared unless it says spares_owner false, as every wall does).
## - What it leaves. A Structure it damaged and a Unit it hit catch fire (Burning): for burn_seconds
##   after the last puff that hit, they take the burn's damage per second. A Teammate keeps burning too
##   (Martin, 2026-11-22: "chcem aby ostal horet aj tvoj kamos ked prejde cez plamen").
##
## The look: the tracer is a few glowing cubes (flame_shot.tscn) that swell and cool from yellow to
## red as the puff flies; their heat is the instance parameter `heat` of spatial_fx_flame.gdshader.
## Set burn_dps, burn_seconds and burning_scene before launch() (Weapon does).

## Damage per second of the fire the puff leaves on what it hit (before the matrix), 0 for none.
var burn_dps: float = 0.0
## Seconds that fire burns after the last puff that hit.
var burn_seconds: float = 0.0
## The Burning scene a target that catches fire gets.
var burning_scene: PackedScene

## The size of the tracer at the nozzle and at the end of the range, metres.
@export var size_start: float = 0.35
@export var size_end: float = 1.6
## The cubes drawn: their heat goes from 1 at the nozzle to 0 at the end of the range.
@export var cubes: Array[GeometryInstance3D] = []


func _process(_delta: float) -> void:
	if tracer == null or _max_range <= 0.0:
		return
	var t: float = clampf(_travelled / _max_range, 0.0, 1.0)
	tracer.scale = Vector3.ONE * lerpf(size_start, size_end, t)
	for cube: GeometryInstance3D in cubes:
		cube.set_instance_shader_parameter(&"heat", 1.0 - t)


func _damage_target(collider: Object) -> void:
	if collider == null or not collider.has_method(&"apply_damage"):
		return
	var type_value: Variant = collider.get(&"type_id")
	if typeof(type_value) != TYPE_STRING_NAME:
		return
	var target_type: StringName = type_value
	var player_value: Variant = collider.get(&"player_index")
	var target_player: int = int(player_value) if typeof(player_value) == TYPE_INT else -1
	var own: bool = _shooter_player_index >= 0 and target_player == _shooter_player_index
	var unit: bool = collider is Unit
	if not unit:
		var spares: Variant = collider.get(&"spares_owner")
		if own and (typeof(spares) != TYPE_BOOL or spares):
			return
	var multiplier: float = _matrix.multiplier(_shooter_type, target_type)
	collider.call(&"apply_damage", _damage * multiplier)
	if burn_dps > 0.0 and burn_seconds > 0.0 and burning_scene != null:
		Burning.ignite(collider as Node3D, burning_scene, burn_dps * multiplier, burn_seconds)
