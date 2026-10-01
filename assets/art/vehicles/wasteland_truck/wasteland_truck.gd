## Low-poly wasteland pickup truck assembled from engine primitives at runtime.
##
## Concept model matched to the "TRUCK" panel of the concept sheet
## (`assets/art/vehicles/vehicle-design.png`): a lifted pickup on big knobby
## tyres with orange rims, an orange bonnet with a teal patch over a dark
## barred grille, a spiked dark bumper over a skid plate, twin headlamps, a
## teal cab wearing the bone skull on each door, a four-lamp light bar and a
## four-tube rocket pod on the roof, a whip antenna, and a teal bed with orange
## rails, a cargo rack, crates and a drum. Not a Unit in the brief; built
## because it is on the sheet. Faces -Z, metres: about 5.3 m long, 2.4 m wide,
## 2.2 m to the roof and 3.1 m to the pod.
extends Node3D

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Yaw of the roof pod about its turret ring, in degrees. 0 points forward.
@export var pod_yaw_deg: float = 25.0
## Elevation of the roof pod above the horizon, in degrees.
@export var pod_pitch_deg: float = 22.0
## Steering angle of the front wheels, in degrees. Positive turns left.
@export var steer_deg: float = 10.0
## Seed of the procedural paint-chip, rust and grime textures. Same seed, same look.
@export var rust_seed: int = 3

const WHEEL_R := 0.52
const WHEEL_W := 0.45
const TUBE_R := 0.04

var _m: Dictionary = {}


func _ready() -> void:
	_m = Palette.materials(rust_seed)
	_build_chassis()
	_build_front()
	_build_cab()
	_build_bed()
	_build_turret()
	_build_wheels()


func _build_chassis() -> void:
	var ch := Kitbash.group(self, "Chassis")
	_box(ch, Vector3(1.4, 0.16, 4.8), Vector3(0, 0.68, 0.05), "rust_dark")
	for z: float in [-1.55, 1.65]:
		Kitbash.tube(ch, Vector3(-0.98, WHEEL_R, z), Vector3(0.98, WHEEL_R, z), 0.06, _m["gunmetal"])
	# aprons under the bonnet, the cab and the bed
	_box(ch, Vector3(1.5, 0.25, 1.5), Vector3(0, 0.875, -1.72), "orange_dark")
	_box(ch, Vector3(1.9, 0.26, 1.5), Vector3(0, 0.88, -0.2), "orange_dark")
	_box(ch, Vector3(1.48, 0.34, 2.0), Vector3(0, 0.92, 1.55), "orange_dark")
	# running boards, rear bumper and exhaust
	for side: float in [-1.0, 1.0]:
		_box(ch, Vector3(0.3, 0.06, 1.3), Vector3(side * 1.1, 0.8, -0.2), "steel_dark")
	_box(ch, Vector3(2.0, 0.24, 0.24), Vector3(0, 0.7, 2.62), "rust_dark")
	_cyl(ch, 0.05, 0.4, Vector3(0.7, 0.6, 2.6), "gunmetal", Vector3(90, 0, 0), 8)
	_cyl(ch, 0.038, 0.02, Vector3(0.7, 0.6, 2.81), "hole", Vector3(90, 0, 0), 8)


func _build_front() -> void:
	var front := Kitbash.group(self, "Front")
	# orange bonnet with a teal patch and stripe, fenders over the wheels
	_box(front, Vector3(1.9, 0.45, 1.55), Vector3(0, 1.22, -1.72), "orange")
	_box(front, Vector3(0.92, 0.47, 0.7), Vector3(-0.5, 1.22, -1.55), "teal")
	_box(front, Vector3(0.6, 0.02, 0.9), Vector3(0.45, 1.455, -1.8), "teal", Vector3(0, -22, 0))
	for side: float in [-1.0, 1.0]:
		_box(front, Vector3(0.42, 0.34, 1.7), Vector3(side * 1.0, 1.22, -1.65), "orange")
	# barred grille and headlamps in orange bezels
	_box(front, Vector3(1.6, 0.4, 0.06), Vector3(0, 1.18, -2.51), "gunmetal")
	for i in 7:
		_box(front, Vector3(0.05, 0.36, 0.05), Vector3(-0.6 + i * 0.2, 1.18, -2.545), "steel_dark")
	for side: float in [-1.0, 1.0]:
		_cyl(front, 0.15, 0.04, Vector3(side * 0.95, 1.22, -2.5), "orange", Vector3(-90, 0, 0), 14)
		_cyl(front, 0.12, 0.08, Vector3(side * 0.95, 1.22, -2.53), "lamp", Vector3(-90, 0, 0), 14)
	# spiked bumper over a skid plate
	_box(front, Vector3(2.3, 0.32, 0.3), Vector3(0, 0.66, -2.6), "rust_dark")
	for i in 7:
		_cone(front, 0.06, 0.42, Vector3(-1.02 + i * 0.34, 0.66, -2.96), "steel", Vector3(-90, 0, 0))
	_box(front, Vector3(1.4, 0.05, 0.6), Vector3(0, 0.45, -2.45), "rust_dark", Vector3(12, 0, 0))
	# whip antenna on the left fender
	Kitbash.tube(front, Vector3(-1.05, 1.39, -1.95), Vector3(-1.05, 2.9, -1.95), 0.012,
			_m["steel_dark"])


func _build_cab() -> void:
	var cab := Kitbash.group(self, "Cab")
	_box(cab, Vector3(2.0, 0.62, 1.5), Vector3(0, 1.31, -0.2), "teal")
	_box(cab, Vector3(1.9, 0.5, 1.2), Vector3(0, 1.85, -0.05), "teal")
	_box(cab, Vector3(1.94, 0.06, 1.24), Vector3(0, 2.11, -0.05), "orange")
	# windscreen between orange pillars, side and rear glass, door skulls, mirrors
	_box(cab, Vector3(1.7, 0.58, 0.04), Vector3(0, 1.85, -0.8), "glass", Vector3(31, 0, 0))
	for side: float in [-1.0, 1.0]:
		_box(cab, Vector3(0.12, 0.58, 0.07), Vector3(side * 0.9, 1.85, -0.8), "orange", Vector3(31, 0, 0))
		_box(cab, Vector3(0.02, 0.38, 0.5), Vector3(side * 0.95, 1.85, 0.05), "glass")
		Kitbash.decal(cab, Vector2(0.4, 0.44), Vector3(side * 1.005, 1.33, -0.05), _m["skull"],
				Vector3(0, 90.0 * side, 0))
		_box(cab, Vector3(0.02, 0.1, 1.4), Vector3(side * 1.0, 1.06, -0.2), "orange")
		Kitbash.tube(cab, Vector3(side * 1.0, 1.7, -0.7), Vector3(side * 1.18, 1.78, -0.7), 0.015,
				_m["gunmetal"])
		_box(cab, Vector3(0.06, 0.16, 0.12), Vector3(side * 1.2, 1.8, -0.7), "gunmetal")
	_box(cab, Vector3(1.4, 0.36, 0.02), Vector3(0, 1.85, 0.56), "glass")
	# roof light bar with four lamps
	_box(cab, Vector3(1.7, 0.1, 0.14), Vector3(0, 2.19, -0.6), "gunmetal")
	for x: float in [-0.6, -0.2, 0.2, 0.6]:
		_cyl(cab, 0.09, 0.04, Vector3(x, 2.19, -0.68), "orange", Vector3(-90, 0, 0), 12)
		_cyl(cab, 0.075, 0.06, Vector3(x, 2.19, -0.71), "lamp", Vector3(-90, 0, 0), 12)


func _build_bed() -> void:
	var bed := Kitbash.group(self, "Bed")
	_box(bed, Vector3(1.9, 0.12, 2.0), Vector3(0, 1.14, 1.55), "teal_dark")
	for side: float in [-1.0, 1.0]:
		_box(bed, Vector3(0.08, 0.5, 2.0), Vector3(side * 0.96, 1.45, 1.55), "teal")
		_box(bed, Vector3(0.12, 0.05, 2.0), Vector3(side * 0.96, 1.72, 1.55), "orange")
		_box(bed, Vector3(0.42, 0.3, 1.5), Vector3(side * 1.0, 1.2, 1.65), "teal")
	_box(bed, Vector3(1.9, 0.5, 0.08), Vector3(0, 1.45, 2.51), "teal")
	_box(bed, Vector3(1.92, 0.12, 0.09), Vector3(0, 1.62, 2.51), "orange")
	# cargo rack: a headache rack behind the cab and rails over the bed
	var rack: Array = [
		[Vector3(-0.9, 1.72, 0.62), Vector3(-0.9, 2.35, 0.62)],
		[Vector3(0.9, 1.72, 0.62), Vector3(0.9, 2.35, 0.62)],
		[Vector3(-0.9, 2.35, 0.62), Vector3(0.9, 2.35, 0.62)],
		[Vector3(-0.9, 1.72, 2.45), Vector3(-0.9, 2.1, 2.45)],
		[Vector3(0.9, 1.72, 2.45), Vector3(0.9, 2.1, 2.45)],
		[Vector3(-0.9, 2.35, 0.62), Vector3(-0.9, 2.1, 2.45)],
		[Vector3(0.9, 2.35, 0.62), Vector3(0.9, 2.1, 2.45)],
		[Vector3(-0.9, 2.1, 2.45), Vector3(0.9, 2.1, 2.45)],
	]
	for seg: Array in rack:
		Kitbash.tube(bed, seg[0], seg[1], TUBE_R, _m["orange"])
	# crates and a drum in the bed
	_crate(bed, Vector3(-0.45, 1.46, 1.35), 0.6)
	_crate(bed, Vector3(0.4, 1.42, 1.0), 0.5)
	_cyl(bed, 0.24, 0.7, Vector3(0.35, 1.44, 2.05), "rust_orange", Vector3(0, 0, 90), 12)


func _build_turret() -> void:
	var turret := Kitbash.group(self, "Turret")
	turret.position = Vector3(0, 2.14, -0.1)
	_cyl(turret, 0.36, 0.1, Vector3.ZERO, "gunmetal", Vector3.ZERO, 20)
	var yaw := Kitbash.group(turret, "Yaw")
	yaw.rotation_degrees = Vector3(0, pod_yaw_deg, 0)
	_cyl(yaw, 0.15, 0.3, Vector3(0, 0.15, 0), "steel_dark", Vector3.ZERO, 12)
	_box(yaw, Vector3(0.9, 0.08, 0.3), Vector3(0, 0.32, 0), "gunmetal")
	for x: float in [-0.42, 0.42]:
		_box(yaw, Vector3(0.08, 0.4, 0.3), Vector3(x, 0.5, 0), "gunmetal")
	for x: float in [-0.4, 0.4]:
		_cyl(yaw, 0.05, 0.1, Vector3(x, 0.64, 0), "steel", Vector3(0, 0, 90), 8)
	# four-tube pod with orange bands, pitching about the trunnions
	var pod := Kitbash.group(yaw, "Pod")
	pod.position = Vector3(0, 0.64, 0)
	pod.rotation_degrees = Vector3(pod_pitch_deg, 0, 0)
	_box(pod, Vector3(0.7, 0.42, 1.0), Vector3.ZERO, "gunmetal")
	for z: float in [-0.3, 0.3]:
		_box(pod, Vector3(0.72, 0.44, 0.14), Vector3(0, 0, z), "orange")
	for row: float in [-0.1, 0.1]:
		for col: float in [-0.17, 0.17]:
			_cyl(pod, 0.085, 1.2, Vector3(col, row, 0), "gunmetal", Vector3(90, 0, 0), 12)
			_cyl(pod, 0.095, 0.04, Vector3(col, row, -0.6), "steel_dark", Vector3(90, 0, 0), 12)
			_cyl(pod, 0.07, 0.02, Vector3(col, row, -0.62), "hole", Vector3(90, 0, 0), 12)


func _build_wheels() -> void:
	var wheels := Kitbash.group(self, "Wheels")
	var specs: Array = [[-1.0, -1.55, true], [1.0, -1.55, true], [-1.0, 1.65, false], [1.0, 1.65, false]]
	for spec: Array in specs:
		var side: float = spec[0]
		var z: float = spec[1]
		var steers: bool = spec[2]
		var wheel := Kitbash.group(wheels, "Wheel")
		wheel.position = Vector3(side * 0.98, WHEEL_R, z)
		if steers:
			wheel.rotation_degrees = Vector3(0, steer_deg, 0)
		_cyl(wheel, WHEEL_R, WHEEL_W, Vector3.ZERO, "rubber", Vector3(0, 0, 90), 20)
		_cyl(wheel, WHEEL_R * 0.56, WHEEL_W + 0.02, Vector3.ZERO, "rim", Vector3(0, 0, 90), 16)
		_cyl(wheel, WHEEL_R * 0.2, WHEEL_W + 0.08, Vector3.ZERO, "gunmetal", Vector3(0, 0, 90), 10)
		for k in 14:
			var a := k * 360.0 / 14.0
			var rad := deg_to_rad(a)
			_box(wheel, Vector3(WHEEL_W * 0.85, 0.08, 0.12),
					(WHEEL_R + 0.02) * Vector3(0, cos(rad), sin(rad)), "tread", Vector3(a, 0, 0))


## Orange crate of side [param s] with a dark X on the lid.
func _crate(parent: Node3D, pos: Vector3, s: float) -> void:
	_box(parent, Vector3(s, s * 0.8, s), pos, "orange")
	for yaw: float in [45.0, -45.0]:
		_box(parent, Vector3(0.03, 0.02, s * 0.9), pos + Vector3(0, s * 0.4 + 0.01, 0), "rust_dark",
				Vector3(0, yaw, 0))


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.cone(parent, radius, height, pos, _m[mat], rot)
