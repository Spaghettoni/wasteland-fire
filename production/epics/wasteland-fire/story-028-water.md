# Story 028: Water that moves and shines

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M to L (one to two days at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-16

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Teams and visual style"); `CONTEXT.md` (Ford)
**Requirement**: The developer's request of 2026-10-15, made in a session. Asked whether the game uses shaders and whether they could improve the visuals, they were offered six ideas and answered "create stories for each of those except number 5" (the fifth, more marks in story 026's track map, was left out). This is the second idea, as offered: "Water shader, the biggest visible gap: moving ripples made from the existing noise textures. Lower roughness so the low sun glints, and more sky reflected at shallow angles. Foam along the shore. The fords and channels are flat rectangles, so the trick the ground shader already uses to blend toward a mesh's edges works here cheaply. The sea would need a shore-distance texture baked from the island's outline." No card of the author's board names it (the developer, 2026-10-15). The developer's answers of the same day (decided 2026-10-15): one story per idea.

Today the sea, the two channels and the two fords are flat planes in StandardMaterial3D with a roughness of 1.0 and a still noise texture: nothing moves, the low sun never glints on them, and a ford meets the sand along a hard straight line (`production/qa/evidence/map-art-2026-10-10/map-art-06-fords-chase-view.png`).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the developer's request and answers of 2026-10-15, scoped to this story:*

- [ ] AC-1: The sea, the two channels and the two fords are drawn by one new water shader (`src/gameplay/maps/spatial_env_water.gdshader`), each kind with its own material, and nothing else about them changes: the meshes, their places and heights, the colliders and the Fords' areas stay as they are, so the Map's layout, the fords' slowdown and every check of them stay.
- [ ] AC-2: Moving: ripples drift on all the water, from two samples of a seamless normal texture written by a script, moving in different directions at different speeds (data), slowly on the sea and the channels and a little faster in the fords. The movement shows in consecutive frames and never strobes. The fords keep today's look of shallow, light water and the sea and the channels of deep, dark water (today's colours to start).
- [ ] AC-3: Shine: under the low sun the water shows a moving glint of the sun in the chase view, and it reflects more of the sky at grazing angles than looking straight down (the view from above), while the ground beside it does not shine. Measured on frames of the same moments before and after.
- [ ] AC-4: Shore: a light foam or wet band follows the edge where water meets land: along the fords' and the channels' banks (which edges of a material are a shore is data), never where a ford meets its channel or where a channel runs into the sea; and along the Island's shore on the sea, from a shore-distance texture written by a script from the Island's outline (`map_01_terrain.tscn:112`). The band moves a little (data) and is drawn on the water only, never on the ground.
- [ ] AC-5: Every value is data: the materials' uniforms (the colours, the ripples' sizes, speeds and directions, the roughness, the glint, the foam's width and strength, the shore edges and the mesh sizes) and the textures' settings in their script. The shader holds named constants and 0 and 1, and no other number (the shader rules: no magic numbers).
- [ ] AC-6: The water stays opaque: no screen or depth texture is read and no transparent pass is added. Both views keep the project budget, measured windowed at 1280 x 720 the `map_fps` way with both Players crossing a ford (the lowest one-second rate at least 60 fps, a frame at most 16.6 ms, at most 1,000 draw calls for both views together). The frame time with and without the water shader is recorded as an observation beside TD-016 and TD-017, and the shader's texture reads are named in its Budget line.
- [ ] AC-7: The older evidence scenarios keep their outputs byte for byte against the capture taken at the start of the story.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are the working tree of 2026-10-16 (`main` at 14eec71 plus story 025's uncommitted build): re-find them as stories 025 to 027 leave them.*

- **What the tree gives.** `src/gameplay/maps/map_01/map_01_water.tscn`: the Sea, a 1000 x 1000 m PlaneMesh at y -0.12 in `materials/sea.tres` (`:6-8`, `:19-22`), and ChannelWest and ChannelEast, StaticBody3D at (-40, 0, 34) and (40, 0, 34) whose Surface is a 12 x 28 m PlaneMesh at y 0.02 in `materials/channel.tres` (`:10-15`, `:24-50`). `src/gameplay/maps/ford.tscn`: a Ford Area3D whose Water is a 12 x 40 m PlaneMesh at y 0.02 in `materials/ford.tres` (`:10-12`, `:24-27`), placed at x -40 and 40 (`map_01.tscn:81-85`). So each line of water runs along z: a ford from z -20 to 20 and its channel from 20 to 48, past the Island's edge at 46.1, into the sea. The three materials are StandardMaterial3D with a roughness of 1.0 and a world-triplanar NoiseTexture2D (`textures/sea.tres`: 512 px, seamless, domain-warped, a ramp of four blues; `textures/ford.tres`; the channel takes the sea's). The Island is a CSGPolygon3D, x -147 to 147 m and z -46.1 to 46.1 m, its top the sand at about y 0 (`map_01_terrain.tscn:109-114`); its side faces, the shore edge, take the ground shader's `side_colour`.
- **The shader.** Opaque and lit, metallic 0, a low roughness (data) and a fresnel term, so the sun's highlight and the sky's reflection come from the lit pipeline (the Environment's reflected light is the sky: measure whether that alone is enough at grazing angles). The ripples are NORMAL from two samples of a seamless normal texture moving in two directions (written by a script under `tools/blender/` beside `build_ground_textures.py`, which may already serve: `ground_soft_normal.png`; measure). Sample in world space from `world_position.xz`, as the ground shader does (`src/gameplay/maps/spatial_env_ground.gdshader:130-134`, `:156`), so the ford and its channel join with no seam and nothing tiles at a size the cameras see. The albedo keeps today's look: a ramp of the existing noise, or the same colours as uniforms.
- **Time.** The ripples move by the shader's TIME, which keeps running under the Round-over screen (the water is ambience; question 1). Measure that a windowed Movie Maker recording at a fixed frame rate gives the same frames twice, as the showcases need. If the author wants the water to stop with the Round, a global time uniform set by a node that pauses with the Round is the way (story 026 sets its own `time now` the same way).
- **The banks** (the fords and the channels). The ground shader's edge trick (`spatial_env_ground.gdshader:168-170`: the distance to the mesh's nearest edge, `min(UV, 1.0 - UV) * mesh_size`) with a per-material mask of the four edges that are a shore and the mesh's size in metres (data, as the salt flat's `mesh_size`). The fords and the channels are banks along their long sides; a ford's end that meets its channel, and a channel's end that meets the ford or runs into the sea, are not. Measure the PlaneMesh's UV orientation first (u along x, v along z), and that the band ends cleanly at a corner.
- **The sea's shore.** A shore-distance texture: the distance to the Island's outline over the sea's panel near the Island (say one pixel per half metre, as far out as the widest band), written by a script from the polygon at `map_01_terrain.tscn:112` (read from the scene, or copied into the script as data with a check that both agree), sampled at world xz. The band lies where the distance is under the foam's width (data). Check that the sea's band and a channel's banks meet without a gap or a double band where the channel runs past the Island's edge (z 46.1 to 48).
- **Units in the water.** A ground Unit in a ford drives on the ground under the 2 cm plane at y 0.02, as today: unchanged. No Unit can enter the sea or a channel (the cliffs_water layer).
- **The older outputs** (AC-7). `map_layout` reads the sea's footprint (`tools/evidence/split_screen/map_layout.gd:69-73`, `:224-226`), which this story does not change, and no other scenario reads the water's materials (a grep of `tools/evidence/` for `sea.tres`, `ford.tres` and `channel.tres` finds only `map_layout`'s paths). Measure first: run every older scenario with the new materials and diff. If an output changes, add an opt-in, `const WATER: bool = true`, and give the other scenarios today's three materials (byte copies under `tools/evidence/frozen/`). The baseline is the retained outputs of the last closed story, captured twice before the first edit.
- **The evidence scenarios.** `water` (headless, run twice byte-identical) checks: the five surfaces drawn by the water shader in their own materials; the meshes, their places and sizes against the start's capture; the data read back (each material's uniforms against its `.tres`, the shore edges per material: a ford's channel end and a channel's two ends are not banks); the shore texture's size and the distances at sample points (0 on the Island's edge, the foam's width a few metres out); and a lint of the new files (the `mines_lint` way: `tools/evidence/split_screen/mines.gd:170`). `water_showcase` (windowed `--write-movie`, waiting for 120 fps): each ford from the chase view and from above, with both Players crossing; a channel's bank; the sea's shore by a Base; four consecutive frames of a ford (the ripples move, the glint moves); every moment before and after. `water_fps` (windowed A/B, AC-6).
- **Seeded defects** (story 011's script as the template). At least: the ripples frozen (no time term: windowed, the consecutive frames are equal); a bank at all four edges (a line across the water where a ford meets its channel); the band on the ground's side of the edge; a roughness of 1 (no glint: windowed); the shore texture flipped (the sea's band out at sea); a ford in the sea's colours; a number in the shader (the lint); a transparent water material (the AC-6 check).
- **Docs in the same change** (`design/rules.md`, Process rules): in "Teams and visual style", the water as built (the shader, the shore, the colours); the shader's header (Purpose, Target, Budget); README's How it plays; a Story 028 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close; `tools/blender/readme.md` for any new texture script.
- Process (`design/rules.md`, Process rules): after the change, say how to test it: the main scene; drive across a ford in the chase view and from above; look along a channel's bank and out over the sea by a Base.

---

## Out of Scope

- Wakes or splashes behind a Unit in a ford (the fifth idea's family, left out on 2026-10-15).
- See-through water with a visible bed (a depth or screen read and a transparent pass in both views: question 4).
- Waves that move the mesh, reflections of the Units or the Map (screen-space reflections), caustics, anything under the water.
- The fords' slowdown and every other rule; the Map's layout.
- The water of the Svätý Jur experiment.
- The light and the colour (story 027), the fire and smoke (029), the hits and shots (030), the air (031).

**Questions for the author** (built as read; asked at `/story-done`)
1. The water keeps moving under the Round-over screen, while the rest of the world stops. Keep, or stop it too?
2. The colours are today's: dark blue sea and channels, light cyan fords. Keep, or retune?
3. The foam along the banks and the shore is a thin light band. Keep, wider, narrower or none?
4. The fords stay opaque water, shallow-looking by their colour. Should you see the ford's bed through the water? New work, with a cost in both views.
5. The sun's glint and the sky's reflection: keep, stronger or weaker?

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots and the lead's sign-off; record the evidence in `production/qa/evidence/story-028-water-evidence.md`: `water` run headless twice byte-identical; the windowed `water_showcase` and `water_fps` (AC-6's bar, the frame time with and without as an observation); the facts measured first (the UV orientation, the corners, the recording reproduced twice); the regression against the capture taken at the start of the story; the seeded defects.
- Retain frames in `production/qa/evidence/story-028-water/`: 00 the launch; each ford from the chase view and from above with a Unit crossing; a channel's bank; the sea's shore by a Base; four consecutive frames of a ford; the same moments before and after.
- The human checks at `/story-done`: the water in play (both views, both cameras, a ford crossed by each Player); the five questions.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 027 (the water is judged under its tone mapper and grade). Never beside another story: every one of them edits the runner or re-baselines the same outputs.
- Unlocks: None.
