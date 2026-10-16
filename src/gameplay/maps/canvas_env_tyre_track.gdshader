// The brush that writes a tyre mark into a Map's track map (src/gameplay/maps/tyre_tracks.gd): one quad
// for each stroke of each tyre, drawn by TyreTrackPainter into the SubViewport that holds the map.
//
// Author: Tomas Kunzo with Claude Code, 2026-10-16 (production/epics/wasteland-fire/story-026-tyre-tracks.md).
// Purpose: the track map is a half-float RGBA target (the SubViewport's use_hdr_2d) that is never cleared
// between strokes, so what was driven stays. This shader writes the two numbers the ground shader
// (spatial_env_ground.gdshader) reads back: R, the coverage of the mark at this texel (1 inside the tyre,
// falling to 0 across the stroke's soft rim), and G, that coverage times the Round's time in seconds at
// which the stroke was made. The time is premultiplied by the coverage so that the ground shader's
// bilinear read of a texel on the rim, G over R, still gives the stroke's own time. A later stroke
// replaces what an earlier one wrote (blend_disabled: no blending), so two tracks that cross are no
// darker than one, and a mark driven over again is as fresh as the new stroke. The colour of the vertices
// is ignored: a colour drawn into a high dynamic range 2D target is converted from sRGB to linear and
// clamped for the target's range (measured on 4.7.2), which would ruin a time of hundreds of seconds, so
// the stroke's time travels in the UV instead (UV.y), and the coverage the stroke's rim gives this
// point in UV.x (0 at the outer edge of the rim, 1 at its inner edge and in the core).
// Target: desktop, Forward+ renderer; macOS Metal and the Windows build. No quality tiers.
// Budget: one fragment pass, no texture reads, no loops, no branches, no keywords or variants.
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	float coverage = smoothstep(0.0, 1.0, UV.x);
	COLOR = vec4(coverage, coverage * UV.y, 0.0, 1.0);
}
