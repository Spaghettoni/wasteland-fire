# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the two-Player split-screen Water Canister run fun on one keyboard?
# Date: 2026-09-30
extends Camera3D

var target: Node3D
var _snapped := false


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + target.global_transform.basis * Vector3(0, 7, 13)
	if not _snapped:
		global_position = desired
		_snapped = true
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-8.0 * delta))
	look_at(target.global_position + Vector3(0, 1, 0), Vector3.UP)
