extends RefCounted
## What an explosion is made of and how long each piece lasts (Story 016 AC-3, AC-5, AC-9), read from the real thing: a
## Truck destroyed by its Player's real Self-destruct key outside its Base, its Explosion read on every tick it counts.
## picture_only: no body, no Area3D and no collision layer under it, in the node group, a child of World, process mode
## ALWAYS. look_is_data: the pieces are built-in shapes (balls and cubes) in unshaded materials, shadow off, render
## layer 1, no Team colour, every colour the data's. pieces_by_tick: the flash shows for its ticks, the fireball swells
## and shrinks over its ticks, the chunks fly the data's arcs and are hidden the tick they reach the floor, the puffs
## begin on their staggered ticks and rise, grow and fade to nothing. lifetime: 120 ticks after the tick it was added in,
## before its Unit can respawn, with the tick counter it counted. Run by explosions.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-016-unit-explosions.md AC-3, AC-5 and AC-9.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The explosion's data, by path.
const SETTINGS_PATH: String = "res://src/gameplay/effects/data/explosion_settings.tres"
## Ticks the Truck's Explosion is followed for: its life and a few more.
const FOLLOW_TICKS: int = 130
## The share of its full radius the fireball must reach at its peak (the tick the swell ends on is a whole tick).
const PEAK_SHARE: float = 0.99
## The share of its first brightness the fireball must have lost by its last tick.
const DARKENED_SHARE: float = 0.8
## The Teams' materials, which no piece may wear.
const TEAM_PATHS: Array[String] = ["res://src/gameplay/split_screen/data/team_orange_material.tres", "res://src/gameplay/split_screen/data/team_teal_material.tres"]

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick
var _settings: ExplosionSettings
## One reading per counted tick: ticks played -> {flash, fireball, fireball_x, fireball_colour, fireball_material, chunks,
## chunk_y, puffs, puff_t, puff_y}.
var _samples: Dictionary = {}


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q
	_settings = load(SETTINGS_PATH) as ExplosionSettings


func run() -> void:
	await _destroy_a_truck()
	_picture_only()
	_look_is_data()
	_pieces_by_tick()
	_lifetime()


## A Truck is destroyed by Player 2's real Self-destruct key outside its Base, the Explosion read each tick.
func _destroy_a_truck() -> void:
	await _k.fresh()
	await _k.t.clear(0)
	_q.units.retype(0, Quick.MOTORBIKE, Vector3(-Kit16.DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	_q.units.retype(1, Quick.TRUCK, Vector3(Kit16.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(Kit16.SETTLE + 15)
	_q.kit.on_tick = _read
	await _q.tokens.destruct(1)
	await _q.kit.advance(FOLLOW_TICKS)
	_q.kit.on_tick = Callable()


## Reads the Explosion that plays (if one does) under the number of ticks it has counted.
func _read() -> void:
	for blast: Explosion in _k.playing():
		var chunks: Array[bool] = []
		var heights: Array[float] = []
		var puffs: Array[bool] = []
		var fades: Array[float] = []
		var rises: Array[float] = []
		for piece: Node in blast.get_node(Kit16.DEBRIS).get_children():
			chunks.append((piece as MeshInstance3D).visible)
			heights.append((piece as MeshInstance3D).position.y)
		for piece: Node in blast.get_node(Kit16.SMOKE).get_children():
			puffs.append((piece as MeshInstance3D).visible)
			fades.append((piece as MeshInstance3D).transparency)
			rises.append((piece as MeshInstance3D).position.y)
		_samples[blast.ticks_played()] = {"flash": (blast.get_node(Kit16.FLASH) as MeshInstance3D).visible,
			"fireball": (blast.get_node(Kit16.FIREBALL) as MeshInstance3D).visible,
			"fireball_x": (blast.get_node(Kit16.FIREBALL) as Node3D).scale.x, "chunks": chunks, "chunk_y": heights,
			"fireball_colour": ((blast.get_node(Kit16.FIREBALL) as MeshInstance3D).material_override as StandardMaterial3D).albedo_color,
			"fireball_material": (blast.get_node(Kit16.FIREBALL) as MeshInstance3D).material_override,
			"puffs": puffs, "puff_t": fades, "puff_y": rises}


## How bright a colour is (the Rec. 709 weights): the order of two fire colours.
func _brightness(colour: Color) -> float:
	return 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b


## The ticks a duration of the data is at the engine's rate, never under one (the Explosion's own rule).
func _ticks(seconds: float) -> int:
	return maxi(roundi(seconds * Engine.physics_ticks_per_second), 1)


## The first Explosion of the record made for Player 2's Truck.
func _truck_blast() -> Dictionary:
	for record: Dictionary in _k.blasts:
		if int(record["player"]) == 1 and record["frame"] == _k.destroyed[-1]["frame"]:
			return record
	return {}


func _picture_only() -> void:
	var problems: PackedStringArray = []
	var scene: PackedScene = load(Kit16.SCENE_PATH) as PackedScene
	var blast: Explosion = scene.instantiate() as Explosion
	_q.kit.need(problems, _k.bodies_under(blast) == 0, "%d CollisionObject3D under an instanced Explosion" % _k.bodies_under(blast))
	_q.kit.need(problems, blast.is_in_group(Kit16.GROUP) and blast.process_mode == Node.PROCESS_MODE_ALWAYS, "group %s, process mode %d" % [blast.is_in_group(Kit16.GROUP), blast.process_mode])
	_q.kit.need(problems, blast.get_node(Kit16.DEBRIS).get_child_count() == 1 and blast.get_node(Kit16.SMOKE).get_child_count() == 1, "the scene holds more than the two templates")
	blast.free()
	var record: Dictionary = _truck_blast()
	_q.kit.need(problems, not record.is_empty(), "no Explosion was made for the Truck")
	if not record.is_empty():
		var chunks: int = _settings.chunk_directions.size()
		var puffs: int = _settings.smoke_offsets.size()
		var sample: Dictionary = _samples.get(0, {})
		_q.kit.need(problems, not sample.is_empty() and sample["chunks"].size() == chunks and sample["puffs"].size() == puffs, "the copies made are %d chunks and %d puffs, the data says %d and %d" % [sample["chunks"].size() if not sample.is_empty() else -1, sample["puffs"].size() if not sample.is_empty() else -1, chunks, puffs])
		_q.kit.need(problems, record["at"] != Vector3.INF, "the Explosion never left")
	var world: Node = _q.units.units[0].get_parent()
	_q.kit.need(problems, _k.destroyed[-1]["in_group"] == 1, "%d Explosions played with the Truck's" % _k.destroyed[-1]["in_group"])
	_q.kit.verdict("picture_only", problems, "an instanced Explosion holds no CollisionObject3D (no body, no Area3D, no layer or mask), is in the group %s with process mode ALWAYS, its scene holds one chunk and one puff as templates that _ready() copies %d and %d times and frees; the Truck's was added under %s" % [Kit16.GROUP, _settings.chunk_directions.size(), _settings.smoke_offsets.size(), world.name])


func _look_is_data() -> void:
	var problems: PackedStringArray = []
	var scene: PackedScene = load(Kit16.SCENE_PATH) as PackedScene
	var host: Node3D = Node3D.new()
	_q.harness.add_child(host)
	var blast: Explosion = scene.instantiate() as Explosion
	host.add_child(blast)
	_q.kit.need(problems, typeof(blast.get(&"chunk_template")) == TYPE_NIL and typeof(blast.get(&"puff_template")) == TYPE_NIL, "the templates freed in _ready() are still referenced by the exports")
	var team: Array[Color] = []
	for path: String in TEAM_PATHS:
		team.append((load(path) as StandardMaterial3D).albedo_color)
	var want: Dictionary = {Kit16.FLASH: _settings.flash_colour, Kit16.FIREBALL: Color(0.0, 0.0, 0.0, 0.0), "Debris/Chunk0": _settings.chunk_colour, "Smoke/Puff0": _settings.smoke_colour}
	for path: String in want:
		var piece: MeshInstance3D = blast.get_node(path) as MeshInstance3D
		var material: StandardMaterial3D = piece.material_override as StandardMaterial3D
		_q.kit.need(problems, piece.mesh is SphereMesh or piece.mesh is BoxMesh, "%s is a %s, not a built-in ball or cube" % [path, piece.mesh.get_class()])
		_q.kit.need(problems, material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s is not in an unshaded material" % path)
		_q.kit.need(problems, piece.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and piece.layers == 1, "%s casts a shadow or is not on render layer 1 alone (layers %d)" % [path, piece.layers])
		if material != null and path != Kit16.FIREBALL:
			_q.kit.need(problems, material.albedo_color.is_equal_approx(want[path]), "%s wears %s, the data says %s" % [path, material.albedo_color, want[path]])
		if material != null:
			for colour: Color in team:
				_q.kit.need(problems, not material.albedo_color.is_equal_approx(Color(colour.r, colour.g, colour.b, material.albedo_color.a)), "%s wears a Team colour" % path)
	var live: Dictionary = _samples.get(0, {})
	_q.kit.need(problems, not live.is_empty() and not _q.units.units.any(func(unit: Unit) -> bool: return live["fireball_material"] == unit.team_material), "the live fireball wears a Team material or was never read")
	_q.kit.need(problems, not live.is_empty() and (live["fireball_colour"] as Color).is_equal_approx(_settings.fireball_colour_start), "the live fireball began in %s, the data says %s" % [live.get("fireball_colour"), _settings.fireball_colour_start])
	var again: Explosion = scene.instantiate() as Explosion
	host.add_child(again)
	_q.kit.need(problems, again.get_node(Kit16.FIREBALL).get("material_override") != blast.get_node(Kit16.FIREBALL).get("material_override"), "two Explosions share one fireball material, so one's colour would change the other's")
	host.queue_free()
	_q.kit.verdict("look_is_data", problems, "the flash and the fireball are balls, the chunks cubes and the puffs balls (built-in shapes), each in an unshaded material of the data's colour (the fireball's changes every tick, one material of its own per Explosion), shadow off, render layer 1, none in a Team colour")


func _pieces_by_tick() -> void:
	var problems: PackedStringArray = []
	var flash: int = _ticks(_settings.flash_seconds)
	var fire: int = _ticks(_settings.fireball_seconds)
	var begin: int = _ticks(_settings.smoke_start_seconds)
	var stagger: int = _ticks(_settings.smoke_stagger_seconds)
	var life: int = _ticks(_settings.lifetime_seconds)
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var size: float = maxf(stats.collision_size.x, stats.collision_size.z)
	var centre_height: float = stats.collision_center.y
	var counted: int = 0
	var peak_tick: int = 0
	var peak: float = 0.0
	var landings: PackedStringArray = []
	for tick: int in life:
		if not _samples.has(tick):
			continue
		counted += 1
		var s: Dictionary = _samples[tick]
		_q.kit.need(problems, s["flash"] == (tick < flash) and s["fireball"] == (tick < fire), "tick %d: flash %s fireball %s" % [tick, s["flash"], s["fireball"]])
		if s["fireball"] and float(s["fireball_x"]) > peak:
			peak = float(s["fireball_x"])
			peak_tick = tick
		for index: int in s["puffs"].size():
			_q.kit.need(problems, s["puffs"][index] == (tick >= begin + index * stagger), "tick %d: puff %d visible %s" % [tick, index, s["puffs"][index]])
			if tick > begin + index * stagger:
				var before: Dictionary = _samples[tick - 1]
				_q.kit.need(problems, float(s["puff_t"][index]) >= float(before["puff_t"][index]) and float(s["puff_y"][index]) > float(before["puff_y"][index]), "tick %d: puff %d does not fade and rise" % [tick, index])
	_q.kit.need(problems, counted == life, "%d of the %d ticks were read" % [counted, life])
	var bright: float = _brightness(_settings.fireball_colour_start)
	var dimmest: float = bright
	for tick: int in range(peak_tick, fire):
		var now: float = _brightness(_samples[tick]["fireball_colour"])
		_q.kit.need(problems, now <= dimmest + Kit16.TOLERANCE, "tick %d: the fireball brightens again (%.3f after %.3f)" % [tick, now, dimmest])
		dimmest = minf(dimmest, now)
	_q.kit.need(problems, _brightness(_samples[peak_tick]["fireball_colour"]) >= bright * PEAK_SHARE and dimmest < bright * DARKENED_SHARE, "the fireball is %.3f bright at its peak and %.3f at its end, from %.3f" % [_brightness(_samples[peak_tick]["fireball_colour"]), dimmest, bright])
	var full: float = _settings.fireball_radius_factor * size
	_q.kit.need(problems, peak <= full + Kit16.TOLERANCE and peak >= full * PEAK_SHARE and absi(peak_tick - roundi(_settings.fireball_swell_fraction * fire)) <= 1, "the fireball peaked at %.3f m on tick %d, the data says %.3f m on tick %d" % [peak, peak_tick, full, roundi(_settings.fireball_swell_fraction * fire)])
	for tick: int in range(fire, life):
		_q.kit.need(problems, is_equal_approx(float(_samples[tick]["fireball_x"]), float(_samples[fire - 1]["fireball_x"])), "tick %d: the hidden fireball is still posed (scale %.3f, last shown %.3f)" % [tick, float(_samples[tick]["fireball_x"]), float(_samples[fire - 1]["fireball_x"])])
	var last: Dictionary = _samples[life - 1]
	for index: int in last["puffs"].size():
		_q.kit.need(problems, float(last["puff_t"][index]) > 0.95, "puff %d is still %.2f thick on the last tick" % [index, 1.0 - float(last["puff_t"][index])])
	for index: int in _settings.chunk_directions.size():
		var edge: float = _settings.chunk_size_factors[index] * size
		var velocity: Vector3 = _settings.chunk_directions[index].normalized() * _settings.chunk_speeds[index]
		var landed: int = -1
		for tick: int in life:
			var age: float = float(tick) / float(Engine.physics_ticks_per_second)
			if landed < 0 and age > 0.0 and centre_height + velocity.y * age - _settings.chunk_gravity * age * age / 2.0 - edge / 2.0 <= 0.0:
				landed = tick
		var seen: int = -1
		for tick: int in life:
			if seen < 0 and not _samples[tick]["chunks"][index]:
				seen = tick
			_q.kit.need(problems, seen < 0 or not _samples[tick]["chunks"][index], "chunk %d shows again on tick %d after it landed on tick %d" % [index, tick, seen])
		_q.kit.need(problems, landed > 0 and seen == landed, "chunk %d was hidden on tick %d, its arc reaches the floor on tick %d" % [index, seen, landed])
		landings.append(str(seen))
	measured.append("chunk_landings=%s" % "/".join(landings))
	_q.kit.verdict("pieces_by_tick", problems, "a Truck's Explosion read on each of its %d ticks: the flash showed for %d ticks, the fireball for %d (peak %.2f m on tick %d, then shrinking), the %d puffs began on ticks %d, %d and %d and every one rose and faded to nothing by the last tick, the %d chunks were hidden on ticks %s (the tick each arc reaches the floor) and never shown again" % [life, flash, fire, peak, peak_tick, _settings.smoke_offsets.size(), begin, begin + stagger, begin + 2 * stagger, _settings.chunk_directions.size(), ", ".join(landings)])


func _lifetime() -> void:
	var problems: PackedStringArray = []
	var record: Dictionary = _truck_blast()
	var life: int = _ticks(_settings.lifetime_seconds)
	_q.kit.need(problems, not record.is_empty() and int(record["gone_frame"]) - int(record["frame"]) == life and int(record["gone_tick"]) - int(record["tick"]) == life, "the Explosion left %d frames and %d ticks after it was added, not %d" % [int(record["gone_frame"]) - int(record["frame"]) if not record.is_empty() else -1, int(record["gone_tick"]) - int(record["tick"]) if not record.is_empty() else -1, life])
	_q.kit.need(problems, not record.is_empty() and int(record["played"]) == life and not bool(record["victim_alive"]), "it had counted %s ticks and its Unit was back in play %s when it left" % [record.get("played", -1), record.get("victim_alive", "?")])
	_q.kit.need(problems, life == Kit16.LIFETIME_TICKS, "the data's lifetime is %d ticks, the story's about 2 s is %d" % [life, Kit16.LIFETIME_TICKS])
	measured.append("lifetime_ticks=%d" % life)
	_q.kit.verdict("lifetime", problems, "the Truck's Explosion, made in a node's tick by a real Self-destruct, freed itself %d ticks after it was added (it counted %d of its own: its first runs in the next tick), before Player 2's Unit could respawn (still waiting when it left)" % [life, life])
