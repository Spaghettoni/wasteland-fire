extends SceneTree
## Renders a Map from straight above into a PNG, the picture its card shows in the map choice
## (Story 038, src/gameplay/maps/map_entry.gd). Tooling only: nothing under src/ depends on it.
##
## Run windowed (a headless run renders nothing), from the repository root, for example under a
## virtual display:
##   xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s res://tools/maps/render_preview.gd -- \
##     --map=res://src/gameplay/maps/map_02/map_02.tscn --out=assets/art/ui/map_02_preview.png --span=124x254
## --span is the width (x) by depth (z) in metres to frame, centred on the Map's origin; the picture
## keeps that aspect and is PREVIEW_HEIGHT pixels tall unless --width is given. --rotate=ccw turns the
## picture a quarter turn counter-clockwise (Map 02, whose Bases are north and south, then reads like
## Map 01, Orange on the left).

const PREVIEW_HEIGHT: int = 800
const CAMERA_HEIGHT: float = 200.0
const SETTLE_FRAMES: int = 10


func _init() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var span: PackedStringArray = String(args.get("span", "300x100")).split("x")
	var width_m: float = float(span[0])
	var depth_m: float = float(span[1])
	var height_px: int = int(args.get("height", PREVIEW_HEIGHT))
	var width_px: int = int(args.get("width", roundi(height_px * width_m / depth_m)))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width_px, height_px)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var map: Node = (load(String(args["map"])) as PackedScene).instantiate()
	viewport.add_child(map)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = depth_m
	camera.far = CAMERA_HEIGHT * 2.0
	viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, CAMERA_HEIGHT, 0))
	camera.current = true
	for frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if String(args.get("rotate", "")) == "ccw":
		image.rotate_90(COUNTERCLOCKWISE)
	var error: Error = image.save_png(String(args["out"]))
	print("render_preview: %s -> %s %dx%d (%s)" % [args["map"], args["out"], width_px, height_px, error_string(error)])
	quit()
