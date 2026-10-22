extends SceneTree
## Writes the colour-correction lookup texture of Map 01's colour grade: a 3D lookup the Environment reads
## (Environment.adjustment_color_correction), warmer in the highlights, a little cooler in the shadows and a little
## dusty. Every number is data in colour_grade.json beside this script, so this script holds none but 0 and 1; the
## texture is written from it and from nothing downloaded, and the same file always gives the same texture.
##
## Implements: production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md AC-3 (a colour grade that makes
## the scene warmer and dustier, the Team colours still apart) and AC-5 (every value is data); design/rules.md "Teams and
## visual style".
##
## Run it WINDOWED (a headless engine has no renderer to hold a 3D texture, and would write an empty one):
##     godot --path . --resolution 64x64 -s res://tools/colour_grade/build_colour_grade_lut.gd
## It prints one LUT line and quits with 0, or with 1 when the file could not be read or written. A path after
## the "--" names another parameter file, for a try that is not the shipped grade.
##
## How the engine reads the texture (measured on 4.7.2 with an identity lookup, the Story 027 evidence doc keeps the
## run): a colour (r, g, b) in 0 to 1, after the tone mapper and in sRGB, is the coordinate into the 3D texture, with
## x for red, y for green and z (the layer) for blue, sampled with linear filtering and NO half-texel correction, so
## texel i is read at the coordinate (i + a half) / size, and the first and the last texel hold the lookup of black and
## of white exactly (otherwise black would read as the first texel's colour). The grade (grade()) is the lookup of a
## colour, so the texel at a coordinate holds grade(coordinate).

## Where the parameters are.
const PARAMETERS_PATH: String = "res://tools/colour_grade/colour_grade.json"


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var source: String = arguments[0] if arguments.size() > 0 else PARAMETERS_PATH
	var parameters: Dictionary = read_parameters(source)
	if parameters.is_empty():
		push_error("build_colour_grade_lut: %s could not be read as a JSON object." % source)
		quit(1)
		return
	var texture: ImageTexture3D = build(parameters)
	var path: String = parameters["output"]
	var error: int = ResourceSaver.save(texture, path)
	print("LUT %s size=%d error=%d black=%s white=%s" % [path, texture.get_depth(), error,
			grade(Color.BLACK, parameters), grade(Color.WHITE, parameters)])
	quit(int(error != OK))


## The parameters of a JSON file as a Dictionary, or an empty one when it cannot be read or is not an object.
static func read_parameters(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The lookup texture: size layers of size by size texels, texel (x, y, z) holding the grade of the colour at the
## coordinates texel_coordinate() gives x, y and z.
static func build(parameters: Dictionary) -> ImageTexture3D:
	var size: int = int(parameters["size"])
	var texture: ImageTexture3D = ImageTexture3D.new()
	texture.create(Image.FORMAT_RGBA8, size, size, size, false, build_layers(parameters))
	return texture


## The layers of the lookup texture as images (build() gives them to the texture): the layer z is the texels of blue
## coordinate z, row y of them green, column x red. Images are plain data, so a headless run, which cannot read a 3D
## texture back, can still make them and compare them with the bytes of the file that was written.
static func build_layers(parameters: Dictionary) -> Array[Image]:
	var size: int = int(parameters["size"])
	var layers: Array[Image] = []
	for blue: int in size:
		var layer: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		for green: int in size:
			for red: int in size:
				var source: Color = Color(texel_coordinate(red, size, parameters),
						texel_coordinate(green, size, parameters), texel_coordinate(blue, size, parameters))
				layer.set_pixel(red, green, grade(source, parameters))
		layers.append(layer)
	return layers


## The coordinate (0 to 1) at which the engine reads texel `index` of a lookup `size` texels a side: its centre, except
## for the first texel, read at 0, and the last, read at 1, which hold the lookup of black and of white exactly.
static func texel_coordinate(index: int, size: int, parameters: Dictionary) -> float:
	if index <= 0:
		return 0.0
	if index >= size - 1:
		return 1.0
	return (float(index) + float(parameters["texel_centre"])) / float(size)


## The grade of a colour (sRGB, after the tone mapper): each channel is multiplied by a tint that goes from the shadow
## tint to the highlight tint across the luminance (the smoothstep of tint_pivot with tint_width on each side), the
## colour is drawn to its grey by `saturation` (1 keeps it), and then to the haze colour by `haze`, most in the
## shadows and none in white. The result is kept from 0 to 1.
static func grade(source: Color, parameters: Dictionary) -> Color:
	var luminance: float = source.get_luminance()
	var pivot: float = parameters["tint_pivot"]
	var width: float = parameters["tint_width"]
	var brightness: float = smoothstep(pivot - width, pivot + width, luminance)
	var tint: Color = colour_of(parameters["shadow_tint"]).lerp(colour_of(parameters["highlight_tint"]), brightness)
	var tinted: Color = Color(source.r * tint.r, source.g * tint.g, source.b * tint.b)
	var grey: float = tinted.get_luminance()
	var graded: Color = Color(grey, grey, grey).lerp(tinted, parameters["saturation"])
	graded = graded.lerp(colour_of(parameters["haze_colour"]), float(parameters["haze"]) * (1.0 - luminance))
	return graded.clamp()


## A colour from a JSON object with r, g and b.
static func colour_of(values: Dictionary) -> Color:
	return Color(values["r"], values["g"], values["b"])
