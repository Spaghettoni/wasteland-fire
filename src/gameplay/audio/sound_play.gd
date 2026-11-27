class_name SoundPlay
extends RefCounted
## Plays one-shot sounds (the first sound pass, 2026-11): a positional one at a point in the world
## (a shot, a hit, a blast) or a flat one for the menus. Each call makes its own player, adds it
## under `parent`, starts it and frees it when the sound ends, so a sound outlives the node that
## asked for it as long as `parent` stays (pass the node's parent, as Shot does).
##
## Split screen: the views share one World3D (SplitScreen's class doc) and each SubViewport's
## current Camera3D is a listener, so a positional sound is heard by every Player, panned and
## faded for each view, and the views' outputs are added together.
##
## The streams come from data: an AudioStreamRandomizer .tres (src/gameplay/audio/data) picks a
## take and jitters the pitch, so a cadence of shots does not repeat one sample. A null stream or
## parent does nothing, so a scene without a sound stays silent and nothing is logged.

## Default loudness reference distance for positional sounds, in metres (AudioStreamPlayer3D.unit_size).
const DEFAULT_UNIT_SIZE: float = 12.0
## Default distance beyond which a positional sound is not heard at all, in metres.
const DEFAULT_MAX_DISTANCE: float = 160.0


## Plays `stream` once at world position `at`, `volume_db` louder or softer than the file, heard
## at full loudness within `unit_size` metres (zero or less: DEFAULT_UNIT_SIZE) and not at all
## past `max_distance`. Returns the
## player (already started and set to free itself), or null when nothing was played.
static func at(parent: Node, stream: AudioStream, position: Vector3, volume_db: float = 0.0,
		unit_size: float = DEFAULT_UNIT_SIZE, max_distance: float = DEFAULT_MAX_DISTANCE) -> AudioStreamPlayer3D:
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = unit_size if unit_size > 0.0 else DEFAULT_UNIT_SIZE
	player.max_distance = max_distance
	# A blast that ends the Round plays on through the Round-over pause.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.global_position = position
	player.play()
	return player


## Plays `stream` once with no position (menus), `volume_db` louder or softer than the file.
## Returns the player (already started and set to free itself), or null when nothing was played.
static func flat(parent: Node, stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null or parent == null or not parent.is_inside_tree():
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.play()
	return player


## Makes a looping positional player under `parent` (not started): an engine, a flamer, a fire.
## The stream must loop itself (the .ogg is imported with loop on). Null for a null stream.
static func make_loop(parent: Node, stream: AudioStream, volume_db: float = 0.0,
		unit_size: float = DEFAULT_UNIT_SIZE, max_distance: float = DEFAULT_MAX_DISTANCE) -> AudioStreamPlayer3D:
	if stream == null or parent == null:
		return null
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.max_distance = max_distance
	parent.add_child(player)
	return player
