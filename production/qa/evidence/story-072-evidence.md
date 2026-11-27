# Evidence: Story 072 — art overhaul, Martin's first feedback

Date: 2026-11-27 · Godot 4.7.2 · Linux; frames in Forward+ (Vulkan, Mesa lavapipe under xvfb).

Frames in `story-072/`:
- `map03-hero.png`, `map01-wide.png` — low-poly faceted sand (no grid), low-poly bushes, short voxel cactuses, no rocks, no mesas on the island Maps, no tilt-shift.
- `map02-wide-mesas.png` — Map 02: smooth strata cliffs with sand tops, low-poly mesas wholly out of play.
- `flame-stream-side.png`, `flame-stream-chase.png` — the new flame stream (puffs laid along 20 m 2.1 m apart, as in flight): white-yellow core at the nozzle, billowing orange, red, rising.

Checks:
- Full regression (132 scenarios): the same exits as before the overhaul (compared with the run of 2026-11-22).
- Along the way: map_02 M3_ridge failed twice on a cactus at the ridge's foot (the ridge has no collider the placer's sphere query saw); place_scenery.gd now also keeps 6 m from any raised terrain piece's box. heights, bushes, tyre_tracks, flame_tank, map_02, map_03 pass.
- Sound: the repository has never had an audio file or player (all commits, both branches), so nothing went missing.
