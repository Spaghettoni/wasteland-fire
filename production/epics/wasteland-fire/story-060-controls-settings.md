# Story 060: The Controls screen

> **Epic**: Wasteland Fire — First Playable
> **Status**: Done
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-26

## Context

**Requirement**: Martin, 2026-10-26: "chcel by som pridat este jednu zasadnu vec, moznost nastavit ovladanie. aj pre keyboard aj ovladace. a aby tam bolo aj default co ich revertne. na zaciatku v menu, kde si volime timy napr". His answers: one layout for every controller; Keyboard 1 and Keyboard 2 each their own keys; kept on disk; every game action, the Round's restart and the menus kept fixed.

**ADR Governing Implementation**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM (the Input Map is shared; a bad layout must not leave a Player without controls)

---

## Acceptance Criteria

- [x] AC-1: Pick a side opens the Controls screen with C, a controller's Menu or the Controls button. It lists Throttle, Reverse, Steer left, Steer right, Fire, Fire high, Secondary, Camera and Self-destruct, with a column for Keyboard 1, Keyboard 2 and two for the controller.
- [x] AC-2: Choosing a cell (arrows / D-pad / mouse, Enter / A / click) and pressing a key, a button, a stick or a trigger sets it. A key or pad input another action holds moves to the action this one came from (across both keyboard halves), so no input does two things.
- [x] AC-3: Default puts every control back, on the screen and in the file.
- [x] AC-4: Escape (keyboard) and Menu and Guide (controller) cannot be taken; Delete empties a controller slot unless it is the action's only one; Escape or six seconds cancel.
- [x] AC-5: The controls are kept in `user://controls.cfg` and read when the game starts; a file that would put one key on two actions, or a controller layout PadLayout refuses, is ignored for the defaults.
- [x] AC-6: The match plays them: a keyboard half's Player gets that half's keys; every controller gets the layout; Pick a side's cards and lines name the keys; the in-game hints name them (they read the Input Map and the layout).

---

## Implementation Notes

- `src/gameplay/input/controls_settings.gd` + `data/controls_settings.tres` (the actions, names, reserved inputs, the file); `control_bindings.gd` (the controls, moves, Default, the file, `keyboard_keys()`, `pad_layout()`).
- `Lineup.controls` carries them from Pick a side to the match; `SplitScreen._apply_inputs()` and `apply_lineup()` (PadAssignment's layout) play them. Without them (evidence runs) project.godot's keys and `pad_layout.tres` play as before.
- `src/ui/lobby/controls_screen.tscn/.gd`; `pick_side.tscn/.gd` (the button, C / Menu, key names in the texts).

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `tools/evidence/lobby/controls_check.gd` C1 to C7 with frames; `pick_side_check`, `map_choice_check`; the regression.

**Status**: [x] `production/qa/evidence/story-059-060-evidence.md`

---

## Dependencies

- Depends on: stories 032 (pads) and 048 (Pick a side, the Lineup).
- Unlocks: none.
