# Story 009: Playtest quick fixes

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`, `design/rules.md`
**Requirement**: The first playtest with friends, on 2026-10-03 (the author's list, in Slovak, pasted in conversation; translated):

1. *rad by som skusil pohlad viac zhora, skoro uplne zhora ale s jemnym naklonom dopredu* — try a view from higher up, almost straight down but with a slight forward tilt.
2. *ked sa vratis domov mal by si si vediet vymenit vozidlo* — back at your own Base you should be able to change your vehicle.
3. *cez velke nadrze v strede sa da prechadzat, to by nemalo byt mozne* — you can drive through the big tanks in the middle; that should not be possible.
4. *vozidla by sa mohli vediet otacat aj na mieste* — vehicles should also be able to turn on the spot.
5. *benzin by mal fungovat tak, ze ked vozidlo stoji, straca benzin pomalsie, a ked sa hybe tak rychlejsie (odlisne rates pre minanie benzinu)* — Fuel should burn slower while a vehicle stands and faster while it moves (different burn rates).
6. *Ak hracovi dosiel benzin a nemoze sa hybat, mal by sa mu ukazat hint ako urobit self destruct* — when a Player is out of Fuel and cannot move, show them a hint how to Self-destruct.
7. *gyrokoptera by mala vediet preletiet nad kamenmi v strede mapy* — the Gyrocopter should be able to fly over the rocks in the middle of the Map.

This story is items 3 to 7 (decided 2026-10-03, "quick fixes first"). Items 1 and 2 are later stories, after the author has played this one: the camera from almost straight above, and the Unit swap at the own Base (decided 2026-10-03: inside the own Base the Self-destruct key puts the Unit away instead of destroying it; no Token is spent, the Player picks any type with Tokens left, and it appears in the Garage at once with full hit points and the spawn tank). Item 7's rocks are the cover (decided 2026-10-03: the Gyrocopter flies over the wrecks, the containers and the scrap walls, and the depot's tanks still stop it).

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the author's playtest list above, items 3 to 7, scoped to this story:*

- [x] AC-1: The depot's three big Fuel tanks are solid: every Unit type, the Gyrocopter included, is stopped at a tank's side as at a wall, and every Shot ends on it; every Fuel Can of the depot is still reachable by a Truck.
- [x] AC-2: The Gyrocopter flies over Map 01's cover, the eight wrecks, the two long containers and the two scrap walls, at full speed: nothing stops or slows it there, and its model rises over each piece and settles back after it, as over the cliffs, so no part of it is drawn inside a piece. The cover still stops every ground Unit and every Shot, and the depot tanks and the Base walls still stop the Gyrocopter.
- [x] AC-3: Every Unit type turns on the spot: standing still with a steer key held it turns at its type's spot turn rate and does not move. A moving Unit never turns slower than that rate, and at speed it steers exactly as before (the turn rate scaled by the speed, flipped in reverse). A ground Unit out of Fuel still turns at its empty turn rate.
- [x] AC-4: Fuel burns at two rates: a standing Unit (its drive speed about zero) burns its type's idle rate, and a moving one its moving rate as before, which is the higher; a Gyrocopter hovering still burns its idle rate and still crashes when its tank runs dry. The starting idle rate of each type is a quarter of its moving rate, to tune by playing.
- [x] AC-5: When a Player's ground Unit runs out of Fuel, that Player's view shows a hint with that Player's own Self-destruct key, read from the Input Map ("Out of Fuel! Press Tab to Self-destruct" for Player 1, Enter for Player 2). It goes away when the Unit is refuelled, destroyed (by the Self-destruct or otherwise) or benched, and when the Round ends; it never shows for a Gyrocopter or in the other Player's view; it fits the 640 x 720 view with nothing clipped and covers no element of the HUD band.
- [x] AC-6: Every new value is data: the spot turn rate and the idle Fuel rate of each type in its UnitStats `.tres`, the cover's physics layer in the Map scene and the masks that name it in the data, the tanks' colliders in the depot scene and the hint's text in its scene (through `tr()`); no number is a constant in code. The evidence scenarios written before this story run on the data they were measured with and keep their outputs.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions:*

- The tanks (AC-1): each `FuelTank*` of `map_01_depot.tscn` is a MeshInstance3D with no collider; give each a StaticBody3D child on the map layer (1) with a CylinderShape3D as wide as the widest drawn part at the ground (the band, radius 2.56 m) and as tall as the tank (3 m). The map layer already stops every Unit type and every Shot. Check that a Truck still reaches each depot Can (`map_cover`'s depot pass drives a line through the south tank, so the new scenario passes the Cans on lines clear of the tanks).
- The cover (AC-2): a new physics layer 7, "cover" (64), named in `project.godot`; the twelve cover bodies of `map_01_cover.tscn` move to it. The ground types' masks gain it (35 to 99), so it still stops them; `MatchRules.shot_collision_mask` gains it (19 to 83), so it still stops every Shot; the Gyrocopter's mask stays the map layer alone (1), so it passes. It cannot go on the cliffs_water layer: Shots ignore that layer. The Base walls stay on the map layer.
- The rise over the cover (AC-2): `KitUnitModel` lifts the model over a collider of `rise_mask` that is drawn geometry itself (a CSG cliff) and flies over a bare body (a water channel). A cover piece is a body whose drawn part is its `Mesh` child, so a second mask, `rise_body_mask` (the cover layer), names the bodies the model rises over at the top of their GeometryInstance3D children. The water stays a bare body on `rise_mask`, untouched.
- Shots at the one shooting height (`design/rules.md` "Units"): a Shot starts inside a piece of cover when its muzzle is in it, and `Shot` tests with `hit_from_inside`, so a Gyrocopter over a piece of cover can neither shoot out of it nor be shot through it. Record it for the author; it is the existing rule that cover stops every Shot.
- Turning on the spot (AC-3): `UnitStats.spot_turn_rate` (rad/s). The yaw rate is `steer * turn_rate * speed fraction * sign(speed)` as before while `turn_rate * speed fraction` is at least `spot_turn_rate`, and `steer * spot_turn_rate` (flipped while rolling backward) below it, so the turn does not die away as a standing Unit drives off; with `spot_turn_rate` 0 the arithmetic is the old one, bit for bit. The stranded rule (`empty_turn_rate`) comes first, as before. Starting values: half of each type's `turn_rate`, the ratio `empty_turn_rate` already uses (Motorbike 1.4, Buggy 1.15, Truck 0.45, Gyrocopter 0.77), so the Buggy still out-turns the Truck.
- Idle burn (AC-4): `UnitStats.fuel_use_idle` (Fuel/s) in the Fuel group. `_burn_fuel()` picks `fuel_use_idle` while the drive speed is approximately zero and `fuel_use` otherwise; with `fuel_use_idle` 0 nothing burns at a standstill, as before. Starting values: a quarter of `fuel_use` (Motorbike 0.5, Buggy 0.625, Truck 0.75, Gyrocopter 1.25).
- The hint (AC-5): a Label scene of its own beside each Player's HUD and countdown in `split_screen.tscn` (the HUD draws its Team edge round every Control child, so a child of the HUD would join the band), display only: it listens to the Unit's `fuel_changed` and the controller's `round_over` and `round_started`, shows while the Unit is alive and stranded (a public read-only `Unit.is_stranded`) and the Round runs, and names the physical key of the action `<prefix>self_destruct` the way the choice panel names its keys. The text format is data in its scene.
- The older scenarios (AC-6): as Stories 005 to 008 did, the harness runner gives every scenario written before this story the data it was measured with: spot turn rate and idle Fuel rate 0 on the shared UnitStats, the Shot mask 19 (the `units` scenario prints it), and on Map 01 the cover back on the map layer and no colliders on the depot tanks. The drive harness gives the driving toy's Motorbike its spot turn rate 0 the same way. Capture all 38 retained outputs before the first edit and compare after.
- Process (`design/rules.md`, Process rules): after the change, say how to test it in the game (the main scene, a Gyrocopter over the containers, a Unit against a depot tank, a standing Unit turning, a ground Unit run dry to see the hint).

---

## Out of Scope

- The camera from almost straight above (item 1) and the Unit swap at the own Base (item 2): later stories, after the author has played this one (decided 2026-10-03).
- Tuning: the spot turn rates, the idle Fuel rates and the tank colliders' size are starting values to tune by playing.
- A different hint on the last Motorbike, where a Self-destruct forfeits the Round (`design/rules.md`): a question for the author.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: the integration test is waived at `qa.level: minimal`; record the evidence in `production/qa/evidence/story-009-playtest-quick-fixes-evidence.md`.
- Screenshots are not waived; this story touches a screen (the hint) and the Gyrocopter's look over the cover, so retain frames of the hint in a Player's view, the Gyrocopter over a container and a Unit stopped at a depot tank, in `production/qa/evidence/story-009-playtest-quick-fixes/`.

**Status**: [x] Created 2026-10-03 — `production/qa/evidence/story-009-playtest-quick-fixes-evidence.md` holds the run result, the playtest note (a scripted Round with real keys through every state of the hint), what each criterion measured, the regression of the 38 older outputs, 22 seeded defects (all caught) and the human checks; the retained frames are in `production/qa/evidence/story-009-playtest-quick-fixes/` (the hint in both views: 05, 06; the Gyrocopter over a container: 01; Units stopped at the depot tanks: 02; turning on the spot: 03, 04; the launch: 00). The integration test is waived at `qa.level: minimal`: none was written.

---

## Dependencies

- Depends on: Story 008 (Complete).
- Unlocks: the author's next play of the build; then the camera story and the swap story.

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 6/6 passing. AC-1 to AC-5 measured on the real build by the six evidence scenarios under `tools/evidence/split_screen/` (`depot_tanks`, `gyro_cover`, `spot_turn`, `idle_burn`, `fuel_hint`, `quick_fixes_showcase`: real key events through the Input Map, headless with `--fixed-fps 60`, each run twice byte-identical; every check shown to fail under at least one of 22 seeded defects, 22 caught) and by retained frames 00 to 06 from a windowed recording, which `/story-done` opened and read. AC-6: every new value is in a `.tres` or a scene; the added code holds no numeric literal other than 0 and 1 (two `@export_range` lines carry editor bounds); the hint's text is scene data read through `tr()`; the 38 retained outputs of Stories 001 to 008 are identical to their baselines at `ad5bb45` (37 raw, `tokens_data` after two exact rewrites for the hint script's line in its lint). The developer confirmed at `/story-done`: Yes on the depot tanks (AC-1), Yes on the Gyrocopter over the cover (AC-2), Yes on turning on the spot and the slower standing burn (AC-3, AC-4), Yes on the out-of-Fuel hint (AC-5).
**Deviations**: ADVISORY only. (1) Reversing turns faster than before: the two clauses of AC-3 meet in reverse (no type reverses fast enough for its speed-scaled turn to pass its spot rate, so the floor wins there); the Implementation Notes' rule was followed and the author is told below. (2) The scenarios written before the story run on the data and the Map they were measured with (`_apply_pre_009_data()` and `_apply_pre_009_map()` in the runner), as Stories 005 to 008 did, so the retained older Map 01 scenarios no longer exercise the shipped cover, tanks or masks; the six new scenarios do. (3) Files touched beyond the notes' list: `shot.gd` and `match_rules.gd` (doc comments of the mask only), the shared docs the process rule names (`design/rules.md`, `CONTEXT.md`, `design/game-brief.md`, `README.md`, the epic, `tests/smoke/critical-paths.md`, the debt register), the class cache and eight `.uid` sidecars written by the import.
**Test Evidence**: Integration: `production/qa/evidence/story-009-playtest-quick-fixes-evidence.md` (the run result, the scripted Round with real keys through every state of the hint, what each criterion measured, the regression of the 38 older outputs, the 22 seeded defects, the measured facts the code comments cite, the human checks as confirmed) and, in `production/qa/evidence/story-009-playtest-quick-fixes/`, seven screenshots with `scenario-outputs/` and `measurements/`. The integration test is waived at `qa.level: minimal`: none was written and nothing under `tests/` changed.
**Code Review**: Skipped, Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped, `qa.level` minimal. No separate review lens ran inside `/dev-story`: the story was built directly and verified by the regression, the six scenarios and the seeded defects.
**Tech debt logged** (at `/dev-story`, in `docs/tech-debt-register.md`): TD-011 new (the key-name code in three screens), TD-006 amended (six scenarios and a helper; `gyro_cover.gd` is 400 lines, over the 280-line guideline), TD-010 amended (`unit.gd` is 761 lines). Nothing new at close.
**Hand-off**: the Windows build `builds/WastelandFire-windows-2026-10-03-playtest-fixes.zip` (gitignored, 37.7 MiB, SHA-256 `2ed178f2b4f5246e571f25f0491aa1ad3701f00acbd1554e1810346142372d91`), over the 30 MiB chat limit and untested on a real Windows PC. Next, as decided 2026-10-03: the camera from almost straight above (item 1) and the Unit swap at the own Base (item 2: inside the own Base the Self-destruct key puts the Unit away for free, then the Player picks any type with Tokens left).
**For the author** (not blocking): (1) Reversing now turns at the spot rate, faster than before; say if the old reverse feel should come back. (2) A Gyrocopter over a piece of cover can neither shoot out of it nor be shot through it (every Unit shoots at one height and the cover stops every Shot). (3) The hint on the last Motorbike still says Self-destruct, which forfeits the Round there. (4) The spot turn rates (half of each turn rate), the standing Fuel rates (a quarter of each moving rate) and the tank collider (the band's radius, the tank's height) are starting values to tune by playing. (5) One Jolt warning ("job system exceeded the maximum number of jobs") appeared once under load in one regression run (`loss` T24); two reruns were clean.
