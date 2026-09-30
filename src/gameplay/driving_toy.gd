class_name DrivingToy
extends Node3D
## The Story 001 launch scene: one Motorbike on the greybox field with a chase camera behind it.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md AC-1 (the game launches
## straight into a flat greybox plane with one Motorbike Unit and a chase camera, no menu, no
## HUD) and the spawn rule of Godot's physics interpolation guide.
##
## The scene holds the pieces. This script only puts the Player 1 Motorbike on its start marker,
## once, when the scene is ready. Where the Motorbike starts is data: the field's player_start
## marker, its position and its facing, asked of the field rather than found by node path, so a
## rename inside the field scene cannot break the spawn. Nothing here knows a coordinate.
##
## The order of a teleport, and a spawn is one, matters: set the transform first, then reset the
## Unit's motion and physics interpolation, then snap the camera. The other order streaks the
## Unit across the map for a few frames.

## The field the Motorbike drives on. It carries the Player 1 start marker.
@export var field: GreyboxField

## The Unit Player 1 drives.
@export var motorbike: Unit

## The camera that chases the Motorbike.
@export var chase_camera: ChaseCamera


func _ready() -> void:
	if field == null or field.player_start == null or motorbike == null or chase_camera == null:
		push_error("DrivingToy '%s': field (with its player_start), motorbike and chase_camera must all be assigned." % name)
		return
	_spawn_motorbike()


func _spawn_motorbike() -> void:
	motorbike.global_transform = field.player_start.global_transform
	motorbike.reset_motion()
	chase_camera.snap_to_target()
