# Story 004: Water Canister and the win

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-01

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4 — *Water Canister and the win: one canister per Base; only a Motorbike picks it up, by touching it; it drops where the Carrier is destroyed and never returns home on its own; a Player may carry their own canister back; delivering the opponent's canister to your own Base ends the Round. Per-Player HUD (hit points, canister status) and a Round-over screen with restart.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: At Round start each Base holds one visible Water Canister in its Player's colour.
- [x] AC-2: A Motorbike that touches a canister picks it up; the canister visibly rides on the Unit, which is now the Carrier. Pick-up is gated by a per-Unit `can_carry` flag in the Unit's data (true only for the Motorbike), not by a type check in code.
- [x] AC-3: When the Carrier is destroyed, the canister drops at that spot and stays there; it never returns to its Base on its own.
- [x] AC-4: A Player may pick up their own dropped canister and carry it back; entering their own Base with it re-seats it at the Base.
- [x] AC-5: The Round ends the moment a Carrier holding the opponent's canister enters their own Base zone; the win is decided by delivery, nothing else (the goal and fail state of the brief).
- [x] AC-6: A Round-over screen names the winning Player and offers restart on a key; restart resets both Units to their Bases, both canisters to their Bases, hit points and the HUD, and starts a new Round.
- [x] AC-7: Each viewport has a HUD showing that Player's hit points and canister status: carrying the opponent's canister / own canister at home / own canister away (stolen or dropped).
- [x] AC-8: All text and elements of the HUD and the Round-over screen fit inside a 640×720 viewport with no clipping or overflow.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- Canister = scene with `Area3D` + mesh; `body_entered` → if the body's stats say `can_carry`, attach (reparent to a mount `Marker3D` on the Unit); on the Carrier's `destroyed` signal, detach at the Carrier's global position.
- Base `Area3D` `body_entered`: if the body carries the opponent's canister → match controller `round_over(winner)`; if it carries its own → re-seat.
- Round state machine in the match controller (Running → Over); the Round-over screen and HUD listen to its signals — no polling.
- HUD per viewport: a `CanvasLayer`/`Control` inside each `SubViewport`; the project uses `canvas_items` / `expand` stretch (`project.godot`), so lay out with anchors, test at 640×720 per half.
- `docs/engine-reference/godot/modules/ui.md` § 4.7 Changes: `Control.custom_maximum_size` and offset transforms exist if HUD animation is wanted; accessibility calls moved to `AccessibilityServer`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: weapons — "the Carrier can shoot" is verified there; only-Motorbike-carries is enforced here by data and exercised there once other Units exist.
- Story 006: the Fuel gauge on the HUD.
- Story 007: the real arena; Bases stay greybox.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: waived at `qa.level: minimal` — record one full canister run (steal, drop, recover, deliver) as a playtest note in `production/qa/evidence/story-004-water-canister-and-win-evidence.md`.
- Screenshots are not waived; this story touches screens, so retain a frame of each: both HUDs during play, a carry state, the Round-over screen — in `production/qa/evidence/story-004-water-canister-and-win/`.

**Status**: [x] Retained — `production/qa/evidence/story-004-water-canister-and-win/` (9 screenshots: the launch, both HUDs, the carry state, the drop, the dropped canister, the recovery, the re-seat, the Round-over screen, the reset; plus the showcase recording output and the canister_run, hud and round_over outputs) and `production/qa/evidence/story-004-water-canister-and-win-evidence.md` (the playtest note: steal, drop, recover, deliver, with every acceptance criterion measured on the real build, written 2026-10-01)

---

## Dependencies

- Depends on: Story 003 must be DONE
- Unlocks: Story 005 (and the vertical-slice playtest: two Motorbikes, two Bases, one canister run)

---

## Completion Notes
**Completed**: 2026-10-01
**Criteria**: 8/8 passing. AC-1 to AC-8 measured on the real build (real key events through the Input Map, headless and windowed on the 120 Hz display, plus mutation testing on scratch copies: 17 of 18 seeded defects caught by the retained scenarios) and observed in 9 retained screenshots; the real-keyboard canister run (AC-2 to AC-5), the Round-over screen and the R restart (AC-6), the readability of both HUDs (AC-7, AC-8) and the look of the canister in its colour and on the Unit's tail (AC-1, AC-2) confirmed by the developer at `/story-done`. Nothing deferred.
**Deviations**: ADVISORY only. (1) Pick-ups and deliveries are polled by `MatchController` once per physics tick with `overlaps_body()`, not driven from `body_entered` as the Implementation Notes suggest: the engine refuses to reparent a node holding an Area3D, or to assign `monitoring`, inside that callback (measured), and the notes' pattern left the canister CARRIED with monitoring on. The canister is a dumb actor the controller drives, and there is no mount `Marker3D` on the Unit (`motorbike.tscn` is a frozen Story 001 file): the ride is data, `can_carry` and `carry_offset` in `UnitStats`. (2) Spawn settle rule: after `Unit.spawn()` the physics server reports a one-tick ghost overlap at the Unit's old place (measured: a respawned Carrier re-touched its own dropped canister 10 m away), so the controller skips a freshly spawned Player's pick-ups and deliveries for `SPAWN_SETTLE_TICKS` = 3 physics frames, a documented engine-latency constant and not a `MatchRules` value; it is the one non-trivial numeric literal in the added code, and the stamp is pushed on across a tree pause like the respawn waits. (3) `carry_offset` is (0, 0.5, 1.7), a tail mount: the body-top mount first designed hid 73% of the Unit's cream nose (the facing cue) from the chase camera. (4) The win pauses the tree and `restart()` unpauses it (a Round reset, not a scene reload); `RoundRestartInput` and the two `RoundOverScreen`s are the only `ALWAYS` nodes, and the harness runner stays `INHERIT` (an `ALWAYS` runner would unfreeze the whole game). (5) Rules the story left open, decided: two deliveries on one tick go to the lower Player index, as a pick-up tie does; an enemy canister dropped inside the Player's own Base zone is picked up and delivered on the same tick, so touching it wins. (6) `round_over` keeps the name the story and design give it although `project.yaml` asks for past-tense signals; the named constants (`NO_WINNER`, `CanisterRules.NONE`, `RoundRestartInput.ACTION_RESTART`), the `CanisterRules` helper and its small API, the Cargo inspector group and `drop_at(at)` (not `position`, which would shadow `Node3D.position`) are accepted implementation detail (decision log, 2026-10-01). (7) `.claude/rules/ui-code.md` asks for gamepad input, scalable text, colourblind modes and a localization system: none built (the game is keyboard-only, `tr()` returns the stored text, no settings system exists): TD-007. (8) Story 001 to 003 files were extended on purpose (`unit.gd`, `unit_stats.gd`, `motorbike_stats.tres`, `base.*`, `match_controller.gd`, `respawn_countdown.gd`, `split_screen.*`, `project.godot`, the harness runner's table and header); Unit movement is unchanged, the eleven frozen files are byte-identical and all twelve pre-story harness outputs are byte-identical. (9) Sizes: `match_controller.gd` is 560 lines against the design's 450 (about 300 of them doc; the carry bookkeeping already sits in `canister_rules.gd`): TD-008; the four new scenarios are 246 to 274 lines against the run's 250 (TD-006 allows 280); a Unit carrying at most one canister has no retained scenario step (TD-006 amended).
**Test Evidence**: Integration — playtest note at `production/qa/evidence/story-004-water-canister-and-win-evidence.md` (one full run: steal, drop, recover, deliver; every acceptance criterion measured; the engine measurements the code comments cite) and 9 retained screenshots plus 4 scenario outputs in `production/qa/evidence/story-004-water-canister-and-win/` (frame 03 the carry state, frame 08 the Round-over screen). Integration test waived at `qa.level: minimal`; none written.
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped — `qa.level` minimal. A GDScript-specialist engine review, a Godot-specialist architecture review and a lead-programmer standards review, plus a headless and a windowed measurement lens, ran inside the `/dev-story` workflow three times with two fix rounds (23 agents). The engine and headless lenses ended clean; the last findings of the others were applied by hand (the helper reads the controller's arrays by reference, the settle stamp pushed across a pause, a doc line per scenario constant, the showcase frame counter, two stale doc sentences) or accepted with a record (sizes, public names, the recording caveat).
**Tech debt logged**: TD-006 amended (the four Story 004 scenarios; the one-canister rule with no retained step), TD-007 amended (gamepad restart and localization), TD-008 (`match_controller.gd` at 560 lines), TD-009 (windowed recording caveats: focus loss and a sleeping display) in `docs/tech-debt-register.md`.
**Notes for Story 005 and later**: Keep ONE Unit node per Player and swap its `stats` (and the visual and collider children) rather than freeing and re-instancing a per-type scene: `PlayerHud.unit`, `ChaseCamera.target`, both input nodes, the `SplitScreen` exports, `MatchController._units`, `CanisterRules` (which now shares the controller's array) and a carried canister all hold the node. `Unit.apply_damage()` and `destroy()` must be called from a physics tick, never from an Area3D or body signal handler: the Round's handler of `destroyed` reparents the canister a Carrier held, and the physics server refuses that while it flushes those signals (a projectile records its hit in `body_entered` and applies it on its own tick). The Unit-type swap at the own Base must be a controller rule ordered after `_apply_deliveries()`, never a `Base.zone` signal handler (by then a Carrier's canister is re-seated or has won; `CanisterRules.drop(player_index)` exists for the defensive case); `can_carry` and `carry_offset` are read live from the Unit's `stats`, so a Unit type with `can_carry = false` never picks up; a Gyrocopter on its own physics layer must be added to the Base zone's mask for the swap, not to the canister's `PickupZone`. `_spawn()` is the one spawn path (settle stamp, camera snap, `unit_spawned`) and the place for the type choice. `hit_points_changed(hit_points, max_hit_points)` fires once per event (damage, `destroy()`, `spawn()`), so the HUD needs no polling. When the debug keys go (`debug_damage` = 0), the `canister_run`, `hud` and `canister_showcase` scenarios destroy the Carrier with them and must switch to the `self_destruct` action or `Unit.apply_damage()`: a tools-only change. Story 006: the HUD band is 16 to 76 px and a fuel bar fits right of the hit-point bar (x 332 to 624); a `fuel_changed` signal mirroring `hit_points_changed` is the path. Story 007: a Map must expose two Bases (they bring `canister`, `canister_seat`, `zone` and the spawn points); `SplitScreen.field` is typed `GreyboxField`, so a new Map keeps that class or `SplitScreen` retypes one export; TD-005 is paid there. Until weapons exist the only way to stop a thief is to body-block them: whether to pull a minimal weapon forward before the sofa playtest is the developer's call.

## v0.1 note (2026-10-01)

The author's artifact is now at version 0.1 (`design/source/`; rules of record `design/rules.md`). The Water Canister of this story is the Flag (vlajka) of v0.1 in every design document and story; the code keeps its names (`WaterCanister`, `canister_rules`, `canister_*`) until story 008 renames them with the end-of-Round logic (decided 2026-10-01). The loss condition, a Player who loses their last Motorbike loses the Round, arrives with story 008; until then AC-5's "the win is decided by delivery, nothing else" describes the build. The Player colours blue and red become the Team colours Orange and Teal in story 007, and the own-Base Unit swap that the Completion Notes prepare for is dropped in v0.1 (decided 2026-10-01). The built behaviour stands and the story stays Complete.
