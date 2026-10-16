class_name TyreTracks
extends Node
## A Map's tyre tracks: the ground Units' tyres leave darker, packed ruts that the ground itself draws
## from one track map and that fade out of it over about a minute.
##
## Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-1 to AC-8. Vocabulary:
## CONTEXT.md (Tyre track, Unit, Map, Round).
##
## What it does, once a physics tick. For each Unit it was handed and each tyre in the Unit type's
## data (UnitStats.tyres: where the tyre touches the ground in the Unit's frame, and its width), it
## takes the tyre's place on the ground in the world and, if the Unit has rolled, adds a stroke from the
## place the tyre was in the tick before to this one, as wide as the tyre and stamped with the Round's
## time. No stroke is made while the Unit is not alive, is not on the floor, was not alive the tick
## before (a spawn, a respawn, a Swap and a bench all pass through "not alive"), whose type changed, or
## whose tyre moved farther than the settings' jump step in the tick (a teleport); a tyre that moved
## less than the minimum step keeps its old place, so a slow roll still draws once it has moved far
## enough and a Unit standing still draws nothing. The Gyrocopter's data lists no tyre, so it leaves
## nothing and no line of code asks which type a Unit is. The list of a tick's strokes, `strokes`, is
## the node's logic: it is what the evidence checks headless. Drawing is only the picture of it.
##
## Why the tracks never run ahead of the tyre drawn (AC-4). The Map is World's first child, so this
## node ticks before the Units, every tick: it reads each Unit where it stood at the END of the tick
## before, one tick behind the body. World draws the Units between their last two ticks (physics
## interpolation), so the drawn tyre is always ahead of where the last stroke ends, never behind it.
##
## The track map. One SubViewport (2D only, transparent, half-float RGBA) the size of the settings'
## texture, which covers the settings' area of the Map. It is cleared once, when the node starts and
## at every Round that starts again (clear()), and never in between, so what was drawn stays; it is
## updated only on a frame that has new strokes, and TyreTrackPainter draws just those into it, with the
## brush canvas_env_tyre_track.gdshader: R is the coverage of a mark and G that times the Round's time
## the stroke was made. A tick only hands the painter its strokes, and the painter draws them once a
## frame, after every tick of the frame: a frame that holds two ticks (any frame while the frame rate
## is under the tick rate) then draws the strokes of both, where a redraw on each tick would replace
## the first tick's with the second's and leave the tracks dashed. What has been driven therefore costs
## nothing: the texture, and the work of an update, are the same after a minute of driving as at the
## start (AC-5).
##
## The ground reads it. The ground shader (spatial_env_ground.gdshader) reads the map through four
## global shader parameters this node publishes, declared in project.godot's [shader_globals]: the map
## (MAP_GLOBAL), the area (AREA_GLOBAL: the corner and the size, metres), the look (LOOK_GLOBAL: the
## darkness, the rut depth, the smoothing, and as w the strength, 0 off and 1 on) and the clock
## (CLOCK_GLOBAL: the Round's time now, the hold, the fade, the rut's reach). The strength in the
## project's default is 0, and this node sets it to 1 when it starts and back to 0 when it leaves the
## tree, so a Map with no TyreTracks node shows no tracks, and neither does a Map whose ground is not
## drawn by that shader (AC-7). The parameters are one set for the whole process: the node that entered
## the tree last holds them (a node that enters again sends every value again), and only that node sets
## the strength to 0 when it leaves, so a Map that enters before the one it replaces has left keeps its
## tracks. Each value goes out through one method, whose signal `published` tells the evidence what went
## where (the headless renderer keeps no global parameters to read back).
##
## The views read the map of their own frame. Sibling SubViewports are drawn in the order they entered
## the tree (measured on 4.7.2, Metal and Vulkan), and SplitScreen's World, which holds the Map and its
## track map, comes before its Views, so a view never reads the map of the frame before: a mark shows on
## the frame it is drawn, and after R no old mark is read against the clock at 0, which would show it at
## full strength for that frame.
##
## Time. The clock is this node's own sum of the physics ticks' delta since the Round began, so the
## Round-over pause, which stops the tree, stops it and every mark's fading with it, and clear() sets
## it to zero (AC-3). A mark keeps its strength for hold_seconds and fades over fade_seconds
## (TyreTrackSettings.strength_at(): the same line the shader computes).
##
## Hand-off (AC-7). SplitScreen sets `units` once, before the Round begins, from its own exports, and
## connects round_started to clear(), with no search of the tree and no singleton. A MapField lists
## the node in tyre_tracks; a Map with none shows no tracks.

## The global shader parameter that holds the track map (a texture).
const MAP_GLOBAL: StringName = &"tyre_track_map"
## The global that holds the track area: x, y the corner with the smallest X and Z (metres), z, w the size.
const AREA_GLOBAL: StringName = &"tyre_track_area"
## The global that holds the look: x darkness, y rut depth (metres), z smoothing, w strength (0 off, 1 on).
const LOOK_GLOBAL: StringName = &"tyre_track_look"
## The global that holds the clock: x the Round's time now (seconds), y the hold, z the fade (seconds),
## w the rut's reach (pixels of the track map).
const CLOCK_GLOBAL: StringName = &"tyre_track_clock"


## One stroke of one tyre in one tick: a line on the ground, as wide as the tyre.
class Stroke extends RefCounted:
	## The index of the Unit in TyreTracks.units.
	var unit_index: int = 0
	## The index of the tyre in that Unit's stats.tyres.
	var tyre_index: int = 0
	## Where the tyre was in the tick before, on the ground as (X, Z), metres.
	var from: Vector2 = Vector2.ZERO
	## Where the tyre is now, as (X, Z), metres.
	var to: Vector2 = Vector2.ZERO
	## The tyre's width, metres.
	var width: float = 0.0
	## The Round's time the stroke was made, seconds.
	var time: float = 0.0


## Emitted for every value this node sends to a global shader parameter: the name and the value. The
## headless renderer keeps no global parameters, so the evidence reads what went out from here.
signal published(parameter: StringName, value: Variant)

## The look, the hold and the fade, the track area and the texture, and the jump (Story 026 AC-2 to
## AC-6): a Map sets them in its scene. A fault first_problem() names is one error in _ready(), and
## then no stroke is drawn and nothing is published.
@export var settings: TyreTrackSettings

## The SubViewport that holds the track map: 2D only, transparent, high dynamic range (half float),
## whose size _ready() sets to the settings' texture size.
@export var track_viewport: SubViewport

## The node that draws the strokes into track_viewport.
@export var painter: TyreTrackPainter

## The Units whose tyres leave tracks, set by SplitScreen before the Round begins. Setting it makes
## the node forget where it saw each Unit last, so the first tick after a hand-off draws nothing.
var units: Array[Unit] = []:
	set(value):
		units = value
		_forget()

## The strokes made on the last physics tick, oldest first: a new list every tick. This is the node's
## logic and what the headless evidence checks.
var strokes: Array[Stroke] = []

## The Round's time now, seconds: the sum of the physics ticks' delta since the Round began (zero at
## clear()). Read-only: assigning to it pushes an error and changes nothing.
var now: float:
	get:
		return _now
	set(_value):
		push_error("TyreTracks '%s': now is read-only. clear() sets it to zero and the physics tick moves it." % name)

var _now: float = 0.0
var _usable: bool = false
## The node whose values the global shader parameters hold: the one that entered the tree last.
static var _holder: TyreTracks = null
## Per Unit: where each of its tyres was on the ground, as (X, Z), when it was last seen or last drew.
var _last_points: Array[PackedVector2Array] = []
## Per Unit: whether it was alive on the last tick.
var _last_alive: Array[bool] = []
## Per Unit: the stats it had on the last tick, so a change of type draws no stroke.
var _last_stats: Array[UnitStats] = []


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("TyreTracks '%s': %s, so no tracks are drawn." % [name, problem])
		set_physics_process(false)
		return
	_usable = true
	track_viewport.size = settings.texture_size
	_forget()
	clear()
	_publish_all()


func _enter_tree() -> void:
	if _usable:
		_publish_all()


func _exit_tree() -> void:
	if _usable and _holder == self:
		_holder = null
		_publish(LOOK_GLOBAL, Vector4.ZERO)


func _physics_process(delta: float) -> void:
	_now += delta
	strokes = []
	for index: int in units.size():
		_follow(index)
	for stroke: Stroke in strokes:
		_paint(stroke)
	_publish_clock()


## Starts the ground clean (Story 026 AC-3): the track map is cleared on its next update, the clock
## is zero, no stroke waits to be drawn and every Unit is forgotten, so none draws a stroke from where it
## stood before. SplitScreen connects round_started to it, which a restart emits after it benched both
## Units. The painter is redrawn empty, so the commands of its last redraw do not draw the last
## strokes again on top of the cleared map.
func clear() -> void:
	_now = 0.0
	strokes = []
	_forget()
	if painter != null:
		painter.discard()
		painter.queue_redraw()
	if track_viewport != null:
		track_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		track_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _usable:
		_publish_clock()


## The three quads of a stroke in the track map's pixels, left rim, core and right rim, each a
## PackedVector2Array of four corners in the order the painter takes them: the stroke's start and end
## pushed out to the side by an inner and an outer reach, in metres. The rim is the settings' rim_pixels
## wide, centred on the tyre's edge, so the mark falls to half strength exactly at the tyre's width (AC-1):
## the outer reach is half the tyre's width plus half the rim, the inner one half the width less half the
## rim (never below zero). The quads share their edge corners, which are the same numbers.
func pixel_quads(stroke: Stroke) -> Array[PackedVector2Array]:
	var rim: float = settings.rim_pixels * minf(settings.metres_per_pixel().x, settings.metres_per_pixel().y)
	var outer: float = stroke.width / 2.0 + rim / 2.0
	var inner: float = maxf(stroke.width / 2.0 - rim / 2.0, 0.0)
	var across: Vector2 = (stroke.to - stroke.from).orthogonal().normalized()
	var corners: Array[PackedVector2Array] = []
	for reach: float in [-outer, -inner, inner, outer]:
		corners.append(PackedVector2Array([settings.world_to_pixel(stroke.from + across * reach), settings.world_to_pixel(stroke.to + across * reach)]))
	var quads: Array[PackedVector2Array] = []
	for band: int in corners.size() - 1:
		quads.append(PackedVector2Array([corners[band][0], corners[band + 1][0], corners[band + 1][1], corners[band][1]]))
	return quads


## The coverage at each corner of the three quads of pixel_quads(), in the same order and the order of
## each quad's corners: 0 on the outer edge of a rim, 1 on its inner edge and everywhere in the core.
func quad_edges() -> Array[PackedFloat32Array]:
	return [PackedFloat32Array([0.0, 1.0, 1.0, 0.0]), PackedFloat32Array([1.0, 1.0, 1.0, 1.0]), PackedFloat32Array([1.0, 0.0, 0.0, 1.0])]


## The ground points of a Unit's tyres now, as (X, Z), in the order of its stats.tyres: empty for a
## type that lists none.
func tyre_points(unit: Unit) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for tyre: TyreContact in unit.stats.tyres:
		points.append(tyre.world_point(unit.global_transform))
	return points


## The first fault that stops this node from working, or an empty String.
func _first_problem() -> String:
	if settings == null:
		return "settings is not assigned"
	var problem: String = settings.first_problem()
	if not problem.is_empty():
		return "the settings are unusable (%s)" % problem
	if track_viewport == null:
		return "track_viewport is not assigned"
	if painter == null:
		return "painter is not assigned"
	return ""


## Makes the stroke of each of one Unit's tyres for this tick, if it has any (class doc), and
## remembers where the Unit's tyres are for the next.
func _follow(index: int) -> void:
	var unit: Unit = units[index]
	if unit == null or unit.stats == null:
		_last_alive[index] = false
		return
	var points: PackedVector2Array = tyre_points(unit)
	var kept: PackedVector2Array = points.duplicate()
	var rolling: bool = unit.is_alive and _last_alive[index] and _last_stats[index] == unit.stats
	rolling = rolling and _last_points[index].size() == points.size() and unit.is_on_floor()
	if rolling:
		for tyre: int in points.size():
			var step: float = _last_points[index][tyre].distance_to(points[tyre])
			if step > settings.jump_step:
				continue
			if step > settings.min_step:
				strokes.append(_stroke(index, tyre, _last_points[index][tyre], points[tyre], unit.stats.tyres[tyre].width))
			else:
				kept[tyre] = _last_points[index][tyre]
	_last_points[index] = kept
	_last_alive[index] = unit.is_alive
	_last_stats[index] = unit.stats


## Hands the painter the three quads of a stroke, stamped with the stroke's time.
func _paint(stroke: Stroke) -> void:
	var quads: Array[PackedVector2Array] = pixel_quads(stroke)
	var edges: Array[PackedFloat32Array] = quad_edges()
	for band: int in quads.size():
		painter.add(quads[band], edges[band], stroke.time)


func _stroke(unit_index: int, tyre_index: int, from: Vector2, to: Vector2, width: float) -> Stroke:
	var stroke: Stroke = Stroke.new()
	stroke.unit_index = unit_index
	stroke.tyre_index = tyre_index
	stroke.from = from
	stroke.to = to
	stroke.width = width
	stroke.time = _now
	return stroke


## Forgets where every Unit was seen last: none draws a stroke on the next tick.
func _forget() -> void:
	_last_points = []
	_last_alive = []
	_last_stats = []
	for _unit: Unit in units:
		_last_points.append(PackedVector2Array())
		_last_alive.append(false)
		_last_stats.append(null)


## Sends every global shader parameter (the map, the area, the look with its strength at 1 and the
## clock) and makes this node the one that holds them.
func _publish_all() -> void:
	_holder = self
	_publish(MAP_GLOBAL, track_viewport.get_texture())
	_publish(AREA_GLOBAL, Vector4(settings.area_origin.x, settings.area_origin.y, settings.area_size.x, settings.area_size.y))
	_publish(LOOK_GLOBAL, Vector4(settings.darkness, settings.rut_depth, settings.smoothing, 1.0))
	_publish_clock()


## Sends the clock to the ground shader: the Round's time now, the hold, the fade and the rut's reach.
func _publish_clock() -> void:
	_publish(CLOCK_GLOBAL, Vector4(_now, settings.hold_seconds, settings.fade_seconds, settings.rut_reach))


## Sends one value to a global shader parameter and tells `published` listeners.
func _publish(parameter: StringName, value: Variant) -> void:
	RenderingServer.global_shader_parameter_set(parameter, value)
	published.emit(parameter, value)
