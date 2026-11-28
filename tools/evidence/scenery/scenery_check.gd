extends SceneTree
## Checks the Maps' voxel scenery (the art overhaul, Stories 071-072, and Martin 2026-11-28: "gyro naraza do kaktusov"):
##  S1 every cactus body on every Map is on the cover layer and on no other;
##  S2 the Gyrocopter's mask leaves the cover layer out (it flies over a cactus) and every ground type's mask holds it
##     (they run into one);
##  S3 every cactus is drawn no taller than the flying height less 0.5 m and its collider no taller than 1.2 m.
## Run: godot --headless --path . -s res://tools/evidence/scenery/scenery_check.gd

const COVER_LAYER: int = 64
const FLYING_HEIGHT_M: float = 2.5
const COLLIDER_TOP_M: float = 1.2
const MAPS: Array[String] = ["res://src/gameplay/maps/map_01/map_01_scenery.tscn", "res://src/gameplay/maps/map_02/map_02_scenery.tscn", "res://src/gameplay/maps/map_03/map_03_scenery.tscn"]
const GROUND: Array[String] = ["motorbike", "buggy", "truck"]


func _init() -> void:
	var problems := PackedStringArray()
	var count: int = 0
	var tallest: float = 0.0
	for path: String in MAPS:
		var scenery: Node = (load(path) as PackedScene).instantiate()
		for body: Node in scenery.get_children():
			var sb := body as StaticBody3D
			if sb == null:
				continue
			count += 1
			if sb.collision_layer != COVER_LAYER:
				problems.append("%s %s on layers %d" % [path.get_file(), sb.name, sb.collision_layer])
			var look := sb.get_node("Look") as MeshInstance3D
			var top: float = look.mesh.get_aabb().end.y * look.scale.y
			tallest = maxf(tallest, top)
			if top > FLYING_HEIGHT_M - 0.5:
				problems.append("%s %s drawn %.2f m tall" % [path.get_file(), sb.name, top])
			var shape := sb.get_node("Collider") as CollisionShape3D
			var h: float = (shape.shape as CylinderShape3D).height if shape.shape is CylinderShape3D else (shape.shape as BoxShape3D).size.y
			if h > COLLIDER_TOP_M + 0.001:
				problems.append("%s %s collider %.2f m tall" % [path.get_file(), sb.name, h])
		scenery.free()
	var gyro: UnitStats = load("res://src/gameplay/units/data/gyrocopter_stats.tres")
	if gyro.collision_mask & COVER_LAYER:
		problems.append("the Gyrocopter's mask %d holds the cover layer" % gyro.collision_mask)
	for t: String in GROUND:
		var stats: UnitStats = load("res://src/gameplay/units/data/%s_stats.tres" % t)
		if not (stats.collision_mask & COVER_LAYER):
			problems.append("%s's mask %d leaves the cover layer out" % [t, stats.collision_mask])
	print("CHECK scenery cactuses=%d tallest=%.2fm gyro_mask=%d %s" % [count, tallest, gyro.collision_mask, "PASS" if problems.is_empty() else "FAIL " + "; ".join(problems)])
	print("RESULT scenery %s" % ("ok" if problems.is_empty() and count > 0 else "FAIL"))
	quit(0 if problems.is_empty() else 1)
