// Greybox floor: a flat colour with thin grid lines, drawn from world position.
//
// Author: Tomas Kunzo with Claude Code (gameplay-programmer), Story 001.
// Purpose: production/epics/wasteland-fire/story-001-driving-toy.md AC-5 and AC-8. On a
// featureless plane there is nothing to judge speed, turning or camera smoothness against; the
// grid gives the eye that reference. A placeholder look, not art. The lines follow world
// position, so the grid stays put while the camera and the Units move over it.
// Target: desktop, Forward+ renderer (project.godot rendering_method). No quality tiers or
// fallback: a greybox placeholder that the ready-made kit art replaces.
// Budget: one fragment pass, no texture reads, no branches, no keywords or variants; one fract,
// one fwidth and one smoothstep per fragment.
shader_type spatial;

group_uniforms colours;
// Colour of the flat floor.
uniform vec3 floor_color : source_color = vec3(0.46, 0.45, 0.43);
// Colour of the grid lines.
uniform vec3 line_color : source_color = vec3(0.32, 0.31, 0.30);
group_uniforms grid;
// Metres between two grid lines.
uniform float cell_size : hint_range(0.5, 50.0, 0.1) = 5.0;
// Width of a grid line in metres.
uniform float line_width : hint_range(0.01, 1.0, 0.01) = 0.1;
group_uniforms;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres from this point to the nearest grid line, along x and along z.
	vec2 to_line = abs(fract(world_position.xz / cell_size - 0.5) - 0.5) * cell_size;
	// One pixel's footprint in metres, so the edge of a line is anti-aliased at any distance.
	vec2 pixel = fwidth(world_position.xz);
	vec2 coverage = 1.0 - smoothstep(vec2(line_width * 0.5), vec2(line_width * 0.5) + pixel, to_line);
	ALBEDO = mix(floor_color, line_color, max(coverage.x, coverage.y));
	ROUGHNESS = 1.0;
}
