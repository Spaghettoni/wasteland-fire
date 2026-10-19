# Story 032: Xbox controllers: each Player can drive, fire, lay Mines and choose with a pad, the keyboard still works

> **Epic**: Wasteland Fire — First Playable
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (about a day at `coarse`: the gameplay input nodes already read actions, not keys)
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-19

## Context

**GDD**: `design/game-brief.md` (Out of scope: "Keyboard only", changed by this story), `design/rules.md` ("Camera and controls"; "First Playable"); `CONTEXT.md` (Player)
**Requirement**: Martin's request of 2026-10-18, made in a session: "aby sme vedeli používať aj ovládače pri hraní — máme natívne Xbox ovládače spárované s mojím PC". He was offered four steps (this story; then two teams of two on four views; then a join screen where each Player picks a pad; then rebinding) and answered that he likes the plan and wants to start with this one (decided 2026-10-18). This changes the scope: the brief's "Keyboard only: no gamepad support, no key-rebinding UI" becomes "no key-rebinding UI yet" (rebinding is a later story).

Today every gameplay input node reads Input Map actions under its Player's prefix (`p1_`, `p2_`, stored in `split_screen.tscn`), never keys, and `project.godot` binds only keyboard keys (no `InputEventJoypad*` at all). The drive input already reads analog strengths (`player_drive_input.gd:72-73`, `Input.get_axis`), so a stick or a trigger drives at part throttle without new code there. The HUD's hints (`self_destruct_hint.gd`, `unit_choice.gd`) and the Round-over screen (`round_over_screen.gd`) name the first **key** event of an action, so they would name a keyboard key to a Player holding a pad.

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal). Read `docs/engine-reference/godot/modules/input.md` first: since 4.7 the keyboard's and the mouse's device IDs are `InputEvent.DEVICE_ID_KEYBOARD` (16) and `InputEvent.DEVICE_ID_MOUSE` (32), not 0, "because some joypads may use 0 as their ID"; since 4.5 gamepads go through SDL3. Never compare `device` to 0 to mean the keyboard.

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From Martin's request of 2026-10-18 and the layout he accepted, scoped to this story:*

- [x] AC-1: Each Player has one **Input source** for pads: the first connected pad (in `Input.get_connected_joypads()` order) belongs to Player 1, the second to Player 2; a third or later pad belongs to nobody and moves nothing. Each Player's keyboard layout keeps working beside the pad, unchanged, so a Round can be played with two pads, one pad and the keyboard, or the keyboard only as today.
- [x] AC-2: A pad drives, fires and acts for its own Player only, never for the other: Player 1's pad moves nothing of Player 2 and the reverse, measured with two pads at once (on the real machine) and with injected joypad events of two device IDs (headless).
- [x] AC-3: The starting pad layout (Xbox names; data, not code): right trigger throttle, left trigger reverse, left stick left and right steer (the D-pad left and right too), A fire, X lay a Mine, Y switch the camera, View (Back) Self-destruct, Menu (Start) restart the Round on the Round-over screen. Throttle, reverse and steering are analog: half a trigger is about half throttle, with a dead zone (data) so a resting stick does not creep. The debug-damage keys get no pad button.
- [x] AC-4: The Unit choice works on the pad: the left stick or the D-pad moves the cursor one type per push (a held stick does not repeat, as a held key does not today) and A confirms, with the same rules as the keys (types with no Tokens skipped, the A still held from the last Unit does not confirm at once).
- [x] AC-5: Pads can come and go: a pad connected during a Round goes to the first Player without one; a pad disconnected frees its Player, whose Unit keeps the keyboard and is not stopped or destroyed (it coasts as with released keys). Nothing errors and nothing needs a restart. A notice in that Player's view says the pad is connected or disconnected (`player_notice.gd`, data: its text and time).
- [x] AC-6: The hints name what the Player holds: the Self-destruct hint, the Unit choice's key hints and the Round-over screen name the pad's buttons (for example "View", "A", "Menu") for a Player who has a pad, and the keys, as today, for a Player who has none. The names come from the Input Map and the layout data, never from text written in the hint code.
- [x] AC-7: Every value is data: the pad layout (which button or axis each action suffix takes), the dead zones and the button names live in a resource (say `src/gameplay/input/pad_layout.tres` with a `first_problem()`); no button index, axis or number in code but 0 and 1. A layout with a missing or doubled action is refused at `_ready()` with one error, and the keyboard still works.
- [x] AC-8: With no pad connected the game is today's game: every older evidence scenario keeps its outputs byte for byte against the capture taken at the start of the story.
- [x] AC-9: Played on Martin's Windows PC with two paired Xbox controllers: a whole Round from the Unit choice to the Round-over screen and a restart, both Players on pads, then one on the pad and one on the keyboard; a pad unplugged and plugged back mid-Round (or switched off and on). Recorded in the evidence doc as the human checks.

---

## Implementation Notes

*At `minimal` there is no ADR; these are pointers, not decisions. The file:line pointers are `main` at bf9e12e: re-find them if stories 027 to 031 land first.*

- **The shape: keep the actions, add the pad's events to them.** Every input node already reads `prefix + suffix` actions (`player_drive_input.gd`, `player_fire_input.gd`, `player_mine_input.gd`, `player_match_input.gd`, `player_choice_input.gd`, `player_camera_input.gd`), so the cheapest correct design leaves all of them untouched: one new node (say `PadAssignment`, `src/gameplay/input/pad_assignment.gd`), composed by `split_screen.tscn`, adds to each Player's `p1_*` / `p2_*` actions the pad layout's events with `device` set to that Player's pad ID (`InputMap.action_add_event`), and removes them again when the pad leaves. An event in the Input Map with a set `device` matches only that device, which is what keeps the two pads apart (AC-2); the keyboard events in `project.godot` stay as they are.
- **The restart.** `round_restart` is one shared action; the Menu button of either Player's pad is added to it (or to it with each pad's device: both work, the build's call).
- **Events the pad gives.** Triggers and stick directions are `InputEventJoypadMotion` (axis + `axis_value` sign), buttons are `InputEventJoypadButton`; the actions' own `deadzone` (0.2 today in `project.godot`) applies to both. Measure on 4.7.2 that `Input.get_axis()` returns the trigger's partial strength through an action (AC-3) and that `is_action_just_pressed` fires once per stick push for the choice (AC-4); if the stick chatters around the dead zone, a separate dead zone for the choice's steer events is data.
- **Hot-plug.** `Input.joy_connection_changed(device, connected)`; on connect, the first Player without a pad gets it; on disconnect, that Player's pad events are removed from the Input Map at once, so no action is left held by a gone device. Godot releases a disconnected pad's held actions; measure it (a Unit must not keep full throttle).
- **The hints.** Today `self_destruct_hint.gd:169-180`, `unit_choice.gd:444-455` and `round_over_screen.gd:150-160` loop the action's events for the first `InputEventKey`. Give them one shared helper (say `InputNames.for_action(action, pad_device)`) that returns the pad button's name from the layout data when the Player has a pad, and today's key name otherwise; the hint refreshes on `PadAssignment`'s change signal.
- **Determinism and the older outputs** (AC-8). The harness injects keys (`tools/evidence/split_screen_harness.gd:1705-1723`); with no joypad connected `PadAssignment` adds nothing, so the old scenarios should be untouched; prove it with the regression against the capture at the start. New headless scenarios inject `InputEventJoypadMotion` / `InputEventJoypadButton` with two device IDs (for example 0 and 1, which 4.7 no longer confuses with the keyboard) and call the assignment's connect and disconnect handlers directly (a headless run has no real pads).
- **The evidence scenarios.** `pads` (headless, run twice byte-identical): assignment in order, a third pad ignored; each pad's throttle, steer, fire, Mine, camera and Self-destruct acting on its own Player only; a half trigger as half throttle; a stick push moving the choice cursor once; a disconnect freeing the Player with no held action left; a reconnect; the hints' names with and without a pad. `pads_data`: the layout's `first_problem()` refusing a missing and a doubled action. Frames: both views with pad hints (the choice panel and the Self-destruct hint), and the Round-over screen naming Menu.
- **Seeded defects** (story 011's script as the template). At least: pad events added with `device = -1` (both pads drive both Players); the keyboard compared to device 0; a disconnect that leaves the throttle held; a held stick repeating the cursor; a hint naming a key to a Player with a pad; a button index written in code (the lint).
- **Docs in the same change** (`design/rules.md`, Process rules): in the brief, "Keyboard only" becomes "No key-rebinding UI yet" with this story's date; in `design/rules.md` "Camera and controls" and "First Playable", the pad layout as built; `CONTEXT.md` gets "Input source" (a Player's keyboard layout and, if one is assigned, their pad); README's How it plays gets the pad layout; a Story 032 entry in `tests/smoke/critical-paths.md`; EPIC.md's row at the close.
- **Process** (`design/rules.md`, Process rules): after the change, say how to test it: the main scene on Windows with both Xbox controllers paired and on before launch; both choose with the stick and A; drive with the triggers; fire, lay a Mine, switch the camera; Self-destruct with View; win or lose and restart with Menu; then switch one pad off mid-Round and on again.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 033 (planned, not yet written: needs Martin's answers on the team rules): two teams of two Players on four views.
- Story 034 (planned): a join screen before the Round where each Player presses A on a pad or a key to take a slot and pick a team; it replaces this story's "pads in connection order" assignment.
- Story 035 (planned): rebinding every pad and keyboard layout, saved between runs.
- Rumble, a pad-driven pause menu, and two keyboards told apart (4.7 cannot tell them apart: `modules/input.md`).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a player-observable change is still launched and observed, with retained frames.*

**Story Type**: Integration
**Required evidence**:
- Integration: a documented playtest (`production/qa/evidence/story-032-xbox-controllers-evidence.md`) with the headless `pads` and `pads_data` outputs, the regression of the older outputs, the seeded defects, frames of the pad hints in both views and of the Round-over screen, and Martin's human checks of AC-9 on the real pads at `/story-done`.

**Status**: [x] Created 2026-10-18: `production/qa/evidence/story-032-xbox-controllers-evidence.md`, with `scenario-outputs/` (`pads`, `pads_data`, each run twice byte-identical) and six frames in `production/qa/evidence/story-032-xbox-controllers/` (each opened and read); the human checks on the real pads (AC-9), the two questions and the sign-off are for `/story-done`

---

## Dependencies

- Depends on: None (stories 027 to 031 touch the looks, not the input; whichever lands second re-finds the file:line pointers).
- Unlocks: Story 033 (four Players need a pad each), Story 034 (the join screen replaces the assignment by connection order), Story 035 (rebinding edits the pad layout this story makes data).

---

## Completion Notes

**Completed**: 2026-10-19
**Criteria**: 9/9 passing. AC-1 to AC-8 measured by `pads` (9 checks) and `pads_data` (4 checks), each run twice byte-identical; AC-9 (the real Xbox controllers on Martin's PC) accepted by Martin after playing `WastelandFire-2026-10-18-controllers.exe` and the later builds ("ok, super za mna", 2026-10-19).
**Deviations**: None blocking. Advisory: half a trigger gives 0.375 of full throttle (the 0.2 dead zone scaled out), not "about half" as AC-3 worded it; Martin did not raise it after playing, so it is kept as built (one value in `pad_layout.tres`).
**Test Evidence**: Integration: `production/qa/evidence/story-032-xbox-controllers-evidence.md` (sign-off `[x]`, 2026-10-19), six frames, `scenario-outputs/`, six seeded defects all caught, the regression of the 88 older scenarios.
**Code Review**: Skipped, Solo mode (LP-CODE-REVIEW); QL-TEST-COVERAGE skipped, `qa.level` minimal.
**Tech debt logged**: None.
**Found on the way**: `InputMap.action_erase_event()` on 4.7.2 releases the whole action, a held keyboard key included; `PadAssignment._take_back()` presses the held keys again (the evidence doc's "A defect the scenario found").
