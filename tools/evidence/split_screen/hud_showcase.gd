extends RefCounted
## Scenario hud_showcase of the split screen evidence harness (split_screen_harness.gd): the one-row HUD of Story 051 on Map 01
## with two Players, windowed, saved as PNGs in the folder named by the environment variable SHOTS. hud-01-flags-home: both
## Motorbikes in their Garages, both Flags at home (the Flag in its dock). hud-02-flag-taken: Player 1's Motorbike is put on
## Player 2's Flag seat and takes the Flag: Player 1 carries it (the golden Flag on a wheel, and the drop-flag icon in the
## secondary slot), Player 2's is away (the red Flag running off). A CHECK reads each HUD's hidden status line.
## Implements: production/epics/wasteland-fire/story-051-one-row-hud.md, Test Evidence. Tooling only.
## Run: SHOTS=<folder> godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=hud_showcase

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_01/map_01.tscn"
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const MORE_TOKENS: bool = true
const OWN_CHOICE: bool = true
const TEAMS: bool = true
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const MINES: bool = true
const TURRET_LOOKS: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const USE_MAP_STOCK: bool = true
const BUSHES: bool = true
const MAP_CHOICE: bool = true
const FLAG_OPEN: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const SHIPPED_CAMERA: bool = true
const LINEUP_DEVICES: Array[int] = [-2, -3]
const LINEUP_TEAMS: Array[int] = [0, 1]
const WATCHDOG_SECONDS: float = 1800.0
const TYPES: Array[int] = [0, 0]
const PICK_TICKS: int = 30

var _h: Harness
var _kit: Kit
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var split: SplitScreen = _h.split
	for player: int in LINEUP_DEVICES.size():
		split.match_controller.choose(player, TYPES[player])
	await _kit.advance(60)
	var problems: PackedStringArray = PackedStringArray()
	var first: PackedStringArray = _statuses(split)
	await _save("hud-01-flags-home")
	var seat: Vector3 = split.field.player_2_base.flag_seat.global_position
	var unit: Unit = split.all_units()[0]
	_h.place(unit, Transform3D(unit.global_basis, Vector3(seat.x, unit.global_position.y, seat.z)), split.all_cameras()[0])
	await _kit.advance(PICK_TICKS)
	var second: PackedStringArray = _statuses(split)
	await _save("hud-02-flag-taken")
	_kit.need(problems, split.match_controller.is_carrying(0), "Player 1 does not carry the Flag")
	_kit.need(problems, _saved.size() == 2, "%d frames" % _saved.size())
	_kit.verdict("S1_frames", problems, "home: %s; taken: %s; frames %s" % [", ".join(first), ", ".join(second), ", ".join(_saved)])
	_h.finish("frames=%d" % _saved.size())


func _statuses(split: SplitScreen) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for node: Node in split.find_children("*", "", true, false):
		var hud: PlayerHud = node as PlayerHud
		if hud != null:
			var label: Label = hud.get_node("%FlagStatusLabel") as Label
			var icon: TextureRect = hud.get_node("%FlagIcon") as TextureRect
			lines.append("P%d '%s' %s" % [hud.player_index + 1, label.text, icon.texture.resource_path.get_file()])
	return lines


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("SHOTS")
	if folder.is_empty():
		return
	var image: Image = _h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
