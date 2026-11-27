// spatial_fx_fire_sprite.gdshader — one soft, flickering sprite of the Flame Tank's stream (the art overhaul, 2026-11-27;
// Martin: "ohen z flame trucku, je stale velmi nepresvedcivy"). A camera-facing quad (it keeps its node's scale) drawn
// as a ragged ball of fire: a radial falloff torn by scrolling noise, its colour from white-yellow in the hot core
// through orange and red to dark smoke at the edge, all of it cooling with `heat` (1 at the nozzle, 0 at the end of the
// range), so a puff starts as a bright tongue and ends as a wisp of smoke. The core of a hot sprite is drawn brighter
// than 1, so the glow blooms it. `seed` turns and shifts each sprite's noise so no two look alike.
// Target: desktop, Forward+. Owner: art overhaul (story-071).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float heat : hint_range(0.0, 1.0) = 1.0;
instance uniform float seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.95;
// How much brighter than white the hottest core is drawn.
uniform float core_boost = 1.6;
// How fast the noise rolls through the sprite, per second.
uniform float flicker_speed = 2.6;
uniform vec3 smoke : source_color = vec3(0.16, 0.12, 0.1);
uniform vec3 red : source_color = vec3(0.72, 0.09, 0.02);
uniform vec3 orange : source_color = vec3(1.0, 0.38, 0.04);
uniform vec3 yellow : source_color = vec3(1.0, 0.74, 0.22);
uniform vec3 white : source_color = vec3(1.0, 0.95, 0.75);

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	mat4 facing = mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}

// The colour along the fire's ramp: 0 smoke, 0.35 red, 0.6 orange, 0.82 yellow, 1 white.
vec3 ramp(float k) {
	if (k < 0.35) return mix(smoke, red, k / 0.35);
	if (k < 0.6) return mix(red, orange, (k - 0.35) / 0.25);
	if (k < 0.82) return mix(orange, yellow, (k - 0.6) / 0.22);
	return mix(yellow, white, (k - 0.82) / 0.18);
}

void fragment() {
	float a = seed * 6.2831;
	vec2 uv = (UV - 0.5) * 2.0;
	uv = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * uv;
	float n = fbm(uv * 1.8 + vec2(seed * 13.0, -TIME * flicker_speed));
	float r = length(uv) + (n - 0.5) * 0.9;
	// The torn ball, and a clean fade before the quad's edge so no corner ever shows.
	float body = (1.0 - smoothstep(0.35, 1.0, r)) * (1.0 - smoothstep(0.75, 1.0, length(uv)));
	float core = 1.0 - smoothstep(0.0, 0.6, r);
	// Hot near the nozzle and in the core; the edge and the far end cool to red and smoke.
	float k = clamp(0.04 + heat * 0.78 + core * heat * 0.4 + (n - 0.5) * 0.3, 0.0, 1.0);
	vec3 c = ramp(k);
	ALBEDO = c * (1.0 + core * smoothstep(0.6, 1.0, heat) * core_boost);
	// Smoke is thinner than flame.
	float smoky = 1.0 - smoothstep(0.15, 0.45, k);
	ALPHA = body * opacity * mix(1.0, 0.5, smoky) * smoothstep(0.0, 0.25, heat + 0.03);
}
