extends RefCounted
## Scenario resource_bars_showcase of the split screen evidence harness (split_screen_harness.gd): the frames of Story 036,
## windowed, saved as PNGs in the folder named by the environment variable BARS_SHOTS: 01 both HUDs full (a full tank and a
## full load); 02 Player 1 after driving and firing (both bars lower), Player 2 untouched; 03 Player 1 with an empty gun (the
## ammo bar empty, its icon still shown), staged: the Weapon announces 0 Shots left of its load, as its last Shot does (a
## real emptying takes 1,200 ticks, too long for a windowed run on a software renderer). Implements: production/epics/wasteland-fire/story-036-slower-fuel-and-resource-bars.md
## AC-2 to AC-4 (the frames). Tooling only.
## Run: BARS_SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=resource_bars_showcase

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

const RESOURCE_BARS: bool = true
const AMMO: bool = true
## Keeps the Mines line and the notice line, so the frames show the whole HUD.
const MINES: bool = true
const SHIPPED_CAMERA: bool = true
## Ticks Player 1 drives and fires before frame 02.
const DRIVE_TICKS: int = 300
const SETTLE_TICKS: int = 10

var _h: Harness
var _kit: Kit
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	await _kit.advance(SETTLE_TICKS)
	await _save("01-both-full")
	_h.set_key(KEY_W, true)
	_h.set_key(KEY_SPACE, true)
	await _kit.advance(DRIVE_TICKS)
	_h.set_key(KEY_W, false)
	await _save("02-player-1-after-driving-and-firing")
	_h.set_key(KEY_SPACE, false)
	await _kit.advance(SETTLE_TICKS)
	_h.split.player_1_weapon.ammo_changed.emit(0, _h.split.player_1_weapon.capacity)
	await _save("03-player-1-empty-gun-staged")
	_kit.verdict("S1_frames", PackedStringArray() if _saved.size() == 3 else PackedStringArray(["%d frames" % _saved.size()]), ", ".join(_saved))
	_h.finish("frames=%d" % _saved.size())


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("BARS_SHOTS")
	if folder.is_empty():
		return
	var image: Image = _h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
