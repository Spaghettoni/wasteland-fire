# Story 027: The light and the colour, and your own Unit through cover

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L (one to two days at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-16

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Teams and visual style"; "Camera and controls", for the two views; "Turrets, Flag Walls and Mines", for the line of sight)
**Requirement**: The developer's request of 2026-10-15, made in a session. Asked whether the game uses shaders and whether they could improve the visuals, they were offered six ideas and answered "create stories for each of those except number 5" (the fifth, more marks in story 026's track map such as scorch marks and mine craters, was left out). This is the first idea, as offered: "Change settings, no shader code. All three are settings in Map 01's lighting setup: switch tone mapping to AgX or Filmic, so bright areas fade gently to white instead of clipping. This costs nothing. Turn on glow for anything brighter than white only. Ideas 3 and 4 need this so fire and tracers read as light. Add a colour-grading lookup texture for a warmer, dustier wasteland mood. Godot 4.5 added an X-Ray setting to standard materials (it exists in 4.7.2). Your Unit could show as a Team-coloured outline when a Turret, wall, water tower or cliff hides it in the chase view. It must only apply to your own Unit in your own view, or it shows the enemy behind cover." No card of the author's board names it (the developer, 2026-10-15). The developer's answers of the same day (decided 2026-10-15): one story per idea, so this one holds the light, the colour and the silhouette; and only the Player's own Unit shows through cover, in that Player's view, because the Turrets' line of sight and the Bushes card (`design/source/wasteland-fire-board-2026-10-07.en.md`) assume that the other Player's Unit stays hidden behind cover.

Today Map 01's Environment sets no tone mapper, so it is Linear, the engine's default, with no glow and no colour grade (probed on the installed 4.7.2, 2026-10-15: a new Environment reads `tonemap_mode` 0, `glow_enabled` false, `adjustment_enabled` false), and the salt flat reads close to white in the retained frames (`production/qa/evidence/story-025-gyrocopter-rotor/06-flying-at-full-speed-chase-view-both-views.png`). In the chase view a 3 m Turret hides a Unit that drives out right behind it until the Unit is 5.33 m past its axis (`design/rules.md`, "Turrets, Flag Walls and Mines", Height and look); from above, the water tower's tank hid the Flag and the Unit that came for it, which story 010 solved by not drawing the tank in that view.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the developer's request and answers of 2026-10-15, scoped to this story:*

- [ ] AC-1: Map 01 is drawn through a tone mapper other than Linear (AgX to start; the build records Linear, AgX, Filmic and ACES at the same moments for the author), with its exposure and white as data in `map_01.tscn`'s Environment. The salt flat in full sun keeps its cracks and stones readable instead of clipping to flat white: on the same frames before and after, the share of the salt flat's pixels with a channel at 255 in a fixed crop is measured and recorded, and it falls. The Team colours still read as their Teams on a Unit in sun and in shade (their hue measured before and after, recorded).
- [ ] AC-2: Glow is on for what is brighter than white only. Its HDR threshold (data) sits above the brightest lit surface of the Map, measured first, so the salt flat, the sand and the Bases in full sun never bloom, while an emissive probe brighter than the threshold (in the showcase only) does. Nothing that ships today is brighter than white (the Units' lamps glow at an emission of 0.4: `mesh_unit_model.gd:45`), so until stories 029 and 030 bring fire and tracers that are, the game changes by the tone mapper and the grade only.
- [ ] AC-3: A colour grade (the Environment's adjustments and a colour-correction lookup texture written by a script of the repository, no downloaded file) makes the scene warmer and dustier. The Team colours stay apart (Orange and Teal measured in frames as in AC-1), and the HUD is not graded: the HUD's band is the same pixels in the frames before and after.
- [ ] AC-4: While cover hides any part of a Player's own Unit in that Player's view (a Turret, a Wall Panel or Flag Wall, a corner tower, a water tower's legs or tank, the Fuel building, an ammunition building, the cover, a cliff), the hidden part is drawn over it as a flat, see-through silhouette in the Unit's Team colour (its strength is data), in both of that Player's views, from above and in the chase view. The parts in sight look as they do today, and a Unit never shows its own hidden parts over itself. The silhouette is drawn in its own Player's view only: the other Player's view never shows it, in either camera, and the other Player's Unit is never drawn through anything (decided 2026-10-15). A Unit out of play (destroyed, benched, its Player choosing) has none, and the rotor's smear, the smoke and the explosion get none.
- [ ] AC-5: Every value is data: the tone mapper with its exposure and white; the glow's threshold, intensity, strength, levels and blend; the grade's adjustments and the lookup texture's script parameters; the silhouette's strength; and the render layer of each Player's silhouettes. No number in code but 0 and 1.
- [ ] AC-6: Both views keep the project budget, measured windowed at 1280 x 720 the `map_fps` way with both Units driving behind cover: the lowest one-second rate at least 60 fps, a frame at most 16.6 ms and at most 1,000 draw calls for both views together. The frame time with and without the glow and the silhouettes, and the draw calls the silhouettes add, are recorded as observations beside TD-016 and TD-017.
- [ ] AC-7: The older evidence scenarios keep their outputs byte for byte against the capture taken at the start of the story: every scenario that does not declare the new opt-in runs with no silhouettes and with today's camera masks.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are the working tree of 2026-10-16 (`main` at 14eec71 plus story 025's uncommitted build): re-find them as stories 025 and 026 leave them.*

- **What the tree gives.** Map 01's Environment (`src/gameplay/maps/map_01/map_01.tscn:31-48`): the sky as the background (`ProceduralSkyMaterial_desert`, `:21-29`), ambient light from the sky (`ambient_light_source` 3, Sky, with `ambient_light_sky_contribution` 0.6 and energy 0.9), SSAO, depth fog from 60 to 260 m, and no `tonemap_mode`, glow or adjustments. The Sun (`:59-64`): energy 1.3, a warm colour, shadows to 100 m. Both SubViewports draw with MSAA 4x (`msaa_3d = 2`: `src/gameplay/split_screen/split_screen.tscn:196`, `:250`) and share one World3D (`split_screen.gd:50-52`), so one Environment serves both views. The main scene's Map is Map 01 (`split_screen.tscn:63`); the greybox field keeps its own Environment (`src/gameplay/maps/greybox_field.tscn:44`) and is not changed, and neither is the untracked Svätý Jur experiment.
- **The engine on this pin** (probed on the installed 4.7.2, 2026-10-15). `Environment.tonemap_mode`: Linear, Reinhard, Filmic, ACES, AgX, with `tonemap_exposure` and `tonemap_white`, and for AgX `tonemap_agx_white` and `tonemap_agx_contrast`. Glow: `glow_enabled`, `glow_levels/1` to `/7`, `glow_intensity`, `glow_strength`, `glow_bloom`, `glow_blend_mode` (Additive, Screen, Soft Light, Replace, Mix), `glow_hdr_threshold`, `glow_hdr_scale`, `glow_hdr_luminance_cap`; since 4.6 glow is processed before tone mapping (`docs/engine-reference/godot/breaking-changes.md:62`). Adjustments: `adjustment_enabled`, `adjustment_brightness`, `adjustment_contrast`, `adjustment_saturation` and `adjustment_color_correction` (a Texture2D or a Texture3D). Materials: `BaseMaterial3D.stencil_mode` (Disabled, Outline, X-Ray, Custom), `stencil_flags` (Read, Write, Write Depth Fail), `stencil_compare` (Always, Less, Equal, Less Or Equal, Greater, Not Equal, Greater Or Equal), `stencil_reference` (0 to 255), `stencil_color`, `stencil_outline_thickness`; `depth_test` (Default, Inverted), `no_depth_test`, `render_priority`, `next_pass`.
- **Measure first** (windowed, Movie Maker, the same moments before and after). The brightest lit value on the Map, with the tone mapper at Linear and the exposure lowered until nothing clips, so that the glow's threshold sits above it (the salt flat's lightest tone is 0.82, `materials/salt_flat.tres`, under a sun of 1.3 and an ambient of 0.9). The salt flat crop's clipped share. The Team colours' hue under each tone mapper (AgX desaturates bright, saturated colours: measure Orange `(0.9, 0.45, 0.14)` and Teal `(0.18, 0.6, 0.58)` in sun and in shade). Record Linear, AgX, Filmic and ACES side by side for question 1.
- **The grade.** A lookup texture written by a script under `tools/blender/` (the textures are generated in code: `design/game-brief.md`, Out of scope; `build_ground_textures.py` is the pattern, run by Blender's Python for numpy): either a 3D lookup written as a strip of slices and imported as a Texture3D, or a 1D gradient. Measure which of the two the 4.7.2 import and `adjustment_color_correction` take, and how each looks. Keep it mild: warmer highlights, slightly cooler shadows, a little dust, the Team colours apart. The HUD lives in each SubViewport over the 3D picture (`split_screen.tscn:209`, `:263`): measure that the Environment's adjustments leave it alone.
- **The silhouette** (AC-4). The X-Ray preset draws a material's hidden parts in `stencil_color`, but it belongs to the material, which both views draw, and the Accent's material is the Unit's `team_material`, which the Bases, their towers, markings and water towers and the Flags share (`design/rules.md`, "Teams and visual style"; `Unit._paint_team_colour()`, `src/gameplay/units/unit.gd:888-895`). A way to try first, in a scratch scene with two cameras on one World3D, before any change: each of the Unit's drawn meshes (`MeshUnitModel._build_meshes()`, `src/gameplay/units/models/mesh_unit_model.gd:73-90`, and the turning parts of `_build_rotors()`, `:102-121`) writes a stencil value where it is seen, through materials of its own (a copy of its Team material per Unit, so that a Base of the same Team never writes the value); and a copy of each mesh, sharing the Mesh resource, beside it (a turning part's copy under its pivot, so that it turns with it), on a render layer that only its Player's camera draws, draws the Team colour with the depth test off wherever that value is not set. Measure that the copy reads the stencil the Unit's own pass wrote in the same viewport, the draw order (`render_priority`) and MSAA 4x. The fallback is `depth_test` Inverted on the copy, which also draws where the Unit's own front parts hide its back parts: measure that overlap. The build chooses between them and records why.
- **Per-Player layers.** Two named render layers in `project.godot`'s `[layer_names]` (layer 2 is `tower_top`; say `3d_render/layer_3="silhouette_p1"` and `3d_render/layer_4="silhouette_p2"`). A camera's cull mask today is every layer but its settings' `hidden_layers` (`src/gameplay/camera/chase_camera.gd:107-109`), and the settings resources are shared by both Players and never written at runtime (`:57-59`), so each camera gets the layer it never draws, the other Player's, from data of its own: an export on ChaseCamera set on `Player1Camera` and `Player2Camera` in `split_screen.tscn` (`:198`, `:252`), or handed over by SplitScreen beside `_hand_supply_zones()` (`split_screen.gd:325`). The copies take their Player's layer when the Unit is given its Player (`SplitScreen._assign_players()`, `:295`), with no type check and no search of the tree.
- **The older outputs** (AC-7). `cull_mask` is read by `tools/evidence/split_screen/camera_views.gd`, `ammo_buildings_look.gd`, `badly_damaged_smoke.gd`, `crash_kit.gd`, `fuel_building_look.gd` and `mines_arm.gd`, and `drawn_box()` (`heights_kit.gd:169`) merges every visible GeometryInstance3D under a model, so a copy changes the printed boxes. The runner (`tools/evidence/split_screen_harness.gd`) therefore gets a new opt-in, `const SEE_THROUGH: bool = true`; for every other scenario no copy is made and both cameras keep today's masks (the `_apply_rotors_off()` way: `:1351`). No scenario reads the Environment (a grep of `tools/evidence/` for Environment, tonemap, glow, fog_ and sky finds none): measure it by running every older scenario after the Environment change alone and diffing. The baseline is the retained outputs of the last closed story, captured twice before the first edit; plan an exact rewrite in `measurements/normalizers.json` for each printed `.gd:` line this story moves.
- **The evidence scenarios.** `see_through` (headless, run twice byte-identical, declaring `SEE_THROUGH` and the opt-ins its pieces need) checks: one copy per drawn mesh of each Unit, sharing its Mesh, on its Player's layer, in its Team's colour, with no shadow and no collider; a turning part's copy under its pivot; each camera draws its own Player's layer and never the other's, in both views and after a view switch; no copy drawn for a Unit out of play, and the copies right after a respawn, a Swap and a change of type; the Environment's values read back from `map_01.tscn`; the settings refusing a strength outside 0 to 1 and one layer for both Players; and a lint of the new files (no number but 0 and 1, the `mines_lint` way: `tools/evidence/split_screen/mines.gd:170`). `light_showcase` (windowed `--write-movie`, the `explosions_showcase` pattern, waiting for 120 fps): the same moments under Linear, AgX, Filmic and ACES (the salt flat in full sun from above, a Base in shade, both Teams' Units side by side in sun and in shade, the HUD); the glow on a probe with nothing else blooming; the grade on and off; then each Player's Unit behind a Turret in the chase view, behind a water tower's legs and behind a cliff, a Gyrocopter under a tank in the chase view, each with the other Player's view at the same moment showing nothing through. `light_fps` (windowed A/B, AC-6).
- **Seeded defects** (story 011's script as the template: one exact replacement each, one worker per scratch copy). At least: both cameras drawing both layers (the other view shows the silhouette); the copy reading no stencil (drawn over the visible Unit: windowed, record the frame); a copy casting a shadow; a copy left visible after a destruction; a copy on the other Player's layer after a Swap; the stencil written by the shared Team material (a Base hides its own Unit's silhouette); the tone mapper back to Linear (the data check); the glow's threshold under the measured brightest value (the salt flat blooms: windowed); a colour written in code (the lint); the runner leaving the copies on (the regression fails).
- **Docs in the same change** (`design/rules.md`, Process rules): in "Teams and visual style", the tone mapper, the glow and the grade as built, and the silhouette; `CONTEXT.md`'s "Silhouette" as built; README's How it plays; a Story 027 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close. A new `class_name` reaches the class cache only through `godot --headless --path . --import`.
- Process (`design/rules.md`, Process rules): after the change, say how to test it: the main scene; drive each Player's Unit out from behind a Turret and a water tower in the chase view (Q and / switch the views) while watching the other Player's half; look at the salt flat in full sun from above.

---

## Out of Scope

- The other Player's Unit through cover, in any view (decided 2026-10-15).
- The Flags, the Mines and every other piece through cover (question 5).
- An outline around every Unit (the Outline preset): a change of style nobody asked for.
- The light of the greybox field and of the Svätý Jur experiment; a different tone mapper per view.
- Volumetric fog, screen-space reflections, SDFGI, depth of field.
- The water, the fire and smoke, the hits and shots, and the air: stories 028 to 031.

**Questions for the author** (built as read; asked at `/story-done`)
1. Map 01 now goes through the AgX tone mapper instead of none (Linear), so the bright salt flat keeps its cracks. Keep AgX, or Filmic, ACES, or back to Linear? The frames show all four at the same moments.
2. The colour grade makes the scene warmer and dustier. Keep, stronger, weaker or none?
3. Glow only touches what is brighter than white: nothing today, the fire and the tracers of stories 029 and 030 later. The Units' lamps stay as they are by day. Keep, or let the lamps glow a little?
4. Your own Unit shows through cover as a see-through silhouette in its Team colour, in your view only, from above and in the chase view. Keep, or only in the chase view, or an outline instead of a filled silhouette?
5. Should the Flags (your own at home, and the one your Motorbike carries) show through cover too? New work.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots and the lead's sign-off; record the evidence in `production/qa/evidence/story-027-light-colour-and-silhouette-evidence.md`: `see_through` run headless twice byte-identical; the windowed `light_showcase` and `light_fps` (AC-6's bar; the frame time and the draw calls with and without as observations); the facts measured first (the brightest lit value, the clipped share, the Team hues); the regression against the capture taken at the start of the story; the seeded defects.
- Retain frames in `production/qa/evidence/story-027-light-colour-and-silhouette/`: 00 the launch; the four tone mappers at the same moments; the glow probe; the grade on and off; each Player's Unit behind a Turret, a water tower's legs and a cliff in the chase view and a Gyrocopter under a tank, each with the other Player's view at the same moment; a silhouette in the view from above.
- The human checks at `/story-done`: the look in play (both views, both cameras, both Teams); the silhouette when your Unit drives behind cover, and nothing in the other Player's view; the five questions.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (it starts from the tree stories 025 and 026 leave). Build it after story 026 and before stories 029 and 030, whose fire and tracers need its glow; never beside another story: every one of them edits the runner and re-baselines the same outputs.
- Unlocks: Stories 029 and 030 (the glow); stories 028 and 031 are judged under its tone mapper and grade.
