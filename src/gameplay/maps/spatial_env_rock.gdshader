// Map 01's rocks: the meshes built in Blender over the cliff colliders
// (tools/blender/build_rocks.py writes assets/art/map_01/rocks/map_01_rocks.glb), drawn with
// src/gameplay/maps/map_01/materials/rock_face.tres.
//
// Author: Tomas Kunzo with Claude Code, 2026-10-10 (the developer's "models for the rocks";
// production/qa/evidence/map-art-2026-10-10-evidence.md).
// Purpose: the meshes carry the large forms and the colours (one colour per face, the stone's
// bands, ambient occlusion baked in, all as sRGB vertex colours); this adds what is smaller than a
// face, from the ground's seamless noise textures sampled in world space: a grain
// on every face (three planar samples blended by the face's normal), streaks along the strata on
// the walls, and joint lines across the tops (the borders of a cell pattern).
// Target: desktop, Forward+ renderer (project.godot rendering_method); macOS Metal and the Windows
// build. No quality tiers or fallback yet.
// Budget: one fragment pass, five texture reads (mipmapped, anisotropic), no loops, no branches,
// no keywords or variants.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// The cell texture stores distances divided by this (ground_cells.png fits 0..0.9 cell units).
const float CELL_DISTANCE_SCALE = 0.9;
// A stratum streak is this many times longer than it is tall.
const float STRATA_ASPECT = 25.0;

// R, G: two smooth fractal noises; B: a fine one (ground_soft.png).
uniform sampler2D soft_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// R: distance to the nearest cell point; G: gap to the second nearest; B: a tone per cell
// (ground_cells.png).
uniform sampler2D cell_noise : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms detail;
// Metres per tile of the grain, of the strata streaks (along the wall) and of the joints' cell
// pattern (24 cells a tile).
uniform float grain_size : hint_range(0.5, 50.0) = 6.0;
uniform float strata_size : hint_range(1.0, 200.0) = 40.0;
uniform float joint_size : hint_range(1.0, 200.0) = 30.0;
// How much each shows; the joints' width in cell units and colour.
uniform float grain_amount : hint_range(0.0, 0.5) = 0.12;
uniform float strata_amount : hint_range(0.0, 0.5) = 0.12;
uniform float joint_amount : hint_range(0.0, 1.0) = 0.45;
uniform float joint_width : hint_range(0.0, 0.3) = 0.05;
uniform vec4 joint_colour : source_color = vec4(0.27, 0.16, 0.1, 1.0);
group_uniforms surface;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.95;
uniform float specular_base : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The vertex colours are sRGB numbers; lighting works in linear values.
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec3 colour = srgb_to_linear(COLOR.rgb);
	// Triplanar weights from the face's normal.
	vec3 weights = abs(world_normal);
	weights /= weights.x + weights.y + weights.z;
	vec3 p = world_position;
	float grain = texture(soft_noise, p.zy / grain_size).b * weights.x
			+ texture(soft_noise, p.xz / grain_size).b * weights.y
			+ texture(soft_noise, p.xy / grain_size).b * weights.z;
	colour *= 1.0 + (grain - 0.5) * grain_amount * 2.0;
	// Along a wall: z for a wall facing X, x for one facing Z, mixed for walls in between.
	float along = p.z * weights.x + p.x * weights.z;
	float strata = texture(soft_noise, vec2(along / strata_size,
			p.y * STRATA_ASPECT / strata_size)).g;
	colour *= 1.0 + (strata - 0.5) * strata_amount * 2.0 * (1.0 - weights.y);
	float gap = texture(cell_noise, p.xz / joint_size).g * CELL_DISTANCE_SCALE;
	float joint = (1.0 - smoothstep(joint_width * 0.5, joint_width, gap)) * joint_amount * weights.y;
	// joint_colour is a source_color uniform: Godot hands it over in linear values already.
	colour = mix(colour, joint_colour.rgb, joint);
	ALBEDO = colour;
	ROUGHNESS = roughness_base;
	SPECULAR = specular_base;
}
