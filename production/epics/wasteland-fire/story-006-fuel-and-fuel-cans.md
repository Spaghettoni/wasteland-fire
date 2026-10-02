# Story 006: Fuel and Fuel Cans

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-02

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

- [x] AC-1: Each of the four Unit types has a Fuel capacity and a burn rate, `fuel_use` (the source's field name), in its `UnitStats`; the Gyrocopter's burn rate is the highest of the four, and the others are starting values to tune by playing.
- [x] AC-2: Fuel decreases only while the Unit moves, at its type's `fuel_use`; a Unit standing still burns nothing.
- [x] AC-3: A ground Unit at 0 Fuel cannot drive but can still turn and fire (`design/rules.md`, decided 2026-09-29).
- [x] AC-4: A Gyrocopter at 0 Fuel crashes: it is destroyed through the Unit's own `destroyed` path and counts as a destruction like any other (from story 008 on it costs a Token); it can never carry a Flag (`can_carry` is false), but the drop code path must not assume a ground Unit.
- [x] AC-5: A freshly spawned Unit starts with a fixed partial tank, a data fraction of its capacity, so dying is never a free refuel.
- [x] AC-6: Fuel Cans (the source's kanister) sit at fixed spots on the Map; touching one refills a data-defined amount and removes the Can, which respawns at the same spot after a data-defined delay.
- [x] AC-7: Each Player's HUD shows a Fuel gauge beside the hit points in the band story 004 built (16 to 76 px from the top of each 640 x 720 view, the gauge right of the hit-point bar at x 332 to 624); it visibly empties while the Unit moves, refills on a Can, and nothing clips or overflows.
- [x] AC-8: Self-destruct still works at 0 Fuel, so a stranded Player can always get a new Unit (from story 008 on, at the cost of a Token).

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

**Status**: [x] Created 2026-10-02 by `/dev-story`: ten retained frames in `production/qa/evidence/story-006-fuel-and-fuel-cans/` (the HUD with the Fuel gauge and Fuel Cans in view in frames 01 to 05) and the evidence doc `production/qa/evidence/story-006-fuel-and-fuel-cans-evidence.md`; the unit test is waived at `qa.level: minimal` and none was written.

---

## Dependencies

- Depends on: Story 005 must be DONE
- Unlocks: Story 007

---

## Completion Notes
**Completed**: 2026-10-02
**Criteria**: 8/8 passing. AC-1 to AC-8 measured on the real build (real key events through the Input Map; headless with `--fixed-fps 60` and windowed on the 120 Hz display; 49 seeded defects on scratch copies in the last headless round, 45 caught and the four survivors explained; slice probes and the engine facts the code comments cite) and observed in 10 retained screenshots. The developer confirmed at `/story-done` on their own keyboard: Yes on all four checks, no notes (the empty rules and Self-destruct at 0 Fuel, a Fuel Can's refill and return, the look of the gauge and the Cans, the feel of the starting numbers).
**Deviations**: ADVISORY only, all decided and logged in `production/session-logs/decision-log.md`. (1) The three new scenarios are over the size rule (`fuel` 340, `fuel_cans` 450, `fuel_showcase` 305 lines against about 280): accepted and recorded in TD-006. (2) The spots are the `FuelCan` instances in a new scene, `src/gameplay/maps/greybox_fuel_cans.tscn`, not `Marker3D`s in the greybox field, which is frozen with the driving toy; story 007 replaces the scene. (3) The Can polls `get_overlapping_bodies()` once per tick instead of `overlaps_body()`, and applies a two-tick touch rule (a Unit destroyed in a zone and respawned on its Base was still listed there on the next tick and took the Can from 11 m away) and a nearest-Unit choice (the engine's list order is not reproducible); both are measured, in the evidence doc. (4) `unit.gd` grew by 122 lines to 687 (TD-010 amended). (5) The runner's no-fuel data (`_apply_no_fuel_data()`) is not load-bearing today: the older outputs stay identical without it; it guards a longer run. (6) A nearly full Unit driving through a Can takes it for a small top-up (a full Motorbike from 8, 30 and 60 m gains 1.5, 3.5 and 6.0 of the 40) and the Can is gone for 20 s: the design as written, a balance question for the author.
**Test Evidence**: Logic — the unit test the story names (`tests/unit/fuel/fuel_burn_test.gd`) is waived at `qa.level: minimal` and was not written. In its place: `production/qa/evidence/story-006-fuel-and-fuel-cans-evidence.md` (every criterion measured, the measured engine facts, the review rounds, the developer's confirmations) and, in `production/qa/evidence/story-006-fuel-and-fuel-cans/`, 10 screenshots, the three scenario outputs, the windowed frame-rate runs (119.4 fps steady on the `fps` scenario, 120.0 on the showcase, at most 182 draw calls) and the probe outputs. The existing gdUnit4 suite passes (1 of 1).
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped — `qa.level` minimal. An engine, an architecture, a standards and a headless acceptance review ran inside the `/dev-story` workflow (preflight with ten corrections, two fix rounds split by area): every behaviour finding was fixed or ruled, and the last round's only open items were the script sizes, ruled and recorded in TD-006.
**Tech debt logged** (at `/dev-story`, in `docs/tech-debt-register.md`): TD-006 amended (the three scenarios, their sizes, two seeded defects the retained scenarios do not catch, the no-fuel data), TD-007 amended (the Fuel gauge's fixed text size and amber), TD-010 amended (`unit.gd` at 687 lines and how the tank could move out). Nothing new at close.
**Notes for Story 007 and 008**: (007 Map 01) `FuelCan` is a self-contained scene (`settings`, `pickup_zone`, `can_body`, the group `fuel_cans` stored in the scene) that references no controller, Round or Map: Map 01 instances it at its spots, or at `Marker3D`s, and restyles the meshes under `Body` as data. Story 007 deletes `greybox_fuel_cans.tscn`, its instance line in `split_screen.tscn` and the paragraph in `split_screen.gd`; `_restock_fuel_cans()` restocks by group, so it works with any Map. The Can's amber and the gauge's amber are close to Player 1's coming Orange (story 007 AC-11 makes the Cans red). The older scenarios were measured on the 80 m greybox composition and keep it. Fuel was tuned on that field: a fresh Gyrocopter flies about 10 s (about 164 m) and a fresh Truck drives about 182 m, so story 007 records the reach on the 300 m Map. (008 Tokens) Nothing under `src/gameplay/fuel/` mentions Tokens: the Fuel crash is `Unit.destroy()` from the Unit's own tick, so `MatchController._on_unit_destroyed()` takes the Token for it like any destruction (measured: the crash is handled exactly like a Tab press, and the controller refuses a destruction of a Unit whose Player is not ALIVE, so a scenario puts a Gyrocopter in play through the Round, never a bare `spawn()`). `Unit.fuel_changed` is emitted twice on a crash tick (the burn, then `destroy()`), harmless for a display. The HUD band's first row is full (hit points 16 to 316, Fuel 332 to 624): the Motorbike Token count joins the status row. The Flag rename touches `fuel.gd` and `fuel_cans.gd` (they preload `canister_kit.gd`) and two lines of `fuel_can.gd`'s class doc.
