## Low-poly armoured wasteland buggy assembled from engine primitives at runtime.
##
## Concept model for the Buggy Unit: a rusted scrap-metal hull, spike arrays on
## the front bumper and side skirts, and a rocket-pod anti-aircraft launcher on
## the rear deck. The vehicle faces -Z and is sized in metres: about 4.9 m long
## over the spikes, 3 m wide over the wheels, 2.2 m to the roof and 3 m to the
## raised launcher. Every part is a MeshInstance3D child, so the node can sit
## under any body as its visual.
extends Node3D

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Yaw of the launcher around its turret ring, in degrees. 0 points forward.
@export var pod_yaw_deg: float = 35.0
## Elevation of the launcher above the horizon, in degrees.
@export var pod_pitch_deg: float = 40.0
## Steering angle of the front wheels, in degrees. Positive turns left.
@export var steer_deg: float = 12.0
## Seed of the procedural rust and grime textures. Same seed, same look.
@export var rust_seed: int = 7

var _m: Dictionary = {}


func _ready() -> void:
	_m = Palette.materials(rust_seed)
	_build_chassis()
	_build_cabin()
	_build_wheels()
	_build_front_armor()
	_build_side_armor()
	_build_launcher()
	_build_fittings()


func _build_chassis() -> void:
	var hull := Kitbash.group(self, "Hull")
	_box(hull, Vector3(1.7, 0.55, 3.2), Vector3(0, 0.8, 0.05), "rust")
	_box(hull, Vector3(1.3, 0.28, 3.5), Vector3(0, 0.45, 0.05), "rust_dark")
	# sloping bonnet with bolted-on scrap plates
	_box(hull, Vector3(1.6, 0.42, 1.05), Vector3(0, 0.86, -1.5), "rust_orange", Vector3(-10, 0, 0))
	_box(hull, Vector3(0.7, 0.05, 0.8), Vector3(-0.4, 1.1, -1.45), "scrap", Vector3(-10, 0, 0))
	_box(hull, Vector3(0.55, 0.05, 0.6), Vector3(0.45, 1.1, -1.3), "rust_dark", Vector3(-10, 5, 0))
	# side armour panels, each a different piece of scrap, over lower skirts
	_box(hull, Vector3(0.12, 0.5, 2.4), Vector3(-0.92, 0.85, 0.0), "scrap")
	_box(hull, Vector3(0.12, 0.5, 2.4), Vector3(0.92, 0.85, 0.0), "rust")
	_box(hull, Vector3(0.1, 0.3, 2.1), Vector3(-0.98, 0.5, 0.05), "rust_dark")
	_box(hull, Vector3(0.1, 0.3, 2.1), Vector3(0.98, 0.5, 0.05), "rust_dark")
	# welded patches
	_box(hull, Vector3(0.05, 0.32, 0.7), Vector3(-1.0, 0.92, -0.5), "rust_orange", Vector3(0, 0, 3))
	_box(hull, Vector3(0.05, 0.26, 0.55), Vector3(-1.0, 0.75, 0.55), "bone", Vector3(0, 0, -2))
	_box(hull, Vector3(0.05, 0.3, 0.6), Vector3(1.0, 0.8, 0.3), "scrap", Vector3(0, 0, 2))
	_box(hull, Vector3(0.05, 0.22, 0.5), Vector3(1.0, 0.95, -0.7), "bone", Vector3(0, 0, -3))
	# rivet rows along the panel edges
	for side: float in [-1.0, 1.0]:
		for i in 7:
			var z := -1.05 + i * 0.35
			_ball(hull, 0.03, Vector3(side * 1.0, 1.06, z), "steel_dark")
			_ball(hull, 0.03, Vector3(side * 1.0, 0.64, z), "steel_dark")
	# rear deck, armour skirt and bumper
	_box(hull, Vector3(1.7, 0.08, 1.25), Vector3(0, 1.1, 1.35), "rust_dark")
	_box(hull, Vector3(1.7, 0.45, 0.06), Vector3(0, 0.83, 1.68), "scrap", Vector3(-6, 0, 0))
	_box(hull, Vector3(1.9, 0.2, 0.2), Vector3(0, 0.62, 1.95), "scrap")


func _build_cabin() -> void:
	var cab := Kitbash.group(self, "Cabin")
	# roll cage
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.55, 0.45]:
			_cyl(cab, 0.045, 1.0, Vector3(x, 1.57, z), "steel_dark", Vector3.ZERO, 8)
		_cyl(cab, 0.045, 1.1, Vector3(x, 2.07, -0.05), "steel_dark", Vector3(90, 0, 0), 8)
	for z: float in [-0.55, 0.45]:
		_cyl(cab, 0.045, 1.5, Vector3(0, 2.07, z), "steel_dark", Vector3(0, 0, 90), 8)
	# roof plates
	_box(cab, Vector3(1.5, 0.06, 1.1), Vector3(0, 2.11, -0.05), "rust")
	_box(cab, Vector3(0.7, 0.05, 0.9), Vector3(-0.35, 2.15, 0.05), "scrap", Vector3(0, 4, 0))
	# armoured windshield with slats
	var shield := Kitbash.group(cab, "Windshield")
	shield.position = Vector3(0, 1.72, -0.62)
	shield.rotation_degrees = Vector3(12, 0, 0)
	_box(shield, Vector3(1.35, 0.6, 0.05), Vector3.ZERO, "glass")
	for i in 3:
		_box(shield, Vector3(1.42, 0.04, 0.06), Vector3(0, -0.2 + i * 0.2, -0.05), "rust_dark")
	# seats
	for x: float in [-0.36, 0.36]:
		_box(cab, Vector3(0.5, 0.45, 0.5), Vector3(x, 1.3, 0.1), "leather")
		_box(cab, Vector3(0.5, 0.55, 0.15), Vector3(x, 1.62, 0.35), "leather", Vector3(-8, 0, 0))
	# scrap door plates over the lower cage and a rear plate behind the seats
	_box(cab, Vector3(0.06, 0.5, 0.9), Vector3(-0.78, 1.34, -0.05), "rust", Vector3(0, 0, 3))
	_box(cab, Vector3(0.06, 0.44, 0.8), Vector3(0.78, 1.32, -0.02), "bone", Vector3(0, 0, -2))
	_box(cab, Vector3(1.45, 0.6, 0.06), Vector3(0, 1.38, 0.5), "rust_dark")


func _build_wheels() -> void:
	var wheels := Kitbash.group(self, "Wheels")
	var specs: Array = [
		[Vector3(-1.25, 0.52, -1.45), 0.52, 0.42, true],
		[Vector3(1.25, 0.52, -1.45), 0.52, 0.42, true],
		[Vector3(-1.27, 0.60, 1.45), 0.60, 0.50, false],
		[Vector3(1.27, 0.60, 1.45), 0.60, 0.50, false],
	]
	for spec: Array in specs:
		var p: Vector3 = spec[0]
		var r: float = spec[1]
		var w: float = spec[2]
		var steers: bool = spec[3]
		var side := signf(p.x)
		var hub := Kitbash.group(wheels, "Wheel")
		hub.position = p
		if steers:
			hub.rotation_degrees = Vector3(0, steer_deg, 0)
		_cyl(hub, r, w, Vector3.ZERO, "rubber", Vector3(0, 0, 90), 20)
		_cyl(hub, r + 0.03, w * 0.55, Vector3.ZERO, "tread", Vector3(0, 0, 90), 20)
		_cyl(hub, r * 0.5, w + 0.08, Vector3.ZERO, "steel_dark", Vector3(0, 0, 90), 12)
		_cyl(hub, r * 0.2, w + 0.14, Vector3.ZERO, "rust", Vector3(0, 0, 90), 8)
		# chunky off-road lugs around the tyre
		for k in 10:
			var a := k * 36.0
			var rad := deg_to_rad(a)
			_box(hub, Vector3(w * 0.8, 0.07, 0.12),
					Vector3(0, (r + 0.02) * cos(rad), (r + 0.02) * sin(rad)), "tread", Vector3(a, 0, 0))
		# axle stub, suspension arm, mudguard and its brackets
		_cyl(wheels, 0.05, 0.6, Vector3(side * 0.95, p.y, p.z), "steel_dark", Vector3(0, 0, 90), 8)
		_box(wheels, Vector3(0.5, 0.06, 0.12), Vector3(side * 0.95, p.y + 0.18, p.z + 0.12),
				"rust_dark", Vector3(0, 0, -side * 18.0))
		# faceted fender arch over the tyre, strutted back to the hull
		var arch_r := r + 0.16
		var seg_len := 2.0 * arch_r * sin(deg_to_rad(15.0)) + 0.04
		for a: float in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			var rad := deg_to_rad(a)
			_box(wheels, Vector3(0.6, 0.08, seg_len),
					Vector3(side * 1.25, p.y + arch_r * cos(rad), p.z + arch_r * sin(rad)),
					"rust_dark", Vector3(a, 0, 0))
		var strut_dy := p.y + arch_r * 0.87 - 0.05 - 1.0
		var strut_len := sqrt(0.4 * 0.4 + strut_dy * strut_dy)
		var strut_tilt := rad_to_deg(atan2(strut_dy, 0.4))
		for dz: float in [-0.34, 0.34]:
			_box(wheels, Vector3(strut_len, 0.06, 0.08),
					Vector3(side * 1.05, 1.0 + strut_dy * 0.5, p.z + dz), "steel_dark",
					Vector3(0, 0, side * strut_tilt))


func _build_front_armor() -> void:
	var front := Kitbash.group(self, "FrontArmor")
	# plate leaning over the grille, bumper bars and struts
	_box(front, Vector3(1.7, 0.62, 0.08), Vector3(0, 0.88, -2.0), "scrap", Vector3(18, 0, 0))
	_box(front, Vector3(2.3, 0.22, 0.22), Vector3(0, 0.6, -2.15), "steel_dark")
	_box(front, Vector3(2.0, 0.12, 0.12), Vector3(0, 1.02, -2.1), "steel_dark")
	for x: float in [-0.75, 0.75]:
		_box(front, Vector3(0.1, 0.55, 0.1), Vector3(x, 0.81, -2.12), "steel_dark")
	# spike arrays: seven on the bumper, five on the upper bar
	for i in 7:
		_cone(front, 0.075, 0.55, Vector3(-0.9 + i * 0.3, 0.6, -2.535), "steel", Vector3(-90, 0, 0))
	for i in 5:
		_cone(front, 0.06, 0.4, Vector3(-0.6 + i * 0.3, 1.02, -2.36), "steel", Vector3(-90, 0, 0))
	# headlamps
	for x: float in [-0.5, 0.5]:
		_cyl(front, 0.11, 0.08, Vector3(x, 0.82, -2.06), "lamp", Vector3(-90, 0, 0), 12)
	# V plow under the bumper
	for side: float in [-1.0, 1.0]:
		_box(front, Vector3(1.0, 0.34, 0.08), Vector3(side * 0.42, 0.33, -2.22), "steel_dark",
				Vector3(0, -side * 38.0, 0))
	_box(front, Vector3(0.1, 0.34, 0.1), Vector3(0, 0.33, -2.5), "steel_dark")


func _build_side_armor() -> void:
	var sides := Kitbash.group(self, "SideArmor")
	for side: float in [-1.0, 1.0]:
		var aim := Vector3(0, 0, -90.0 * side)
		for i in 5:
			var z := -0.75 + i * 0.3
			_cone(sides, 0.06, 0.4, Vector3(side * 1.18, 0.92, z), "steel", aim)
			_cone(sides, 0.05, 0.32, Vector3(side * 1.19, 0.55, z + 0.15), "steel", aim)


func _build_launcher() -> void:
	var turret := Kitbash.group(self, "Turret")
	turret.position = Vector3(0, 1.14, 1.35)
	_cyl(turret, 0.42, 0.14, Vector3.ZERO, "gunmetal", Vector3.ZERO, 20)
	var yaw := Kitbash.group(turret, "Yaw")
	yaw.rotation_degrees = Vector3(0, pod_yaw_deg, 0)
	# tall pedestal so the pod clears the roofline, with a yoke on top
	_cyl(yaw, 0.26, 0.08, Vector3(0, 0.08, 0), "gunmetal", Vector3.ZERO, 12)
	_cyl(yaw, 0.2, 0.7, Vector3(0, 0.3, 0), "steel_dark", Vector3.ZERO, 12)
	_box(yaw, Vector3(1.0, 0.08, 0.36), Vector3(0, 0.68, 0), "gunmetal")
	for x: float in [-0.46, 0.46]:
		_box(yaw, Vector3(0.08, 0.6, 0.36), Vector3(x, 0.94, 0), "gunmetal")
	for x: float in [-0.44, 0.44]:
		_cyl(yaw, 0.06, 0.12, Vector3(x, 1.19, 0), "steel", Vector3(0, 0, 90), 8)
	# tracking dish on a stalk beside the yoke
	_cyl(yaw, 0.02, 0.5, Vector3(-0.72, 0.9, 0.12), "steel_dark", Vector3.ZERO, 6)
	var dish := _ball(yaw, 0.2, Vector3(-0.72, 1.17, 0.12), "scrap", Vector3(1.0, 0.28, 1.0))
	dish.rotation_degrees = Vector3(-35, 0, 0)
	# the pod pitches about the trunnions
	var pod := Kitbash.group(yaw, "Pod")
	pod.position = Vector3(0, 1.19, 0)
	pod.rotation_degrees = Vector3(pod_pitch_deg, 0, 0)
	_box(pod, Vector3(0.8, 0.54, 1.2), Vector3.ZERO, "olive")
	_box(pod, Vector3(0.82, 0.08, 0.3), Vector3(0, 0.24, 0.3), "stripe")
	_box(pod, Vector3(0.82, 0.08, 0.3), Vector3(0, 0.24, -0.3), "stripe")
	_box(pod, Vector3(0.12, 0.12, 0.4), Vector3(0, 0.33, 0.0), "gunmetal")
	for row: float in [-0.13, 0.13]:
		for col: float in [-0.25, 0.0, 0.25]:
			_cyl(pod, 0.1, 1.5, Vector3(col, row, 0.0), "gunmetal", Vector3(90, 0, 0), 12)
			_cyl(pod, 0.11, 0.05, Vector3(col, row, -0.74), "steel_dark", Vector3(90, 0, 0), 12)
			_cyl(pod, 0.085, 0.02, Vector3(col, row, -0.77), "hole", Vector3(90, 0, 0), 12)


func _build_fittings() -> void:
	var fit := Kitbash.group(self, "Fittings")
	# exhaust stacks
	for x: float in [-0.6, 0.6]:
		_cyl(fit, 0.06, 0.95, Vector3(x, 1.55, 0.62), "steel_dark", Vector3.ZERO, 10)
		_cyl(fit, 0.085, 0.14, Vector3(x, 2.06, 0.62), "gunmetal", Vector3.ZERO, 10)
		_cyl(fit, 0.06, 0.02, Vector3(x, 2.14, 0.62), "hole", Vector3.ZERO, 10)
	# jerry cans on the deck corners
	_box(fit, Vector3(0.3, 0.42, 0.16), Vector3(-0.68, 1.36, 1.78), "olive")
	_box(fit, Vector3(0.18, 0.05, 0.05), Vector3(-0.68, 1.6, 1.78), "olive")
	_box(fit, Vector3(0.3, 0.42, 0.16), Vector3(0.68, 1.36, 1.78), "rust_orange")
	_box(fit, Vector3(0.18, 0.05, 0.05), Vector3(0.68, 1.6, 1.78), "rust_orange")
	# whip antenna with a rag flag
	_cyl(fit, 0.012, 1.8, Vector3(0.82, 2.2, 1.85), "steel_dark", Vector3.ZERO, 6)
	_box(fit, Vector3(0.36, 0.16, 0.02), Vector3(1.0, 3.0, 1.85), "flag", Vector3(0, 0, -6))


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.cone(parent, radius, height, pos, _m[mat], rot)


func _ball(parent: Node3D, radius: float, pos: Vector3, mat: String,
		scale_by: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return Kitbash.ball(parent, radius, pos, _m[mat], scale_by)
