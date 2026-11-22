shader_type spatial;
// The Flame Tank's flame puffs (Story 063): unshaded, from a yellow heart at heat 1 (at the nozzle)
// through orange to a dull red at heat 0 (the end of the range), fading as it cools. heat is set per
// instance by FlameShot.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

instance uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.32);
uniform vec3 warm : source_color = vec3(1.0, 0.42, 0.04);
uniform vec3 cool : source_color = vec3(0.62, 0.1, 0.02);
uniform float opacity = 0.92;

void fragment() {
	vec3 c = heat > 0.5 ? mix(warm, hot, (heat - 0.5) * 2.0) : mix(cool, warm, heat * 2.0);
	ALBEDO = c;
	ALPHA = opacity * smoothstep(0.0, 0.3, heat);
}
