# Story 003: Bases, destruction and respawn

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-01

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — *Bases, destruction and respawn: two greybox Bases; a destroyed Unit respawns at its Player's Base after a delay of about three seconds (tuning value); a Self-destruct action so a stranded Unit can respawn.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: Two greybox Bases stand on the plane, one per Player, visually distinct (Player colours), each with a spawn point; each Player's Unit starts the Round at its own Base.
- [x] AC-2: Every Unit has hit points from its data resource; a Unit whose hit points reach 0 is destroyed and leaves play.
- [x] AC-3: A destroyed Unit respawns at its Player's Base after a delay whose default is 3 seconds and which is a data tuning value.
- [x] AC-4: Respawns are unlimited — a Player can be destroyed and respawn any number of times in a Round.
- [x] AC-5: Self-destruct: one key per Player destroys that Player's own Unit immediately, which then goes through the normal respawn path.
- [x] AC-6: While a Player is waiting to respawn, their viewport shows the seconds remaining.
- [x] AC-7: Match state (who is alive, respawn timers) lives in one match-controller node that emits signals (`unit_destroyed`, `unit_spawned`); Units never reach into each other or into a global singleton to change state (coding standards: dependency injection over singletons, public methods unit-testable).
- [x] AC-8: Until story 005 exists, a debug key applies damage to the local Unit so AC-2/AC-3 can be exercised; it is removed or gated behind a debug flag when weapons arrive.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Base = a scene with an `Area3D` zone, a `Marker3D` spawn point and a coloured greybox mesh; the Map scene instances two and hands the match controller their references (data, not hardcoded positions).
- Match controller owns respawn `Timer`s and spawn logic; Units expose `apply_damage(amount)` and emit `destroyed`; signals up, calls down.
- Hit points and respawn delay live in `UnitStats` / a `MatchRules` resource (`.tres`), never as literals.
- `docs/engine-reference/godot/modules/physics.md` § 4.7 Changes: under Jolt, `Area3D` now also reports `SoftBody3D` overlaps — irrelevant here but set collision layers/masks deliberately from the start (Units, canisters, zones on separate layers).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the Water Canister, HUD hit-point display, Round end.
- Story 005: weapons and damage from other Players; choosing a Unit at spawn; swapping at the own Base.
- Story 006: the partial tank on spawn (no Fuel yet).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Unit test `tests/unit/match/story-003-bases-destruction-respawn_test.gd`: waived at `qa.level: minimal` (advisory; gdUnit4 is not installed until `/test-setup`).
- The run-and-observe screenshot is not waived: a retained frame of a viewport showing the respawn countdown and the two Bases, in `production/qa/evidence/story-003-bases-destruction-respawn/`.

**Status**: [x] Retained — `production/qa/evidence/story-003-bases-destruction-respawn/` (7 screenshots + the showcase, destruction and fps outputs) and `production/qa/evidence/story-003-bases-destruction-respawn-evidence.md` (the developer's confirmations recorded at `/story-done`, 2026-10-01)

---

## Dependencies

- Depends on: Story 002 must be DONE
- Unlocks: Story 004

## Completion Notes
**Completed**: 2026-10-01
**Criteria**: 8/8 passing. AC-1 to AC-8 measured on the real build (real key events through the Input Map, headless and windowed, plus mutation testing) and observed in retained screenshots; AC-5 (Tab and Enter on the real keyboard), AC-6 (the look of the countdown), AC-8 (the 1 and 2 debug keys) and the AC-3 feel (3 seconds is the right starting value) confirmed by the developer at `/story-done`. Nothing deferred.
**Deviations**: ADVISORY only. (1) Respawn onto a parked Unit: not in the story, but a Unit spawned inside another one ends under the floor or in the air (measured), so each Base has two spare spawn points (4 m left and right of the spawn point) and `MatchController` puts the Unit on the first free spot on the due tick, never inside a Unit (`Unit.is_spot_taken()`); with every spot taken it keeps waiting and the label reads 1. The policy is open to the designer and lives in one function, `MatchController._try_respawn()`. (2) The respawn wait is a physics-frame stamp, not the `Timer` the implementation notes mention and not a delta countdown (`.claude/rules/gameplay-code.md`): the only clock measured to fire on exactly round(delay × 60) ticks from every call context; it is frame-rate independent and honours pause; `Engine.time_scale` is untested and unused. (3) The Beacon stands on the pad's front-right corner, not the back edge the design said, because a back-edge pillar hides the Unit from its own chase camera. (4) The loose start markers stay as the Bases' spawn points, because the frozen Story 001 harness writes `player_start.transform` as a field-space position: TD-005. (5) Story 001 and 002 files were extended on purpose (`unit.gd`, `unit_stats.gd`, `motorbike_stats.tres`, `greybox_field.*`, `split_screen.*`, `project.godot`); Unit movement is bit-identical to the committed code (per-tick hash) and every Story 001 and 002 harness output is byte-identical to the pre-story baselines. (6) `.claude/rules/ui-code.md` asks for scalable text and colourblind modes: not built, no settings system exists: TD-007. (7) Preload constants that hold scripts are PascalCase under `tools/` (the GDScript style-guide exception).
**Test Evidence**: Logic — evidence record at `production/qa/evidence/story-003-bases-destruction-respawn-evidence.md` and 7 retained screenshots in `production/qa/evidence/story-003-bases-destruction-respawn/` (frame 03 shows the countdown in one view and a Base in each). Unit test waived at `qa.level: minimal`; none written.
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped — `qa.level` minimal. A lead-programmer standards review, a GDScript-specialist engine review and a Godot-specialist architecture review ran inside the `/dev-story` workflow: 19 findings on the first pass; its two fix rounds added unrequested behaviour and left 20 open, so the orchestrator simplified the respawn policy and two fix agents applied the rest (one real defect: a missing debug action switched off Self-destruct). The architecture lens ended clean.
**Tech debt logged**: TD-003 resolved (the Story 002 harness is now a 330-line runner plus one script per scenario); TD-005 (loose start markers), TD-006 (scenario set, 3,238 lines) and TD-007 (scalable text and colourblind modes) in `docs/tech-debt-register.md`.
**Notes for Story 004 and 005**: `Unit.destroyed` fires with the Unit still at the wreck, so a Water Canister can drop at `unit.global_position` in that handler. A HUD hit-point display can poll `hit_points` and `stats.max_hit_points`; a `hit_points_changed` signal is three emit lines if wanted. A Round restart is `get_tree().reload_current_scene()` or a short `restart()` that calls `_spawn()` per Player (`begin()` refuses a second call on purpose). The Base `Zone` sees both Players' Units and carries no Player index, so the owner check belongs in the controller; its events arrive one tick after a destroy or a spawn. Story 005: `spawn()` will take a `UnitStats` argument and the `_ready()`-only setup (snap length, wall angle, saved layer and mask, `_can_drive`) must become callable from it; `PlayerDriveInput` turns itself off for good when its Unit is null at ready; set `debug_damage` to 0 to switch the debug keys off (the actions may then be deleted). Both Players still start in one lane facing each other, so holding throttle from the first second meets head-on after about 1.6 s: the Bases now decide the start layout.

## v0.1 note (2026-10-01)

The author's artifact is now at version 0.1 (`design/source/`; rules of record `design/rules.md`). AC-4, "respawns are unlimited", is superseded by the Token stock of story 008: from then on a destroyed Unit costs one Token of its type, Self-destruct included (decided 2026-10-01), and a Player who loses their last Motorbike loses the Round. A Base's spawn point is the Garage of v0.1 (CONTEXT.md). The swap at the own Base that this story's Out of Scope hands to story 005 is dropped in v0.1 (decided 2026-10-01). Nothing in the built code changes until story 008; the story stays Complete as built.
