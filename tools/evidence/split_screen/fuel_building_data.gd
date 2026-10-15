extends RefCounted
## Every value is data in the Story 023 scenario fuel_building, AC-6 and the places of AC-2: the time to full and the stopped speed come from
## the shipped SupplySettings (4.0 s, above zero), which both zones share, and a copy with other numbers is followed by a zone (the time to
## full, the stopped speed: a Truck crawling at 0.5 m/s is refuelled under a stopped speed of 1.0 m/s and not under the shipped one); settings
## the zone refuses (zero, negative, NaN) and a zone with a missing or empty field push one named error and give nothing; the two zones sit
## where the Map's scene puts them (kind, size, place, the east one turned half a round and never scaled), and the zone's script holds no
## number that is not a count or a half. Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-2, AC-6.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
const ZONE_SCENE_PATH: String = "res://src/gameplay/supply/supply_zone.tscn"
const ZONE_SCRIPT_PATH: String = "res://src/gameplay/supply/supply_zone.gd"
const DEPOT_SCENE_PATH: String = "res://src/gameplay/maps/map_01/map_01_depot.tscn"
## The node names of the two zones in the depot's scene, and the lines each must store on its instance: its kind (FUEL is 0) and its size.
const ZONE_NODE_NAMES: Array[String] = ["FuelZoneWest", "FuelZoneEast"]
const STORED_LINES: Array[String] = ["\nkind = 0\n", "\nsize = Vector3(6, 6, 6)\n"]
## The story's time from empty to full, seconds, the stopped speed it starts at (about 0.1 m/s, above the noise the measure module reads),
## and the zones' size and places as the Map's scene gives them.
const STORY_SECONDS: float = 4.0
const STORY_STOPPED_SPEED: float = 0.1
const STORY_SIZE: Vector3 = Vector3(6.0, 6.0, 6.0)
const STORY_PLACES: Array[Vector3] = [Vector3(-12.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0)]
## Where an extra zone for the tests stands: open flat, 48 m from the real ones.
const FAR_SPOT: Vector3 = Vector3(-60.0, 0.0, -8.0)
## Ticks a Truck stands or crawls in an extra zone.
const WATCH_TICKS: int = 120
## Another time to full and another stopped speed for the "data is followed" pair.
const OTHER_SECONDS: float = 2.0
const OTHER_STOPPED: float = 1.0
## A crawl at half the other stopped speed, as a share of the Truck's top speed taken from the data.
const CRAWL_OF_OTHER: float = 0.5
## The numbers the zone's code may hold: counts and halves of the geometry, never a gameplay value.
const ALLOWED_NUMBERS: PackedStringArray = ["0", "0.0", "0.5", "1", "1.0", "2", "2.0", "4"]

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
## The engine errors this module causes on purpose.
var expected_errors: int = 0
var _k: Kit23
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	_shipped_data()
	_refused_data()
	_zones_in_the_scene()
	_no_numbers_in_the_code()
	await _bad_zones_give_nothing()
	await _data_is_followed()


func _shipped_data() -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, _settings != null and is_equal_approx(_settings.fuel_seconds_to_full, STORY_SECONDS), "the shipped time to full is %s" % [_settings.fuel_seconds_to_full if _settings != null else "missing"])
	_q.kit.need(problems, is_equal_approx(_settings.stopped_speed, STORY_STOPPED_SPEED) and _settings.first_problem().is_empty(), "the shipped stopped speed is %s, the story starts at %s ('%s')" % [_settings.stopped_speed, STORY_STOPPED_SPEED, _settings.first_problem()])
	for side: int in 2:
		_q.kit.need(problems, _k.zone(side).settings == _settings and _k.zone(side).settings.resource_path == SETTINGS_PATH, "zone %d does not share the shipped settings" % side)
	var layers: Array[String] = [ProjectSettings.get_setting("layer_names/3d_physics/layer_2"), ProjectSettings.get_setting("layer_names/3d_physics/layer_5")]
	for side: int in 2:
		_q.kit.need(problems, _k.zone(side).collision_layer == 0 and _k.zone(side).collision_mask == ((1 << 1) | (1 << 4)) and layers == ["units", "gyrocopters"], "zone %d is on layer %d with mask %d (layers 2 and 5 are %s)" % [side, _k.zone(side).collision_layer, _k.zone(side).collision_mask, layers])
	_q.kit.verdict("settings_are_the_shipped_data", problems, "both zones share data/supply_settings.tres: %.1f s from empty to full and a stopped speed of %.2f m/s; each zone is on no layer and watches the units and gyrocopters layers (mask 18)" % [_settings.fuel_seconds_to_full, _settings.stopped_speed])


## Settings with a time or a speed of zero, below zero or NaN are refused, each field alone.
func _refused_data() -> void:
	var problems: PackedStringArray = []
	var refused: int = 0
	for field: String in ["fuel_seconds_to_full", "stopped_speed"]:
		for bad: float in [0.0, -1.0, NAN]:
			var copy: SupplySettings = _settings.duplicate() as SupplySettings
			copy.set(field, bad)
			var problem: String = copy.first_problem()
			_q.kit.need(problems, problem.begins_with(field), "%s = %s was answered with '%s'" % [field, bad, problem])
			refused += 1 if not problem.is_empty() else 0
	_q.kit.verdict("bad_settings_are_refused", problems, "%d of 6 copies of the settings, each with the time to full or the stopped speed at zero, below zero or NaN, were refused by name; the shipped ones are not" % refused)


## Kind, size, place and turn of the two zones, as the Map's scene stores them.
func _zones_in_the_scene() -> void:
	var problems: PackedStringArray = []
	var found: Array[Node] = _q.map.map.find_children("*", "SupplyZone", true, false)
	_q.kit.need(problems, found.size() == 2, "the Map holds %d supply zones" % found.size())
	var depot: Node = _q.map.find("Depot")
	_q.kit.need(problems, _k.zone(0).get_index() > _q.map.find("Depot/FuelTanks").get_index() and _k.zone(0).get_parent() == depot and _k.zone(1).get_parent() == depot, "the zones are not the depot's children after its tanks")
	for side: int in 2:
		var zone: SupplyZone = _k.zone(side)
		_q.kit.need(problems, zone.kind == SupplyZone.Kind.FUEL and zone.size == STORY_SIZE, "zone %d is kind %d, size %s" % [side, zone.kind, zone.size])
		_q.kit.need(problems, zone.global_position.is_equal_approx(STORY_PLACES[side]), "zone %d stands at %s" % [side, zone.global_position])
		_q.kit.need(problems, zone.scale.is_equal_approx(Vector3.ONE) and zone.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "zone %d is scaled %s" % [side, zone.global_transform.basis.get_scale()])
	var west: Transform3D = _k.zone(0).global_transform
	var east: Transform3D = _k.zone(1).global_transform
	_q.kit.need(problems, west.basis.is_equal_approx(Basis.IDENTITY) and east.basis.is_equal_approx(Basis(Vector3.UP, PI)), "the west zone is turned %s and the east one %s" % [west.basis.get_euler(), east.basis.get_euler()])
	_q.kit.need(problems, is_equal_approx(east.origin.x, -west.origin.x) and is_equal_approx(east.origin.z, west.origin.z), "the east zone is not the west one mirrored across x = 0")
	var scene_text: String = FileAccess.get_file_as_string(DEPOT_SCENE_PATH)
	for zone_name: String in ZONE_NODE_NAMES:
		var from: int = scene_text.find('[node name="%s"' % zone_name)
		var next: int = scene_text.find("\n[node name=", from + 1)
		var block: String = scene_text.substr(from, (next if next >= 0 else scene_text.length()) - from) + "\n" if from >= 0 else ""
		for line: String in STORED_LINES:
			_q.kit.need(problems, block.contains(line), "the depot's scene stores no %s for %s" % [line.strip_edges(), zone_name])
	measured.append("zones=%s_%s_size_%s" % [west.origin, east.origin, STORY_SIZE])
	_q.kit.verdict("zones_are_in_the_scene", problems, "the depot holds exactly two Fuel zones after its tanks, of kind FUEL and size %s, at %s and %s, the east one turned half a round about y and mirrored across x = 0, neither scaled, each storing its kind and its size in the depot's scene" % [STORY_SIZE, west.origin, east.origin])


## No number in the zone's code but the counts and halves of its geometry (a time or a speed written in code is found here).
func _no_numbers_in_the_code() -> void:
	var problems: PackedStringArray = []
	var counted: int = 0
	var regex: RegEx = RegEx.new()
	regex.compile("(?<![\\w.])\\d+(\\.\\d+)?(?![\\w.])")
	var hints: RegEx = RegEx.new()
	hints.compile("@export_range\\([^)]*\\)|\"[^\"]*\"")
	for path: String in [ZONE_SCRIPT_PATH, "res://src/gameplay/supply/supply_settings.gd"]:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = hints.sub(line.split("#")[0], "", true)
			for hit: RegExMatch in regex.search_all(code):
				counted += 1
				_q.kit.need(problems, ALLOWED_NUMBERS.has(hit.get_string()), "%s holds the number %s in '%s'" % [path.get_file(), hit.get_string(), line.strip_edges()])
	_q.kit.verdict("no_gameplay_number_in_the_code", problems, "%d numbers in the code lines of the zone and its settings, every one of %s (counts and halves of the geometry)" % [counted, ", ".join(ALLOWED_NUMBERS)])


## An extra zone of the scene's own kind at a place, with settings and size given, added under the Map. A zone is freed with free_zone().
func _extra_zone(settings: SupplySettings, size: Vector3, at: Vector3) -> SupplyZone:
	var zone: SupplyZone = (load(ZONE_SCENE_PATH) as PackedScene).instantiate() as SupplyZone
	zone.settings = settings
	zone.size = size
	zone.position = at
	_q.map.map.add_child(zone)
	return zone


func _free_zone(zone: SupplyZone) -> void:
	zone.get_parent().remove_child(zone)
	zone.free()


## A zone whose settings are refused, whose size is zero or whose settings are missing pushes one error and gives a stopped Truck nothing;
## the same place with good settings gives it Fuel and pushes none.
func _bad_zones_give_nothing() -> void:
	var problems: PackedStringArray = []
	var nan_time: SupplySettings = _settings.duplicate() as SupplySettings
	nan_time.fuel_seconds_to_full = NAN
	var cases: Array[Dictionary] = [
		{"name": "NaN time", "settings": nan_time, "size": STORY_SIZE, "errors": 1, "gives": false},
		{"name": "no size", "settings": _settings, "size": Vector3.ZERO, "errors": 1, "gives": false},
		{"name": "no settings", "settings": null, "size": STORY_SIZE, "errors": 1, "gives": false},
		{"name": "good (control)", "settings": _settings, "size": STORY_SIZE, "errors": 0, "gives": true}]
	await _k.park(1)
	for case: Dictionary in cases:
		var before: int = _q.tokens.engine_log.errors.size()
		var zone: SupplyZone = _extra_zone(case["settings"], case["size"], FAR_SPOT)
		await _k.put(0, Quick.TRUCK, FAR_SPOT, Vector3.RIGHT, 0.5)
		_k.watch.clear()
		_k.watch.logging = true
		await _q.kit.advance(WATCH_TICKS)
		_k.watch.logging = false
		var gained: bool = _k.first_gain(0) >= 0
		var raised: int = _q.tokens.engine_log.errors.size() - before
		_q.kit.need(problems, raised == int(case["errors"]) and gained == bool(case["gives"]), "%s: %d errors (expected %d), the Truck gained Fuel %s" % [case["name"], raised, case["errors"], gained])
		expected_errors += int(case["errors"])
		_free_zone(zone)
	_q.kit.verdict("bad_zones_give_nothing", problems, "a zone with a NaN time to full, with no size and with no settings pushed one named error each and gave a stopped Truck nothing in %d ticks; a zone with good settings at the same place gave it Fuel and pushed none" % WATCH_TICKS)


## A zone with another time to full fills a Truck in that many seconds' ticks; one with another stopped speed refuels a Truck crawling at half
## of it, where the shipped one does not.
func _data_is_followed() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var quicker: SupplySettings = _settings.duplicate() as SupplySettings
	quicker.fuel_seconds_to_full = OTHER_SECONDS
	var zone: SupplyZone = _extra_zone(quicker, STORY_SIZE, FAR_SPOT)
	var span: int = _k.fill_ticks(stats, OTHER_SECONDS) + 30
	await _k.park(0)
	await _k.put_recorded(0, Quick.TRUCK, FAR_SPOT, Vector3.RIGHT, 0.0, span)
	var fill: Dictionary = _k.fill_of(0)
	var expected: int = _k.fill_ticks(stats, OTHER_SECONDS, float(fill["start"]))
	_q.kit.need(problems, int(fill["ticks"]) == expected and expected < _k.fill_ticks(stats, _settings.fuel_seconds_to_full) - 100, "with %.1f s to full the fill took %d ticks, the rule says %d" % [OTHER_SECONDS, fill["ticks"], expected])
	_free_zone(zone)
	var looser: SupplySettings = _settings.duplicate() as SupplySettings
	looser.stopped_speed = OTHER_STOPPED
	var crawl: float = CRAWL_OF_OTHER * OTHER_STOPPED / stats.max_speed
	var gained: Array[bool] = []
	for settings: SupplySettings in [_settings, looser]:
		zone = _extra_zone(settings, STORY_SIZE, FAR_SPOT)
		await _k.put(0, Quick.TRUCK, FAR_SPOT, Vector3.RIGHT, 0.5)
		_k.watch.clear()
		_k.watch.logging = true
		await _k.a.k.drive(0, WATCH_TICKS, crawl)
		_k.watch.logging = false
		gained.append(_k.first_gain(0) >= 0)
		_free_zone(zone)
	_q.kit.need(problems, gained == [false, true], "a Truck crawling at %.2f m/s gained Fuel under the stopped speeds %.2f and %.2f: %s" % [CRAWL_OF_OTHER * OTHER_STOPPED, _settings.stopped_speed, OTHER_STOPPED, gained])
	_q.kit.verdict("settings_are_followed", problems, "a zone with %.1f s to full filled a Truck in %d ticks (the rule: %d; the shipped %.1f s takes %d); a Truck crawling at %.2f m/s was refuelled under a stopped speed of %.2f and not under the shipped %.2f" % [OTHER_SECONDS, fill["ticks"], expected, _settings.fuel_seconds_to_full, _k.fill_ticks(stats, _settings.fuel_seconds_to_full), CRAWL_OF_OTHER * OTHER_STOPPED, OTHER_STOPPED, _settings.stopped_speed])
	await _k.park(0)
