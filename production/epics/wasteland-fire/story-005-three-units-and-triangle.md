# Story 005: Four Units and the triangle

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-02

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5 — *Four Units and the triangle: Buggy, Truck and Gyrocopter beside the Motorbike, with the source's starting values (HP, DMG, speed, turn rate, flies) as data; one weapon each that fires straight ahead at one height, so turning is aiming; the damage-multiplier matrix as data: 1.5 against the Unit you beat, 0.5 against the one that beats you, 1.0 otherwise and for the Motorbike both ways; the Gyrocopter crosses cliffs and water and gains nothing else from flying; the Unit type is chosen at every spawn; the Carrier can shoot; only the Motorbike carries.*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: The Buggy, the Truck and the Gyrocopter exist beside the Motorbike, each with its own `UnitStats` `.tres` holding the starting values of the Units table in `design/rules.md` (hit points in `max_hit_points`, damage in `damage`, speed in `max_speed`, turn rate in `turn_rate` converted from the table's deg/s to rad/s, and `can_fly`, true for the Gyrocopter only; Fuel use is story 006's), and each has a distinct greybox silhouette.
- [x] AC-2: The Motorbike's data gains the source's `damage` and its 40 hit points, which replace the placeholder 100 of story 003; its speed and turn rate keep the values story 001 tuned by playing, 24 m/s and 2.8 rad/s (decided 2026-10-01), so no story 001 to 004 harness baseline changes; the other three Units take the source's starting values and are tuned relative to the Motorbike (see Implementation Notes).
- [x] AC-3: Every Unit has one weapon, fired with one key per Player (`p1_fire`, `p2_fire`), that fires straight ahead along the Unit's heading at the one shooting height all Units share, so turning is aiming; a hit applies the attacker's `damage`, times the multiplier of AC-4, to the Unit hit and never to the shooter, and the fire rate and range are data.
- [x] AC-4: Damage taken is the attacker's `damage` times the multiplier for its type against the target's type, read from one data resource: the Buggy, the Truck and the Gyrocopter deal 1.5 against the Unit they beat (Buggy against Truck, Truck against Gyrocopter, Gyrocopter against Buggy), 0.5 against the one that beats them and 1.0 against their own type, the Motorbike deals and receives 1.0 against every type, no branch in code names a Unit type, and setting every multiplier to 1.0 in the data (the fallback in `design/rules.md`) needs no code change.
- [x] AC-5: The Gyrocopter crosses cliffs and water that stop every ground Unit, shown on a greybox stand-in (one block on the cliff collision layer, one strip on the water layer); flying gives it nothing else: it fires and is hit at the same height as every Unit, by every weapon, at the matrix's multipliers; it passes through ground Units and they through it (decided 2026-10-01), so only cliffs and water tell it apart.
- [x] AC-6: At every spawn (the start of the Round, after a destruction, after a restart) the Player chooses the Unit type in their own viewport with their own keys before the Unit appears in the Garage, with every type available (the Token stock limits the choice in story 008); at the start the Unit appears as soon as it is chosen, after a destruction once it is chosen and the respawn delay has passed, whichever is later, and the other Player plays on meanwhile.
- [x] AC-7: The Carrier can shoot: a Motorbike carrying a Flag keeps its weapon; only the Motorbike carries, because `can_carry` is false in the data of the Buggy, the Truck and the Gyrocopter, so none of them ever picks up a Flag.
- [x] AC-8: Which Unit a Player drives shows in its silhouette in both views, and the HUD's hit points come from the chosen Unit's data (after a spawn as a Truck, the bar and the line read the Truck's maximum).
- [x] AC-9: Every number in this story (hit points, damage, speeds, turn rates, fire rates, ranges, multipliers, the shooting height) is a tuning value in data; the rules of `design/rules.md` are the only fixed things.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- One Unit node per Player (story 004's Completion Notes): keep ONE `Unit` per Player and swap its `stats` and its visual and collider children at each spawn, rather than freeing and re-instancing a per-type scene; `PlayerHud.unit`, `ChaseCamera.target`, both input nodes, the `SplitScreen` exports, `MatchController._units`, `CanisterRules` and a carried Flag all hold that node. `Unit.spawn()` takes the chosen `UnitStats`, and the setup `_ready()` does once today (snap length, wall angle, the saved collision layer and mask, `_can_drive`) becomes callable from it (story 003's notes). `split_screen.tscn` colours each Unit through its `Body` child's `material_override`, so a swapped visual needs the same Player body material. The source gives no acceleration, braking, coasting or reverse values: starting values are chosen here.
- The Gyrocopter: `unit.gd`'s class doc leaves this story the choice of a base class or a subclass for it; with one node per Player it is a mode of the same `Unit`, chosen by `can_fly` at spawn. It may need `MOTION_MODE_FLOATING` with its height as data, so it does not drop into water (the ground handling warns when the mode is not GROUNDED); its weapon and the shape it is hit by stay at the shared shooting height, whatever height its model is drawn at.
- Collision layers (`project.godot`: 1 map, 2 units, 3 zones, 4 canisters): add one for the Gyrocopter and one for cliffs and water; ground Units mask the cliff and water layer and the Gyrocopter does not. The Base zones (mask 2 today) also watch the Gyrocopter's layer, and `Unit.is_spot_taken()`, which queries only the Units layer today, must see it too, or a Unit is put down inside a Gyrocopter parked in its Garage. A Gyrocopter and a ground Unit never block each other (decided 2026-10-01): the Gyrocopter's layer is masked by weapons and the Base zones, not by Units, and its own mask leaves out the Units layer; the spot check above is about the spawn pose, not a collision.
- Damage from a tick: `Unit.apply_damage()` and `destroy()` are called from a physics tick, never from an `Area3D` or body signal handler (story 004's notes: the drop of a Flag reparents it, which the physics server refuses while it flushes those signals). Hitscan `RayCast3D` from the shooting height along the Unit's -Z, or a projectile `Area3D` that records its hit in `body_entered` and applies it on its own tick; the shooter is excluded, and the weapon's collision mask decides what stops a shot (the rules do not say whether walls and cliffs do).
- The matrix: one resource read through one function of (attacker type, target type), with a type id in each `UnitStats`. Superseded by `design/rules.md` (Units): the 2026-09-29 rule that only the Buggy's weapon hits the Gyrocopter, and the Motorbike-Buggy-Gyrocopter triangle, so there is no `can_hit_air` flag.
- The choice: a per-viewport `Control` under `src/ui/hud/` that shows itself on the MatchController's `round_started` and `unit_destroyed` (the controller references no UI class, its class doc), and an input node that reads the Player's keys and hands the choice to the controller, as `RoundRestartInput` does for the restart. The choice goes into `_spawn()`, the one spawn path (settle stamp, camera snap, `unit_spawned`). `begin()` and `restart()` spawn both Units at once today; they now start the Round with both Players choosing, and the respawn tick (`_try_respawn()`) spawns once the choice is made and the due frame has come. `.claude/rules/ui-code.md` asks for scalable text, colourblind modes and gamepad input, which no screen has yet (TD-007): log the new screen there rather than build them.
- The retained scenarios under `tools/evidence/split_screen/` assume both Units are in play right after `begin()`: give the harness runner one place that makes each Player's choice by a key press through the Input Map, rather than editing every scenario. Keep each new scenario under about 280 lines (TD-006).
- Keys: `p1_fire`, `p2_fire` and the choice keys are Input Map actions with the Player prefix (the source's own example is `p2_fire`); check them for ghosting against the drive keys with `tools/evidence/input_ghosting_check.tscn` (story 002). `docs/engine-reference/godot/modules/input.md` § 4.7 Changes: keyboard events carry `InputEvent.DEVICE_ID_KEYBOARD`, not 0, so read actions and never a device id.
- Story 003 AC-8: the debug keys go now that weapons exist (`debug_damage` = 0 in `match_rules.tres`, or the actions removed); the `canister_run`, `hud` and `canister_showcase` scenarios destroy the Carrier with them and move to the `self_destruct` action or `Unit.apply_damage()` (tools only, story 004's notes).
- The Motorbike's speed and turn rate: story 001 tuned 24 m/s and 2.8 rad/s (about 160 deg/s) by playing and the user confirmed the feel, so they stay (decided 2026-10-01) and every story 001 to 004 harness baseline holds. The source's starting values for it are 22 m/s and 220 deg/s; at 160 deg/s the Buggy's starting 180 deg/s would out-turn the Motorbike, so the Buggy's and the Truck's turn rates are set relative to the Motorbike's when they are tuned (the Motorbike stays the most agile).
- Turning is aiming: story 001's model turns at `turn_rate` times speed over `max_speed` and not at all at a standstill, so a Unit standing still cannot aim. Whether a Unit may turn on the spot is open for the designer; story 006 needs the same answer for a ground Unit with no Fuel.
- The Truck's bigger silhouette may fill more of the chase camera's fixed frame; camera settings per Unit belong to the camera test, deferred after v0.1 (`design/rules.md`, Camera and controls).
- TD-008: `match_controller.gd` is 560 lines, and the register schedules its split for this story, when the choice joins the tick list (the own-Base swap it also names is dropped).
- Code doc comments cite `design/rules.md` sections by names they lost on 2026-10-01 ("Destruction, respawn and unit swap" is now "Destruction and respawn"; "Handling the Water Canister" is now part of "Resources"): fix them in the files this story touches.
- `docs/engine-reference/godot/modules/physics.md` § 4.7 Changes: Jolt `Area3D`/`SoftBody3D` overlap and `WorldBoundaryShape3D.plane.d` sign notes; keep layers and masks explicit for the Gyrocopter and the ground Units.
- Process (`design/rules.md`, Process rules, decided 2026-10-01): a short plan before the change; after it, say how to test it (the main scene `src/gameplay/split_screen/split_screen.tscn` and each Player's choice, fire and Self-destruct keys); the tracked class cache is written by the import only, never by hand.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: Fuel and each Unit's burn rate (`fuel_use`), and the crash of a Gyrocopter with no Fuel.
- Story 007: Map 01 with its cliffs and water, the built-mesh models of the four Units, and the recolour to the Team colours; greybox silhouettes in today's colours are fine here.
- Story 008: the Token stock, the limits it puts on the choice, and the loss.
- Not in v0.1: the Unit swap at the own Base (dropped, decided 2026-10-01); the camera and control test (after v0.1, decided 2026-10-01).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Unit test `tests/unit/combat/combat_damage_matrix_test.gd` covering the matrix (every attacker and target pair, the Motorbike's row and column, the all-1.0 fallback) and the damage formula: waived at `qa.level: minimal` (advisory; gdUnit4 6.2.1 is installed, and the matrix is pure data behind one function, so this is the cheapest test in the epic).
- The run-and-observe screenshot is not waived: retained frames of the selection UI and of all four Units in play, in `production/qa/evidence/story-005-three-units-and-triangle/`.

**Status**: [x] Retained — `production/qa/evidence/story-005-three-units-and-triangle/` (13 screenshots: the launch with both choice panels, a moved cursor, both Units in play with their hit points, shots in flight, the damage on the bars, the respawn countdown beside the panel, the ready state, the Buggy, the Truck and the Gyrocopter in play, the Gyrocopter over the water, the Motorbike stopped at the cliff and at the water; plus the outputs of the five new scenarios, the windowed frame-rate runs and the probes under `measurements/`) and `production/qa/evidence/story-005-three-units-and-triangle-evidence.md` (every acceptance criterion measured on the real build, the engine measurements the code comments cite, the review rounds; written 2026-10-02). The unit test named above is waived at `qa.level: minimal` and was not written.

---

## Dependencies

- Depends on: Story 004 must be DONE (Complete 2026-10-01)
- Unlocks: Story 006

## Completion Notes
**Completed**: 2026-10-02
**Criteria**: 9/9 passing. AC-1 to AC-9 measured on the real build (real key events through the Input Map; headless with `--fixed-fps 60` and windowed on the 120 Hz display; 21 of 21 seeded defects caught on scratch copies; probes for the arming, the freed shots and the engine facts the code comments cite) and observed in 13 retained screenshots. The real-keyboard choose-and-fire run with both Players (AC-3, AC-6), the ghosting tool with the two new fire combinations (AC-3), the look of the four Units, the choice panel and the shots (AC-1, AC-8) and the feel of the triangle and of the Gyrocopter's crossing (AC-4, AC-5) were confirmed by the developer at `/story-done`: Yes on all four, no notes. Nothing deferred.
**Deviations**: ADVISORY only, all decided and logged in `production/session-logs/decision-log.md`. (1) The weapon's trigger is armed only after the fire key was seen up since the Unit came alive (the design said a plain level trigger): the fire key also confirms the Unit choice, and a confirm would otherwise fire a shot from the spawn pose. (2) `SplitScreen` frees every Shot at each Round start, which the design did not name: the Round-over pause froze shots in flight and `restart()` released them. (3) The harness runner restores three legacy data values (Motorbike 100 hit points, collision mask 3, debug damage 25) and re-chooses by a direct call for the scenarios written before the choice, so the twelve strict baselines stay byte-identical; they now describe test data that no longer ships (TD-006). (4) Player 2 fires with Period, not Right Shift: a bare Right Shift matches only events that carry a right location, which the harness cannot send. (5) The Shot is a projectile at 60 m/s with one ray per tick, not hitscan. (6) `PlayerChoiceInput` orders itself one priority below the controller and `MatchController.NO_CHOICE` is public; neither is named by the design. (7) Fire and confirm share one key per Player, so a fire press right after a destruction confirms the type under the cursor at once; the developer added no note, so it stays. (8) Beyond the story's file list: the README's Controls table and Status row, the epic's status row, `split_screen.gd` (the composition root, for the shot cleanup and its layout doc) and the doc comments of two Story 003 files.
**Test Evidence**: Logic — the unit test the story names (`tests/unit/combat/combat_damage_matrix_test.gd`) is waived at `qa.level: minimal` and was not written. In its place: `production/qa/evidence/story-005-three-units-and-triangle-evidence.md` (every criterion measured, all sixteen ordered pairs of the matrix through real shots, the engine facts the code comments cite, the review rounds, the developer's confirmations) and, in `production/qa/evidence/story-005-three-units-and-triangle/`, 13 screenshots, five scenario outputs, the windowed frame-rate runs and the probe outputs. The existing gdUnit4 suite passes (1 of 1).
**Code Review**: Skipped — Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped — `qa.level` minimal. An engine, an architecture and a standards review and a headless measurement ran inside the `/dev-story` workflow and raised 37 issues; a model usage limit then stopped that workflow before its windowed lens and fix rounds. The ratified fixes were applied by hand, the tools fixes finished under a byte-identical guard against 21 saved outputs, the windowed measurements made by the orchestrator, and one read-only reviewer checked the hand-made source fixes last: no behavioural finding, three doc fixes applied.
**Tech debt logged** (at `/dev-story`, in `docs/tech-debt-register.md`): TD-006 amended (the five scenarios and the helper, their sizes, eleven check functions over a rough complexity of 10, three behaviours with no retained step, the legacy data), TD-007 amended (the choice panel), TD-008 resolved (the extraction into `GarageQueue`), TD-010 added (the doc weight of the Story 005 source files).
**Notes for Story 006 and later**: (006 Fuel) New `UnitStats` fields follow the zero-default convention: a `.tres` omits values equal to the script's default, and new fields append after the Controller group. `Unit.spawn(at, stats)` is the one place a Unit's state resets (hit points today), so the fixed partial tank belongs there. The `Weapon` and `PlayerFireInput` read nothing about movement, so an empty ground Unit still fires and the turn rule stays in `Unit._physics_process()`. An empty Gyrocopter crashes through `destroy()`, which the controller already treats as a destruction. The HUD maximum comes from `hit_points_changed(hit_points, max)`, so a Fuel gauge joins `PlayerHud` the same way, by a signal up from the Unit. (007 Map) Team colours reach a Unit through `team_material`, set per Unit in `split_screen.tscn` and painted onto the meshes of each model scene's `team_colour` node group, so real models choose their painted parts by group, not by name. The greybox models are replaced by editing `UnitStats.model`. `terrain_stand_ins.tscn` (a cliff block and a water strip on the `cliffs_water` layer) stands in for the Map's cliffs and water and must keep that layer. Bases carry `spare_spawn_points`, and `Unit.is_spot_taken()` tests the chosen type's collider against its `spot_mask` (units and gyrocopters). (008 Tokens) `MatchController.choose()` is the single gate for a choice, so a type with no Tokens refuses there; `UnitChoice` lists `unit_types()` and will need a stock mark. The loss belongs in the controller's tick beside the delivery check and ends the Round through the same `round_over` path. The canister to Flag rename touches `WaterCanister`, `CanisterRules`, the controller's `canister_*` signals and members, `PlayerHud`, and the scenarios `canister_run`, `canister_showcase`, `canister_kit`, `hud` and `round_over`; the legacy runner overrides (TD-006) will need the stock data too. (Camera) The Truck is the biggest Unit; the camera test after v0.1 should weigh per-Unit camera settings. (Engine, all measured in the evidence document) A collider-changing `Unit.spawn()` on the first tick after the same Unit's teleport is thrown (a Truck flew 10 m), which is why the Garage waits `SPAWN_SETTLE_TICKS` after a bench; a mask change on a body that overlaps a cliff pushes it under the floor, so `spawn()` turns the layers off first; `Input.is_action_just_pressed` arrives one physics tick after an injected event.
