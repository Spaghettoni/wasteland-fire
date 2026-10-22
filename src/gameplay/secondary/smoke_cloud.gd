class_name SmokeCloud
extends Node3D
## A smoke screen (Story 042): a big grey cloud the Gyrocopter drops where it is, which hangs there
## for SmokeSettings.seconds and fades out. It is a picture that hides what is in and behind it from
## both views, and a sight body on the physics layer named "smoke" (layer 9), which a Turret's sight
## of every target holds (TurretStats sight_extra_mask and flying_sight_extra_mask), so a Turret
## sees nothing in or behind it. No Unit and no Shot collides with it. A Round that starts again
## frees every cloud (SplitScreen, SMOKE_GROUP).
##
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-3.

## The cloud's numbers. Required.
@export var settings: SmokeSettings
## The puffs, scaled to the radius and faded together through one material.
@export var puffs: Node3D
## The body on the smoke layer, its sphere sized to the radius.
@export var sight_body: CollisionObject3D
## The sphere of the sight body.
@export var sight_shape: CollisionShape3D

var _age: float = 0.0
var _material: StandardMaterial3D


## Drops the cloud at `at` (the Gyrocopter's ground point); call it after adding the cloud to the tree.
func drop(at: Vector3) -> void:
	global_position = Vector3(at.x, 0.0, at.z)
	reset_physics_interpolation()


func _ready() -> void:
	if settings == null or puffs == null:
		push_error("SmokeCloud '%s': settings and puffs must be set, so the cloud frees itself." % name)
		queue_free()
		return
	puffs.scale = Vector3.ONE * settings.radius
	var sphere := SphereShape3D.new()
	sphere.radius = settings.radius
	if sight_shape != null:
		sight_shape.shape = sphere
	for child: Node in puffs.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			if _material == null:
				_material = (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mesh.material_override = _material
	_set_opacity(settings.opacity)


func _physics_process(delta: float) -> void:
	_age += delta
	var left: float = settings.seconds - _age
	if left <= 0.0:
		set_physics_process(false)
		queue_free()
		return
	if left < settings.fade_seconds:
		_set_opacity(settings.opacity * left / settings.fade_seconds)
		if sight_body != null and left < settings.fade_seconds / 2.0:
			sight_body.collision_layer = 0


## Sets the puffs' opacity: a fully opaque cloud is drawn opaque (nothing in it shows through, the
## Gyrocopter included); a fading one blends.
func _set_opacity(alpha: float) -> void:
	if _material != null:
		var colour: Color = _material.albedo_color
		colour.a = alpha
		_material.albedo_color = colour
		_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if alpha >= 1.0 else BaseMaterial3D.TRANSPARENCY_ALPHA
