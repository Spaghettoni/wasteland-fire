extends RefCounted
## Scenario map_02_showcase of the split screen evidence harness (split_screen_harness.gd): the frames of Story 038 on Map 02,
## windowed, saved as PNGs in the folder named by the environment variable MAP_02_SHOTS:
##  01 both Players at the start, each in the Garage west of its Flag, the Gate to the east;
##  02 Player 1's Buggy in front of the middle Bush and wreck; Player 2's Buggy in front of Player 1's wall gap, its Turrets firing;
##  03 Player 1's Buggy through the Bush, which lies flat; Player 2 at the wall gap, hit;
##  04 a wreck and a small building damaged (staged: hit points set below 80% and 35%), seen from Player 1's Unit; Player 2 by
##     the Fuel building;
##  05 Player 1's Gyrocopter over the ridge; Player 2's Buggy in the passage's water.
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-3 to AC-7 (the frames). Tooling only.
## Run: MAP_02_SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=map_02_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
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
const SHIPPED_CAMERA: bool = true
const WATCHDOG_SECONDS: float = 1800.0
const SETTLE_TICKS: int = 20
const FRAMES: int = 5

var _m: M2
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("map-02-01-start-garages-west-of-the-flags")
	var bush: Bush = _m.piece("Cover/BushMiddle") as Bush
	await _m.put(0, M2.BUGGY, bush.global_position + Vector3.LEFT * 9.0, Vector3.RIGHT)
	await _m.put(1, M2.BUGGY, M2.at(50.0, 92.0), Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("map-02-02-bush-ahead-and-outposts-firing")
	await _m.drive_for(0, 1, 0, 70)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("map-02-03-bush-flattened")
	var wreck: Structure = _m.piece("Cover/WreckNorth2") as Structure
	var shack: Structure = _m.piece("Cover/ShackNorth1") as Structure
	wreck.apply_damage(wreck.hit_points - 0.5 * wreck.stats.max_hit_points)
	shack.apply_damage(shack.hit_points - 0.2 * shack.stats.max_hit_points)
	await _m.put(0, M2.MOTORBIKE, M2.at(64.0, 120.0), Vector3.FORWARD)
	await _m.put(1, M2.TRUCK, M2.at(50.0, 145.0), Vector3.LEFT)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("map-02-04-wreck-and-building-damaged-staged")
	await _m.put(0, M2.GYROCOPTER, M2.at(111.0, 100.0), Vector3.RIGHT)
	await _m.put(1, M2.BUGGY, M2.at(125.0, 196.0), Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _save("map-02-05-gyrocopter-over-the-ridge-buggy-in-the-water")
	var problems: PackedStringArray = PackedStringArray() if _saved.size() == FRAMES else PackedStringArray(["%d frames" % _saved.size()])
	_m.kit.verdict("S1_frames", problems, ", ".join(_saved))
	_m.h.finish("frames=%d" % _saved.size())


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("MAP_02_SHOTS")
	if folder.is_empty():
		return
	var image: Image = _m.h.get_viewport().get_texture().get_image()
	if image != null and image.save_png("%s/%s.png" % [folder, label]) == OK:
		_saved.append(label)
