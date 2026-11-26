# Story 071: Art overhaul toward Martin's voxel-desert picture

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L
> **Last Updated**: 2026-11-26

## Context

**Requirement**: Martin, 2026-11-26, with a picture of a voxel desert (a spiked flame tank before layered cliffs, cactuses, a stone fortress, warm low sun, brown smoke, a dust cloud): "vedeli by sme spravit teraz taky poriadny overhaul, nech to vyzera ako na tomto obrazku, aj tie utesy, kaktusy, textury, svetlo, tiene, dym, plamene. nech to je naozaj pekne." All at once, one build. Tilt-shift: "len jemne, ale ostre moje vozidlo a to co vidim pred sebou". Teams stay teal vs orange.

## What changed

- **Light** — one shared Environment for Maps 01–03 (`src/gameplay/maps/data/wasteland_environment.tres`): warm dusk sky, AgX, SSAO, warm dust fog, glow, the colour-grade LUT, more saturation. The Sun is lower (30° up), warmer and stronger, with softer shadows.
- **Tilt-shift** — the Player cameras carry `src/gameplay/camera/data/tilt_shift_attributes.tres`: far blur only, from 48 m with a 45 m fade, so the own vehicle and what lies ahead stay sharp.
- **Ground** — `spatial_env_ground.gdshader` gained a pixel look (`pixel_size` 0.35 m on the sand, road and salt flat): every layer sampled per square tile, each tile its own tone, a faint seam and bevel that fade out with distance; side faces in rock bands.
- **Voxel props** — `tools/art/voxel_builder.gd` (cubes drawn as their exposed faces, with per-corner occlusion) and `tools/art/build_voxel_props.gd` write `assets/art/voxel/`: four layered mesas, four cactuses, four rocks, shrubs and the Bush's two looks.
- **Scenery** — `tools/art/place_scenery.gd` writes `map_0N_scenery.tscn` per Map: 26 mesas beyond the edges (in the sea on Maps 01 and 03), 34–40 cactuses and rocks in play away from everything that collides or watches and from ridges and cliffs (Map 02 also 12 m from its edges); colliders 1.2 m tall at most; Map 02 a plain far sand plane.
- **Bushes** — the voxel bush, the same sight and trigger shapes.
- **Walls** — stone blocks (`stone_blocks.png` + normal), also on the damaged Flag Wall looks. **Rock** — voxel strata (`rock_strata.png`). **Sea** — teal-tinted and glossier.
- **Effects** — the burn's smoke, impact smoke, muzzle smoke and the rocket trail are tumbling voxel cubes in browns and greys; the wheel dust is denser and warmer; the flame stream is more saturated with a hot core that blooms.

## Acceptance Criteria

- [x] AC-1: All three Maps share the new light and grade; frames show warm low sun and long shadows.
- [x] AC-2: The own vehicle and the ground ahead are sharp; only the far distance blurs.
- [x] AC-3: Mesas, cactuses, rocks, voxel bushes, stone walls and pixel sand on every Map.
- [x] AC-4: Smoke, dust and flames restyled.
- [x] AC-5: No gameplay change: the full regression has the same exits as before.

## Test Evidence

`production/qa/evidence/story-071-evidence.md`, frames in `production/qa/evidence/story-071/`.
