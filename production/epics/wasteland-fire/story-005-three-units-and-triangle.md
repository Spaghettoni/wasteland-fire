# Story 005: Four Units and the triangle

> **Epic**: Wasteland Fire — First Playable
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-01

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

- [ ] AC-1: The Buggy, the Truck and the Gyrocopter exist beside the Motorbike, each with its own `UnitStats` `.tres` holding the starting values of the Units table in `design/rules.md` (hit points in `max_hit_points`, damage in `damage`, speed in `max_speed`, turn rate in `turn_rate` converted from the table's deg/s to rad/s, and `can_fly`, true for the Gyrocopter only; Fuel use is story 006's), and each has a distinct greybox silhouette.
- [ ] AC-2: The Motorbike's data gains the source's `damage` and its 40 hit points, which replace the placeholder 100 of story 003; its speed and turn rate keep the values story 001 tuned by playing, 24 m/s and 2.8 rad/s (decided 2026-10-01), so no story 001 to 004 harness baseline changes; the other three Units take the source's starting values and are tuned relative to the Motorbike (see Implementation Notes).
- [ ] AC-3: Every Unit has one weapon, fired with one key per Player (`p1_fire`, `p2_fire`), that fires straight ahead along the Unit's heading at the one shooting height all Units share, so turning is aiming; a hit applies the attacker's `damage`, times the multiplier of AC-4, to the Unit hit and never to the shooter, and the fire rate and range are data.
- [ ] AC-4: Damage taken is the attacker's `damage` times the multiplier for its type against the target's type, read from one data resource: the Buggy, the Truck and the Gyrocopter deal 1.5 against the Unit they beat (Buggy against Truck, Truck against Gyrocopter, Gyrocopter against Buggy), 0.5 against the one that beats them and 1.0 against their own type, the Motorbike deals and receives 1.0 against every type, no branch in code names a Unit type, and setting every multiplier to 1.0 in the data (the fallback in `design/rules.md`) needs no code change.
- [ ] AC-5: The Gyrocopter crosses cliffs and water that stop every ground Unit, shown on a greybox stand-in (one block on the cliff collision layer, one strip on the water layer); flying gives it nothing else: it fires and is hit at the same height as every Unit, by every weapon, at the matrix's multipliers; it passes through ground Units and they through it (decided 2026-10-01), so only cliffs and water tell it apart.
- [ ] AC-6: At every spawn (the start of the Round, after a destruction, after a restart) the Player chooses the Unit type in their own viewport with their own keys before the Unit appears in the Garage, with every type available (the Token stock limits the choice in story 008); at the start the Unit appears as soon as it is chosen, after a destruction once it is chosen and the respawn delay has passed, whichever is later, and the other Player plays on meanwhile.
- [ ] AC-7: The Carrier can shoot: a Motorbike carrying a Flag keeps its weapon; only the Motorbike carries, because `can_carry` is false in the data of the Buggy, the Truck and the Gyrocopter, so none of them ever picks up a Flag.
- [ ] AC-8: Which Unit a Player drives shows in its silhouette in both views, and the HUD's hit points come from the chosen Unit's data (after a spawn as a Truck, the bar and the line read the Truck's maximum).
- [ ] AC-9: Every number in this story (hit points, damage, speeds, turn rates, fire rates, ranges, multipliers, the shooting height) is a tuning value in data; the rules of `design/rules.md` are the only fixed things.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be DONE (Complete 2026-10-01)
- Unlocks: Story 006
