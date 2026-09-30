# Story 005: Three Units and the triangle

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — *Three Units and the triangle: Motorbike, Buggy and Gyrocopter with hit points and one weapon each; damage ×2 against the Unit you beat, ×½ against the Unit you lose to, ×1 against your own type; only the Buggy's gun can hit the Gyrocopter; the Gyrocopter flies over terrain; Unit type is chosen at every spawn, and driving into your own Base swaps it without dying.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: Buggy and Gyrocopter Units exist beside the Motorbike, each with its own data resource: hit points, max speed, acceleration, turn rate, weapon damage, fire rate. The Motorbike is the fastest and weakest, the Buggy the heaviest.
- [ ] AC-2: Each Unit has one weapon fired with a key per Player; a hit applies the weapon's damage to the Unit hit.
- [ ] AC-3: Damage follows the table: ×2 against the Unit you beat, ×0.5 against the Unit you lose to, ×1 against your own type, where Motorbike beats Buggy, Buggy beats Gyrocopter, Gyrocopter beats Motorbike. The triangle and the multipliers are data (a damage-table resource), not branches in code.
- [ ] AC-4: Hard rule on top of the table: only the Buggy's weapon can damage a Gyrocopter; every other weapon does 0 to it.
- [ ] AC-5: The Gyrocopter flies at a fixed altitude over terrain and ground obstacles and shoots from above; ground Units cannot collide with it.
- [ ] AC-6: At every spawn the Player chooses the Unit type from their viewport (keys 1/2/3 or equivalent) before the Unit appears.
- [ ] AC-7: Driving into your own Base opens the same choice and swaps the Unit type in place without a destruction or respawn delay.
- [ ] AC-8: The Carrier can shoot — a Motorbike carrying a canister keeps its weapon; the Buggy and the Gyrocopter can never pick up a canister (`can_carry` false in their data).
- [ ] AC-9: Every number above (hit points, damage, speeds, multipliers) is a tuning value in data; the rules of `design/rules.md` are the only things fixed.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- One `Unit` scene/script with per-type `UnitStats` `.tres` (research note §E step 4); the Gyrocopter uses `MOTION_MODE_FLOATING` with altitude held as a value, on its own collision layer so ground Units pass beneath.
- Weapon: hitscan `RayCast3D` or a projectile `Area3D`; resolve damage through `DamageTable.multiplier(attacker_type, target_type)` plus a `can_hit_air` flag only the Buggy's weapon sets.
- Selection UI: a small per-viewport `Control` shown by the match controller on `unit_destroyed` and on own-Base entry; the choice is passed into the spawn call (data in, no globals).
- `docs/engine-reference/godot/modules/physics.md` § 4.7 Changes: Jolt `Area3D`/`SoftBody3D` overlap and `WorldBoundaryShape3D.plane.d` sign notes; keep layers/masks explicit for air vs ground.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: Fuel burn rates per Unit (the Gyrocopter's is highest), the crash at 0 Fuel.
- Story 007: kit models for the three Units; greybox shapes are fine here (a distinct silhouette each).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Unit test `tests/unit/combat/story-005-three-units-and-triangle_test.gd` covering the damage table and the Gyrocopter hard rule: waived at `qa.level: minimal` (advisory — but this is the first story where a unit test is cheap and valuable; `/test-setup` may run here).
- The run-and-observe screenshot is not waived: retained frames of the Unit selection UI and of all three Units in play, in `production/qa/evidence/story-005-three-units-and-triangle/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be DONE
- Unlocks: Story 006
