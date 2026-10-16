class_name TyreTrackPainter
extends Node2D
## Draws the strokes a TyreTracks hands it into the SubViewport it sits in, the Map's track map: one quad
## for each stroke, with the brush of canvas_env_tyre_track.gdshader (its material).
##
## Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-5 (the cost does not grow with
## what has been driven: the map keeps what was drawn, and this node draws only the strokes added since
## the last redraw). Vocabulary: CONTEXT.md (Tyre track).
##
## A CanvasItem keeps the commands of its last _draw() until it is drawn again, and a SubViewport that
## is updated renders them all, on top of what the target holds. So the quads wait in a list that
## _draw() empties as it draws them, and an update of the viewport comes with a redraw (one with an
## empty list draws nothing, which is how a clear leaves no ghost of the last strokes). This node asks
## for both once a frame, in _process(), after every physics tick of the frame has queued its quads: a
## redraw asked for on each tick would run after that tick and replace the commands of the tick before,
## so a frame that holds two ticks would draw only the second tick's quads (measured on 4.7.2). It runs
## while the tree is paused too, so the quads of the tick that paused it are drawn.
## A quad's corners are in the track map's pixels. Its `edges` are the coverage of each corner (the
## brush's UV.x, interpolated across the quad: 1 for a corner in the core, 0 on the outer edge of a
## rim), and UV.y is the stroke's time in seconds. A stroke is three quads side by side, a rim, the
## core and a rim, whose shared corners are the same numbers, so they meet without a gap or an overlap.

## The quads waiting to be drawn, in pixels, oldest first.
var _quads: Array[PackedVector2Array] = []
## The coverage of each corner of each waiting quad, in the same order.
var _edges: Array[PackedFloat32Array] = []
## The time of each waiting quad, seconds of the Round's time, in the same order.
var _times: Array[float] = []


## Queues a quad (its corners, in pixels, and the coverage at each corner) to be drawn at the next
## redraw, stamped with `time`. Does nothing for a list of corners that is empty or has no coverage each.
func add(corners: PackedVector2Array, edges: PackedFloat32Array, time: float) -> void:
	if corners.is_empty() or corners.size() != edges.size():
		return
	_quads.append(corners)
	_edges.append(edges)
	_times.append(time)


## Throws away every quad still waiting. The commands of the last redraw are replaced at the next one.
func discard() -> void:
	_quads = []
	_edges = []
	_times = []


## How many quads wait to be drawn.
func waiting() -> int:
	return _quads.size()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _quads.is_empty():
		return
	queue_redraw()
	var target: SubViewport = get_viewport() as SubViewport
	if target != null:
		target.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	for index: int in _quads.size():
		var time: float = _times[index]
		var colours: PackedColorArray = PackedColorArray()
		var uvs: PackedVector2Array = PackedVector2Array()
		for edge: float in _edges[index]:
			colours.append(Color.WHITE)
			uvs.append(Vector2(edge, time))
		draw_primitive(_quads[index], colours, uvs)
	discard()
