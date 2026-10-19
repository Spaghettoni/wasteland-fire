# Story 032 evidence: Xbox controllers

> **Story**: `production/epics/wasteland-fire/story-032-xbox-controllers.md`
> **Type**: Integration (documented playtest record + headless scenarios)
> **Written**: 2026-10-18, by `/dev-story` in a cloud session (Linux, Godot 4.7.2 official build, no pads attached)
> **Sign-off**: [x] Approved by Martin after playing the build, 2026-10-19 ("ok, super za mna")

## What was built

- `src/gameplay/input/pad_binding.gd` — one pad input (a button, or an axis direction) bound to one action suffix, with the name the hints show.
- `src/gameplay/input/pad_layout.gd` and `src/gameplay/input/data/pad_layout.tres` — the layout as data: RT throttle, LT reverse, left stick and D-pad steer, A fire, X Mine, Y camera, View Self-destruct, Menu restart; dead zone 0.2; `debug_damage` deliberately unbound. `first_problem(prefix)` refuses a missing action, an input bound to two actions, a missing name, an unknown action and a dead zone outside (0, 1).
- `src/gameplay/input/pad_assignment.gd` — the node in `split_screen.tscn` that gives the first connected pad to Player 1 and the second to Player 2, adding the layout's events to that Player's `p1_*` / `p2_*` actions with the pad's device ID (so the Input Map matches them for that pad alone), and taking them back on a disconnect and when the node leaves the tree. No gameplay input node changed.
- The hints: `self_destruct_hint.gd`, `unit_choice.gd` and `round_over_screen.gd` take an optional `pad_assignment` and name the pad's inputs for a Player who has a pad; `player_notice.gd` shows "Controller connected" / "Controller disconnected" for 1.5 s in that Player's view.

## Acceptance criteria, as measured

| AC | Result | Where |
|---|---|---|
| AC-1 pads in connection order, keyboard still works | PASS: pad 0 → Player 1, pad 1 → Player 2, pad 2 → nobody, pad 0 again while Player 2 is free → nobody; every action keeps its keyboard key | `pads` P2 |
| AC-2 a pad acts for its own Player only | PASS: all 11 inputs pressed on each pad press only the own Player's action (the shared restart by both); RT on pad 0 moved Player 1's Unit 10.17 m and Player 2's 0.000 m; the stick on pad 1 turned Player 2's Unit 0.700 rad and Player 1's 0.000 rad | `pads` P3, P6 |
| AC-3 the layout, analog | PASS for the layout and the buttons (A fired a Shot, Y stepped Player 1's camera only, X read by `p1_lay_mine` only, View destroyed Player 1's Unit only). **Half a trigger is 0.375 of full throttle, not "about half"**: Godot scales what is past the dead zone to the full range (inverse_lerp(0.2, 1, 0.5)). See Questions. | `pads` P6, P7; `pads_data` D1 |
| AC-4 the choice on the pad | PASS: one stick push 0 → 1, a stick held 30 ticks one more step (1 → 2), two D-pad lefts back to 0, the other Player's cursor never moved; A on both pads put both Units in play | `pads` P5 |
| AC-5 pads that come and go | PASS: unplugged with RT held, `p1_throttle` is released at once and the Unit slows from 20.0 to 8.0 m/s in 60 ticks; "Controller disconnected" in Player 1's view only; reconnect → Player 1, "Controller connected"; W held through a disconnect stays held and releases with W | `pads` P8; frames 02, 06 |
| AC-6 the hints name what the Player holds | PASS: before any pad the hints read exactly as before ("A / D to choose, Space to confirm", "Tab", …); with pad 0 only, Player 1 reads "Stick left / Stick right to choose, A to confirm" and "View" while Player 2 still reads the keys; the Round-over line reads "Press R or Menu to play again" | `pads` P1, P2, P4; frames 01–03, 05 |
| AC-7 all data, broken layout refused | PASS: five broken layouts each named by `first_problem()`; a PadAssignment with A on two actions pushes exactly one error, takes no pad, adds no event, and the 132 keyboard events stay; no integer literal but 0 and 1 in the pad scripts | `pads_data` D2–D4 |
| AC-8 no pad, today's game | PASS with the differences explained below: no older scenario changes what it measures | Regression |
| AC-9 Martin's play on the real pads | NOT YET: for `/story-done` | Human checks |

Both scenarios ran twice, byte-identical: `scenario-outputs/pads.txt` (9 checks, 0 errors, 0 warnings) and `scenario-outputs/pads_data.txt` (4 checks).

## Regression (AC-8)

All 88 scenarios of the harness were captured on `main` at bf9e12e (an untouched copy of the tree) before any change, and again on the story's tree, headless, two at a time on this 2-core machine. 85 pass on the old tree; the other 3 (`camera_smooth`, `rotors_fps`, `tyre_tracks_fps`) need a real window and fail headless on both trees. Of the 85, 60 are byte-identical. The other 25 differ only in:

- **the Jolt warning** "job system exceeded the maximum number of jobs", which the engine prints at random under load on 2 cores, on both trees (it is why `loss` fails: its engine-log check counts the warning; `loss` alone on the old tree failed 2 runs of 2, on the new tree 1 of 2, the same warning each time);
- **the harness's own line numbers** in stack traces (four lines were added to its scenario table);
- **the frame-rate scenarios' timings** (`*_fps`, measured time, different on every run);
- **the lint counts that read the files this story extended**: `ammo` and `mines` count the notice's code lines (225 → 243, 389 → 407), `fuel_building` counts the scripts under `src/` (64 → 67, the three pad scripts); all three still pass. `tokens_data` counted one integer literal more (a `2` in `round_over_screen.gd`); the literal was removed, and the rerun counts 5, as before.

None of them changes a measured position, a count of Shots, Tokens, destructions or spawns, or a verdict that does not read the engine log.

## A defect the scenario found, and the engine fact behind it

The first `pads` run failed P8: a keyboard key held while the pad of the same Player was unplugged lost its action. Measured on 4.7.2 with a probe: `InputMap.action_erase_event()` releases the whole action, the keyboard's hold included, and the engine does not press it again while the key stays down. `PadAssignment._take_back()` now presses every key that is still down once more, through the Input like a real key, after the erase; the key's real release then releases the action (P8: "W held through a disconnect: p1_throttle true, released with W true"). Side effect, documented in the code: a key held at that very moment reads as freshly pressed.

## Seeded defects (each one mutation, run, restored)

| Mutation | Caught by |
|---|---|
| M1 pad events with device -1 (every pad drives both Players) | P2, P3, P5, P7 |
| M2 a held key not pressed again after a disconnect | P8 |
| M3 a disconnect that keeps the pad's events | P8, P9 |
| M4 the Self-destruct hint naming the key to a Player with a pad | P4 |
| M5 a button index written in code | D4 |
| M6 one pad assigned to two Players | P2 (after the check was tightened: the first version tried the duplicate only when both slots were full, and missed it) |

## Frames

Captured windowed at 1280 x 720 under a virtual display, with the **OpenGL compatibility renderer on Mesa llvmpipe** (the cloud machine has no GPU), so the 3D looks differ from Forward+ on a real machine; the HUD, the hints and the notices are what these frames are for. `pads_showcase` connects the pads through the PadAssignment (no real pads there).

- `story-032-xbox-controllers/01-launch-keyboard-hints.png` — both choice panels name the keys, as before.
- `02-pad-1-connected-notice-and-pad-hint.png` — "Controller connected" in Player 1's view; Player 1's panel reads "Stick left / Stick right to choose, A to confirm", Player 2's "Left / Right to choose, Period to confirm".
- `03-both-pads-pad-hints.png` — both panels name the stick and A.
- `04-driving-on-the-right-trigger.png` — both Units in play after A on both pads; Player 1 has driven out on the right trigger.
- `05-round-over-r-or-menu-staged.png` — the Round-over screen (staged: its show called directly) reads "Press R or Menu to play again" in both views.
- `06-pad-1-disconnected-notice.png` — "Controller disconnected" in Player 1's view only.

Each was opened and read. The out-of-Fuel line with "View" is measured as text in P4 and has no frame.

## Human checks (for `/story-done`, on Martin's Windows PC with two paired Xbox controllers)

1. Launch with both controllers on: do the choice panels say "Stick left / Stick right to choose, A to confirm" and does each stick move only its own Player's cursor, one type per push?
2. Drive both Units on the triggers: does the throttle feel right, especially half a trigger (0.375 of full, see Questions)? Does a resting stick creep?
3. A fires, X lays a Mine with a Truck, Y switches the camera, View Self-destructs: each only for its own Player?
4. Play a Round to the end: does Menu restart it?
5. Mid-Round, switch one controller off and on again (or unplug it): does the view say so, does the Unit stop accelerating, does the keyboard still drive it, and does the pad drive again after it reconnects — to the same Player?
6. One Player on a pad, the other on the keyboard: anything odd?

## Questions for Martin

1. **Half a trigger.** Godot counts the first 20% of a trigger as nothing and stretches the rest to full, so half a trigger gives 0.375 of full throttle, not 0.5. Keep it (a smaller dead zone, say 0.1, gives 0.44), or make the trigger linear from zero (no dead zone on the triggers, keeping one on the stick)? It is one value in `pad_layout.tres` either way.
2. **The order of the pads.** Windows decides which pad is "first". If the wrong Player gets a pad, the join screen of story 034 fixes it; until then, switch the pads on in Player order before launching.
