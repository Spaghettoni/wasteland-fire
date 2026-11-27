// spatial_env_strata.gdshader — layered rock for cliffs and canyon walls (the art overhaul, 2026-11-27).
// The side faces take horizontal strata by world height (a column of the strata texture, its rows gently waved along
// the wall); the faces that look up take the top colour (sand), blended over the edge, so a plateau's top is sand, not
// stripes. Target: desktop, Forward+. Owner: art overhaul (story-071).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The strata, read down its height: one tile is band_height metres of wall.
uniform sampler2D strata : source_color, filter_linear_mipmap, repeat_enable;
uniform float band_height = 12.0;
uniform float wave_amount = 0.35;
uniform vec3 top_colour : source_color = vec3(0.86, 0.62, 0.4);
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float along = world_position.x + world_position.z;
	float wave = sin(along * 0.21) * wave_amount + sin(along * 0.57 + 1.3) * wave_amount * 0.5;
	vec3 side = texture(strata, vec2(along / band_height * 0.05, (world_position.y + wave) / band_height)).rgb;
	float up = smoothstep(0.55, 0.8, world_normal.y);
	ALBEDO = mix(side, top_colour, up);
	ROUGHNESS = roughness_value;
}
