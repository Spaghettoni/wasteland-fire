## Low-poly wasteland dune buggy assembled from engine primitives at runtime.
##
## Concept model for the Buggy Unit, matched to the "BUGINA" panel of the
## concept sheet (`assets/art/vehicles/vehicle-design.png`): a low teal and
## orange two-tone body with rust flecks, an orange roll cage with a three-lamp
## light bar and a pennant flag, three round headlamps in the nose, an orange
## tube bull bar over a dark skid plate, exposed orange suspension arms and
## coil shocks, big knobby tyres on orange rims, and a bone skull on each door.
## Faces -Z, metres: about 4 m long, 2.4 m wide over the tyres, 1.9 m to the
## light bar and 2.8 m to the flag. Every part is a MeshInstance3D child.
## The armoured variant with spikes and a rocket pod lives next door as
## `wasteland_buggy_armored.gd`.
extends Node3D

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Steering angle of the front wheels, in degrees. Positive turns left.
@export var steer_deg: float = 12.0
## Seed of the procedural paint-chip, rust and grime textures. Same seed, same look.
@export var rust_seed: int = 7

const TUBE_R := 0.045
const WHEEL_R := 0.5
const WHEEL_W := 0.42

var _m: Dictionary = {}


func _ready() -> void:
	_m = Palette.materials(rust_seed)
	_build_body()
	_build_cage()
	_build_bumpers()
	_build_wheels()
	_build_cockpit()


func _build_body() -> void:
	var body := Kitbash.group(self, "Body")
	_box(body, Vector3(1.5, 0.1, 3.3), Vector3(0, 0.38, 0.0), "rust_dark")
	# cabin tub with orange door panels, teal insets and the skull emblems
	_box(body, Vector3(1.5, 0.5, 1.5), Vector3(0, 0.68, 0.3), "teal")
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.04, 0.44, 0.9), Vector3(side * 0.75, 0.68, 0.25), "orange")
		_box(body, Vector3(0.02, 0.3, 0.52), Vector3(side * 0.775, 0.68, 0.3), "teal_dark")
		Kitbash.decal(body, Vector2(0.26, 0.3), Vector3(side * 0.79, 0.68, 0.3), _m["skull"],
				Vector3(0, 90.0 * side, 0))
	# sloping bonnet: a tilted group so its patches, nose plate and lamps share the plane
	var hood := Kitbash.group(body, "Hood")
	hood.position = Vector3(0, 0.64, -1.15)
	hood.rotation_degrees = Vector3(-8, 0, 0)
	_box(hood, Vector3(1.4, 0.34, 1.35), Vector3.ZERO, "teal")
	_box(hood, Vector3(0.52, 0.36, 0.5), Vector3(0.45, 0, -0.4), "orange")
	_box(hood, Vector3(0.5, 0.02, 0.9), Vector3(-0.25, 0.175, 0.0), "orange", Vector3(0, 28, 0))
	_box(hood, Vector3(1.32, 0.34, 0.06), Vector3(0, -0.02, -0.69), "teal_dark")
	for x: float in [-0.38, 0.0, 0.38]:
		_cyl(hood, 0.12, 0.03, Vector3(x, -0.02, -0.71), "orange", Vector3(-90, 0, 0), 12)
		_cyl(hood, 0.1, 0.06, Vector3(x, -0.02, -0.735), "lamp", Vector3(-90, 0, 0), 12)
	# dash between bonnet and tub
	_box(body, Vector3(1.3, 0.16, 0.3), Vector3(0, 0.98, -0.6), "teal_dark")
	# rear deck (engine cover) with a teal patch, a crate and the exhaust
	_box(body, Vector3(1.4, 0.42, 0.75), Vector3(0, 0.64, 1.45), "orange")
	_box(body, Vector3(0.6, 0.02, 0.5), Vector3(-0.3, 0.855, 1.4), "teal", Vector3(0, -20, 0))
	_box(body, Vector3(0.4, 0.34, 0.36), Vector3(0.35, 1.02, 1.45), "orange_dark")
	for yaw: float in [45.0, -45.0]:
		_box(body, Vector3(0.03, 0.02, 0.46), Vector3(0.35, 1.2, 1.45), "rust_dark", Vector3(0, yaw, 0))
	_cyl(body, 0.04, 0.3, Vector3(0.45, 0.5, 1.92), "gunmetal", Vector3(90, 0, 0), 10)
	_cyl(body, 0.03, 0.02, Vector3(0.45, 0.5, 2.075), "hole", Vector3(90, 0, 0), 10)


func _build_cage() -> void:
	var cage := Kitbash.group(self, "Cage")
	var ft := Vector3(0.62, 1.78, -0.35)
	var rt := Vector3(0.62, 1.78, 0.75)
	for side: float in [-1.0, 1.0]:
		var s := Vector3(side, 1, 1)
		_tube(cage, Vector3(0.66, 0.85, -0.9) * s, ft * s)
		_tube(cage, Vector3(0.7, 0.92, 0.98) * s, rt * s)
		_tube(cage, ft * s, rt * s)
		_tube(cage, rt * s, Vector3(0.6, 0.86, 1.7) * s)
		_tube(cage, Vector3(0.72, 0.95, -0.4) * s, Vector3(0.72, 0.95, 1.0) * s)
		_tube(cage, Vector3(0.78, 0.36, -0.5) * s, Vector3(0.78, 0.36, 1.0) * s, 0.035)
	_tube(cage, ft * Vector3(-1, 1, 1), ft)
	_tube(cage, rt * Vector3(-1, 1, 1), rt)
	_tube(cage, Vector3(-0.62, 1.78, 0.3), Vector3(0.62, 1.78, 0.3))
	# light bar with three lamps
	_box(cage, Vector3(1.1, 0.1, 0.12), Vector3(0, 1.87, -0.36), "gunmetal")
	for x: float in [-0.3, 0.0, 0.3]:
		_cyl(cage, 0.085, 0.04, Vector3(x, 1.87, -0.42), "orange", Vector3(-90, 0, 0), 12)
		_cyl(cage, 0.07, 0.06, Vector3(x, 1.87, -0.45), "lamp", Vector3(-90, 0, 0), 12)
	# pennant flag on a whip at the rear right
	_tube(cage, Vector3(0.6, 0.9, 1.6), Vector3(0.6, 2.75, 1.6), 0.015, "steel_dark")
	_box(cage, Vector3(0.55, 0.28, 0.02), Vector3(0.88, 2.6, 1.6), "flag")
	_box(cage, Vector3(0.55, 0.07, 0.024), Vector3(0.88, 2.52, 1.6), "orange_dark")


func _build_bumpers() -> void:
	var bars := Kitbash.group(self, "Bumpers")
	_tube(bars, Vector3(-0.85, 0.5, -2.02), Vector3(0.85, 0.5, -2.02))
	for side: float in [-1.0, 1.0]:
		var end := Vector3(0.85 * side, 0.5, -2.02)
		_tube(bars, end, Vector3(0.72 * side, 0.5, -1.7))
		_tube(bars, Vector3(0, 0.3, -2.0), end)
		_tube(bars, end, Vector3(0.62 * side, 0.75, -1.83), 0.035)
	_box(bars, Vector3(0.9, 0.04, 0.55), Vector3(0, 0.29, -1.78), "rust_dark", Vector3(14, 0, 0))
	_tube(bars, Vector3(-0.7, 0.42, 1.93), Vector3(0.7, 0.42, 1.93))


func _build_wheels() -> void:
	var wheels := Kitbash.group(self, "Wheels")
	var specs: Array = [[-1.0, -1.25, true], [1.0, -1.25, true], [-1.0, 1.25, false], [1.0, 1.25, false]]
	for spec: Array in specs:
		var side: float = spec[0]
		var z: float = spec[1]
		var steers: bool = spec[2]
		var hub_pos := Vector3(side * 1.0, WHEEL_R, z)
		var wheel := Kitbash.group(wheels, "Wheel")
		wheel.position = hub_pos
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
		# exposed suspension: A-arms, an upper link, the axle stub and a coil-over shock
		var s := Vector3(side, 1, 1)
		var knuckle := Vector3(0.8, WHEEL_R, z) * s
		_tube(wheels, Vector3(0.55, 0.42, z - 0.28) * s, knuckle, 0.03)
		_tube(wheels, Vector3(0.55, 0.42, z + 0.28) * s, knuckle, 0.03)
		_tube(wheels, Vector3(0.6, 0.75, z) * s, Vector3(0.8, 0.62, z) * s, 0.03)
		_tube(wheels, knuckle, hub_pos, 0.04, "gunmetal")
		var shock_lo := Vector3(0.82, 0.58, z + 0.06) * s
		var shock_hi := Vector3(0.6, 1.05, z + 0.14) * s
		_tube(wheels, shock_lo, shock_hi, 0.022, "steel_dark")
		_tube(wheels, shock_lo.lerp(shock_hi, 0.25), shock_lo.lerp(shock_hi, 0.75), 0.05, "orange")


func _build_cockpit() -> void:
	var cab := Kitbash.group(self, "Cockpit")
	for x: float in [-0.32, 0.32]:
		_box(cab, Vector3(0.5, 0.36, 0.5), Vector3(x, 0.78, 0.35), "leather")
		_box(cab, Vector3(0.5, 0.62, 0.12), Vector3(x, 1.18, 0.62), "leather", Vector3(-10, 0, 0))
	Kitbash.torus(cab, 0.11, 0.15, Vector3(-0.32, 1.06, -0.32), _m["gunmetal"], Vector3(65, 0, 0))
	_tube(cab, Vector3(-0.32, 0.92, -0.55), Vector3(-0.32, 1.04, -0.34), 0.02, "gunmetal")


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _tube(parent: Node3D, from: Vector3, to: Vector3, radius: float = TUBE_R,
		mat: String = "orange") -> MeshInstance3D:
	return Kitbash.tube(parent, from, to, radius, _m[mat])
