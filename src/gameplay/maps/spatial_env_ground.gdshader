// Map 01's open ground: the sand, the canyon road and the salt flat, each a ShaderMaterial of this
// shader (src/gameplay/maps/map_01/materials/sand.tres, road.tres, salt_flat.tres).
//
// Author: Tomas Kunzo with Claude Code, 2026-10-10 (the developer's "more thorough textures for the
// ground"; production/qa/evidence/map-art-2026-10-10-evidence.md).
// Purpose: the cameras see mostly ground, from 26 m above or from behind a Unit, under a low sun;
// a flat noise colour reads as a painted floor. Every layer here comes from seamless noise textures
// generated in code (tools/blender/build_ground_textures.py writes
// src/gameplay/maps/map_01/textures/ground_*.png), sampled in world space, metres on X and Z, so
// the Island's CSG, the road's CSG and the salt flat's plane join without seams and nothing tiles
// at a size the cameras see. Layers, large to small: a macro tone over hundreds of metres; a mottle
// over tens; wind streaks stretched along one direction; plates and cracks of a cell pattern (the
// salt flat's crust, the road's dried mud); stones of the same pattern at a finer size, gathered
// in patches; a fine grain. The relief under the sun comes from relief maps of the same patterns
// (gentle swells, the stones' domes, the cracks' grooves and rims), stored as world-oriented
// normals of a level surface, so the meshes need no tangents. Side faces (the Island's shore edge)
// take side_colour and no relief. The macro and mottle sizes are the same in all three materials,
// so their tones run on where two surfaces meet; near the edges of a mesh whose UV spans it (the
// salt flat's plane), edge_width blends toward the edge tones (the sand's).
// Tyre tracks (Story 026, production/epics/wasteland-fire/story-026-tyre-tracks.md): a Map that has a
// TyreTracks node (src/gameplay/maps/tyre_tracks.gd) keeps one track map over its ground, a texture the
// tyres of the ground Units write into as they roll, and publishes it, its area, its look and its clock
// as global shader parameters (project.godot's [shader_globals]). Here the map is read in world space
// like every layer above: where a mark lies the colour darkens, the roughness drops (packed earth is
// smoother) and the rut's two sides, read from the mark's strength one reach to either side, tilt the
// surface toward and away from the low sun. The mark's strength is its coverage times what is left of it
// at its age, the Round's time now less the time it was written, through a hold and a fade. Level faces
// only (the shore edge takes none), and only on these three surfaces: the water, the fords, the
// channels and the Garage floors are other materials, and a Map with no TyreTracks node leaves the
// strength at the project's default of 0, which makes every term below exactly nothing.
// Target: desktop, Forward+ renderer (project.godot rendering_method); macOS Metal and the Windows
// build. No quality tiers or fallback yet.
// Budget: one fragment pass, fifteen texture reads (ten mipmapped and anisotropic, and the five of the
// tyre track map, linear without mipmaps: the mark and one to either side on X and on Z), no loops, no
// branches, no keywords or variants.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// The cell textures store distances divided by this (ground_cells.png fits 0..0.9 cell units).
const float CELL_DISTANCE_SCALE = 0.9;
// Offsets that keep samples of the same texture at different sizes from lining up.
const vec2 MOTTLE_OFFSET = vec2(0.31, 0.67);
const vec2 FINE_CRACK_OFFSET = vec2(0.5, 0.21);
const vec2 STONE_OFFSET = vec2(0.13, 0.77);
// A streak is this many times longer than it is wide.
const float STREAK_ASPECT = 8.0;
// Share of a stone's radius that is fully stone; the rest fades to the ground.
const float STONE_EDGE = 0.75;
// Stones' tone: the lowest multiplier of stone_colour and the spread up from it, by cell tone.
const float STONE_TONE_LOW = 0.82;
const float STONE_TONE_SPREAD = 0.36;
// Stones' size spread: the smallest and largest share of stone_radius, picked per cell through a
// multiplier that turns the cell's tone into a second random value.
const float STONE_SIZE_LOW = 0.5;
const float STONE_SIZE_HIGH = 1.2;
const float STONE_SIZE_HASH = 13.0;
// Roughness taken off where a stone lies.
const float STONE_SMOOTHER = 0.15;
// The mottle values between which stones gather (stone_patchiness).
const float GATHER_LOW = 0.38;
const float GATHER_HIGH = 0.68;
// How far the mottle shifts the edge blend's line, as a share of edge_width.
const float EDGE_WOBBLE = 0.8;
// A face is level (the surface's tones and relief) from this up-component of its normal, a side
// (side_colour) below the first; between them the two blend.
const float LEVEL_LOW = 0.55;
const float LEVEL_HIGH = 0.85;
// The smallest relief normal height used when turning a relief normal into a slope.
const float RELIEF_MIN_HEIGHT = 0.2;
// The smallest coverage the track map's time is divided by: the map stores the coverage times the
// time a stroke was written, so the time is G over R, and a texel with next to no coverage has none.
const float TRACK_MIN_COVERAGE = 0.004;
// The shortest fade, seconds, that the fade is divided by, so a clock that was never set divides by
// something.
const float TRACK_MIN_SECONDS = 0.001;

// R, G: two smooth fractal noises; B: a fine one (ground_soft.png).
uniform sampler2D soft_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// The relief of soft_noise's R (ground_soft_normal.png).
uniform sampler2D soft_relief : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// R: distance to the nearest cell point; G: gap to the second nearest; B: a tone per cell; a
// 24-cell tile (ground_cells.png).
uniform sampler2D cell_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// The relief of a round stone around each cell point (ground_stones_normal.png).
uniform sampler2D stone_relief_map : hint_default_white, filter_linear_mipmap_anisotropic,
		repeat_enable;
// The relief of the cracks along the cell borders (ground_cracks_normal.png).
uniform sampler2D crack_relief_map : hint_default_white, filter_linear_mipmap_anisotropic,
		repeat_enable;

// Tyre tracks (Story 026), published by the Map's TyreTracks (declared in project.godot's
// [shader_globals]). The track map: R the coverage of a mark, G that times the Round's time it was
// written, a half-float texture drawn into by the tyres.
global uniform sampler2D tyre_track_map : filter_linear, repeat_disable;
// The track area: xy the corner with the smallest X and Z, zw its size, metres.
global uniform vec4 tyre_track_area;
// The look: x the darkness a mark takes off the colour, y the rut's depth (metres), z the roughness a
// mark takes off, w the strength of the whole effect (0 off, the project's default; 1 on).
global uniform vec4 tyre_track_look;
// The clock: x the Round's time now, y the hold, z the fade (seconds), w the rut's reach (pixels of the map).
global uniform vec4 tyre_track_clock;

group_uniforms tones;
// The surface's three tones, dark to light, blended by the macro tone and the mottle.
uniform vec4 tone_dark : source_color = vec4(0.58, 0.45, 0.29, 1.0);
uniform vec4 tone_mid : source_color = vec4(0.671, 0.535, 0.348, 1.0);
uniform vec4 tone_light : source_color = vec4(0.75, 0.62, 0.42, 1.0);
// Stones and gravel.
uniform vec4 stone_colour : source_color = vec4(0.47, 0.38, 0.29, 1.0);
// The cracks between plates.
uniform vec4 crack_colour : source_color = vec4(0.55, 0.48, 0.38, 1.0);
// Side faces (the Island's shore edge).
uniform vec4 side_colour : source_color = vec4(0.45, 0.35, 0.23, 1.0);
// The tones the edge blend goes toward (the sand's).
uniform vec4 edge_tone_dark : source_color = vec4(0.58, 0.45, 0.29, 1.0);
uniform vec4 edge_tone_mid : source_color = vec4(0.671, 0.535, 0.348, 1.0);
uniform vec4 edge_tone_light : source_color = vec4(0.75, 0.62, 0.42, 1.0);

group_uniforms sizes;
// Metres per tile of each sample.
uniform float macro_size : hint_range(1.0, 1000.0) = 260.0;
uniform float mottle_size : hint_range(1.0, 200.0) = 36.0;
uniform float streak_size : hint_range(1.0, 200.0) = 60.0;
uniform float grain_size : hint_range(0.1, 50.0) = 5.0;
uniform float stone_size : hint_range(0.5, 100.0) = 14.0;
uniform float crack_size : hint_range(1.0, 400.0) = 90.0;
uniform float fine_crack_size : hint_range(1.0, 200.0) = 30.0;
// The wind's direction for the streaks, radians from +X toward +Z.
uniform float streak_angle : hint_range(-3.15, 3.15) = 0.4;
// How far in from the mesh's edge the edge blend reaches, metres (0: no blend), and the mesh's size
// in metres along its UV's u and v.
uniform float edge_width : hint_range(0.0, 20.0) = 0.0;
uniform vec2 mesh_size = vec2(1.0, 1.0);

group_uniforms amounts;
uniform float macro_amount : hint_range(0.0, 1.0) = 0.5;
uniform float mottle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float streak_amount : hint_range(0.0, 0.5) = 0.07;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.06;
// Share of cells that hold a stone, its radius in cell units, and how far the stones gather in the
// mottle's patches (0: spread evenly; 1: only in patches).
uniform float stone_amount : hint_range(0.0, 1.0) = 0.35;
uniform float stone_radius : hint_range(0.0, 0.42) = 0.3;
uniform float stone_patchiness : hint_range(0.0, 1.0) = 0.75;
// The plates' cracks: how much shows, their width in cell units, the tone change per plate.
uniform float crack_amount : hint_range(0.0, 1.0) = 0.0;
uniform float crack_width : hint_range(0.0, 0.3) = 0.06;
uniform float plate_amount : hint_range(0.0, 0.3) = 0.0;
// The fine cracks inside the plates.
uniform float fine_crack_amount : hint_range(0.0, 1.0) = 0.0;
uniform float fine_crack_width : hint_range(0.0, 0.3) = 0.04;
// Relief strengths, and the surface's roughness and specular.
uniform float swell_relief : hint_range(0.0, 2.0) = 0.25;
uniform float stone_relief : hint_range(0.0, 2.0) = 0.8;
uniform float crack_relief : hint_range(0.0, 2.0) = 0.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.95;
uniform float specular_base : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The tone at t (0 dark, 0.5 mid, 1 light) between three colours, without a branch.
vec3 three_tone(vec3 dark, vec3 mid, vec3 light, float t) {
	t = clamp(t, 0.0, 1.0);
	return mix(mix(dark, mid, t * 2.0), mix(mid, light, t * 2.0 - 1.0), step(0.5, t));
}

// The level-surface slope (x, z) that a relief map holds at uv.
vec2 slope_of(sampler2D map, vec2 uv) {
	vec3 n = texture(map, uv).rgb * 2.0 - 1.0;
	return n.xy / max(n.z, RELIEF_MIN_HEIGHT);
}

// The strength of the tyre mark at a point of the track map, 0 to 1: its coverage times what is left of
// it at its age (TyreTrackSettings.strength_at() is the same line), and nothing outside the track area.
float track_mark(vec2 uv) {
	vec4 texel = texture(tyre_track_map, uv);
	float age = tyre_track_clock.x - texel.g / max(texel.r, TRACK_MIN_COVERAGE);
	float left = 1.0 - clamp((age - tyre_track_clock.y) / max(tyre_track_clock.z, TRACK_MIN_SECONDS), 0.0, 1.0);
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texel.r * left * inside.x * inside.y;
}

// A cell texture's "outside a width" mask: 0 inside width of a border (its G), 1 past it.
float crack_line(float gap, float width) {
	return 1.0 - smoothstep(width * 0.5, width, gap * CELL_DISTANCE_SCALE);
}

void fragment() {
	vec2 p = world_position.xz;
	vec3 macro = texture(soft_noise, p / macro_size).rgb;
	vec3 mottle = texture(soft_noise, p / mottle_size + MOTTLE_OFFSET).rgb;
	// The streak sample runs along the wind: rotate the position into (along, across).
	vec2 wind = vec2(cos(streak_angle), sin(streak_angle));
	vec2 along = vec2(dot(p, wind), dot(p, vec2(-wind.y, wind.x)));
	float streak = texture(soft_noise, along / vec2(streak_size, streak_size / STREAK_ASPECT)).g;
	float grain = texture(soft_noise, p / grain_size).b;

	float t = 0.5 + (macro.r - 0.5) * macro_amount * 2.0 + (mottle.g - 0.5) * mottle_amount * 2.0;
	vec3 colour = three_tone(tone_dark.rgb, tone_mid.rgb, tone_light.rgb, t);
	// Distance in metres to the mesh's nearest edge, wobbled by the mottle, then the blend.
	vec2 from_edge = min(UV, 1.0 - UV) * mesh_size;
	float edge = min(from_edge.x, from_edge.y) + (mottle.r - 0.5) * edge_width * EDGE_WOBBLE;
	float toward_edge = (1.0 - smoothstep(0.0, edge_width, edge)) * step(0.001, edge_width);
	vec3 edge_colour = three_tone(edge_tone_dark.rgb, edge_tone_mid.rgb, edge_tone_light.rgb, t);
	colour = mix(colour, edge_colour, toward_edge);
	colour *= 1.0 + (streak - 0.5) * streak_amount * 2.0;
	colour *= 1.0 + (grain - 0.5) * grain_amount * 2.0;

	vec3 plates = texture(cell_noise, p / crack_size).rgb;
	colour *= 1.0 + (plates.b - 0.5) * plate_amount * 2.0;
	vec3 fine = texture(cell_noise, p / fine_crack_size + FINE_CRACK_OFFSET).rgb;
	float cracks = max(crack_line(plates.g, crack_width) * crack_amount,
			crack_line(fine.g, fine_crack_width) * fine_crack_amount);
	colour = mix(colour, crack_colour.rgb, cracks);

	// A stone lies at a cell point whose cell tone passes the amount; its radius shrinks outside
	// the mottle's patches.
	vec2 stone_uv = p / stone_size + STONE_OFFSET;
	vec3 cell = texture(cell_noise, stone_uv).rgb;
	float gather = mix(1.0, smoothstep(GATHER_LOW, GATHER_HIGH, mottle.r), stone_patchiness);
	// A second random value from the cell's tone varies the stones' size.
	float size_pick = fract(cell.b * STONE_SIZE_HASH);
	float radius = stone_radius * gather * mix(STONE_SIZE_LOW, STONE_SIZE_HIGH, size_pick);
	float stone = 1.0 - smoothstep(radius * STONE_EDGE, radius, cell.r * CELL_DISTANCE_SCALE);
	stone *= step(1.0 - stone_amount, cell.b) * step(0.001, radius);
	colour = mix(colour, stone_colour.rgb * (STONE_TONE_LOW + cell.b * STONE_TONE_SPREAD), stone);

	float level = smoothstep(LEVEL_LOW, LEVEL_HIGH, world_normal.y);
	// The tyre mark here, on level faces only; its rut's sides come from the mark one reach to either side.
	vec2 track_uv = (p - tyre_track_area.xy) / tyre_track_area.zw;
	vec2 reach = tyre_track_clock.w / vec2(textureSize(tyre_track_map, 0));
	float mark = track_mark(track_uv) * tyre_track_look.w * level;
	colour *= 1.0 - tyre_track_look.x * mark;
	ALBEDO = mix(side_colour.rgb, colour, level);
	ROUGHNESS = clamp(roughness_base - stone * STONE_SMOOTHER - tyre_track_look.z * mark, 0.0, 1.0);
	SPECULAR = specular_base;

	vec2 slope = slope_of(soft_relief, p / mottle_size + MOTTLE_OFFSET) * swell_relief;
	slope += slope_of(stone_relief_map, stone_uv) * stone_relief * stone;
	slope += slope_of(crack_relief_map, p / crack_size) * crack_relief * crack_amount;
	// The rut: the mark's rise a metre across its edge (the rise of the mark from one reach to the other, over
	// the two reaches in metres), turned into a slope of depth rut_depth; the level mix below keeps it off side faces.
	vec2 rise = vec2(track_mark(track_uv + vec2(reach.x, 0.0)) - track_mark(track_uv - vec2(reach.x, 0.0)),
			track_mark(track_uv + vec2(0.0, reach.y)) - track_mark(track_uv - vec2(0.0, reach.y)));
	slope += rise / (2.0 * reach * tyre_track_area.zw) * tyre_track_look.y * tyre_track_look.w;
	vec3 relief = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 world = normalize(mix(world_normal, relief, level));
	NORMAL = normalize((VIEW_MATRIX * vec4(world, 0.0)).xyz);
}
