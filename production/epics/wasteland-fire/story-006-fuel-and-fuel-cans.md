# Story 006: Fuel and Fuel Cans

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — *Fuel and Fuel Cans: every Unit burns Fuel while moving, the Gyrocopter fastest; an empty ground Unit stops but can still turn and fire; an empty Gyrocopter crashes and counts as destroyed; a fresh Unit spawns with a fixed partial tank; Fuel Cans at fixed Map spots refill and respawn.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: Each Unit type has a Fuel capacity and a burn rate in its data resource; the Gyrocopter's burn rate is the highest of the three.
- [ ] AC-2: Fuel decreases only while the Unit is moving (throttle applied or the Gyrocopter airborne), at its type's rate; a stationary ground Unit burns nothing.
- [ ] AC-3: A ground Unit at 0 Fuel cannot drive but can still turn on the spot and fire.
- [ ] AC-4: A Gyrocopter at 0 Fuel crashes: it is destroyed and goes through the normal respawn path, dropping a canister if it were somehow carrying one (it cannot — `can_carry` is false — but the drop code path must not assume a ground Unit).
- [ ] AC-5: A freshly spawned Unit starts with a fixed partial tank (a data fraction of capacity), so dying is never a free refuel.
- [ ] AC-6: Fuel Cans sit at fixed Map spots; touching one refills a data-defined amount, removes the can, and the can respawns at the same spot after a data-defined delay.
- [ ] AC-7: Each Player's HUD shows a Fuel gauge that visibly empties while moving and refills on a can.
- [ ] AC-8: Self-destruct still works at 0 Fuel, so a stranded Player can always respawn.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Fuel fields in `UnitStats` (`fuel_capacity`, `fuel_burn_per_second`, `spawn_fuel_fraction`); decrement in `_physics_process` when moving; at 0 the drive input is ignored, steering and fire are not.
- Fuel Can = scene with `Area3D` + mesh + a respawn `Timer`; the Map places them at `Marker3D` spawn points (data), with amount and respawn delay in a `.tres`.
- The empty-Gyrocopter crash reuses the Unit's own `destroyed` path (story 003) — no second death mechanism.
- HUD gauge extends the story 004 HUD; fit inside 640×720.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: where exactly the cans and Bases sit in the dressed arena (positions are markers the Map owns).
- Game-Night Build: no ammo economy, no repair — the rules dropped them.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Unit test `tests/unit/fuel/story-006-fuel-and-fuel-cans_test.gd` covering burn, empty rules and the partial tank: waived at `qa.level: minimal` (advisory).
- The run-and-observe screenshot is not waived: a retained frame of a HUD with the Fuel gauge and a Fuel Can in view, in `production/qa/evidence/story-006-fuel-and-fuel-cans/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 must be DONE
- Unlocks: Story 007
