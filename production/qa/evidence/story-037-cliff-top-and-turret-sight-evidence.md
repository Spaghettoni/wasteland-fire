# Story 037 evidence: RidgeWest's top and the Turret's sight of a flying target

> **Story**: `production/epics/wasteland-fire/story-037-cliff-top-and-turret-sight.md`
> **Written**: 2026-10-19, cloud session (Godot 4.7.2; Blender 5.2.2 LTS as the `bpy` module)
> **Sign-off**: [ ] pending — Martin's play is for `/story-done`

| AC | Result |
|---|---|
| AC-1 rock tops | PASS (`cliff_tops`): up-facing area against outline, m²: RockCanyonNorth 2552/2545, RockCanyonSouth 1249/1243, RidgeWest 1331/1330 (was 67), RidgeCentre 1805/1802, RidgeEast 1332/1330; down-facing at most 4 |
| AC-2 fixed in the script | PASS: `build_rocks.py` turns every top face up and skips the kit's recalc for it (`_finish_part(recalc=False)`); the unchanged script first rebuilt the same five meshes, vertex and index counts as the committed `.glb`, then the fixed one wrote it |
| AC-3 Gyrocopter over a cliff | PASS (`turret_flying_sight` F1): aimed, 5 Shots in 240 ticks, hit points 70 -> 10 |
| AC-4 ground still hidden | PASS (F3): a Buggy 3 m behind the block, not aimed at, no Shot |
| AC-5 data | PASS (F4): sight_extra_mask 32, flying_sight_extra_mask 0; F2: with 32 the Turret stays idle (the check can fail) |
| AC-6 older outputs | see Regression |

Both scenarios ran twice, byte-identical. Frames: `story-037-cliff-top-and-turret-sight/00-ridge-west-from-above-before.png` (the ridge hollow: its walls and the sand inside) and `01-ridge-west-from-above.png` (a full top like its neighbour), OpenGL compatibility renderer under Xvfb.

## Regression

Pending at commit time: all 97 scenarios on `main` at a6708b4 against this tree; the result is added when the run ends.
