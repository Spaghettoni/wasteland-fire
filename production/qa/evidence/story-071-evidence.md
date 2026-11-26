# Evidence: Story 071 — art overhaul toward Martin's voxel-desert picture

Date: 2026-11-26 · Godot 4.7.2 · Linux. Frames rendered with Forward+ on Vulkan (Mesa lavapipe under xvfb), the renderer the
game ships with. (Earlier stories' "windowed" frames fell back to OpenGL; this story's are the first in Forward+.)

Frames in `story-071/`:
- `before-map03-chase.png`, `before-map03-hero.png` — the look before.
- `after-map03-chase.png`, `after-map03-hero.png`, `after-map03-wide.png`, `after-map02-chase.png`, `after-map02-base.png`, `after-map01-wide.png` — the Map viewer (the Maps with Unit models, the shipped tilt-shift attributes): warm low sun and long shadows, pixel sand, mesas, cactuses, rocks, voxel bushes, stone-block walls, strata cliffs, teal sea, the far blur.
- `game-flame-stream.png`, `game-burning-buggy.png` — the flame_tank scenario recorded in the game (harness arena): the saturated flame stream, the voxel smoke, the burning Buggy with its fire riding along.
- `voxel-props.png` — the generated props.

Checks:
- Full regression (132 scenarios): the same exits as before the overhaul, except `fuel`, which logged the host's Jolt "maximum number of jobs" warning (a known flake on this 2-core machine); rerun alone: ok.
- Along the way: map_02 M3_ridge and M2_canyon and tyre_tracks ground_surfaces failed on the first scenery; place_scenery.gd now keeps clear of ridges and cliffs, 12 m off a sea-less Map's edges, colliders 1.2 m tall at most, and gives the far sand its own material; all three pass.
