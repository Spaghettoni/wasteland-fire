# Story 011: The Unit swap at the own Base

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (multi-day at `coarse`)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-04

## Context

**GDD**: `design/game-brief.md`, `design/rules.md` ("Destruction and respawn", "Tokens and the Garage")
**Requirement**: Item 2 of the author's list from the first playtest with friends (2026-10-03; `story-009-playtest-quick-fixes.md` quotes the whole list): *ked sa vratis domov mal by si si vediet vymenit vozidlo* — "back at your own Base you should be able to change your vehicle." Decided with the developer on 2026-10-03 (`design/rules.md`, Destruction and respawn): inside the own Base the Self-destruct key puts the Unit away instead of destroying it; no Token is spent, the Player picks any type with Tokens left, and it appears in the Garage at once with full hit points and the spawn tank. This brings back the swap of 2026-09-29 that was dropped for v0.1 on 2026-10-01. Decided 2026-10-03: after story 010, so the swap is judged in the new view.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From the author's playtest item 2 and the rule decided for it, scoped to this story:*

- [x] AC-1: A Player whose Unit is in play inside its own Base (the zone over the inside of the Base's walls, the Garage included) and who presses the Self-destruct key swaps instead: the Unit is put away, not destroyed (no destruction signal, no Token taken, no respawn delay), the Player is choosing at once from the types with Tokens left (the type just put away included), and the chosen Unit appears in that Player's Garage as soon as it is chosen, after the bench settle of story 005, with full hit points and the spawn tank. Every type can swap, the Gyrocopter included.
- [x] AC-2: Everywhere else the key is the Self-destruct it was (stories 003 and 008): outside its own Base, the other Player's Base included, the Unit is destroyed, a Token of its type is taken, the respawn delay runs, and the destruction of a Player's last Motorbike loses the Round. A Unit destroyed on the tick of a swap stays destroyed: the swap acts only on a Unit still in play.
- [x] AC-3: A swap takes nothing with it and decides nothing: a Motorbike that brings the other Player's Flag into its own Base delivers it and wins before any swap can happen; one that brings its own Flag home has it seated first; after a swap every Flag and every Token count is what it was before, and the other Player plays on, never paused.
- [x] AC-4: The screens follow the swap on its tick, in that Player's view only: the choice panel opens with the counts unchanged, no respawn countdown shows, and the HUD's Motorbike Tokens do not change. A ground Unit out of Fuel inside its own Base shows the hint for the swap instead of the Self-destruct ("Out of Fuel! Press Tab to swap your Unit" for Player 1, Enter for Player 2): the key does something else there, and on the last Motorbike it no longer forfeits the Round.
- [x] AC-5: Every rule of it is data: whether the own-Base swap is on (`MatchRules`), what counts as inside (each Base's zone in the Map's scenes, which now watches the gyrocopters layer as well as the units layer) and the hint's swap text (its scene, through `tr()`). The evidence scenarios written before this story, many of which Self-destruct a Unit standing in its own Garage, run with the swap off and keep their outputs.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions:*

- Putting a Unit away already exists: `GarageQueue.bench(player_index)` (`src/gameplay/match/garage_queue.gd`), which the Round start and the restart use, puts the Unit on its Base's spawn point, snaps its camera, benches it with `Unit.leave_play()` (no `destroyed`), clears the choice and makes the Player WAITING and due at once, with the bench settle stamped. The swap is that call mid-Round; its doc, which names begin() and restart() as its only callers, grows by one.
- Who decides: today `PlayerMatchInput` (`src/gameplay/match/player_match_input.gd`) calls `unit.destroy()` on the key. It should instead call down into the MatchController (signals up, calls down, as `PlayerChoiceInput` calls `choose()`), which decides: swap when the swap is on, the Round runs, the Unit is in play and inside its own Base; else destroy, as now. The input node runs at its Unit's physics priority minus one, which is also before the controller today (the Unit and the controller both keep the default 0), so the request lands in the controller's tick of the same frame; keep it so, and act on it after `_apply_deliveries()` and the reseat, so a delivery or a homecoming of the same tick comes first (AC-3). `split_screen.tscn` wires the controller into both input nodes.
- Inside the own Base: `FlagRules.is_in_own_zone(player_index)` already answers it for deliveries (`zone.overlaps_body()`). Each zone's mask is 2 (units) in `compound_base.tscn`, so it does not see a Gyrocopter (layer 16): make it 18. Deliveries do not change, because only a Carrier delivers and a Carrier is a ground Unit; the greybox `base.tscn` and its scenarios are older and run with the swap off. The zone reports a Unit one to two ticks after it drives in or out (measured in story 004), so a press on the very tick a Unit enters is a Self-destruct: record that in the evidence.
- The screens: the choice panel opens on `round_started` and `unit_destroyed` today, and the swap emits neither. Add a controller signal for it (for example `unit_swapped(player_index)`), emitted after the bench, which `UnitChoice` and `PlayerHud` listen to; the respawn countdown needs nothing, as there is no wait. The out-of-Fuel hint (`SelfDestructHint`, story 009) gains a second text format (scene data) and a controller query for "inside its own Base with the swap on"; a stranded Unit can still coast for a few ticks after its tank runs dry, so the hint re-reads that state while it is shown.
- The older scenarios (AC-5): as stories 005 to 010 did, the runner gives every scenario written before this story the swap off (on the shared `match_rules.tres` before the scene is instanced) and, if a retained output changes with the zone's mask, the old mask on the Map's zones. Capture the retained outputs before the first edit and compare after; the seeded-defect pass of story 009 is the model for the new scenario's checks.
- Stale docs to fix on the way: `base.gd` still says "Story 005 (swapping Unit type at the own Base) will" use the zone; `design/rules.md` and `CONTEXT.md` say the swap is "not built yet".
- Process (`design/rules.md`, Process rules): after the change, say how to test it (the main scene, a Unit driven home and Tab or Enter pressed inside the walls, then outside them).

---

## Out of Scope

- The camera from above: story 010.
- A swap anywhere else (at a depot, at a Fuel Can) or with a delay or a cost: not decided.
- A repair or a refuel at the Base other than the swap itself: the source's backlog (the key repair, the water boost), not v0.1.

**Questions for the author** (built as decided; ask before the story closes). **Answered at `/story-done`, 2026-10-04: both kept as built.**
1. Choosing the same type again is allowed ("any type with Tokens left"), so a trip home is a free repair and resets the tank to the spawn share: a nearly empty Unit gets fuller, a full one gets emptier. Keep it?
2. A Player can swap the moment their Unit appears in the Garage, so the choice at the start of a Round and after a respawn can be changed for free. Keep it?

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration test OR documented playtest: the integration test is waived at `qa.level: minimal`; record the evidence in `production/qa/evidence/story-011-unit-swap-at-own-base-evidence.md`: a Round with real keys where each Player swaps at home (every type at least once, the Gyrocopter included), Self-destructs outside the Base (a Token spent), swaps on the last Motorbike without losing, and brings a Flag home on the tick of a press.
- This story touches screens, so retain frames in `production/qa/evidence/story-011-unit-swap-at-own-base/`: the choice panel opened by a swap with the counts unchanged, the new Unit in the Garage, and the swap hint of a Unit stranded at home.

**Status**: [x] Created 2026-10-04 (`production/qa/evidence/story-011-unit-swap-at-own-base-evidence.md`, frames in `production/qa/evidence/story-011-unit-swap-at-own-base/`); the human checks and the two questions for the author are for `/story-done`

---

## Dependencies

- Depends on: Story 009 (Complete). Story 010 first by decision (2026-10-03), not by code: the swap does not need the new camera.
- Unlocks: the author's next playtest with both changes.


---

## Completion Notes
**Completed**: 2026-10-04
**Criteria**: 5/5 passing. AC-1 to AC-5 measured on the real build by `unit_swap` (10 checks, headless, every key a real event through the Input Map, run twice byte-identical: every type swapped by both Players, the Gyrocopter included; Self-destruct outside, in the other Player's Base and one tick before the zone reports a Unit; the last Motorbike swapped without losing and then lost outside; the key acting on the very tick of a delivery and of a homecoming; a Gyrocopter crashing on the tick of the press; the hint with each Player's key and following the Unit across its gate; the switch off, the zone masks and a refused Round) and `unit_swap_showcase` (windowed, four frames retained and read), `map_fps` (119.7 steady, 222 draw calls); 23 seeded defects, 23 caught; the 46 older outputs unchanged (44 byte-identical, 2 after exact rewrites of engine-backtrace line numbers, one new call frame and two source counts). The developer confirmed at `/story-done` ("Yes — passes" to all three): the real keyboard with both Players (the swap at home for every type, the destruction outside and in the other Base), the feel (the panel at once, the new Unit quickly, a swap and not a respawn) and the hint's wording and place. No criterion is deferred.
**Deviations**: ADVISORY only. (1) Beyond the criteria, `MatchController.begin()` refuses a Round, with the swap on, whose Base zone does not watch a Unit type's physics layer (a Map whose zone misses a layer would silently cost a Token at home); logged in the decision log. (2) `PlayerHud` is unchanged although the note said it would listen: a swap changes no Token count and no Flag status, so nothing it shows can be stale. (3) A key that acts less than 2 ticks (33 ms) after a Unit is driven or put inside its Base is still a Self-destruct, because the zone reports 2 ticks late (measured; 1 to 2 after a spawn); recorded in the evidence doc, not a defect. (4) `match_controller.gd` is 731 lines, about two thirds of the growth doc (TD-010 amended). (5) The greybox `base.tscn` zone keeps mask 2 and its scenarios run with the swap off.
**Test Evidence**: Integration: `production/qa/evidence/story-011-unit-swap-at-own-base-evidence.md` (the run result, the runs, what each criterion measured, the regression of the 46 older outputs, the 23 seeded defects and the flaws found in the checks themselves, the measured facts, the notes for the author, the human checks as confirmed) and, in `production/qa/evidence/story-011-unit-swap-at-own-base/`, five screenshots with `scenario-outputs/` and `measurements/`. The tests are waived at `qa.level: minimal`: none was written and nothing under `tests/` changed.
**Code Review**: Skipped, Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped, `qa.level` minimal. No review lens ran: the story was built directly and verified by the regression, the two scenarios and the seeded defects.
**Tech debt logged**: TD-006 and TD-010 amended with the Story 011 sizes at `/dev-story`; nothing new.
**For the author** (not blocking): (1) Both open questions are answered: the free repair and refuel by choosing the same type, and the free re-pick right after a spawn, are kept as built (recorded in `design/rules.md`). (2) The swap works anywhere the Base's zone reports the Unit: the yard and the Garage, up to the inner face of the gate walls; the gateway itself is outside. (3) The switch is `own_base_swap` in `match_rules.tres`; the hint's two texts are in `self_destruct_hint.tscn`.
**Hand-off**: all eleven stories are built. Stories 009, 010 and 011 are not committed: commit when the developer says so. Next is playing the build with friends (the author's next playtest with the camera from above and the swap), then `/create-stories` for what it shows.
