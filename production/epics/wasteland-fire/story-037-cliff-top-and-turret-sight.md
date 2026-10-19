# Story 037: RidgeWest's top is drawn, and a Turret sees a Gyrocopter over a cliff

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (half a day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-19

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Heights"; "Turrets, Flag Walls and Mines"); `CONTEXT.md` (Turret, Height)
**Requirement**: Martin's playtest of 2026-10-19 (with a screenshot): "vsimol som si ze jeden utes sa dobre nezobrazuje, je akoby prazdny" (one cliff is not drawn right, it looks empty) and "ked s gyrokopterov letis nad utesom, tak Ta vezicka neregistruje a nestriela po tebe, to chceme zmenit" (when you fly the Gyrocopter over a cliff the Turret does not notice you and does not shoot at you; we want to change that).

Found: `map_01_rocks.glb`'s RidgeWest has its top built facing down (67 m² of up-facing top against 1,330 m² of outline; RidgeEast, its mirror, 1,332), so Godot culls it and from above the ridge shows only its walls. `tools/blender/build_rocks.py` builds each top as an open sheet and lets `recalc_face_normals` choose its side, which guessed wrong for that outline. The Turret's sight ray adds the cliffs layer (`sight_extra_mask` 32: a cliff hides a target though Shots pass through cliffs), so a Gyrocopter hovering over a cliff, its body at the shooting height inside the cliff's column, is never seen.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [x] AC-1: Every rock of Map 01 has a top that faces up over at least 80% of its outline's area; RidgeWest's matches RidgeEast's within 5%.
- [x] AC-2: The fix is in the build script (`build_rocks.py`: every face of a rock's top turned to face up), and the `.glb` is rebuilt from it, never edited by hand (`tools/blender/readme.md`).
- [x] AC-3: A Turret sees, aims at and fires on a Gyrocopter flying over a cliff, and its Shots hit.
- [x] AC-4: A cliff still hides a ground Unit behind it from a Turret, as before.
- [x] AC-5: The sight is data: `TurretStats.flying_sight_extra_mask` (0 in `turret_stats.tres`) is used in place of `sight_extra_mask` for a target whose type can fly.
- [x] AC-6: The older evidence scenarios keep their outputs: the runner gives them the old sight (`flying_sight_extra_mask` = `sight_extra_mask`) unless they declare `TURRET_SEES_FLYING`; the rocks' tops change only what is drawn.

---

## Implementation Notes

- Rebuilt with `bpy` 5.2.2 (Blender 5.2.2 LTS as a Python module, the version `tools/blender/readme.md` names), the unchanged script first: the same five meshes with the same vertex and index counts as the committed file.
- `wasteland_kit._finish_part()` takes `recalc=False` for a caller that has set its faces' sides.
- Scenarios: `cliff_tops` (AC-1, AC-2), `turret_flying_sight` (AC-3 to AC-5: an arena Turret, a 10 x 2.5 x 10 m block on the cliffs layer 20 m ahead, a Gyrocopter over it, the same with the old sight, a Buggy behind it).

---

## Out of Scope

- Bushes or anything else hiding a Gyrocopter.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `production/qa/evidence/story-037-cliff-top-and-turret-sight-evidence.md` with the two scenarios' outputs and Martin's checks in the game.

**Status**: [x] Created 2026-10-19: `production/qa/evidence/story-037-cliff-top-and-turret-sight-evidence.md`, two frames and the outputs of `cliff_tops` and `turret_flying_sight`

---

## Dependencies

- Depends on: None.
- Unlocks: None.

---

## Completion Notes

**Completed**: 2026-10-19
**Criteria**: 6/6 passing: `cliff_tops` (2 checks) and `turret_flying_sight` (4 checks), each run twice byte-identical; the ridge's frames before and after; Martin played `WastelandFire-2026-10-19-ridge-turret.exe` and accepted it ("ok, super za mna", 2026-10-19).
**Deviations**: None.
**Test Evidence**: Integration: `production/qa/evidence/story-037-cliff-top-and-turret-sight-evidence.md` (sign-off `[x]`, 2026-10-19), the regression of the 97 older scenarios.
**Code Review**: Skipped, Solo mode; QL-TEST-COVERAGE skipped, `qa.level` minimal.
**Tech debt logged**: None. `map_01_rocks.glb` was rebuilt with Blender 5.2.2 as the `bpy` module (`tools/blender/readme.md`); the unchanged script gave the committed mesh counts, so a rebuild on Tomáš's Blender should match.
