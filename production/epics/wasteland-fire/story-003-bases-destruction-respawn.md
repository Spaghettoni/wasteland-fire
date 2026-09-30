# Story 003: Bases, destruction and respawn

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

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

- [ ] AC-1: Two greybox Bases stand on the plane, one per Player, visually distinct (Player colours), each with a spawn point; each Player's Unit starts the Round at its own Base.
- [ ] AC-2: Every Unit has hit points from its data resource; a Unit whose hit points reach 0 is destroyed and leaves play.
- [ ] AC-3: A destroyed Unit respawns at its Player's Base after a delay whose default is 3 seconds and which is a data tuning value.
- [ ] AC-4: Respawns are unlimited — a Player can be destroyed and respawn any number of times in a Round.
- [ ] AC-5: Self-destruct: one key per Player destroys that Player's own Unit immediately, which then goes through the normal respawn path.
- [ ] AC-6: While a Player is waiting to respawn, their viewport shows the seconds remaining.
- [ ] AC-7: Match state (who is alive, respawn timers) lives in one match-controller node that emits signals (`unit_destroyed`, `unit_spawned`); Units never reach into each other or into a global singleton to change state (coding standards: dependency injection over singletons, public methods unit-testable).
- [ ] AC-8: Until story 005 exists, a debug key applies damage to the local Unit so AC-2/AC-3 can be exercised; it is removed or gated behind a debug flag when weapons arrive.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE
- Unlocks: Story 004
