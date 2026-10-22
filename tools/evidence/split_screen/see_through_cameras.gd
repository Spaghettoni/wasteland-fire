extends RefCounted
## The cameras of the see_through scenario (Story 027 AC-4 and AC-7): cameras (each Player's camera never draws the other Player's silhouette layer and draws its
## own, in the view from above the Round starts in, in the chase view after the real key switches it, with the other Player's view on the other settings, and after
## the keys switch it back; no copy and no fill quad of the other Player's Unit is drawn by a camera in any view, every drawn mesh of both Units is drawn by both cameras,
## the silhouette layers are neither the default layer nor tower_top, and no third camera draws the world). Run by see_through.gd. Tooling only. Every number comes from the
## game's data; the scenario types only its test inputs. What a view shows of the silhouette is the windowed light_showcase's.

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where Player 1's Unit is staged: the open middle of the Map, 30 m west of its middle (Player 2's Unit stays in its Garage).
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## The keys that switch a Player's view: Q for Player 1, / for Player 2.
const VIEW_KEYS: Array[Key] = [KEY_Q, KEY_SLASH]
## Ticks a view is given to glide to its place.
const SETTLE_TICKS: int = 30

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit27
var _q: Quick
var _problems: PackedStringArray = []
var _rows: PackedStringArray = []


func _init(kit: Kit27, _at_start: Dictionary) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().turrets_down()
	await _k.stage(0, Quick.MOTORBIKE, OPEN, Vector3.RIGHT)
	_judge("the Round's start: both views from above")
	for player: int in 2:
		await _q.kit.press_settled([VIEW_KEYS[player]] as Array[Key])
		await _q.kit.advance(SETTLE_TICKS)
		_judge("after the key of Player %d: its view in the chase view, the other from above" % (player + 1))
	for player: int in 2:
		await _q.kit.press_settled([VIEW_KEYS[player]] as Array[Key])
		await _q.kit.advance(SETTLE_TICKS)
	_judge("after both keys again: both views from above")
	var cameras: int = _q.harness.split.find_children("*", "Camera3D", true, false).size()
	_q.kit.need(_problems, cameras == 2, "the launch scene holds %d cameras, not the two of the Players" % cameras)
	measured.append("camera_reads=%d" % _rows.size())
	_q.kit.verdict("cameras", _problems, "in each of the %d states of the two views (%s) each Player's camera draws its own silhouette layer and never the other Player's (its never_drawn_layers is the other layer and its culling mask is every layer but that one and what its settings hide), so no copy and no fill quad of the other Player's Unit is drawn by it, and every drawn mesh of both Units is drawn by both cameras; the launch scene holds the two cameras of the Players and no other" % [_rows.size(), "; ".join(_rows)])


## Reads both cameras in the state the views are in and judges them: see the class doc.
func _judge(state: String) -> void:
	var settings: SilhouetteSettings = _k.settings()
	var words: PackedStringArray = []
	for camera_player: int in 2:
		var camera: ChaseCamera = _k.camera(camera_player)
		var own: int = settings.layer_of(camera_player)
		var other: int = settings.layer_of(1 - camera_player)
		var hidden: int = camera.settings.hidden_layers
		var label: String = "%s, Player %d's camera" % [state, camera_player + 1]
		_q.kit.need(_problems, camera.never_drawn_layers == other, "%s: never_drawn_layers is %d, not the other Player's layer %d" % [label, camera.never_drawn_layers, other])
		_q.kit.need(_problems, camera.cull_mask == (ChaseCamera.ALL_VISUAL_LAYERS & ~(other | hidden)), "%s: the culling mask is %d, not every layer but the other Player's silhouettes and what the settings hide (%d)" % [label, camera.cull_mask, hidden])
		_q.kit.need(_problems, (camera.cull_mask & own) == own and (camera.cull_mask & other) == 0, "%s: it draws its own layer %d or the other's %d (mask %d)" % [label, own, other, camera.cull_mask])
		for unit_player: int in 2:
			var copies: Array[MeshInstance3D] = _k.copies_of(unit_player)
			_q.kit.need(_problems, not copies.is_empty(), "%s: Player %d's Unit has no copy, so nothing is judged" % [label, unit_player + 1])
			for copy: MeshInstance3D in copies:
				var drawn: bool = (camera.cull_mask & copy.layers) != 0
				_q.kit.need(_problems, drawn == (unit_player == camera_player), "%s: it %s the copy %s of Player %d's Unit" % [label, "draws" if drawn else "does not draw", copy.name, unit_player + 1])
			var fill: MeshInstance3D = _k.fill_of(unit_player)
			_q.kit.need(_problems, fill != null, "%s: Player %d's Unit has no fill quad, so nothing is judged" % [label, unit_player + 1])
			if fill != null:
				var fill_drawn: bool = (camera.cull_mask & fill.layers) != 0
				_q.kit.need(_problems, fill_drawn == (unit_player == camera_player), "%s: it %s the fill quad of Player %d's Unit" % [label, "draws" if fill_drawn else "does not draw", unit_player + 1])
			for mesh: MeshInstance3D in _k.drawn_meshes(unit_player):
				_q.kit.need(_problems, (camera.cull_mask & mesh.layers) != 0, "%s: it does not draw the mesh %s of Player %d's Unit" % [label, mesh.name, unit_player + 1])
		words.append("p%d %s hides %d" % [camera_player + 1, "above" if hidden != 0 else "chase", hidden])
	_rows.append("%s (%s)" % [state.get_slice(":", 0), ", ".join(words)])
