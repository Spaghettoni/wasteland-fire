## Seeded procedural textures for kitbashed concept models.
##
## Everything is CPU-generated at runtime from noise, so a given seed always
## produces the same texture and nothing needs importing. Results are cached per
## parameter set for the lifetime of the process.
extends RefCounted

static var _cache: Dictionary = {}

## Pixel rows of the skull emblem: `X` is bone, `.` is transparent.
const SKULL_ROWS: PackedStringArray = [
	"....XXXXXX....",
	"..XXXXXXXXXX..",
	".XXXXXXXXXXXX.",
	".XXXXXXXXXXXX.",
	"XXXXXXXXXXXXXX",
	"XX...XXXX...XX",
	"XX...XXXX...XX",
	"XX...XXXX...XX",
	"XXXXXXXXXXXXXX",
	"XXXXXX..XXXXXX",
	".XXXXX..XXXXX.",
	".XXXXXXXXXXXX.",
	"..XXXXXXXXXX..",
	"..X.X.X.X.X.X.",
	"..X.X.X.X.X.X.",
	"..............",
]


## The skull emblem from the concept sheet as a crisp pixel texture with alpha.
## Use it on a material with nearest filtering and alpha scissor.
static func skull_texture() -> ImageTexture:
	var key := "skull"
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var width := SKULL_ROWS[0].length()
	var height := SKULL_ROWS.size()
	var img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var on := SKULL_ROWS[y][x] == "X"
			img.set_pixel(x, y, Color(1, 1, 1, 1) if on else Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Mottled grime or rust map. Low-frequency noise blends [param dark] toward
## [param light]; cellular "pits" push the result toward [param bloom] by up to
## [param bloom_amount]. Multiply it under a flat albedo colour to keep one hue
## per part while breaking up the surface.
static func mottle(seed: int, dark: Color, light: Color, bloom: Color,
		bloom_amount: float, size: int = 256) -> ImageTexture:
	var key := "%d|%s|%s|%s|%.2f|%d" % [seed, dark, light, bloom, bloom_amount, size]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var base := FastNoiseLite.new()
	base.seed = seed
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.frequency = 0.012
	base.fractal_octaves = 4
	var pits := FastNoiseLite.new()
	pits.seed = seed + 101
	pits.noise_type = FastNoiseLite.TYPE_CELLULAR
	pits.frequency = 0.05
	pits.fractal_octaves = 2
	var base_img := base.get_seamless_image(size, size)
	var pit_img := pits.get_seamless_image(size, size)
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var b := base_img.get_pixel(x, y).r
			var p := pit_img.get_pixel(x, y).r
			var c := dark.lerp(light, clampf(b * 1.25 - 0.12, 0.0, 1.0))
			c = c.lerp(bloom, clampf((p - 0.55) * 2.5, 0.0, 1.0) * bloom_amount)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
