# Story 031: The air: drifting sand, heat haze, a dusty sky and the red edge of your view

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L+ (more than two days at `coarse`, likely two sessions: the developer chose one story per idea over smaller ones, 2026-10-15)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-16

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Teams and visual style"; "Camera and controls", for the views); `CONTEXT.md` (View, Tyre track)
**Requirement**: The developer's request of 2026-10-15, made in a session. Asked whether the game uses shaders and whether they could improve the visuals, they were offered six ideas and answered "create stories for each of those except number 5" (the fifth, more marks in story 026's track map, was left out). This is the sixth idea, as offered: "Atmosphere (most expensive, do last): sand drifting along the wind direction the ground shader already has. Heat haze over the salt flat. It's a full-screen effect, so split screen pays for it twice. A dusty sky. A red flash at the screen edges when you're hit." No card of the author's board names it (the developer, 2026-10-15). The developer's answers of the same day (decided 2026-10-15): one story per idea, this one holding the sand, the heat haze, the sky and the red edge of the view; and of the hit looks offered, "the view whose Unit was hit pulses red at its edges" (the flash and the charring are story 030's).

Today the ground stands still but for the tracks story 026 adds, the sky is Godot's procedural sky in Map 01's colours, and a hit shows to the Player only as the hit points in the HUD.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the developer's request and answers of 2026-10-15, scoped to this story:*

- [ ] AC-1: A faint layer of sand drifts slowly along the wind's direction that the ground shader already uses for its streaks (`streak_angle`, 0.4 rad), on the sand and the canyon road and less or not at all on the salt flat (data per material: speed, size, amount), visible in consecutive frames from both cameras. It is drawn on the ground's level faces only, never on the shore edge, the water or anything standing, and a fresh tyre track (story 026) stays readable under it.
- [ ] AC-2: Far from the camera the picture shimmers slightly, as heat haze does: a slow wobble of what lies behind (data: strength, size, speed), strongest toward the horizon and over the salt flat at the grazing angles of the chase view, nothing within a distance of the camera (data: 40 m to start), so the Units and the fight stay sharp, and faint or none in the view from above (by the view's angle: data). The HUD is never distorted.
- [ ] AC-3: Map 01's sky is drawn by a new sky shader: a warm, dusty haze toward the horizon, a soft glare around the sun in the Sun's direction (`map_01.tscn:59-64`) and a blue that deepens upward. The sky lights the ground too (the Environment takes its ambient light from it), so the change is judged on frames of the same moments before and after, and the Team colours and the salt flat read as story 027 left them (measured as in story 027's AC-1).
- [ ] AC-4: When a Player's Unit loses hit points and survives, and when it is destroyed (a Shot, a Turret, a Mine, a crash or a Self-destruct), that Player's view pulses red at its edges (data: colour, width, peak strength, the ticks it takes to fade), and only that view. It never pulses at a spawn, a Swap, a bench or a restart, it is drawn under the HUD's band and the Unit choice panel, so they stay readable, and it plays out under the Round-over screen instead of freezing there.
- [ ] AC-5: Every value is data: the ground materials' new uniforms, the haze's, the sky shader's uniforms in `map_01.tscn`, and the red edge's settings. The shaders hold named constants and 0 and 1, and the new scripts no number but 0 and 1.
- [ ] AC-6: The drift and the haze move by the clock, so they are recorded at a fixed frame rate and the same recording gives the same frames twice; the red edge counts its own ticks. The sky does not move, so its radiance is not redrawn every frame (measured).
- [ ] AC-7: Both views keep the project budget, measured windowed at 1280 x 720 the `map_fps` way with both Units in the open looking toward the horizon in the chase view (the lowest one-second rate at least 60 fps, a frame at most 16.6 ms, at most 1,000 draw calls for both views together), with the frame time of each part (drift, haze, sky, red edge) on and off recorded as observations beside TD-016 and TD-017. If the haze cannot keep the budget, it ships with its strength at zero in the data and the author is asked (question 2).
- [ ] AC-8: The older evidence scenarios keep their outputs byte for byte against the capture taken at the start of the story: every scenario that does not declare the new opt-in runs with no red edge and no haze node.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are the working tree of 2026-10-16 (`main` at 14eec71 plus story 025's uncommitted build): re-find them as stories 025 to 030 leave them; story 026 edits the ground shader first.*

- **Build order inside the story** (so that a session break leaves whole parts): the red edge (it needs nothing else), then the sky, then the drift (after story 026's tracks), then the haze, the costliest, with its budget gate last.
- **The drift.** `src/gameplay/maps/spatial_env_ground.gdshader` already turns the position into the wind's frame for its streaks (`streak_angle`, `:99`; `:160-162`) and tells level faces from the shore edge (`level`, `:195`). One more sample of `soft_noise` at the position moved along the wind by time, brightening or darkening the albedo a little where the noise is high, multiplied by `level`; each material its own speed, size and amount (`materials/sand.tres`, `road.tres`, `salt_flat.tres`). Update the Budget line (`:22`: ten reads today, plus story 026's). Time: the shader's TIME, which keeps running under the Round-over screen (ambience, as story 028's water: question 5), or story 026's global time of the Round, which stops with it: the build's call, asked.
- **The sky.** `map_01.tscn:21-29`: a ProceduralSkyMaterial (top `(0.4, 0.56, 0.76)`, horizon `(0.7, 0.78, 0.86)`, ground bottom `(0.5, 0.4, 0.28)`, ground horizon `(0.76, 0.67, 0.53)`). The Environment draws it as the background, takes its ambient light from it (`ambient_light_source` 3, Sky, with `ambient_light_sky_contribution` 0.6 and energy 0.9: `:31-37`) and lets the fog cover it by 0.3 (`:46`). A sky shader (say `src/gameplay/maps/sky_env_desert.gdshader`) gets the sun's direction from the scene's DirectionalLight3D (`LIGHT0_DIRECTION` in a sky shader) and draws the glare around it. On 4.7.2 (probed) `Sky.process_mode` is Automatic, High-Quality, High-Quality Incremental or Real-Time, and `radiance_size` is a setting: a sky that uses TIME redraws its radiance every frame in Real-Time mode, so keep the sky still and measure its cost. ProceduralSkyMaterial's own `sky_cover`, `sun_angle_max` and `sun_curve` may come close without a shader: compare them in frames and record the choice.
- **The haze** (measure both on 4.7.2 first). (a) A Compositor on each Player's camera (`Camera3D.compositor`, probed) with a CompositorEffect, a compute shader over the colour buffer that reads the depth buffer to grow the wobble with the distance: the engine reference's way for post-processing (`docs/engine-reference/godot/modules/rendering.md:46-55`), more code, written once and drawn in each view. (b) A spatial shader on a mesh over the salt flat and the far ground (say `src/gameplay/maps/spatial_env_heat_haze.gdshader`) that reads `hint_screen_texture` and `hint_depth_texture` and shifts its lookup by a slow noise, faded by the distance and by the view's angle: less code, but see-through, so it adds a copy of the screen and a transparent pass in each view and covers only where the mesh is (4.7 forbids `hint_screen_texture` only in the shader types that do not support it). Both leave the HUD alone: it is drawn after the 3D picture, in each SubViewport (`split_screen.tscn:209`, `:263`). Measure the cost of each with MSAA 4x in both views; record the choice.
- **The red edge.** A full-rect Control in each Player's SubViewport, drawn before the HUD so that the HUD's band and the panels stay on top (the order of the SubViewport's children: `split_screen.tscn:205-240`), with a canvas_item shader (say `src/ui/hud/canvas_ui_red_edge.gdshader`: the colour by the distance to the rect's edge, a strength uniform), its mouse filter set to ignore. Its script listens to its own Player's Unit as PlayerHud does (`src/ui/hud/player_hud.gd:200`, `:304`, the Unit given by a node path in `split_screen.tscn`): a `hit_points_changed` with a lower value while the Unit is alive is a survived hit, `destroyed` is a destruction (`unit.gd:236-241`), and a refill at a spawn, the zero of a bench and a restart are neither. In process mode ALWAYS, as the explosion is (`explosion.tscn:30`), so that the pulse of the hit that ends a Round fades under the Round-over screen.
- **The older outputs** (AC-8). `tools/evidence/split_screen/camera_views.gd` counts every Control in each view, so the runner (`tools/evidence/split_screen_harness.gd`) frees both red edges unless the scenario declares the new opt-in, `const ATMOSPHERE: bool = true` (the MineCount and AmmoCount way: `_apply_mine_counts_off()`, `:1430`; `_apply_ammo_counts_off()`, `:1419`). A haze node with a script in the Map would show in `map_layout`'s list of the Map's scripts (`map_layout.gd:98`), so the runner removes it too; the sky and the ground's new uniforms are read by no scenario (measure by running the older outputs). The baseline is the retained outputs of the last closed story, captured twice before the first edit.
- **The evidence scenarios.** `atmosphere` (headless, run twice byte-identical, declaring `ATMOSPHERE` and the opt-ins its pieces need) checks: each Player's red edge tick by tick after a survived hit and after a destruction, the other view's untouched; none at a spawn, a Swap, a bench and R; the red edge's place under the HUD and its process mode; the materials' and the sky's data read back; the haze's settings; the settings refusing a negative strength and a fade of zero ticks; a lint of the new files (the `mines_lint` way: `tools/evidence/split_screen/mines.gd:170`). `atmosphere_showcase` (windowed `--write-movie`, waiting for 120 fps): the drift in four consecutive frames from both cameras, over the sand with a fresh track and over the road; the haze toward the horizon in the chase view, from above, and none near a Unit; the sky before and after at the same moments, with a Base in shade and both Teams' Units; the red edge's pulse, frame by frame, in one view while the other stays clean. `atmosphere_fps` (windowed A/B, each part on and off, AC-7).
- **Seeded defects** (story 011's script as the template). At least: the drift on the shore edge (`level` left out); the drift hiding a fresh track; the haze near the camera (the Unit wobbles: windowed); the haze on the HUD; the red edge in both views; a red edge at a spawn or a Swap; a red edge that never fades; the red edge over the HUD's band; the sky animated by TIME in Real-Time mode (the fps run); a number written in code (the lint); the runner leaving the red edges on (the regression fails).
- **Docs in the same change** (`design/rules.md`, Process rules): in "Teams and visual style", the drift, the haze and the sky as built; `CONTEXT.md`'s "Red edge" as built; the shaders' headers (Purpose, Target, Budget); README's How it plays; a Story 031 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close.
- Process (`design/rules.md`, Process rules): after the change, say how to test it: the main scene; drive onto the salt flat in the chase view and look toward the horizon; switch to the view from above; let the other Player or a Turret hit your Unit and watch your half of the screen and the other half.

---

## Out of Scope

- Sand blowing through the air (gusts, particles), dust behind the wheels, the Gyrocopter's downwash.
- Clouds and their shadows, day and night, sandstorms or any weather, volumetric fog.
- A screen that greys out at low hit points, a heartbeat, sound.
- Scorch marks and craters on the ground (the fifth idea, left out on 2026-10-15).
- The flash and the charring of a hit Unit (story 030); the water (story 028).

**Questions for the author** (built as read; asked at `/story-done`)
1. The sand drifts slowly along the wind on the sand and the road, less on the salt flat. Keep, faster or slower, stronger or weaker?
2. The heat haze shimmers in the distance in the chase view, never near your Unit and hardly from above. Keep, stronger, weaker or none? It costs a pass in each view (measured).
3. The sky has a dusty haze at the horizon and a soft glare around the sun. Keep?
4. Your half of the screen pulses red at its edges when your Unit is hit, and when it is destroyed, a Self-destruct included. Keep, or not at a Self-destruct? The colour and the length?
5. The drift and the haze keep moving under the Round-over screen, like story 028's water. Keep, or stop them with the rest of the world?

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots and the lead's sign-off; record the evidence in `production/qa/evidence/story-031-atmosphere-evidence.md`: `atmosphere` run headless twice byte-identical; the windowed `atmosphere_showcase` and `atmosphere_fps` (AC-7's bar, each part's frame time as an observation); the facts measured first (the haze's two ways and their costs, the sky's radiance mode, the recording reproduced twice); the regression against the capture taken at the start of the story; the seeded defects.
- Retain frames in `production/qa/evidence/story-031-atmosphere/`: 00 the launch; four consecutive frames of the drift with a track; the haze toward the horizon and none near a Unit; the sky before and after; the red edge's pulse in one view with the other clean; the HUD band over the red edge.
- The human checks at `/story-done`: the air in play (both views, both cameras), a hit on your Unit, the other Player's half; the five questions.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 026 (both edit the ground shader; the tracks show under the drift) and story 027 (the sky and the haze are judged under its tone mapper and grade). Never beside another story: every one of them edits the runner and re-baselines the same outputs.
- Unlocks: None.
