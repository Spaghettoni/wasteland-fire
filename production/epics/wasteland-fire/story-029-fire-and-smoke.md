# Story 029: Fire and smoke drawn by shaders

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M (about a day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-16

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Teams and visual style"; "Destruction and respawn"); `CONTEXT.md` (Explosion, Badly damaged)
**Requirement**: The developer's request of 2026-10-15, made in a session. Asked whether the game uses shaders and whether they could improve the visuals, they were offered six ideas and answered "create stories for each of those except number 5" (the fifth, more marks in story 026's track map such as scorch marks under explosions, was left out). This is the third idea, as offered: "Fire and smoke. The explosion code stays; only the materials change. Fireball: a noise-roughened sphere, white-hot fading to soot over its lifetime, with soft edges. Smoke from explosions and badly damaged Units: breaks up with noise instead of fading evenly, and has a lit and a shaded side." No card of the author's board names it (the developer, 2026-10-15). The developer's answers of the same day (decided 2026-10-15): one story per idea.

Today the fireball is a flat, unlit ball whose colour goes from yellow to dark red, and it reads as a yellow disc (`production/qa/evidence/story-016-unit-explosions/02-shot-down-motorbike-the-fireball.png`); the explosion's smoke is three grey balls in a see-through material, and a badly damaged Unit's smoke is soft round billboards that fade evenly (story 017's evidence).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the developer's request and answers of 2026-10-15, scoped to this story:*

- [ ] AC-1: The fireball is drawn by a new shader on the same sphere, with story 016's timing, size and centre (0.6 s; swelling to 0.7 of the type's larger box side in its first third, then shrinking to half of that). Its outline is broken up by noise that changes over its life, so no frame shows a smooth disc; it is hottest at its heart (white to yellow) and cooler toward its edge and as it ages (orange, dark red, then soot), from ExplosionSettings' colours; its edge is soft; and at its hottest it is brighter than white, so it blooms with story 027's glow.
- [ ] AC-2: The flash keeps its colour and its 0.1 s and is drawn brighter than white (data), so it blooms; the chunks are unchanged.
- [ ] AC-3: One new smoke shader draws the explosion's three puffs and a badly damaged Unit's puffs: soft round puffs whose edges break up with noise and that thin out by eroding from their edge inward over their life, instead of fading evenly, with a lit side toward the sun and a shaded side away from it, each in its own grey (no Team colour), casting no shadow. The explosion's puffs take the badly damaged smoke's billboard quad (story 017 chose the soft quad over the ball), so the two smokes read as one. The Flag dropped at a carrier's wreck still reads through the explosion's smoke (story 016's frame 12, recorded again).
- [ ] AC-4: Every change over a piece's life comes from its node's own ticks, given to the shader per piece as an instance uniform (its age), never from the shader's TIME, so the same run draws the same frames: the explosion keeps playing under the Round-over screen (story 016) and the badly damaged smoke stops with the pause (story 017). Nothing is random: the noise is a texture written by a script, and each piece's offset into it is fixed data.
- [ ] AC-5: One material per shader serves every explosion and every smoke: no material is local to the scene (today's fireball material is) and nothing is duplicated per explosion; the per-piece values go through instance uniforms, colours as a Vector4 (story 025's trap: a Color given to an instance uniform is converted from sRGB). The time to instance the first explosion after a gap and the next is measured before and after (story 016 measured 4 to 10 ms against 0.3 to 1 ms while its materials were local to the scene: `explosion.gd:31-37`).
- [ ] AC-6: Every value is data: ExplosionSettings and the smoke scene's exports gain the new look values (the noise's size and strength, the fireball's colour ramp and its brightness, the smoke's erosion and its light); no number in code but 0 and 1.
- [ ] AC-7: Three explosions at once and two smoking Units, in both views, keep the project budget, measured windowed at 1280 x 720 the `map_fps` way (the lowest one-second rate at least 60 fps, a frame at most 16.6 ms, at most 1,000 draw calls for both views together); the frame time with and without the new looks is recorded as an observation beside TD-016 and TD-017.
- [ ] AC-8: The older evidence scenarios keep their outputs byte for byte against the capture taken at the start of the story: every scenario that does not declare the new opt-in sees story 016's explosion and story 017's smoke as they are today.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are the working tree of 2026-10-16 (`main` at 14eec71 plus story 025's uncommitted build): re-find them as stories 025 to 028 leave them.*

- **What the tree gives.** `src/gameplay/effects/explosion.tscn`: a unit SphereMesh (`:6-10`) and a unit BoxMesh (`:12-13`); four unshaded StandardMaterial3D, the flash's (`:15`), the fireball's, local to the scene so its colour can change every tick (`:18-19`), the chunks' (`:22`) and the smoke's, see-through (`:25-26`); the Explosion node in process mode ALWAYS (`:29-30`) with Flash, Fireball, Debris/Chunk and Smoke/Puff (`:38-60`). `explosion.gd` writes the settings' colours into the shared materials once in `_ready()` (`:118-121`), poses every piece on its own ticks (`_pose()`, `:175`), sets the fireball's scale and colour each tick (`_pose_fireball()`, `:189-201`) and fades each puff with `GeometryInstance3D.transparency` (`_pose_smoke()`, `:219-231`). `explosion_settings.gd` holds every number with zero defaults and `first_problem()` (`:11-16`). `src/gameplay/effects/badly_damaged_smoke.tscn`: a radial GradientTexture2D (`:5-15`) on a 2 x 2 QuadMesh (`:17`) in an unshaded see-through StandardMaterial3D that faces the camera (`:20-26`), a pool of top-level puffs (`:38`); `badly_damaged_smoke.gd` grows and fades each puff on its own ticks (`_pose_all()`, `:179-194`). SplitScreen warms one explosion before the Round, because the first one ever made took 12 to 16 ms to instance (`src/gameplay/split_screen/split_screen.gd:351-366`).
- **The fireball shader.** Vertex: push the sphere's surface out along its normal by a noise sampled in the sphere's own frame (so the shape stays with the ball), its amount by the age. Fragment: a temperature from the noise and from how squarely the surface faces the camera (the heart is hot, the rim cool), lowered by the age, through a ramp of four or five colours (data: ExplosionSettings' start and end colours and the stops between them), with an emission above 1 at the hottest (data) and an alpha that falls off toward the rim for the soft edge. A soft edge makes the fireball see-through, so it is sorted with the puffs: measure the order against the smoke and the Flag. The flash can take the same shader at its own age, or its StandardMaterial3D with an emission above 1: the build's call.
- **The smoke shader.** On the billboard quad: a round falloff from the quad's middle, broken up by the noise; the erosion threshold rises with the age, so the noise eats the puff from its edge inward; a normal rebuilt as a half sphere from the quad's UV, so a lit material gives the puff a sunny side and a shaded side (a puff under a water tower's tank is darker), with no highlight; no shadow cast. Measure that a lit, see-through billboard takes the sun's shadow map in Forward+ on 4.7.2, and the cost.
- **The noise.** A seamless texture written by a script under `tools/blender/` (the `build_ground_textures.py` pattern; `ground_soft.png` may already serve: measure), sampled at a fixed offset per piece (data: the chunk directions are fixed the same way, `explosion_settings.tres`). Prefer a PNG to a NoiseTexture2D, whose image is generated after loading: measure whether that would show on the first explosion's first frame.
- **The instance uniforms.** One ShaderMaterial per shader in the scenes, shared by every copy, with the settings' colours written into it once (the same value every time, as `_ready()` does today); each piece's age and offset set with `set_instance_shader_parameter()` (scalars and vectors, at most 16 per shader, per the 4.7 shading-language reference). The badly damaged smoke's puffs are copies of one template sharing its mesh and material (`badly_damaged_smoke.gd:22-30`), so the pool stays one material.
- **The older outputs** (AC-8). `tools/evidence/split_screen/explosions_picture.gd` reads the pieces' materials, the puffs' fades and the fireball's StandardMaterial3D colour each tick (`:5-6`, `:74`, `:79-80`), and `explosions_data.gd`, `badly_damaged_smoke.gd` and `badly_damaged_data.gd` read the looks too. The runner (`tools/evidence/split_screen_harness.gd`) therefore gets a new opt-in, `const FIRE_LOOKS: bool = true`. Two ways to give every other scenario today's looks, measured by the regression: byte copies of today's `explosion.tscn` and `badly_damaged_smoke.tscn` under `tools/evidence/frozen/` that the runner swaps in (`explosion_scene` on SplitScreen, `smoke_scene` on each model scene, the `_apply_rotors_off()` way, `:1351`), which run the shipped scripts, so those scripts must still draw a StandardMaterial3D look exactly as today; or the new looks as data that the runner nulls on the shared settings before the scene is instanced (the `_apply_badly_damaged_off()` way, `:1313`), the scenes keeping today's materials as the look of a null setting. The build's call, recorded. The baseline is the retained outputs of the last closed story, captured twice before the first edit.
- **The evidence scenarios.** `fire_and_smoke` (headless, run twice byte-identical, declaring `FIRE_LOOKS`, `EXPLOSIONS` and `BADLY_DAMAGED` with the opt-ins their pieces need) checks: one material per shader across three explosions and two smokes, none local to the scene; each piece's age and offset by tick, the colours as Vector4; story 016's ticks (the flash, the fireball's swell and shrink, the puffs' start, stagger and end) and story 017's (born every interval, the lifetime) unchanged; no Team colour, no shadow, render layer 1; the smoke's age frozen under the Round-over screen and the explosion's going on; the settings refusing a negative strength and a ramp out of order; a lint of the new files (no number but 0 and 1, the `mines_lint` way: `tools/evidence/split_screen/mines.gd:170`). `fire_and_smoke_showcase` (windowed `--write-movie`, the `explosions_showcase` moments, waiting for 120 fps): a Motorbike shot down (the flash, the fireball); a Truck's Self-destruct (the fireball, the chunks and the smoke, the smoke thinning); a Gyrocopter shot down in the air; a carrier's wreck with the Flag reading through the smoke; three explosions at once; a badly damaged Unit standing (a column) and driving (a trail), and one under a water tower's tank; each before and after. `fire_and_smoke_fps` (windowed A/B, AC-7) and the instancing times of AC-5.
- **Seeded defects** (story 011's script as the template). At least: the age taken from TIME (the badly damaged smoke moves under the Round-over screen: windowed); a material local to the scene again (the shared-material check); a colour given to an instance uniform as a Color (the type check); the fireball never brighter than white (no bloom: windowed); offsets that differ between runs (the two runs differ); a Team colour on a piece; a puff casting a shadow; the smoke unlit (no shaded side: windowed); a number written in code (the lint); the runner leaving the new looks on (the regression fails).
- **Docs in the same change** (`design/rules.md`, Process rules): in "Teams and visual style", the explosion and the smoke as built; `CONTEXT.md`'s Explosion and Badly damaged where the look is named; the shaders' headers (Purpose, Target, Budget); README's How it plays; a Story 029 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close; `tools/blender/readme.md` for any new texture script.
- Process (`design/rules.md`, Process rules): after the change, say how to test it: the main scene; shoot a Unit down, Self-destruct one (in a Base's yard it is a Swap: do it outside), bring a Unit to a fifth of its hit points; watch from both cameras.

---

## Out of Scope

- The chunks' look; a burning wreck; fire on a badly damaged Unit (`CONTEXT.md`'s Badly damaged avoids "on fire").
- Scorch marks or craters on the ground (the fifth idea, left out on 2026-10-15).
- Sparks and muzzle flashes (story 030); heat haze (story 031); distortion over the fire.
- Particles (GPUParticles3D): the pieces stay built-in meshes.
- A Mine's own flash; sound.

**Questions for the author** (built as read; asked at `/story-done`)
1. The fireball is ragged and white-hot at its heart, darkening to soot as it dies. Keep, more or less ragged, hotter or cooler?
2. The smoke breaks up from its edges instead of fading evenly, and is lit on its sunny side. Keep, thicker or thinner?
3. The explosion's smoke puffs are now soft billboards like a badly damaged Unit's smoke (they were grey balls). Keep?
4. The flash now glows (it is brighter than white). Keep, or the flat flash of before?
5. At a carrier's wreck the dropped Flag reads through the smoke (frame). Enough, or thinner smoke there?

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- Retained screenshots and the lead's sign-off; record the evidence in `production/qa/evidence/story-029-fire-and-smoke-evidence.md`: `fire_and_smoke` run headless twice byte-identical; the windowed `fire_and_smoke_showcase` and `fire_and_smoke_fps` (AC-7's bar, the frame time with and without as an observation); the instancing times (AC-5); the facts measured first (the sort order, the lit billboard's shadows, the noise's first frame); the regression against the capture taken at the start of the story; the seeded defects.
- Retain frames in `production/qa/evidence/story-029-fire-and-smoke/`: 00 the launch; the moments of the showcase, each before and after; four consecutive frames of one fireball; the smoke under a water tower's tank.
- The human checks at `/story-done`: the explosions and the smoke in play (both views, both cameras); the five questions.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 027 (the glow that makes the fire bloom). Never beside another story: every one of them edits the runner and re-baselines the same outputs.
- Unlocks: None.
