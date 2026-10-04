# Story 011 — The Unit swap at the own Base: test evidence

**Story:** `production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md` · **Type:** Integration (touches screens) · **Layer:** Core · **Estimate:** M
**Engine:** Godot 4.7.2.stable.official.ed1daf0bf, Jolt Physics, Forward+ (Metal 4.0), 60 physics ticks/s
**Machine:** macOS (Darwin 25.5.0) arm64, Apple M4 Pro, 120 Hz built-in display · **Date:** 2026-10-04 · **Run by:** the implementing session directly (no workflow, as the usage-quota note asks), in a fresh session after story 010
**Gate level:** Integration: an integration test or a documented playtest, and this story touches screens, so retained frames. Tests are waived at `qa.level: minimal`; none was written for `tests/` and nothing under it changed. The evidence is the scenario `unit_swap` (ten checks, real keys through the Input Map), the windowed `unit_swap_showcase` (four frames, all read), 46 older outputs compared with baselines captured before the first edit, 23 seeded defects, and the human checks at the end.

## Run result

`Run result: OBSERVED — the main scene (godot --path . --windowed --resolution 1280x720, recorded with --write-movie --quit-after 90) opens Map 01 with both Players choosing, as before the story (00); the windowed recording of unit_swap_showcase on the shipped data shows both Units in their Garages (01), Player 1's choice panel open after a swap with the counts x5 x3 x2 x2 and "Motorbike Tokens: 5" unchanged while Player 2's Motorbike drives on and its view shows no panel (02), the new Buggy in the Garage at 100 / 100 hit points (03) and the two hints, "Out of Fuel! Press Tab to swap your Unit" for a Buggy stranded in its own Base and "Out of Fuel! Press Enter to Self-destruct" for a Motorbike stranded outside its own (04).`

The feel half (how soon the panel opens after the key, how soon the new Unit appears) is for the human checks below; a still cannot show it.

## The runs

- **Launch** (`commands.run` plus `--write-movie --quit-after 90`): rc 0, no ERROR or WARNING (`measurements/windowed-launch-recording.txt`); frame 89 is 00.
- **`unit_swap`** (headless, `--fixed-fps 60`, shipped rules with `OWN_BASE_SWAP`, Token stock of three of each type, every key a real event through the Input Map; two runs byte-identical, `scenario-outputs/split-unit_swap.txt`): 10 checks, all PASS, `swaps=11 spawns=21 zone_latency_ticks=1-2`, one engine ERROR that the scenario causes on purpose (the refused Round of `swap_data`) and none else.
- **`unit_swap_showcase`** (headless twice byte-identical, `scenario-outputs/split-unit_swap_showcase.txt`; windowed with `--write-movie`, 212 frames, rc 0, `measurements/unit_swap_showcase-windowed-run.txt`): four moments, each with its premise read; no premise failed, `errors=0 warnings=0`.
- **`map_fps`** on the build (windowed, 120 Hz, `measurements/windowed-map_fps-run-*.txt`): see AC-5 and the build section.
- **The 46 older outputs** (the drive harness's four and 42 of the split-screen runner's; `fps`, `map_fps` and `camera_smooth` are windowed tools) compared with baselines captured twice before the first edit (byte-identical to each other): see the regression section.

## Retained screenshots (`production/qa/evidence/story-011-unit-swap-at-own-base/`)

All 1280 × 720 frames from `--write-movie` recordings on 2026-10-04 (Metal 4.0, Forward+), each opened and read. Player 1 (orange HUD) is on the left, Player 2 (teal) on the right, both in the view from above.

| File | What it shows | Read |
|---|---|---|
| `00-launch-both-players-choosing.png` | The main scene at launch, both Units benched in their Garages, both Players choosing | Both choice panels open with x5 x3 x2 x2, the HUD band, the Team edges and the Tokens line ("Motorbike Tokens: 5") where they were before the story |
| `01-both-units-in-their-garages.png` | Player 1's Truck (220 / 220 hit points) and Player 2's Motorbike (40 / 40) standing in their Garages | Each Unit on its Garage floor inside the walls, the tower and the Flag seat behind it, no panel in either view |
| `02-swap-panel-open-counts-unchanged-other-player-drives-on.png` | One moment after Player 1 pressed Self-destruct in its Garage | Player 1's Garage is empty, its gauges read 0 / 220 and 0 / 100, the panel "Choose your Unit" is open with Motorbike x5, Buggy x3, Truck x2 (the type just put away, under the cursor) and Gyrocopter x2, the Tokens line still says 5, and there is no respawn countdown; Player 2's view has no panel and its Motorbike has driven on out of the Garage (40 / 40) |
| `03-new-unit-in-the-garage.png` | Player 1 chose the Buggy | The Buggy stands in the Garage at 100 / 100 hit points and 50 / 100 Fuel (the spawn tank), the panel is gone, the Tokens line is unchanged |
| `04-swap-hint-at-home-and-self-destruct-hint-outside.png` | Player 1's Buggy dry in its own Base, Player 2's Motorbike dry on the open flat outside its own | Player 1's hint reads "Out of Fuel! Press Tab to swap your Unit", Player 2's "Out of Fuel! Press Enter to Self-destruct"; each is one line inside its panel in its own view, clear of the HUD band, and nothing is clipped |

## Acceptance criteria — what was measured

- **AC-1 (the swap).** `swap_at_home`: each Player swaps its Unit at home four times in a row, one of every type (Motorbike, Buggy, Truck, Gyrocopter), by the real Self-destruct key (Tab, Enter), and chooses the next type; the last swap of each is the Gyrocopter's. At every one of the 8 swaps: exactly one `unit_swapped` and no `unit_destroyed`; the Token counts of both Players are what they were; in the handler the Player is choosing and not alive; two ticks later the Unit is hidden, its collision layer is 0 and it stands on its Base's spawn point; the respawn wait reads 0.00 s. The chosen Unit appeared 4 ticks after the swap in every case (the choice key takes two ticks and the bench settle of story 005 does the rest; the respawn delay is 180), as the chosen type, at its full hit points and the spawn tank of its type read in the `unit_spawned` handler, on a spawn point. `last_motorbike` adds the type just put away: with one Motorbike Token left the swap leaves the count at 1, and the Motorbike is chosen again.
- **AC-2 (everywhere else).** `destruct_elsewhere`: Player 1's Self-destruct in the open outside its gate, inside Player 2's Base and one tick before the zone reports a Unit just put inside its own Base each announced a destruction and no swap, took one Token of the Unit's type and nothing else (Motorbike 3 to 2, 2 to 1, Buggy 3 to 2) and started the full delay (2.98 s read two ticks later) with the countdown showing. `last_motorbike`: after the swap of the last Motorbike (no loss) and the Motorbike chosen again, the Self-destruct outside the Base lost the Round for Player 1 and Player 2 won, with Player 1's Motorbike count at 0. `swap_vs_destruction`: a Gyrocopter with a copy of its stats that has one Fuel unit hovers dry; the key is set two ticks before the tank empties so it acts on the tick the Unit crashes in (its own tick, before the controller's); the Unit stayed destroyed (Gyrocopter Token 3 to 2, a 2.98 s wait running, no swap). That check is not vacuous: removing the controller's `is_alive` test from the swap fails it and only it (seeded defect 7).
- **AC-3 (it decides nothing, takes nothing).** `swap_vs_delivery`: Player 1's Carrier is put inside its own Base with the key set to act on the first tick the zone reports it (tick 713); the delivery of that tick won the Round for Player 1 (`round_over` on tick 713), no swap was announced, the Unit is still in play and the counts are as before. `swap_vs_homecoming`: the same with Player 1 carrying its own dropped Flag (tick 787): the events of that tick are `seated 0` then `swapped 0`, the Flag stands on its seat, Player 1 is choosing and the counts are as before. `swap_screens`: through Player 1's first swap Player 2's Motorbike kept driving (it moved) and the tree was never paused.
- **AC-4 (the screens).** `swap_screens`, read inside the handler of every one of the 8 swaps: the swapping Player's panel is visible, the other Player's is hidden, the countdown is hidden, the HUD's Tokens line is what it was before and the panel's count lines are the Player's counts. Frames 02 and 03 show it. `swap_hint`: a Motorbike stranded in Player 1's Base and a Buggy in Player 2's show "Out of Fuel! Press Tab to swap your Unit" and "Press Enter to swap your Unit" (the story's words, pinned in the check); carried out of its gate the same Unit's hint reads "Press Tab to Self-destruct" within three ticks, and carried back in the swap text again; the key then swaps the Unit and the hint goes. The last Motorbike no longer forfeits at home: `last_motorbike`.
- **AC-5 (data).** `swap_data`: both Base zones in `compound_base.tscn` have mask 18 (the units layer 2 and the gyrocopters layer 16) and watch the layer of every type in `match_rules.tres`; with `own_base_swap` false at runtime the same press at home destroys (Buggy Token 3 to 2) and the hint says Self-destruct; with the swap on and Player 1's zone mask set back to 2 a throwaway MatchController refuses the Round with one error that names the Gyrocopter ("bases[0].zone does not watch the physics layer of rules.unit_types[3] ('Gyrocopter'), so that type could not swap at home") and the mask is put back. The hint's swap text is a field of `self_destruct_hint.tscn` read through `tr()`, the switch is `MatchRules.own_base_swap` (shipped `true` in `match_rules.tres`), and the runner turns the swap off for every scenario that does not declare `OWN_BASE_SWAP`: the older outputs below are the proof. `map_fps` windowed on the build: `fps_avg_steady` 119.7 and 120.0, `fps_min_steady` 118.0 and 120.0, `draw_calls_max` 222 and 221 (story 010: 120.0 and 222), so the swap costs no frame.

## Stories 001 to 010 regression

Baselines of all 46 retained outputs (the drive harness's four and 42 of the split-screen runner's) were captured at the working tree of the start of the story, twice, before the first edit; the two captures were byte-identical. On the final code: 44 byte-identical, and `token_ui` and `tokens_data` identical after exact rewrites (`measurements/normalizers.json`): both print an engine backtrace of an intended error, and the lines of it name `match_controller.gd:295` (now 331) and `split_screen_harness.gd:750` (now 779) because the files gained lines; `tokens_data` also names `match_controller.gd:626` (now 728) and gains one frame, `request_self_destruct`, between `destroy` and the input node, because the Self-destruct key now calls the controller; it counts the controller's signals ("of 8 listened to", now 9, the new `unit_swapped`) and lints the code lines of 13 source files (1194, now 1263, with the same 5 integer literals, none new). All 46 exited 0 with `RESULT ok` (`measurements/regress-46-baselines.txt`). The older outputs keep their bytes because the runner turns the swap off before the scene is instanced (`_apply_swap_off()`), and because a Self-destruct that is not a swap destroys the Unit on the spot in the input node's tick exactly as before: the unchanged `destruction` and `loss` outputs are the proof that no destruction moved, `loss` in particular because it decides the loss on the frame of the destruction. Widening the Map's zones to mask 18 changed no older output.

## Seeded defects

23 seeded, 23 caught (`measurements/seeded-defects.py.txt` is the script, one exact text replacement each in a scratch copy of the repo, run against the scenario that guards it; `measurements/seeded-defects.txt` the run on the final code, each copy checked clean at the end). The first version of the script read each file's original text before taking its lock, so a second defect on the same copy could "restore" the first one's change: it produced identical cascades of failures and was caught by comparing a copy with the repo; it was rewritten with one worker per copy and the earlier numbers discarded. Four defects survived the first clean run and were closed: the swap query after the Round is over (a check of `can_swap()` after the Round was lost), the hint's wording (the story's sentence is now pinned), the destruction moved out of the input tick (it belongs to `loss`, not `destruction`), and a panel that opens for both Players (the first mutant, `if true: _refresh()`, is equivalent: the panel rereads the controller's answers for its own Player, so a spurious refresh changes nothing; a mutant that forces `visible = true` is caught).

| Defect | Caught by |
|---|---|
| the key never swaps | `swap_at_home` and six more |
| the swap destroys the Unit | `swap_at_home`, `swap_screens`, `destruct_elsewhere`, `last_motorbike`, `swap_vs_homecoming` |
| the swap takes a Token | the same five |
| the swap starts the respawn wait | `swap_at_home` |
| the swap is not announced | `swap_at_home`, `last_motorbike`, `swap_vs_homecoming`, `swap_hint` |
| the swap runs before the deliveries | `swap_vs_homecoming` |
| the swap ignores a Unit destroyed on its tick | `swap_vs_destruction` |
| the swap works after the Round is over | `last_motorbike` |
| the swap works anywhere | `destruct_elsewhere` and five more |
| the swap works in either Base's zone | `destruct_elsewhere` |
| the switch is ignored | `swap_data` |
| a Self-destruct outside destroys nothing | `destruct_elsewhere` and four more |
| the zone does not watch the gyrocopters layer | eight checks (the Round is refused) |
| the shipped data has the swap off | `swap_at_home` and six more |
| Player 2's key asks for Player 1 | `swap_at_home`, `destruct_elsewhere`, `swap_vs_homecoming`, `swap_hint`, `swap_data` |
| the panel ignores the swap | `swap_screens`, `last_motorbike` |
| the panel is shown for both Players | `swap_screens` |
| the hint never says swap | `swap_hint` |
| the hint is not read again while shown | `swap_hint`, `swap_data` |
| the hint's swap text is the Self-destruct text | `swap_hint` |
| begin() does not check the zone masks | `swap_data`, `no_engine_noise` |
| the runner leaves the swap on | `destruction` (output differs from its baseline) |
| the destruction is moved out of the input tick | `loss` (output differs from its baseline) |

One defensive branch has no seeded defect and cannot have one: `_apply_swaps()` leaves a Unit alone that still carries a Flag. A Carrier inside its own zone has delivered or re-seated before the swap runs, so no key can reach it; it stays as a guard because a swap that took a Flag out of play would be a worse defect than a refused key.

## Verification of the build itself

- **Parse:** `godot --headless --path . --import` exit 0, no ERROR; the parse check over the 21 scripts changed or added: `ok` for all, exit 0 (`measurements/parse-check.txt`). Engine risk is HIGH on this pin; the APIs used are `Area3D.overlaps_body()`, `OS.add_logger`, `Node.set_process()` and `Label.tr()`, all in use in the code before this story.
- **Run:** the main scene launched windowed and recorded (00), the showcase windowed (01 to 04), `map_fps` windowed twice: rc 0 every time, no ERROR or WARNING outside the one the scenario causes.
- **Scenario sizes:** `unit_swap.gd` 225 lines, `unit_swap_flows.gd` 229, `unit_swap_kit.gd` 225, `unit_swap_showcase.gd` 112, under the 280-line guideline of TD-006 each; the runner grew to 934 lines (the swap-off step, the two constants and two registrations).

## Measured facts the code comments point at

- **A key set at a tick's start acts on the next tick** (the runner's own rule, stated in `token_kit.gd` and the Story 005 evidence doc). The first draft of the timed checks ignored it: the homecoming's swap came on tick 855 against the pick-up on 854, and the delivery and Gyrocopter checks would have passed without ever putting the key on the tick they claim. The checks now measure a zone latency first (`zone_latency()`) and set the key so that it acts on the tick the zone first reports the Unit (`enter_pressing()`), or on the tick the tank empties.
- **The zone reports a Unit put inside its Base 2 ticks later** (measured by `zone_latency()`, the same number every time), and a Unit that has just appeared (`unit_spawned`) 1 to 2 ticks later (21 spawns). So a Self-destruct that acts less than 2 ticks after a Unit is driven or put in is still a Self-destruct: the check puts the key one tick early and the Unit is destroyed and a Token taken (Motorbike 3 to 2). That window is two physics ticks, 33 ms; no human press lands in it by intent.
- **Order inside the controller's tick:** the garage queue's spawns, the pick-ups, the deliveries, the swaps, the loss check. A swap request is noted in the input node's tick (priority -1) and made in the controller's tick of the same frame, so a Shot's kill or a Fuel crash (the Unit's and the Shot's own ticks, before the controller's) comes first, and a delivery or an owner's homecoming of the same tick comes first.
- **`UnitChoice._refresh()` rereads the controller's answers for its own Player**, so the panel needs no filter of its own on `unit_swapped`; the filter is there for clarity and the mutant that removes it is equivalent.

## Notes for the author

- **Two questions, built as decided; ask before the story closes** (the story text): (1) choosing the same type again is allowed, so a trip home is a free repair and resets the tank to the spawn share, a nearly empty Unit getting fuller and a full one emptier. Keep it? (2) A Player can swap the moment their Unit appears in the Garage (after about two ticks), so the choice at the start of a Round and after a respawn can be changed for free. Keep it? Both are recorded in `design/rules.md` as open for the author. Answered at `/story-done` on 2026-10-04: keep both.
- The swap works wherever the Base's zone reports the Unit: the whole yard inside the walls and the Garage, not only the Garage floor. The zone ends 13.9 m in front of the Base's origin, level with the inner face of the gate walls (they span 13.7 to 15.0 m), so a Unit in the gateway itself is outside.
- The greybox `base.tscn` zone keeps mask 2 (units only) and its scenarios run with the swap off; a Round on a Map with such a zone and the swap on is refused at launch with a message naming the type.
- `match_controller.gd` grew from 629 to 731 lines (about 60 of them the swap's class-doc paragraph, the signal and the query docs), the second src file over 700 after `unit.gd`; TD-008 and TD-010 carry the figure.
- The hint polls the controller once per frame while it is shown (a stranded Unit can coast across its gate); nothing polls while it is hidden.

## Human checks (confirmed at `/story-done`, 2026-10-04)

1. **Real keyboard, both Players:** drive a Unit home through the gate and press Tab (Player 1) or Enter (Player 2) inside the walls: the Unit goes, the panel opens, and a chosen Unit appears in the Garage; press the same key outside the walls and in the other Player's Base: the Unit is destroyed and the countdown runs. Every type, the Gyrocopter included.
2. **Feel:** the panel opens at once after the key, and the new Unit appears quickly after the choice (about 0.1 s in the run); the swap does not feel like a respawn.
3. **The hint:** "Out of Fuel! Press Tab to swap your Unit" at home reads well and is where the Player looks.
4. **The two questions** above.

The developer answered "Yes — passes" to checks 1 (real keyboard, both Players), 2 (feel) and 3 (the hint), and **kept both behaviours as built**: choosing the same type again stays a free repair and refuel to the spawn tank, and a Player may swap the moment the Unit appears, so a first choice can be changed for free.

## Sign-Off

| Check | Result |
|---|---|
| Frames read against the acceptance criteria | [x] Done by the implementing session (00 to 04) |
| Human checks 1 to 3 (keyboard, feel, hint) | [x] Confirmed by the developer, 2026-10-04 |
| The two questions for the author | [x] Answered by the developer, 2026-10-04: keep both |
| Lead sign-off (solo developer: Tomas Kunzo) | [x] Approved, 2026-10-04 |

*Recorded from the developer's answers to the `/story-done` questions on 2026-10-04; not filled in by an agent on its own.*
