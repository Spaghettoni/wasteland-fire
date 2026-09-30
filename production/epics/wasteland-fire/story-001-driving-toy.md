# Story 001: Driving toy

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-09-30

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — *Driving toy: one Motorbike on a greybox plane: keyboard throttle and steering, chase camera, arcade kinematic movement that is fun to drive for five minutes.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: A scene launches straight from the command line (`godot --path . --windowed --resolution 1280x720 res://<scene>.tscn`) into a flat greybox plane with one Motorbike Unit on it and a chase camera behind it — no menu in between.
- [x] AC-2: Player 1's keyboard layout drives it: W/S throttle forward and reverse, A/D steer; releasing the keys lets the Unit coast to a stop.
- [x] AC-3: Movement is arcade and kinematic (`CharacterBody3D` in `_physics_process`), not a physics-vehicle simulation; the Unit never tips, bounces or gets stuck on the flat plane.
- [x] AC-4: Every feel value — max speed, acceleration, braking, reverse speed, turn rate — is read from a data resource (a `Resource` `.tres` per Unit type), never hardcoded in a script.
- [x] AC-5: The chase camera follows smoothly with no visible jitter at 60 fps (camera updated in `_process` with interpolation; physics interpolation enabled).
- [x] AC-6: A five-minute drive cannot leave the playfield (invisible walls or a plane large enough), and cannot fall through it.
- [x] AC-7: Holds 60 fps at 1280×720 on the dev machine (the perf budget in `.claude/docs/technical-preferences.md`).
- [x] AC-8: The stop condition of the build order — "fun to drive for five minutes" — is judged by a human and recorded in the evidence doc with what was tuned to get there.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- `CharacterBody3D` + `move_and_slide()`; `VehicleBody3D` is out — Godot's own reference says it "has known issues" and an overhead arcade game needs no suspension model (research note, Part 2 §A.3).
- Jolt is the 3D physics engine (`project.godot`). `docs/engine-reference/godot/modules/physics.md` § 4.7 Changes: GH-118155 moved Jolt's `body_test_motion` contact filtering and its PR warns about character controllers — re-test `move_and_slide()` on slopes and walls before calling the feel done.
- Feel values in a `UnitStats` `Resource` script + `motorbike.tres`; tuning is data (coding standards).
- Physics interpolation: `physics/common/physics_interpolation` on; camera smoothing in `_process`.
- Keep the launch scene reachable by path for run-and-observe; the scene is the story's evidence surface.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the second Player, second viewport and second key layout.
- Story 003: hit points, destruction, respawn.
- Story 005: weapons, the Buggy and the Gyrocopter.
- Story 006: Fuel — the Unit drives on nothing for now.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Visual/Feel
**Required evidence**:
- A retained screenshot (frame from `--write-movie`) of the Motorbike on the plane with the chase camera, in `production/qa/evidence/story-001-driving-toy/`, plus sign-off in `production/qa/evidence/story-001-driving-toy-evidence.md` recording the five-minute feel judgement (AC-8) and the tuned values.
- Tests: waived at `qa.level: minimal`.

**Status**: [x] Retained — `production/qa/evidence/story-001-driving-toy/` (6 screenshots) and `production/qa/evidence/story-001-driving-toy-evidence.md` (sign-off approved 2026-09-30)

---

## Dependencies

- Depends on: None
- Unlocks: Story 002

## Completion Notes
**Completed**: 2026-09-30
**Criteria**: 8/8 passing. AC-1 to AC-7 measured on the real build (scripted input through the Input Map, headless and windowed) and observed in retained screenshots; AC-2 (real keyboard), AC-5 (look) and AC-8 (five-minute feel) confirmed by the developer at `/story-done`. Nothing deferred.
**Deviations**: ADVISORY only. (1) The story's Implementation Notes asked to re-test `move_and_slide()` on slopes and walls; walls and corners were covered, slopes were not (the field is flat by AC-1) — logged as TD-002, Story 007 owns it. (2) A grid-floor shader was added beyond the story text as the speed and jitter reference (accepted). (3) The evidence harness is larger than needed and hardwires Player 1 — logged as TD-001. Also: `src/gameplay/arenas` was renamed `maps` for CONTEXT.md vocabulary. `assets/art/**` on disk is separate work, not part of this story.
**Test Evidence**: Visual/Feel — evidence doc at `production/qa/evidence/story-001-driving-toy-evidence.md` (6 retained screenshots, sign-off approved). Tests waived at `qa.level: minimal`; none written.
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW). A lead-programmer standards review and a GDScript-specialist engine review did run inside the `/dev-story` workflow: 22 findings applied over two fix rounds, all four verification lenses clean.
**Tech debt logged**: TD-001, TD-002 in `docs/tech-debt-register.md`.
