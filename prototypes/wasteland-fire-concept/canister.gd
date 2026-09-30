# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the two-Player split-screen Water Canister run fun on one keyboard?
# Date: 2026-09-30
extends Area3D

var owner_player := 1
var home := Vector3.ZERO
var at_home := true
var held_by = null
var world: Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body) -> void:
	if held_by != null or not (body is CharacterBody3D):
		return
	if not body.alive or body.carrying != null:
		return
	if body.global_position.distance_to(global_position) > 4.0:
		return   # an overlap reported for a body that is not here (teleport sweep) is not a pickup
	if body.player == owner_player and at_home:
		return
	call_deferred("pick_up", body)


func pick_up(bike) -> void:
	if held_by != null or bike.carrying != null or not bike.alive:
		return
	held_by = bike
	bike.carrying = self
	at_home = false
	monitoring = false
	reparent(bike.mount, false)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	print("PICKUP canister", owner_player, " by P", bike.player, " bike_at=", bike.global_position, " can_at=", global_position)


func drop() -> void:
	var pos := global_position
	_release()
	global_position = Vector3(pos.x, 0.6, pos.z)
	print("DROP canister", owner_player, " at ", global_position)


func return_home() -> void:
	_release()
	global_position = home
	at_home = true
	print("RETURN canister", owner_player)


func _release() -> void:
	if held_by != null:
		held_by.carrying = null
		held_by = null
	reparent(world, true)
	rotation = Vector3.ZERO
	monitoring = true
	print("RELEASE canister", owner_player, " parent=", get_parent().name, " at=", global_position)
