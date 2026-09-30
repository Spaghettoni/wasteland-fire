# Story 002: Split screen for two

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-09-30

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 — *Split screen for two: two side-by-side viewports, one Unit and one fixed keyboard layout per Player, both driving at once.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: The launch scene shows two viewports side by side filling the 1280×720 window (640×720 each), each with its own chase camera following its Player's Unit.
- [x] AC-2: Two Motorbikes exist, one per Player, at distinct start positions, both in the same 3D world (one `World3D`, not two copies of the scene).
- [x] AC-3: Player 1 drives with W/A/S/D and Player 2 with the arrow keys; each layout moves only its own Unit.
- [x] AC-4: Both Players can drive at the same time — holding keys from both layouts moves both Units; any keyboard-ghosting limit found on the dev keyboard is recorded in the evidence doc.
- [x] AC-5: Key bindings are Input Map actions named per Player (`p1_throttle`, `p1_steer_left`, … `p2_…`) defined in `project.godot`, not key codes in scripts.
- [x] AC-6: Input handling never compares `InputEvent.device` to `0` to identify the keyboard (Godot 4.7 changed keyboard/mouse device IDs; two keyboards are not distinguished — layouts, not devices, separate the Players).
- [x] AC-7: Holds 60 fps with two viewports rendering the shared world.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- `HBoxContainer` → two `SubViewportContainer` (stretch on) → `SubViewport` each with its own `Camera3D`; leave `own_world_3d` off so both share the world (research note, Part 2 §A.1; `docs/engine-reference/godot/modules/rendering.md`).
- `docs/engine-reference/godot/modules/input.md` § 4.7 Changes: `InputEvent.DEVICE_ID_KEYBOARD` is 16, `DEVICE_ID_MOUSE` 32; the release page says 4.7 "does not add support for differentiating between multiple keyboards or mice" — per-Player actions are the mechanism.
- `Input.get_vector(&"p1_steer_left", &"p1_steer_right", &"p1_throttle", &"p1_reverse")` per Unit, with the action prefix injected from the Player (data), not two copies of the driving script.
- Audio (later): only viewports with `audio_listener_enable_3d` enabled are merged in 4.7 (`modules/audio.md`) — irrelevant now, relevant when sound arrives in the Game-Night Build.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: Bases, hit points, destruction, respawn.
- Story 004: HUD elements inside each viewport.
- Story 005: Unit choice per Player.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: waived at `qa.level: minimal` — record the two-player drive as a playtest note in `production/qa/evidence/story-002-split-screen-evidence.md`.
- The run-and-observe screenshot is not waived: a retained frame showing both viewports with both Units, in `production/qa/evidence/story-002-split-screen/`.

**Status**: [x] Retained — `production/qa/evidence/story-002-split-screen/` (6 screenshots + showcase output) and `production/qa/evidence/story-002-split-screen-evidence.md` (playtest record; the developer's confirmations recorded at `/story-done`, 2026-09-30)

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Story 003

## Completion Notes
**Completed**: 2026-09-30
**Criteria**: 7/7 passing. AC-1 to AC-7 measured on the real build (real key events through the Input Map, headless and windowed) and observed in retained screenshots; AC-1 (the look and the smooth follow of the running build), AC-3 (each layout moves only its own Unit) and AC-4 (both Players drive at once; ghosting check 6/6 combinations green, no limit on the dev keyboard) confirmed by the developer on the real keyboard at `/story-done`. Nothing deferred.
**Deviations**: ADVISORY only. (1) Additions beyond the AC text, all in the decision log: a 4 px overlay divider, per-Player Body colours as data, a second start marker (`player_2_start`) on the field, `World.physics_interpolation_mode = ON` (a Control root defaults to OFF, so the first build drew both Units at the 60 Hz tick: measured and fixed), and the keyboard-ghosting tool with a self-test and a styled page. (2) The evidence harness is 965 lines: TD-003. (3) Above 1280×720 the views are scaled up instead of rendering native pixels: TD-004. (4) Story 001 files changed additively only (`greybox_field.*`, `project.godot`); its six frozen files are byte-identical (sha256) and its harness output is identical line for line.
**Test Evidence**: Integration — playtest record at `production/qa/evidence/story-002-split-screen-evidence.md` and 6 retained screenshots in `production/qa/evidence/story-002-split-screen/`. Tests waived at `qa.level: minimal`; none written.
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped — `qa.level` minimal. A lead-programmer standards review, a GDScript-specialist engine review and a Godot-specialist architecture review ran inside the `/dev-story` workflow: 23 findings on the first pass, 15 fixed over two fix rounds, the remaining 8 resolved or recorded by the orchestrator; the engine, architecture and both measurement lenses ended clean.
**Tech debt logged**: TD-003 (harness size), TD-004 (views upscaled above 1280×720) in `docs/tech-debt-register.md`; TD-001 amended.
**Notes for Story 003**: the match controller should own spawning, so the first spawn and every respawn take one path: lift `SplitScreen._spawn_unit` there and remove the spawn from `SplitScreen._ready()`. `PlayerDriveInput._ready()` turns its physics processing off for good when `unit` is null at ready, so a Unit assigned at runtime needs that node re-enabled, or the Unit assigned before ready. The two start markers become the Bases. Both Units start in one lane facing each other, so two Players holding throttle from the first second meet head-on after about 1.6 s and, as kinematic bodies, stop dead.
