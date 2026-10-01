# Story 006: Fuel and Fuel Cans

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-01

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6 — *Fuel and Fuel Cans: as before, for four Units. Every Unit burns Fuel while moving, the Gyrocopter fastest; an empty ground Unit stops but can still turn and fire; an empty Gyrocopter crashes and counts as destroyed; a fresh Unit spawns with a fixed partial tank; Fuel Cans at fixed Map spots refill and respawn; a Fuel gauge on the HUD.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [ ] AC-1: Each of the four Unit types has a Fuel capacity and a burn rate, `fuel_use` (the source's field name), in its `UnitStats`; the Gyrocopter's burn rate is the highest of the four, and the others are starting values to tune by playing.
- [ ] AC-2: Fuel decreases only while the Unit moves, at its type's `fuel_use`; a Unit standing still burns nothing.
- [ ] AC-3: A ground Unit at 0 Fuel cannot drive but can still turn and fire (`design/rules.md`, decided 2026-09-29).
- [ ] AC-4: A Gyrocopter at 0 Fuel crashes: it is destroyed through the Unit's own `destroyed` path and counts as a destruction like any other (from story 008 on it costs a Token); it can never carry a Flag (`can_carry` is false), but the drop code path must not assume a ground Unit.
- [ ] AC-5: A freshly spawned Unit starts with a fixed partial tank, a data fraction of its capacity, so dying is never a free refuel.
- [ ] AC-6: Fuel Cans (the source's kanister) sit at fixed spots on the Map; touching one refills a data-defined amount and removes the Can, which respawns at the same spot after a data-defined delay.
- [ ] AC-7: Each Player's HUD shows a Fuel gauge beside the hit points in the band story 004 built (16 to 76 px from the top of each 640 x 720 view, the gauge right of the hit-point bar at x 332 to 624); it visibly empties while the Unit moves, refills on a Can, and nothing clips or overflows.
- [ ] AC-8: Self-destruct still works at 0 Fuel, so a stranded Player can always get a new Unit (from story 008 on, at the cost of a Token).

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Fuel fields in `UnitStats` beside the existing ones: `fuel_use` (the source's name, Fuel per second while moving) plus a capacity and the spawn fraction (for example `fuel_capacity`, `spawn_fuel_fraction`); zero defaults, and every tuned value written into each type's `.tres` (the class doc says why).
- Burn in the Unit's `_physics_process` while it moves; at 0 the throttle is ignored, steering and fire are not. In story 001's model the speed is a command that a Unit pinned against a wall keeps, so say in the evidence doc what "moving" reads.
- Turning at 0 Fuel: story 001's model scales the turn with speed and does not turn at a standstill, so "can still turn" needs its own turn while the tank is empty (a rate in `UnitStats`, data), unless story 005 settled turning on the spot for every Unit.
- The Gyrocopter's crash reuses `Unit.destroy()` (story 003), called from the Unit's own tick: no second death path.
- Fuel Can: a scene with an `Area3D` and a mesh, its touches polled once per physics tick with `overlaps_body()` as the Flags' are (story 004 measured that the engine refuses a reparent or a `monitoring` change inside `body_entered`); its respawn is a physics-frame stamp like the respawn wait of story 003, not a `Timer`. The spots are `Marker3D`s in the Map (the greybox field until story 007); the amount and the respawn delay live in a `.tres`. Call it `FuelCan` and `fuel_can` in code: "canister" means the Flag there until story 008 renames it.
- HUD: extend `src/ui/hud/player_hud.tscn`; a `fuel_changed` signal mirroring `hit_points_changed` keeps it free of polling (story 004's notes).
- Keep each new scenario under about 280 lines (TD-006).
- Process (`design/rules.md`, Process rules, decided 2026-10-01): a short plan before the change; after it, say how to test it (the main scene `src/gameplay/split_screen/split_screen.tscn` and the keys that drive, fire and Self-destruct); the tracked class cache is written by the import only, never by hand.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: where the Fuel Cans and the Bases sit on Map 01 (the spots are markers the Map owns).
- Story 008: the Token a Gyrocopter's Fuel crash costs.
- Not in v0.1 (`design/rules.md`, Resources): the water boost and the key repair are the source's backlog; there is no ammo economy.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Unit test `tests/unit/fuel/fuel_burn_test.gd` covering the burn, the empty rules and the partial tank: waived at `qa.level: minimal` (advisory).
- The run-and-observe screenshot is not waived: a retained frame of a HUD with the Fuel gauge and a Fuel Can in view, in `production/qa/evidence/story-006-fuel-and-fuel-cans/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 must be DONE
- Unlocks: Story 007
