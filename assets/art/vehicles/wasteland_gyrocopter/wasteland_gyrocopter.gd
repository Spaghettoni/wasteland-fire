## Low-poly wasteland gyrocopter assembled from engine primitives at runtime.
##
## Concept model for the Gyrocopter Unit, matched to the "GYROKOPTERA" panel of
## the concept sheet (`assets/art/vehicles/vehicle-design.png`): an open orange
## tube frame with a mast and braces, a two-blade teal rotor with orange tips on
## a teetering head, a teal nose pod with an orange face and a pale windscreen,
## a saddle behind an instrument panel, a dark engine driving a three-blade
## pusher propeller, a tail boom ending in a teal and orange stabiliser and a
## fin wearing the bone skull, and tricycle gear on orange outriggers with
## small knobby wheels on orange rims. Faces -Z, metres: about 3.6 m long,
## 7.3 m across the rotor, 2.4 m to the rotor head.
extends Node3D

const Palette := preload("res://assets/art/shared/wasteland_palette.gd")
const Kitbash := preload("res://assets/art/shared/kitbash.gd")

## Yaw of the rotor about the mast, in degrees. 0 lies across the frame.
@export var rotor_yaw_deg: float = 25.0
## Backward tilt of the rotor disc, in degrees, as it rests on the ground.
@export var rotor_tilt_deg: float = 6.0
## Seed of the procedural paint-chip, rust and grime textures. Same seed, same look.
@export var rust_seed: int = 5

const TUBE_R := 0.045
const KEEL_Y := 0.5
const MAST_TOP := Vector3(0.0, 2.2, -0.1)

var _m: Dictionary = {}


func _ready() -> void:
	_m = Palette.materials(rust_seed)
	_build_frame()
	_build_pod()
	_build_engine()
	_build_tail()
	_build_gear()
	_build_rotor()


func _build_frame() -> void:
	var frame := Kitbash.group(self, "Frame")
	# keel, mast and the two mast braces
	_tube(frame, Vector3(0, KEEL_Y, -1.25), Vector3(0, KEEL_Y, 2.0), 0.05)
	_tube(frame, Vector3(0, KEEL_Y, -0.1), MAST_TOP, 0.05)
	_tube(frame, MAST_TOP + Vector3(0, -0.12, 0), Vector3(0, KEEL_Y + 0.05, -1.05), 0.03, "orange_dark")
	_tube(frame, MAST_TOP + Vector3(0, -0.12, 0), Vector3(0, KEEL_Y + 0.05, 0.85), 0.03, "orange_dark")
	# cockpit floor rails
	for side: float in [-1.0, 1.0]:
		_tube(frame, Vector3(side * 0.3, KEEL_Y, -1.0), Vector3(side * 0.3, KEEL_Y, 0.7), 0.03)
		_tube(frame, Vector3(side * 0.3, KEEL_Y, -1.0), Vector3(0, KEEL_Y, -1.25), 0.03)
		_tube(frame, Vector3(side * 0.3, KEEL_Y, 0.7), Vector3(0, KEEL_Y, 0.95), 0.03)


func _build_pod() -> void:
	var pod := Kitbash.group(self, "Pod")
	# teal nose tub with an orange face, flank stripes and a pale windscreen
	_box(pod, Vector3(0.62, 0.36, 1.0), Vector3(0, 0.7, -0.6), "teal")
	_box(pod, Vector3(0.5, 0.3, 0.3), Vector3(0, 0.66, -1.2), "orange")
	_box(pod, Vector3(0.64, 0.14, 0.4), Vector3(0, 0.82, -0.85), "orange")
	for side: float in [-1.0, 1.0]:
		_box(pod, Vector3(0.02, 0.1, 0.7), Vector3(side * 0.32, 0.64, -0.55), "orange")
	_box(pod, Vector3(0.56, 0.5, 0.03), Vector3(0, 1.1, -0.93), "screen", Vector3(28, 0, 0))
	_box(pod, Vector3(0.44, 0.16, 0.05), Vector3(0, 0.98, -0.62), "gunmetal")
	# fuel tank under the saddle, the saddle and its backrest
	_box(pod, Vector3(0.5, 0.25, 0.5), Vector3(0, 0.62, 0.35), "orange")
	_box(pod, Vector3(0.5, 0.1, 0.5), Vector3(0, 0.78, 0.35), "leather")
	_box(pod, Vector3(0.5, 0.55, 0.1), Vector3(0, 1.05, 0.62), "leather", Vector3(12, 0, 0))


func _build_engine() -> void:
	var eng := Kitbash.group(self, "Engine")
	# pylon up from the keel, finned block, exhaust stub
	_box(eng, Vector3(0.14, 0.62, 0.24), Vector3(0, 0.85, 0.95), "orange_dark")
	_box(eng, Vector3(0.46, 0.42, 0.42), Vector3(0, 1.35, 0.95), "gunmetal")
	for i in 3:
		_box(eng, Vector3(0.5, 0.015, 0.3), Vector3(0, 1.22 + i * 0.1, 0.95), "steel_dark")
	_cyl(eng, 0.045, 0.3, Vector3(0.24, 1.22, 1.05), "gunmetal", Vector3(90, 0, 0), 8)
	# three-blade pusher propeller behind the block
	_cyl(eng, 0.08, 0.14, Vector3(0, 1.35, 1.23), "gunmetal", Vector3(90, 0, 0), 10)
	var prop := Kitbash.group(eng, "Prop")
	prop.position = Vector3(0, 1.35, 1.29)
	prop.rotation_degrees = Vector3(0, 0, 20)
	for k in 3:
		var blade := Kitbash.group(prop, "Blade")
		blade.rotation_degrees = Vector3(0, 0, k * 120.0)
		_box(blade, Vector3(0.1, 0.62, 0.025), Vector3(0, 0.37, 0), "steel_dark")
		_box(blade, Vector3(0.1, 0.14, 0.027), Vector3(0, 0.71, 0), "orange")


func _build_tail() -> void:
	var tail := Kitbash.group(self, "Tail")
	# riser, stabiliser with orange tips, fin with the skull on both faces, skid
	_tube(tail, Vector3(0, KEEL_Y, 1.95), Vector3(0, 0.66, 1.95), 0.04)
	_box(tail, Vector3(1.4, 0.03, 0.42), Vector3(0, 0.66, 1.95), "teal")
	for side: float in [-1.0, 1.0]:
		_box(tail, Vector3(0.32, 0.034, 0.42), Vector3(side * 0.55, 0.66, 1.95), "orange")
	_box(tail, Vector3(0.03, 0.85, 0.5), Vector3(0, 1.1, 2.0), "orange")
	_box(tail, Vector3(0.034, 0.5, 0.36), Vector3(0, 1.05, 2.0), "teal")
	for side: float in [-1.0, 1.0]:
		Kitbash.decal(tail, Vector2(0.24, 0.28), Vector3(side * 0.022, 1.05, 2.0), _m["skull"],
				Vector3(0, 90.0 * side, 0))
	_tube(tail, Vector3(0, KEEL_Y, 1.9), Vector3(0, 0.22, 2.15), 0.025, "steel_dark")


func _build_gear() -> void:
	var gear := Kitbash.group(self, "Gear")
	# main wheels on V outriggers, nose wheel on a short leg
	for side: float in [-1.0, 1.0]:
		var hub := Vector3(side * 0.95, 0.25, 0.4)
		_tube(gear, Vector3(0, KEEL_Y, 0.1), hub, 0.035)
		_tube(gear, Vector3(0, KEEL_Y, 0.8), hub, 0.035)
		_cyl(gear, 0.03, 0.22, hub, "gunmetal", Vector3(0, 0, 90), 8)
		_wheel(gear, hub, 0.25, 0.12, 8)
	_tube(gear, Vector3(0, KEEL_Y, -1.1), Vector3(0, 0.2, -1.15), 0.03)
	_wheel(gear, Vector3(0, 0.2, -1.15), 0.2, 0.1, 8)


func _build_rotor() -> void:
	# Tilt rocks the whole disc back about the frame's X axis; Rotor then yaws
	# the blades within that tilted disc, so the tilt stays fore-and-aft.
	var head := Kitbash.group(self, "RotorHead")
	head.position = MAST_TOP + Vector3(0, 0.06, 0)
	_cyl(head, 0.09, 0.12, Vector3.ZERO, "gunmetal", Vector3.ZERO, 10)
	var tilt := Kitbash.group(head, "Tilt")
	tilt.position = Vector3(0, 0.12, 0)
	tilt.rotation_degrees = Vector3(rotor_tilt_deg, 0, 0)
	var rotor := Kitbash.group(tilt, "Rotor")
	rotor.rotation_degrees = Vector3(0, rotor_yaw_deg, 0)
	_box(rotor, Vector3(0.5, 0.08, 0.16), Vector3.ZERO, "steel_dark")
	for side: float in [-1.0, 1.0]:
		var blade := Kitbash.group(rotor, "Blade")
		blade.rotation_degrees = Vector3(0, 0, 2.5 * side)
		_box(blade, Vector3(2.7, 0.03, 0.26), Vector3(side * 1.6, 0, 0), "teal")
		_box(blade, Vector3(0.7, 0.032, 0.27), Vector3(side * 3.3, 0, 0), "orange")


## Small knobby wheel on an orange rim.
func _wheel(parent: Node3D, pos: Vector3, r: float, w: float, lugs: int) -> Node3D:
	var wheel := Kitbash.group(parent, "Wheel")
	wheel.position = pos
	_cyl(wheel, r, w, Vector3.ZERO, "rubber", Vector3(0, 0, 90), 16)
	_cyl(wheel, r * 0.55, w + 0.02, Vector3.ZERO, "rim", Vector3(0, 0, 90), 12)
	_cyl(wheel, r * 0.2, w + 0.06, Vector3.ZERO, "gunmetal", Vector3(0, 0, 90), 8)
	for k in lugs:
		var a := k * 360.0 / lugs
		var rad := deg_to_rad(a)
		_box(wheel, Vector3(w * 0.8, 0.04, 0.06), (r + 0.01) * Vector3(0, cos(rad), sin(rad)),
				"tread", Vector3(a, 0, 0))
	return wheel


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Kitbash.box(parent, size, pos, _m[mat], rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: String,
		rot: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	return Kitbash.cylinder(parent, radius, height, pos, _m[mat], rot, segments)


func _tube(parent: Node3D, from: Vector3, to: Vector3, radius: float = TUBE_R,
		mat: String = "orange") -> MeshInstance3D:
	return Kitbash.tube(parent, from, to, radius, _m[mat])
