// The smear of a turning part (the Gyrocopter's main rotor and pusher propeller): a soft
// see-through fan that each blade trails behind it over a share of the gap between two blades,
// drawn on a flat disc in the plane the blades turn in. It is a picture only.
//
// Author: Tomas Kunzo with Claude Code, 2026-10-15 (the developer's "I want some sort of animation
// for the gyrocopter spinning blades. Something smooth. Blurred is fine, but it needs to be
// recognizable enough."; production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-2, AC-3
// and AC-6).
//
// Purpose: at 60 physics ticks a second a blade that turns fast enough to look fast strobes: it
// jumps by a whole step between frames. The blades stay solid and countable; this fan hides the
// step by trailing each blade, strongest at the blade and fading to nothing, so the blur reads as
// the blade's own motion and never as a disc that replaces the blades.
//
// Frame: the mesh is a PlaneMesh of its default size (2 x 2, facing +Y) that RotorPivot scales by
// the part's reach and turns so that +Y is the axis the part turns about and +X runs along one
// blade at rest, in the part's own pivot, so the fan turns with the blades. A positive turn about
// +Y takes +X toward -Z, so the side behind a blade is the side of the larger polar angle,
// atan(z, x).
//
// Light: the fan is lit, with no highlight, so it takes the light the blades take (the sun's, the
// shade under a water tower's tank) and is as bright as the blade it trails; drawn unshaded it
// read dull beside the blades and kept its colour in a shadow.
//
// Numbers: every one is a per-instance uniform set by RotorPivot from RotorSettings and
// RotorPart (the colours are linear), so one ShaderMaterial serves every smear of every Unit and
// none is made per Unit; the shader holds no number but 0 and 1 (the rotors scenario lints it).
// Target: desktop, Forward+ renderer (project.godot rendering_method). Instance uniforms need
// Forward+ or Mobile. No quality tiers or fallback.
// Budget: one fragment pass, no texture, no loop; two smears for each Gyrocopter in each view.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// The colour of the fan from the hub out to tip_start (linear RGB), and its alpha at the blade.
instance uniform vec4 body_colour;
// The colour of the fan from tip_start out to the edge (linear RGB), and its alpha at the blade.
instance uniform vec4 tip_colour;
// How many blades the part has; the fan repeats once for each.
instance uniform float blades;
// How far behind a blade its fan reaches, radians: above 0 and never more than one gap between two
// blades (RotorPivot makes no smear for an arc of 0).
instance uniform float arc;
// The share of the reach (0 at the hub, 1 at the edge) where the tip colour begins.
instance uniform float tip_start;
// The share of the reach over which the fan fades in from the hub, so the hub is not tinted: above
// 0 (RotorSettings refuses a part without it).
instance uniform float inner_share;

// The position on the disc, from -1 to 1 on each side, the same at the vertex and the fragment.
varying vec2 disc;


void vertex() {
	disc = VERTEX.xz;
}


void fragment() {
	float reach = length(disc);
	float gap = TAU / max(blades, 1.0);
	float behind = mod(atan(disc.y, disc.x), gap);
	float trail = 1.0 - smoothstep(0.0, arc, behind);
	float within = 1.0 - step(1.0, reach);
	float grown = smoothstep(0.0, inner_share, reach);
	vec4 colour = mix(body_colour, tip_colour, step(tip_start, reach));
	ALBEDO = colour.rgb;
	ALPHA = colour.a * trail * within * grown;
	SPECULAR = 0.0;
}
