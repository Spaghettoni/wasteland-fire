## Low-poly wasteland motorbike assembled from engine primitives at runtime.
##
## Concept model for the Motorbike Unit, matched to the "MOTORKA" panel of the
## concept sheet (`assets/art/vehicles/vehicle-design.png`): an orange tube
## frame and fork, a teal tank wearing the bone skull, a round headlamp in an
## orange bezel, flat black bars, a dark V-twin, big knobby tyres on orange
## rims, a brown saddle with an orange tail, a small two-tone fender at each
## end and a pair of spikes on the tail. Faces -Z, metres: about 2.3 m long,
## 1.15 m to the bars.
extends Node3D

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Steering angle of the front wheel about the fork axis, in degrees. Positive turns left.
@export var steer_deg: float = 14.0
## Lean of the whole bike onto its kickstand side, in degrees. 0 stands upright.
@export var lean_deg: float = 0.0
## Seed of the procedural paint-chip, rust and grime textures. Same seed, same look.
@export var rust_seed: int = 11

## Fork angle back from vertical, in degrees.
const RAKE_DEG := 31.6
## Steering head, in bike space. The fork axis runs from here to FRONT_AXLE.
const HEAD := Vector3(0.0, 0.88, -0.50)
const FRONT_AXLE := Vector3(0.0, 0.36, -0.82)
const FRONT_R := 0.36
const REAR_AXLE := Vector3(0.0, 0.40, 0.72)
const REAR_R := 0.40

var _m: Dictionary = {}


func _ready() -> void:
	_m = Palette.materials(rust_seed)
	rotation_degrees = Vector3(0, 0, lean_deg)
	_build_frame()
	_build_engine()
	_build_body()
	_build_rear()
	_build_front()
	_build_exhausts()


func _build_frame() -> void:
	var frame := Kitbash.group(self, "Frame")
	# spine from the steering head back over the engine; down tube to the cradle
	_box(frame, Vector3(0.09, 0.09, 0.86), Vector3(0, 0.83, -0.075), "orange", Vector3(6.7, 0, 0))
	_box(frame, Vector3(0.08, 0.08, 0.59), Vector3(0, 0.615, -0.375), "orange", Vector3(64.7, 0, 0))
	_cyl(frame, 0.05, 0.22, HEAD, "orange_dark", Vector3(RAKE_DEG, 0, 0), 10)
	# cradle rails under the engine, seat rails, and the tubes joining them
	for x: float in [-0.13, 0.13]:
		_box(frame, Vector3(0.05, 0.05, 0.6), Vector3(x, 0.30, 0.0), "orange")
		_box(frame, Vector3(0.05, 0.05, 0.62), Vector3(x, 0.76, 0.35), "orange")
		_box(frame, Vector3(0.05, 0.46, 0.05), Vector3(x, 0.53, 0.25), "orange")
	# kickstand and foot pegs
	_cyl(frame, 0.012, 0.44, Vector3(-0.2, 0.19, 0.27), "gunmetal", Vector3(0, 0, 152.0), 6)
	_box(frame, Vector3(0.06, 0.02, 0.06), Vector3(-0.3, 0.01, 0.27), "gunmetal")
	for x: float in [-0.2, 0.2]:
		_cyl(frame, 0.015, 0.14, Vector3(x, 0.30, 0.1), "gunmetal", Vector3(0, 0, 90), 6)


func _build_engine() -> void:
	var engine := Kitbash.group(self, "Engine")
	_box(engine, Vector3(0.3, 0.3, 0.4), Vector3(0, 0.42, 0.0), "gunmetal")
	# V-twin heads with cooling fins
	for spec: Array in [[-0.16, -22.0], [0.14, 22.0]]:
		var z: float = spec[0]
		var tilt: float = spec[1]
		var head := Kitbash.group(engine, "Cylinder")
		head.position = Vector3(0, 0.62, z)
		head.rotation_degrees = Vector3(tilt, 0, 0)
		_cyl(head, 0.085, 0.22, Vector3.ZERO, "steel_dark", Vector3.ZERO, 12)
		for i in 4:
			_box(head, Vector3(0.24, 0.015, 0.24), Vector3(0, -0.08 + i * 0.05, 0), "gunmetal")
	# crankcase covers and teal side panels under the saddle
	for x: float in [-0.17, 0.17]:
		_cyl(engine, 0.11, 0.05, Vector3(x, 0.4, 0.0), "steel_dark", Vector3(0, 0, 90), 14)
		_box(engine, Vector3(0.02, 0.22, 0.25), Vector3(x, 0.6, 0.33), "teal")


func _build_body() -> void:
	var body := Kitbash.group(self, "Body")
	# teal tank with an orange top patch, the cap, and a skull on each flank
	_box(body, Vector3(0.34, 0.26, 0.56), Vector3(0, 0.88, -0.1), "teal")
	_box(body, Vector3(0.36, 0.02, 0.28), Vector3(0, 1.015, 0.03), "orange")
	_cyl(body, 0.04, 0.03, Vector3(0, 1.03, -0.22), "steel", Vector3.ZERO, 10)
	for side: float in [-1.0, 1.0]:
		Kitbash.decal(body, Vector2(0.2, 0.22), Vector3(side * 0.175, 0.87, -0.1), _m["skull"],
				Vector3(0, 90.0 * side, 0))
	# saddle with an orange tail cowl
	_box(body, Vector3(0.28, 0.08, 0.46), Vector3(0, 0.83, 0.36), "leather")
	_box(body, Vector3(0.26, 0.1, 0.28), Vector3(0, 0.86, 0.72), "orange")
	_box(body, Vector3(0.27, 0.02, 0.1), Vector3(0, 0.915, 0.8), "teal")


func _build_rear() -> void:
	var rear := Kitbash.group(self, "Rear")
	_wheel(rear, REAR_AXLE, REAR_R, 0.22, 12)
	# swingarm, sprocket and shocks with orange springs
	for x: float in [-0.15, 0.15]:
		_box(rear, Vector3(0.05, 0.06, 0.6), Vector3(x, 0.40, 0.44), "orange")
	_cyl(rear, 0.13, 0.02, REAR_AXLE + Vector3(-0.19, 0, 0), "steel_dark", Vector3(0, 0, 90), 16)
	for x: float in [-0.16, 0.16]:
		_cyl(rear, 0.022, 0.42, Vector3(x, 0.60, 0.53), "steel_dark", Vector3(-25.0, 0, 0), 8)
		_cyl(rear, 0.038, 0.22, Vector3(x, 0.60, 0.53), "orange", Vector3(-25.0, 0, 0), 8)
	# small two-tone fender over the wheel with a pair of tail spikes
	var arch_r := REAR_R + 0.08
	var fender_mats: Array = ["teal", "teal", "orange"]
	var angles: Array = [15.0, 45.0, 75.0]
	for i in 3:
		var rad := deg_to_rad(angles[i])
		_box(rear, Vector3(0.3, 0.04, 0.27), REAR_AXLE + arch_r * Vector3(0, cos(rad), sin(rad)),
				fender_mats[i], Vector3(angles[i], 0, 0))
	for b: float in [40.0, 68.0]:
		var rad := deg_to_rad(b)
		var radial := Vector3(0, cos(rad), sin(rad))
		_cone(rear, 0.025, 0.22, REAR_AXLE + (arch_r + 0.13) * radial, "steel", Vector3(b, 0, 0))


func _build_front() -> void:
	# Rake tilts local Y onto the fork axis; Steer turns about it; Level undoes
	# the tilt so world-aligned parts can be placed as plain offsets from the head.
	var rake := Kitbash.group(self, "Rake")
	rake.position = HEAD
	rake.rotation_degrees = Vector3(RAKE_DEG, 0, 0)
	var steer := Kitbash.group(rake, "Steer")
	steer.rotation_degrees = Vector3(0, steer_deg, 0)
	var level := Kitbash.group(steer, "Level")
	level.rotation_degrees = Vector3(-RAKE_DEG, 0, 0)
	# orange fork tubes over dark sliders, stem, clamps, risers, flat bars and grips
	var fork_len := HEAD.distance_to(FRONT_AXLE)
	for x: float in [-0.09, 0.09]:
		_cyl(steer, 0.035, 0.85, Vector3(x, -fork_len + 0.425, 0), "orange", Vector3.ZERO, 10)
		_cyl(steer, 0.042, 0.36, Vector3(x, -fork_len + 0.18, 0), "gunmetal", Vector3.ZERO, 10)
	_cyl(steer, 0.04, 0.2, Vector3(0, 0.08, 0), "gunmetal", Vector3.ZERO, 10)
	_box(steer, Vector3(0.3, 0.04, 0.12), Vector3(0, 0.2, 0), "gunmetal")
	_box(steer, Vector3(0.3, 0.04, 0.12), Vector3(0, -0.05, 0), "gunmetal")
	for x: float in [-0.08, 0.08]:
		_cyl(steer, 0.02, 0.1, Vector3(x, 0.26, 0), "gunmetal", Vector3.ZERO, 8)
	_cyl(steer, 0.016, 0.7, Vector3(0, 0.32, 0), "gunmetal", Vector3(0, 0, 90), 8)
	for x: float in [-0.3, 0.3]:
		_cyl(steer, 0.026, 0.13, Vector3(x, 0.32, 0), "rubber", Vector3(0, 0, 90), 8)
	# wheel, small two-tone fender and the round headlamp in its orange bezel
	var wheel_c := FRONT_AXLE - HEAD
	_wheel(level, wheel_c, FRONT_R, 0.12, 8)
	var arch_r := FRONT_R + 0.07
	var fender_mats: Array = ["teal", "orange", "orange"]
	var angles: Array = [5.0, 33.0, 61.0]
	for i in 3:
		var rad := deg_to_rad(angles[i])
		_box(level, Vector3(0.22, 0.03, 0.24), wheel_c + arch_r * Vector3(0, cos(rad), -sin(rad)),
				fender_mats[i], Vector3(-angles[i], 0, 0))
	_cyl(level, 0.125, 0.1, Vector3(0, -0.02, -0.15), "gunmetal", Vector3(-90, 0, 0), 14)
	_cyl(level, 0.11, 0.06, Vector3(0, -0.02, -0.225), "lamp", Vector3(-90, 0, 0), 14)
	_cyl(level, 0.135, 0.03, Vector3(0, -0.02, -0.235), "orange", Vector3(-90, 0, 0), 14)


func _build_exhausts() -> void:
	var pipes := Kitbash.group(self, "Exhausts")
	# right side: header off the front cylinder, low pipe back to a flared tip
	_cyl(pipes, 0.03, 0.14, Vector3(0.12, 0.56, -0.2), "gunmetal", Vector3(0, 0, 90), 8)
	_cyl(pipes, 0.03, 0.4, Vector3(0.19, 0.412, -0.08), "gunmetal", Vector3(140.6, 0, 0), 8)
	_cyl(pipes, 0.03, 0.92, Vector3(0.2, 0.26, 0.5), "gunmetal", Vector3(90, 0, 0), 8)
	_cyl(pipes, 0.045, 0.12, Vector3(0.2, 0.26, 0.99), "steel_dark", Vector3(90, 0, 0), 8)
	_cyl(pipes, 0.032, 0.02, Vector3(0.2, 0.26, 1.055), "hole", Vector3(90, 0, 0), 8)
	# left side: header off the rear cylinder, upswept shotgun pipe
	_cyl(pipes, 0.03, 0.3, Vector3(-0.16, 0.56, 0.2), "gunmetal", Vector3(0, 0, 90), 8)
	_cyl(pipes, 0.03, 0.81, Vector3(-0.24, 0.67, 0.59), "gunmetal", Vector3(74.2, 0, 0), 8)
	_cyl(pipes, 0.045, 0.12, Vector3(-0.24, 0.796, 1.04), "steel_dark", Vector3(74.2, 0, 0), 8)
	_cyl(pipes, 0.032, 0.02, Vector3(-0.24, 0.814, 1.1), "hole", Vector3(74.2, 0, 0), 8)


## Spoked wheel: a torus tyre with lugs, an orange rim ring, a hub, six spokes
## and an axle nut.
func _wheel(parent: Node3D, pos: Vector3, r: float, w: float, lugs: int) -> Node3D:
	var wheel := Kitbash.group(parent, "Wheel")
	wheel.position = pos
	Kitbash.torus(wheel, r - w, r, Vector3.ZERO, _m["rubber"], Vector3(0, 0, 90))
	Kitbash.torus(wheel, r - w - 0.05, r - w + 0.01, Vector3.ZERO, _m["rim"], Vector3(0, 0, 90))
	_cyl(wheel, r * 0.2, w + 0.04, Vector3.ZERO, "gunmetal", Vector3(0, 0, 90), 12)
	_cyl(wheel, 0.045, w + 0.12, Vector3.ZERO, "steel", Vector3(0, 0, 90), 8)
	for k in 6:
		_cyl(wheel, 0.011, (r - w - 0.05) * 2.0 + 0.04, Vector3.ZERO, "steel_dark",
				Vector3(k * 30.0, 0, 0), 6)
	for k in lugs:
		var a := k * 360.0 / lugs
		var rad := deg_to_rad(a)
		_box(wheel, Vector3(w * 0.9, 0.07, 0.1), (r + 0.02) * Vector3(0, cos(rad), sin(rad)),
				"tread", Vector3(a, 0, 0))
	return wheel


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.cone(parent, radius, height, pos, _m[mat], rot)
