class_name Bush
extends Node3D
## A Bush (the author's krík): cover that hides a ground Unit behind it from a Turret but stops no
## Shot and no Unit, and that a Buggy or a Truck flattens by driving into it.
##
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-6 and AC-8,
## from the author's board of 2026-10-07 (design/source/wasteland-fire-board-2026-10-07.en.md,
## Bushes): "Cover: you can hide behind a bush, but you can shoot through it. When a buggy or a truck
## drives through it, it collapses and the cover is gone. The motorbike passes through without
## destroying it; the gyrocopter flies over. Turrets need a direct line of sight: they do not shoot
## at a target behind a bush". Vocabulary: CONTEXT.md (Bush, Turret, Unit).
##
## How it hides. A Bush has a sight body (a StaticBody3D on the physics layer named "sight", layer 8,
## with no mask): no Unit's mask and no Shot's mask (MatchRules.shot_collision_mask) holds that
## layer, so nothing collides with it and every Shot passes through, but a Turret's sight ray adds it
## for a ground target (TurretStats.sight_extra_mask), so a ground Unit behind a standing Bush is not
## seen. A flying target's sight (flying_sight_extra_mask) leaves it out: a Bush never hides the
## Gyrocopter, which flies over it (Story 037's Out of Scope keeps it so).
##
## How it falls. The trigger, an Area3D that watches the units layer, reports every ground Unit
## that enters it; one whose type says crushes_bushes (UnitStats: the Buggy and the Truck) flattens
## the Bush at once: the standing look hides, the flat look shows and the sight body leaves its
## layer, so it hides nothing any more. A Motorbike, whose type does not, passes and leaves it
## standing. A flattened Bush stays flat for the Round; SplitScreen calls restore() on every Bush the
## Map lists (MapField.bushes) when a Round starts again.

## Emitted once when a Unit that crushes Bushes flattens this Bush.
signal flattened

## Emitted when restore() stands the Bush again.
signal restored

## The Area3D that watches the units layer for a Unit driving into the Bush. Required: with none
## the Bush can never be flattened (an error says so).
@export var trigger: Area3D

## The body on the sight layer that hides a ground target from a Turret while the Bush stands.
## Required: with none the Bush hides nothing (an error says so).
@export var sight_body: CollisionObject3D

## What the Bush looks like while it stands.
@export var standing_look: Node3D

## What the Bush looks like once it is flattened: low, dark, trampled.
@export var flat_look: Node3D

## How big the Bush is, times the scene's own numbers: the looks, the sight body and the trigger
## grow together (Story 044; Martin, 2026-10-22: "zvacsi trochu kricky, paci sa mi myslienka ze sa
## schovas s moto do kricku"). bush.tscn sets it; set_size() changes it on a live Bush.
@export_range(0.5, 3.0, 0.05) var size: float = 1.0

## Whether the Bush stands (hides a ground target) or is flattened. Read-only.
var is_standing: bool:
	get:
		return _standing
	set(_value):
		push_error("Bush '%s': is_standing is read-only. Change it with flatten() or restore()." % name)

var _standing: bool = true
var _sight_layer: int = 0
## The scene's own numbers, read once, that size multiplies: each shape node's position and its
## cylinder's radius and height.
var _base_shapes: Array[Dictionary] = []


func _ready() -> void:
	if sight_body == null:
		push_error("Bush '%s': sight_body is not assigned, so it hides nothing from a Turret." % name)
	else:
		_sight_layer = sight_body.collision_layer
	if trigger == null:
		push_error("Bush '%s': trigger is not assigned, so no Unit can flatten it." % name)
	else:
		trigger.body_entered.connect(_on_body_entered)
	set_size(size)
	_show_look()


## Makes the Bush `value` times the scene's own size: both looks scaled, each cylinder of the sight
## body and the trigger given its own copy, radius and height multiplied, its centre lifted to match.
func set_size(value: float) -> void:
	size = value
	if _base_shapes.is_empty():
		for body: Node in [sight_body, trigger]:
			if body == null:
				continue
			for child: Node in body.get_children():
				var holder: CollisionShape3D = child as CollisionShape3D
				if holder != null and holder.shape is CylinderShape3D:
					var cylinder: CylinderShape3D = holder.shape as CylinderShape3D
					_base_shapes.append({"node": holder, "y": holder.position.y, "radius": cylinder.radius, "height": cylinder.height})
	for look: Node3D in [standing_look, flat_look]:
		if look != null:
			look.scale = Vector3.ONE * size
	for entry: Dictionary in _base_shapes:
		var holder: CollisionShape3D = entry["node"]
		var cylinder := CylinderShape3D.new()
		cylinder.radius = entry["radius"] * size
		cylinder.height = entry["height"] * size
		holder.shape = cylinder
		holder.position.y = entry["y"] * size


## Flattens the Bush: it shows its flat look and its sight body leaves the sight layer, so it hides
## nothing until restore(). A flattened Bush is left alone.
func flatten() -> void:
	if not _standing:
		return
	_standing = false
	if sight_body != null:
		sight_body.set_deferred(&"collision_layer", 0)
	_show_look()
	flattened.emit()


## Stands the Bush again (the restart): its standing look and its sight body's layer come back. A
## standing Bush is left as it is.
func restore() -> void:
	if _standing:
		return
	_standing = true
	if sight_body != null:
		sight_body.set_deferred(&"collision_layer", _sight_layer)
	_show_look()
	restored.emit()


func _on_body_entered(body: Node3D) -> void:
	var unit: Unit = body as Unit
	if unit == null or unit.stats == null or not unit.stats.crushes_bushes:
		return
	flatten()


func _show_look() -> void:
	if standing_look != null:
		standing_look.visible = _standing
	if flat_look != null:
		flat_look.visible = not _standing
