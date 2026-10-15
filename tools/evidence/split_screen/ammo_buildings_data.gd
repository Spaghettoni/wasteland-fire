extends RefCounted
## Every value is data in the Story 024 scenario ammo_buildings, AC-5 (and the scene half of AC-1): the ammo's time from empty to full is in
## supply_settings.tres (4 s), the no-Mine margin in mine_settings.tres (3 m), each refused when unusable; the building's size, collider
## and look are in its scene, the zone's size, height and kind in its scene, the buildings' places in map_01.tscn (the east one the west one
## turned half a round about y and mirrored across x = 0, neither scaled), the Map lists its four zones in order and SplitScreen hands the
## Weapons and the zones on; the notice text is in player_notice.tscn and a notice without it refuses to run; no number is a constant in the
## code of the zone, its settings, the MineLayer, the Map or the hand-over; a zone with unusable settings or no Weapons gives nothing, and a
## zone with another time is followed. Tooling only. Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-5.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
const MINE_SETTINGS_PATH: String = "res://src/gameplay/mines/data/mine_settings.tres"
const ZONE_SCENE_PATH: String = "res://src/gameplay/supply/supply_zone.tscn"
const BUILDING_SCENE_PATH: String = "res://src/gameplay/supply/ammo_building.tscn"
const SHOT_SCENE_PATH: String = "res://src/gameplay/combat/shot.tscn"
const NOTICE_SCENE_PATH: String = "res://src/ui/hud/player_notice.tscn"
## The story's values: the ammo's time from empty to full and the margin, the building's size and height, the zone's size, the places.
const STORY_SECONDS: float = 4.0
const STORY_MARGIN: float = 3.0
const STORY_BUILDING: Vector3 = Vector3(4.0, 1.8, 6.0)
const STORY_ZONE: Vector3 = Vector3(6.0, 6.0, 6.0)
const STORY_PLACES: Array[Vector3] = [Vector3(-64.0, 0.0, 14.0), Vector3(64.0, 0.0, 14.0)]
const COVER_LAYER: int = 64
## The notice text the story names.
const STORY_NOTICE: String = "No Mines at a supply building"
## The source files whose code holds no gameplay number, and the numbers their code may hold (counts and halves of the geometry).
const LINTED: Array[String] = ["res://src/gameplay/supply/supply_zone.gd", "res://src/gameplay/supply/supply_settings.gd", "res://src/gameplay/mines/mine_layer.gd", "res://src/gameplay/mines/mine_settings.gd", "res://src/gameplay/maps/map_field.gd"]
const ALLOWED_NUMBERS: PackedStringArray = ["0", "0.0", "0.5", "1", "1.0", "2", "2.0", "4"]
## Where an extra zone for the tests stands: open flat, far from the real ones.
const FAR_SPOT: Vector3 = Vector3(-60.0, 0.0, -8.0)
## Ticks a Unit stands in an extra zone, and another time to full for the "data is followed" check.
const WATCH_TICKS: int = 120
const OTHER_SECONDS: float = 2.0
## The first row a Unit brought into a zone is given Shots on.
const FIRST_GIFT_ROW: int = 3

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
## The engine errors and warnings this module causes on purpose, for the noise check.
var expected_errors: int = 0
var expected_warnings: int = 0
var _k: Kit24
var _q: Quick
var _settings: SupplySettings
var _mine_settings: MineSettings


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings
	_mine_settings = load(MINE_SETTINGS_PATH) as MineSettings


func run() -> void:
	_shipped_data()
	_refused_data()
	_scene_and_places()
	_handed_on()
	_look_is_data()
	_notice_is_data()
	_map_warns_for_an_unassigned_zone()
	_no_numbers_in_the_code()
	await _bad_zones_give_nothing()
	await _data_is_followed()


func _shipped_data() -> void:
	var problems: PackedStringArray = []
	_q.kit.need(problems, _settings != null and is_equal_approx(_settings.ammo_seconds_to_full, STORY_SECONDS) and _settings.first_problem().is_empty(), "the shipped ammo time to full is %s ('%s')" % [_settings.ammo_seconds_to_full if _settings != null else "missing", _settings.first_problem() if _settings != null else ""])
	_q.kit.need(problems, _mine_settings != null and is_equal_approx(_mine_settings.supply_margin, STORY_MARGIN) and _mine_settings.first_problem().is_empty(), "the shipped supply margin is %s ('%s')" % [_mine_settings.supply_margin if _mine_settings != null else "missing", _mine_settings.first_problem() if _mine_settings != null else ""])
	for index: int in Kit24.ZONE_PATHS.size():
		_q.kit.need(problems, _k.zone(index).settings == _settings and _k.zone(index).settings.resource_path == SETTINGS_PATH, "zone %d does not share the shipped settings" % index)
	for player: int in 2:
		_q.kit.need(problems, _k.mines().layers[player].settings == _mine_settings, "Player %d's MineLayer does not read the shipped Mine settings" % (player + 1))
	_q.kit.verdict("settings_are_the_shipped_data", problems, "all four zones share data/supply_settings.tres, whose ammo time from empty to full is %.1f s, and both MineLayers read data/mine_settings.tres, whose supply margin is %.1f m; both pass first_problem()" % [_settings.ammo_seconds_to_full, _mine_settings.supply_margin])


## An ammo time of zero, below zero or NaN, and a supply margin below zero or NaN, are refused by name, each field alone; a margin of zero is allowed.
func _refused_data() -> void:
	var problems: PackedStringArray = []
	var refused: int = 0
	for bad: float in [0.0, -1.0, NAN]:
		var copy: SupplySettings = _settings.duplicate() as SupplySettings
		copy.ammo_seconds_to_full = bad
		var problem: String = copy.first_problem()
		_q.kit.need(problems, problem.begins_with("ammo_seconds_to_full"), "ammo_seconds_to_full = %s was answered with '%s'" % [bad, problem])
		refused += 1 if not problem.is_empty() else 0
	for bad: float in [-0.1, NAN]:
		var copy: MineSettings = _mine_settings.duplicate() as MineSettings
		copy.supply_margin = bad
		var problem: String = copy.first_problem()
		_q.kit.need(problems, problem.begins_with("supply_margin"), "supply_margin = %s was answered with '%s'" % [bad, problem])
		refused += 1 if not problem.is_empty() else 0
	var none: MineSettings = _mine_settings.duplicate() as MineSettings
	none.supply_margin = 0.0
	_q.kit.need(problems, none.first_problem().is_empty(), "a supply margin of zero was refused: '%s'" % none.first_problem())
	_q.kit.verdict("bad_settings_are_refused", problems, "%d of 5 copies of the settings, each with the ammo time at zero, below zero or NaN or the supply margin below zero or NaN, were refused by name; a margin of zero is allowed" % refused)


## The buildings' places and turn in the Map's scene, the building's and the zone's data in theirs.
func _scene_and_places() -> void:
	var problems: PackedStringArray = []
	var packed: PackedScene = load(BUILDING_SCENE_PATH) as PackedScene
	var sample: StaticBody3D = packed.instantiate() as StaticBody3D
	var box: BoxShape3D = (sample.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_q.kit.need(problems, box != null and box.size == STORY_BUILDING and sample.collision_layer == COVER_LAYER and sample.collision_mask == 0, "the building's scene holds a collider of %s on layer %d, mask %d" % [box.size if box != null else "none", sample.collision_layer, sample.collision_mask])
	var zone: SupplyZone = sample.get_node("AmmoZone") as SupplyZone
	_q.kit.need(problems, zone.kind == SupplyZone.Kind.AMMO and zone.size == STORY_ZONE, "the scene's zone is kind %d, size %s" % [zone.kind, zone.size])
	_q.kit.need(problems, is_equal_approx(zone.position.x - zone.size.x / 2.0, box.size.x / 2.0) and is_zero_approx(zone.position.z) and is_zero_approx(zone.position.y), "the zone's inner face is at x %.3f in the building's frame, the building's face is at %.3f (zone at %s)" % [zone.position.x - zone.size.x / 2.0, box.size.x / 2.0, zone.position])
	sample.free()
	var scene_text: String = FileAccess.get_file_as_string(BUILDING_SCENE_PATH)
	var block: int = scene_text.find('[node name="AmmoZone"')
	var end: int = scene_text.find("\n[node name=", block + 1)
	var zone_block: String = scene_text.substr(block, end - block)
	for line: String in ["kind = 1", "size = Vector3(6, 6, 6)"]:
		_q.kit.need(problems, zone_block.contains(line), "the building's scene stores no '%s' for its zone" % line)
	for side: int in 2:
		var body: StaticBody3D = _k.building(side)
		_q.kit.need(problems, body.global_position.is_equal_approx(STORY_PLACES[side]), "building %d stands at %s" % [side, body.global_position])
		_q.kit.need(problems, body.scale.is_equal_approx(Vector3.ONE) and body.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "building %d is scaled %s" % [side, body.global_transform.basis.get_scale()])
		_q.kit.need(problems, body.get_index() == _q.map.find("Depot").get_index() + 1 + side, "building %d is not right after the Depot (index %d)" % [side, body.get_index()])
	_q.kit.need(problems, _k.building(0).global_transform.basis.is_equal_approx(Basis.IDENTITY) and _k.building(1).global_transform.basis.is_equal_approx(Basis(Vector3.UP, PI)), "the west building is turned %s and the east one %s" % [_k.building(0).global_transform.basis.get_euler(), _k.building(1).global_transform.basis.get_euler()])
	_q.kit.need(problems, is_equal_approx(_k.building(1).global_position.x, -_k.building(0).global_position.x) and is_equal_approx(_k.building(1).global_position.z, _k.building(0).global_position.z), "the east building is not the west one mirrored across x = 0")
	var map_text: String = FileAccess.get_file_as_string("res://src/gameplay/maps/map_01/map_01.tscn")
	for line: String in ['[node name="AmmoBuildingWest" parent="." instance=ExtResource("15_ammo_building")]', '[node name="AmmoBuildingEast" parent="." instance=ExtResource("15_ammo_building")]', 'Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -64, 0, 14)', 'Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 64, 0, 14)']:
		_q.kit.need(problems, map_text.contains(line), "map_01.tscn stores no '%s'" % line)
	for side: int in 2:
		var scene_zone: SupplyZone = _k.ammo_zone(side)
		_q.kit.need(problems, scene_zone.kind == SupplyZone.Kind.AMMO and scene_zone.size == STORY_ZONE and scene_zone.settings == _settings, "ammunition zone %d is kind %d, size %s" % [side, scene_zone.kind, scene_zone.size])
	measured.append("buildings=%s_%s_zone_inner_face_on_the_building_face" % [STORY_PLACES[0], STORY_PLACES[1]])
	_q.kit.verdict("buildings_and_zones_are_in_the_scenes", problems, "the building's scene holds a collider of %s on the cover layer and its zone of kind AMMO and size %s with its inner face on the building's face; map_01.tscn places two instances right after the Depot at %s and %s, the east one turned half a round about y, neither scaled" % [STORY_BUILDING, STORY_ZONE, STORY_PLACES[0], STORY_PLACES[1]])


## The Map lists its four zones in order, SplitScreen hands the Weapons to the ammunition zones alone and every zone to both MineLayers.
func _handed_on() -> void:
	var problems: PackedStringArray = []
	var listed: Array[SupplyZone] = _q.map.map.supply_zones
	var expected: Array[SupplyZone] = []
	for index: int in Kit24.ZONE_PATHS.size():
		expected.append(_k.zone(index))
	_q.kit.need(problems, listed == expected, "the Map lists %s" % [listed])
	var kinds: Array[int] = []
	for zone: SupplyZone in listed:
		kinds.append(zone.kind)
	_q.kit.need(problems, kinds == [SupplyZone.Kind.FUEL, SupplyZone.Kind.FUEL, SupplyZone.Kind.AMMO, SupplyZone.Kind.AMMO], "the kinds listed are %s" % [kinds])
	for index: int in Kit24.ZONE_PATHS.size():
		var weapons: Array[Weapon] = _k.zone(index).weapons
		var wanted: bool = index >= Kit24.AMMO_ZONE_FROM
		_q.kit.need(problems, (weapons == [_k.gun(0), _k.gun(1)]) if wanted else weapons.is_empty(), "zone %d holds %s" % [index, weapons])
	for player: int in 2:
		_q.kit.need(problems, _k.mines().layers[player].supply_zones == expected, "Player %d's MineLayer holds %s" % [player + 1, _k.mines().layers[player].supply_zones])
	_q.kit.need(problems, _q.harness.split.player_1_weapon == _k.gun(0) and _q.harness.split.player_2_weapon == _k.gun(1), "SplitScreen's Weapons are not the Players'")
	_q.kit.verdict("lists_are_handed_on", problems, "the Map lists its two Fuel zones then its two ammunition zones; SplitScreen's two Weapon exports are the Players' own; every ammunition zone holds both Weapons in Player order, a Fuel zone none, and both MineLayers hold all four zones")


## The pale yellow of the ammunition zone's marking is the Shots' tracer colour, in the building's scene; the Fuel zones' amber is another.
func _look_is_data() -> void:
	var problems: PackedStringArray = []
	var tracer: Color = Color.BLACK
	var shot: Node = (load(SHOT_SCENE_PATH) as PackedScene).instantiate()
	for node: Node in shot.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = (node as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		tracer = material.albedo_color
	shot.free()
	for side: int in 2:
		var slab: MeshInstance3D = _k.ammo_zone(side).slab as MeshInstance3D
		var colour: Color = (slab.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color
		var fuel: Color = ((_k.zone(side).slab as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D).albedo_color
		_q.kit.need(problems, colour.is_equal_approx(tracer) and not fuel.is_equal_approx(tracer) and colour != fuel, "the ammunition zone's marking is %s, the tracer %s, the Fuel zone's %s" % [colour, tracer, fuel])
		_q.kit.need(problems, slab.scale.is_equal_approx(Vector3(STORY_ZONE.x, 1.0, STORY_ZONE.z)) and slab.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the marking's slab is scaled %s, shadow %d" % [slab.scale, slab.cast_shadow])
	measured.append("marking_pale_yellow_is_the_tracer_%s" % [tracer])
	_q.kit.verdict("marking_colour_is_data", problems, "each ammunition zone's marking is the pale yellow of the Shots' tracer (%s), set in the building's scene, and each Fuel zone's is another colour (the amber of the depot's scene)" % [tracer])


## The refusal's text is in the scene of the notice, both views hold it, and a notice with it missing refuses to run.
func _notice_is_data() -> void:
	var problems: PackedStringArray = []
	var scene_text: String = FileAccess.get_file_as_string(NOTICE_SCENE_PATH)
	_q.kit.need(problems, scene_text.contains('near_supply_text = "%s"' % STORY_NOTICE), "player_notice.tscn stores no near_supply_text")
	for player: int in 2:
		var found: Array[Node] = _q.units.cameras[player].get_viewport().find_children("*", "PlayerNotice", false, false)
		_q.kit.need(problems, found.size() == 1 and (found[0] as PlayerNotice).near_supply_text == STORY_NOTICE and (found[0] as PlayerNotice).mine_layer == _k.mines().layers[player], "view %d holds %d notices" % [player + 1, found.size()])
	var bare: PlayerNotice = (load(NOTICE_SCENE_PATH) as PackedScene).instantiate() as PlayerNotice
	bare.match_controller = _q.controller
	bare.player_index = 0
	bare.mine_layer = _k.mines().layers[0]
	var control: String = bare.call(&"_first_problem")
	bare.near_supply_text = ""
	var without: String = bare.call(&"_first_problem")
	_q.kit.need(problems, control.is_empty() and without.contains("refusal text"), "the notice answered '%s' with the text and '%s' without it" % [control, without])
	bare.free()
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	_q.kit.need(problems, readme.contains(STORY_NOTICE) and readme.contains("ammunition building") and readme.contains("Ammo is refilled in the two ammunition buildings"), "the README does not tell of the ammunition buildings and of the refusal")
	_q.kit.verdict("notice_text_is_data", problems, "player_notice.tscn stores \"%s\", both views hold it on their own MineLayer, a notice built without the text refuses to run ('%s') and the README tells of the buildings and of the refusal" % [STORY_NOTICE, without])


## A Map whose supply_zones holds an entry that is not assigned warns once, naming the entry, and the list's other entries stay readable.
func _map_warns_for_an_unassigned_zone() -> void:
	var problems: PackedStringArray = []
	var before: int = _q.tokens.engine_log.warnings.size()
	var field: MapField = MapField.new()
	var zones: Array[SupplyZone] = [null, _k.zone(0)]
	field.supply_zones = zones
	_q.map.map.add_child(field)
	var raised: Array = _q.tokens.engine_log.warnings.slice(before)
	_q.map.map.remove_child(field)
	field.free()
	_q.kit.need(problems, raised.size() == 1 and String(raised[0]).contains("supply_zones entry 0 is not assigned"), "a Map with an unassigned supply zone raised %s" % [raised])
	expected_warnings += raised.size()
	_q.kit.verdict("unassigned_zone_is_warned_about", problems, "a Map whose supply_zones lists one entry that is not assigned warned once, naming entry 0 (the entry after it is a zone)")


## The numbers in the code lines of the zone, its settings, the MineLayer, its settings and the Map, and in the hand-over of SplitScreen,
## quoted text, comments and the editor's range hints taken out: only counts and halves of the geometry.
func _no_numbers_in_the_code() -> void:
	var problems: PackedStringArray = []
	var counted: int = 0
	var regex: RegEx = RegEx.new()
	regex.compile("(?<![\\w.])\\d+(\\.\\d+)?(?![\\w.])")
	var hints: RegEx = RegEx.new()
	hints.compile("@export_range\\([^)]*\\)|\"[^\"]*\"")
	var texts: Dictionary[String, String] = {}
	for path: String in LINTED:
		texts[path.get_file()] = FileAccess.get_file_as_string(path)
	var split_text: String = FileAccess.get_file_as_string("res://src/gameplay/split_screen/split_screen.gd")
	var from: int = split_text.find("func _hand_supply_zones")
	_q.kit.need(problems, from >= 0, "split_screen.gd has no _hand_supply_zones")
	texts["split_screen.gd _hand_supply_zones"] = split_text.substr(from, split_text.find("\nfunc ", from + 1) - from) if from >= 0 else ""
	for label: String in texts:
		for line: String in texts[label].split("\n"):
			var code: String = hints.sub(line.split("#")[0], "", true)
			for hit: RegExMatch in regex.search_all(code):
				counted += 1
				_q.kit.need(problems, ALLOWED_NUMBERS.has(hit.get_string()), "%s holds the number %s in '%s'" % [label, hit.get_string(), line.strip_edges()])
	_q.kit.verdict("no_gameplay_number_in_the_code", problems, "%d numbers in the code lines of the zone, its settings, the MineLayer, its settings, the Map and the hand-over, every one of %s (counts and halves of the geometry)" % [counted, ", ".join(ALLOWED_NUMBERS)])


## An extra ammunition zone at the far spot: the placed zone scene with kind AMMO, settings, size and Weapons given, added under the Map.
func _extra_zone(settings: SupplySettings, handed: bool) -> SupplyZone:
	var zone: SupplyZone = (load(ZONE_SCENE_PATH) as PackedScene).instantiate() as SupplyZone
	zone.kind = SupplyZone.Kind.AMMO
	zone.settings = settings
	zone.size = STORY_ZONE
	zone.position = FAR_SPOT
	if handed:
		zone.weapons = [_k.gun(0), _k.gun(1)]
	_q.map.map.add_child(zone)
	return zone


func _free_zone(zone: SupplyZone) -> void:
	zone.get_parent().remove_child(zone)
	zone.free()


## A zone whose settings are refused pushes one error and gives an empty Truck nothing; one with good settings and no Weapons handed
## gives nothing and pushes none; the same place with good settings and the Weapons gives Shots.
func _bad_zones_give_nothing() -> void:
	var problems: PackedStringArray = []
	var nan_time: SupplySettings = _settings.duplicate() as SupplySettings
	nan_time.ammo_seconds_to_full = NAN
	var cases: Array[Dictionary] = [
		{"name": "NaN time", "settings": nan_time, "handed": true, "errors": 1, "gives": false},
		{"name": "no settings", "settings": null, "handed": true, "errors": 1, "gives": false},
		{"name": "no Weapons handed", "settings": _settings, "handed": false, "errors": 0, "gives": false},
		{"name": "good (control)", "settings": _settings, "handed": true, "errors": 0, "gives": true}]
	await _k.park(1)
	for case: Dictionary in cases:
		var before: int = _q.tokens.engine_log.errors.size()
		var zone: SupplyZone = _extra_zone(case["settings"], bool(case["handed"]))
		await _k.empty_in_the_arena(0, Quick.TRUCK)
		await _k.record_after_move(0, FAR_SPOT, Vector3.RIGHT, WATCH_TICKS)
		var gained: bool = _k.gains(0) > 0
		var raised: int = _q.tokens.engine_log.errors.size() - before
		_q.kit.need(problems, raised == int(case["errors"]) and gained == bool(case["gives"]), "%s: %d errors (expected %d), the Truck gained Shots %s" % [case["name"], raised, case["errors"], gained])
		expected_errors += int(case["errors"])
		_free_zone(zone)
	_q.kit.verdict("bad_zones_give_nothing", problems, "an ammunition zone with a NaN time to full and one with no settings pushed one named error each and gave an empty Truck nothing in %d ticks; one with good settings and no Weapons handed gave nothing and pushed none; with the Weapons handed the same place gave it Shots" % WATCH_TICKS)
	await _k.park(0)


## A zone with another time to full fills a Truck in that many seconds' ticks.
func _data_is_followed() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var quicker: SupplySettings = _settings.duplicate() as SupplySettings
	quicker.ammo_seconds_to_full = OTHER_SECONDS
	var zone: SupplyZone = _extra_zone(quicker, true)
	var expected: int = _k.fill_ticks(stats.ammo_capacity, OTHER_SECONDS)
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.record_after_move(0, FAR_SPOT, Vector3.RIGHT, expected + WATCH_TICKS / 2)
	var full: int = -1
	for index: int in _k.rows(0).size():
		if full < 0 and int(_k.rows(0)[index]["left"]) >= stats.ammo_capacity:
			full = index
	var listed_from: int = _k.first_listed(0, 0)
	_q.kit.need(problems, full >= 0 and listed_from == -1, "the Truck's load was never whole (row %d) or a depot zone listed it" % full)
	var ticks: int = full - FIRST_GIFT_ROW + 1
	_q.kit.need(problems, ticks == expected and expected < _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full) - 100, "with %.1f s to full the fill took %d ticks, the rule says %d" % [OTHER_SECONDS, ticks, expected])
	_free_zone(zone)
	_q.kit.verdict("settings_are_followed", problems, "an extra ammunition zone with %.1f s to full filled an empty Truck in %d ticks (the rule: %d; the shipped %.1f s takes %d)" % [OTHER_SECONDS, ticks, expected, _settings.ammo_seconds_to_full, _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full)])
	await _k.park(0)
