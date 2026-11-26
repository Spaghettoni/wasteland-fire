shader_type spatial;
// The Flame Tank's flame puffs (Story 063): unshaded, from a yellow heart at heat 1 (at the nozzle)
// through orange to a dull red at heat 0 (the end of the range), fading as it cools. heat is set per
// instance by FlameShot.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

instance uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform vec3 hot : source_color = vec3(1.0, 0.66, 0.1);
uniform vec3 warm : source_color = vec3(0.95, 0.26, 0.02);
uniform vec3 cool : source_color = vec3(0.55, 0.06, 0.02);
uniform float opacity = 0.97;
// How much brighter than its colour the hottest part is drawn: above the glow threshold, it blooms (the art overhaul, 2026-11-26).
uniform float brightness = 1.0;

void fragment() {
	vec3 c = heat > 0.5 ? mix(warm, hot, (heat - 0.5) * 2.0) : mix(cool, warm, heat * 2.0);
	ALBEDO = c * mix(1.0, brightness, smoothstep(0.55, 1.0, heat));
	ALPHA = opacity * smoothstep(0.0, 0.3, heat);
}
