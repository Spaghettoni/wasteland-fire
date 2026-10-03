# Story 008: Tokens, the Garage and the loss

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-03

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 8 — *Tokens, the Garage and the loss: the per-Map Token stock; minus one per destruction, Self-destruct and Fuel crash included; the choice from the remaining stock at the start and after every destruction while the game keeps running; the chosen Unit appears in the Garage; the loss when the last Motorbike is gone; the Round-over screen naming the win or the loss. The code renames the Water Canister to the Flag here (WaterCanister, canister_rules, canister_\*).*

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md` (the **Player goal & fail state** field + the MVP feature this story implements), scoped to this story:*

- [x] AC-1: Each Player starts the Round with a Token stock, one count per Unit type, copied from the Map's data; Map 01 gives both Players the source's example, Motorbike 5, Buggy 3, Truck 2, Gyrocopter 2, as starting values to tune by playing; `begin()` refuses a stock with no Motorbike Token with one error that names it (`design/rules.md`, Tokens and the Garage: a Map gives every Player at least 1).
- [x] AC-2: A destroyed Unit costs its Player one Token of its type, taken at the destruction and never at the spawn, so the Unit in play is not yet subtracted; enemy fire, a Self-destruct and, once story 006 exists, a Gyrocopter's Fuel crash all count.
- [x] AC-3: At the start of the Round and after every destruction the Player chooses the next Unit in their own viewport from the remaining stock: the choice shows each type's count, and a type with 0 Tokens left cannot be chosen, through the UI or by any key; the Unit appears in that Player's Garage at their Base, at the start as soon as it is chosen and after a destruction once it is chosen and the respawn delay has passed, whichever is later (decided 2026-10-01: the choice may be made during the countdown), while the other Player plays on.
- [x] AC-4: The destruction that leaves a Player with 0 Motorbike Tokens ends the Round: that Player loses and the opponent wins. When both Players lose their last Motorbike on the same tick, the Round ends with no winner (`design/rules.md`, Destruction and respawn, a reading of the source).
- [x] AC-5: Nothing else ends a Round: the win by delivering the opponent's Flag (story 004) and the loss of AC-4 are the only ends; a type running out of Tokens, and a Self-destruct or a Fuel crash that does not spend the last Motorbike Token, end nothing.
- [x] AC-6: Each Player's HUD shows at least that Player's remaining Motorbike Tokens, updated on the tick of every destruction and at a restart, inside the HUD band, with nothing clipped or overflowing in the 640 x 720 view.
- [x] AC-7: The Round-over screen names the winner in both views whichever way the Round ended, and says that nobody won after the double loss of AC-4; R (the `round_restart` action) restarts the Round with both stocks full again, both Flags at home and both Players choosing, each Unit appearing in its Garage as soon as it is chosen.
- [x] AC-8: The code takes the Flag's name here, with the end-of-Round logic (decided 2026-10-01): `WaterCanister`, `CanisterRules` and `canister_rules.gd`, the controller's `canister_*` signals and members, the Base's canister exports, the `canisters` physics layer, the HUD's three status texts and the evidence scenarios named for the canister are renamed for the Flag; no player-facing text or code name calls the Flag a canister; every retained scenario under `tools/evidence/` is re-run after the rename and passes.
- [x] AC-9: Every count and delay in this story is data: the Token counts in the Map scene (in `GreyboxField` until story 007 builds Map 01) and the respawn delay in `MatchRules`; no count is a constant in code, and the rules of `design/rules.md` are the only fixed things.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers into the pinned engine reference, not decisions:*

- The MatchController owns the stock and the loss, signals up and calls down (story 004's Completion Notes). It copies the Map's counts into one array per Player at `begin()` and again at `restart()`, and never writes to the shared resource, as with `MatchRules`. `_on_unit_destroyed()` takes the Token after it drops a carried Flag and before `unit_destroyed` goes out, so every listener already reads the new count. The loss check runs in the controller's tick, after `_apply_deliveries()`: a Player with no Motorbike Token left sets the Round OVER with the other Player as the winner, both at once leave `NO_WINNER`, and the tick's existing end (the pause, then `round_over`) announces it. The class doc's Round state table (RUNNING to OVER) gains both rows, and `winner_index()` its no-winner case.
- The choice: story 005's choice UI and its input node read the counts from the controller (a read-only query per Player and type) when `round_started` and `unit_destroyed` arrive, and hide on `round_over`, so a Player who has just lost is not left choosing under the Round-over screen. The chosen type goes into `_spawn()`, the one spawn path, which refuses a type with 0 Tokens itself, so a key press the UI did not stop spawns nothing.
- Which type's last Token ends the Round is the Motorbike's; read it from data (the type with `can_carry`, the reason the rules give for the loss) rather than naming the Motorbike in code, as story 005 keeps type names out of the matrix.
- The stock as data: one resource (for example `TokenStock`, one count per Unit type keyed by the type id story 005 adds to `UnitStats`) exported by the Map scene and handed to `begin()` by `SplitScreen`, the composition root that already hands over the Bases. Until story 007 builds Map 01, `GreyboxField` exports it. A scenario that needs the loss quickly can load a stock with 1 Motorbike Token rather than spend 5.
- The HUD: after story 006 the band holds the hit-point bar (x 16 to 316), the Fuel gauge (x 332 to 624) and the status line (y 46 to 76); the Motorbike count joins it without pushing anything below about 90 px, the limit `player_hud.gd`'s class doc keeps for the middle of the view. The count changes only at a destruction and at a restart, so the HUD reads it again on `unit_destroyed` and `round_started`: no polling and no new signal.
- The Round-over screen: `round_over(winner_index)` stays, and the winner line already names the winning Player whichever way the Round ended. `_show_winner()` formats `winner_index + 1`, so `NO_WINNER` (-1) would read "Player 0 wins!": the double loss needs its own line, a format stored in `round_over_screen.tscn` like the other two. The screen's class doc says "when a delivery wins"; it now says "when the Round ends".
- The rename: `WaterCanister` (`src/gameplay/canister/water_canister.*`) becomes the Flag's class and scene (for example `Flag`), `CanisterRules` its rules helper (for example `FlagRules`), and the controller's `canister_picked_up`, `canister_dropped`, `canister_seated`, `canister_status()` and `CanisterStatus`, the Base's `canister` and `canister_seat`, the HUD's `CanisterStatusLabel` and its three texts in `player_hud.tscn`, the name of physics layer 4 in `project.godot` and the scenarios `canister_kit`, `canister_run` and `canister_showcase` under `tools/evidence/split_screen/`, with the harness runner's table, follow. Move each script with its `.uid` file so the scenes' references hold; the tracked class cache is rewritten by the import (`godot --headless --path . --import`, `docs/engine-reference/godot/current-best-practices.md`), never by hand. The Fuel Can stays `FuelCan` (story 006).
- Story 004's retained outputs under `production/qa/evidence/story-004-water-canister-and-win/` are that story's record and stay as they are; the outputs of the re-run after the rename go into this story's evidence folder. Doc comments that cite CONTEXT.md's "Water Canister" change with the files they sit in; references to the story 004 file name stay.
- TD-008: if `match_controller.gd` is still over 500 lines after story 005's split, the stock and the loss go into a small helper beside the Flag rules, with the class-doc state tables kept. Keep each new scenario under about 280 lines (TD-006).
- Process (`design/rules.md`, Process rules, decided 2026-10-01): a short plan before the change; after it, say how to test it (the main scene `src/gameplay/split_screen/split_screen.tscn`, each Player's choice keys, the Self-destruct keys to spend Motorbike Tokens, R to restart); the tracked class cache is written by the import only, never by hand.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: Map 01 itself; this story reads the stock the Map holds.
- Not in v0.1 (`design/game-brief.md`, Out of scope): hazards, bots, a score or a series across Rounds (the source plays one match), menus beyond the Round-over screen.
- The camera and control test, and the arrow to the own Base or the north-up minimap it may call for: after v0.1 (decided 2026-10-01).
- The Unit swap at the own Base: dropped (decided 2026-10-01).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: the integration test is waived at `qa.level: minimal`; record a playtest note in `production/qa/evidence/story-008-tokens-garage-and-loss-evidence.md` with one Round lost by the last Motorbike and one Round won by a delivery.
- Screenshots are not waived; this story touches screens, so retain frames of the choice UI with its counts, the Round-over screen after a loss, and both views after the restart, in `production/qa/evidence/story-008-tokens-garage-and-loss/`.

**Status**: [x] Created 2026-10-03 — `production/qa/evidence/story-008-tokens-garage-and-loss-evidence.md` holds the playtest note (Round A lost by the last Motorbike, Round B won by a delivery, Round C lost by both Players at once), the run result and the measurements of the seven evidence scenarios under `tools/evidence/split_screen/` (`tokens`, `tokens_data`, `token_choice`, `loss`, `token_ui`, `token_layout`, `tokens_showcase`); the retained frames are in `production/qa/evidence/story-008-tokens-garage-and-loss/` (the choice UI with its counts: 01, 02, 04, 05, 15; the Round-over screens: 08, 10, 13; both views after the restart: 09, 11, 14; the HUD's Motorbike Tokens: 01, 06, 07, 16). The integration test is waived at `qa.level: minimal`: none was written.

---

## Dependencies

- Depends on: Story 007 must be DONE. If Map 01 is late, Story 005 DONE is enough: the stock sits in `GreyboxField` until story 007 moves it into Map 01, and a Gyrocopter's Fuel crash costs its Token through the same `destroyed` path whenever story 006 lands.
- Unlocks: the v0.1 playtest (the First Playable is complete)

---

## Completion Notes
**Completed**: 2026-10-03
**Criteria**: 9/9 passing. AC-1 to AC-9 measured on the real build by the seven evidence scenarios under `tools/evidence/split_screen/` (`tokens`, `tokens_data`, `token_choice`, `loss`, `token_ui`, `token_layout`, `tokens_showcase`: real key events through the Input Map, headless with `--fixed-fps 60`, each run twice byte-identical; every check shown to fail under at least one seeded defect it names, roughly 350 defects on scratch copies across the build slices plus 84 seeded defects, a 425-mutant run and a 142-check independent probe by the acceptance lens) and by 16 retained frames from windowed recordings (launch, and the three-Round `tokens_showcase`). The developer confirmed at `/story-done`: Yes on the screens (AC-3 and AC-6: a count under every type, the dimmed `x0` type, the skipping cursor, the HUD's Motorbike count), Yes on the loss by the last Motorbike with nothing else ending a Round (AC-2, AC-4, AC-5), Yes on the double loss, "Nobody wins!" and the restart (AC-4, AC-7), and Yes on the delivery and the Flag's name (AC-5, AC-7, AC-8).
**Deviations**: ADVISORY only, all decided and logged in `production/session-logs/decision-log.md`. (1) No 0-Token refusal in the spawn path, which the Implementation Notes asked for: a Player with no Unit in play cannot lose a Token and `choose()` refuses an empty type, so the branch was unreachable and untestable, and it could only have cleared the choice without a signal; `MatchController.choose()` is the single guard of AC-3, proved through every key and by direct calls (`token_choice` T13, `loss` T18). (2) `begin()` refuses more than the missing Motorbike Token the story names: an unknown stock key, a duplicate or empty type id, a negative count, no stock, and anything but exactly one Unit type that can carry the Flag, each with one error that names the problem (`tokens_data` T03, T04). (3) Files touched beyond the story's list: `map_layout.gd` (two lines: it reads Map 01's own stock), `choice.gd` (the one path line for the moved NameLabel), four stale doc comments (`respawn_countdown.gd`, `round_restart_input.gd`, `garage_queue.gd`, `damage_matrix.gd`) and `tests/smoke/critical-paths.md`. (4) The choice cursor is kept across a restart as Story 005 decided and now also snaps off a spent type, so after a Round lost by the last Motorbike the loser's cursor starts the next Round on another type (frames 09 and 14 of the evidence): left for the author.
**Test Evidence**: Integration: `production/qa/evidence/story-008-tokens-garage-and-loss-evidence.md` (the playtest note with one Round lost by the last Motorbike, one won by a delivery and one lost by both; every criterion measured; the measured engine facts the code comments cite; the review rounds; the human checks) and, in `production/qa/evidence/story-008-tokens-garage-and-loss/`, 16 screenshots, with `scenario-outputs/` and `measurements/` (the preflight logs and pictures, the slice reports, the normalizers). The integration test is waived at `qa.level: minimal`: none was written and nothing under `tests/` changed. The 31 retained outputs (Stories 001 to 007) are identical to their baselines after the rename mapping, 28 raw and 3 through exact rewrites (`choice`, `fuel_cans`, `hud`: the count line, the narrowed status label and the Tokens label).
**Code Review**: Skipped, Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped, `qa.level` minimal. Inside the `/dev-story` runs: an engine and design preflight (14 design issues and a 37-test matrix folded into the design before any code), six build slices each with an independent verifier, then engine, architecture and standards, and headless-acceptance review lenses and one fix round; the lenses found no behaviour defect in `src/`, and every finding (stale class docs, rename leftovers, five holes where a seeded defect survived) was fixed or ruled.
**Tech debt logged** (at `/dev-story`, in `docs/tech-debt-register.md`): TD-006 amended (seven scenarios and six helpers, 13,661 lines in 58 scripts, the thirteen functions over a complexity of 10), TD-007 amended (three new texts, the 300 px status label), TD-008 amended (its 480-line figure is superseded: `match_controller.gd` is 629 lines with the ledger in its own 201-line file), TD-010 amended (the doc dedupe between `garage_queue.gd` and `match_controller.gd` was not paid; moved to Backlog). Nothing new at close.
**Hand-off**: this closes the First Playable (stories 001 to 008). The Windows builds are gitignored in `builds/`: `WastelandFire-windows-2026-10-03.zip` (the story-007 state) and `WastelandFire-windows-2026-10-03-first-playable.zip` (this state, 37.7 MiB, SHA-256 `00ff0cec140360600ac99617243ff42a10974ac0c1242c1a324ba5a25feee050`), both over the 30 MiB chat limit and untested on a real Windows PC. The next thing the project needs is the v0.1 playtest with a friend.
**For the author** (not blocking): (1) Reset the choice cursor at a restart? One line in `PlayerChoiceInput`, but it changes what the retained `choice` scenario asserts after a restart. (2) The centred Round-over panel covers a Unit in the middle of the view. (3) A loss ends the Round at once with the wreck still on screen; a short hold before the panel would be a design change. (4) Map 01's 5 / 3 / 2 / 2 are the source's example and starting values to tune by playing. (5) `R` pressed in the loss tick restarts inside that tick and the winner can be a Player whose own Unit is destroyed (both recorded in the evidence doc).
