extends RefCounted
## Scenario real_flag of the split screen evidence harness (split_screen_harness.gd): the Flag is a real flag (Story 043), on
## Map 01 with its rules as they are. CHECK lines:
##  F1 at home: each Flag stands about 2 m tall on its foot (the top of its meshes 1.9 to 2.2 m above the seat; 3 m until
##     Story 046), every panel
##     of its cloth painted in its Base's colour, the two Flags in different colours.
##  F2 it waves: each hinge of the cloth turns about the up axis, a different turn 0.25 s later, never past wave_amplitude.
##  F3 carried: Player 1's Motorbike picks up Flag 2; the foot is hidden and the cloth streams behind the Carrier (its middle
##     behind the pole along the Unit's +z).
##  F4 dropped and seated: the Carrier destroyed, the Flag lies DROPPED with its mast leaning drop_tilt_degrees and sunk
##     drop_sink, the foot hidden; seat_at() (the restart's and a delivery's call) stands it upright on its foot again.
## Implements: production/epics/wasteland-fire/story-043-a-real-flag.md AC-1 to AC-4.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=real_flag

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")

const FLAG_OPEN: bool = true
const THIEF: int = 0
const OWNER: int = 1
const TALL_METRES: float = 1.9
const TALL_MAX_METRES: float = 2.2
const WAVE_GAP_TICKS: int = 15
const BEHIND_METRES: float = 0.3
const TOLERANCE: float = 0.01

var _h: Harness
var _kit: Kit
var _f: Flags


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_f = Flags.new(_h, _kit)
	await _kit.advance(Kit.START_TICKS)
	_check_home()
	await _check_wave()
	await _check_carried()
	await _check_dropped()
	_h.finish("flags=2")


func _panels(flag: Flag) -> Array[MeshInstance3D]:
	var all: Array[MeshInstance3D] = [flag.body_mesh]
	all.append_array(flag.cloth_meshes)
	return all


## The highest point of a Flag's meshes above its origin, metres.
func _top(flag: Flag) -> float:
	var top: float = 0.0
	for mesh: MeshInstance3D in _meshes(flag):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y - flag.global_position.y)
	return top


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		found.append(child as MeshInstance3D)
	return found


func _check_home() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	var colours: Array[Color] = []
	for index: int in _f.flags.size():
		var flag: Flag = _f.flags[index]
		var expected: StandardMaterial3D = _f.bases[index].color_material as StandardMaterial3D
		var painted: int = 0
		for panel: MeshInstance3D in _panels(flag):
			var material: StandardMaterial3D = panel.material_override as StandardMaterial3D
			if material != null and material.albedo_color == expected.albedo_color:
				painted += 1
		colours.append(expected.albedo_color)
		var top: float = _top(flag)
		_kit.need(problems, top >= TALL_METRES and top <= TALL_MAX_METRES and flag.stand.visible and painted == _panels(flag).size() and _panels(flag).size() == 4,
			"flag %d: %.2f m tall, foot %s, %d of %d panels painted" % [index + 1, top, flag.stand.visible, painted, _panels(flag).size()])
		lines.append("flag_%d %.2f m, foot %s, %d / %d panels in its colour" % [index + 1, top, flag.stand.visible, painted, _panels(flag).size()])
	_kit.need(problems, colours[0] != colours[1], "both Flags in %s" % colours[0])
	_kit.verdict("F1_at_home", problems, "; ".join(lines))


func _check_wave() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var flag: Flag = _f.flags[0]
	var first: Array[float] = []
	for hinge: Node3D in flag.cloth_hinges:
		first.append(hinge.rotation.y)
	await _kit.advance(WAVE_GAP_TICKS)
	var moved: int = 0
	var widest: float = 0.0
	for index: int in flag.cloth_hinges.size():
		var turn: float = flag.cloth_hinges[index].rotation.y
		if absf(turn - first[index]) > TOLERANCE:
			moved += 1
		widest = maxf(widest, absf(turn))
	_kit.need(problems, flag.cloth_hinges.size() == 4 and moved == 4, "%d of %d hinges moved" % [moved, flag.cloth_hinges.size()])
	_kit.need(problems, widest <= flag.wave_amplitude + TOLERANCE, "a hinge turned %.3f rad (amplitude %.3f)" % [widest, flag.wave_amplitude])
	_kit.verdict("F2_waves", problems, "%d of %d hinges turned in %d ticks, widest %.3f rad (amplitude %.2f)" % [moved, flag.cloth_hinges.size(), WAVE_GAP_TICKS, widest, flag.wave_amplitude])


func _cloth_middle(flag: Flag) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for panel: MeshInstance3D in _panels(flag):
		sum += panel.global_position
	return sum / float(_panels(flag).size())


func _check_carried() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var flag: Flag = _f.flags[OWNER]
	var thief: Unit = _f.units[THIEF]
	var base_dir: Vector3 = _f.bases[OWNER].global_position - flag.global_position
	_f.approach(THIEF, flag.global_position, -base_dir if base_dir.length() > 0.1 else Vector3.BACK)
	await _kit.advance(3)
	var ticks: int = await _f.drive_until(THIEF, 1, 4.0, func() -> bool: return flag.state == Flag.State.CARRIED)
	await _f.rest(THIEF)
	var behind: float = (_cloth_middle(flag) - flag.global_position).dot(thief.global_transform.basis.z)
	_kit.need(problems, ticks > 0 and flag.carrier == thief, "the pick-up took %d ticks, carrier %s" % [ticks, flag.carrier])
	_kit.need(problems, not flag.stand.visible, "the foot shows on the Carrier")
	_kit.need(problems, behind > BEHIND_METRES, "the cloth's middle is %.2f m behind its pole" % behind)
	_kit.verdict("F3_carried", problems, "picked up after %d ticks; foot %s; the cloth's middle %.2f m behind its pole" % [ticks, flag.stand.visible, behind])


func _check_dropped() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var flag: Flag = _f.flags[OWNER]
	_f.units[THIEF].destroy()
	await _kit.advance(3)
	var lean: float = rad_to_deg(flag.mast.transform.basis.y.angle_to(Vector3.UP))
	var sink: float = -flag.mast.position.y
	var dropped_ok: bool = flag.state == Flag.State.DROPPED and not flag.stand.visible
	_kit.need(problems, dropped_ok, "state %s, foot %s" % [_f.state_name(OWNER), flag.stand.visible])
	_kit.need(problems, absf(lean - flag.drop_tilt_degrees) < 0.1 and absf(sink - flag.drop_sink) < TOLERANCE, "lean %.2f deg, sink %.2f m" % [lean, sink])
	flag.seat_at(_f.bases[OWNER].flag_seat.global_transform)
	await _kit.advance(3)
	var seated: bool = flag.state == Flag.State.AT_HOME and flag.stand.visible and flag.mast.transform.is_equal_approx(Transform3D.IDENTITY)
	_kit.need(problems, seated, "seated again: state %s, foot %s, mast %s" % [_f.state_name(OWNER), flag.stand.visible, flag.mast.transform])
	_kit.verdict("F4_dropped", problems, "dropped: %s, leaning %.1f deg, sunk %.2f m, foot %s; seated again %s on its foot %s" % [
		dropped_ok, lean, sink, not dropped_ok, _f.state_name(OWNER), flag.stand.visible])
